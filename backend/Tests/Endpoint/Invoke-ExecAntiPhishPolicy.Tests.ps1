# Pester tests for Invoke-ExecAntiPhishPolicy

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecAntiPhishPolicy.ps1'
    $ValidationPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Test-CippExchangeInputValidation.ps1'
    $ToolsDir = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools'

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
    $script:LastExoRequest = @{}
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
        $script:LastExoRequest = @{ TenantId = $tenantid; Cmdlet = $cmdlet; CmdParams = $cmdParams }
        if ($cmdlet -like 'Get-*') { return [pscustomobject]@{ EnableMailboxIntelligence = $true; PhishThresholdLevel = 2; Priority = 0 } }
        $true 
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $ValidationPath
    . $FunctionPath
}

Describe 'Invoke-ExecAntiPhishPolicy' {
    It 'creates a new anti-phishing policy' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiPhishPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter                    = 'contoso.onmicrosoft.com'
                action                          = 'New'
                policyName                      = 'CustomPhishPolicy'
                enableMailboxIntelligence       = $true
                enableTargetedDomainsProtection = $true
            }
        }
        $response = Invoke-ExecAntiPhishPolicy -Request $request -TriggerMetadata $null
        $response.StatusCode | Should -Be 200
        $response.Body.Results | Should -Match 'Created anti-phishing policy'
    }

    It 'validates policy name pattern' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiPhishPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'New'
                policyName   = 'Invalid<>Policy'
            }
        }
        $response = Invoke-ExecAntiPhishPolicy -Request $request -TriggerMetadata $null
        $response.Body.Results | Should -Match 'must match pattern'
    }
}
