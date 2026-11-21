BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    class HttpResponseContext {
        [int]$StatusCode
        [object]$Body
        [object]$ContentType
    }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = "$Exception" } }
    function New-ExoRequest { param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox) }
    function Add-CIPPGuardedWriteAudit {
        param($Endpoint, $Tenant, $Ticket, $Caller, $Request, $Before, $After, $DryRun, $Result, $SecretValues)
        return 'audit-1'
    }
    function Get-CIPPFeatureFlag { param($Id) [pscustomobject]@{ Id = $Id; Enabled = $script:GuardedFlagEnabled } }

    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Test-CIPPTransportRuleGuardedMode.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Test-CIPPGuardedTenantWritesEnabled.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Get-CIPPTransportRuleProjection.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/ConvertTo-CIPPTransportRuleGuardedFields.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Test-CIPPTransportRuleApplyToAll.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Test-CIPPGuardedWriteRequest.ps1')

    $Using = "using namespace System.Net`n"
    . ([ScriptBlock]::Create($Using + (Get-Content -LiteralPath (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-EditTransportRule.ps1') -Raw)))
    . ([ScriptBlock]::Create($Using + (Get-Content -LiteralPath (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-RemoveTransportRule.ps1') -Raw)))
    . ([ScriptBlock]::Create($Using + (Get-Content -LiteralPath (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-AddEditTransportRule.ps1') -Raw)))

    $script:GuardedFlagEnabled = $true
    $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
}

Describe 'Transport rule guarded envelope helpers' {
    It 'does not trigger guarded mode without ticket/dryRun/reason' {
        $Request = [pscustomobject]@{ Body = [pscustomobject]@{ tenantFilter = 'contoso.onmicrosoft.com'; Name = 'Example' }; Query = $null }
        Test-CIPPTransportRuleGuardedMode -Request $Request | Should -BeFalse
    }

    It 'triggers guarded mode when dryRun is present' {
        $Request = [pscustomobject]@{ Body = [pscustomobject]@{ dryRun = $true }; Query = $null }
        Test-CIPPTransportRuleGuardedMode -Request $Request | Should -BeTrue
    }

    It 'normalizes RuleErrorAction and rejects unknown values' {
        $Ok = ConvertTo-CIPPTransportRuleGuardedFields -RuleErrorAction 'defer'
        $Ok.Ok | Should -BeTrue
        $Ok.RuleErrorAction | Should -Be 'Defer'
        $Bad = ConvertTo-CIPPTransportRuleGuardedFields -RuleErrorAction 'Reject'
        $Bad.Ok | Should -BeFalse
    }

    It 'normalizes Enabled/State and Priority in guarded mode' {
        $Ok = ConvertTo-CIPPTransportRuleGuardedFields -Enabled 'true' -Priority '2' -StopRuleProcessing '1'
        $Ok.Ok | Should -BeTrue
        $Ok.EnabledBool | Should -BeTrue
        $Ok.Priority | Should -Be 2
        $Ok.StopRuleProcessing | Should -BeTrue
    }
}

Describe 'Invoke-EditTransportRule legacy and guarded' {
    BeforeEach {
        $script:GuardedFlagEnabled = $true
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
        Mock New-ExoRequest {
            $script:ExoCalls.Add([pscustomobject]@{ cmdlet = $cmdlet; cmdParams = $cmdParams }) | Out-Null
            if ($cmdlet -eq 'Get-TransportRule') {
                return [pscustomobject]@{ Name = 'Example - Copy all mail to archive'; Guid = '11111111-1111-1111-1111-111111111111'; Identity = '11111111-1111-1111-1111-111111111111'; Priority = 0; State = 'Enabled'; Mode = 'Audit'; RuleErrorAction = 'Ignore'; StopRuleProcessing = $false }
            }
        }
        Mock Add-CIPPGuardedWriteAudit { return 'audit-edit' }
    }

    It 'keeps legacy enable behavior without ticket/dryRun/reason' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'EditTransportRule' }
            Headers = @{}
            Query   = @{ tenantFilter = 'contoso.onmicrosoft.com'; guid = '11111111-1111-1111-1111-111111111111'; state = 'enable' }
            Body    = $null
        }
        $Response = Invoke-EditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Results | Should -Match 'Set transport rule'
        $Response.Body.Status | Should -BeNullOrEmpty
        $script:ExoCalls.Cmdlet | Should -Contain 'Enable-TransportRule'
        $script:ExoCalls.Cmdlet | Should -Not -Contain 'Get-TransportRule'
    }

    It 'enforces ticket when only dryRun:false is sent' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'EditTransportRule' }
            Headers = @{}
            Query   = $null
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                guid         = '11111111-1111-1111-1111-111111111111'
                state        = 'enable'
                dryRun       = $false
            }
        }
        $Response = Invoke-EditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'ticketNumber'
        $script:ExoCalls.Count | Should -Be 0
    }

    It 'returns 403 when GuardedTenantWrites is off' {
        $script:GuardedFlagEnabled = $false
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'EditTransportRule' }
            Headers = @{}
            Query   = $null
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                guid         = '11111111-1111-1111-1111-111111111111'
                state        = 'disable'
                ticketNumber = '1234567'
                dryRun       = $true
                reason       = 'preview'
            }
        }
        $Response = Invoke-EditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 403
        $script:ExoCalls.Count | Should -Be 0
    }

    It 'preview defaults true and issues zero writes' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'EditTransportRule' }
            Headers = @{}
            Query   = $null
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                guid         = '11111111-1111-1111-1111-111111111111'
                state        = 'disable'
                ticketNumber = '1234567'
                reason       = 'preview disable'
            }
        }
        $Response = Invoke-EditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.Before.Name | Should -Be 'Example - Copy all mail to archive'
        $Response.Body.Rollback | Should -Not -BeNullOrEmpty
        $WriteCalls = @($script:ExoCalls | Where-Object { $_.cmdlet -ne 'Get-TransportRule' })
        $WriteCalls.Count | Should -Be 0
    }
}

