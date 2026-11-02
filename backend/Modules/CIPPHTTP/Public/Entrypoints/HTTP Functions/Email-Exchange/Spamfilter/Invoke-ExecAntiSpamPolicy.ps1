function Invoke-ExecAntiSpamPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Create or update custom anti-spam policies (HostedContentFilterPolicy and Rule).
        Supports SCL thresholds, spam actions, BCL threshold, and ASF settings.
        Allow lists and RedirectToRecipients are rejected - use ExecRemoveAntiSpamPolicy for deletions.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Action = $Request.Body.action  # New or Update
    $PolicyName = Get-CippQuarantineInputValue $Request.Body.policyName
    $RuleName = Get-CippQuarantineInputValue $Request.Body.ruleName
    $Priority = $Request.Body.priority

    try {
        # Normalize tenantFilter inside try block
        $TenantFilter = Get-CippNormalizedTenantFilter -TenantFilter $Request.Body.tenantFilter
        
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($Action)) { throw 'action is required.' }
        if ($Action -notin @('New', 'Update')) { throw 'action must be New or Update. Use ExecRemoveAntiSpamPolicy for removal.' }
        if ([string]::IsNullOrWhiteSpace($PolicyName)) { throw 'policyName is required.' }

        # Validate policy/rule names
        $Validation = Test-CippExchangeInputValidation -PolicyName $PolicyName
        if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        if (![string]::IsNullOrWhiteSpace($RuleName)) {
            $Validation = Test-CippExchangeInputValidation -RuleName $RuleName
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        }

        # Validate priority
        if ($null -ne $Priority) {
            $Validation = Test-CippExchangeInputValidation -Priority $Priority
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        }

        # Build policy parameters
        $PolicyParams = @{
            Name = $PolicyName
        }

        # SCL thresholds and actions
        if ($null -ne $Request.Body.bulkThreshold) { $PolicyParams.BulkThreshold = $Request.Body.bulkThreshold }
        if ($null -ne $Request.Body.bulkSpamAction) { 
            if ($Request.Body.bulkSpamAction -eq 'Redirect') {
                throw "Redirect actions require the Security Policy admin role. Contact your CIPP administrator to use the ExecRemoveAntiSpamPolicy endpoint for redirect configuration."
            }
            if ($Request.Body.bulkSpamAction -notin @('MoveToJmf', 'Quarantine', 'Delete', 'AddXHeader', 'ModifySubject')) {
                throw "bulkSpamAction must be one of: MoveToJmf, Quarantine, Delete, AddXHeader, ModifySubject"
            }
            $PolicyParams.BulkSpamAction = $Request.Body.bulkSpamAction 
        }
        if ($null -ne $Request.Body.spamAction) { 
            if ($Request.Body.spamAction -eq 'Redirect') {
                throw "Redirect actions require the Security Policy admin role. Contact your CIPP administrator to use the ExecRemoveAntiSpamPolicy endpoint for redirect configuration."
            }
            if ($Request.Body.spamAction -notin @('MoveToJmf', 'Quarantine', 'Delete', 'AddXHeader', 'ModifySubject')) {
                throw "spamAction must be one of: MoveToJmf, Quarantine, Delete, AddXHeader, ModifySubject"
            }
            $PolicyParams.SpamAction = $Request.Body.spamAction 
        }
        if ($null -ne $Request.Body.highConfidenceSpamAction) { 
            if ($Request.Body.highConfidenceSpamAction -eq 'Redirect') {
                throw "Redirect actions require the Security Policy admin role. Contact your CIPP administrator to use the ExecRemoveAntiSpamPolicy endpoint for redirect configuration."
            }
            if ($Request.Body.highConfidenceSpamAction -notin @('MoveToJmf', 'Quarantine', 'Delete')) {
                throw "highConfidenceSpamAction must be one of: MoveToJmf, Quarantine, Delete"
            }
            $PolicyParams.HighConfidenceSpamAction = $Request.Body.highConfidenceSpamAction 
        }
        if ($null -ne $Request.Body.phishSpamAction) { 
            if ($Request.Body.phishSpamAction -eq 'Redirect') {
                throw "Redirect actions require the Security Policy admin role. Contact your CIPP administrator to use the ExecRemoveAntiSpamPolicy endpoint for redirect configuration."
            }
            if ($Request.Body.phishSpamAction -notin @('MoveToJmf', 'Quarantine', 'Delete')) {
                throw "phishSpamAction must be one of: MoveToJmf, Quarantine, Delete"
            }
            $PolicyParams.PhishSpamAction = $Request.Body.phishSpamAction 
        }
        if ($null -ne $Request.Body.highConfidencePhishAction) { 
            if ($Request.Body.highConfidencePhishAction -eq 'Redirect') {
                throw "Redirect actions require the Security Policy admin role. Contact your CIPP administrator to use the ExecRemoveAntiSpamPolicy endpoint for redirect configuration."
            }
            if ($Request.Body.highConfidencePhishAction -notin @('MoveToJmf', 'Quarantine', 'Delete')) {
                throw "highConfidencePhishAction must be one of: MoveToJmf, Quarantine, Delete"
            }
            $PolicyParams.HighConfidencePhishAction = $Request.Body.highConfidencePhishAction 
        }

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

        # Allow/Block lists - rejected (require SecurityPolicy.ReadWrite which this endpoint doesn't have)
        if ($Request.Body.allowedSenders -or $Request.Body.allowedSenderDomains -or $Request.Body.blockedSenders -or $Request.Body.blockedSenderDomains) {
            throw 'Allow/block lists require Exchange.SecurityPolicy.ReadWrite. Use a separate endpoint for allow/block list management.'
        }

        # Language/Region filters - use helper for validation
        if ($null -ne $Request.Body.enableLanguageBlockList) { $PolicyParams.EnableLanguageBlockList = $Request.Body.enableLanguageBlockList }
        if ($Request.Body.languageBlockList) { 
            $Validation = Test-CippExchangeInputValidation -LanguageBlockList $Request.Body.languageBlockList
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.LanguageBlockList = $Request.Body.languageBlockList 
        }
        if ($null -ne $Request.Body.enableRegionBlockList) { $PolicyParams.EnableRegionBlockList = $Request.Body.enableRegionBlockList }
        if ($Request.Body.regionBlockList) { 
            $Validation = Test-CippExchangeInputValidation -RegionBlockList $Request.Body.regionBlockList
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.RegionBlockList = $Request.Body.regionBlockList 
        }

        # Specific quarantine tags (not generic) - use helper for validation
        if ($Request.Body.spamQuarantineTag) { 
            $Validation = Test-CippExchangeInputValidation -QuarantineTag $Request.Body.spamQuarantineTag
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.SpamQuarantineTag = $Request.Body.spamQuarantineTag 
        }
        if ($Request.Body.highConfidenceSpamQuarantineTag) { 
            $Validation = Test-CippExchangeInputValidation -QuarantineTag $Request.Body.highConfidenceSpamQuarantineTag
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.HighConfidenceSpamQuarantineTag = $Request.Body.highConfidenceSpamQuarantineTag 
        }
        if ($Request.Body.phishQuarantineTag) { 
            $Validation = Test-CippExchangeInputValidation -QuarantineTag $Request.Body.phishQuarantineTag
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.PhishQuarantineTag = $Request.Body.phishQuarantineTag 
        }
        if ($Request.Body.highConfidencePhishQuarantineTag) { 
            $Validation = Test-CippExchangeInputValidation -QuarantineTag $Request.Body.highConfidencePhishQuarantineTag
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.HighConfidencePhishQuarantineTag = $Request.Body.highConfidencePhishQuarantineTag 
        }
        if ($Request.Body.bulkQuarantineTag) {
            $Validation = Test-CippExchangeInputValidation -QuarantineTag $Request.Body.bulkQuarantineTag
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.BulkQuarantineTag = $Request.Body.bulkQuarantineTag
        }

        # RedirectToRecipients - rejected (requires SecurityPolicy.ReadWrite which this endpoint doesn't have)
        if ($Request.Body.redirectToRecipients) {
            throw 'RedirectToRecipients requires Exchange.SecurityPolicy.ReadWrite. Use a separate endpoint for redirect configuration.'
        }

        # ZAP settings (specific, not generic)
        if ($null -ne $Request.Body.spamZapEnabled) { $PolicyParams.SpamZapEnabled = $Request.Body.spamZapEnabled }
        if ($null -ne $Request.Body.phishZapEnabled) { $PolicyParams.PhishZapEnabled = $Request.Body.phishZapEnabled }

        # Inline safety tips
        if ($null -ne $Request.Body.inlineSafetyTipsEnabled) { $PolicyParams.InlineSafetyTipsEnabled = $Request.Body.inlineSafetyTipsEnabled }

        $Results = @()
        $AuditLog = @()

        if ($Action -eq 'New') {
            # Create new policy
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-HostedContentFilterPolicy' -cmdParams $PolicyParams -useSystemMailbox $true
            $AuditLog += "Created anti-spam policy: $PolicyName with settings: $($PolicyParams | ConvertTo-Json -Compress)"
            $Results += "Created anti-spam policy: $PolicyName"

            # Create associated rule if rule details provided
            if (![string]::IsNullOrWhiteSpace($RuleName)) {
                $RuleParams = @{
                    Name                      = $RuleName
                    HostedContentFilterPolicy = $PolicyName
                    Enabled                   = $true
                }
                if ($null -ne $Priority) { $RuleParams.Priority = $Priority }
                
                # Validate and add scoping
                if ($Request.Body.recipientDomainIs) { 
                    $Validation = Test-CippExchangeInputValidation -Domains $Request.Body.recipientDomainIs
                    if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    $RuleParams.RecipientDomainIs = $Request.Body.recipientDomainIs 
                }
                if ($Request.Body.sentTo) { 
                    $Validation = Test-CippExchangeInputValidation -EmailAddresses $Request.Body.sentTo
                    if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    $RuleParams.SentTo = $Request.Body.sentTo 
                }
                if ($Request.Body.sentToMemberOf) { $RuleParams.SentToMemberOf = $Request.Body.sentToMemberOf }
                if ($Request.Body.exceptIfRecipientDomainIs) { 
                    $Validation = Test-CippExchangeInputValidation -Domains $Request.Body.exceptIfRecipientDomainIs
                    if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    $RuleParams.ExceptIfRecipientDomainIs = $Request.Body.exceptIfRecipientDomainIs 
                }
                if ($Request.Body.exceptIfSentTo) { 
                    $Validation = Test-CippExchangeInputValidation -EmailAddresses $Request.Body.exceptIfSentTo
                    if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    $RuleParams.ExceptIfSentTo = $Request.Body.exceptIfSentTo 
                }
                if ($Request.Body.exceptIfSentToMemberOf) { $RuleParams.ExceptIfSentToMemberOf = $Request.Body.exceptIfSentToMemberOf }

                New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-HostedContentFilterRule' -cmdParams $RuleParams -useSystemMailbox $true
                $AuditLog += "Created anti-spam rule: $RuleName with settings: $($RuleParams | ConvertTo-Json -Compress)"
                $Results += "Created anti-spam rule: $RuleName"
            }
        } else {
            # Update existing policy - read before for audit
            $BeforePolicy = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-HostedContentFilterPolicy' -cmdParams @{ Identity = $PolicyName } -useSystemMailbox $true
            
            $PolicyParams.Identity = $PolicyName
            $PolicyParams.Remove('Name')
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-HostedContentFilterPolicy' -cmdParams $PolicyParams -useSystemMailbox $true
            
            $AuditLog += "Updated anti-spam policy: $PolicyName. Before: BulkThreshold=$($BeforePolicy.BulkThreshold), SpamAction=$($BeforePolicy.SpamAction). After: BulkThreshold=$($PolicyParams.BulkThreshold), SpamAction=$($PolicyParams.SpamAction)"
            $Results += "Updated anti-spam policy: $PolicyName"

            # Update rule if rule details provided
            if (![string]::IsNullOrWhiteSpace($RuleName)) {
                $BeforeRule = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-HostedContentFilterRule' -cmdParams @{ Identity = $RuleName } -useSystemMailbox $true
                
                $RuleParams = @{
                    Identity = $RuleName
                }
                if ($null -ne $Priority) { $RuleParams.Priority = $Priority }
                
                if ($Request.Body.recipientDomainIs) { 
                    $Validation = Test-CippExchangeInputValidation -Domains $Request.Body.recipientDomainIs
                    if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    $RuleParams.RecipientDomainIs = $Request.Body.recipientDomainIs 
                }
                if ($Request.Body.sentTo) { 
                    $Validation = Test-CippExchangeInputValidation -EmailAddresses $Request.Body.sentTo
                    if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    $RuleParams.SentTo = $Request.Body.sentTo 
                }
                if ($Request.Body.sentToMemberOf) { $RuleParams.SentToMemberOf = $Request.Body.sentToMemberOf }
                if ($Request.Body.exceptIfRecipientDomainIs) { 
                    $Validation = Test-CippExchangeInputValidation -Domains $Request.Body.exceptIfRecipientDomainIs
                    if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    $RuleParams.ExceptIfRecipientDomainIs = $Request.Body.exceptIfRecipientDomainIs 
                }
                if ($Request.Body.exceptIfSentTo) { 
                    $Validation = Test-CippExchangeInputValidation -EmailAddresses $Request.Body.exceptIfSentTo
                    if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    $RuleParams.ExceptIfSentTo = $Request.Body.exceptIfSentTo 
                }
                if ($Request.Body.exceptIfSentToMemberOf) { $RuleParams.ExceptIfSentToMemberOf = $Request.Body.exceptIfSentToMemberOf }

                New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-HostedContentFilterRule' -cmdParams $RuleParams -useSystemMailbox $true
                $AuditLog += "Updated anti-spam rule: $RuleName. Before: Priority=$($BeforeRule.Priority). After: Priority=$($RuleParams.Priority)"
                $Results += "Updated anti-spam rule: $RuleName"
            }
        }

        $Result = $Results -join '; '
        $AuditMessage = if ($AuditLog.Count -gt 0) { $AuditLog -join '; ' } else { $Result }
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Info'
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
