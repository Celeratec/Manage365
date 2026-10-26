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
        
        # Track results by index to preserve userId order (store result objects, not strings)
        $ResultsByIndex = @{}
        $ToVerify = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Track which requests received responses
        $ReceivedIndices = [System.Collections.Generic.HashSet[int]]::new()
        
        # Check PATCH responses and queue successful ones for verification
        foreach ($Response in $PatchResponses) {
            $RequestIndex = [int]$Response.id
            $null = $ReceivedIndices.Add($RequestIndex)
            
            # Safely get the user ID - handle unexpected response IDs
            if ($RequestIndex -lt 0 -or $RequestIndex -ge $userId.Count) {
                $ErrorMsg = "Failed: Received unexpected response ID $RequestIndex (expected 0-$($userId.Count - 1))"
                $ResultsByIndex[$RequestIndex] = [PSCustomObject]@{
                    UserId  = if ($RequestIndex -ge 0 -and $RequestIndex -lt $userId.Count) { $userId[$RequestIndex] } else { "Unknown" }
                    Success = $false
                    Message = $ErrorMsg
                }
                Write-LogMessage -headers $Headers -API $APIName -message $ErrorMsg -Sev Error -tenant $TenantFilter
                continue
            }
            
            $TargetUserId = $userId[$RequestIndex]
            $StatusCode = [int]$Response.status
            
            # Check if PATCH succeeded
            if ($StatusCode -lt 200 -or $StatusCode -ge 300) {
                $ErrorMsg = if ($Response.body.error.message) { $Response.body.error.message } else { "HTTP $StatusCode" }
                $FailureMessage = "Failed: Could not set MFA State to $State for $TargetUserId. Graph API returned status $StatusCode : $ErrorMsg"
                $ResultsByIndex[$RequestIndex] = [PSCustomObject]@{
                    UserId  = $TargetUserId
                    Success = $false
                    Message = $FailureMessage
                }
                Write-LogMessage -headers $Headers -API $APIName -message $FailureMessage -Sev Error -tenant $TenantFilter
            } else {
                # Queue for verification
                $ToVerify.Add([PSCustomObject]@{
                        Index  = $RequestIndex
                        UserId = $TargetUserId
                    })
            }
        }
        
        # Report users missing from batch response
        for ($i = 0; $i -lt $userId.Count; $i++) {
            if (-not $ReceivedIndices.Contains($i)) {
                $MissingMsg = "Failed: No response received for $($userId[$i]) (request ID $i)"
                $ResultsByIndex[$i] = [PSCustomObject]@{
                    UserId  = $userId[$i]
                    Success = $false
                    Message = $MissingMsg
                }
                Write-LogMessage -headers $Headers -API $APIName -message $MissingMsg -Sev Error -tenant $TenantFilter
            }
        }
        
        # Batch verify all successful PATCHes
        if ($ToVerify.Count -gt 0) {
            try {
                # Verification retries: 3 attempts with 2s and 4s delays between them (6s of sleep total).
                # New-GraphBulkRequest itself retries throttled requests (429/503/504) up to twice per batch
                # with up to 30s wait each, so worst case including Graph retries can approach several minutes.
                $MaxRetries = 3
                $RetryDelay = 2
                
                for ($Retry = 0; $Retry -lt $MaxRetries; $Retry++) {
                    if ($Retry -gt 0) {
                        Start-Sleep -Seconds $RetryDelay
                        $RetryDelay *= 2
                    }
                    
                    # Build bulk verification requests
                    $VerifyRequests = foreach ($Item in $ToVerify) {
                        @{
                            id     = $Item.Index
                            method = 'GET'
                            url    = "users/$($Item.UserId)/authentication/requirements"
                        }
                    }
                    
                    $VerifyResponses = New-GraphBulkRequest -tenantid $TenantFilter -scope 'https://graph.microsoft.com/.default' -Requests $VerifyRequests -asapp $true
                    
                    # Track which verification requests received responses
                    $VerifiedIndices = [System.Collections.Generic.HashSet[int]]::new()
                    
                    # Check verification results
                    $StillToVerify = [System.Collections.Generic.List[PSCustomObject]]::new()
                    
                    foreach ($VerifyResponse in $VerifyResponses) {
                        $VerifyIndex = [int]$VerifyResponse.id
                        $null = $VerifiedIndices.Add($VerifyIndex)
                        $Item = $ToVerify | Where-Object { $_.Index -eq $VerifyIndex } | Select-Object -First 1
                        
                        if (-not $Item) {
                            Write-LogMessage -headers $Headers -API $APIName -message "Received unexpected verification response ID $VerifyIndex" -Sev Warning -tenant $TenantFilter
                            continue
                        }
                        
                        $VerifyStatus = [int]$VerifyResponse.status
                        $ActualState = $VerifyResponse.body.perUserMfaState
                        
                        if ($VerifyStatus -eq 200 -and $ActualState -eq $State) {
                            # Verified successfully - Success = $true only here
                            $SuccessMessage = "Successfully set Per user MFA State to $State for $($Item.UserId)"
                            $ResultsByIndex[$Item.Index] = [PSCustomObject]@{
                                UserId  = $Item.UserId
                                Success = $true
                                Message = $SuccessMessage
                            }
                            Write-LogMessage -headers $Headers -API $APIName -message $SuccessMessage -Sev Info -tenant $TenantFilter
                        } elseif ($Retry -eq ($MaxRetries - 1)) {
                            # Final retry failed
                            $VerificationError = "Failed: MFA State for $($Item.UserId) did not change to $State after PATCH (status: $ActualState). The user may require special privileges or permissions."
                            $ResultsByIndex[$Item.Index] = [PSCustomObject]@{
                                UserId  = $Item.UserId
                                Success = $false
                                Message = $VerificationError
                            }
                            Write-LogMessage -headers $Headers -API $APIName -message $VerificationError -Sev Error -tenant $TenantFilter
                        } else {
                            # Queue for retry
                            $StillToVerify.Add($Item)
                        }
                    }
                    
                    # Handle users missing from verification response
                    foreach ($Item in $ToVerify) {
                        if (-not $VerifiedIndices.Contains($Item.Index)) {
                            if ($Retry -eq ($MaxRetries - 1)) {
                                # Final retry - report as failure
                                $MissingVerifyMsg = "Failed: No verification response received for $($Item.UserId) (request ID $($Item.Index))"
                                $ResultsByIndex[$Item.Index] = [PSCustomObject]@{
                                    UserId  = $Item.UserId
                                    Success = $false
                                    Message = $MissingVerifyMsg
                                }
                                Write-LogMessage -headers $Headers -API $APIName -message $MissingVerifyMsg -Sev Error -tenant $TenantFilter
                            } else {
                                # Non-final retry - queue for retry
                                $StillToVerify.Add($Item)
                            }
                        }
                    }
                    
                    # Update the list for next retry
                    $ToVerify = $StillToVerify
                    if ($ToVerify.Count -eq 0) { break }
                }
            } catch {
                # If verification throws, keep the per-user results collected so far
                $VerifyException = Get-CippException -Exception $_
                foreach ($Item in $ToVerify) {
                    $VerifyErrorMsg = "Failed: Could not verify MFA State for $($Item.UserId). Error: $($VerifyException.NormalizedError)"
                    $ResultsByIndex[$Item.Index] = [PSCustomObject]@{
                        UserId  = $Item.UserId
                        Success = $false
                        Message = $VerifyErrorMsg
                    }
                    Write-LogMessage -headers $Headers -API $APIName -message $VerifyErrorMsg -Sev Error -tenant $TenantFilter
                }
            }
        }
        
        # Build final results array in userId order, then add any out-of-range results
        $FinalResults = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # First, add results for valid user indices in order
        for ($i = 0; $i -lt $userId.Count; $i++) {
            if ($ResultsByIndex.ContainsKey($i)) {
                $FinalResults.Add($ResultsByIndex[$i])
            }
        }
        
        # Then, add any out-of-range results (e.g., unexpected response IDs)
        foreach ($Key in $ResultsByIndex.Keys) {
            if ($Key -lt 0 -or $Key -ge $userId.Count) {
                $FinalResults.Add($ResultsByIndex[$Key])
            }
        }
        
        return $FinalResults
    } catch {
        # Unexpected infrastructure exception - throw for 500 (callers will log)
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed: Unexpected error setting MFA State. Error: $($ErrorMessage.NormalizedError)"
        throw $Result
    }
}
