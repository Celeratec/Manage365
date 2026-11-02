function Invoke-ExecDefenderPresetPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SecurityPolicy.ReadWrite
    .DESCRIPTION
        Enable, disable, or rescope Defender preset security policies (Standard or Strict).
        Manages EOP and ATP Protection Policy Rules. Enable action uses Exchange.SpamFilter.ReadWrite.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    
    # Normalize tenantFilter: reject arrays, take single value
    $TenantFilter = if ($Request.Body.tenantFilter -is [array]) {
        if ($Request.Body.tenantFilter.Count -ne 1) {
            throw 'tenantFilter must be a single tenant, not an array'
        }
        $Request.Body.tenantFilter[0]
    } else {
        $Request.Body.tenantFilter
    }
    
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

        # Note: Enable action uses Exchange.SpamFilter.ReadWrite (less privileged)
        # Disable and Rescope require Exchange.SecurityPolicy.ReadWrite (this function's role)

        $Results = @()
        $AuditLog = @()

        # The actual rule names are "Standard Preset Security Policy" or "Strict Preset Security Policy"
        # for both EOP and ATP rules
        $RuleName = "$PolicyType Preset Security Policy"

        # Determine which rules to manage
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
            
            switch ($Action) {
                'Enable' {
                    # Read current state for audit
                    $GetCmdlet = if ($RuleTypeLabel -eq 'EOP') { 'Get-EOPProtectionPolicyRule' } else { 'Get-ATPProtectionPolicyRule' }
                    try {
                        $CurrentRule = New-ExoRequest -tenantid $TenantFilter -cmdlet $GetCmdlet -cmdParams @{ Identity = $RuleIdentity } -useSystemMailbox $true | Select-Object -First 1
                        $BeforeState = if ($CurrentRule) { $CurrentRule.State } else { 'NotFound' }
                    } catch {
                        $BeforeState = 'Error'
                    }

                    $CmdletName = if ($RuleTypeLabel -eq 'EOP') { 'Enable-EOPProtectionPolicyRule' } else { 'Enable-ATPProtectionPolicyRule' }
                    New-ExoRequest -tenantid $TenantFilter -cmdlet $CmdletName -cmdParams @{
                        Identity = $RuleIdentity
                    } -useSystemMailbox $true
                    
                    $AuditLog += "$RuleTypeLabel rule '$RuleIdentity': State changed from $BeforeState to Enabled"
                    $Results += "Enabled $RuleTypeLabel preset policy: $RuleIdentity"
                }
                'Disable' {
                    # Read current state for audit
                    $GetCmdlet = if ($RuleTypeLabel -eq 'EOP') { 'Get-EOPProtectionPolicyRule' } else { 'Get-ATPProtectionPolicyRule' }
                    try {
                        $CurrentRule = New-ExoRequest -tenantid $TenantFilter -cmdlet $GetCmdlet -cmdParams @{ Identity = $RuleIdentity } -useSystemMailbox $true | Select-Object -First 1
                        $BeforeState = if ($CurrentRule) { $CurrentRule.State } else { 'NotFound' }
                    } catch {
                        $BeforeState = 'Error'
                    }

                    $CmdletName = if ($RuleTypeLabel -eq 'EOP') { 'Disable-EOPProtectionPolicyRule' } else { 'Disable-ATPProtectionPolicyRule' }
                    New-ExoRequest -tenantid $TenantFilter -cmdlet $CmdletName -cmdParams @{
                        Identity = $RuleIdentity
                    } -useSystemMailbox $true
                    
                    $AuditLog += "$RuleTypeLabel rule '$RuleIdentity': State changed from $BeforeState to Disabled"
                    $Results += "Disabled $RuleTypeLabel preset policy: $RuleIdentity"
                }
                'Rescope' {
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
                    if ($RecipientDomainIs -and $RecipientDomainIs.Count -gt 0) {
                        $Validation = Test-CippExchangeInputValidation -Domains $RecipientDomainIs
                        if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    }
                    if ($ExceptIfSentTo -and $ExceptIfSentTo.Count -gt 0) {
                        $Validation = Test-CippExchangeInputValidation -EmailAddresses $ExceptIfSentTo
                        if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    }
                    if ($ExceptIfRecipientDomainIs -and $ExceptIfRecipientDomainIs.Count -gt 0) {
                        $Validation = Test-CippExchangeInputValidation -Domains $ExceptIfRecipientDomainIs
                        if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
                    }

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
            }
        }

        $Result = $Results -join '; '
        $AuditMessage = if ($AuditLog.Count -gt 0) { $AuditLog -join '; ' } else { $Result }
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Info'
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