Describe 'Invoke-RemoveTransportRule guarded confirmRuleName' {
    BeforeEach {
        $script:GuardedFlagEnabled = $true
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
        Mock New-ExoRequest {
            $script:ExoCalls.Add([pscustomobject]@{ cmdlet = $cmdlet; cmdParams = $cmdParams }) | Out-Null
            if ($cmdlet -eq 'Get-TransportRule') {
                return [pscustomobject]@{ Name = 'Example - Copy all mail to archive'; Guid = '11111111-1111-1111-1111-111111111111'; Identity = '11111111-1111-1111-1111-111111111111'; Priority = 1; State = 'Disabled'; Mode = 'Enforce'; RuleErrorAction = 'Ignore' }
            }
        }
        Mock Add-CIPPGuardedWriteAudit { return 'audit-remove' }
    }

    It 'keeps legacy delete without ticket' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'RemoveTransportRule' }
            Headers = @{}
            Query   = @{ tenantFilter = 'contoso.onmicrosoft.com'; guid = '11111111-1111-1111-1111-111111111111' }
            Body    = $null
        }
        $Response = Invoke-RemoveTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Results | Should -Be 'Deleted 11111111-1111-1111-1111-111111111111'
        $script:ExoCalls.Cmdlet | Should -Contain 'Remove-TransportRule'
    }

    It 'refuses a wrong confirmRuleName' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'RemoveTransportRule' }
            Headers = @{}
            Query   = $null
            Body    = [pscustomobject]@{
                tenantFilter    = 'contoso.onmicrosoft.com'
                guid            = '11111111-1111-1111-1111-111111111111'
                ticketNumber    = '1234567'
                dryRun          = $true
                reason          = 'remove'
                confirmRuleName = 'Wrong Name'
            }
        }
        $Response = Invoke-RemoveTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'confirmRuleName'
        $script:ExoCalls.Cmdlet | Should -Not -Contain 'Remove-TransportRule'
    }

    It 'accepts matching confirmRuleName on preview' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'RemoveTransportRule' }
            Headers = @{}
            Query   = $null
            Body    = [pscustomobject]@{
                tenantFilter    = 'contoso.onmicrosoft.com'
                guid            = '11111111-1111-1111-1111-111111111111'
                ticketNumber    = '1234567'
                dryRun          = $true
                reason          = 'remove'
                confirmRuleName = 'Example - Copy all mail to archive'
            }
        }
        $Response = Invoke-RemoveTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.Rollback.Rule.Name | Should -Be 'Example - Copy all mail to archive'
    }
}

