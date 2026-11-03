BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $Private = Join-Path $RepoRoot 'Modules/CIPPCore/Private/MailFilter'
    $Public = Join-Path $RepoRoot 'Modules/CIPPCore/Public/MailFilter'
    . (Join-Path $Private 'MailFilter.Common.ps1')
    . (Join-Path $Public 'Join-CIPPMailboxJunkSenderList.ps1')
    Get-ChildItem $Private -Filter 'Get-CIPP*.ps1' | ForEach-Object { . $_.FullName }
}

Describe 'Join-CIPPMailboxJunkSenderList' {
    It 'merges an added sender into the existing list' {
        $Merged = Join-CIPPMailboxJunkSenderList -Existing @('keep@contoso.com') -Add @('new@contoso.com')
        $Merged.List | Should -Be @('keep@contoso.com', 'new@contoso.com')
        $Merged.Added | Should -Be @('new@contoso.com')
    }

    It 'does not duplicate a sender that is already present' {
        $Merged = Join-CIPPMailboxJunkSenderList -Existing @('keep@contoso.com') -Add @('KEEP@contoso.com')
        $Merged.List | Should -Be @('keep@contoso.com')
        @($Merged.Added) | Should -BeNullOrEmpty
    }

    It 'removes a sender without clearing the rest of the list' {
        $Merged = Join-CIPPMailboxJunkSenderList -Existing @('keep@contoso.com', 'drop@contoso.com') -Remove @('drop@contoso.com')
        $Merged.List | Should -Be @('keep@contoso.com')
        $Merged.Removed | Should -Be @('drop@contoso.com')
    }

    It 'rejects a wildcard sender' {
        { Join-CIPPMailboxJunkSenderList -Add @('*') } | Should -Throw '*wildcard*'
    }
}

Describe 'mail filter protection floor' {
    It 'treats Quarantine as stronger than junk-folder delivery' {
        (Get-CIPPMailFilterActionRank 'Quarantine') | Should -BeGreaterThan (Get-CIPPMailFilterActionRank 'MoveToJmf')
        Test-CIPPMailFilterSettingWeaker -Field 'SpamAction' -Before 'Quarantine' -After 'MoveToJmf' | Should -BeTrue
    }

    It 'treats Reject and Quarantine as the same strength' {
        Test-CIPPMailFilterSettingWeaker -Field 'FileTypeAction' -Before 'Quarantine' -After 'Reject' | Should -BeFalse
    }

    It 'treats a higher bulk threshold as weaker' {
        Test-CIPPMailFilterSettingWeaker -Field 'BulkThreshold' -Before 5 -After 8 | Should -BeTrue
        Test-CIPPMailFilterSettingWeaker -Field 'BulkThreshold' -Before 8 -After 5 | Should -BeFalse
    }

    It 'treats disabling an enabled preset as weaker' {
        Test-CIPPMailFilterSettingWeaker -Field 'State' -Before 'Enabled' -After 'Disabled' | Should -BeTrue
    }

    It 'reads the string false as false' {
        ConvertTo-CIPPMailFilterBool -Value 'false' | Should -BeFalse
        ConvertTo-CIPPMailFilterBool -Value 'true' | Should -BeTrue
    }
}

