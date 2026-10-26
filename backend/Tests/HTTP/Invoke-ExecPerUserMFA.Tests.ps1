BeforeAll {
    $BackendRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $ModulesRoot = Join-Path $BackendRoot 'Modules'
    Import-Module (Join-Path $ModulesRoot 'CIPPHTTP/CIPPHTTP.psd1') -Force
    Import-Module (Join-Path $ModulesRoot 'CIPPCore/CIPPCore.psd1') -Force
}

Describe 'Invoke-ExecPerUserMFA' {
    BeforeEach {
        Mock Set-CIPPPerUserMFA { }
        Mock Write-LogMessage { }
    }

    It 'returns 400 when userPrincipalName is null' {
        $Request = [PSCustomObject]@{
            Headers = @{ Authorization = 'Bearer token' }
            Params  = @{ CIPPEndpoint = 'ExecPerUserMFA' }
            Body    = @{
                userPrincipalName = $null
                tenantFilter      = 'contoso.onmicrosoft.com'
                State             = 'disabled'
            }
        }
        
        $Response = Invoke-ExecPerUserMFA -Request $Request
        
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results[0] | Should -Be 'Failed: No users were processed. Please check the request parameters.'
        Should -Invoke Set-CIPPPerUserMFA -Times 0
    }

    It 'returns 400 when userPrincipalName is empty string' {
        $Request = [PSCustomObject]@{
            Headers = @{ Authorization = 'Bearer token' }
            Params  = @{ CIPPEndpoint = 'ExecPerUserMFA' }
            Body    = @{
                userPrincipalName = ''
                tenantFilter      = 'contoso.onmicrosoft.com'
                State             = 'disabled'
            }
        }
        
        $Response = Invoke-ExecPerUserMFA -Request $Request
        
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results[0] | Should -Be 'Failed: No users were processed. Please check the request parameters.'
        Should -Invoke Set-CIPPPerUserMFA -Times 0
    }

    It 'returns 400 when userPrincipalName is whitespace' {
        $Request = [PSCustomObject]@{
            Headers = @{ Authorization = 'Bearer token' }
            Params  = @{ CIPPEndpoint = 'ExecPerUserMFA' }
            Body    = @{
                userPrincipalName = '   '
                tenantFilter      = 'contoso.onmicrosoft.com'
                State             = 'disabled'
            }
        }
        
        $Response = Invoke-ExecPerUserMFA -Request $Request
        
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results[0] | Should -Be 'Failed: No users were processed. Please check the request parameters.'
        Should -Invoke Set-CIPPPerUserMFA -Times 0
    }
}
