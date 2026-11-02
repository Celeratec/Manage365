# Pester tests for Invoke-ListEnhancedFiltering response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-ListEnhancedFiltering.ps1'
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
    
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) 
        if ($cmdlet -eq 'Get-InboundConnector') {
            return [pscustomobject]@{
                Identity     = 'Test Connector'
                EFSkipIPs    = @('192.168.1.1')
                EFSkipLastIP = $true
                EFUsers      = @('user@contoso.com')
            }
        }
        $null
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $TenantFilterPath
    . $FunctionPath
}

Describe 'Invoke-ListEnhancedFiltering' {
    It 'returns Enhanced Filtering settings' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ListEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Test Connector'
            }
        }

        $response = Invoke-ListEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Retrieved Enhanced Filtering settings'
        $response.Body.Settings | Should -Not -BeNullOrEmpty
        $response.Body.Settings.ConnectorIdentity | Should -Be 'Test Connector'
        $response.Body.Settings.Keys | Should -Contain 'EFSkipIPs'
        $response.Body.Settings.Keys | Should -Contain 'EFSkipLastIP'
        $response.Body.Settings.Keys | Should -Contain 'EFUsers'
    }

    It 'requires tenantFilter' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ListEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                connectorIdentity = 'Test Connector'
            }
        }

        $response = Invoke-ListEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'tenantFilter is required'
    }

    It 'requires connectorIdentity' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ListEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
            }
        }

        $response = Invoke-ListEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'connectorIdentity is required'
    }
}
