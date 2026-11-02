# Pester tests for Invoke-ExecFocusedInbox response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Tools/Invoke-ExecFocusedInbox.ps1'
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
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams, $Anchor) 
        if ($cmdlet -eq 'Get-FocusedInbox') {
            return [pscustomobject]@{ FocusedInboxOn = $true }
        }
        $true 
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $FunctionPath
}

Describe 'Invoke-ExecFocusedInbox' {
    It 'returns focused inbox state when action is Get' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecFocusedInbox' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                userPrincipalName = 'user@contoso.com'
                action            = 'Get'
            }
        }

        $response = Invoke-ExecFocusedInbox -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.FocusedInboxOn | Should -Be $true
    }

    It 'returns a success message when enabling Focused Inbox' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecFocusedInbox' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                userPrincipalName = 'user@contoso.com'
                action            = 'Enable'
            }
        }

        $response = Invoke-ExecFocusedInbox -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Focused Inbox Enabled'
    }

    It 'returns a success message when disabling Focused Inbox' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecFocusedInbox' }
            Headers = @{}
            Body    = @{
                tenantFilter      = 'contoso.onmicrosoft.com'
                userPrincipalName = 'user@contoso.com'
                action            = 'Disable'
            }
        }

        $response = Invoke-ExecFocusedInbox -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Focused Inbox Disabled'
    }
}
