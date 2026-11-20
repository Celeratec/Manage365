function Invoke-ListAzPolicyAssignments {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.Read
    .DESCRIPTION
        Lists policy assignments at subscription or resource group scope.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPAzArmListAction -Action "ListAzPolicyAssignments" -Request $Request
}
