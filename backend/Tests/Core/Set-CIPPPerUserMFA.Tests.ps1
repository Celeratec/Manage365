BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    
    function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = $Exception.Exception.Message } }
    function Write-LogMessage { param($message, $tenant, $API, $sev, $Headers, $LogData) }
    function New-GraphBulkRequest { param($tenantid, $Requests, $NoAuthCheck, $asapp, $scope) }
    
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Set-CIPPPerUserMFA.ps1')
}

Describe 'Set-CIPPPerUserMFA' {
    BeforeEach {
        $script:GraphCalls = [System.Collections.Generic.List[object]]::new()
        Mock Write-LogMessage { }
    }

    Context 'Success case' {
        It 'successfully sets MFA state when PATCH succeeds and state verifies' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                # First call is PATCH, second is batched GET verification
                if ($script:GraphCalls.Count -eq 1) {
                    # PATCH response
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 204
                            body   = @{}
                        }
                    )
                } else {
                    # Batched GET verification response
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 200
                            body   = [pscustomobject]@{
                                perUserMfaState = 'disabled'
                            }
                        }
                    )
                }
            }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Result | Should -Not -BeNullOrEmpty
            $Result[0].UserId | Should -Be 'user@contoso.com'
            $Result[0].Success | Should -Be $true
            $Result[0].Message | Should -Match 'Successfully set Per user MFA State to disabled for user@contoso.com'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Info' -and $message -match 'Successfully' }
        }
        
        It 'handles multiple users in bulk operations' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                # First call is bulk PATCH, second is batched GET verifications
                if ($script:GraphCalls.Count -eq 1) {
                    # PATCH responses for 2 users
                    @(
                        [pscustomobject]@{ id = 0; status = 204; body = @{} }
                        [pscustomobject]@{ id = 1; status = 204; body = @{} }
                    )
                } else {
                    # Batched GET verification responses
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 200
                            body   = [pscustomobject]@{ perUserMfaState = 'enabled' }
                        }
                        [pscustomobject]@{
                            id     = 1
                            status = 200
                            body   = [pscustomobject]@{ perUserMfaState = 'enabled' }
                        }
                    )
                }
            }
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('user1@contoso.com', 'user2@contoso.com') -State 'enabled' -Headers @{ Authorization = 'Bearer token' }
            
            $Result.Count | Should -Be 2
            $Result[0].UserId | Should -Be 'user1@contoso.com'
            $Result[0].Success | Should -Be $true
            $Result[1].UserId | Should -Be 'user2@contoso.com'
            $Result[1].Success | Should -Be $true
        }
    }
    
    Context 'Graph API error case' {
        It 'reports error when Graph API PATCH fails with 403' {
            Mock New-GraphBulkRequest {
                @(
                    [pscustomobject]@{
                        id     = 0
                        status = 403
                        body   = [pscustomobject]@{
                            error = [pscustomobject]@{
                                message = 'Insufficient privileges to complete the operation.'
                            }
                        }
                    }
                )
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'admin@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Success | Should -Be $false
            $Result[0].Message | Should -Match '403'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match '403' }
        }
        
        It 'reports error when Graph API PATCH fails with 400' {
            Mock New-GraphBulkRequest {
                @(
                    [pscustomobject]@{
                        id     = 0
                        status = 400
                        body   = [pscustomobject]@{
                            error = [pscustomobject]@{
                                message = 'Invalid request'
                            }
                        }
                    }
                )
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Success | Should -Be $false
            $Result[0].Message | Should -Match '400.*Invalid request'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' }
        }
    }
    
    Context 'State verification failure case' {
        It 'reports error when PATCH succeeds but state does not change' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                if ($script:GraphCalls.Count -le 1) {
                    # PATCH response - success
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 204
                            body   = @{}
                        }
                    )
                } else {
                    # GET verification response - state unchanged
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 200
                            body   = [pscustomobject]@{
                                perUserMfaState = 'enforced'
                            }
                        }
                    )
                }
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'olumc.org' -userId 'ryanadmin@olumc.org' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Success | Should -Be $false
            $Result[0].Message | Should -Match 'did not change'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match 'did not change' }
            Should -Invoke Start-Sleep -Times 2
        }
        
        It 'retries verification multiple times before failing' {
            $script:VerifyCallCount = 0
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                if ($script:GraphCalls.Count -eq 1) {
                    # PATCH response
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 204
                            body   = @{}
                        }
                    )
                } else {
                    $script:VerifyCallCount++
                    # All GET verification attempts return wrong state
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 200
                            body   = [pscustomobject]@{
                                perUserMfaState = 'enforced'
                            }
                        }
                    )
                }
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Success | Should -Be $false
            $script:VerifyCallCount | Should -Be 3
        }
        
        It 'succeeds on retry when state eventually changes' {
            $script:VerifyCallCount = 0
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                if ($script:GraphCalls.Count -eq 1) {
                    # PATCH response
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 204
                            body   = @{}
                        }
                    )
                } else {
                    $script:VerifyCallCount++
                    # Second verification batch returns correct state
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 200
                            body   = [pscustomobject]@{
                                perUserMfaState = if ($script:VerifyCallCount -ge 2) { 'disabled' } else { 'enforced' }
                            }
                        }
                    )
                }
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Success | Should -Be $true
            $Result[0].Message | Should -Match 'Successfully'
            $script:VerifyCallCount | Should -Be 2
        }
    }
    
    Context 'Mixed results in bulk operations' {
        It 'returns both successes and failures for bulk operations' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                if ($script:GraphCalls.Count -eq 1) {
                    # PATCH responses - one success, one failure
                    @(
                        [pscustomobject]@{ id = 0; status = 204; body = @{} }
                        [pscustomobject]@{ 
                            id = 1
                            status = 403
                            body = [pscustomobject]@{
                                error = [pscustomobject]@{
                                    message = 'Insufficient privileges'
                                }
                            }
                        }
                    )
                } else {
                    # Batched GET verification for the successful one
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 200
                            body   = [pscustomobject]@{ perUserMfaState = 'disabled' }
                        }
                    )
                }
            }
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('user@contoso.com', 'admin@contoso.com') -State 'disabled' -Headers @{ Authorization = 'Bearer token' }
            
            $Result.Count | Should -Be 2
            $Result[0].UserId | Should -Be 'user@contoso.com'
            $Result[0].Success | Should -Be $true
            $Result[1].UserId | Should -Be 'admin@contoso.com'
            $Result[1].Success | Should -Be $false
            $Result[1].Message | Should -Match 'Failed.*403'
        }
        
        It 'handles unexpected response IDs gracefully' {
            Mock New-GraphBulkRequest {
                # Return response with ID out of bounds - user@contoso.com (ID 0) gets no response
                @(
                    [pscustomobject]@{
                        id     = 99
                        status = 204
                        body   = @{}
                    }
                )
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Success | Should -Be $false
            $Result[0].Message | Should -Match 'Failed:.*No response received.*user@contoso.com'
            Should -Invoke Write-LogMessage -Times 2 -ParameterFilter { $sev -eq 'Error' }
        }
        
        It 'returns failures for all users instead of throwing when all fail' {
            Mock New-GraphBulkRequest {
                # All users fail
                @(
                    [pscustomobject]@{
                        id     = 0
                        status = 403
                        body   = [pscustomobject]@{
                            error = [pscustomobject]@{
                                message = 'Insufficient privileges'
                            }
                        }
                    }
                    [pscustomobject]@{
                        id     = 1
                        status = 403
                        body   = [pscustomobject]@{
                            error = [pscustomobject]@{
                                message = 'Insufficient privileges'
                            }
                        }
                    }
                )
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('user1@contoso.com', 'user2@contoso.com') -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Result.Count | Should -Be 2
            $Result[0].Success | Should -Be $false
            $Result[1].Success | Should -Be $false
        }
        
        It 'retries users missing from verification response on non-final retries' {
            $script:VerifyCallCount = 0
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                if ($script:GraphCalls.Count -eq 1) {
                    # PATCH responses for 2 users
                    @(
                        [pscustomobject]@{ id = 0; status = 204; body = @{} }
                        [pscustomobject]@{ id = 1; status = 204; body = @{} }
                    )
                } else {
                    $script:VerifyCallCount++
                    if ($script:VerifyCallCount -eq 1) {
                        # First verification - only user2 in response (user1 missing)
                        @(
                            [pscustomobject]@{
                                id     = 1
                                status = 200
                                body   = [pscustomobject]@{ perUserMfaState = 'disabled' }
                            }
                        )
                    } else {
                        # Second verification - user1 now succeeds
                        @(
                            [pscustomobject]@{
                                id     = 0
                                status = 200
                                body   = [pscustomobject]@{ perUserMfaState = 'disabled' }
                            }
                        )
                    }
                }
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('user1@contoso.com', 'user2@contoso.com') -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Result.Count | Should -Be 2
            $Result[0].Success | Should -Be $true
            $Result[0].UserId | Should -Be 'user1@contoso.com'
            $Result[1].Success | Should -Be $true
            $Result[1].UserId | Should -Be 'user2@contoso.com'
            $script:VerifyCallCount | Should -Be 2
        }
        
        It 'throws for infrastructure exceptions instead of returning structured failures' {
            Mock New-GraphBulkRequest {
                throw "Unexpected network error"
            }
            Mock Start-Sleep { }
            
            { Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' } } | Should -Throw -ExpectedMessage '*Unexpected error setting MFA State*'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match 'Unexpected error' }
        }
        
        It 'all failure messages start with "Failed:" and Success is explicitly false on all 7 failure paths' {
            # Path 1: Graph API error (403)
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{
                    id = 0
                    status = 403
                    body = [pscustomobject]@{ error = [pscustomobject]@{ message = 'Access denied' } }
                })
            }
            Mock Start-Sleep { }
            
            $Result1 = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user1@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result1[0].Message | Should -Match '^Failed:'
            $Result1[0].Success | Should -Be $false
            
            # Path 2: Graph API error (400)
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{
                    id = 0
                    status = 400
                    body = [pscustomobject]@{ error = [pscustomobject]@{ message = 'Bad request' } }
                })
            }
            
            $Result2 = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user2@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result2[0].Message | Should -Match '^Failed:'
            $Result2[0].Message | Should -Match 'Could not set'
            $Result2[0].Success | Should -Be $false
            
            # Path 3: No response received for user
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{ id = 99; status = 204; body = @{} })
            }
            
            $Result3 = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user3@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result3[0].Message | Should -Match '^Failed:'
            $Result3[0].Message | Should -Match 'No response received'
            $Result3[0].Success | Should -Be $false
            
            # Path 4: Unexpected response ID
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{ id = -1; status = 204; body = @{} })
            }
            
            $Result4 = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user4@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result4[0].Message | Should -Match '^Failed:'
            $Result4[0].Message | Should -Match 'unexpected response ID'
            $Result4[0].Success | Should -Be $false
            
            # Path 5: State did not change after PATCH
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'enforced' }
                    })
                }
            }
            
            $Result5 = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user5@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result5[0].Message | Should -Match '^Failed:'
            $Result5[0].Message | Should -Match 'did not change'
            $Result5[0].Success | Should -Be $false
            
            # Path 6: No verification response received
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    @([pscustomobject]@{ id = 99; status = 200; body = [pscustomobject]@{ perUserMfaState = 'disabled' } })
                }
            }
            
            $Result6 = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user6@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result6[0].Message | Should -Match '^Failed:'
            $Result6[0].Message | Should -Match 'No verification response'
            $Result6[0].Success | Should -Be $false
            
            # Path 7: Could not verify (verification exception)
            $script:VerifyCallCount = 0
            Mock New-GraphBulkRequest {
                $script:VerifyCallCount++
                if ($script:VerifyCallCount -eq 1) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    throw "Network error"
                }
            }
            
            $Result7 = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user7@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result7[0].Message | Should -Match '^Failed:'
            $Result7[0].Message | Should -Match 'Could not verify'
            $Result7[0].Success | Should -Be $false
        }
        
        It 'handles out-of-order batch responses correctly' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                if ($script:GraphCalls.Count -eq 1) {
                    # PATCH responses for 3 users, returned out of order
                    @(
                        [pscustomobject]@{ id = 2; status = 204; body = @{} }
                        [pscustomobject]@{ id = 0; status = 204; body = @{} }
                        [pscustomobject]@{ id = 1; status = 204; body = @{} }
                    )
                } else {
                    # Verification responses also out of order
                    @(
                        [pscustomobject]@{
                            id     = 1
                            status = 200
                            body   = [pscustomobject]@{ perUserMfaState = 'disabled' }
                        }
                        [pscustomobject]@{
                            id     = 2
                            status = 200
                            body   = [pscustomobject]@{ perUserMfaState = 'disabled' }
                        }
                        [pscustomobject]@{
                            id     = 0
                            status = 200
                            body   = [pscustomobject]@{ perUserMfaState = 'disabled' }
                        }
                    )
                }
            }
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('user0@contoso.com', 'user1@contoso.com', 'user2@contoso.com') -State 'disabled' -Headers @{ Authorization = 'Bearer token' }
            
            $Result.Count | Should -Be 3
            $Result[0].UserId | Should -Be 'user0@contoso.com'
            $Result[0].Success | Should -Be $true
            $Result[1].UserId | Should -Be 'user1@contoso.com'
            $Result[1].Success | Should -Be $true
            $Result[2].UserId | Should -Be 'user2@contoso.com'
            $Result[2].Success | Should -Be $true
        }
    }
}
