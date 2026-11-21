function Invoke-ListAzCosts {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Cost.Read
    .DESCRIPTION
        Runs a Cost Management query (read-only POST) for the pinned subscription.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzCosts" -Request $Request
}
