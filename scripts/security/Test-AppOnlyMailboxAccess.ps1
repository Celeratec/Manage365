#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Prove an app-only Graph Mail.Read grant is scoped: 200 for in-scope mailboxes, 403 for out-of-scope.

.DESCRIPTION
    Operator-box script for #3281675 PR6 (open question 1 = A). Builds an RS256 client assertion
    from a local certificate, requests a Graph app-only token, and issues GET-only
    /users/{mailbox}/messages?$top=1&$select=id probes. Never prints tokens, assertions, keys,
    passphrases, message ids, subjects, or bodies — status codes and counts only.

    Manage365 never holds the private key; do not turn this into an HTTP endpoint.

.PARAMETER TenantId
    Target Entra tenant GUID (required; no default).

.PARAMETER ClientId
    Application (client) id of the probe app (required; no default).

.PARAMETER CertificatePath
    Path to a PFX or PEM certificate file that includes the private key.

.PARAMETER CertificateThumbprint
    Thumbprint of a cert already in the local certificate store (CurrentUser\My then LocalMachine\My).

.PARAMETER CertificatePassword
    SecureString passphrase for a PFX. If omitted and the PFX needs one, you are prompted.
    Never pass a plaintext password on the command line.

.PARAMETER InScopeMailbox
    One or more mailboxes that must return HTTP 200.

.PARAMETER OutOfScopeMailbox
    One or more mailboxes that must return HTTP 403.

.PARAMETER WaitForPropagation
    On 403 for an in-scope mailbox, retry every RetryDelaySeconds up to MaxWaitSeconds
    (default 10 minutes / 2 hours) — Microsoft often takes 30 minutes to 2 hours.

.PARAMETER RetryDelaySeconds
    Delay between propagation retries (default 600). Tests may lower this.

.PARAMETER MaxWaitSeconds
    Max wait for in-scope 403→200 (default 7200).

.PARAMETER HttpTransport
    Optional scriptblock for tests: param($Method, $Uri, $Headers, $Body) → response object
    with StatusCode and optional Content/Body. Production uses Invoke-RestMethod / WebRequest.

.PARAMETER Certificate
    Optional X509Certificate2 (tests). Bypasses path/thumbprint load.

.PARAMETER PassThru
    Return the result object instead of exiting (for Pester).
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory)]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [string]$ClientId,

    [Parameter(ParameterSetName = 'Path')]
    [string]$CertificatePath,

    [Parameter(ParameterSetName = 'Thumbprint')]
    [string]$CertificateThumbprint,

    [securestring]$CertificatePassword,

    [Parameter(Mandatory)]
    [string[]]$InScopeMailbox,

    [Parameter(Mandatory)]
    [string[]]$OutOfScopeMailbox,

    [switch]$WaitForPropagation,

    [int]$RetryDelaySeconds = 600,

    [int]$MaxWaitSeconds = 7200,

    [scriptblock]$HttpTransport,

    [Parameter(ParameterSetName = 'Injected')]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-AppOnlyMailboxAddress {
    param([Parameter(Mandatory)][string]$Mailbox)
    if ([string]::IsNullOrWhiteSpace($Mailbox)) {
        throw 'Mailbox value is empty.'
    }
    if ($Mailbox -match '[/?#%]|\.\.') {
        throw "Mailbox value is malformed (illegal characters): refused."
    }
    # UPN/SMTP-ish or GUID
    if ($Mailbox -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
        return
    }
    if ($Mailbox -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        throw "Mailbox value is malformed (expected UPN/SMTP or GUID): refused."
    }
}

function ConvertTo-Base64Url {
    param([byte[]]$Bytes)
    $b64 = [Convert]::ToBase64String($Bytes)
    return ($b64.TrimEnd('=') -replace '\+', '-' -replace '/', '_')
}

function ConvertTo-Base64UrlString {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return ConvertTo-Base64Url -Bytes $bytes
}

