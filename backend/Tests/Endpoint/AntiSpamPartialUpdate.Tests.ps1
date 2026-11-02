# Test to verify that Set-* custom policy updates only send provided fields

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $AntiSpamPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecAntiSpamPolicy.ps1'
    $ValidationPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Test-CippExchangeInputValidation.ps1'
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
    function Get-CippException { param($Exception) @{ NormalizedError = $Exception.Exception.Message } }
    function Get-CippNormalizedTenantFilter { param($TenantFilter) if ($TenantFilter -is [array] -and $TenantFilter.Count -eq 1) { $TenantFilter[0] } else { $TenantFilter } }
    function Test-CIPPAccess { param($Request, $TenantFilter) $true }
    
    $script:LastExoRequest = @{}
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
        $script:LastExoRequest = @{
            TenantId         = $tenantid
            Cmdlet           = $cmdlet
            CmdParams        = $cmdParams
            UseSystemMailbox = $useSystemMailbox
        }
        
        # For Get- cmdlets, return a mock policy
        if ($cmdlet -eq 'Get-HostedContentFilterPolicy') {
            return [pscustomobject]@{
                Identity                = $cmdParams.Identity
                BulkThreshold           = 7
                SpamAction              = 'MoveToJmf'
                HighConfidenceSpamAction = 'Quarantine'
                PhishSpamAction         = 'Quarantine'
                EnableLanguageBlockList = $false
                LanguageBlockList       = @()
            }
        }
        
        $true 
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $ValidationPath
    . $AntiSpamPath
}

Describe 'AntiSpam Partial Update Only Sends Provided Fields' {
    BeforeEach {
        $script:LastExoRequest = @{}
    }

    It 'Update with only BulkThreshold does not send SpamAction as $null' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiSpamPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter  = 'contoso.onmicrosoft.com'
                action        = 'Update'
                policyName    = 'TestPolicy'
                bulkThreshold = 5
                # Deliberately NOT including spamAction
            }
        }

        $response = Invoke-ExecAntiSpamPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        
        # Verify Set-HostedContentFilterPolicy was called
        $script:LastExoRequest.Cmdlet | Should -Be 'Set-HostedContentFilterPolicy'
        
        # Verify BulkThreshold was included
        $script:LastExoRequest.CmdParams.Keys | Should -Contain 'BulkThreshold'
        $script:LastExoRequest.CmdParams.BulkThreshold | Should -Be 5
        
        # Verify SpamAction was NOT included (not $null, just absent)
        $script:LastExoRequest.CmdParams.Keys | Should -Not -Contain 'SpamAction'
        
        # Verify HighConfidenceSpamAction was NOT included
        $script:LastExoRequest.CmdParams.Keys | Should -Not -Contain 'HighConfidenceSpamAction'
    }
}
