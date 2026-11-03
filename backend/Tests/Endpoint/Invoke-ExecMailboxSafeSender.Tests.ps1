# Pester tests for Invoke-ExecMailboxSafeSender response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecMailboxSafeSender.ps1'
    $ToolsDir = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools'
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Private/MailFilter/MailFilter.Common.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/MailFilter/Join-CIPPMailboxJunkSenderList.ps1')

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

    function Write-LogMessage { param($headers, $API, $message, $sev) }
    function Get-CippException { param($Exception) @{ NormalizedError = $Exception.Message } }
    $script:SafeSenderWrites = @()
    function New-ExoRequest {
        param($tenantid, $cmdlet, $cmdParams, $Anchor, $useSystemMailbox)
        if ($cmdlet -eq 'Get-MailboxJunkEmailConfiguration') {
            return [pscustomobject]@{ TrustedSendersAndDomains = @('keep@contoso.com') }
        }
        $script:SafeSenderWrites += $cmdParams
    }

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $FunctionPath
}

Describe 'Invoke-ExecMailboxSafeSender' {
    It 'returns a success Results message when mailbox and sender are provided' {
        $request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecMailboxSafeSender' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                mailbox      = 'user@contoso.com'
                sender       = 'sender@example.com'
            }
        }

        $response = Invoke-ExecMailboxSafeSender -Request $request -TriggerMetadata $null

        $response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $response.Body.Results | Should -Match 'Added sender@example.com'
        $script:SafeSenderWrites[0].Keys | Should -Not -Contain 'TrustedSendersToAdd'
        $script:SafeSenderWrites[0].TrustedSendersAndDomains | Should -Be @('keep@contoso.com', 'sender@example.com')
    }
}
