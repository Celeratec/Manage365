function Get-CIPPGraphWritePlan {
    <#
    .SYNOPSIS
        Accepts a Graph write only when the method, path, and API version are on the allowlist.
    .DESCRIPTION
        oauth2PermissionGrants accept consentType Principal only. AllPrincipals is refused.
        Anything else returns Allowed false for a 403.
    #>
    [CmdletBinding()]
    param(
        [string]$Method,
        [string]$Path,
        [string]$ApiVersion,
        $Body,
        $Allowlist
    )

    $MethodName = ([string]$Method).ToUpperInvariant()
    $Relative = ([string]$Path).Trim().TrimStart('/')
    $Version = if ([string]::IsNullOrWhiteSpace($ApiVersion)) { 'v1.0' } else { [string]$ApiVersion }
    if ($Version -notin @('v1.0', 'beta')) {
        return [pscustomobject]@{ Allowed = $false; Reason = "ApiVersion '$Version' is not allowed." }
    }
    if (-not $Allowlist) {
        $HelperPath = Join-Path $PSScriptRoot '../../Private/Resolve-CIPPGuardedWriteConfigPath.ps1'
        if (Test-Path -LiteralPath $HelperPath) {
            . $HelperPath
        }
        $ConfigPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/GraphAllowlist.json' -PSScriptRoot $PSScriptRoot
        try {
            $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Failed to load or parse GuardedWrite allowlist from '$ConfigPath': $($_.Exception.Message)"
        }
    }

    $Match = $null
    foreach ($Rule in @($Allowlist)) {
        $Versions = @($Rule.apiVersion)
        if ($Rule.method -eq $MethodName -and $Version -in $Versions -and $Relative -match $Rule.path) {
            $Match = $Rule
            break
        }
    }
    if (-not $Match) {
        return [pscustomobject]@{ Allowed = $false; Reason = "Graph $MethodName $Relative is not on the allowlist." }
    }

    $WriteBody = $Body
    if ($Relative -match '^oauth2PermissionGrants') {
        $Consent = [string]$Body.consentType
        if ([string]::IsNullOrWhiteSpace($Consent)) { $Consent = 'Principal' }
        if ($Consent -ne 'Principal') {
            return [pscustomobject]@{ Allowed = $false; Reason = 'consentType must be Principal.' }
        }
        if ($Body -is [System.Collections.IDictionary]) {
            $WriteBody = @{} + $Body
            $WriteBody.consentType = $Consent
        }
    }

    return [pscustomobject]@{
        Allowed = $true
        Reason  = $null
        Method  = $MethodName
        Uri     = "https://graph.microsoft.com/$Version/$Relative"
        Body    = $WriteBody
    }
}
