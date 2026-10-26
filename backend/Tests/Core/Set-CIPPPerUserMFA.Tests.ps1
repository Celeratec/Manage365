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
                
                # First call is PATCH, second is GET verification
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
                    # GET verification response
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
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' }
            
            $Result | Should -Not -BeNullOrEmpty
            $Result[0] | Should -Match 'Successfully set Per user MFA State to disabled for user@contoso.com'
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Info' -and $message -match 'Successfully' }
        }
        
        It 'handles multiple users in bulk operations' {
            Mock New-GraphBulkRequest {
                $script:GraphCalls.Add([pscustomobject]@{ Requests = $Requests })
                
                # First call is bulk PATCH, subsequent calls are individual GET verifications
                if ($script:GraphCalls.Count -eq 1) {
                    # PATCH responses for 2 users
                    @(
                        [pscustomobject]@{ id = 0; status = 204; body = @{} }
                        [pscustomobject]@{ id = 1; status = 204; body = @{} }
                    )
                } else {
                    # GET verification response
                    @(
                        [pscustomobject]@{
                            id     = 0
                            status = 200
                            body   = [pscustomobject]@{ perUserMfaState = 'enabled' }
                        }
                    )
                }
            }
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId @('user1@contoso.com', 'user2@contoso.com') -State 'enabled' -Headers @{ Authorization = 'Bearer token' }
            
            $Result.Count | Should -Be 2
            $Result[0] | Should -Match 'Successfully.*user1@contoso.com'
            $Result[1] | Should -Match 'Successfully.*user2@contoso.com'
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
            
            { Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'admin@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' } } | Should -Throw
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
            
            { Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'invalid' -Headers @{ Authorization = 'Bearer token' } } | Should -Throw -ExpectedMessage '*400*Invalid request*'
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
            
            { Set-CIPPPerUserMFA -TenantFilter 'olumc.org' -userId 'ryanadmin@olumc.org' -State 'disabled' -Headers @{ Authorization = 'Bearer token' } } | Should -Throw
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter { $sev -eq 'Error' -and $message -match 'did not change' }
            Should -Invoke Start-Sleep -Times 3
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
            
            { Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' } } | Should -Throw
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
                    # Second verification returns correct state
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
            
            $Result = Set-CIPPPerUserMFA -TenantFilter 'contoso.onmicrosoft.com' -userId 'user@contoso.com' -State 'disabled' -Headers @{ Authorization = 'Bearer token' }
            $Result[0] | Should -Match 'Successfully'
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
                    # GET verification for the successful one
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
            $Result[0] | Should -Match 'Successfully.*user@contoso.com'
            $Result[1] | Should -Match 'Failed.*admin@contoso.com.*403'
        }
    }
}
