function Invoke-ExecAppConsentRequest {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.ReadWrite
    .SYNOPSIS
        Approves or denies a user consent request. The decision is recorded only; admin consent is not granted.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Context = Get-CIPPAppConsentContext -Request $Request
    try {
        if ([string]::IsNullOrWhiteSpace($Context.TenantFilter)) { throw [System.ArgumentException]::new('tenantFilter is required') }
        $Action = $Context.Action
        if ($Action -notin @('Approve', 'Deny')) { throw [System.ArgumentException]::new('Action must be Approve or Deny') }
        $Result = Invoke-CIPPAppConsentRequest -TenantFilter $Context.TenantFilter -Action $Action `
            -AppConsentRequestId (ConvertTo-CIPPRequestValue ($Request.Body.appConsentRequestId ?? $Request.Body.AppConsentRequestId)) `
            -UserConsentRequestId (ConvertTo-CIPPRequestValue ($Request.Body.userConsentRequestId ?? $Request.Body.UserConsentRequestId)) `
            -StageId (ConvertTo-CIPPRequestValue ($Request.Body.stageId ?? $Request.Body.StageId)) `
            -Justification (ConvertTo-CIPPRequestValue ($Request.Body.justification ?? $Request.Body.Justification)) `
            -Headers $Context.Headers -APIName $Context.APIName
        $StatusCode = [HttpStatusCode]::OK
        $Results = if ($Result.Fallback) {
            "Denied the user consent request in $($Context.TenantFilter) because CIPP is not an assigned reviewer. Justification: $($Result.Justification). Admin consent was not granted."
        } else {
            "$($Result.ReviewResult) recorded for the user consent request in $($Context.TenantFilter). Admin consent was not granted."
        }
        $Body = @{ Results = $Results; Metadata = $Result }
    } catch {
        $Failure = Get-CIPPGraphFailure -ErrorRecord $_
        $StatusCode = if ($_.Exception -is [System.ArgumentException]) { [HttpStatusCode]::BadRequest } else { $Failure.StatusCode }
        $Body = @{ Results = $Failure.Message }
        Write-LogMessage -headers $Context.Headers -API $Context.APIName -tenant $Context.TenantFilter -message $Failure.Message -Sev 'Error'
    }
    return ([HttpResponseContext]@{ StatusCode = $StatusCode; Body = $Body })
}
