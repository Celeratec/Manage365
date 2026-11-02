function Invoke-ExecRescopeDefenderPresetPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SecurityPolicy.ReadWrite
    .DESCRIPTION
        Rescope Defender preset security policies (Standard or Strict).
        Modifies the recipient/domain/group scope which can weaken protection and requires SecurityPolicy.ReadWrite.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $PolicyType = $Request.Body.policyType  # Standard or Strict
    $RuleType = $Request.Body.ruleType  # EOP or ATP or Both

    try {
        $TenantFilter = Get-CippNormalizedTenantFilter -TenantFilter $Request.Body.tenantFilter
        
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($PolicyType)) { throw 'policyType is required.' }
        if ($PolicyType -notin @('Standard', 'Strict')) { throw 'policyType must be Standard or Strict.' }
        if ([string]::IsNullOrWhiteSpace($RuleType)) { throw 'ruleType is required.' }
        if ($RuleType -notin @('EOP', 'ATP', 'Both')) { throw 'ruleType must be EOP, ATP, or Both.' }

        $Results = @()
        $AuditLog = @()
        $RuleName = "$PolicyType Preset Security Policy"

        # Rescoping requires recipient/domain/group lists
        $SentTo = $Request.Body.sentTo ?? @()
        $SentToMemberOf = $Request.Body.sentToMemberOf ?? @()
        $RecipientDomainIs = $Request.Body.recipientDomainIs ?? @()
        $ExceptIfSentTo = $Request.Body.exceptIfSentTo ?? @()
        $ExceptIfSentToMemberOf = $Request.Body.exceptIfSentToMemberOf ?? @()
        $ExceptIfRecipientDomainIs = $Request.Body.exceptIfRecipientDomainIs ?? @()

        # Validate scoping inputs
        if ($SentTo -and $SentTo.Count -gt 0) {
            $Validation = Test-CippExchangeInputValidation -EmailAddresses $SentTo
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        }
        if ($SentToMemberOf -and $SentToMemberOf.Count -gt 0) {
            $Validation = Test-CippExchangeInputValidation -SentToMemberOf $SentToMemberOf
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        }
        if ($RecipientDomainIs -and $RecipientDomainIs.Count -gt 0) {
            $Validation = Test-CippExchangeInputValidation -Domains $RecipientDomainIs
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        }
        if ($ExceptIfSentTo -and $ExceptIfSentTo.Count -gt 0) {
            $Validation = Test-CippExchangeInputValidation -EmailAddresses $ExceptIfSentTo
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        }
        if ($ExceptIfSentToMemberOf -and $ExceptIfSentToMemberOf.Count -gt 0) {
            $Validation = Test-CippExchangeInputValidation -SentToMemberOf $ExceptIfSentToMemberOf
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        }
        if ($ExceptIfRecipientDomainIs -and $ExceptIfRecipientDomainIs.Count -gt 0) {
            $Validation = Test-CippExchangeInputValidation -Domains $ExceptIfRecipientDomainIs
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        }

        $RulesToManage = @()
        if ($RuleType -in @('EOP', 'Both')) {
            $RulesToManage += @{ Type = 'EOP'; Name = $RuleName }
        }
        if ($RuleType -in @('ATP', 'Both')) {
            $RulesToManage += @{ Type = 'ATP'; Name = $RuleName }
        }

        foreach ($Rule in $RulesToManage) {
            $RuleIdentity = $Rule.Name
            $RuleTypeLabel = $Rule.Type
            
            # Read current rule for audit
            $GetCmdlet = if ($RuleTypeLabel -eq 'EOP') { 'Get-EOPProtectionPolicyRule' } else { 'Get-ATPProtectionPolicyRule' }
            $CurrentRule = New-ExoRequest -tenantid $TenantFilter -cmdlet $GetCmdlet -cmdParams @{ Identity = $RuleIdentity } -useSystemMailbox $true | Select-Object -First 1
            
            $BeforeScope = @{
                SentTo                     = $CurrentRule.SentTo ?? @()
                SentToMemberOf             = $CurrentRule.SentToMemberOf ?? @()
                RecipientDomainIs          = $CurrentRule.RecipientDomainIs ?? @()
                ExceptIfSentTo             = $CurrentRule.ExceptIfSentTo ?? @()
                ExceptIfSentToMemberOf     = $CurrentRule.ExceptIfSentToMemberOf ?? @()
                ExceptIfRecipientDomainIs  = $CurrentRule.ExceptIfRecipientDomainIs ?? @()
            }

            # Check if anything actually changed
            $Changed = $false
            if (($SentTo -join ',') -ne (($BeforeScope.SentTo ?? @()) -join ',')) { $Changed = $true }
            if (($SentToMemberOf -join ',') -ne (($BeforeScope.SentToMemberOf ?? @()) -join ',')) { $Changed = $true }
            if (($RecipientDomainIs -join ',') -ne (($BeforeScope.RecipientDomainIs ?? @()) -join ',')) { $Changed = $true }
            if (($ExceptIfSentTo -join ',') -ne (($BeforeScope.ExceptIfSentTo ?? @()) -join ',')) { $Changed = $true }
            if (($ExceptIfSentToMemberOf -join ',') -ne (($BeforeScope.ExceptIfSentToMemberOf ?? @()) -join ',')) { $Changed = $true }
            if (($ExceptIfRecipientDomainIs -join ',') -ne (($BeforeScope.ExceptIfRecipientDomainIs ?? @()) -join ',')) { $Changed = $true }

            if (-not $Changed) {
                $Results += "No changes to $RuleTypeLabel preset policy scope: $RuleIdentity (already matches requested scope)"
                continue
            }

            $SetParams = @{
                Identity = $RuleIdentity
            }
            
            # Explicitly set each parameter (supports clearing by passing empty arrays)
            $SetParams.SentTo = $SentTo
            $SetParams.SentToMemberOf = $SentToMemberOf
            $SetParams.RecipientDomainIs = $RecipientDomainIs
            $SetParams.ExceptIfSentTo = $ExceptIfSentTo
            $SetParams.ExceptIfSentToMemberOf = $ExceptIfSentToMemberOf
            $SetParams.ExceptIfRecipientDomainIs = $ExceptIfRecipientDomainIs

            $CmdletName = if ($RuleTypeLabel -eq 'EOP') { 'Set-EOPProtectionPolicyRule' } else { 'Set-ATPProtectionPolicyRule' }
            New-ExoRequest -tenantid $TenantFilter -cmdlet $CmdletName -cmdParams $SetParams -useSystemMailbox $true
            
            $AfterScope = @{
                SentTo                     = $SentTo
                SentToMemberOf             = $SentToMemberOf
                RecipientDomainIs          = $RecipientDomainIs
                ExceptIfSentTo             = $ExceptIfSentTo
                ExceptIfSentToMemberOf     = $ExceptIfSentToMemberOf
                ExceptIfRecipientDomainIs  = $ExceptIfRecipientDomainIs
            }
            
            $AuditLog += "$RuleTypeLabel rule '$RuleIdentity' rescoped: Before=$($BeforeScope | ConvertTo-Json -Compress), After=$($AfterScope | ConvertTo-Json -Compress)"
            $Results += "Rescoped $RuleTypeLabel preset policy: $RuleIdentity"
        }

        $Result = $Results -join '; '
        $AuditMessage = if ($AuditLog.Count -gt 0) { $AuditLog -join '; ' } else { $Result }
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ 
            Results   = $Result
            AuditLog  = $AuditLog
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to rescope $PolicyType $RuleType preset policy for $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
