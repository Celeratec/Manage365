function Invoke-ExecAzResourceProvider {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.ReadWrite
    .DESCRIPTION
        Registers an allowlisted Azure resource provider (change profile). Requires tenantFilter, ticketNumber (6-8 digits), reason, and dryRun (defaults true). Uses the Azure ARM change profile.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmWriteAction -Action 'ExecAzResourceProvider' -Request $Request
}
