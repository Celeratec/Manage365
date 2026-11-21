BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    class HttpResponseContext {
        [int]$StatusCode
        [object]$Body
        [object]$Headers
        [object]$ContentType
    }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = "$Exception" } }
    function New-ExoRequest { param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) }
    function Add-CIPPGuardedWriteAudit {
        param($Endpoint, $Tenant, $Ticket, $Caller, $Request, $Before, $After, $DryRun, $Result, $SecretValues)
        return 'audit-1'
    }
    function Get-CIPPFeatureFlag { param($Id) [pscustomobject]@{ Id = $Id; Enabled = $true } }

    Get-ChildItem (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite') -Filter '*.ps1' | ForEach-Object { . $_.FullName }

    $Using = "using namespace System.Net`n"
    . ([ScriptBlock]::Create($Using + (Get-Content -LiteralPath (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-AddEditTransportRule.ps1') -Raw)))

    $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
}

Describe 'Test-CIPPTransportRuleApplyToAll' {
    It 'allows a rule that has a condition' {
        $Result = Test-CIPPTransportRuleApplyToAll -CmdletParams @{ Name = 'R'; FromScope = 'InOrganization'; BlindCopyTo = @('a@contoso.example') } -ApplyToAllMessages $null
        $Result.Ok | Should -BeTrue
        $Result.HasCondition | Should -BeTrue
    }

    It 'refuses condition-less without applyToAllMessages' {
        $Result = Test-CIPPTransportRuleApplyToAll -CmdletParams @{ Name = 'R'; BlindCopyTo = @('a@contoso.example'); Mode = 'Audit' } -ApplyToAllMessages $false
        $Result.Ok | Should -BeFalse
        $Result.Message | Should -Match 'applyToAllMessages'
    }

    It 'refuses unconditional DeleteMessage even with applyToAllMessages' {
        $Result = Test-CIPPTransportRuleApplyToAll -CmdletParams @{ Name = 'R'; DeleteMessage = $true } -ApplyToAllMessages $true
        $Result.Ok | Should -BeFalse
        $Result.Message | Should -Match 'DeleteMessage'
    }

    It 'allows unconditional BlindCopyTo with applyToAllMessages' {
        $Result = Test-CIPPTransportRuleApplyToAll -CmdletParams @{ Name = 'R'; BlindCopyTo = @('archive@contoso.example'); Mode = 'Audit' } -ApplyToAllMessages $true
        $Result.Ok | Should -BeTrue
        $Result.HasCondition | Should -BeFalse
    }
}

Describe 'Invoke-AddEditTransportRule condition-less guarded create' {
    BeforeEach {
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
        Mock New-ExoRequest {
            $script:ExoCalls.Add([pscustomobject]@{ cmdlet = $cmdlet; cmdParams = $cmdParams }) | Out-Null
            if ($cmdlet -eq 'Get-TransportRule') { return @() }
        }
        Mock Add-CIPPGuardedWriteAudit { return 'audit-nc' }
    }

    It 'builds New-TransportRule with no predicate and flattens value objects' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter         = 'contoso.onmicrosoft.com'
                Name                 = 'Example - Copy all mail to archive'
                Comments             = 'BCC archive'
                BlindCopyTo          = @(@{ value = 'archive@contoso.example' })
                ExceptIfSentTo       = @(@{ value = 'other@contoso.example' })
                ExceptIfFrom         = @('skip@contoso.example')
                SenderAddressLocation = 'Header'
                StopRuleProcessing   = $true
                RuleErrorAction      = 'Ignore'
                Priority             = 0
                Mode                 = 'Audit'
                applyToAllMessages   = $true
                ticketNumber         = '1234567'
                dryRun               = $true
                reason               = 'condition-less bcc'
            }
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Params = $Response.Body.WhatIfPlan[0].Parameters
        $Response.Body.WhatIfPlan[0].Cmdlet | Should -Be 'New-TransportRule'
        $Params.BlindCopyTo | Should -Contain 'archive@contoso.example'
        $Params.ExceptIfSentTo | Should -Contain 'other@contoso.example'
        $Params.ExceptIfFrom | Should -Contain 'skip@contoso.example'
        $Params.Keys | Should -Not -Contain 'From'
        $Params.Keys | Should -Not -Contain 'FromScope'
        $Params.Keys | Should -Not -Contain 'SentTo'
        $Params.Keys | Should -Not -Contain 'SubjectContainsWords'
        $WriteCalls = @($script:ExoCalls | Where-Object { $_.cmdlet -ne 'Get-TransportRule' })
        $WriteCalls.Count | Should -Be 0
    }

    It 'builds New-TransportRule with no conditions and no exceptions' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter       = 'contoso.onmicrosoft.com'
                Name               = 'Example - Copy all mail to archive'
                BlindCopyTo        = @('archive@contoso.example')
                Mode               = 'Audit'
                applyToAllMessages = $true
                ticketNumber       = '1234567'
                dryRun             = $true
                reason             = 'no except'
            }
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Params = $Response.Body.WhatIfPlan[0].Parameters
        @($Params.Keys | Where-Object { $_ -like 'ExceptIf*' }).Count | Should -Be 0
        @($Params.Keys | Where-Object { $_ -in @('From', 'FromScope', 'SentTo', 'SubjectContainsWords') }).Count | Should -Be 0
    }

    It 'refuses condition-less create without applyToAllMessages' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                Name         = 'Example - Copy all mail to archive'
                BlindCopyTo  = @('archive@contoso.example')
                Mode         = 'Audit'
                ticketNumber = '1234567'
                dryRun       = $true
                reason       = 'missing flag'
            }
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'applyToAllMessages'
    }

    It 'refuses unconditional <Action> even with applyToAllMessages' -ForEach @(
        @{ Action = 'DeleteMessage'; Body = @{ DeleteMessage = $true } }
        @{ Action = 'Quarantine'; Body = @{ Quarantine = $true } }
        @{ Action = 'RedirectMessageTo'; Body = @{ RedirectMessageTo = @('a@contoso.example') } }
        @{ Action = 'RouteMessageOutboundConnector'; Body = @{ RouteMessageOutboundConnector = 'Outbound' } }
        @{ Action = 'RejectMessageReasonText'; Body = @{ RejectMessageReasonText = 'blocked' } }
    ) {
        $BodyHash = @{
            tenantFilter       = 'contoso.onmicrosoft.com'
            Name               = 'Example - risky'
            Mode               = 'Audit'
            applyToAllMessages = $true
            ticketNumber       = '1234567'
            dryRun             = $true
            reason             = 'refuse'
        }
        foreach ($Key in $Body.Keys) { $BodyHash[$Key] = $Body[$Key] }
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]$BodyHash
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match $Action
    }
}
