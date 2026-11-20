function Invoke-ListAzFlexLocations {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.Read
    .DESCRIPTION
        Lists Flex Consumption geo regions for the pinned subscription.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzFlexLocations" -Request $Request
}