Describe 'Get-CIPPPresetSecurityPolicyChange' {
    BeforeAll {
        $script:PresetRule = [pscustomobject]@{
            Identity          = 'Standard Preset Security Policy'
            Name              = 'Standard Preset Security Policy'
            State             = 'Enabled'
            SentTo            = @('a@contoso.com', 'b@contoso.com')
            SentToMemberOf    = @()
            RecipientDomainIs = @('contoso.com')
        }
    }

    It 'blocks a disable in the diff and builds EOP and ATP rollback commands' {
        $Plan = Get-CIPPPresetSecurityPolicyChange -Preset 'Standard' -State 'Disable' -EopRule $script:PresetRule -AtpRule $script:PresetRule
        @($Plan.Diff | Where-Object Weaker).Count | Should -BeGreaterThan 0
        $Plan.Commands.Cmdlet | Should -Contain 'Disable-EOPProtectionPolicyRule'
        $Plan.Commands.Cmdlet | Should -Contain 'Disable-ATPProtectionPolicyRule'
        $Plan.Rollback.Cmdlet | Should -Contain 'Enable-EOPProtectionPolicyRule'
    }

    It 'marks a smaller user scope as weaker while the preset stays enabled' {
        $Plan = Get-CIPPPresetSecurityPolicyChange -Preset 'Standard' -EopRule $script:PresetRule -HasUsers $true -Users @('a@contoso.com')
        @($Plan.Diff | Where-Object { $_.Field -eq 'EOP.SentTo' -and $_.Weaker }).Count | Should -Be 1
        $Plan.Commands[0].Cmdlet | Should -Be 'Set-EOPProtectionPolicyRule'
    }

    It 'does not mark enabling a disabled preset as weaker' {
        $Disabled = [pscustomobject]@{
            Identity = 'Strict Preset Security Policy'
            Name     = 'Strict Preset Security Policy'
            State    = 'Disabled'
            SentTo   = @('a@contoso.com')
        }
        $Plan = Get-CIPPPresetSecurityPolicyChange -Preset 'Strict' -State 'Enable' -EopRule $Disabled
        @($Plan.Diff | Where-Object Weaker) | Should -BeNullOrEmpty
        $Plan.Commands.Cmdlet | Should -Contain 'Enable-EOPProtectionPolicyRule'
    }
}

Describe 'Get-CIPPCustomMailFilterChange' {
    BeforeAll {
        $script:SpamBaseline = [pscustomobject]@{
            Name                     = 'Default'
            IsDefault                = $true
            SpamAction               = 'Quarantine'
            HighConfidenceSpamAction = 'Quarantine'
            BulkSpamAction           = 'Quarantine'
            BulkThreshold            = 6
        }
        $script:SpamPolicy = [pscustomobject]@{
            Name                     = 'Contoso spam'
            SpamAction               = 'Quarantine'
            HighConfidenceSpamAction = 'Quarantine'
            BulkSpamAction           = 'MoveToJmf'
            BulkThreshold            = 6
        }
        $script:SpamRule = [pscustomobject]@{
            Name                      = 'Contoso spam'
            HostedContentFilterPolicy = 'Contoso spam'
            State                     = 'Enabled'
            RecipientDomainIs         = @('contoso.com')
        }
    }

    It 'rejects a spam action that is weaker than the policy already has' {
        $Plan = Get-CIPPCustomMailFilterChange -PolicyType 'AntiSpam' -Operation 'Update' -Name 'Contoso spam' -Policy $script:SpamPolicy -Rule $script:SpamRule -BaselinePolicy $script:SpamBaseline -Settings @{ SpamAction = 'MoveToJmf' }
        @($Plan.Diff | Where-Object { $_.Field -eq 'SpamAction' -and $_.Weaker }).Count | Should -Be 1
        $Plan.Commands[0].Cmdlet | Should -Be 'Set-HostedContentFilterPolicy'
        $Plan.Rollback[0].Parameters.SpamAction | Should -Be 'Quarantine'
    }

    It 'keeps a new policy at the baseline strength when an action is omitted' {
        $Plan = Get-CIPPCustomMailFilterChange -PolicyType 'AntiSpam' -Operation 'Create' -Name 'Finance spam' -BaselinePolicy $script:SpamBaseline -RuleSettings @{ RecipientDomainIs = @('contoso.com') } -Settings @{ SpamAction = 'Quarantine' }
        $Plan.Commands[0].Parameters.HighConfidenceSpamAction | Should -Be 'Quarantine'
        @($Plan.Diff | Where-Object Weaker) | Should -BeNullOrEmpty
        $Plan.Rollback.Cmdlet | Should -Contain 'Remove-HostedContentFilterPolicy'
    }

    It 'marks deletion of an enabled custom policy as weaker' {
        $Plan = Get-CIPPCustomMailFilterChange -PolicyType 'AntiSpam' -Operation 'Delete' -Name 'Contoso spam' -Policy $script:SpamPolicy -Rule $script:SpamRule
        @($Plan.Diff | Where-Object Weaker).Count | Should -Be 1
        $Plan.Commands.Cmdlet | Should -Contain 'Remove-HostedContentFilterRule'
        $Plan.Rollback.Cmdlet | Should -Contain 'New-HostedContentFilterPolicy'
    }

    It 'refuses to delete the Default policy' {
        { Get-CIPPCustomMailFilterChange -PolicyType 'AntiSpam' -Operation 'Delete' -Name 'Default' -Policy $script:SpamBaseline } | Should -Throw '*cannot be deleted*'
    }

    It 'accepts only Reject or Quarantine for the file-type action' {
        $Malware = [pscustomobject]@{ Name = 'Custom malware'; EnableFileFilter = $true; FileTypes = @('exe'); FileTypeAction = 'Quarantine' }
        $MalwareRule = [pscustomobject]@{ Name = 'Custom malware'; MalwareFilterPolicy = 'Custom malware'; State = 'Enabled' }
        { Get-CIPPCustomMailFilterChange -PolicyType 'AntiMalware' -Operation 'Update' -Name 'Custom malware' -Policy $Malware -Rule $MalwareRule -Settings @{ FileTypeAction = 'Delete' } } | Should -Throw '*Reject or Quarantine*'
    }

    It 'marks turning the file-type filter off as weaker' {
        $Malware = [pscustomobject]@{ Name = 'Custom malware'; EnableFileFilter = $true; FileTypes = @('exe', 'bat'); FileTypeAction = 'Quarantine' }
        $MalwareRule = [pscustomobject]@{ Name = 'Custom malware'; MalwareFilterPolicy = 'Custom malware'; State = 'Enabled' }
        $Plan = Get-CIPPCustomMailFilterChange -PolicyType 'AntiMalware' -Operation 'Update' -Name 'Custom malware' -Policy $Malware -Rule $MalwareRule -Settings @{ EnableFileFilter = $false }
        @($Plan.Diff | Where-Object { $_.Field -eq 'EnableFileFilter' -and $_.Weaker }).Count | Should -Be 1
    }
}

