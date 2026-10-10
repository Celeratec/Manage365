#!/usr/bin/env pwsh
# Exports the Proxyman root CA to build/config/proxyman-ca.pem so the cipp-api dev
# container can trust it (see build/docker-compose-proxyman.yml).
#
# The cipp-api container runs on the distroless Craft image — no shell, no
# update-ca-certificates. Instead of baking the cert into the image, we mount this
# PEM and point OpenSSL (which PowerShell 7 / .NET use for TLS on Linux) at it via
# SSL_CERT_FILE. Re-run this whenever Proxyman regenerates its CA.
#
# Requires Proxyman's CA to be installed/trusted on this machine:
#   macOS   — Proxyman > Certificate > Install Certificate on this Mac (login keychain)
#   Windows — Proxyman > Certificate > Install Certificate on this Windows (Root store)
[CmdletBinding()]
param(
    # Output PEM path. Default lands in build/config/ (gitignored) next to appsettings.
    [string]$OutputPath = (Join-Path $PSScriptRoot '../config/proxyman-ca.pem'),
    # Substring matched against the certificate subject/common name in the trust store.
    [string]$NameMatch = 'Proxyman'
)

$ErrorActionPreference = 'Stop'

# Wrap a DER-encoded cert in a PEM block (works on Windows PowerShell 5.1 and pwsh 7).
function ConvertTo-Pem([byte[]]$der) {
    $b64 = [Convert]::ToBase64String($der, [Base64FormattingOptions]::InsertLineBreaks)
    "-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----"
}

$blocks = [System.Collections.Generic.List[string]]::new()

# $IsMacOS/$IsWindows exist in pwsh 6+. On Windows PowerShell 5.1 they're undefined,
# so fall back to the platform check that treats 5.1 (Desktop edition) as Windows.
$onWindows = if ($null -ne $IsWindows) { $IsWindows } else { $PSVersionTable.PSEdition -eq 'Desktop' -or $env:OS -eq 'Windows_NT' }
$onMac = [bool]$IsMacOS

if ($onMac) {
    # -a: every match (Proxyman names its CA e.g. "Proxyman CA (hostname)"); -p: PEM output.
    $pem = & security find-certificate -a -c $NameMatch -p 2>$null
    if (-not $pem) {
        throw "No certificate matching '$NameMatch' found in the keychain. In Proxyman: Certificate > Install Certificate on this Mac > Install for this device, then re-run."
    }
    $blocks.Add((($pem -join "`n").Trim()))
}
elseif ($onWindows) {
    # Proxyman installs its CA into the Trusted Root store — CurrentUser when installed
    # for the user, LocalMachine when installed for the whole device. Check both.
    $found = @(
        Get-ChildItem 'Cert:\CurrentUser\Root', 'Cert:\LocalMachine\Root' -ErrorAction SilentlyContinue |
            Where-Object { $_.Subject -match $NameMatch }
    ) | Sort-Object Thumbprint -Unique
    if (-not $found) {
        throw "No certificate matching '$NameMatch' found in the Windows Root store. In Proxyman: Certificate > Install Certificate on this Windows, then re-run. (LocalMachine install may require an elevated shell to read.)"
    }
    foreach ($cert in $found) { $blocks.Add((ConvertTo-Pem($cert.Export('Cert')))) }
}
else {
    throw "Unsupported OS. Export the Proxyman root cert as PEM by hand and save it to $OutputPath."
}

# Resolve the output path against the current directory unless it's already absolute
# (leading / on Unix, or a drive letter / UNC on Windows).
$resolved = if ($OutputPath -match '^(/|\\\\|[A-Za-z]:)') { $OutputPath } else { [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath)) }
$dir = Split-Path -Parent $resolved
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# One PEM block per cert; join with LF (not CRLF) so the file is valid for OpenSSL
# regardless of the host OS, and Set-Content -NoNewline avoids a trailing CRLF on Windows.
$out = (($blocks -join "`n").Trim()) + "`n"
$out = $out -replace "`r`n", "`n"
Set-Content -Path $resolved -Value $out -NoNewline -Encoding ascii

$count = ([regex]::Matches($out, 'BEGIN CERTIFICATE')).Count
Write-Host "Wrote $count certificate block(s) to $resolved" -ForegroundColor Green

