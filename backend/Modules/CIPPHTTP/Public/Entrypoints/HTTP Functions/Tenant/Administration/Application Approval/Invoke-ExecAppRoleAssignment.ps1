function Invoke-ExecAppRoleAssignment {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.ReadWrite
    .SYNOPSIS
        Assigns or removes an app role for one user or group. Does not grant delegated consent.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Context = Get-CIPPAppConsentContext -Request $Request
    try {
        if ([string]::IsNullOrWhiteSpace($Context.TenantFilter)) { throw [System.ArgumentException]::new('tenantFilter is required') }
        $Action = $Context.Action
        if ($Action -notin @('Add', 'Remove')) { throw [System.ArgumentException]::new('Action must be Add or Remove') }
        $Result = Invoke-CIPPAppRoleAssignment -TenantFilter $Context.TenantFilter -Action $Action `
            -ServicePrincipalId (ConvertTo-CIPPRequestValue ($Request.Body.servicePrincipalId ?? $Request.Body.ServicePrincipalId ?? $Request.Query.servicePrincipalId)) `
            -PrincipalId (ConvertTo-CIPPRequestValue ($Request.Body.principalId ?? $Request.Body.PrincipalId)) `
            -AppRoleId $(if (ConvertTo-CIPPRequestValue ($Request.Body.appRoleId ?? $Request.Body.AppRoleId)) { ConvertTo-CIPPRequestValue ($Request.Body.appRoleId ?? $Request.Body.AppRoleId) } else { '00000000-0000-0000-0000-000000000000' }) `
            -AssignmentId (ConvertTo-CIPPRequestValue ($Request.Body.assignmentId ?? $Request.Body.AssignmentId)) `
            -Headers $Context.Headers -APIName $Context.APIName
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = "App role assignment $Action completed for $($Context.TenantFilter)."; Metadata = $Result }
    } catch {
        $Failure = Get-CIPPGraphFailure -ErrorRecord $_
        $StatusCode = if ($_.Exception -is [System.ArgumentException]) { [HttpStatusCode]::BadRequest } else { $Failure.StatusCode }
        $Body = @{ Results = $Failure.Message }
        Write-LogMessage -headers $Context.Headers -API $Context.APIName -tenant $Context.TenantFilter -message $Failure.Message -Sev 'Error'
    }
    return ([HttpResponseContext]@{ StatusCode = $StatusCode; Body = $Body })
}
