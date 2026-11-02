function Invoke-ExecAntiPhishPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Create or update custom anti-phishing policies (AntiPhishPolicy and Rule).
        Supports impersonation protection, mailbox intelligence, and safety tips.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter | Select-Object -First 1
    $Action = $Request.Body.action  # New or Update
    $PolicyName = Get-CippQuarantineInputValue $Request.Body.policyName
    $RuleName = Get-CippQuarantineInputValue $Request.Body.ruleName
    $Priority = $Request.Body.priority

    try {
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($Action)) { throw 'action is required.' }
        if ($Action -notin @('New', 'Update')) { throw 'action must be New or Update.' }
        if ([string]::IsNullOrWhiteSpace($PolicyName)) { throw 'policyName is required.' }

        # Build policy parameters
        $PolicyParams = @{
            Name = $PolicyName
        }

        # Impersonation protection
        if ($null -ne $Request.Body.enableTargetedUserProtection) { $PolicyParams.EnableTargetedUserProtection = $Request.Body.enableTargetedUserProtection }
        if ($Request.Body.targetedUsersToProtect) { $PolicyParams.TargetedUsersToProtect = $Request.Body.targetedUsersToProtect }
        if ($null -ne $Request.Body.enableTargetedDomainProtection) { $PolicyParams.EnableTargetedDomainProtection = $Request.Body.enableTargetedDomainProtection }
        if ($Request.Body.targetedDomainsToProtect) { $PolicyParams.TargetedDomainsToProtect = $Request.Body.targetedDomainsToProtect }
        if ($null -ne $Request.Body.targetedUserProtectionAction) { $PolicyParams.TargetedUserProtectionAction = $Request.Body.targetedUserProtectionAction }
        if ($null -ne $Request.Body.targetedDomainProtectionAction) { $PolicyParams.TargetedDomainProtectionAction = $Request.Body.targetedDomainProtectionAction }

        # Mailbox intelligence
        if ($null -ne $Request.Body.enableMailboxIntelligence) { $PolicyParams.EnableMailboxIntelligence = $Request.Body.enableMailboxIntelligence }
        if ($null -ne $Request.Body.enableMailboxIntelligenceProtection) { $PolicyParams.EnableMailboxIntelligenceProtection = $Request.Body.enableMailboxIntelligenceProtection }
        if ($null -ne $Request.Body.mailboxIntelligenceProtectionAction) { $PolicyParams.MailboxIntelligenceProtectionAction = $Request.Body.mailboxIntelligenceProtectionAction }

        # Safety tips
        if ($null -ne $Request.Body.enableSimilarUsersSafetyTips) { $PolicyParams.EnableSimilarUsersSafetyTips = $Request.Body.enableSimilarUsersSafetyTips }
        if ($null -ne $Request.Body.enableSimilarDomainsSafetyTips) { $PolicyParams.EnableSimilarDomainsSafetyTips = $Request.Body.enableSimilarDomainsSafetyTips }
        if ($null -ne $Request.Body.enableUnusualCharactersSafetyTips) { $PolicyParams.EnableUnusualCharactersSafetyTips = $Request.Body.enableUnusualCharactersSafetyTips }

        # Spoofing
        if ($null -ne $Request.Body.enableAntiSpoofEnforcement) { $PolicyParams.EnableAntiSpoofEnforcement = $Request.Body.enableAntiSpoofEnforcement }
        if ($null -ne $Request.Body.enableUnauthenticatedSender) { $PolicyParams.EnableUnauthenticatedSender = $Request.Body.enableUnauthenticatedSender }
        if ($null -ne $Request.Body.authenticationFailAction) { $PolicyParams.AuthenticationFailAction = $Request.Body.authenticationFailAction }

        # Actions
        if ($null -ne $Request.Body.phishThresholdLevel) { $PolicyParams.PhishThresholdLevel = $Request.Body.phishThresholdLevel }

        # Trusted senders/domains
        if ($Request.Body.excludedSenders) { $PolicyParams.ExcludedSenders = $Request.Body.excludedSenders }
        if ($Request.Body.excludedDomains) { $PolicyParams.ExcludedDomains = $Request.Body.excludedDomains }

        # Quarantine/redirection
        if ($Request.Body.targetedUserQuarantineTag) { $PolicyParams.TargetedUserQuarantineTag = $Request.Body.targetedUserQuarantineTag }
        if ($Request.Body.targetedDomainQuarantineTag) { $PolicyParams.TargetedDomainQuarantineTag = $Request.Body.targetedDomainQuarantineTag }
        if ($Request.Body.mailboxIntelligenceQuarantineTag) { $PolicyParams.MailboxIntelligenceQuarantineTag = $Request.Body.mailboxIntelligenceQuarantineTag }

        # Honor DMARC
        if ($null -ne $Request.Body.honorDmarcPolicy) { $PolicyParams.HonorDmarcPolicy = $Request.Body.honorDmarcPolicy }

        $Results = @()

        if ($Action -eq 'New') {
            # Create new policy
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-AntiPhishPolicy' -cmdParams $PolicyParams -useSystemMailbox $true
            $Results += "Created anti-phishing policy: $PolicyName"

            # Create associated rule if rule details provided
            if (![string]::IsNullOrWhiteSpace($RuleName)) {
                $RuleParams = @{
                    Name           = $RuleName
                    AntiPhishPolicy = $PolicyName
                    Enabled        = $true
                }
                if ($null -ne $Priority) { $RuleParams.Priority = $Priority }
                if ($Request.Body.recipientDomainIs) { $RuleParams.RecipientDomainIs = $Request.Body.recipientDomainIs }
                if ($Request.Body.sentTo) { $RuleParams.SentTo = $Request.Body.sentTo }
                if ($Request.Body.sentToMemberOf) { $RuleParams.SentToMemberOf = $Request.Body.sentToMemberOf }
                if ($Request.Body.exceptIfRecipientDomainIs) { $RuleParams.ExceptIfRecipientDomainIs = $Request.Body.exceptIfRecipientDomainIs }
                if ($Request.Body.exceptIfSentTo) { $RuleParams.ExceptIfSentTo = $Request.Body.exceptIfSentTo }
                if ($Request.Body.exceptIfSentToMemberOf) { $RuleParams.ExceptIfSentToMemberOf = $Request.Body.exceptIfSentToMemberOf }

                New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-AntiPhishRule' -cmdParams $RuleParams -useSystemMailbox $true
                $Results += "Created anti-phishing rule: $RuleName"
            }
        } else {
            # Update existing policy
            $PolicyParams.Identity = $PolicyName
            $PolicyParams.Remove('Name')
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-AntiPhishPolicy' -cmdParams $PolicyParams -useSystemMailbox $true
            $Results += "Updated anti-phishing policy: $PolicyName"

            # Update rule if rule details provided
            if (![string]::IsNullOrWhiteSpace($RuleName)) {
                $RuleParams = @{
                    Identity = $RuleName
                }
                if ($null -ne $Priority) { $RuleParams.Priority = $Priority }
                if ($Request.Body.recipientDomainIs) { $RuleParams.RecipientDomainIs = $Request.Body.recipientDomainIs }
                if ($Request.Body.sentTo) { $RuleParams.SentTo = $Request.Body.sentTo }
                if ($Request.Body.sentToMemberOf) { $RuleParams.SentToMemberOf = $Request.Body.sentToMemberOf }
                if ($Request.Body.exceptIfRecipientDomainIs) { $RuleParams.ExceptIfRecipientDomainIs = $Request.Body.exceptIfRecipientDomainIs }
                if ($Request.Body.exceptIfSentTo) { $RuleParams.ExceptIfSentTo = $Request.Body.exceptIfSentTo }
                if ($Request.Body.exceptIfSentToMemberOf) { $RuleParams.ExceptIfSentToMemberOf = $Request.Body.exceptIfSentToMemberOf }

                New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-AntiPhishRule' -cmdParams $RuleParams -useSystemMailbox $true
                $Results += "Updated anti-phishing rule: $RuleName"
            }
        }

        $Result = $Results -join '; '
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to $Action anti-phishing policy $PolicyName for $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
