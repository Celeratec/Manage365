function Invoke-ExecCustomMailFilterPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Creates, updates, or deletes a custom anti-spam, anti-phish, or anti-malware policy and its rule.
        Every write snapshots the current policy, requires a numeric ticket ID, and returns a rollback payload.
        Set dryRun to true to receive the diff without applying it. A change that leaves the tenant with
        weaker filtering is rejected unless allowWeakerProtection is true.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    # Tenant the policy change applies to.
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
    # Numeric ticket ID recorded with the audit row.
    $TicketNumber = $Request.Query.ticketNumber ?? $Request.Body.ticketNumber ?? $Request.Query.TicketNumber ?? $Request.Body.TicketNumber
    # AntiSpam, AntiPhish, or AntiMalware.
    $PolicyType = $Request.Query.policyType ?? $Request.Body.policyType
    # Create, Update, or Delete.
    $Operation = $Request.Query.operation ?? $Request.Body.operation
    # Policy name. Default and the built-in preset policies cannot be deleted.
    $Name = $Request.Query.name ?? $Request.Body.name
    # Rule name. Defaults to the policy name.
    $RuleName = $Request.Query.ruleName ?? $Request.Body.ruleName
    # When true, return the diff and rollback payload without changing the tenant.
    $DryRun = $Request.Query.dryRun ?? $Request.Body.dryRun
    # Explicit override that allows a change which weakens current protection.
    $AllowWeakerProtection = $Request.Query.allowWeakerProtection ?? $Request.Body.allowWeakerProtection
    # Anti-spam bulk complaint threshold, 1 to 9. A higher number lets more bulk mail through.
    $BulkThreshold = $Request.Query.bulkThreshold ?? $Request.Body.bulkThreshold
    # Action for spam: MoveToJmf, AddXHeader, ModifySubject, Redirect, Delete, or Quarantine.
    $SpamAction = $Request.Query.spamAction ?? $Request.Body.spamAction
    # Action for high-confidence spam.
    $HighConfidenceSpamAction = $Request.Query.highConfidenceSpamAction ?? $Request.Body.highConfidenceSpamAction
    # Action for bulk mail.
    $BulkSpamAction = $Request.Query.bulkSpamAction ?? $Request.Body.bulkSpamAction
    # Action when a targeted user is impersonated.
    $TargetedUserProtectionAction = $Request.Query.targetedUserProtectionAction ?? $Request.Body.targetedUserProtectionAction
    # Action when a targeted domain is impersonated.
    $TargetedDomainProtectionAction = $Request.Query.targetedDomainProtectionAction ?? $Request.Body.targetedDomainProtectionAction
    # Action when mailbox intelligence flags a phish.
    $MailboxIntelligenceProtectionAction = $Request.Query.mailboxIntelligenceProtectionAction ?? $Request.Body.mailboxIntelligenceProtectionAction
    # Turns the common attachment file-type filter on or off.
    $EnableFileFilter = $Request.Query.enableFileFilter ?? $Request.Body.enableFileFilter
    # File extensions the malware filter blocks.
    $FileTypes = $Request.Query.fileTypes ?? $Request.Body.fileTypes
    # What happens to a filtered file type: Reject or Quarantine.
    $FileTypeAction = $Request.Query.fileTypeAction ?? $Request.Body.fileTypeAction
    # Whether the policy rule is enabled.
    $Enabled = $Request.Query.enabled ?? $Request.Body.enabled
    # Rule priority. A lower number wins over later rules.
    $Priority = $Request.Query.priority ?? $Request.Body.priority
    # Users the rule applies to.
    $SentTo = $Request.Query.sentTo ?? $Request.Body.sentTo
    # Groups the rule applies to.
    $SentToMemberOf = $Request.Query.sentToMemberOf ?? $Request.Body.sentToMemberOf
    # Domains the rule applies to.
    $RecipientDomainIs = $Request.Query.recipientDomainIs ?? $Request.Body.recipientDomainIs

    $Settings = @{}
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'bulkThreshold') { $Settings.BulkThreshold = $BulkThreshold }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'spamAction') { $Settings.SpamAction = $SpamAction }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'highConfidenceSpamAction') { $Settings.HighConfidenceSpamAction = $HighConfidenceSpamAction }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'bulkSpamAction') { $Settings.BulkSpamAction = $BulkSpamAction }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'targetedUserProtectionAction') { $Settings.TargetedUserProtectionAction = $TargetedUserProtectionAction }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'targetedDomainProtectionAction') { $Settings.TargetedDomainProtectionAction = $TargetedDomainProtectionAction }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'mailboxIntelligenceProtectionAction') { $Settings.MailboxIntelligenceProtectionAction = $MailboxIntelligenceProtectionAction }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'enableFileFilter') { $Settings.EnableFileFilter = $EnableFileFilter }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'fileTypes') { $Settings.FileTypes = $FileTypes }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'fileTypeAction') { $Settings.FileTypeAction = $FileTypeAction }

    $RuleSettings = @{}
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'enabled') { $RuleSettings.Enabled = $Enabled }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'priority') { $RuleSettings.Priority = $Priority }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'sentTo') { $RuleSettings.SentTo = $SentTo }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'sentToMemberOf') { $RuleSettings.SentToMemberOf = $SentToMemberOf }
    if (Test-CIPPMailFilterRequestField -Request $Request -Name 'recipientDomainIs') { $RuleSettings.RecipientDomainIs = $RecipientDomainIs }

    try {
        $Caller = Get-CIPPMailFilterCaller -Headers $Request.Headers
        $Outcome = Invoke-CIPPCustomMailFilterPolicy -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller `
            -PolicyType $PolicyType -Operation $Operation -Name $Name -RuleName $RuleName `
            -Settings $Settings -RuleSettings $RuleSettings -DryRun $DryRun -AllowWeakerProtection $AllowWeakerProtection -ApiName $APIName
        $Severity = if ($Outcome.Blocked -or $Outcome.Error) { 'Warning' } else { 'Info' }
        try {
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "$($Outcome.Results) Caller $Caller. Ticket $TicketNumber." -Sev $Severity
        } catch {
            $Outcome.LogWarning = $_.Exception.Message
        }
        $StatusCode = if ($Outcome.Blocked) { [HttpStatusCode]::BadRequest } elseif ($Outcome.Error) { [HttpStatusCode]::InternalServerError } else { [HttpStatusCode]::OK }
        $Body = $Outcome
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Body = @{ Results = $ErrorMessage.NormalizedError; Applied = $false }
        $StatusCode = [HttpStatusCode]::BadRequest
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Custom mail filter change failed: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
