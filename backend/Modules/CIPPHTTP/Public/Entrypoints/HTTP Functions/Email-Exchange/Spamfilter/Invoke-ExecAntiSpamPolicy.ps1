function Invoke-ExecAntiSpamPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SecurityPolicy.ReadWrite
    .DESCRIPTION
        Create or update custom anti-spam policies (HostedContentFilterPolicy and Rule).
        Supports SCL thresholds, spam actions, BCL threshold, and ASF settings.
        This role gates allow lists and RedirectToRecipients which can bypass security.
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
        if ($Action -notin @('New', 'Update', 'Remove')) { throw 'action must be New, Update, or Remove.' }
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
            if ($Request.Body.bulkSpamAction -notin @('MoveToJmf', 'Quarantine', 'Delete', 'Redirect', 'AddXHeader', 'ModifySubject')) {
                throw "bulkSpamAction must be one of: MoveToJmf, Quarantine, Delete, Redirect, AddXHeader, ModifySubject"
            }
            $PolicyParams.BulkSpamAction = $Request.Body.bulkSpamAction 
        }
        if ($null -ne $Request.Body.spamAction) { 
            if ($Request.Body.spamAction -notin @('MoveToJmf', 'Quarantine', 'Delete', 'Redirect', 'AddXHeader', 'ModifySubject')) {
                throw "spamAction must be one of: MoveToJmf, Quarantine, Delete, Redirect, AddXHeader, ModifySubject"
            }
            $PolicyParams.SpamAction = $Request.Body.spamAction 
        }
        if ($null -ne $Request.Body.highConfidenceSpamAction) { 
            if ($Request.Body.highConfidenceSpamAction -notin @('MoveToJmf', 'Quarantine', 'Delete', 'Redirect')) {
                throw "highConfidenceSpamAction must be one of: MoveToJmf, Quarantine, Delete, Redirect"
            }
            $PolicyParams.HighConfidenceSpamAction = $Request.Body.highConfidenceSpamAction 
        }
        if ($null -ne $Request.Body.phishSpamAction) { 
            if ($Request.Body.phishSpamAction -notin @('MoveToJmf', 'Quarantine', 'Delete', 'Redirect')) {
                throw "phishSpamAction must be one of: MoveToJmf, Quarantine, Delete, Redirect"
            }
            $PolicyParams.PhishSpamAction = $Request.Body.phishSpamAction 
        }
        if ($null -ne $Request.Body.highConfidencePhishAction) { 
            if ($Request.Body.highConfidencePhishAction -notin @('MoveToJmf', 'Quarantine', 'Delete', 'Redirect')) {
                throw "highConfidencePhishAction must be one of: MoveToJmf, Quarantine, Delete, Redirect"
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

        # Allow/Block lists - require Exchange.SecurityPolicy.ReadWrite
        if ($Request.Body.allowedSenders -or $Request.Body.allowedSenderDomains -or $Request.Body.blockedSenders -or $Request.Body.blockedSenderDomains) {
            # Note: These require elevated permissions - checked by role
            if ($Request.Body.allowedSenders) { 
                $Validation = Test-CippExchangeInputValidation -EmailAddresses $Request.Body.allowedSenders
                if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                $PolicyParams.AllowedSenders = $Request.Body.allowedSenders 
            }
            if ($Request.Body.allowedSenderDomains) { 
                $Validation = Test-CippExchangeInputValidation -Domains $Request.Body.allowedSenderDomains
                if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                $PolicyParams.AllowedSenderDomains = $Request.Body.allowedSenderDomains 
            }
            if ($Request.Body.blockedSenders) { 
                $Validation = Test-CippExchangeInputValidation -EmailAddresses $Request.Body.blockedSenders
                if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                $PolicyParams.BlockedSenders = $Request.Body.blockedSenders 
            }
            if ($Request.Body.blockedSenderDomains) { 
                $Validation = Test-CippExchangeInputValidation -Domains $Request.Body.blockedSenderDomains
                if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                $PolicyParams.BlockedSenderDomains = $Request.Body.blockedSenderDomains 
            }
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

        # RedirectToRecipients - must be in accepted domains
        if ($Request.Body.redirectToRecipients) {
            $Validation = Test-CippExchangeInputValidation -EmailAddresses $Request.Body.redirectToRecipients
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            
            # Verify recipients are in accepted domains (use DomainName property)
            $AcceptedDomains = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-AcceptedDomain' | Select-Object -ExpandProperty DomainName
            foreach ($Recipient in $Request.Body.redirectToRecipients) {
                $RecipientDomain = ($Recipient -split '@')[1]
                if ($RecipientDomain -notin $AcceptedDomains) {
                    throw "RedirectToRecipients address '$Recipient' must be in an accepted domain of the tenant"
                }
            }
            $PolicyParams.RedirectToRecipients = $Request.Body.redirectToRecipients 
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
        } elseif ($Action -eq 'Remove') {
            # Remove policy and rule (for rollback) - requires Exchange.SecurityPolicy.ReadWrite
            # Guard: Get the policy first and refuse if it's default, built-in, or preset
            try {
                $ExistingPolicy = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-HostedContentFilterPolicy' -cmdParams @{ Identity = $PolicyName } -useSystemMailbox $true
            } catch {
                # Don't swallow the Get error - return it
                throw "Failed to get policy '$PolicyName': $($_.Exception.Message)"
            }
            
            if ($ExistingPolicy.IsDefault -eq $true) {
                throw "Cannot remove default policy '$PolicyName'"
            }
            if ($ExistingPolicy.RecommendedPolicyType -and $ExistingPolicy.RecommendedPolicyType -ne 'Custom') {
                throw "Cannot remove $($ExistingPolicy.RecommendedPolicyType) policy '$PolicyName'. Only custom policies can be removed."
            }
            
            # Audit before-state
            $AuditLog += "Before Remove - Policy: $($ExistingPolicy | ConvertTo-Json -Compress -Depth 2)"
            
            # First remove any associated rules - don't swallow errors
            $ExistingRules = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-HostedContentFilterRule' -useSystemMailbox $true | 
                Where-Object { $_.HostedContentFilterPolicy -eq $PolicyName }
            
            foreach ($Rule in $ExistingRules) {
                # Audit before-state for rule
                $AuditLog += "Before Remove - Rule: $($Rule | ConvertTo-Json -Compress -Depth 2)"
                
                # Don't swallow errors - if rule removal fails, abort
                try {
                    New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-HostedContentFilterRule' -cmdParams @{ Identity = $Rule.Name; Confirm = $false } -useSystemMailbox $true
                    $AuditLog += "Removed anti-spam rule: $($Rule.Name)"
                    $Results += "Removed anti-spam rule: $($Rule.Name)"
                } catch {
                    throw "Failed to remove rule '$($Rule.Name)': $($_.Exception.Message). Policy removal aborted."
                }
            }
            
            # Then remove the policy
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-HostedContentFilterPolicy' -cmdParams @{ Identity = $PolicyName; Confirm = $false } -useSystemMailbox $true
            $AuditLog += "Removed anti-spam policy: $PolicyName"
            $Results += "Removed anti-spam policy: $PolicyName"
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
