function Invoke-ExecDisableDefenderPresetPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SecurityPolicy.ReadWrite
    .DESCRIPTION
        Disable Defender preset security policies (Standard or Strict).
        This is a high-risk operation that weakens protection and requires SecurityPolicy.ReadWrite.
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

            # Use Disable-*ProtectionPolicyRule
            $DisableCmdlet = if ($RuleTypeLabel -eq 'EOP') { 'Disable-EOPProtectionPolicyRule' } else { 'Disable-ATPProtectionPolicyRule' }
            New-ExoRequest -tenantid $TenantFilter -cmdlet $DisableCmdlet -cmdParams @{
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
            $Results += "Disabled $RuleTypeLabel preset policy: $RuleIdentity (was: $BeforeState, now: $AfterState)"
        }

        $Result = $Results -join '; '
        $AuditMessage = ($AuditLog | ForEach-Object { "$($_.RuleType) rule '$($_.RuleIdentity)': State changed from $($_.BeforeState) to $($_.AfterState)" }) -join '; '
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ 
            Results   = $Result
            AuditLog  = $AuditLog
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to disable $PolicyType $RuleType preset policy for $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
