function Invoke-ExecOAuth2PermissionGrant {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.ReadWrite
    .SYNOPSIS
        Adds, updates, or removes a Principal delegated permission grant. AllPrincipals is refused.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Context = Get-CIPPAppConsentContext -Request $Request
    try {
        if ([string]::IsNullOrWhiteSpace($Context.TenantFilter)) { throw [System.ArgumentException]::new('tenantFilter is required') }
        $Action = $Context.Action
        if ($Action -notin @('Add', 'Update', 'Remove')) { throw [System.ArgumentException]::new('Action must be Add, Update, or Remove') }
        $ConsentType = ConvertTo-CIPPRequestValue ($Request.Body.consentType ?? $Request.Body.ConsentType)
        if ([string]::IsNullOrWhiteSpace($ConsentType)) { $ConsentType = 'Principal' }
        $Result = Invoke-CIPPOAuth2PermissionGrant -TenantFilter $Context.TenantFilter -Action $Action -ConsentType $ConsentType `
            -ServicePrincipalId (ConvertTo-CIPPRequestValue ($Request.Body.servicePrincipalId ?? $Request.Body.ServicePrincipalId ?? $Request.Body.clientId)) `
            -PrincipalId (ConvertTo-CIPPRequestValue ($Request.Body.principalId ?? $Request.Body.PrincipalId)) `
            -Scope (ConvertTo-CIPPRequestValue ($Request.Body.scope ?? $Request.Body.Scope)) `
            -ResourceId (ConvertTo-CIPPRequestValue ($Request.Body.resourceId ?? $Request.Body.ResourceId)) `
            -GrantId (ConvertTo-CIPPRequestValue ($Request.Body.grantId ?? $Request.Body.GrantId)) `
            -Headers $Context.Headers -APIName $Context.APIName
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = "Principal oauth2 permission grant $Action completed for $($Context.TenantFilter)."; Metadata = $Result }
    } catch {
        $Failure = Get-CIPPGraphFailure -ErrorRecord $_
        $StatusCode = if ($_.Exception -is [System.ArgumentException]) { [HttpStatusCode]::BadRequest } else { $Failure.StatusCode }
        $Body = @{ Results = $Failure.Message }
        Write-LogMessage -headers $Context.Headers -API $Context.APIName -tenant $Context.TenantFilter -message $Failure.Message -Sev 'Error'
    }
    return ([HttpResponseContext]@{ StatusCode = $StatusCode; Body = $Body })
}
