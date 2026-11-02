# Pester tests for Invoke-ListDefenderPresetPolicies

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Reports/Invoke-ListDefenderPresetPolicies.ps1'

    class HttpResponseContext {
        [int]$StatusCode
        [object]$Body
    }

    Add-Type -AssemblyName System.Net.Primitives
    $typeAccelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not $typeAccelerators::Get.Keys.Contains('HttpStatusCode')) {
        $typeAccelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Write-LogMessage { param($headers, $API, $message, $sev, $tenant) }
    function Get-CippException { param($Exception) @{ NormalizedError = $Exception.Message } }
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $useSystemMailbox) 
        @(
            [pscustomobject]@{ Identity = 'Standard Preset Security Policy'; State = 'Enabled'; Priority = 0 },
            [pscustomobject]@{ Identity = 'Strict Preset Security Policy'; State = 'Disabled'; Priority = 1 }
        )
    }

    . $FunctionPath
}

Describe 'Invoke-ListDefenderPresetPolicies' {
    It 'lists preset policies successfully' {
        $request = [pscustomobject]@{
            Query = @{ TenantFilter = 'contoso.onmicrosoft.com' }
            Headers = @{}
        }
        $response = Invoke-ListDefenderPresetPolicies -Request $request -TriggerMetadata $null
        $response.StatusCode | Should -Be 200
        $response.Body.Count | Should -BeGreaterThan 0
        $response.Body[0].RuleType | Should -Match 'EOP|ATP'
    }

    It 'does not return 500 on error' {
        function New-ExoRequest { throw 'Test error' }
        $request = [pscustomobject]@{
            Query = @{ TenantFilter = 'contoso.onmicrosoft.com' }
            Headers = @{}
        }
        $response = Invoke-ListDefenderPresetPolicies -Request $request -TriggerMetadata $null
        $response.StatusCode | Should -Be 200
        $response.Body.Results | Should -Match 'Failed'
    }
}
