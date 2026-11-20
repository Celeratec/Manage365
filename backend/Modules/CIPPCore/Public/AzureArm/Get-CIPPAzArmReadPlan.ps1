function Get-CIPPAzArmReadPlan {
    <#
    .SYNOPSIS
        Resolves an allowlisted ARM read action into a concrete method/path/api-version plan.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        $Config,

        [hashtable]$Params,

        $Allowlist
    )

    if (-not $Allowlist) {
        $HelperPath = Join-Path $PSScriptRoot '../../Private/Resolve-CIPPGuardedWriteConfigPath.ps1'
        if (Test-Path -LiteralPath $HelperPath) { . $HelperPath }
        $ConfigPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/AzureArmReadAllowlist.json' -PSScriptRoot $PSScriptRoot
        $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }

    if ($null -eq $Allowlist.PSObject.Properties[$Action]) {
        return [pscustomobject]@{ Allowed = $false; Reason = "Action '$Action' is not on the Azure ARM read allowlist." }
    }
    $Entry = $Allowlist.$Action
    if ([string]$Entry.classification -ne 'read') {
        return [pscustomobject]@{ Allowed = $false; Reason = "Action '$Action' is not classified as read." }
    }
    if (-not $Config -or -not $Config.Enabled) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'Azure ARM access is not enabled for this tenant.' }
    }

    if ([string]$Entry.special -eq 'listConfig') {
        return [pscustomobject]@{
            Allowed    = $true
            Action     = $Action
            Special    = 'listConfig'
            Profile    = 'none'
            Role       = [string]$Entry.role
            Method     = 'LOCAL'
        }
    }

    $Sub = [string]$Config.SubscriptionId
    if (-not (Test-CIPPAzArmSegment -Value $Sub -Kind guid)) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'Configured subscriptionId is invalid.' }
    }

    $Rg = $null
    if ($Params -and $Params.ContainsKey('resourceGroupName')) { $Rg = [string]$Params.resourceGroupName }
    elseif ($Params -and $Params.ContainsKey('ResourceGroupName')) { $Rg = [string]$Params.ResourceGroupName }

    if ($Entry.requireResourceGroup -or $Entry.scope -eq 'resourceGroup') {
        if ([string]::IsNullOrWhiteSpace($Rg)) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is required.' }
        }
        if (-not (Test-CIPPAzArmSegment -Value $Rg -Kind resourceGroup)) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is invalid.' }
        }
        $Allowed = @($Config.AllowedResourceGroups)
        if ($Allowed.Count -gt 0 -and $Allowed -notcontains $Rg) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is not in allowedResourceGroups.' }
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($Rg)) {
        if (-not (Test-CIPPAzArmSegment -Value $Rg -Kind resourceGroup)) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is invalid.' }
        }
        $Allowed = @($Config.AllowedResourceGroups)
        if ($Allowed.Count -gt 0 -and $Allowed -notcontains $Rg) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is not in allowedResourceGroups.' }
        }
    }

    $Name = $null
    if ($Params -and $Params.ContainsKey('name')) { $Name = [string]$Params.name }
    elseif ($Params -and $Params.ContainsKey('Name')) { $Name = [string]$Params.Name }
    if (-not [string]::IsNullOrWhiteSpace($Name) -and -not (Test-CIPPAzArmSegment -Value $Name -Kind resourceName)) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'name is invalid.' }
    }

    $Method = [string]$Entry.method
    $ApiVersion = [string]$Entry.apiVersion
    $Path = [string]$Entry.pathTemplate

    if ($Entry.pathTemplateByType) {
        $Type = [string]($Params.type ?? $Params.Type)
        if ([string]::IsNullOrWhiteSpace($Type) -or -not $Entry.pathTemplateByType.PSObject.Properties[$Type]) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'type must be storage, keyvault, or functionapp.' }
        }
        $Path = [string]$Entry.pathTemplateByType.$Type
        $ApiVersion = [string]$Entry.apiVersionByType.$Type
    } elseif (-not [string]::IsNullOrWhiteSpace($Name) -and $Entry.pathTemplateNamed) {
        $Path = [string]$Entry.pathTemplateNamed
    } elseif (-not [string]::IsNullOrWhiteSpace($Rg) -and $Entry.pathTemplateRg) {
        $Path = [string]$Entry.pathTemplateRg
    } elseif (-not [string]::IsNullOrWhiteSpace($Rg) -and $Entry.pathTemplateNamed -and [string]::IsNullOrWhiteSpace($Name) -eq $false) {
        $Path = [string]$Entry.pathTemplateNamed
    }

    if ([string]::IsNullOrWhiteSpace($Path) -and [string]$Entry.special -ne 'accessStatus') {
        # accessStatus still uses pathTemplate
    }
    if ([string]::IsNullOrWhiteSpace($Path) -and [string]$Entry.method -ne 'LOCAL') {
        return [pscustomobject]@{ Allowed = $false; Reason = "No path template for action '$Action'." }
    }

    $Path = $Path.Replace('{subscriptionId}', $Sub)
    if ($Path.Contains('{resourceGroupName}')) {
        if ([string]::IsNullOrWhiteSpace($Rg)) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is required for this path.' }
        }
        $Path = $Path.Replace('{resourceGroupName}', $Rg)
    }
    if ($Path.Contains('{name}')) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'name is required for this path.' }
        }
        $Path = $Path.Replace('{name}', $Name)
    }
    if ($Path -match '\{[^}]+\}') {
        return [pscustomobject]@{ Allowed = $false; Reason = 'Path template still contains unresolved segments.' }
    }
    if ($Path.Contains('..') -or $Path -notmatch '\A/') {
        return [pscustomobject]@{ Allowed = $false; Reason = 'Resolved path is invalid.' }
    }

    $Query = @{}
    if ($Entry.query) {
        foreach ($Prop in $Entry.query.PSObject.Properties) { $Query[$Prop.Name] = [string]$Prop.Value }
    }
    $AlsoPaths = @()
    if ($Entry.alsoPath) {
        $Also = [string]$Entry.alsoPath
        $Also = $Also.Replace('{subscriptionId}', $Sub)
        if ($Also.Contains('{resourceGroupName}')) { $Also = $Also.Replace('{resourceGroupName}', $Rg) }
        $AlsoPaths += $Also
    }

    return [pscustomobject]@{
        Allowed     = $true
        Action      = $Action
        Method      = $Method
        Path        = $Path
        AlsoPaths   = $AlsoPaths
        ApiVersion  = $ApiVersion
        Profile     = [string]$Entry.profile
        Role        = [string]$Entry.role
        Special     = [string]$Entry.special
        Query       = $Query
        MaxRangeDays = $(if ($Entry.maxRangeDays) { [int]$Entry.maxRangeDays } else { $null })
        BodyFromRequest = [bool]$Entry.bodyFromRequest
        AlsoFetch   = [string]$Entry.alsoFetch
        ExpandChildren = @($Entry.expandChildren)
        SubscriptionId = $Sub
        ResourceGroupName = $Rg
    }
}
