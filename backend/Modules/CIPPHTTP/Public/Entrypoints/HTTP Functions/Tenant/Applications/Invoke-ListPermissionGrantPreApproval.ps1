function Invoke-ListPermissionGrantPreApproval {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.AppGovernance.Read
    .DESCRIPTION
        Lists permission grant pre-approval policies for a tenant.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Tenant = [string]($Request.Query.tenantFilter ?? $Request.Body.tenantFilter)
    if ([string]::IsNullOrWhiteSpace($Tenant)) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'tenantFilter is required.' } }
    }
    $Policies = @(New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/policies/permissionGrantPreApprovalPolicies' -tenantid $Tenant -asApp $true)
    return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = @{ Results = $Policies } }
}