# ── Combined trust bundle ─────────────────────────────────────────────────────
# The cipp-api container runs the distroless Craft image and reaches Microsoft over
# TLS the system proxy (Proxyman) re-signs, so it must trust Proxyman's CA. The
# overlay bind-mounts a bundle OVER the image's own root store — a single file, so
# it must contain the image's 217 real roots too, or every non-intercepted host
# breaks. We pull those roots straight out of the image (exact match to the runtime)
# and append Proxyman. Needs Docker; if it's unavailable we skip the bundle and the
# launcher simply won't enable interception (safe, un-proxied stack).
$bundlePath = Join-Path $dir 'proxyman-ca-bundle.pem'
$imageRootsPath = '/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem'  # Azure Linux/Mariner
$image = $env:CRAFT_DEV_IMAGE; if (-not $image) { $image = 'ghcr.io/cyberdrain/craft:dev' }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Warning "Docker not found — skipping combined bundle. Interception stays OFF until you re-run this with Docker available."
    return
}

$baseRoots = Join-Path ([System.IO.Path]::GetTempPath()) 'craft-tls-ca-bundle.pem'
# Prefer the running cipp-api (guaranteed same image); else spin a throwaway container.
$srcContainer = (& docker ps --filter 'name=cipp-api' --format '{{.Names}}' 2>$null | Select-Object -First 1)
$tmpContainer = $null
try {
    if (-not $srcContainer) {
        $tmpContainer = 'cipp-catrust-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
        & docker create --name $tmpContainer $image | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not create a container from $image to read its root store." }
        $srcContainer = $tmpContainer
    }
    & docker cp "${srcContainer}:${imageRootsPath}" $baseRoots | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $baseRoots)) { throw "Could not copy $imageRootsPath out of $srcContainer." }
}
finally {
    if ($tmpContainer) { & docker rm -f $tmpContainer 2>$null | Out-Null }
}

$roots = (Get-Content -Raw $baseRoots) -replace "`r`n", "`n"
$bundle = ($roots.TrimEnd() + "`n" + $out.TrimEnd() + "`n") -replace "`r`n", "`n"
Set-Content -Path $bundlePath -Value $bundle -NoNewline -Encoding ascii
Remove-Item $baseRoots -ErrorAction SilentlyContinue

$bundleCount = ([regex]::Matches($bundle, 'BEGIN CERTIFICATE')).Count
Write-Host "Wrote combined trust bundle ($bundleCount certs = image roots + Proxyman) to $bundlePath" -ForegroundColor Green

# ── build/.env: activate the optional mounts baked into the compose files ──────
# The compose files carry optional CA mounts that default to a /dev/null no-op; they
# turn on only when these vars are set. Docker Compose auto-loads build/.env for
# interpolation (project dir = the compose file's folder), so a plain `docker compose
# up` — or a `docker restart` of an already-created container — keeps Proxyman trust
# without any -f overlay to remember. Deleting build/.env (or the bundle) disables it.
$envPath = Join-Path $dir '.env'
$envLines = @(
    '# Machine-local — written by Export-ProxymanCert.ps1. Activates the optional Proxyman'
    '# CA mounts in docker-compose-all.yml / docker-compose-no-frontend.yml. Gitignored.'
    'CIPP_API_CA_MOUNT=./config/proxyman-ca-bundle.pem:/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem:ro'
    'CIPP_NODE_CA_MOUNT=./config/proxyman-ca-bundle.pem:/certs/proxyman-ca-bundle.pem:ro'
    'CIPP_NODE_CA=/certs/proxyman-ca-bundle.pem'
)
# Preserve any unrelated vars already in build/.env; only manage our three keys.
$managed = 'CIPP_API_CA_MOUNT', 'CIPP_NODE_CA_MOUNT', 'CIPP_NODE_CA'
if (Test-Path $envPath) {
    $kept = Get-Content $envPath | Where-Object {
        $line = $_
        -not ($managed | Where-Object { $line -match "^\s*$_\s*=" }) -and $line -notmatch '^# Machine-local — written by Export-ProxymanCert'
    }
    $envLines = @($kept) + $envLines
}
Set-Content -Path $envPath -Value (($envLines -join "`n") + "`n") -NoNewline -Encoding ascii
Write-Host "Activated Proxyman trust in $envPath (survives plain 'docker compose up' / restart)" -ForegroundColor Green

Write-Host "Apply by (re)creating the stack — e.g.:" -ForegroundColor Cyan
if ($onWindows) {
    Write-Host "  build/tools/Start-Cipp-Dev-Windows-docker.ps1"
} else {
    Write-Host "  ./cipp-dev-switch.sh main    # or: build/tools/Start-CippDev.sh"
}
Write-Host "Note: traffic already routes through Proxyman via the system proxy — this only adds trust." -ForegroundColor DarkGray
Write-Host "To disable: delete build/.env (or build/config/proxyman-ca-bundle.pem) and recreate the stack." -ForegroundColor DarkGray
