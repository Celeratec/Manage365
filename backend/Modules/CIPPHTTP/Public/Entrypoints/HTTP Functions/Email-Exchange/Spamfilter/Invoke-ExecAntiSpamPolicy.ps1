function Invoke-ExecAntiSpamPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Create or update custom anti-spam policies (HostedContentFilterPolicy and Rule).
        Supports SCL thresholds, spam actions, BCL threshold, and ASF settings.
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

        # SCL thresholds
        if ($null -ne $Request.Body.bulkThreshold) { $PolicyParams.BulkThreshold = $Request.Body.bulkThreshold }
        if ($null -ne $Request.Body.bulkSpamAction) { $PolicyParams.BulkSpamAction = $Request.Body.bulkSpamAction }
        if ($null -ne $Request.Body.spamAction) { $PolicyParams.SpamAction = $Request.Body.spamAction }
        if ($null -ne $Request.Body.highConfidenceSpamAction) { $PolicyParams.HighConfidenceSpamAction = $Request.Body.highConfidenceSpamAction }
        if ($null -ne $Request.Body.phishSpamAction) { $PolicyParams.PhishSpamAction = $Request.Body.phishSpamAction }
        if ($null -ne $Request.Body.highConfidencePhishAction) { $PolicyParams.HighConfidencePhishAction = $Request.Body.highConfidencePhishAction }

        # BCL threshold
        if ($null -ne $Request.Body.bulkSpamThreshold) { $PolicyParams.BulkSpamThreshold = $Request.Body.bulkSpamThreshold }

        # ASF (Advanced Spam Filter) settings
        if ($null -ne $Request.Body.increaseSCLImageLinks) { $PolicyParams.IncreaseScoreWithImageLinks = $Request.Body.increaseSCLImageLinks }
        if ($null -ne $Request.Body.increaseSCLNumericIPs) { $PolicyParams.IncreaseScoreWithNumericIps = $Request.Body.increaseSCLNumericIPs }
        if ($null -ne $Request.Body.increaseSCLRedirectToOtherPort) { $PolicyParams.IncreaseScoreWithRedirectToOtherPort = $Request.Body.increaseSCLRedirectToOtherPort }
        if ($null -ne $Request.Body.increaseSCLBizOrInfoUrls) { $PolicyParams.IncreaseScoreWithBizOrInfoUrls = $Request.Body.increaseSCLBizOrInfoUrls }
        if ($null -ne $Request.Body.markAsSpamEmptyMessages) { $PolicyParams.MarkAsSpamEmptyMessages = $Request.Body.markAsSpamEmptyMessages }
        if ($null -ne $Request.Body.markAsSpamJavaScriptInHtml) { $PolicyParams.MarkAsSpamJavaScriptInHtml = $Request.Body.markAsSpamJavaScriptInHtml }
        if ($null -ne $Request.Body.markAsSpamFramesInHtml) { $PolicyParams.MarkAsSpamFramesInHtml = $Request.Body.markAsSpamFramesInHtml }
        if ($null -ne $Request.Body.markAsSpamObjectTagsInHtml) { $PolicyParams.MarkAsSpamObjectTagsInHtml = $Request.Body.markAsSpamObjectTagsInHtml }
        if ($null -ne $Request.Body.markAsSpamEmbedTagsInHtml) { $PolicyParams.MarkAsSpamEmbedTagsInHtml = $Request.Body.markAsSpamEmbedTagsInHtml }
        if ($null -ne $Request.Body.markAsSpamFormTagsInHtml) { $PolicyParams.MarkAsSpamFormTagsInHtml = $Request.Body.markAsSpamFormTagsInHtml }
        if ($null -ne $Request.Body.markAsSpamWebBugsInHtml) { $PolicyParams.MarkAsSpamWebBugsInHtml = $Request.Body.markAsSpamWebBugsInHtml }
        if ($null -ne $Request.Body.markAsSpamSensitiveWordList) { $PolicyParams.MarkAsSpamSensitiveWordList = $Request.Body.markAsSpamSensitiveWordList }
        if ($null -ne $Request.Body.markAsSpamSpfRecordHardFail) { $PolicyParams.MarkAsSpamSpfRecordHardFail = $Request.Body.markAsSpamSpfRecordHardFail }
        if ($null -ne $Request.Body.markAsSpamFromAddressAuthFail) { $PolicyParams.MarkAsSpamFromAddressAuthFail = $Request.Body.markAsSpamFromAddressAuthFail }
        if ($null -ne $Request.Body.markAsSpamBulkMail) { $PolicyParams.MarkAsSpamBulkMail = $Request.Body.markAsSpamBulkMail }
        if ($null -ne $Request.Body.markAsSpamNdrBackscatter) { $PolicyParams.MarkAsSpamNdrBackscatter = $Request.Body.markAsSpamNdrBackscatter }

        # Allow/Block lists
        if ($Request.Body.allowedSenders) { $PolicyParams.AllowedSenders = $Request.Body.allowedSenders }
        if ($Request.Body.allowedSenderDomains) { $PolicyParams.AllowedSenderDomains = $Request.Body.allowedSenderDomains }
        if ($Request.Body.blockedSenders) { $PolicyParams.BlockedSenders = $Request.Body.blockedSenders }
        if ($Request.Body.blockedSenderDomains) { $PolicyParams.BlockedSenderDomains = $Request.Body.blockedSenderDomains }

        # Enable/Disable settings
        if ($null -ne $Request.Body.enableEndUserSpamNotifications) { $PolicyParams.EnableEndUserSpamNotifications = $Request.Body.enableEndUserSpamNotifications }
        if ($null -ne $Request.Body.endUserSpamNotificationFrequency) { $PolicyParams.EndUserSpamNotificationFrequency = $Request.Body.endUserSpamNotificationFrequency }
        if ($null -ne $Request.Body.enableLanguageBlockList) { $PolicyParams.EnableLanguageBlockList = $Request.Body.enableLanguageBlockList }
        if ($Request.Body.languageBlockList) { $PolicyParams.LanguageBlockList = $Request.Body.languageBlockList }
        if ($null -ne $Request.Body.enableRegionBlockList) { $PolicyParams.EnableRegionBlockList = $Request.Body.enableRegionBlockList }
        if ($Request.Body.regionBlockList) { $PolicyParams.RegionBlockList = $Request.Body.regionBlockList }

        # Quarantine/redirection settings
        if ($Request.Body.quarantineTag) { $PolicyParams.QuarantineTag = $Request.Body.quarantineTag }
        if ($Request.Body.redirectToRecipients) { $PolicyParams.RedirectToRecipients = $Request.Body.redirectToRecipients }

        # ZAP settings
        if ($null -ne $Request.Body.inlineSafetyTipsEnabled) { $PolicyParams.InlineSafetyTipsEnabled = $Request.Body.inlineSafetyTipsEnabled }
        if ($null -ne $Request.Body.zapEnabled) { $PolicyParams.ZapEnabled = $Request.Body.zapEnabled }

        $Results = @()

        if ($Action -eq 'New') {
            # Create new policy
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-HostedContentFilterPolicy' -cmdParams $PolicyParams -useSystemMailbox $true
            $Results += "Created anti-spam policy: $PolicyName"

            # Create associated rule if rule details provided
            if (![string]::IsNullOrWhiteSpace($RuleName)) {
                $RuleParams = @{
                    Name                      = $RuleName
                    HostedContentFilterPolicy = $PolicyName
                    Enabled                   = $true
                }
                if ($null -ne $Priority) { $RuleParams.Priority = $Priority }
                if ($Request.Body.recipientDomainIs) { $RuleParams.RecipientDomainIs = $Request.Body.recipientDomainIs }
                if ($Request.Body.sentTo) { $RuleParams.SentTo = $Request.Body.sentTo }
                if ($Request.Body.sentToMemberOf) { $RuleParams.SentToMemberOf = $Request.Body.sentToMemberOf }
                if ($Request.Body.exceptIfRecipientDomainIs) { $RuleParams.ExceptIfRecipientDomainIs = $Request.Body.exceptIfRecipientDomainIs }
                if ($Request.Body.exceptIfSentTo) { $RuleParams.ExceptIfSentTo = $Request.Body.exceptIfSentTo }
                if ($Request.Body.exceptIfSentToMemberOf) { $RuleParams.ExceptIfSentToMemberOf = $Request.Body.exceptIfSentToMemberOf }

                New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-HostedContentFilterRule' -cmdParams $RuleParams -useSystemMailbox $true
                $Results += "Created anti-spam rule: $RuleName"
            }
        } else {
            # Update existing policy
            $PolicyParams.Identity = $PolicyName
            $PolicyParams.Remove('Name')
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-HostedContentFilterPolicy' -cmdParams $PolicyParams -useSystemMailbox $true
            $Results += "Updated anti-spam policy: $PolicyName"

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

                New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-HostedContentFilterRule' -cmdParams $RuleParams -useSystemMailbox $true
                $Results += "Updated anti-spam rule: $RuleName"
            }
        }

        $Result = $Results -join '; '
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to $Action anti-spam policy $PolicyName for $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
