function Set-CIPPEdiscoveryTenantConfig {
    <#
    .SYNOPSIS
        Upserts per-tenant eDiscovery config. Stores Key Vault credential references only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantFilter,

        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter(Mandatory)]
        [string]$CertificateSecretName,

        [string]$CertificatePasswordSecretName,

        [bool]$Enabled = $true,

        [string]$Notes,

        [hashtable]$Table
    )

    if ($AppId -notmatch '\A[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\z') {
        throw 'AppId must be a GUID.'
    }
    $Sam = [string]$env:ApplicationID
    if (-not [string]::IsNullOrWhiteSpace($Sam) -and $AppId -eq $Sam) {
        throw 'The CIPP SAM application identity cannot be used for eDiscovery.'
    }
    if ([string]::IsNullOrWhiteSpace($CertificateSecretName)) {
        throw 'CertificateSecretName (Key Vault secret name) is required.'
    }
    if ($CertificateSecretName -match '(?i)-----BEGIN|private.?key|\.pfx') {
        throw 'CertificateSecretName must be a Key Vault secret name, not certificate material.'
    }
    if (-not $Table) {
        $Table = Get-CIPPTable -TableName 'EdiscoveryConfig'
    }

    $Entity = @{
        PartitionKey                  = $TenantFilter
        RowKey                        = 'config'
        AppId                         = $AppId
        CertificateSecretName         = $CertificateSecretName
        CertificatePasswordSecretName = [string]$CertificatePasswordSecretName
        Enabled                       = $Enabled
        Notes                         = [string]$Notes
    }
    Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
    return Get-CIPPEdiscoveryTenantConfig -TenantFilter $TenantFilter -Table $Table
}