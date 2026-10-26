function Set-CIPPPerUserMFA {
    <#
    .SYNOPSIS
    Change Per-User MFA State for a User

    .DESCRIPTION
    Change the Per-User MFA State for a user via the /users/{id}/authentication/requirements endpoint

    .PARAMETER TenantFilter
    Tenant where the user resides

    .PARAMETER userId
    One or more User IDs to set the MFA state for (GUID or UserPrincipalName). UPNs are resolved to object IDs before API calls.

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
        [AllowEmptyString()]
        [string[]]$userId,
        [ValidateSet('enabled', 'disabled', 'enforced')]
        $State = 'enabled',
        $Headers,
        $APIName = 'Set-CIPPPerUserMFA'
    )

    try {
        # Filter out empty entries
        $userId = @($userId | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        
        # If all entries were empty, return empty array
        if ($userId.Count -eq 0) {
            return @()
        }
        
        # Resolve UPNs to GUIDs
        $ResolvedUsers = [System.Collections.Generic.List[PSCustomObject]]::new()
        $UPNsToResolve = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        for ($i = 0; $i -lt $userId.Count; $i++) {
            $id = $userId[$i]
            # Check if it's a GUID (8-4-4-4-12 format)
            if ($id -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                # Already a GUID, use directly
                $ResolvedUsers.Add([PSCustomObject]@{
                    Index = $i
                    ObjectId = $id
                    DisplayIdentifier = $id
                })
            } elseif ($id -match '@') {
                # Looks like a UPN, queue for resolution
                $UPNsToResolve.Add([PSCustomObject]@{
                    Index = $i
                    UPN = $id
                })
            } else {
                # Invalid format
                $ErrorMsg = "Failed: Invalid user identifier format for $id (expected GUID or UPN)"
                $ResolvedUsers.Add([PSCustomObject]@{
                    Index = $i
                    ObjectId = $null
                    DisplayIdentifier = $id
                    Error = $ErrorMsg
                })
                Write-LogMessage -headers $Headers -API $APIName -message $ErrorMsg -Sev Error -tenant $TenantFilter
            }
        }
        
        # Resolve UPNs to GUIDs in bulk
        if ($UPNsToResolve.Count -gt 0) {
            $ResolveRequests = foreach ($Item in $UPNsToResolve) {
                @{
                    id     = $Item.Index
                    method = 'GET'
                    url    = "users?`$filter=userPrincipalName eq '$($Item.UPN)'&`$select=id"
                }
            }
            
            $ResolveResponses = New-GraphBulkRequest -tenantid $TenantFilter -scope 'https://graph.microsoft.com/.default' -Requests $ResolveRequests -asapp $true
            
            foreach ($Response in $ResolveResponses) {
                $ResolveIndex = [int]$Response.id
                $Item = $UPNsToResolve | Where-Object { $_.Index -eq $ResolveIndex } | Select-Object -First 1
                
                if (-not $Item) {
                    continue
                }
                
                $ResolveStatus = [int]$Response.status
                if ($ResolveStatus -eq 200) {
                    $MatchedUsers = @($Response.body.value)
                    if ($MatchedUsers.Count -eq 0) {
                        # No match
                        $ErrorMsg = "Failed: User not found with UPN $($Item.UPN)"
                        $ResolvedUsers.Add([PSCustomObject]@{
                            Index = $Item.Index
                            ObjectId = $null
                            DisplayIdentifier = $Item.UPN
                            Error = $ErrorMsg
                        })
                        Write-LogMessage -headers $Headers -API $APIName -message $ErrorMsg -Sev Error -tenant $TenantFilter
                    } elseif ($MatchedUsers.Count -gt 1) {
                        # Ambiguous match
                        $ErrorMsg = "Failed: More than one user found with UPN $($Item.UPN)"
                        $ResolvedUsers.Add([PSCustomObject]@{
                            Index = $Item.Index
                            ObjectId = $null
                            DisplayIdentifier = $Item.UPN
                            Error = $ErrorMsg
                        })
                        Write-LogMessage -headers $Headers -API $APIName -message $ErrorMsg -Sev Error -tenant $TenantFilter
                    } else {
                        # Single match - success
                        $ResolvedUsers.Add([PSCustomObject]@{
                            Index = $Item.Index
                            ObjectId = $MatchedUsers[0].id
                            DisplayIdentifier = $Item.UPN
                        })
                    }
                } else {
                    # Graph error during resolution
                    $ErrorMsg = if ($Response.body.error.message) { $Response.body.error.message } else { "HTTP $ResolveStatus" }
                    $FailureMessage = "Failed: Could not resolve UPN $($Item.UPN) to object ID. Graph API returned status $ResolveStatus : $ErrorMsg"
                    $ResolvedUsers.Add([PSCustomObject]@{
                        Index = $Item.Index
                        ObjectId = $null
                        DisplayIdentifier = $Item.UPN
                        Error = $FailureMessage
                    })
                    Write-LogMessage -headers $Headers -API $APIName -message $FailureMessage -Sev Error -tenant $TenantFilter
                }
            }
        }
        
        # Sort by index to maintain order
        $ResolvedUsers = $ResolvedUsers | Sort-Object -Property Index
        
        $int = 0
        $Body = @{
            perUserMfaState = $State
        }
        
        # Build PATCH requests only for successfully resolved users
        $PatchRequests = foreach ($User in $ResolvedUsers) {
            if ($User.ObjectId) {
                @{
                    id        = $User.Index
                    method    = 'PATCH'
                    url       = "users/$($User.ObjectId)/authentication/requirements"
                    body      = $Body
                    'headers' = @{
                        'Content-Type' = 'application/json'
                    }
                }
            }
        }
        
        # Track results by index - pre-populate with resolution errors
        $ResultsByIndex = @{}
        foreach ($User in $ResolvedUsers) {
            if ($User.Error) {
                $ResultsByIndex[$User.Index] = [PSCustomObject]@{
                    UserId  = $User.DisplayIdentifier
                    Success = $false
                    Message = $User.Error
                }
            }
        }

        # Execute PATCH requests (only for successfully resolved users)
        $PatchResponses = if ($PatchRequests.Count -gt 0) {
            New-GraphBulkRequest -tenantid $TenantFilter -scope 'https://graph.microsoft.com/.default' -Requests @($PatchRequests) -asapp $true
        } else {
            @()
        }
        
        $ToVerify = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Track which requests received responses
        $ReceivedIndices = [System.Collections.Generic.HashSet[int]]::new()
        
        # Check PATCH responses and queue successful ones for verification
        foreach ($Response in $PatchResponses) {
            $RequestIndex = [int]$Response.id
            $null = $ReceivedIndices.Add($RequestIndex)
            
            # Get the resolved user info
            $ResolvedUser = $ResolvedUsers | Where-Object { $_.Index -eq $RequestIndex } | Select-Object -First 1
            
            # Safely get the user ID - handle unexpected response IDs
            if (-not $ResolvedUser) {
                $ErrorMsg = "Failed: Received unexpected response ID $RequestIndex"
                $ResultsByIndex[$RequestIndex] = [PSCustomObject]@{
                    UserId  = "Unknown"
                    Success = $false
                    Message = $ErrorMsg
                }
                Write-LogMessage -headers $Headers -API $APIName -message $ErrorMsg -Sev Error -tenant $TenantFilter
                continue
            }
            
            $StatusCode = [int]$Response.status
            
            # Check if PATCH succeeded
            if ($StatusCode -lt 200 -or $StatusCode -ge 300) {
                $ErrorMsg = if ($Response.body.error.message) { $Response.body.error.message } else { "HTTP $StatusCode" }
                $FailureMessage = "Failed: Could not set MFA State to $State for $($ResolvedUser.DisplayIdentifier). Graph API returned status $StatusCode : $ErrorMsg"
                $ResultsByIndex[$RequestIndex] = [PSCustomObject]@{
                    UserId  = $ResolvedUser.DisplayIdentifier
                    Success = $false
                    Message = $FailureMessage
                }
                Write-LogMessage -headers $Headers -API $APIName -message $FailureMessage -Sev Error -tenant $TenantFilter
            } else {
                # Queue for verification
                $ToVerify.Add([PSCustomObject]@{
                        Index  = $RequestIndex
                        ObjectId = $ResolvedUser.ObjectId
                        DisplayIdentifier = $ResolvedUser.DisplayIdentifier
                    })
            }
        }
        
        # Report users that were sent for PATCH but didn't get responses
        foreach ($User in $ResolvedUsers) {
            if ($User.ObjectId -and -not $ReceivedIndices.Contains($User.Index) -and -not $ResultsByIndex.ContainsKey($User.Index)) {
                $MissingMsg = "Failed: No response received for $($User.DisplayIdentifier) (request ID $($User.Index))"
                $ResultsByIndex[$User.Index] = [PSCustomObject]@{
                    UserId  = $User.DisplayIdentifier
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
                            url    = "users/$($Item.ObjectId)/authentication/requirements"
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
                            $SuccessMessage = "Successfully set Per user MFA State to $State for $($Item.DisplayIdentifier)"
                            $ResultsByIndex[$Item.Index] = [PSCustomObject]@{
                                UserId  = $Item.DisplayIdentifier
                                Success = $true
                                Message = $SuccessMessage
                            }
                            Write-LogMessage -headers $Headers -API $APIName -message $SuccessMessage -Sev Info -tenant $TenantFilter
                        } elseif ($Retry -eq ($MaxRetries - 1)) {
                            # Final retry failed
                            $VerificationError = "Failed: MFA State for $($Item.DisplayIdentifier) did not change to $State after PATCH (status: $ActualState). The user may require special privileges or permissions."
                            $ResultsByIndex[$Item.Index] = [PSCustomObject]@{
                                UserId  = $Item.DisplayIdentifier
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
                                $MissingVerifyMsg = "Failed: No verification response received for $($Item.DisplayIdentifier) (request ID $($Item.Index))"
                                $ResultsByIndex[$Item.Index] = [PSCustomObject]@{
                                    UserId  = $Item.DisplayIdentifier
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
                    $VerifyErrorMsg = "Failed: Could not verify MFA State for $($Item.DisplayIdentifier). Error: $($VerifyException.NormalizedError)"
                    $ResultsByIndex[$Item.Index] = [PSCustomObject]@{
                        UserId  = $Item.DisplayIdentifier
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
