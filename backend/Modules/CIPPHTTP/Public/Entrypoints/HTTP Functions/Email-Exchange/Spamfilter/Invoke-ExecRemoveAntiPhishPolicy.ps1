function Invoke-ExecRemoveAntiPhishPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SecurityPolicy.ReadWrite
    .DESCRIPTION
        Remove custom anti-phishing policies (AntiPhishPolicy and Rule).
        Refuses to remove default, built-in, or preset (Standard/Strict) policies.
        This is a high-risk operation requiring explicit SecurityPolicy.ReadWrite permission.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    
    try {
        $TenantFilter = Get-CippNormalizedTenantFilter -TenantFilter $Request.Body.tenantFilter
        $PolicyName = Get-CippQuarantineInputValue $Request.Body.policyName
        
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($PolicyName)) { throw 'policyName is required.' }

        $Results = @()
        $AuditLog = @()

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

        $FinalResult = ($Results -join '; ')
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message ($AuditLog -join "`n") -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $FinalResult }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to remove anti-phishing policy '$PolicyName' in $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
