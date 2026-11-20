function Get-CIPPAzArmAccessToken {
    <#
    .SYNOPSIS
        Returns an ARM bearer token for the requested profile. Never logs the token.
    .DESCRIPTION
        Modes: lighthouse (client credentials in ManagingTenantId) and servicePrincipal
        (client credentials in the managed tenant). Profiles reader|change|rbac fail closed
        when absent. The CIPP SAM ApplicationID can never be used.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantFilter,

        [Parameter(Mandatory)]
        [ValidateSet('reader', 'change', 'rbac')]
        [string]$Profile,

        $Config
    )

    if (-not $Config) {
        $Config = Get-CIPPAzArmTenantConfig -TenantFilter $TenantFilter
    }
    if (-not $Config -or -not $Config.Enabled) {
        throw 'Azure ARM access is not configured or not enabled for this tenant.'
    }

    if ($Profile -in @('change', 'rbac') -and $Config.ChangeWindow) {
        $Now = [datetime]::UtcNow
        $Start = $null; $End = $null
        if ($Config.ChangeWindow.start) { [void][datetime]::TryParse([string]$Config.ChangeWindow.start, [ref]$Start) }
        if ($Config.ChangeWindow.end) { [void][datetime]::TryParse([string]$Config.ChangeWindow.end, [ref]$End) }
        if ($Start -and $Now -lt $Start.ToUniversalTime()) {
            throw "Profile '$Profile' is outside the configured changeWindow."
        }
        if ($End -and $Now -gt $End.ToUniversalTime()) {
            throw "Profile '$Profile' is outside the configured changeWindow."
        }
    }

    $ProfileConfig = $null
    if ($Config.Profiles -is [hashtable]) {
        $ProfileConfig = $Config.Profiles[$Profile]
    } elseif ($Config.Profiles) {
        $ProfileConfig = $Config.Profiles.$Profile
    }
    if (-not $ProfileConfig) {
        throw "Azure ARM profile '$Profile' is not configured for this tenant."
    }

    $AppId = [string]($ProfileConfig.appId ?? $ProfileConfig.AppId)
    if ([string]::IsNullOrWhiteSpace($AppId)) {
        throw "Azure ARM profile '$Profile' is missing appId."
    }
    $SamAppId = [string]$env:ApplicationID
    if (-not [string]::IsNullOrWhiteSpace($SamAppId) -and $AppId -eq $SamAppId) {
        throw 'The CIPP SAM application identity cannot be used for Azure ARM.'
    }

    $TokenTenantId = if ([string]$Config.Mode -eq 'lighthouse') {
        [string]$Config.ManagingTenantId
    } else {
        # Resolve customer tenant GUID via existing helper when possible
        $TenantId = $null
        try {
            $TenantRow = Get-Tenants -TenantFilter $TenantFilter | Select-Object -First 1
            $TenantId = [string]($TenantRow.customerId ?? $TenantRow.CustomerId ?? $TenantRow.tenantId)
        } catch { }
        if ([string]::IsNullOrWhiteSpace($TenantId)) {
            $TenantId = [string]($ProfileConfig.tenantId ?? $ProfileConfig.TenantId)
        }
        if ([string]::IsNullOrWhiteSpace($TenantId)) {
            throw 'Could not resolve client tenant id for servicePrincipal mode.'
        }
        $TenantId
    }

    $Scope = 'https://management.azure.com/.default'
    $CacheKey = "$TenantFilter|$Profile|$AppId|$TokenTenantId"
    if ($script:CIPPAzArmTokenCache -and $script:CIPPAzArmTokenCache[$CacheKey]) {
        $Cached = $script:CIPPAzArmTokenCache[$CacheKey]
        if ($Cached.ExpiresOn -and [datetime]::UtcNow -lt $Cached.ExpiresOn.AddMinutes(-2)) {
            return [pscustomobject]@{
                AccessToken = $Cached.AccessToken
                ExpiresOn   = $Cached.ExpiresOn
                AppId       = $AppId
                Mode        = [string]$Config.Mode
                Profile     = $Profile
                TenantId    = $TokenTenantId
            }
        }
    }

    $TokenResponse = $null
    $CertName = [string]($ProfileConfig.certificateSecretName ?? $ProfileConfig.CertificateSecretName)
    $SecretName = [string]($ProfileConfig.clientSecretName ?? $ProfileConfig.ClientSecretName)

    if (-not [string]::IsNullOrWhiteSpace($CertName)) {
        $CertPemOrB64 = Get-CippKeyVaultSecret -Name $CertName -AsPlainText
        if ([string]::IsNullOrWhiteSpace($CertPemOrB64)) {
            throw "Certificate secret '$CertName' is empty."
        }
        # Prefer PFX base64 with optional password ref; otherwise PEM is not supported here.
        $CertPassword = $null
        $PwdName = [string]($ProfileConfig.certificatePasswordSecretName ?? $ProfileConfig.CertificatePasswordSecretName)
        if (-not [string]::IsNullOrWhiteSpace($PwdName)) {
            $CertPassword = Get-CippKeyVaultSecret -Name $PwdName -AsPlainText
        }
        $CertBytes = [Convert]::FromBase64String($CertPemOrB64)
        $Flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        $Certificate = if ($CertPassword) {
            $SecurePwd = ConvertTo-SecureString $CertPassword -AsPlainText -Force
            [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertBytes, $SecurePwd, $Flags)
        } else {
            [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertBytes, '', $Flags)
        }
        $TokenResponse = Get-GraphTokenFromCert -TenantId $TokenTenantId -AppId $AppId -Certificate $Certificate -Scope $Scope -SkipCache
    } elseif (-not [string]::IsNullOrWhiteSpace($SecretName)) {
        $ClientSecret = Get-CippKeyVaultSecret -Name $SecretName -AsPlainText
        if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
            throw "Client secret '$SecretName' is empty."
        }
        $Body = @{
            client_id     = $AppId
            client_secret = $ClientSecret
            scope         = $Scope
            grant_type    = 'client_credentials'
        }
        $TokenResponse = Invoke-CIPPRestMethod -Method Post -Uri "https://login.microsoftonline.com/$TokenTenantId/oauth2/v2.0/token" -Body $Body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
    } else {
        throw "Azure ARM profile '$Profile' needs certificateSecretName or clientSecretName."
    }

    if (-not $TokenResponse.access_token) {
        throw 'ARM token response did not include access_token.'
    }

    $ExpiresOn = [datetime]::UtcNow.AddSeconds( [math]::Max(60, [int]($TokenResponse.expires_in ?? 3600)) )
    if (-not $script:CIPPAzArmTokenCache) { $script:CIPPAzArmTokenCache = @{} }
    $script:CIPPAzArmTokenCache[$CacheKey] = @{
        AccessToken = [string]$TokenResponse.access_token
        ExpiresOn   = $ExpiresOn
    }

    return [pscustomobject]@{
        AccessToken = [string]$TokenResponse.access_token
        ExpiresOn   = $ExpiresOn
        AppId       = $AppId
        Mode        = [string]$Config.Mode
        Profile     = $Profile
        TenantId    = $TokenTenantId
    }
}
