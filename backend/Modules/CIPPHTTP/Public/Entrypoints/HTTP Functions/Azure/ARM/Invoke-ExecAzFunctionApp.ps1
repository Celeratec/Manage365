function Invoke-ExecAzFunctionApp {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.ReadWrite
    .DESCRIPTION
        Creates a Flex Consumption function app (or setAppSettings / setKeyVaultReferenceIdentity). Requires tenantFilter, ticketNumber (6-8 digits), reason, and dryRun (defaults true). Uses the Azure ARM change profile.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmWriteAction -Action 'ExecAzFunctionApp' -Request $Request
}
