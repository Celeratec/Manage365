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

        # Impersonation protection
        if ($null -ne $Request.Body.enableTargetedUserProtection) { $PolicyParams.EnableTargetedUserProtection = $Request.Body.enableTargetedUserProtection }
        if ($Request.Body.targetedUsersToProtect) { $PolicyParams.TargetedUsersToProtect = $Request.Body.targetedUsersToProtect }
        if ($null -ne $Request.Body.enableTargetedDomainsProtection) { $PolicyParams.EnableTargetedDomainsProtection = $Request.Body.enableTargetedDomainsProtection }
        if ($Request.Body.targetedDomainsToProtect) { 
            $Validation = Test-CippExchangeInputValidation -Domains $Request.Body.targetedDomainsToProtect
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.TargetedDomainsToProtect = $Request.Body.targetedDomainsToProtect 
        }
        if ($null -ne $Request.Body.targetedUserProtectionAction) { 
            if ($Request.Body.targetedUserProtectionAction -notin @('NoAction', 'BccMessage', 'Redirect', 'Quarantine', 'Delete')) {
                throw "targetedUserProtectionAction must be one of: NoAction, BccMessage, Redirect, Quarantine, Delete"
            }
            $PolicyParams.TargetedUserProtectionAction = $Request.Body.targetedUserProtectionAction 
        }
        if ($null -ne $Request.Body.targetedDomainProtectionAction) { 
            if ($Request.Body.targetedDomainProtectionAction -notin @('NoAction', 'BccMessage', 'Redirect', 'Quarantine', 'Delete')) {
                throw "targetedDomainProtectionAction must be one of: NoAction, BccMessage, Redirect, Quarantine, Delete"
            }
            $PolicyParams.TargetedDomainProtectionAction = $Request.Body.targetedDomainProtectionAction 
        }

        # Mailbox intelligence
        if ($null -ne $Request.Body.enableMailboxIntelligence) { $PolicyParams.EnableMailboxIntelligence = $Request.Body.enableMailboxIntelligence }
        if ($null -ne $Request.Body.enableMailboxIntelligenceProtection) { $PolicyParams.EnableMailboxIntelligenceProtection = $Request.Body.enableMailboxIntelligenceProtection }
        if ($null -ne $Request.Body.mailboxIntelligenceProtectionAction) { 
            if ($Request.Body.mailboxIntelligenceProtectionAction -notin @('NoAction', 'BccMessage', 'Redirect', 'Quarantine', 'Delete', 'MoveToJmf')) {
                throw "mailboxIntelligenceProtectionAction must be one of: NoAction, BccMessage, Redirect, Quarantine, Delete, MoveToJmf"
            }
            $PolicyParams.MailboxIntelligenceProtectionAction = $Request.Body.mailboxIntelligenceProtectionAction 
        }

        # Safety tips
        if ($null -ne $Request.Body.enableSimilarUsersSafetyTips) { $PolicyParams.EnableSimilarUsersSafetyTips = $Request.Body.enableSimilarUsersSafetyTips }
        if ($null -ne $Request.Body.enableSimilarDomainsSafetyTips) { $PolicyParams.EnableSimilarDomainsSafetyTips = $Request.Body.enableSimilarDomainsSafetyTips }
        if ($null -ne $Request.Body.enableUnusualCharactersSafetyTips) { $PolicyParams.EnableUnusualCharactersSafetyTips = $Request.Body.enableUnusualCharactersSafetyTips }

        # Spoofing (EnableAntiSpoofEnforcement removed - doesn't exist)
        if ($null -ne $Request.Body.enableUnauthenticatedSender) { $PolicyParams.EnableUnauthenticatedSender = $Request.Body.enableUnauthenticatedSender }
        if ($null -ne $Request.Body.authenticationFailAction) { 
            if ($Request.Body.authenticationFailAction -notin @('MoveToJmf', 'Quarantine')) {
                throw "authenticationFailAction must be one of: MoveToJmf, Quarantine"
            }
            $PolicyParams.AuthenticationFailAction = $Request.Body.authenticationFailAction 
        }

        # Actions
        if ($null -ne $Request.Body.phishThresholdLevel) { 
            if ($Request.Body.phishThresholdLevel -notin @(1, 2, 3, 4)) {
                throw "phishThresholdLevel must be 1, 2, 3, or 4"
            }
            $PolicyParams.PhishThresholdLevel = $Request.Body.phishThresholdLevel 
        }

        # Trusted senders/domains
        if ($Request.Body.excludedSenders) { 
            $Validation = Test-CippExchangeInputValidation -EmailAddresses $Request.Body.excludedSenders
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.ExcludedSenders = $Request.Body.excludedSenders 
        }
        if ($Request.Body.excludedDomains) { 
            $Validation = Test-CippExchangeInputValidation -Domains $Request.Body.excludedDomains
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.ExcludedDomains = $Request.Body.excludedDomains 
        }

        # Quarantine/redirection
        if ($Request.Body.targetedUserQuarantineTag) {
            $Validation = Test-CippExchangeInputValidation -QuarantineTag $Request.Body.targetedUserQuarantineTag
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.TargetedUserQuarantineTag = $Request.Body.targetedUserQuarantineTag
        }
        if ($Request.Body.targetedDomainQuarantineTag) {
            $Validation = Test-CippExchangeInputValidation -QuarantineTag $Request.Body.targetedDomainQuarantineTag
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.TargetedDomainQuarantineTag = $Request.Body.targetedDomainQuarantineTag
        }
        if ($Request.Body.mailboxIntelligenceQuarantineTag) {
            $Validation = Test-CippExchangeInputValidation -QuarantineTag $Request.Body.mailboxIntelligenceQuarantineTag
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
            $PolicyParams.MailboxIntelligenceQuarantineTag = $Request.Body.mailboxIntelligenceQuarantineTag
        }

        # Honor DMARC
        if ($null -ne $Request.Body.honorDmarcPolicy) { $PolicyParams.HonorDmarcPolicy = $Request.Body.honorDmarcPolicy }

        $Results = @()
        $AuditLog = @()

        if ($Action -eq 'New') {
            # Create new policy
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-AntiPhishPolicy' -cmdParams $PolicyParams -useSystemMailbox $true
            $AuditLog += "Created anti-phishing policy: $PolicyName with settings: $($PolicyParams | ConvertTo-Json -Compress)"
            $Results += "Created anti-phishing policy: $PolicyName"

            # Create associated rule if rule details provided
            if (![string]::IsNullOrWhiteSpace($RuleName)) {
                $RuleParams = @{
                    Name            = $RuleName
                    AntiPhishPolicy = $PolicyName
                    Enabled         = $true
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

                New-ExoRequest -tenantid $TenantFilter -cmdlet 'New-AntiPhishRule' -cmdParams $RuleParams -useSystemMailbox $true
                $AuditLog += "Created anti-phishing rule: $RuleName with settings: $($RuleParams | ConvertTo-Json -Compress)"
                $Results += "Created anti-phishing rule: $RuleName"
            }
        } elseif ($Action -eq 'Remove') {
            # Remove policy and rule (for rollback) - requires Exchange.SecurityPolicy.ReadWrite
            # Guard: Get the policy first and refuse if it's default, built-in, or preset
            try {
                $ExistingPolicy = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-AntiPhishPolicy' -cmdParams @{ Identity = $PolicyName } -useSystemMailbox $true
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
            $ExistingRules = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-AntiPhishRule' -useSystemMailbox $true | 
                Where-Object { $_.AntiPhishPolicy -eq $PolicyName }
            
            foreach ($Rule in $ExistingRules) {
                # Audit before-state for rule
                $AuditLog += "Before Remove - Rule: $($Rule | ConvertTo-Json -Compress -Depth 2)"
                
                # Don't swallow errors - if rule removal fails, abort
                try {
                    New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-AntiPhishRule' -cmdParams @{ Identity = $Rule.Name; Confirm = $false } -useSystemMailbox $true
                    $AuditLog += "Removed anti-phishing rule: $($Rule.Name)"
                    $Results += "Removed anti-phishing rule: $($Rule.Name)"
                } catch {
                    throw "Failed to remove rule '$($Rule.Name)': $($_.Exception.Message). Policy removal aborted."
                }
            }
            
            # Then remove the policy
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Remove-AntiPhishPolicy' -cmdParams @{ Identity = $PolicyName; Confirm = $false } -useSystemMailbox $true
            $AuditLog += "Removed anti-phishing policy: $PolicyName"
            $Results += "Removed anti-phishing policy: $PolicyName"
        } else {
            # Update existing policy - read before for audit
            $BeforePolicy = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-AntiPhishPolicy' -cmdParams @{ Identity = $PolicyName } -useSystemMailbox $true
            
            $PolicyParams.Identity = $PolicyName
            $PolicyParams.Remove('Name')
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-AntiPhishPolicy' -cmdParams $PolicyParams -useSystemMailbox $true
            
            $AuditLog += "Updated anti-phishing policy: $PolicyName. Before: EnableMailboxIntelligence=$($BeforePolicy.EnableMailboxIntelligence), PhishThresholdLevel=$($BeforePolicy.PhishThresholdLevel)"
            $Results += "Updated anti-phishing policy: $PolicyName"

            # Update rule if rule details provided
            if (![string]::IsNullOrWhiteSpace($RuleName)) {
                $BeforeRule = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-AntiPhishRule' -cmdParams @{ Identity = $RuleName } -useSystemMailbox $true
                
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

                New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-AntiPhishRule' -cmdParams $RuleParams -useSystemMailbox $true
                $AuditLog += "Updated anti-phishing rule: $RuleName. Before: Priority=$($BeforeRule.Priority)"
                $Results += "Updated anti-phishing rule: $RuleName"
            }
        }

        $Result = $Results -join '; '
        $AuditMessage = if ($AuditLog.Count -gt 0) { $AuditLog -join '; ' } else { $Result }
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Info'
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
