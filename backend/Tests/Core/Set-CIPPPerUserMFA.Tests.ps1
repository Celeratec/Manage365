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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '020b75aa-9718-4e83-93ff-2a5bced7ef7f' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Result | Should -Not -BeNullOrEmpty
            $Result[0].UserId | Should -Be '020b75aa-9718-4e83-93ff-2a5bced7ef7f'
            $Result[0].Success | Should -Be $true
            $Result[0].Message | Should -Match 'Successfully set Per user MFA State to disabled for 020b75aa-9718-4e83-93ff-2a5bced7ef7f'
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
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('020b75aa-9718-4e83-93ff-2a5bced7ef7f', 'f3a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c') -State 'enabled' -Headers @{ Authorization = 'Bearer token' }
            
            $Result.Count | Should -Be 2
            $Result[0].UserId | Should -Be '020b75aa-9718-4e83-93ff-2a5bced7ef7f'
            $Result[0].Success | Should -Be $true
            $Result[1].UserId | Should -Be 'f3a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c'
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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '11111111-1111-1111-1111-111111111111' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '22222222-2222-2222-2222-222222222222' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'olumc.org' -userId 'cccccccc-cccc-cccc-cccc-cccccccccccc' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '22222222-2222-2222-2222-222222222222' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '22222222-2222-2222-2222-222222222222' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
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
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111') -State 'disabled' -Headers @{ Authorization = 'Bearer token' }
            
            $Result.Count | Should -Be 2
            $Result[0].UserId | Should -Be '22222222-2222-2222-2222-222222222222'
            $Result[0].Success | Should -Be $true
            $Result[1].UserId | Should -Be '11111111-1111-1111-1111-111111111111'
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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '22222222-2222-2222-2222-222222222222' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Success | Should -Be $false
            $Result[0].Message | Should -Match 'Failed:.*No response received.*22222222-2222-2222-2222-222222222222'
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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555') -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
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
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555') -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Result.Count | Should -Be 2
            $Result[0].Success | Should -Be $true
            $Result[0].UserId | Should -Be '44444444-4444-4444-4444-444444444444'
            $Result[1].Success | Should -Be $true
            $Result[1].UserId | Should -Be '55555555-5555-5555-5555-555555555555'
            $script:VerifyCallCount | Should -Be 2
        }
        
        It 'throws for infrastructure exceptions instead of returning structured failures' {
            # Reset shared state to make test deterministic
            $script:GraphCalls = [System.Collections.Generic.List[PSCustomObject]]::new()
            
            Mock New-GraphBulkRequest {
                throw "Unexpected network error"
            }
            Mock Start-Sleep { }
            Mock Get-CippException { [PSCustomObject]@{ NormalizedError = 'Unexpected network error' } }
            
            # Infrastructure exceptions throw without logging (callers will log)
            { Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '22222222-2222-2222-2222-222222222222' -State 'disabled' -Headers @{ Authorization = 'Bearer token' } } | Should -Throw -ExpectedMessage 'Failed: Unexpected error setting MFA State. Error: Unexpected network error'
            Should -Invoke Write-LogMessage -Times 0
        }
        
        It 'success path: message does NOT start with "Failed:" and Success=$true' {
            # Mutation test: adding 'Failed:' to success message or flipping Success to $false should fail
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'disabled' }
                    })
                }
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '33333333-3333-3333-3333-333333333333' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Message | Should -Not -Match '^Failed:'
            $Result[0].Message | Should -Be 'Successfully set Per user MFA State to disabled for 33333333-3333-3333-3333-333333333333'
            $Result[0].Success | Should -Be $true
        }
        
        It 'failure path 1: Graph API 403 has "Failed:" prefix and Success=$false' {
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{
                    id = 0
                    status = 403
                    body = [pscustomobject]@{ error = [pscustomobject]@{ message = 'Access denied' } }
                })
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '44444444-4444-4444-4444-444444444444' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Message | Should -Be 'Failed: Could not set MFA State to disabled for 44444444-4444-4444-4444-444444444444. Graph API returned status 403 : Access denied'
            $Result[0].Success | Should -Be $false
        }
        
        It 'failure path 2: Graph API 400 has "Failed:" prefix and Success=$false' {
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{
                    id = 0
                    status = 400
                    body = [pscustomobject]@{ error = [pscustomobject]@{ message = 'Bad request' } }
                })
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '55555555-5555-5555-5555-555555555555' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Message | Should -Be 'Failed: Could not set MFA State to disabled for 55555555-5555-5555-5555-555555555555. Graph API returned status 400 : Bad request'
            $Result[0].Success | Should -Be $false
        }
        
        It 'failure path 3: No response received has "Failed:" prefix and Success=$false' {
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{ id = 99; status = 204; body = @{} })
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '66666666-6666-6666-6666-666666666666' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Message | Should -Be 'Failed: No response received for 66666666-6666-6666-6666-666666666666 (request ID 0)'
            $Result[0].Success | Should -Be $false
        }
        
        It 'failure path 4: Unexpected response ID has "Failed:" prefix and Success=$false' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    @(
                        [pscustomobject]@{ id = -1; status = 204; body = @{} }
                        [pscustomobject]@{ id = 0; status = 204; body = @{} }
                    )
                } else {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'disabled' }
                    })
                }
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '77777777-7777-7777-7777-777777777777' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result.Count | Should -Be 2
            # Check out-of-range result
            $UnexpectedResult = $Result | Where-Object { $_.Message -match 'unexpected response ID' } | Select-Object -First 1
            $UnexpectedResult | Should -Not -BeNullOrEmpty
            $UnexpectedResult.Message | Should -Be 'Failed: Received unexpected response ID -1'
            $UnexpectedResult.Success | Should -Be $false
            # Check successful result
            $SuccessResult = $Result | Where-Object { $_.Success -eq $true } | Select-Object -First 1
            $SuccessResult | Should -Not -BeNullOrEmpty
            $SuccessResult.Message | Should -Be 'Successfully set Per user MFA State to disabled for 77777777-7777-7777-7777-777777777777'
            $SuccessResult.Success | Should -Be $true
        }
        
        It 'failure path 5: State did not change has "Failed:" prefix and Success=$false' {
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
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '88888888-8888-8888-8888-888888888888' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Message | Should -Be 'Failed: MFA State for 88888888-8888-8888-8888-888888888888 did not change to disabled after PATCH (status: enforced). The user may require special privileges or permissions.'
            $Result[0].Success | Should -Be $false
        }
        
        It 'failure path 6: No verification response has "Failed:" prefix and Success=$false' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    @([pscustomobject]@{ id = 99; status = 200; body = [pscustomobject]@{ perUserMfaState = 'disabled' } })
                }
            }
            Mock Start-Sleep { }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '99999999-9999-9999-9999-999999999999' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Message | Should -Be 'Failed: No verification response received for 99999999-9999-9999-9999-999999999999 (request ID 0)'
            $Result[0].Success | Should -Be $false
        }
        
        It 'failure path 7: Could not verify (exception) has "Failed:" prefix and Success=$false' {
            $script:VerifyCallCount = 0
            Mock New-GraphBulkRequest {
                $script:VerifyCallCount++
                if ($script:VerifyCallCount -eq 1) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    throw "Network error"
                }
            }
            Mock Start-Sleep { }
            Mock Get-CippException { [PSCustomObject]@{ NormalizedError = 'Network error' } }
            
            $Result = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            $Result[0].Message | Should -Be 'Failed: Could not verify MFA State for aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa. Error: Network error'
            $Result[0].Success | Should -Be $false
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
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555') -State 'disabled' -Headers @{ Authorization = 'Bearer token' }
            
            $Result.Count | Should -Be 3
            $Result[0].UserId | Should -Be 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            $Result[0].Success | Should -Be $true
            $Result[1].UserId | Should -Be '44444444-4444-4444-4444-444444444444'
            $Result[1].Success | Should -Be $true
            $Result[2].UserId | Should -Be '55555555-5555-5555-5555-555555555555'
            $Result[2].Success | Should -Be $true
        }
        
        It 'uses GUID directly without resolution when userId is a GUID' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    # First call should be PATCH, not resolution
                    $Requests[0].url | Should -BeLike 'users/020b75aa-9718-4e83-93ff-2a5bced7ef7f/*'
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    # Second call is verification
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'disabled' }
                    })
                }
            }
            Mock Start-Sleep { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId '020b75aa-9718-4e83-93ff-2a5bced7ef7f' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].UserId | Should -Be '020b75aa-9718-4e83-93ff-2a5bced7ef7f'
            $Results[0].Success | Should -Be $true
            Should -Invoke New-GraphBulkRequest -Times 2
        }
        
        It 'resolves UPN to object ID before PATCH when userId is a UPN' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    # First call is UPN resolution - must include userPrincipalName for exact match
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{
                            value = @(
                                [pscustomobject]@{ 
                                    id = '020b75aa-9718-4e83-93ff-2a5bced7ef7f'
                                    userPrincipalName = 'ryanadmin@olumc.org'
                                }
                            )
                        }
                    })
                } elseif ($script:GraphCalls.Count -eq 2) {
                    # Second call is PATCH with resolved GUID
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    # Third call is verification
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'disabled' }
                    })
                }
            }
            Mock Start-Sleep { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'ryanadmin@olumc.org' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].UserId | Should -Be 'ryanadmin@olumc.org'
            $Results[0].Success | Should -Be $true
            Should -Invoke New-GraphBulkRequest -Times 3
        }
        
        It 'reports error when UPN resolution finds zero matches' {
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{
                    id = 0
                    status = 200
                    body = [pscustomobject]@{
                        value = @()
                    }
                })
            }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'notfound@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].UserId | Should -Be 'notfound@contoso.com'
            $Results[0].Success | Should -Be $false
            $Results[0].Message | Should -Be 'Failed: User not found with UPN notfound@contoso.com'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match 'User not found' }
        }
        
        It 'reports error when UPN resolution finds multiple matches' {
            Mock New-GraphBulkRequest {
                @([pscustomobject]@{
                    id = 0
                    status = 200
                    body = [pscustomobject]@{
                        value = @(
                            [pscustomobject]@{ id = 'guid1' }
                            [pscustomobject]@{ id = 'guid2' }
                        )
                    }
                })
            }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'ambiguous@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].UserId | Should -Be 'ambiguous@contoso.com'
            $Results[0].Success | Should -Be $false
            $Results[0].Message | Should -Be 'Failed: More than one user found with UPN ambiguous@contoso.com'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match 'More than one user found' }
        }
        
        It 'reports error when userId is neither GUID nor UPN' {
            Mock New-GraphBulkRequest { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'invalid-format' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].UserId | Should -Be 'invalid-format'
            $Results[0].Success | Should -Be $false
            $Results[0].Message | Should -Be 'Failed: Invalid user identifier format for invalid-format (expected GUID or UPN)'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match 'Invalid user identifier format' }
            Should -Invoke New-GraphBulkRequest -Times 0
        }
        
        It 'escapes apostrophe in UPN for OData filter' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{
                            value = @(
                                [pscustomobject]@{ id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'; userPrincipalName = "user'test@contoso.com" }
                            )
                        }
                    })
                } elseif ($script:GraphCalls.Count -eq 2) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'disabled' }
                    })
                }
            }
            Mock Start-Sleep { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId "user'test@contoso.com" -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].Success | Should -Be $true
        }
        
        It 'URL-encodes ampersand in UPN for OData filter' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{
                            value = @(
                                [pscustomobject]@{ id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'; userPrincipalName = 'user&test@contoso.com' }
                            )
                        }
                    })
                } elseif ($script:GraphCalls.Count -eq 2) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'disabled' }
                    })
                }
            }
            Mock Start-Sleep { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user&test@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].Success | Should -Be $true
        }
        
        It 'handles guest #EXT# UPN correctly' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{
                            value = @(
                                [pscustomobject]@{ id = '10101010-1010-1010-1010-101010101010'; userPrincipalName = 'guest_contoso.com#EXT#@tenant.onmicrosoft.com' }
                            )
                        }
                    })
                } elseif ($script:GraphCalls.Count -eq 2) {
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'disabled' }
                    })
                }
            }
            Mock Start-Sleep { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'guest_contoso.com#EXT#@tenant.onmicrosoft.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].Success | Should -Be $true
        }
        
        It 'prevents OData injection attack' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                # Return zero matches - injection should not resolve to another user
                @([pscustomobject]@{
                    id = 0
                    status = 200
                    body = [pscustomobject]@{ value = @() }
                })
            }
            
            $InjectionPayload = "n@x' or startswith(displayName,'Victim') or userPrincipalName eq 'q"
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId $InjectionPayload -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].Success | Should -Be $false
            $Results[0].Message | Should -Be "Failed: User not found with UPN $InjectionPayload"
        }
        
        It 'rejects UPN when returned userPrincipalName does not match' {
            Mock New-GraphBulkRequest {
                # Simulate proxyAddresses match where returned UPN differs
                @([pscustomobject]@{
                    id = 0
                    status = 200
                    body = [pscustomobject]@{
                        value = @(
                            [pscustomobject]@{ id = 'other-user-guid'; userPrincipalName = 'realuser@contoso.com' }
                        )
                    }
                })
            }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'alias@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].Success | Should -Be $false
            $Results[0].Message | Should -Match 'Failed: UPN mismatch.*proxyAddresses'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match 'UPN mismatch' }
        }
        
        It 'reports error when UPN gets no response in resolve batch' {
            Mock New-GraphBulkRequest {
                # Return empty response array (no response for index 0)
                @()
            }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'missing@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].Success | Should -Be $false
            $Results[0].Message | Should -Be 'Failed: No resolution response received for UPN missing@contoso.com'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match 'No resolution response received' }
        }
        
        It 'handles mixed GUIDs and UPNs in bulk operations' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    # First call is UPN resolution (only for the UPN, not the GUID)
                    @([pscustomobject]@{
                        id = 1
                        status = 200
                        body = [pscustomobject]@{
                            value = @(
                                [pscustomobject]@{ 
                                    id = '12121212-1212-1212-1212-121212121212'
                                    userPrincipalName = 'user@contoso.com'
                                }
                            )
                        }
                    })
                } elseif ($script:GraphCalls.Count -eq 2) {
                    # Second call is PATCH for both users
                    @(
                        [pscustomobject]@{ id = 0; status = 204; body = @{} }
                        [pscustomobject]@{ id = 1; status = 204; body = @{} }
                    )
                } else {
                    # Third call is verification
                    @(
                        [pscustomobject]@{ id = 0; status = 200; body = [pscustomobject]@{ perUserMfaState = 'disabled' } }
                        [pscustomobject]@{ id = 1; status = 200; body = [pscustomobject]@{ perUserMfaState = 'disabled' } }
                    )
                }
            }
            Mock Start-Sleep { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('020b75aa-9718-4e83-93ff-2a5bced7ef7f', 'user@contoso.com') -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 2
            $Results[0].UserId | Should -Be '020b75aa-9718-4e83-93ff-2a5bced7ef7f'
            $Results[0].Success | Should -Be $true
            $Results[1].UserId | Should -Be 'user@contoso.com'
            $Results[1].Success | Should -Be $true
            
            # Verify calls
            $script:GraphCalls.Count | Should -Be 3
        }
    }
    
    Context 'Empty entry filtering' {
        It 'returns empty array when userId contains only empty entries' {
            Mock New-GraphBulkRequest { }
            Mock Start-Sleep { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('', '   ', $null) -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 0
            Should -Invoke New-GraphBulkRequest -Times 0
        }
        
        It 'filters empty entries from userId array' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                if ($script:GraphCalls.Count -eq 1) {
                    # Resolve UPN
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{
                            value = @([pscustomobject]@{ 
                                id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
                                userPrincipalName = 'user@contoso.com'
                            })
                        }
                    })
                } elseif ($script:GraphCalls.Count -eq 2) {
                    # PATCH
                    @([pscustomobject]@{ id = 0; status = 204; body = @{} })
                } else {
                    # Verification
                    @([pscustomobject]@{
                        id = 0
                        status = 200
                        body = [pscustomobject]@{ perUserMfaState = 'disabled' }
                    })
                }
            }
            Mock Start-Sleep { }
            
            $Results = @(Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('user@contoso.com', '', '   ') -State 'disabled' -Headers @{ Authorization = 'Bearer token' })
            
            $Results.Count | Should -Be 1
            $Results[0].UserId | Should -Be 'user@contoso.com'
            $Results[0].Success | Should -Be $true
        }
    }
}
