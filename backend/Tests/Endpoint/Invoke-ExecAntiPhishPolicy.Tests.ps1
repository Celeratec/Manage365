# Pester tests for Invoke-ExecAntiPhishPolicy

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecAntiPhishPolicy.ps1'
    $RemoveFunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecRemoveAntiPhishPolicy.ps1'
    $ValidationPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Test-CippExchangeInputValidation.ps1'
    $TenantFilterPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Get-CippNormalizedTenantFilter.ps1'
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
    function Get-CippException { param($Exception) @{ NormalizedError = $Exception.Exception.Message } }
    $script:ExoRequestHistory = @()
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
        $script:ExoRequestHistory += @{ TenantId = $tenantid; Cmdlet = $cmdlet; CmdParams = $cmdParams }
        if ($cmdlet -like 'Get-*') { return [pscustomobject]@{ EnableMailboxIntelligence = $true; PhishThresholdLevel = 2; Priority = 0 } }
        $true 
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $TenantFilterPath
    . $ValidationPath
    . $FunctionPath
    . $RemoveFunctionPath
}

Describe 'Invoke-ExecAntiPhishPolicy' {
    BeforeEach {
        $script:ExoRequestHistory = @()
    }

    It 'creates a new anti-phishing policy' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAntiPhishPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter                    = 'contoso.onmicrosoft.com'
                action                          = 'New'
                policyName                      = 'CustomPhishPolicy'
                ruleName                        = 'CustomPhishRule'
                priority                        = 10
                enableMailboxIntelligence       = $true
                enableTargetedDomainsProtection = $true
            }
        }
        $response = Invoke-ExecAntiPhishPolicy -Request $request -TriggerMetadata $null
        $response.StatusCode | Should -Be 200
        $response.Body.Results | Should -Match 'Created anti-phishing policy'

        # Assert cmdlets
        $script:ExoRequestHistory | Should -HaveCount 2
        $script:ExoRequestHistory[0].Cmdlet | Should -Be 'New-AntiPhishPolicy'
        $script:ExoRequestHistory[1].Cmdlet | Should -Be 'New-AntiPhishRule'

        # Assert parameters
        $script:ExoRequestHistory[0].CmdParams.Name | Should -Be 'CustomPhishPolicy'
        $script:ExoRequestHistory[0].CmdParams.EnableMailboxIntelligence | Should -Be $true
        $script:ExoRequestHistory[0].CmdParams.EnableTargetedDomainsProtection | Should -Be $true
        $script:ExoRequestHistory[1].CmdParams.Name | Should -Be 'CustomPhishRule'
        $script:ExoRequestHistory[1].CmdParams.AntiPhishPolicy | Should -Be 'CustomPhishPolicy'
        $script:ExoRequestHistory[1].CmdParams.Priority | Should -Be 10
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

    It 'Remove action gets policy first then removes it' {
        # Mock Get to return a custom policy
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
            $script:ExoRequestHistory += @{ TenantId = $tenantid; Cmdlet = $cmdlet; CmdParams = $cmdParams }
            if ($cmdlet -eq 'Get-AntiPhishPolicy') {
                return [pscustomobject]@{ 
                    Identity = $cmdParams.Identity
                    IsDefault = $false
                    RecommendedPolicyType = 'Custom'
                }
            }
            if ($cmdlet -eq 'Get-AntiPhishRule') {
                return [pscustomobject]@{
                    Identity = 'TestPolicy'
                    AntiPhishPolicy = 'TestPolicy'
                }
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecRemoveAntiPhishPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                policyName   = 'TestPolicy'
            }
        }

        $response = Invoke-ExecRemoveAntiPhishPolicy -Request $request -TriggerMetadata $null
        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        
        $script:ExoRequestHistory[0].Cmdlet | Should -Be 'Get-AntiPhishPolicy'
        
        # Assert rule is removed before policy
        $removeRuleIndex = ($script:ExoRequestHistory | ForEach-Object { $i = 0 } { if ($_.Cmdlet -eq 'Remove-AntiPhishRule') { $i }; $i++ }) | Select-Object -First 1
        $removePolicyIndex = ($script:ExoRequestHistory | ForEach-Object { $i = 0 } { if ($_.Cmdlet -eq 'Remove-AntiPhishPolicy') { $i }; $i++ }) | Select-Object -First 1
        $removeRuleIndex | Should -Not -BeNullOrEmpty
        $removePolicyIndex | Should -Not -BeNullOrEmpty
        $removeRuleIndex | Should -BeLessThan $removePolicyIndex
        
        ($script:ExoRequestHistory | Where-Object { $_.Cmdlet -eq 'Remove-AntiPhishPolicy' }).CmdParams.Confirm | Should -Be $false
    }

    It 'Remove refuses default policy' {
        $script:ExoRequestHistory = @()
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
            $script:ExoRequestHistory += @{ Cmdlet = $cmdlet }
            if ($cmdlet -eq 'Get-AntiPhishPolicy') {
                return [pscustomobject]@{ IsDefault = $true; RecommendedPolicyType = 'Custom' }
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecRemoveAntiPhishPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                policyName   = 'Default'
            }
        }

        $response = Invoke-ExecRemoveAntiPhishPolicy -Request $request -TriggerMetadata $null
        $response.Body.Results | Should -Match 'Cannot remove default policy'
        
        # Assert no Remove cmdlets were called
        $script:ExoRequestHistory | Where-Object { $_.Cmdlet -like 'Remove-*' } | Should -BeNullOrEmpty
    }

    It 'Remove refuses built-in policy' {
        $script:ExoRequestHistory = @()
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            $script:ExoRequestHistory += @{ Cmdlet = $cmdlet }
            if ($cmdlet -eq 'Get-AntiPhishPolicy') {
                return [pscustomobject]@{ IsDefault = $false; RecommendedPolicyType = 'BuiltIn' }
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecRemoveAntiPhishPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                policyName   = 'BuiltInPolicy'
            }
        }

        $response = Invoke-ExecRemoveAntiPhishPolicy -Request $request -TriggerMetadata $null
        $response.Body.Results | Should -Match 'Only custom policies can be removed'
        
        # Assert no Remove cmdlets were called
        $script:ExoRequestHistory | Where-Object { $_.Cmdlet -like 'Remove-*' } | Should -BeNullOrEmpty
    }

    It 'Remove refuses Standard preset policy' {
        $script:ExoRequestHistory = @()
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            $script:ExoRequestHistory += @{ Cmdlet = $cmdlet }
            if ($cmdlet -eq 'Get-AntiPhishPolicy') {
                return [pscustomobject]@{ IsDefault = $false; RecommendedPolicyType = 'Standard' }
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecRemoveAntiPhishPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                policyName   = 'Standard Preset Security Policy'
            }
        }

        $response = Invoke-ExecRemoveAntiPhishPolicy -Request $request -TriggerMetadata $null
        $response.Body.Results | Should -Match 'Only custom policies can be removed'
        
        # Assert no Remove cmdlets were called
        $script:ExoRequestHistory | Where-Object { $_.Cmdlet -like 'Remove-*' } | Should -BeNullOrEmpty
    }

    It 'Remove refuses Strict preset policy' {
        $script:ExoRequestHistory = @()
        function New-ExoRequest { 
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            $script:ExoRequestHistory += @{ Cmdlet = $cmdlet }
            if ($cmdlet -eq 'Get-AntiPhishPolicy') {
                return [pscustomobject]@{ IsDefault = $false; RecommendedPolicyType = 'Strict' }
            }
            $true 
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecRemoveAntiPhishPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                policyName   = 'Strict Preset Security Policy'
            }
        }

        $response = Invoke-ExecRemoveAntiPhishPolicy -Request $request -TriggerMetadata $null
        $response.Body.Results | Should -Match 'Only custom policies can be removed'
        
        # Assert no Remove cmdlets were called
        $script:ExoRequestHistory | Where-Object { $_.Cmdlet -like 'Remove-*' } | Should -BeNullOrEmpty
    }
}
