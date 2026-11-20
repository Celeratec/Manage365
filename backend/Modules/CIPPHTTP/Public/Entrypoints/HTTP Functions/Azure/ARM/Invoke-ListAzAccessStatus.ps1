function Invoke-ListAzAccessStatus {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.Read
    .DESCRIPTION
        Self-check for ARM access: subscriptions, permissions, over-privilege tripwire.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzAccessStatus" -Request $Request
}