Describe 'Invoke-AddEditTransportRule guarded create' {
    BeforeEach {
        $script:GuardedFlagEnabled = $true
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
        $script:ExistingRules = @()
        Mock New-ExoRequest {
            $script:ExoCalls.Add([pscustomobject]@{ cmdlet = $cmdlet; cmdParams = $cmdParams }) | Out-Null
            if ($cmdlet -eq 'Get-TransportRule' -and (-not $cmdParams -or -not $cmdParams.Identity)) {
                return $script:ExistingRules
            }
            if ($cmdlet -eq 'Get-TransportRule') {
                return [pscustomobject]@{
                    Name = 'Example - Copy all mail to archive'; Guid = '22222222-2222-2222-2222-222222222222'
                    Identity = '22222222-2222-2222-2222-222222222222'; Priority = 0; State = 'Enabled'; Mode = 'Audit'
                    RuleErrorAction = 'Defer'; StopRuleProcessing = $true; BlindCopyTo = @('archive@contoso.example')
                }
            }
        }
        Mock Add-CIPPGuardedWriteAudit { return 'audit-addedit' }
    }

    It 'keeps legacy create without ticket (snapshot cmdlets)' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                Name         = 'Example - Copy all mail to archive'
                Mode         = 'Audit'
                BlindCopyTo  = @('archive@contoso.example')
            }
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Results | Should -Match 'Successfully created'
        $Response.Body.Status | Should -BeNullOrEmpty
        $script:ExoCalls.Cmdlet | Should -Contain 'New-TransportRule'
        $script:ExoCalls.Cmdlet | Should -Not -Contain 'Get-TransportRule'
    }

    It 'refuses create when name already exists in guarded mode' {
        $script:ExistingRules = @([pscustomobject]@{ Name = 'Example - Copy all mail to archive'; Guid = '11111111-1111-1111-1111-111111111111'; Priority = 0; State = 'Enabled'; Mode = 'Enforce' })
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                Name               = 'Example - Copy all mail to archive'
                Mode               = 'Audit'
                BlindCopyTo        = @('archive@contoso.example')
                applyToAllMessages = $true
                ticketNumber       = '1234567'
                dryRun             = $true
                reason             = 'create'
            }
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'already exists'
        $script:ExoCalls.Cmdlet | Should -Not -Contain 'New-TransportRule'
    }

    It 'preview create returns Before list and zero writes' {
        $script:ExistingRules = @()
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter       = 'contoso.onmicrosoft.com'
                Name               = 'Example - Copy all mail to archive'
                Mode               = 'Audit'
                Priority           = 0
                RuleErrorAction    = 'Defer'
                StopRuleProcessing = $true
                BlindCopyTo        = @(@{ value = 'archive@contoso.example' })
                applyToAllMessages = $true
                ticketNumber       = '1234567'
                reason             = 'create preview'
            }
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.Before.Rules | Should -Be @()
        $Response.Body.WhatIfPlan[0].Cmdlet | Should -Be 'New-TransportRule'
        $Response.Body.WhatIfPlan[0].Parameters.RuleErrorAction | Should -Be 'Defer'
        $Response.Body.WhatIfPlan[0].Parameters.BlindCopyTo | Should -Contain 'archive@contoso.example'
        $Response.Body.Rollback.Steps.Count | Should -Be 2
        $WriteCalls = @($script:ExoCalls | Where-Object { $_.cmdlet -ne 'Get-TransportRule' })
        $WriteCalls.Count | Should -Be 0
    }

    It 'rejects invalid RuleErrorAction with 400' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter    = 'contoso.onmicrosoft.com'
                Name            = 'Example - Copy all mail to archive'
                RuleErrorAction = 'Reject'
                ticketNumber    = '1234567'
                dryRun          = $true
                reason          = 'bad action'
            }
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'RuleErrorAction'
    }

    It 'pins legacy edit quirk: truthy Enabled only runs Enable/Disable' {
        Mock New-ExoRequest {
            $script:ExoCalls.Add([pscustomobject]@{ cmdlet = $cmdlet; cmdParams = $cmdParams }) | Out-Null
            if ($cmdlet -eq 'Get-TransportRule') {
                return [pscustomobject]@{ Name = 'Example'; Guid = '11111111-1111-1111-1111-111111111111'; Identity = '11111111-1111-1111-1111-111111111111'; Priority = 0; State = 'Disabled'; Mode = 'Audit'; RuleErrorAction = 'Ignore'; StopRuleProcessing = $false }
            }
        }
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'AddEditTransportRule' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                ruleId       = '11111111-1111-1111-1111-111111111111'
                Name         = 'Example'
                Enabled      = 'Enabled'
                Mode         = 'Enforce'
                ticketNumber = '1234567'
                dryRun       = $true
                reason       = 'enable only'
            }
        }
        $Response = Invoke-AddEditTransportRule -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.WhatIfPlan.Count | Should -Be 1
        $Response.Body.WhatIfPlan[0].Cmdlet | Should -Be 'Enable-TransportRule'
    }
}
