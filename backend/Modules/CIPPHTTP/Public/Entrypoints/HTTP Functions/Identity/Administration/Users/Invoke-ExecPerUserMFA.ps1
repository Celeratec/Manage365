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


    # Guest user handling
    $UserId = $Request.Body.userPrincipalName -match '#EXT#' ? $Request.Body.userId : $Request.Body.userPrincipalName
    $TenantFilter = $Request.Body.tenantFilter
    $State = $Request.Body.State.value ?  $Request.Body.State.value : $Request.Body.State

    $Request = @{
        userId       = $UserId
        TenantFilter = $TenantFilter
        State        = $State
        Headers      = $Headers
        APIName      = $APIName
    }
    try {
        $Results = @(Set-CIPPPerUserMFA @Request)
        
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
    } catch {
        $Messages = @($_.Exception.Message)
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ 'Results' = $Messages }
        })
}
