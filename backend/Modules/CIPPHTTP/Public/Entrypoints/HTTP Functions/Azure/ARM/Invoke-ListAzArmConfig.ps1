function Invoke-ListAzArmConfig {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.Read
    .DESCRIPTION
        Returns the sanitized per-tenant Azure ARM access config (no secrets).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzArmConfig" -Request $Request
}
