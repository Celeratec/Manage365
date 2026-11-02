# Pester tests for Invoke-ExecFocusedInboxOverride

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Tools/Invoke-ExecFocusedInboxOverride.ps1'
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
    $script:LastGraphRequest = @{}
    function New-GraphPOSTRequest { 
        param($uri, $tenantid, $body, $type) 
        $script:LastGraphRequest = @{ Uri = $uri; TenantId = $tenantid; Body = $body; Type = $type }
        [pscustomobject]@{ id = 'override-id-123' }
    }
    function New-GraphGetRequest { 
        param($uri, $tenantid) 
        $script:LastGraphRequest = @{ Uri = $uri; TenantId = $tenantid }
        @([pscustomobject]@{ id = 'override-id-123'; senderEmailAddress = @{ address = 'sender@example.com' }; classifyAs = 'focused' })
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $TenantFilterPath
    . $ValidationPath
    . $FunctionPath
}

Describe 'Invoke-ExecFocusedInboxOverride' {
    BeforeEach {
        $script:LastGraphRequest = @{}
    }

    It 'adds a focused inbox override' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecFocusedInboxOverride' }
            Headers = @{}
            Body    = @{
                tenantFilter       = 'contoso.onmicrosoft.com'
                userPrincipalName  = 'user@contoso.com'
                action             = 'Add'
                senderEmailAddress = 'sender@example.com'
                classifyAs         = 'focused'
            }
        }
        $response = Invoke-ExecFocusedInboxOverride -Request $request -TriggerMetadata $null
        $response.StatusCode | Should -Be 200
        $response.Body.Results | Should -Match 'Added Focused Inbox override'
        $script:LastGraphRequest.Uri | Should -Match 'user%40contoso.com'
    }

    It 'prevents UPN path injection' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecFocusedInboxOverride' }
            Headers = @{}
            Body    = @{
                tenantFilter       = 'contoso.onmicrosoft.com'
                userPrincipalName  = '../../../etc/passwd'
                action             = 'List'
            }
        }
        $response = Invoke-ExecFocusedInboxOverride -Request $request -TriggerMetadata $null
        $response.StatusCode | Should -Be 200
        $response.Body.Results | Should -Match 'must be a valid email'
    }

    It 'validates sender email address' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecFocusedInboxOverride' }
            Headers = @{}
            Body    = @{
                tenantFilter       = 'contoso.onmicrosoft.com'
                userPrincipalName  = 'user@contoso.com'
                action             = 'Add'
                senderEmailAddress = 'not-an-email'
                classifyAs         = 'focused'
            }
        }
        $response = Invoke-ExecFocusedInboxOverride -Request $request -TriggerMetadata $null
        $response.StatusCode | Should -Be 200
        $response.Body.Results | Should -Match 'Invalid email'
    }
}
