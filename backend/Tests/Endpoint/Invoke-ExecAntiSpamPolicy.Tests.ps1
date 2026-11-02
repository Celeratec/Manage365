# Pester tests for Invoke-ExecAntiSpamPolicy response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecAntiSpamPolicy.ps1'
    $ValidationPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Test-CippExchangeInputValidation.ps1'
    $TenantFilterPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Get-CippNormalizedTenantFilter.ps1'
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
    $script:ExoRequestHistory = @()
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
        $script:ExoRequestHistory += @{ TenantId = $tenantid; Cmdlet = $cmdlet; CmdParams = $cmdParams }
        if ($cmdlet -eq 'Get-AcceptedDomain') { return @([pscustomobject]@{ DomainName = 'contoso.onmicrosoft.com' }) }
        $true 
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $ValidationPath
    . $TenantFilterPath
    . $FunctionPath
}

Describe 'Invoke-ExecAntiSpamPolicy' {
    BeforeEach {
        $script:ExoRequestHistory = @()
    }

    It 'has .ROLE Exchange.SecurityPolicy.ReadWrite' {
        $Help = Get-Help Invoke-ExecAntiSpamPolicy
        $Help.Role | Should -Be 'Exchange.SecurityPolicy.ReadWrite'
    }

    It 'returns a success message when creating a new anti-spam policy' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiSpamPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter             = 'contoso.onmicrosoft.com'
                action                   = 'New'
                policyName               = 'CustomSpamPolicy'
                ruleName                 = 'CustomSpamRule'
                priority                 = 10
                bulkThreshold            = 7
                spamAction               = 'MoveToJmf'
                highConfidenceSpamAction = 'Quarantine'
            }
        }

        $response = Invoke-ExecAntiSpamPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Created anti-spam policy'

        # Assert cmdlets
        $script:ExoRequestHistory | Should -HaveCount 2
        $script:ExoRequestHistory[0].Cmdlet | Should -Be 'New-HostedContentFilterPolicy'
        $script:ExoRequestHistory[1].Cmdlet | Should -Be 'New-HostedContentFilterRule'

        # Assert parameters
        $script:ExoRequestHistory[0].CmdParams.Name | Should -Be 'CustomSpamPolicy'
        $script:ExoRequestHistory[0].CmdParams.BulkThreshold | Should -Be 7
        $script:ExoRequestHistory[0].CmdParams.SpamAction | Should -Be 'MoveToJmf'
        $script:ExoRequestHistory[0].CmdParams.HighConfidenceSpamAction | Should -Be 'Quarantine'
        $script:ExoRequestHistory[1].CmdParams.Name | Should -Be 'CustomSpamRule'
        $script:ExoRequestHistory[1].CmdParams.HostedContentFilterPolicy | Should -Be 'CustomSpamPolicy'
        $script:ExoRequestHistory[1].CmdParams.Priority | Should -Be 10
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

        # Assert cmdlets
        $script:ExoRequestHistory | Should -Not -BeNullOrEmpty
        $SetCall = $script:ExoRequestHistory | Where-Object { $_.Cmdlet -eq 'Set-HostedContentFilterPolicy' }
        $SetCall | Should -Not -BeNullOrEmpty

        # Assert parameters
        $SetCall.CmdParams.Identity | Should -Be 'CustomSpamPolicy'
        $SetCall.CmdParams.BulkThreshold | Should -Be 6
    }

    It 'Remove action gets policy, removes rule, then removes policy' {
        # Mock Get to return a custom policy
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
            $script:ExoRequestHistory += @{ TenantId = $tenantid; Cmdlet = $cmdlet; CmdParams = $cmdParams }
            if ($cmdlet -eq 'Get-HostedContentFilterPolicy') {
                return [pscustomobject]@{ 
                    Identity = $cmdParams.Identity
                    IsDefault = $false
                    RecommendedPolicyType = 'Custom'
                }
            }
            if ($cmdlet -eq 'Get-HostedContentFilterRule') {
                return @([pscustomobject]@{ Name = 'TestRule'; HostedContentFilterPolicy = 'TestPolicy' })
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiSpamPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'Remove'
                policyName   = 'TestPolicy'
            }
        }

        $response = Invoke-ExecAntiSpamPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        
        # Assert cmdlets in order: Get-Policy, Get-Rule, Remove-Rule, Remove-Policy
        $script:ExoRequestHistory | Should -Not -BeNullOrEmpty
        $script:ExoRequestHistory[0].Cmdlet | Should -Be 'Get-HostedContentFilterPolicy'
        $script:ExoRequestHistory[1].Cmdlet | Should -Be 'Get-HostedContentFilterRule'
        $script:ExoRequestHistory[2].Cmdlet | Should -Be 'Remove-HostedContentFilterRule'
        $script:ExoRequestHistory[2].CmdParams.Confirm | Should -Be $false
        $script:ExoRequestHistory[3].Cmdlet | Should -Be 'Remove-HostedContentFilterPolicy'
        $script:ExoRequestHistory[3].CmdParams.Confirm | Should -Be $false
    }

    It 'Remove refuses default policy' {
        # Mock Get to return a default policy
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
            if ($cmdlet -eq 'Get-HostedContentFilterPolicy') {
                return [pscustomobject]@{ 
                    Identity = $cmdParams.Identity
                    IsDefault = $true
                    RecommendedPolicyType = 'Custom'
                }
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiSpamPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'Remove'
                policyName   = 'DefaultPolicy'
            }
        }

        $response = Invoke-ExecAntiSpamPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Cannot remove default policy'
    }

    It 'Remove refuses built-in policy' {
        # Mock Get to return a built-in policy
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
            if ($cmdlet -eq 'Get-HostedContentFilterPolicy') {
                return [pscustomobject]@{ 
                    Identity = $cmdParams.Identity
                    IsDefault = $false
                    RecommendedPolicyType = 'Standard'
                }
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiSpamPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'Remove'
                policyName   = 'StandardPolicy'
            }
        }

        $response = Invoke-ExecAntiSpamPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Only custom policies can be removed'
    }

    It 'Remove refuses preset policy' {
        # Mock Get to return a preset policy
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
            if ($cmdlet -eq 'Get-HostedContentFilterPolicy') {
                return [pscustomobject]@{ 
                    Identity = $cmdParams.Identity
                    IsDefault = $false
                    RecommendedPolicyType = 'Strict'
                }
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiSpamPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'Remove'
                policyName   = 'StrictPolicy'
            }
        }

        $response = Invoke-ExecAntiSpamPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Only custom policies can be removed'
    }
}
