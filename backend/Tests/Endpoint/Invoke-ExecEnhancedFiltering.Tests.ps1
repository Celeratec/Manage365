# Pester tests for Invoke-ExecEnhancedFiltering response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-ExecEnhancedFiltering.ps1'
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
    
    $script:LastExoRequest = @{}
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
        $script:LastExoRequest = @{
            TenantId         = $tenantid
            Cmdlet           = $cmdlet
            CmdParams        = $cmdParams
            UseSystemMailbox = $useSystemMailbox
        }
        if ($cmdlet -eq 'Get-InboundConnector') {
            return [pscustomobject]@{
                Identity     = 'Test Connector'
                EFSkipIPs    = @()
                EFSkipLastIP = $false
                EFUsers      = @()
            }
        }
        $true 
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $TenantFilterPath
    . $ValidationPath
    . $FunctionPath
}

Describe 'Invoke-ExecEnhancedFiltering' {
    BeforeEach {
        $script:LastExoRequest = @{}
    }

    It 'returns a success message when configuring Enhanced Filtering' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Inbound from Mail Gateway'
                efSkipIPs         = @('192.168.1.1', '10.0.0.0/24')
                efSkipLastIP      = $true
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Enhanced Filtering configured'
    }

    It 'rejects 0.0.0.0/0 (overly broad IPv4 range)' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = @('0.0.0.0/0')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'must be /16 or more specific'
    }

    It 'rejects ::/0 (overly broad IPv6 range)' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = @('::/0')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'must be /32 or more specific'
    }

    It 'rejects shorthand IP like "1"' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = @('1')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'must be in dotted-quad notation'
    }

    It 'rejects more than 50 IP entries' {
        $tooManyIPs = 1..51 | ForEach-Object { "192.168.1.$_" }
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = $tooManyIPs
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'exceeds maximum of 50'
    }

    It 'rejects single string (not array) for efSkipIPs' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = '192.168.1.1'
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'must be an array'
    }

    It 'validates CIDR prefix lengths correctly' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = @('10.0.0.0/99')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Invalid CIDR prefix length'
    }

    It 'accepts IP ranges (a-b notation)' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = @('192.168.1.1-192.168.1.10')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Enhanced Filtering configured|No changes'
    }

    It 'rejects array tenantFilter with multiple values' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = @('tenant1.onmicrosoft.com', 'tenant2.onmicrosoft.com')
                connectorIdentity = 'Test Connector'
                efSkipIPs         = @('192.168.1.1')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'must be a single tenant'
    }

    It 'Get action returns current Enhanced Filtering settings' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                action            = 'Get'
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Retrieved Enhanced Filtering settings'
        $response.Body.Settings | Should -Not -BeNullOrEmpty
        $response.Body.Settings.ConnectorIdentity | Should -Be 'Test Connector'
        $response.Body.Settings.Keys | Should -Contain 'EFSkipIPs'
        $response.Body.Settings.Keys | Should -Contain 'EFSkipLastIP'
        $response.Body.Settings.Keys | Should -Contain 'EFUsers'
    }

    It 'rejects invalid action parameter' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                action            = 'Delete'
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'action must be Get or Set'
    }

    It 'rejects EFSkipIPs that overlap with HostedConnectionFilterPolicy IPAllowList' {
        # Mock New-ExoRequest to return a connection filter policy with IPAllowList
        Mock New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            $script:LastExoRequest = @{
                TenantId         = $tenantid
                Cmdlet           = $cmdlet
                CmdParams        = $cmdParams
                UseSystemMailbox = $useSystemMailbox
            }
            if ($cmdlet -eq 'Get-InboundConnector') {
                return [pscustomobject]@{
                    Identity     = 'Test Connector'
                    EFSkipIPs    = @()
                    EFSkipLastIP = $false
                    EFUsers      = @()
                }
            }
            if ($cmdlet -eq 'Get-HostedConnectionFilterPolicy') {
                return [pscustomobject]@{
                    IPAllowList = @('192.168.1.1', '10.0.0.0/24')
                    IPBlockList = @()
                }
            }
            $true
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = @('192.168.1.1', '172.16.0.0/16')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'overlaps with HostedConnectionFilterPolicy IPAllowList'
    }

    It 'rejects EFSkipIPs that overlap with HostedConnectionFilterPolicy IPBlockList' {
        # Mock New-ExoRequest to return a connection filter policy with IPBlockList
        Mock New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            $script:LastExoRequest = @{
                TenantId         = $tenantid
                Cmdlet           = $cmdlet
                CmdParams        = $cmdParams
                UseSystemMailbox = $useSystemMailbox
            }
            if ($cmdlet -eq 'Get-InboundConnector') {
                return [pscustomobject]@{
                    Identity     = 'Test Connector'
                    EFSkipIPs    = @()
                    EFSkipLastIP = $false
                    EFUsers      = @()
                }
            }
            if ($cmdlet -eq 'Get-HostedConnectionFilterPolicy') {
                return [pscustomobject]@{
                    IPAllowList = @()
                    IPBlockList = @('10.0.0.0/24')
                }
            }
            $true
        }

        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
                efSkipIPs         = @('10.0.0.0/24')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'overlaps with HostedConnectionFilterPolicy IPBlockList'
    }
}
