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
        $Result = @(Set-CIPPPerUserMFA @Request)
        
        # Check if any results indicate failure
        $HasFailures = $false
        $HasSuccesses = $false
        foreach ($Message in $Result) {
            if ($Message -match '^Failed|^No response|^Received unexpected|did not change') {
                $HasFailures = $true
            } elseif ($Message -match '^Successfully') {
                $HasSuccesses = $true
            }
        }
        
        # Set status code based on results
        if ($HasFailures -and -not $HasSuccesses) {
            # All failed
            $StatusCode = [HttpStatusCode]::BadRequest
        } elseif ($HasFailures -and $HasSuccesses) {
            # Partial failure
            $StatusCode = [HttpStatusCode]::MultiStatus
        } else {
            # All succeeded
            $StatusCode = [HttpStatusCode]::OK
        }
    } catch {
        $Result = @($_.Exception.Message)
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ 'Results' = $Result }
        })
}
