# Pester tests for Invoke-ExecDefenderPresetPolicy response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecDefenderPresetPolicy.ps1'
    $ValidationPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Test-CippExchangeInputValidation.ps1'
    $TenantFilterPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Get-CippNormalizedTenantFilter.ps1'

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
    
    $script:LastExoRequest = @{}
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
        $script:LastExoRequest = @{
            TenantId         = $tenantid
            Cmdlet           = $cmdlet
            CmdParams        = $cmdParams
            UseSystemMailbox = $useSystemMailbox
        }
        # Return mock rule for Get cmdlets
        if ($cmdlet -like 'Get-*') {
            return [pscustomobject]@{
                Identity                   = 'Standard Preset Security Policy'
                State                      = 'Enabled'
                SentTo                     = @()
                SentToMemberOf             = @()
                RecipientDomainIs          = @()
                ExceptIfSentTo             = @()
                ExceptIfSentToMemberOf     = @()
                ExceptIfRecipientDomainIs  = @()
            }
        }
        $true
    }

    . $TenantFilterPath
    . $ValidationPath
    . $FunctionPath
}

Describe 'Invoke-ExecDefenderPresetPolicy' {
    BeforeEach {
        $script:LastExoRequest = @{}
    }

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
        $script:LastExoRequest.Cmdlet | Should -Be 'Enable-EOPProtectionPolicyRule'
        $script:LastExoRequest.CmdParams.Identity | Should -Be 'Standard Preset Security Policy'
    }

    It 'returns a success message when disabling a strict preset policy' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDefenderPresetPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'Disable'
                policyType   = 'Strict'
                ruleType     = 'ATP'
            }
        }

        $response = Invoke-ExecDefenderPresetPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Disabled'
        $script:LastExoRequest.Cmdlet | Should -Be 'Disable-ATPProtectionPolicyRule'
        $script:LastExoRequest.CmdParams.Identity | Should -Be 'Strict Preset Security Policy'
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

    It 'validates action enum' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDefenderPresetPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action       = 'InvalidAction'
                policyType   = 'Standard'
                ruleType     = 'EOP'
            }
        }

        $response = Invoke-ExecDefenderPresetPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'action must be'
    }

    It 'rejects array tenantFilter with multiple values' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDefenderPresetPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter = @('tenant1.onmicrosoft.com', 'tenant2.onmicrosoft.com')
                action       = 'Enable'
                policyType   = 'Standard'
                ruleType     = 'EOP'
            }
        }

        $response = Invoke-ExecDefenderPresetPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'must be a single tenant'
    }

    It 'supports rescoping with validated email addresses' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDefenderPresetPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                action            = 'Rescope'
                policyType        = 'Standard'
                ruleType          = 'EOP'
                sentTo            = @('user@contoso.com')
                recipientDomainIs = @('contoso.com')
            }
        }

        $response = Invoke-ExecDefenderPresetPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Rescoped|No changes'
    }

    It 'reports no changes when rescoping to same values' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDefenderPresetPolicy' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                action            = 'Rescope'
                policyType        = 'Standard'
                ruleType          = 'EOP'
                sentTo            = @()
                recipientDomainIs = @()
            }
        }

        $response = Invoke-ExecDefenderPresetPolicy -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'No changes'
    }
}
