function Get-CIPPEdiscoveryTenantConfig {
    <#
    .SYNOPSIS
        Loads the per-tenant eDiscovery config from table storage.
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
        $Table = Get-CIPPTable -TableName 'EdiscoveryConfig'
    }
    $SafeTenant = $TenantFilter.Replace("'", "''")
    $Entity = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq '$SafeTenant' and RowKey eq 'config'" | Select-Object -First 1
    if (-not $Entity) { return $null }

    return [pscustomobject]@{
        TenantFilter                  = [string]$Entity.PartitionKey
        AppId                         = [string]$Entity.AppId
        CertificateSecretName         = [string]$Entity.CertificateSecretName
        CertificatePasswordSecretName = [string]$Entity.CertificatePasswordSecretName
        Enabled                       = [bool]$Entity.Enabled
        Notes                         = [string]$Entity.Notes
    }
}