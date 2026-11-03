BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $Private = Join-Path $RepoRoot 'Modules/CIPPCore/Private/MailFilter'
    $Public = Join-Path $RepoRoot 'Modules/CIPPCore/Public/MailFilter'
    . (Join-Path $Private 'MailFilter.Common.ps1')
    Get-ChildItem $Public -Filter '*.ps1' | ForEach-Object { . $_.FullName }
    Get-ChildItem $Private -Filter 'Get-CIPP*.ps1' | ForEach-Object { . $_.FullName }

    class HttpResponseContext {
        [int]$StatusCode
        [object]$Body
    }
    $Accelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not $Accelerators::Get.Keys.Contains('HttpStatusCode')) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Write-LogMessage { param($headers, $API, $message, $sev, $LogData) }
    function Get-CippException { param($Exception) @{ NormalizedError = $Exception.Exception.Message } }
    function Get-CippTable { param($tablename) @{ Table = $tablename } }
    function Add-CIPPAzDataTableEntity { param($Entity) }

    $Http = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange'
    . (Join-Path $Http 'Spamfilter/Invoke-ExecPresetSecurityPolicy.ps1')
    . (Join-Path $Http 'Spamfilter/Invoke-ExecCustomMailFilterPolicy.ps1')
    . (Join-Path $Http 'Spamfilter/Invoke-ExecMailboxJunkConfiguration.ps1')
    . (Join-Path $Http 'Transport/Invoke-ExecInboundConnectorEnhancedFiltering.ps1')
    . (Join-Path $Http 'Administration/Invoke-ExecFocusedInbox.ps1')

    function New-MailFilterRequest {
        param($Endpoint, $Body)
        [pscustomobject]@{
            Params  = @{ CIPPEndpoint = $Endpoint }
            Headers = @{ 'x-ms-client-principal-name' = 'tech@msp.example' }
            Query   = @{}
            Body    = $Body
        }
    }
}

Describe 'Invoke-ExecPresetSecurityPolicy' {
    BeforeEach {
        $script:Cmdlets = @()
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox, $Anchor)
            $script:Cmdlets += $cmdlet
            [pscustomobject]@{
                Identity = 'Standard Preset Security Policy'
                Name     = 'Standard Preset Security Policy'
                State    = 'Enabled'
                SentTo   = @('a@contoso.com')
            }
        }
    }

    It 'rejects a write that does not include a ticket ID' {
        $Response = Invoke-ExecPresetSecurityPolicy -Request (New-MailFilterRequest 'ExecPresetSecurityPolicy' @{ tenantFilter = 'contoso.onmicrosoft.com'; preset = 'Standard'; state = 'Disable' }) -TriggerMetadata $null
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'ticketNumber'
        $script:Cmdlets | Should -BeNullOrEmpty
    }

    It 'dry-runs a preset disable and returns the snapshot and rollback' {
        $Response = Invoke-ExecPresetSecurityPolicy -Request (New-MailFilterRequest 'ExecPresetSecurityPolicy' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4401'; preset = 'Standard'; state = 'Disable'; dryRun = $true; allowWeakerProtection = $true
            }) -TriggerMetadata $null
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $Response.Body.DryRun | Should -BeTrue
        $Response.Body.Applied | Should -BeFalse
        $Response.Body.Snapshot.EOP.State | Should -Be 'Enabled'
        $Response.Body.Rollback.Commands.Cmdlet | Should -Contain 'Enable-EOPProtectionPolicyRule'
        $script:Cmdlets | Should -Not -Contain 'Disable-EOPProtectionPolicyRule'
    }

    It 'rejects a weaker preset change unless the override flag is set' {
        $Blocked = Invoke-ExecPresetSecurityPolicy -Request (New-MailFilterRequest 'ExecPresetSecurityPolicy' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4401'; preset = 'Standard'; state = 'Disable'
            }) -TriggerMetadata $null
        $Blocked.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        $Blocked.Body.Blocked | Should -BeTrue
        $script:Cmdlets | Should -Not -Contain 'Disable-EOPProtectionPolicyRule'

        $Allowed = Invoke-ExecPresetSecurityPolicy -Request (New-MailFilterRequest 'ExecPresetSecurityPolicy' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4401'; preset = 'Standard'; state = 'Disable'; allowWeakerProtection = $true
            }) -TriggerMetadata $null
        $Allowed.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $Allowed.Body.Applied | Should -BeTrue
        $Allowed.Body.Caller | Should -Be 'tech@msp.example'
        $script:Cmdlets | Should -Contain 'Disable-EOPProtectionPolicyRule'
        $script:Cmdlets | Should -Contain 'Disable-ATPProtectionPolicyRule'
    }
}

