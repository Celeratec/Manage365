#!/usr/bin/env pwsh
# Verifies local trust stores reject eMudhra compromise probe hosts and reports TLS issuers
# for Manage365-related endpoints. Read-only; does not modify trust stores.
[CmdletBinding()]
param(
    [string[]]$Hosts = @(
        'manage365.celeratec.cloud',
        'cippbefno.azurewebsites.net',
        'manage36533arg.azurewebsites.net',
        'ghcr.io',
        'login.microsoftonline.com',
        'graph.microsoft.com'
    ),
    [switch]$SkipProbeUrls
)

$ErrorActionPreference = 'Continue'
$ProbeUrls = @(
    'https://dv-g3b-emudhra.we-have-a-problem.com/',
    'https://dv-g3b-aaa-emudhra.we-have-a-problem.com/',
    'https://dv-g3b-noct-emudhra.we-have-a-problem.com/'
)

function Test-TlsIssuer {
    param([string]$HostName)
    $result = [ordered]@{
        Host   = $HostName
        Issuer = $null
        Subject = $null
        Emudhra = $false
        Error  = $null
    }
    try {
        $tcp = [System.Net.Sockets.TcpClient]::new($HostName, 443)
        try {
            $ssl = [System.Net.Security.SslStream]::new($tcp.GetStream(), $false, ({ $true }))
            $ssl.AuthenticateAsClient($HostName)
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
            $result.Subject = $cert.Subject
            $result.Issuer = $cert.Issuer
            $blob = "$($cert.Subject)$($cert.Issuer)"
            if ($blob -match 'emudhra|emsign|emSign') {
                $result.Emudhra = $true
            }
        }
        finally {
            $ssl.Dispose()
            $tcp.Dispose()
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    return [pscustomobject]$result
}

function Invoke-ProbeCurl {
    param([string]$Url, [string]$CaFile)
    $curl = Get-Command curl -ErrorAction SilentlyContinue
    if (-not $curl) {
        return [pscustomobject]@{ Url = $Url; CaFile = $CaFile; HttpCode = $null; Ok = $null; Note = 'curl not found' }
    }
    $args = @('-sS', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', '20')
    if ($CaFile) { $args += @('--cacert', $CaFile) }
    $args += $Url
    $code = & $curl.Source @args 2>&1
    $http = if ($LASTEXITCODE -eq 0) { [int]$code } else { $null }
    $trustedCompromised = ($http -ge 200 -and $http -lt 400)
    [pscustomobject]@{
        Url    = $Url
        CaFile = $(if ($CaFile) { $CaFile } else { '(default)' })
        HttpCode = $http
        Ok     = -not $trustedCompromised
        Note   = if ($trustedCompromised) { 'FAIL: accepts compromised chain' } elseif ($null -eq $http) { 'PASS: TLS rejected' } else { "unexpected http $http" }
    }
}

Write-Host "`n=== Manage365 / dependency TLS issuers ===" -ForegroundColor Cyan
$issuerRows = foreach ($h in $Hosts) { Test-TlsIssuer -HostName $h }
$issuerRows | Format-Table -AutoSize
if ($issuerRows | Where-Object { $_.Emudhra }) {
    Write-Warning 'At least one host presented an eMudhra/emSign issuer chain.'
}

if (-not $SkipProbeUrls) {
    Write-Host "`n=== eMudhra probe URLs (should NOT succeed TLS) ===" -ForegroundColor Cyan
    $caCandidates = @(
        $null,
        (Join-Path $env:HOMEBREW_PREFIX 'etc/ca-certificates/cert.pem'),
        (python3 -c 'import certifi; print(certifi.where())' 2>$null)
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    $probeRows = [System.Collections.Generic.List[object]]::new()
    foreach ($u in $ProbeUrls) {
        $probeRows.Add((Invoke-ProbeCurl -Url $u -CaFile $null))
        foreach ($ca in $caCandidates) {
            $probeRows.Add((Invoke-ProbeCurl -Url $u -CaFile $ca))
        }
    }
    $probeRows | Format-Table -AutoSize
}

Write-Host "`n=== Runtime versions ===" -ForegroundColor Cyan
$versionLines = [System.Collections.Generic.List[string]]::new()
if (Get-Command go -ErrorAction SilentlyContinue) {
    $versionLines.Add((go version))
}
if (Get-Command node -ErrorAction SilentlyContinue) {
    $versionLines.Add("node PATH: $(Get-Command node | Select-Object -ExpandProperty Source)")
    $versionLines.Add((node -v))
}
try {
    $certifiVer = python3 -c 'import certifi; print(certifi.__version__)' 2>$null
    if ($certifiVer) { $versionLines.Add("certifi $certifiVer") }
}
catch { }
if (Get-Command brew -ErrorAction SilentlyContinue) {
    $bc = brew list --versions ca-certificates 2>$null
    if ($bc) { $versionLines.Add("brew $bc") }
}
$versionLines | ForEach-Object { Write-Host $_ }

if (Test-Path '/etc/ssl/cert.pem') {
    $macPem = Select-String -Path '/etc/ssl/cert.pem' -Pattern 'emSign ECC Root CA - G3|AAA Certificate Services' -SimpleMatch -ErrorAction SilentlyContinue
    if ($macPem) {
        Write-Warning '/etc/ssl/cert.pem still lists affected roots (macOS CLI tools may trust compromised chains). See docs/security/emudhra-ca-incident-2026.md'
    }
}

Write-Host "`nDone. Review docs/security/emudhra-ca-incident-2026.md for remediation.`n" -ForegroundColor DarkGray