function Get-AppOnlyProbeCertificate {
    param(
        [string]$Path,
        [string]$Thumbprint,
        [securestring]$Password,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Injected
    )
    if ($Injected) {
        if (-not $Injected.HasPrivateKey) {
            throw 'Injected certificate has no private key.'
        }
        return $Injected
    }
    if ($Path) {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "CertificatePath not found: refused."
        }
        # Prefer EphemeralKeySet when the platform supports it; fall back for macOS/etc.
        $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
        try {
            $flags = $flags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
        } catch {
            # enum value missing on older runtimes — ignore
        }
        try {
            if ($Password) {
                return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path, $Password, $flags)
            }
            return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path, '', $flags)
        } catch {
            if ("$($_.Exception.Message)" -match 'EphemeralKeySet') {
                $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
                if ($Password) {
                    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path, $Password, $flags)
                }
                try {
                    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path, '', $flags)
                } catch {
                    if ($Password) { throw 'Failed to load certificate with the provided passphrase.' }
                    $Prompted = Read-Host -AsSecureString -Prompt 'Certificate passphrase'
                    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path, $Prompted, $flags)
                }
            }
            if ($Password) { throw 'Failed to load certificate with the provided passphrase.' }
            $Prompted = Read-Host -AsSecureString -Prompt 'Certificate passphrase'
            return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path, $Prompted, $flags)
        }
    }
    if ($Thumbprint) {
        $normalized = ($Thumbprint -replace '\s', '').ToUpperInvariant()
        foreach ($StorePath in @('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My')) {
            $found = Get-ChildItem -Path $StorePath -ErrorAction SilentlyContinue |
                Where-Object { $_.Thumbprint -eq $normalized } |
                Select-Object -First 1
            if ($found) {
                if (-not $found.HasPrivateKey) {
                    throw 'Certificate in store has no private key.'
                }
                return $found
            }
        }
        throw 'CertificateThumbprint not found in CurrentUser or LocalMachine My stores.'
    }
    throw 'Provide CertificatePath, CertificateThumbprint, or Certificate.'
}

function New-AppOnlyClientAssertion {
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
    )
    $now = [DateTimeOffset]::UtcNow
    $header = @{
        alg = 'RS256'
        typ = 'JWT'
        x5t = (ConvertTo-Base64Url -Bytes $Cert.GetCertHash())
    } | ConvertTo-Json -Compress
    $payload = @{
        aud = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        iss = $ClientId
        sub = $ClientId
        jti = [guid]::NewGuid().ToString()
        nbf = $now.ToUnixTimeSeconds()
        exp = $now.AddMinutes(10).ToUnixTimeSeconds()
    } | ConvertTo-Json -Compress

    $headerPart = ConvertTo-Base64UrlString -Text $header
    $payloadPart = ConvertTo-Base64UrlString -Text $payload
    $toSign = [System.Text.Encoding]::ASCII.GetBytes("$headerPart.$payloadPart")

    $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Cert)
    if (-not $rsa) {
        throw 'Certificate private key is not available for RS256 signing.'
    }
    $signature = $rsa.SignData($toSign, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    return "$headerPart.$payloadPart.$(ConvertTo-Base64Url -Bytes $signature)"
}

function Invoke-AppOnlyHttp {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers,
        $Body,
        [scriptblock]$Transport
    )
    $parsed = [uri]$Uri
    $hostOk = $parsed.Host -in @('login.microsoftonline.com', 'graph.microsoft.com')
    if (-not $hostOk) {
        throw "Refused: host '$($parsed.Host)' is not allowlisted."
    }
    if ($Method -eq 'GET' -and $parsed.Host -eq 'graph.microsoft.com') {
        if ($Uri -notmatch '/v1\.0/users/[^/]+/messages\?') {
            throw 'Refused: Graph path is not the fixed mailbox messages probe template.'
        }
        if ($Method -ne 'GET') {
            throw 'Refused: only GET is allowed for Graph probes.'
        }
    }
    if ($Transport) {
        return & $Transport -Method $Method -Uri $Uri -Headers $Headers -Body $Body
    }
    if ($Method -eq 'POST') {
        try {
            $resp = Invoke-WebRequest -Method POST -Uri $Uri -Headers $Headers -Body $Body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
            return [pscustomobject]@{
                StatusCode = [int]$resp.StatusCode
                Content    = $resp.Content
            }
        } catch {
            $ex = $_.Exception
            $code = $null
            $content = $null
            if ($ex.Response) {
                $code = [int]$ex.Response.StatusCode
                $reader = [System.IO.StreamReader]::new($ex.Response.GetResponseStream())
                $content = $reader.ReadToEnd()
                $reader.Dispose()
            }
            return [pscustomobject]@{ StatusCode = $code; Content = $content; Error = 'token request failed' }
        }
    }
    try {
        $resp = Invoke-WebRequest -Method GET -Uri $Uri -Headers $Headers -UseBasicParsing
        $count = 0
        try {
            $json = $resp.Content | ConvertFrom-Json
            if ($json.value) { $count = @($json.value).Count }
        } catch {
            $count = 0
        }
        return [pscustomobject]@{
            StatusCode = [int]$resp.StatusCode
            ItemCount  = $count
        }
    } catch {
        $code = $null
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
        } elseif ("$($_.Exception.Message)" -match '\b(401|403|404)\b') {
            $code = [int]$Matches[1]
        }
        return [pscustomobject]@{
            StatusCode = $code
            ItemCount  = 0
            Error      = 'graph probe failed'
        }
    }
}

