# Pester tests for Invoke-ExecDefenderPresetPolicy response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecDefenderPresetPolicy.ps1'

    class HttpResponseContext {
        [int]$StatusCode
        [object]$Body
    }

    Add-Type -AssemblyName System.Net.Primitives
    Add-Type -AssemblyName System.Net.Http
    $typeAccelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not $typeAccelerators::Get.Keys.Contains('HttpStatusCode')) {
        $typeAccelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Write-LogMessage { param($headers, $API, $message, $sev, $tenant) }
    function Get-CippException { param($Exception) @{ NormalizedError = $Exception.Message } }
    function New-ExoRequest { param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) $true }

    . $FunctionPath
}

Describe 'Invoke-ExecDefenderPresetPolicy' {
    It 'returns a success message when enabling a preset policy' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDefenderPresetPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'Enable'
                policyType   = 'Standard'
                ruleType     = 'EOP'
            }
        }

        $response = Invoke-ExecDefenderPresetPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Enabled'
    }

    It 'returns a success message when disabling a preset policy' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDefenderPresetPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'Disable'
                policyType   = 'Strict'
                ruleType     = 'Both'
            }
        }

        $response = Invoke-ExecDefenderPresetPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Disabled'
    }

    It 'validates required parameters' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDefenderPresetPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = ''
            }
        }

        $response = Invoke-ExecDefenderPresetPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'required'
    }
}
