# Pester tests for Invoke-ExecAntiSpamPolicy response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecAntiSpamPolicy.ps1'
    $ToolsDir = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools'

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

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $FunctionPath
}

Describe 'Invoke-ExecAntiSpamPolicy' {
    It 'has .ROLE Exchange.SecurityPolicy.ReadWrite' {
        $Help = Get-Help Invoke-ExecAntiSpamPolicy
        $Help.Role | Should -Be 'Exchange.SecurityPolicy.ReadWrite'
    }

    It 'returns a success message when creating a new anti-spam policy' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiSpamPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter            = 'contoso.onmicrosoft.com'
                action                  = 'New'
                policyName              = 'CustomSpamPolicy'
                ruleName                = 'CustomSpamRule'
                priority                = 10
                bulkThreshold           = 7
                spamAction              = 'MoveToJmf'
                highConfidenceSpamAction = 'Quarantine'
            }
        }

        $response = Invoke-ExecAntiSpamPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Created anti-spam policy'
    }

    It 'returns a success message when updating an anti-spam policy' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiSpamPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter  = 'contoso.onmicrosoft.com'
                action        = 'Update'
                policyName    = 'CustomSpamPolicy'
                bulkThreshold = 6
            }
        }

        $response = Invoke-ExecAntiSpamPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Updated anti-spam policy'
    }
}
