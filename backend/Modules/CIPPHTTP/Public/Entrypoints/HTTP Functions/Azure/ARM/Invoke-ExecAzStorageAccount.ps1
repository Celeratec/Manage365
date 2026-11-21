function Invoke-ExecAzStorageAccount {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.ReadWrite
    .DESCRIPTION
        Creates a StorageV2 account with secure defaults (TLS1.2, no public blob, no shared key). Requires tenantFilter, ticketNumber (6-8 digits), reason, and dryRun (defaults true). Uses the Azure ARM change profile.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmWriteAction -Action 'ExecAzStorageAccount' -Request $Request
}