Describe 'Invoke-ExecCustomMailFilterPolicy' {
    BeforeEach {
        $script:Cmdlets = @()
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            $script:Cmdlets += $cmdlet
            if ($cmdlet -eq 'Get-HostedContentFilterPolicy') {
                return @(
                    [pscustomobject]@{ Name = 'Default'; IsDefault = $true; SpamAction = 'Quarantine'; HighConfidenceSpamAction = 'Quarantine'; BulkSpamAction = 'Quarantine'; BulkThreshold = 6 }
                    [pscustomobject]@{ Name = 'Contoso spam'; SpamAction = 'Quarantine'; HighConfidenceSpamAction = 'Quarantine'; BulkSpamAction = 'Quarantine'; BulkThreshold = 6 }
                )
            }
            if ($cmdlet -eq 'Get-HostedContentFilterRule') {
                return @([pscustomobject]@{ Name = 'Contoso spam'; HostedContentFilterPolicy = 'Contoso spam'; State = 'Enabled'; RecipientDomainIs = @('contoso.com') })
            }
            return $null
        }
    }

    It 'rejects a weaker spam action and applies it when the override is set' {
        $Blocked = Invoke-ExecCustomMailFilterPolicy -Request (New-MailFilterRequest 'ExecCustomMailFilterPolicy' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4402'; policyType = 'AntiSpam'; operation = 'Update'; name = 'Contoso spam'; spamAction = 'MoveToJmf'
            }) -TriggerMetadata $null
        $Blocked.Body.Blocked | Should -BeTrue
        $script:Cmdlets | Should -Not -Contain 'Set-HostedContentFilterPolicy'

        $Allowed = Invoke-ExecCustomMailFilterPolicy -Request (New-MailFilterRequest 'ExecCustomMailFilterPolicy' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4402'; policyType = 'AntiSpam'; operation = 'Update'; name = 'Contoso spam'; spamAction = 'MoveToJmf'; allowWeakerProtection = $true
            }) -TriggerMetadata $null
        $Allowed.Body.Applied | Should -BeTrue
        $Allowed.Body.Rollback.Commands[0].Parameters.SpamAction | Should -Be 'Quarantine'
        $script:Cmdlets | Should -Contain 'Set-HostedContentFilterPolicy'
    }

    It 'creates an anti-phish policy and rule on dry run without writing' {
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            $script:Cmdlets += $cmdlet
            if ($cmdlet -eq 'Get-AntiPhishPolicy') {
                return @([pscustomobject]@{ Name = 'Default'; IsDefault = $true; TargetedUserProtectionAction = 'Quarantine'; TargetedDomainProtectionAction = 'Quarantine'; MailboxIntelligenceProtectionAction = 'Quarantine' })
            }
            return @()
        }
        $Response = Invoke-ExecCustomMailFilterPolicy -Request (New-MailFilterRequest 'ExecCustomMailFilterPolicy' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4403'; policyType = 'AntiPhish'; operation = 'Create'; name = 'Finance phish'
                targetedUserProtectionAction = 'Quarantine'; recipientDomainIs = @('contoso.com'); dryRun = $true
            }) -TriggerMetadata $null
        $Response.Body.DryRun | Should -BeTrue
        $Response.Body.Commands.Cmdlet | Should -Contain 'New-AntiPhishPolicy'
        $Response.Body.Commands.Cmdlet | Should -Contain 'New-AntiPhishRule'
        $script:Cmdlets | Should -Not -Contain 'New-AntiPhishPolicy'
    }
}

