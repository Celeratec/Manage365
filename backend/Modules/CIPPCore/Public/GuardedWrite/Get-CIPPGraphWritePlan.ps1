function Get-CIPPGraphWritePlan {
    <#
    .SYNOPSIS
        Accepts a Graph write only when the method, path, and API version are on the allowlist.
    .DESCRIPTION
        oauth2PermissionGrants default to consentType Principal. AllPrincipals is refused unless
        the caller holds the elevated role. Anything else returns Allowed false for a 403.
    #>
    [CmdletBinding()]
    param(
        [string]$Method,
        [string]$Path,
        [string]$ApiVersion,
        $Body,
        [switch]$AllowAllPrincipals,
        $Allowlist
    )

    $MethodName = ([string]$Method).ToUpperInvariant()
    $Relative = ([string]$Path).Trim().TrimStart('/')
    $Version = if ([string]::IsNullOrWhiteSpace($ApiVersion)) { 'v1.0' } else { [string]$ApiVersion }
    if ($Version -notin @('v1.0', 'beta')) {
        return [pscustomobject]@{ Allowed = $false; Reason = "ApiVersion '$Version' is not allowed." }
    }
    if (-not $Allowlist) {
        $ConfigPath = Join-Path $PSScriptRoot '../../../../Config/GuardedWrites/GraphAllowlist.json'
        $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
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
        if ($Consent -eq 'AllPrincipals' -and -not $AllowAllPrincipals) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'AllPrincipals grants require Tenant.AppGovernance.AllPrincipals.' }
        }
        if ($Consent -notin @('Principal', 'AllPrincipals')) {
            return [pscustomobject]@{ Allowed = $false; Reason = "consentType '$Consent' is not allowed." }
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