Describe 'Get-CIPPInboundConnectorFilteringChange' {
    It 'sets EFSkipIPs, EFSkipLastIP, and EFUsers and rolls them back' {
        $Connector = [pscustomobject]@{ Name = 'From gateway'; Identity = 'From gateway'; EFSkipLastIP = $false; EFSkipIPs = @(); EFUsers = @() }
        $Plan = Get-CIPPInboundConnectorFilteringChange -Identity 'From gateway' -Connector $Connector -HasSkipIPs $true -SkipIPs @('203.0.113.5') -HasSkipLastIP $true -SkipLastIP $true -HasUsers $true -Users @('a@contoso.com')
        $Plan.Commands[0].Cmdlet | Should -Be 'Set-InboundConnector'
        $Plan.Commands[0].Parameters.EFSkipIPs | Should -Be @('203.0.113.5')
        $Plan.Commands[0].Parameters.EFSkipLastIP | Should -BeTrue
        $Plan.Commands[0].Parameters.EFUsers | Should -Be @('a@contoso.com')
        $Plan.Rollback[0].Parameters.EFSkipLastIP | Should -BeFalse
    }

    It 'rejects a value that is not an IP address' {
        $Connector = [pscustomobject]@{ Name = 'From gateway'; Identity = 'From gateway' }
        { Get-CIPPInboundConnectorFilteringChange -Identity 'From gateway' -Connector $Connector -HasSkipIPs $true -SkipIPs @('not-an-ip') } | Should -Throw '*not an IP*'
    }
}

Describe 'Get-CIPPMailboxJunkChange' {
    It 'writes the merged trusted list and does not use TrustedSendersToAdd' {
        $Current = [pscustomobject]@{ TrustedSendersAndDomains = @('keep@contoso.com'); BlockedSendersAndDomains = @('bad@contoso.com') }
        $Plan = Get-CIPPMailboxJunkChange -Mailbox 'a@contoso.com' -Configuration $Current -TrustedToAdd @('new@contoso.com') -BlockedToRemove @('bad@contoso.com')
        $Params = $Plan.Commands[0].Parameters
        $Params.Keys | Should -Not -Contain 'TrustedSendersToAdd'
        $Params.TrustedSendersAndDomains | Should -Be @('keep@contoso.com', 'new@contoso.com')
        $Params.BlockedSendersAndDomains | Should -Be @()
        $Plan.Rollback[0].Parameters.TrustedSendersAndDomains | Should -Be @('keep@contoso.com')
    }
}

