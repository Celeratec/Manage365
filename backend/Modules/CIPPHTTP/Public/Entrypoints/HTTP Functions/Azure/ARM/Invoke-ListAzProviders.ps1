function Invoke-ListAzProviders {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.Read
    .DESCRIPTION
        Lists resource providers for the pinned subscription.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzProviders" -Request $Request
}
