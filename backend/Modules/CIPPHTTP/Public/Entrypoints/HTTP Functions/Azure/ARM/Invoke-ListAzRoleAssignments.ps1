function Invoke-ListAzRoleAssignments {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.Read
    .DESCRIPTION
        Lists role assignments at subscription or resource group scope, plus role definitions.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzRoleAssignments" -Request $Request
}
