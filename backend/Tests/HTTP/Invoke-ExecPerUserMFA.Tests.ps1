BeforeAll {
    $BackendRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $ModulesRoot = Join-Path $BackendRoot 'Modules'
    
    class HttpResponseContext { [int]$StatusCode; [object]$Body }
    $TypeAccelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not ([System.Management.Automation.PSTypeName]'HttpStatusCode').Type) {
        $TypeAccelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }
    
    Import-Module (Join-Path $ModulesRoot 'CIPPHTTP/CIPPHTTP.psd1') -Force
    Import-Module (Join-Path $ModulesRoot 'CIPPCore/CIPPCore.psd1') -Force
    
    # Mock logging and table infrastructure to avoid dependencies
    Mock Write-LogMessage { } -ModuleName CIPPCore
    Mock Write-LogMessage { } -ModuleName CIPPHTTP
}

Describe 'Invoke-ExecPerUserMFA' {
    BeforeEach {
        Mock Set-CIPPPerUserMFA { }
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
    
    It 'returns 400 when Set-CIPPPerUserMFA returns zero results' -Skip {
        Mock Set-CIPPPerUserMFA { , @() }
        Mock Get-CippException { [PSCustomObject]@{ NormalizedError = 'test error' } }
        
        $Request = [PSCustomObject]@{
            Headers = @{ Authorization = 'Bearer token' }
            Params  = @{ CIPPEndpoint = 'ExecPerUserMFA' }
            Body    = @{
                userPrincipalName = 'user@contoso.com'
                tenantFilter      = 'contoso.onmicrosoft.com'
                State             = 'disabled'
            }
        }
        
        $Response = Invoke-ExecPerUserMFA -Request $Request
        
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results[0] | Should -Be 'Failed: No users were processed. Please check the request parameters.'
    }
}
