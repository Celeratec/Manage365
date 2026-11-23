function Get-CIPPEdiscoveryAccessToken {
    <#
    .SYNOPSIS
        Returns a dedicated per-tenant Microsoft Graph token for eDiscovery.
    .DESCRIPTION
        Uses a Key Vault certificate reference from EdiscoveryConfig and refuses the
        CIPP SAM application identity. The access token is returned only to callers
        and must never be logged.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Wraps Key Vault PFX password for X509Certificate2; value is not persisted as plaintext')]
    param(
        [Parameter(Mandatory)]
        [string]$TenantFilter,

        $Config
    )

    if (-not $Config) {
        $Config = Get-CIPPEdiscoveryTenantConfig -TenantFilter $TenantFilter
    }
    if (-not $Config -or -not $Config.Enabled) {
        throw 'eDiscovery access is not configured or not enabled for this tenant.'
    }

    $AppId = [string]($Config.AppId ?? $Config.appId)
    if ([string]::IsNullOrWhiteSpace($AppId)) {
        throw 'eDiscovery config is missing AppId.'
    }
    # Hosting environments have used both ApplicationID and ApplicationId casing.
    $SamAppIds = @($env:ApplicationID, $env:ApplicationId, $env:APPSETTING_ApplicationID, $env:APPSETTING_ApplicationId) |
        ForEach-Object { [string]$_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
    if (@($SamAppIds | Where-Object { $AppId -eq $_ }).Count -gt 0) {
        throw 'The CIPP SAM application identity cannot be used for eDiscovery.'
    }

    $TokenTenantId = $null
    try {
        $TenantRow = Get-Tenants -TenantFilter $TenantFilter | Select-Object -First 1
        $TokenTenantId = [string]($TenantRow.customerId ?? $TenantRow.CustomerId ?? $TenantRow.tenantId ?? $TenantRow.TenantId)
    } catch {
    }
    if ([string]::IsNullOrWhiteSpace($TokenTenantId)) {
        $TokenTenantId = [string]($Config.TenantId ?? $Config.tenantId)
    }
    if ([string]::IsNullOrWhiteSpace($TokenTenantId)) {
        throw 'Could not resolve client tenant id for eDiscovery.'
    }

    $Scope = 'https://graph.microsoft.com/.default'
    $CacheKey = "$TenantFilter|$AppId|$TokenTenantId"
    if ($script:CIPPEdiscoveryTokenCache -and $script:CIPPEdiscoveryTokenCache[$CacheKey]) {
        $Cached = $script:CIPPEdiscoveryTokenCache[$CacheKey]
        if ($Cached.ExpiresOn -and [datetime]::UtcNow -lt $Cached.ExpiresOn.AddMinutes(-2)) {
            return [pscustomobject]@{
                AccessToken = $Cached.AccessToken
                ExpiresOn   = $Cached.ExpiresOn
                AppId       = $AppId
                TenantId    = $TokenTenantId
            }
        }
    }

    $CertName = [string]($Config.CertificateSecretName ?? $Config.certificateSecretName)
    if ([string]::IsNullOrWhiteSpace($CertName)) {
        throw 'eDiscovery config is missing CertificateSecretName.'
    }

    $CertPfxBase64 = Get-CippKeyVaultSecret -Name $CertName -AsPlainText
    if ([string]::IsNullOrWhiteSpace($CertPfxBase64)) {
        throw "Certificate secret '$CertName' is empty."
    }

    $CertPassword = $null
    $PwdName = [string]($Config.CertificatePasswordSecretName ?? $Config.certificatePasswordSecretName)
    if (-not [string]::IsNullOrWhiteSpace($PwdName)) {
        $CertPassword = Get-CippKeyVaultSecret -Name $PwdName -AsPlainText
    }

    $Certificate = $null
    $SecurePwd = $null
    try {
        $CertBytes = [Convert]::FromBase64String($CertPfxBase64)
        $Flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        $SecurePwd = if ($CertPassword) { ConvertTo-SecureString $CertPassword -AsPlainText -Force } else { $null }
        try {
            $Certificate = if ($SecurePwd) {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertBytes, $SecurePwd, $Flags)
            } else {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertBytes, '', $Flags)
            }
        } catch [System.PlatformNotSupportedException] {
            $Certificate = if ($SecurePwd) {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertBytes, $SecurePwd)
            } else {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertBytes, '')
            }
        }
    } catch {
        throw "Certificate secret '$CertName' must contain a base64 PFX certificate."
    }

    try {
        $TokenResponse = Get-GraphTokenFromCert -TenantId $TokenTenantId -AppId $AppId -Certificate $Certificate -Scope $Scope -SkipCache
        if (-not $TokenResponse.access_token) {
            throw 'eDiscovery token response did not include access_token.'
        }

        $ExpiresOn = if ($TokenResponse.expires_on) {
            [DateTimeOffset]::FromUnixTimeSeconds([int64]$TokenResponse.expires_on).UtcDateTime
        } else {
            [datetime]::UtcNow.AddSeconds([math]::Max(60, [int]($TokenResponse.expires_in ?? 3600)))
        }
        if (-not $script:CIPPEdiscoveryTokenCache) { $script:CIPPEdiscoveryTokenCache = @{} }
        $script:CIPPEdiscoveryTokenCache[$CacheKey] = @{
            AccessToken = [string]$TokenResponse.access_token
            ExpiresOn   = $ExpiresOn
        }

        return [pscustomobject]@{
            AccessToken = [string]$TokenResponse.access_token
            ExpiresOn   = $ExpiresOn
            AppId       = $AppId
            TenantId    = $TokenTenantId
        }
    } finally {
        if ($Certificate) { $Certificate.Dispose() }
        if ($SecurePwd) { $SecurePwd.Dispose() }
    }
}