function Get-SafeJwtClaimsSummary {
    param([string]$AccessToken)
    # Decode payload only for roles presence; never return raw token.
    $parts = $AccessToken -split '\.'
    if ($parts.Count -lt 2) {
        return [pscustomobject]@{ HasRolesClaim = $false; Note = 'token payload not JWT-shaped' }
    }
    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    switch ($payload.Length % 4) {
        0 { }
        2 { $payload += '==' }
        3 { $payload += '=' }
        default { return [pscustomobject]@{ HasRolesClaim = $false; Note = 'could not decode token claims' } }
    }
    try {
        $jsonText = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
        $json = $jsonText | ConvertFrom-Json
        $hasRoles = ($null -ne $json.PSObject.Properties['roles']) -and ($null -ne $json.roles)
        return [pscustomobject]@{
            HasRolesClaim = [bool]$hasRoles
            Note          = if ($hasRoles) { 'roles claim present (unexpected for Exchange-RBAC-only app)' } else { 'roles claim absent (expected for Exchange-RBAC-only app)' }
        }
    } catch {
        return [pscustomobject]@{ HasRolesClaim = $false; Note = 'could not decode token claims' }
    }
}

function Invoke-CIPPAppOnlyMailboxAccessProbe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [string]$CertificatePath,
        [string]$CertificateThumbprint,
        [securestring]$CertificatePassword,
        [Parameter(Mandatory)][string[]]$InScopeMailbox,
        [Parameter(Mandatory)][string[]]$OutOfScopeMailbox,
        [switch]$WaitForPropagation,
        [int]$RetryDelaySeconds = 600,
        [int]$MaxWaitSeconds = 7200,
        [scriptblock]$HttpTransport,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    if ($TenantId -notmatch '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
        throw 'TenantId must be a GUID.'
    }
    if ($ClientId -notmatch '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
        throw 'ClientId must be a GUID.'
    }
    if ($RetryDelaySeconds -lt 1) { throw 'RetryDelaySeconds must be >= 1.' }
    if ($MaxWaitSeconds -lt 1) { throw 'MaxWaitSeconds must be >= 1.' }

    foreach ($m in @($InScopeMailbox) + @($OutOfScopeMailbox)) {
        Test-AppOnlyMailboxAddress -Mailbox $m
    }

    $cert = Get-AppOnlyProbeCertificate -Path $CertificatePath -Thumbprint $CertificateThumbprint -Password $CertificatePassword -Injected $Certificate
    $assertion = New-AppOnlyClientAssertion -TenantId $TenantId -ClientId $ClientId -Cert $cert

    $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $form = "client_id=$([uri]::EscapeDataString($ClientId))" +
        '&scope=https%3A%2F%2Fgraph.microsoft.com%2F.default' +
        '&grant_type=client_credentials' +
        "&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer" +
        "&client_assertion=$([uri]::EscapeDataString($assertion))"

    $tokenResp = Invoke-AppOnlyHttp -Method POST -Uri $tokenUri -Headers @{} -Body $form -Transport $HttpTransport
    if ([int]$tokenResp.StatusCode -ne 200) {
        Write-Host "Token request failed with status $($tokenResp.StatusCode)." -ForegroundColor Red
        return [pscustomobject]@{
            Success     = $false
            ExitCode    = 2
            Claims      = $null
            Probes      = @()
            Mismatch    = @('token request failed')
        }
    }
    $tokenJson = $tokenResp.Content | ConvertFrom-Json
    $accessToken = [string]$tokenJson.access_token
    if ([string]::IsNullOrWhiteSpace($accessToken)) {
        Write-Host 'Token response missing access_token.' -ForegroundColor Red
        return [pscustomobject]@{ Success = $false; ExitCode = 2; Claims = $null; Probes = @(); Mismatch = @('missing access_token') }
    }

    $claims = Get-SafeJwtClaimsSummary -AccessToken $accessToken
    Write-Host "Token claims: $($claims.Note)" -ForegroundColor Cyan

    $authHeaders = @{ Authorization = 'Bearer [redacted-in-logs]' }
    # Real header for transport; scrubbed from any Write-Host of headers
    $realHeaders = @{ Authorization = "Bearer $accessToken" }

    function Get-ProbeUri {
        param([string]$Mailbox)
        $encoded = [uri]::EscapeDataString($Mailbox)
        return "https://graph.microsoft.com/v1.0/users/$encoded/messages?`$top=1&`$select=id"
    }

    function Invoke-OneProbe {
        param([string]$Mailbox, [int]$ExpectedStatus)
        $uri = Get-ProbeUri -Mailbox $Mailbox
        $resp = Invoke-AppOnlyHttp -Method GET -Uri $uri -Headers $realHeaders -Transport $HttpTransport
        $code = [int]$resp.StatusCode
        $count = if ($null -ne $resp.ItemCount) { [int]$resp.ItemCount } else { 0 }
        [pscustomobject]@{
            Mailbox        = $Mailbox
            StatusCode     = $code
            ItemCount      = $count
            ExpectedStatus = $ExpectedStatus
            Ok             = ($code -eq $ExpectedStatus)
        }
    }

    $probes = [System.Collections.Generic.List[object]]::new()
    $mismatches = [System.Collections.Generic.List[string]]::new()
    $deadline = [datetime]::UtcNow.AddSeconds($MaxWaitSeconds)

    foreach ($mbx in @($InScopeMailbox)) {
        $attempt = 0
        while ($true) {
            $attempt++
            $row = Invoke-OneProbe -Mailbox $mbx -ExpectedStatus 200
            if ($row.Ok) {
                $probes.Add($row)
                Write-Host "In-scope $mbx → $($row.StatusCode) (count=$($row.ItemCount))" -ForegroundColor Green
                break
            }
            if ($WaitForPropagation -and $row.StatusCode -eq 403 -and [datetime]::UtcNow -lt $deadline) {
                Write-Host "In-scope $mbx → 403 (propagation wait attempt $attempt)..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelaySeconds
                continue
            }
            $probes.Add($row)
            Write-Host "In-scope $mbx → $($row.StatusCode) (expected 200)" -ForegroundColor Red
            $mismatches.Add("in-scope $mbx expected 200 got $($row.StatusCode)")
            break
        }
    }

    foreach ($mbx in @($OutOfScopeMailbox)) {
        $row = Invoke-OneProbe -Mailbox $mbx -ExpectedStatus 403
        $probes.Add($row)
        if ($row.Ok) {
            Write-Host "Out-of-scope $mbx → $($row.StatusCode) (count=$($row.ItemCount))" -ForegroundColor Green
        } else {
            Write-Host "Out-of-scope $mbx → $($row.StatusCode) (expected 403)" -ForegroundColor Red
            $mismatches.Add("out-of-scope $mbx expected 403 got $($row.StatusCode)")
        }
    }

    # Silence unused (keeps analyzer happy if StrictMode + redacted header object)
    $null = $authHeaders

    $success = ($mismatches.Count -eq 0)
    return [pscustomobject]@{
        Success  = $success
        ExitCode = if ($success) { 0 } else { 1 }
        Claims   = $claims
        Probes   = @($probes)
        Mismatch = @($mismatches)
    }
}

$result = Invoke-CIPPAppOnlyMailboxAccessProbe `
    -TenantId $TenantId `
    -ClientId $ClientId `
    -CertificatePath $CertificatePath `
    -CertificateThumbprint $CertificateThumbprint `
    -CertificatePassword $CertificatePassword `
    -InScopeMailbox $InScopeMailbox `
    -OutOfScopeMailbox $OutOfScopeMailbox `
    -WaitForPropagation:$WaitForPropagation `
    -RetryDelaySeconds $RetryDelaySeconds `
    -MaxWaitSeconds $MaxWaitSeconds `
    -HttpTransport $HttpTransport `
    -Certificate $Certificate

if ($PassThru) {
    return $result
}

exit $result.ExitCode
