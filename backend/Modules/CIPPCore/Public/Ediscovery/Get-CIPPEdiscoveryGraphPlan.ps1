function Get-CIPPEdiscoveryGraphPlan {
    <#
    .SYNOPSIS
        Resolves an allowlisted eDiscovery Graph action into method/path/classification.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [hashtable]$Params,

        $Allowlist
    )

    if (-not $Allowlist) {
        $HelperPath = Join-Path $PSScriptRoot '../../Private/Resolve-CIPPGuardedWriteConfigPath.ps1'
        if (Test-Path -LiteralPath $HelperPath) { . $HelperPath }
        $ConfigPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/EdiscoveryAllowlist.json' -PSScriptRoot $PSScriptRoot
        $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }

    if ($null -eq $Allowlist.PSObject.Properties[$Action]) {
        return [pscustomobject]@{ Allowed = $false; Reason = "Action '$Action' is not on the eDiscovery allowlist." }
    }

    $Entry = $Allowlist.$Action
    $Path = [string]$Entry.pathTemplate
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [pscustomobject]@{ Allowed = $false; Reason = "Action '$Action' has no path template." }
    }

    $GetParam = {
        param($Name)
        if ($Params -and $Params.ContainsKey($Name)) { return [string]$Params[$Name] }
        $Pascal = $Name.Substring(0, 1).ToUpperInvariant() + $Name.Substring(1)
        if ($Params -and $Params.ContainsKey($Pascal)) { return [string]$Params[$Pascal] }
        return $null
    }

    foreach ($Match in [regex]::Matches($Path, '\{(?<name>[^}]+)\}')) {
        $Name = [string]$Match.Groups['name'].Value
        $Value = & $GetParam $Name
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return [pscustomobject]@{ Allowed = $false; Reason = "$Name is required." }
        }
        if ($Name -in @('caseId', 'searchId', 'custodianId', 'operationId')) {
            if ($Value -match '[\x00-\x1F\x7F]' -or $Value.Contains('/') -or $Value.Contains('\') -or $Value.Contains('..') -or $Value.Contains('?') -or $Value.Contains('#') -or $Value -notmatch '\A[a-fA-F0-9\-]{1,64}\z') {
                return [pscustomobject]@{ Allowed = $false; Reason = "$Name is invalid." }
            }
        } else {
            return [pscustomobject]@{ Allowed = $false; Reason = "Unsupported path parameter '$Name'." }
        }
        $Path = $Path.Replace("{$Name}", $Value)
    }

    if ($Path -match '\{[^}]+\}' -or $Path.Contains('..') -or $Path -notmatch '\A/' -or $Path -match '(?i)https?://') {
        return [pscustomobject]@{ Allowed = $false; Reason = 'Resolved path is invalid.' }
    }

    return [pscustomobject]@{
        Allowed                   = $true
        Action                    = $Action
        Method                    = [string]$Entry.method
        Path                      = $Path
        Classification            = [string]$Entry.classification
        Role                      = [string]$Entry.role
        RequiresApprovalReference = [bool]$Entry.requiresApprovalReference
        Reason                    = ''
    }
}