Describe 'Invoke-ExecMailboxJunkConfiguration' {
    BeforeEach {
        $script:Writes = @()
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox, $Anchor)
            if ($cmdlet -eq 'Get-MailboxJunkEmailConfiguration') {
                return [pscustomobject]@{ TrustedSendersAndDomains = @('keep@contoso.com'); BlockedSendersAndDomains = @() }
            }
            $script:Writes += [pscustomobject]@{ Cmdlet = $cmdlet; Parameters = $cmdParams }
        }
    }

    It 'merges trusted senders instead of calling TrustedSendersToAdd' {
        $Response = Invoke-ExecMailboxJunkConfiguration -Request (New-MailFilterRequest 'ExecMailboxJunkConfiguration' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4404'; mailbox = 'a@contoso.com'; trustedSendersToAdd = @('new@contoso.com')
            }) -TriggerMetadata $null
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $Response.Body.Applied | Should -BeTrue
        $script:Writes[0].Parameters.Keys | Should -Not -Contain 'TrustedSendersToAdd'
        $script:Writes[0].Parameters.TrustedSendersAndDomains | Should -Be @('keep@contoso.com', 'new@contoso.com')
        $Response.Body.Rollback.Commands[0].Parameters.TrustedSendersAndDomains | Should -Be @('keep@contoso.com')
    }
}

Describe 'Invoke-ExecInboundConnectorEnhancedFiltering' {
    BeforeEach {
        $script:Writes = @()
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            if ($cmdlet -eq 'Get-InboundConnector') {
                return @([pscustomobject]@{ Name = 'Gateway'; Identity = 'Gateway'; EFSkipLastIP = $false; EFSkipIPs = @(); EFUsers = @() })
            }
            $script:Writes += $cmdParams
        }
    }

    It 'dry-runs Enhanced Filtering and shows the three fields' {
        $Response = Invoke-ExecInboundConnectorEnhancedFiltering -Request (New-MailFilterRequest 'ExecInboundConnectorEnhancedFiltering' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4405'; identity = 'Gateway'; efSkipIPs = @('203.0.113.8'); efSkipLastIP = $true; efUsers = @('a@contoso.com'); dryRun = $true
            }) -TriggerMetadata $null
        $Response.Body.DryRun | Should -BeTrue
        $Response.Body.Commands[0].Parameters.EFSkipIPs | Should -Be @('203.0.113.8')
        $Response.Body.Commands[0].Parameters.EFSkipLastIP | Should -BeTrue
        $Response.Body.Commands[0].Parameters.EFUsers | Should -Be @('a@contoso.com')
        $script:Writes | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-ExecFocusedInbox' {
    It 'turns Focused Inbox off for a mailbox and returns the previous value for rollback' {
        $script:Writes = @()
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox, $Anchor)
            if ($cmdlet -eq 'Get-FocusedInbox') { return [pscustomobject]@{ FocusedInboxOn = $true } }
            $script:Writes += [pscustomobject]@{ Cmdlet = $cmdlet; Parameters = $cmdParams }
        }
        $Response = Invoke-ExecFocusedInbox -Request (New-MailFilterRequest 'ExecFocusedInbox' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4406'; scope = 'Mailbox'; mailbox = 'a@contoso.com'; enabled = $false
            }) -TriggerMetadata $null
        $Response.Body.Applied | Should -BeTrue
        $script:Writes[0].Cmdlet | Should -Be 'Set-FocusedInbox'
        $script:Writes[0].Parameters.FocusedInboxOn | Should -BeFalse
        $Response.Body.Rollback.Commands[0].Parameters.FocusedInboxOn | Should -BeTrue
    }

    It 'dry-runs the organisation setting' {
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $useSystemMailbox)
            if ($cmdlet -eq 'Get-OrganizationConfig') { return [pscustomobject]@{ FocusedInboxOn = $true } }
            throw "Unexpected write $cmdlet"
        }
        $Response = Invoke-ExecFocusedInbox -Request (New-MailFilterRequest 'ExecFocusedInbox' @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '4407'; scope = 'Organization'; enabled = $false; dryRun = $true
            }) -TriggerMetadata $null
        $Response.Body.DryRun | Should -BeTrue
        $Response.Body.Commands[0].Cmdlet | Should -Be 'Set-OrganizationConfig'
        $Response.Body.TicketNumber | Should -Be '4407'
    }
}
