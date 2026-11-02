# Pester tests for Invoke-ExecEnhancedFiltering response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-ExecEnhancedFiltering.ps1'
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

Describe 'Invoke-ExecEnhancedFiltering' {
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

    It 'validates IP addresses in EFSkipIPs' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Inbound from Mail Gateway'
                efSkipIPs         = @('invalid-ip')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Invalid IP address'
    }

    It 'validates CIDR notation in EFSkipIPs' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecEnhancedFiltering' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                connectorIdentity = 'Inbound from Mail Gateway'
                efSkipIPs         = @('10.0.0.0/99')
            }
        }

        $response = Invoke-ExecEnhancedFiltering -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Invalid CIDR prefix length'
    }
}
