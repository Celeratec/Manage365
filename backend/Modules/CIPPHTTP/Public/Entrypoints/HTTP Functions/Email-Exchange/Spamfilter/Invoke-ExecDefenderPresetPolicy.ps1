function Invoke-ExecDefenderPresetPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Enable Defender preset security policies (Standard or Strict).
        Manages EOP and ATP Protection Policy Rules. Use ExecDisableDefenderPresetPolicy or
        ExecRescopeDefenderPresetPolicy for disable/rescope operations.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Action = $Request.Body.action  # Enable, Disable, or Rescope
    $PolicyType = $Request.Body.policyType  # Standard or Strict
    $RuleType = $Request.Body.ruleType  # EOP or ATP or Both

    try {
        # Normalize tenantFilter inside try block to return proper 400
        $TenantFilter = Get-CippNormalizedTenantFilter -TenantFilter $Request.Body.tenantFilter
        
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($Action)) { throw 'action is required.' }
        if ($Action -ne 'Enable') { throw 'action must be Enable. Use ExecDisableDefenderPresetPolicy or ExecRescopeDefenderPresetPolicy for other actions.' }
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
            
            # Read current state for audit
            $GetCmdlet = if ($RuleTypeLabel -eq 'EOP') { 'Get-EOPProtectionPolicyRule' } else { 'Get-ATPProtectionPolicyRule' }
            try {
                $CurrentRule = New-ExoRequest -tenantid $TenantFilter -cmdlet $GetCmdlet -cmdParams @{ Identity = $RuleIdentity } -useSystemMailbox $true | Select-Object -First 1
                $BeforeState = if ($CurrentRule) { $CurrentRule.State } else { 'NotFound' }
            } catch {
                $BeforeState = 'Error'
            }

            # Use Enable-*ProtectionPolicyRule
            $EnableCmdlet = if ($RuleTypeLabel -eq 'EOP') { 'Enable-EOPProtectionPolicyRule' } else { 'Enable-ATPProtectionPolicyRule' }
            New-ExoRequest -tenantid $TenantFilter -cmdlet $EnableCmdlet -cmdParams @{
                Identity = $RuleIdentity
            } -useSystemMailbox $true
            
            # Re-Get the rule to report the actual after state
            try {
                $UpdatedRule = New-ExoRequest -tenantid $TenantFilter -cmdlet $GetCmdlet -cmdParams @{ Identity = $RuleIdentity } -useSystemMailbox $true | Select-Object -First 1
                $AfterState = if ($UpdatedRule) { $UpdatedRule.State } else { 'Unknown' }
            } catch {
                $AfterState = 'Error'
            }
            
            $AuditLog += @{
                RuleType     = $RuleTypeLabel
                RuleIdentity = $RuleIdentity
                BeforeState  = $BeforeState
                AfterState   = $AfterState
            }
            $Results += "Enabled $RuleTypeLabel preset policy: $RuleIdentity (was: $BeforeState, now: $AfterState)"
        }

        $Result = $Results -join '; '
        $AuditMessage = if ($AuditLog.Count -gt 0) { 
            if ($AuditLog[0] -is [hashtable]) {
                # Structured audit log (Enable/Disable actions)
                ($AuditLog | ForEach-Object { "$($_.RuleType) rule '$($_.RuleIdentity)': State changed from $($_.BeforeState) to $($_.AfterState)" }) -join '; '
            } else {
                # String audit log (Rescope action)
                $AuditLog -join '; '
            }
        } else { 
            $Result 
        }
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ 
            Results   = $Result
            AuditLog  = $AuditLog
        }
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
