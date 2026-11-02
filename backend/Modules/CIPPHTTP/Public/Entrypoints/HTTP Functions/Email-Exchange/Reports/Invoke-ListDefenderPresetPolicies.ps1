function Invoke-ListDefenderPresetPolicies {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.Read
    .DESCRIPTION
        Lists Defender preset security policies (Standard and Strict) for both EOP and ATP.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.TenantFilter

    try {
        $EOPRules = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-EOPProtectionPolicyRule' -useSystemMailbox $true | Select-Object -Property *
        $ATPRules = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-ATPProtectionPolicyRule' -useSystemMailbox $true | Select-Object -Property *

        # Combine both rule types
        $AllRules = @()
        if ($EOPRules) {
            $AllRules += $EOPRules | ForEach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name 'RuleType' -Value 'EOP' -Force
                $_
            }
        }
        if ($ATPRules) {
            $AllRules += $ATPRules | ForEach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name 'RuleType' -Value 'ATP' -Force
                $_
            }
        }

        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $AllRules
            })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Request.Headers -API 'ListDefenderPresetPolicies' -tenant $TenantFilter -message "Failed to list Defender preset policies: $($ErrorMessage.NormalizedError)" -Sev 'Error'
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{ Results = "Failed to retrieve preset policies: $($ErrorMessage.NormalizedError)" }
            })
    }
}
