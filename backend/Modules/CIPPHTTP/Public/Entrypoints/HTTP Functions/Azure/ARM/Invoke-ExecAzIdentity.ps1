function Invoke-ExecAzIdentity {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.ReadWrite
    .DESCRIPTION
        Creates a user-assigned managed identity in an allowed resource group. Requires tenantFilter, ticketNumber (6-8 digits), reason, and dryRun (defaults true). Uses the Azure ARM change profile.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmWriteAction -Action 'ExecAzIdentity' -Request $Request
}
