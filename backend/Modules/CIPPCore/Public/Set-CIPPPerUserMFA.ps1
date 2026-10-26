function Set-CIPPPerUserMFA {
    <#
    .SYNOPSIS
    Change Per-User MFA State for a User

    .DESCRIPTION
    Change the Per-User MFA State for a user via the /users/{id}/authentication/requirements endpoint

    .PARAMETER TenantFilter
    Tenant where the user resides

    .PARAMETER userId
    One or more User IDs to set the MFA state for (GUID or UserPrincipalName)

    .PARAMETER State
    State to set the user to (enabled, disabled, enforced)

    .PARAMETER Headers
    User executing the command

    .EXAMPLE
    Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId user@contoso.onmicrosoft.com -State 'disabled' -Headers 'mspuser@partner.com'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,
        [Parameter(Mandatory = $true)]
        [string[]]$userId,
        [ValidateSet('enabled', 'disabled', 'enforced')]
        $State = 'enabled',
        $Headers,
        $APIName = 'Set-CIPPPerUserMFA'
    )

    try {
        $int = 0
        $Body = @{
            perUserMfaState = $State
        }
        
        # Build PATCH requests
        $PatchRequests = foreach ($id in $userId) {
            @{
                id        = $int++
                method    = 'PATCH'
                url       = "users/$id/authentication/requirements"
                body      = $Body
                'headers' = @{
                    'Content-Type' = 'application/json'
                }
            }
        }

        # Execute PATCH requests
        $PatchResponses = New-GraphBulkRequest -tenantid $TenantFilter -scope 'https://graph.microsoft.com/.default' -Requests @($PatchRequests) -asapp $true
        
        # Verify each response
        $Results = [System.Collections.Generic.List[string]]::new()
        $Errors = [System.Collections.Generic.List[string]]::new()
        
        foreach ($Response in $PatchResponses) {
            $RequestIndex = [int]$Response.id
            $TargetUserId = $userId[$RequestIndex]
            $StatusCode = [int]$Response.status
            
            # Check if PATCH succeeded
            if ($StatusCode -lt 200 -or $StatusCode -ge 300) {
                $ErrorMsg = if ($Response.body.error.message) { $Response.body.error.message } else { "HTTP $StatusCode" }
                $FailureMessage = "Failed to set MFA State to $State for $TargetUserId. Graph API returned status $StatusCode : $ErrorMsg"
                $Errors.Add($FailureMessage)
                Write-LogMessage -headers $Headers -API $APIName -message $FailureMessage -Sev Error -tenant $TenantFilter
                continue
            }
            
            # Verify the state actually changed by re-reading it
            $VerifyRequests = @(
                @{
                    id     = 0
                    method = 'GET'
                    url    = "users/$TargetUserId/authentication/requirements"
                }
            )
            
            $MaxRetries = 3
            $RetryDelay = 1
            $StateVerified = $false
            
            for ($Retry = 0; $Retry -lt $MaxRetries; $Retry++) {
                if ($Retry -gt 0) {
                    Start-Sleep -Seconds $RetryDelay
                    $RetryDelay *= 2
                }
                
                $VerifyResponses = New-GraphBulkRequest -tenantid $TenantFilter -scope 'https://graph.microsoft.com/.default' -Requests $VerifyRequests -asapp $true
                $VerifyResponse = $VerifyResponses[0]
                
                if ([int]$VerifyResponse.status -eq 200 -and $VerifyResponse.body.perUserMfaState -eq $State) {
                    $StateVerified = $true
                    break
                }
            }
            
            if ($StateVerified) {
                $SuccessMessage = "Successfully set Per user MFA State to $State for $TargetUserId"
                $Results.Add($SuccessMessage)
                Write-LogMessage -headers $Headers -API $APIName -message $SuccessMessage -Sev Info -tenant $TenantFilter
            } else {
                $VerificationError = "MFA State for $TargetUserId did not change to $State after PATCH (status: $($VerifyResponse.body.perUserMfaState)). The user may require special privileges or permissions."
                $Errors.Add($VerificationError)
                Write-LogMessage -headers $Headers -API $APIName -message $VerificationError -Sev Error -tenant $TenantFilter
            }
        }
        
        # Return results or throw if all failed
        if ($Errors.Count -gt 0 -and $Results.Count -eq 0) {
            throw ($Errors -join '; ')
        } elseif ($Errors.Count -gt 0) {
            return @($Results) + @($Errors)
        } else {
            return $Results
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to set MFA State to $State. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -message $Result -Sev Error -tenant $TenantFilter -LogData $ErrorMessage
        throw $Result
    }
}
