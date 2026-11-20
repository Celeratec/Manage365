function Invoke-ListAzLocks {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.Read
    .DESCRIPTION
        Lists locks on an allowed resource group.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzLocks" -Request $Request
}
