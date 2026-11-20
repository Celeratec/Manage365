function Get-CIPPAzArmTenantConfig {
    <#
    .SYNOPSIS
        Loads the per-tenant Azure ARM access config from table storage.
    .DESCRIPTION
        PartitionKey = tenantFilter, RowKey = config. Credential fields are Key Vault
        secret or certificate *names* only. Returns $null when no row exists.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantFilter,

        [hashtable]$Table
    )

    if (-not $Table) {
        $Table = Get-CIPPTable -TableName 'AzureArmConfig'
    }
    $Entity = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq '$($TenantFilter.Replace("'","''"))' and RowKey eq 'config'" | Select-Object -First 1
    if (-not $Entity) { return $null }

    $AllowedRgs = @()
    if ($Entity.AllowedResourceGroups) {
        try { $AllowedRgs = @($Entity.AllowedResourceGroups | ConvertFrom-Json -ErrorAction Stop) } catch { $AllowedRgs = @() }
    }
    $Profiles = @{}
    if ($Entity.ProfilesJson) {
        try { $Profiles = $Entity.ProfilesJson | ConvertFrom-Json -AsHashtable -ErrorAction Stop } catch { $Profiles = @{} }
    }
    $ChangeWindow = $null
    if ($Entity.ChangeWindowJson) {
        try { $ChangeWindow = $Entity.ChangeWindowJson | ConvertFrom-Json -ErrorAction Stop } catch { $ChangeWindow = $null }
    }

    return [pscustomobject]@{
        TenantFilter          = [string]$Entity.PartitionKey
        Mode                  = [string]$Entity.Mode
        SubscriptionId        = [string]$Entity.SubscriptionId
        AllowedResourceGroups = $AllowedRgs
        Profiles              = $Profiles
        Enabled               = [bool]$Entity.Enabled
        ChangeWindow          = $ChangeWindow
        Notes                 = [string]$Entity.Notes
        ManagingTenantId      = [string]$Entity.ManagingTenantId
    }
}
