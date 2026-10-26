function Invoke-ExecPerUserMFA {
    <#
    .FUNCTIONALITY
    Entrypoint

    .ROLE
    Identity.User.ReadWrite
    #>
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    
    # Initialize response variables
    $Messages = @()
    $StatusCode = [HttpStatusCode]::OK

    # Prefer object ID (GUID) over UPN when available
    $UserId = if ($Request.Body.userId -and $Request.Body.userId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        $Request.Body.userId
    } else {
        $Request.Body.userPrincipalName
    }
    $TenantFilter = $Request.Body.tenantFilter
    $State = $Request.Body.State.value ?  $Request.Body.State.value : $Request.Body.State

    # Check for empty input before calling Set-CIPPPerUserMFA
    if ([string]::IsNullOrWhiteSpace($UserId)) {
        $Messages = @("Failed: No users were processed. Please check the request parameters.")
        $StatusCode = [HttpStatusCode]::BadRequest
    } else {
        $Request = @{
            userId       = $UserId
            TenantFilter = $TenantFilter
            State        = $State
            Headers      = $Headers
            APIName      = $APIName
        }
        try {
            $Results = @(Set-CIPPPerUserMFA @Request)
            
            # Check for zero results
            if ($Results.Count -eq 0) {
                $Messages = @("Failed: No users were processed. Please check the request parameters.")
                $StatusCode = [HttpStatusCode]::BadRequest
            } else {
                # Check structured results for success/failure
                $SuccessCount = 0
                $FailureCount = 0
                $Messages = foreach ($Result in $Results) {
                if ($Result.Success) {
                    $SuccessCount++
                } else {
                    $FailureCount++
                }
                $Result.Message
            }
            
            # Set status code based on results
            if ($FailureCount -gt 0 -and $SuccessCount -eq 0) {
                # All failed
                $StatusCode = [HttpStatusCode]::BadRequest
            } elseif ($FailureCount -gt 0 -and $SuccessCount -gt 0) {
                # Partial failure
                $StatusCode = [HttpStatusCode]::MultiStatus
            } else {
                # All succeeded
                $StatusCode = [HttpStatusCode]::OK
            }
            }
        } catch {
            $ErrorData = Get-CippException -Exception $_
            $ErrorMessage = "Failed to set per-user MFA for $UserId in $TenantFilter. Error: $($ErrorData.NormalizedError)"
            Write-LogMessage -API $APIName -tenant $TenantFilter -message $ErrorMessage -Sev Error -headers $Headers -LogData $ErrorData
            $Messages = @($_.Exception.Message)
            $StatusCode = [HttpStatusCode]::InternalServerError
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ 'Results' = $Messages }
        })
}
