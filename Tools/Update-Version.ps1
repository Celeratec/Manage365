<#
.SYNOPSIS
    Bump version tracking files after a Manage365 upstream intake (monorepo edition).

.DESCRIPTION
    Updates the upstream baseline version used by GetVersion / GetCippAlerts out-of-date checks
    and the Manage365 fork release shown in Application Settings.

    Files written:
      frontend/public/version.json           — upstream baseline (dev source; the Docker image
                                                build overwrites out/version.json from the
                                                APP_VERSION build arg, so pass the same value
                                                there when building a release image)
      frontend/package.json                  — upstream baseline
      backend/version_latest.txt             — upstream baseline
      frontend/public/manage365-version.json — Manage365 release + baseline (flows into the
                                                static export untouched)

.PARAMETER UpstreamVersion
    CIPP upstream baseline absorbed (e.g. 10.8.5).

.PARAMETER Manage365Version
    Optional Manage365 fork release (e.g. 5.33.0).

.EXAMPLE
    ./Tools/Update-Version.ps1 -UpstreamVersion 10.8.5 -Manage365Version 5.33.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$UpstreamVersion,

    [string]$Manage365Version
)

Set-Location (Get-Item $PSScriptRoot).Parent.FullName

Set-Content 'backend/version_latest.txt' -Value $UpstreamVersion -NoNewline

$VersionJson = @{ version = $UpstreamVersion } | ConvertTo-Json
Set-Content 'frontend/public/version.json' -Value $VersionJson

$Package = Get-Content frontend/package.json -Raw | ConvertFrom-Json
$Package.version = $UpstreamVersion
$Package | ConvertTo-Json -Depth 10 | Set-Content frontend/package.json

if ($Manage365Version) {
    $Manage365Json = @{
        version          = $Manage365Version
        upstreamBaseline = $UpstreamVersion
    } | ConvertTo-Json
    Set-Content 'frontend/public/manage365-version.json' -Value $Manage365Json
}

Write-Host "Upstream baseline set to $UpstreamVersion"
if ($Manage365Version) {
    Write-Host "Manage365 release set to $Manage365Version"
}
Write-Host "Remember: pass APP_VERSION=$UpstreamVersion when building the container image, then deploy it."
