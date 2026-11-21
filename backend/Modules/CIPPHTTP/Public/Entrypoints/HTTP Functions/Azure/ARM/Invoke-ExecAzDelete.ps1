function Invoke-ExecAzDelete {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.ReadWrite
    .DESCRIPTION
        Deletes a Manage365-tagged resource created under the same ticket (rollback only). Requires tenantFilter, ticketNumber (6-8 digits), reason, and dryRun (defaults true). Uses the Azure ARM change profile.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmWriteAction -Action 'ExecAzDelete' -Request $Request
}