Describe 'Get-CIPPFocusedInboxChange' {
    It 'builds Set-FocusedInbox for one mailbox' {
        $Plan = Get-CIPPFocusedInboxChange -Scope 'Mailbox' -Mailbox 'a@contoso.com' -Enabled $false -Current ([pscustomobject]@{ FocusedInboxOn = $true })
        $Plan.Commands[0].Cmdlet | Should -Be 'Set-FocusedInbox'
        $Plan.Commands[0].Parameters.FocusedInboxOn | Should -BeFalse
        $Plan.Rollback[0].Parameters.FocusedInboxOn | Should -BeTrue
    }

    It 'builds Set-OrganizationConfig for the organisation' {
        $Plan = Get-CIPPFocusedInboxChange -Scope 'Organization' -Enabled 'true' -Current ([pscustomobject]@{ FocusedInboxOn = $false })
        $Plan.Commands[0].Cmdlet | Should -Be 'Set-OrganizationConfig'
        $Plan.Commands[0].Parameters.FocusedInboxOn | Should -BeTrue
    }
}

Describe 'Invoke-CIPPMailFilterApply' {
    It 'returns the snapshot and rollback on a dry run and does not call Exchange' {
        $script:Called = $false
        function New-ExoRequest { $script:Called = $true }
        $Plan = @{
            Snapshot = @{ State = 'Enabled' }
            Diff     = @([pscustomobject]@{ Field = 'State'; Before = 'Enabled'; After = 'Disabled'; Weaker = $true })
            Commands = @(@{ Cmdlet = 'Disable-EOPProtectionPolicyRule'; Parameters = @{ Identity = 'Standard Preset Security Policy' } })
            Rollback = @(@{ Cmdlet = 'Enable-EOPProtectionPolicyRule'; Parameters = @{ Identity = 'Standard Preset Security Policy' } })
        }
        $Outcome = Invoke-CIPPMailFilterApply -TenantFilter 'contoso.onmicrosoft.com' -TicketNumber '1001' -Caller 'tech@msp.example' -Operation 'preset' -DryRun $true -Plan $Plan -ApiName 'ExecPresetSecurityPolicy'
        $Outcome.DryRun | Should -BeTrue
        $Outcome.Applied | Should -BeFalse
        $Outcome.Blocked | Should -BeTrue
        $Outcome.Snapshot.State | Should -Be 'Enabled'
        $Outcome.Rollback.Commands[0].Cmdlet | Should -Be 'Enable-EOPProtectionPolicyRule'
        $script:Called | Should -BeFalse
    }

    It 'applies a weaker change only when the override flag is set' {
        $script:Cmdlets = @()
        function New-ExoRequest { param($cmdlet) $script:Cmdlets += $cmdlet }
        $Plan = @{
            Snapshot = @{ State = 'Enabled' }
            Diff     = @([pscustomobject]@{ Field = 'State'; Before = 'Enabled'; After = 'Disabled'; Weaker = $true })
            Commands = @(@{ Cmdlet = 'Disable-EOPProtectionPolicyRule'; Parameters = @{ Identity = 'Standard Preset Security Policy' } })
            Rollback = @()
        }
        $Blocked = Invoke-CIPPMailFilterApply -TenantFilter 'contoso.onmicrosoft.com' -TicketNumber '1001' -Caller 'tech@msp.example' -Operation 'preset' -Plan $Plan
        $Blocked.Blocked | Should -BeTrue
        $script:Cmdlets | Should -BeNullOrEmpty

        $Allowed = Invoke-CIPPMailFilterApply -TenantFilter 'contoso.onmicrosoft.com' -TicketNumber '1001' -Caller 'tech@msp.example' -Operation 'preset' -AllowWeakerProtection $true -Plan $Plan
        $Allowed.Applied | Should -BeTrue
        $script:Cmdlets | Should -Be @('Disable-EOPProtectionPolicyRule')
    }
}
