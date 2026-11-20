function Set-CIPPAzArmTenantConfig {
    <#
    .SYNOPSIS
        Upserts per-tenant Azure ARM access config. Stores credential references only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantFilter,

        [Parameter(Mandatory)]
        [ValidateSet('lighthouse', 'servicePrincipal')]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [string[]]$AllowedResourceGroups = @(),

        [Parameter(Mandatory)]
        [hashtable]$Profiles,

        [bool]$Enabled = $true,

        $ChangeWindow,

        [string]$Notes,

        [string]$ManagingTenantId,

        [hashtable]$Table
    )

    if ($SubscriptionId -notmatch '\A[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\z') {
        throw 'SubscriptionId must be a GUID.'
    }
    if ($Mode -eq 'lighthouse' -and [string]::IsNullOrWhiteSpace($ManagingTenantId)) {
        throw 'ManagingTenantId is required for lighthouse mode.'
    }
    foreach ($Rg in @($AllowedResourceGroups)) {
        if ($Rg -notmatch '\A[A-Za-z0-9_\-\.\(\)]{1,90}\z' -or $Rg -match '\.\.') {
            throw "Invalid resource group name '$Rg'."
        }
    }

    if (-not $Table) {
        $Table = Get-CIPPTable -TableName 'AzureArmConfig'
    }

    $Entity = @{
        PartitionKey          = $TenantFilter
        RowKey                = 'config'
        Mode                  = $Mode
        SubscriptionId        = $SubscriptionId
        AllowedResourceGroups = [string](@($AllowedResourceGroups) | ConvertTo-Json -Compress)
        ProfilesJson          = [string]($Profiles | ConvertTo-Json -Depth 6 -Compress)
        Enabled               = $Enabled
        Notes                 = [string]$Notes
        ManagingTenantId      = [string]$ManagingTenantId
    }
    if ($null -ne $ChangeWindow) {
        $Entity.ChangeWindowJson = [string]($ChangeWindow | ConvertTo-Json -Compress)
    }
    Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
    return Get-CIPPAzArmTenantConfig -TenantFilter $TenantFilter -Table $Table
}
