function Invoke-ExecGrantAppToUsers {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.ReadWrite
    .SYNOPSIS
        Creates the customer service principal if needed, requires assignment, and grants Principal delegated scopes to the named users.
    .DESCRIPTION
        Idempotent. Reuses an existing service principal, assignment, or grant and merges scopes.
        Returns the ids created so the change can be rolled back. Never writes AllPrincipals consent.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Context = Get-CIPPAppConsentContext -Request $Request
    try {
        if ([string]::IsNullOrWhiteSpace($Context.TenantFilter)) { throw [System.ArgumentException]::new('tenantFilter is required') }
        $AppId = ConvertTo-CIPPRequestValue ($Request.Body.appId ?? $Request.Body.AppId)
        $Users = @(ConvertTo-CIPPRequestValue -List ($Request.Body.userIds ?? $Request.Body.UserIds))
        $Scopes = @(ConvertTo-CIPPRequestValue -List ($Request.Body.scopes ?? $Request.Body.Scopes))
        $Require = $true
        $RequireValue = $Request.Body.requireAssignment ?? $Request.Body.RequireAssignment
        if ($null -ne $RequireValue -and "$RequireValue" -ne '') {
            $Require = [System.Convert]::ToBoolean((ConvertTo-CIPPRequestValue $RequireValue))
        }
        $Result = Invoke-CIPPGrantAppToUsers -TenantFilter $Context.TenantFilter -AppId $AppId -UserIds $Users -Scopes $Scopes -RequireAssignment:$Require -Headers $Context.Headers -APIName $Context.APIName
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            Results  = "Granted $AppId to $($Users.Count) user(s) in $($Context.TenantFilter). No tenant-wide consent was granted."
            Metadata = $Result
        }
    } catch {
        $Failure = Get-CIPPGraphFailure -ErrorRecord $_
        $StatusCode = if ($_.Exception -is [System.ArgumentException]) { [HttpStatusCode]::BadRequest } else { $Failure.StatusCode }
        $Body = @{ Results = $Failure.Message }
        Write-LogMessage -headers $Context.Headers -API $Context.APIName -tenant $Context.TenantFilter -message $Failure.Message -Sev 'Error'
    }
    return ([HttpResponseContext]@{ StatusCode = $StatusCode; Body = $Body })
}
