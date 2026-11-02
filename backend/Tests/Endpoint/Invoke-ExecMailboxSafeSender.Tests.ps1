# Pester tests for Invoke-ExecMailboxSafeSender response shape

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecMailboxSafeSender.ps1'
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
    function Test-CippExchangeInputValidation { 
        param($EmailAddress, $Domain)
        @{ IsValid = $true; Errors = @() }
    }
    
    $script:LastExoRequest = $null
    function New-ExoRequest { 
        param($tenantid, $cmdlet, $cmdParams) 
        $script:LastExoRequest = @{
            TenantId  = $tenantid
            Cmdlet    = $cmdlet
            CmdParams = $cmdParams
        }
        # Validate the fix: TrustedSendersAndDomains should have GenericHashTable with Add
        if ($cmdlet -eq 'Set-MailboxJunkEmailConfiguration') {
            if ($cmdParams.TrustedSendersAndDomains) {
                $hashtable = $cmdParams.TrustedSendersAndDomains
                if ($hashtable.'@odata.type' -ne '#Exchange.GenericHashTable') {
                    throw 'TrustedSendersAndDomains must use GenericHashTable format'
                }
                if (-not $hashtable.Add) {
                    throw 'TrustedSendersAndDomains GenericHashTable must have Add property'
                }
            }
        }
        $true 
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
        
        # Assert the correct cmdlet and parameters were used
        $script:LastExoRequest | Should -Not -BeNullOrEmpty
        $script:LastExoRequest.Cmdlet | Should -Be 'Set-MailboxJunkEmailConfiguration'
        $script:LastExoRequest.CmdParams.Identity | Should -Be 'user@contoso.com'
        $script:LastExoRequest.CmdParams.TrustedSendersAndDomains.'@odata.type' | Should -Be '#Exchange.GenericHashTable'
        $script:LastExoRequest.CmdParams.TrustedSendersAndDomains.Add | Should -Be 'sender@example.com'
    }
}
