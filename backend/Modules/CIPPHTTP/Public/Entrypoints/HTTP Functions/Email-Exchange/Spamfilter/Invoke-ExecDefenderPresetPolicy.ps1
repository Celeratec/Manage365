function Invoke-ExecDefenderPresetPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Enable, disable, or rescope Defender preset security policies (Standard or Strict).
        Manages EOP and ATP Protection Policy Rules.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter | Select-Object -First 1
    $Action = $Request.Body.action  # Enable, Disable, or Rescope
    $PolicyType = $Request.Body.policyType  # Standard or Strict
    $RuleType = $Request.Body.ruleType  # EOP or ATP or Both

    try {
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($Action)) { throw 'action is required.' }
        if ($Action -notin @('Enable', 'Disable', 'Rescope')) { throw 'action must be Enable, Disable, or Rescope.' }
        if ([string]::IsNullOrWhiteSpace($PolicyType)) { throw 'policyType is required.' }
        if ($PolicyType -notin @('Standard', 'Strict')) { throw 'policyType must be Standard or Strict.' }
        if ([string]::IsNullOrWhiteSpace($RuleType)) { throw 'ruleType is required.' }
        if ($RuleType -notin @('EOP', 'ATP', 'Both')) { throw 'ruleType must be EOP, ATP, or Both.' }

        $Results = @()

        # Determine which rules to manage
        $RulesToManage = @()
        if ($RuleType -in @('EOP', 'Both')) {
            $RulesToManage += @{ Type = 'EOP'; Cmdlet = if ($PolicyType -eq 'Standard') { 'Standard Preset Security Policy' } else { 'Strict Preset Security Policy' } }
        }
        if ($RuleType -in @('ATP', 'Both')) {
            $RulesToManage += @{ Type = 'ATP'; Cmdlet = if ($PolicyType -eq 'Standard') { 'Standard Preset Security Policy' } else { 'Strict Preset Security Policy' } }
        }

        foreach ($Rule in $RulesToManage) {
            $RuleBaseName = "$($Rule.Type) $($Rule.Cmdlet)"
            
            switch ($Action) {
                'Enable' {
                    $CmdletName = if ($Rule.Type -eq 'EOP') { 'Enable-EOPProtectionPolicyRule' } else { 'Enable-ATPProtectionPolicyRule' }
                    New-ExoRequest -tenantid $TenantFilter -cmdlet $CmdletName -cmdParams @{
                        Identity = $RuleBaseName
                    } -useSystemMailbox $true
                    $Results += "Enabled $RuleBaseName"
                }
                'Disable' {
                    $CmdletName = if ($Rule.Type -eq 'EOP') { 'Disable-EOPProtectionPolicyRule' } else { 'Disable-ATPProtectionPolicyRule' }
                    New-ExoRequest -tenantid $TenantFilter -cmdlet $CmdletName -cmdParams @{
                        Identity = $RuleBaseName
                    } -useSystemMailbox $true
                    $Results += "Disabled $RuleBaseName"
                }
                'Rescope' {
                    # Rescoping requires recipient/domain/group lists
                    $SentTo = $Request.Body.sentTo ?? @()
                    $SentToMemberOf = $Request.Body.sentToMemberOf ?? @()
                    $RecipientDomainIs = $Request.Body.recipientDomainIs ?? @()
                    $ExceptIfSentTo = $Request.Body.exceptIfSentTo ?? @()
                    $ExceptIfSentToMemberOf = $Request.Body.exceptIfSentToMemberOf ?? @()
                    $ExceptIfRecipientDomainIs = $Request.Body.exceptIfRecipientDomainIs ?? @()

                    $SetParams = @{
                        Identity = $RuleBaseName
                    }
                    if ($SentTo -and $SentTo.Count -gt 0) { $SetParams.SentTo = $SentTo }
                    if ($SentToMemberOf -and $SentToMemberOf.Count -gt 0) { $SetParams.SentToMemberOf = $SentToMemberOf }
                    if ($RecipientDomainIs -and $RecipientDomainIs.Count -gt 0) { $SetParams.RecipientDomainIs = $RecipientDomainIs }
                    if ($ExceptIfSentTo -and $ExceptIfSentTo.Count -gt 0) { $SetParams.ExceptIfSentTo = $ExceptIfSentTo }
                    if ($ExceptIfSentToMemberOf -and $ExceptIfSentToMemberOf.Count -gt 0) { $SetParams.ExceptIfSentToMemberOf = $ExceptIfSentToMemberOf }
                    if ($ExceptIfRecipientDomainIs -and $ExceptIfRecipientDomainIs.Count -gt 0) { $SetParams.ExceptIfRecipientDomainIs = $ExceptIfRecipientDomainIs }

                    $CmdletName = if ($Rule.Type -eq 'EOP') { 'Set-EOPProtectionPolicyRule' } else { 'Set-ATPProtectionPolicyRule' }
                    New-ExoRequest -tenantid $TenantFilter -cmdlet $CmdletName -cmdParams $SetParams -useSystemMailbox $true
                    $Results += "Rescoped $RuleBaseName"
                }
            }
        }

        $Result = $Results -join '; '
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to $Action $PolicyType $RuleType preset policy for $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
