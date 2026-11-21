function Invoke-ListAzKeyVaults {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.Read
    .DESCRIPTION
        Lists Key Vault config and deleted vaults (never secrets).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzKeyVaults" -Request $Request
}
