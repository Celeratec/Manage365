Function Invoke-AddConnectionFilter {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.ConnectionFilter.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)


    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers


    $RequestParams = $Request.Body.PowerShellCommand |
        ConvertFrom-Json |
        Select-Object -Property *, @{Name = 'identity'; Expression = { $_.name } } -ExcludeProperty GUID, comments, name

    $Tenants = ($Request.Body.selectedTenants).value
    $Failed = 0

    # Guard against blocking mail relay IPs (only if IPBlockList is being set)
    if ($null -ne $RequestParams.IPBlockList -and $RequestParams.IPBlockList.Count -gt 0) {
        foreach ($TenantFilter in $Tenants) {
            $SafetyCheck = Test-CIPPIPBlockListSafety -TenantFilter $TenantFilter -IPsToCheck $RequestParams.IPBlockList
            if (-not $SafetyCheck.IsValid) {
                $AuditMessage = "BLOCKED connection filter IPBlockList add for tenant $TenantFilter - Reason: $($SafetyCheck.Reason) - Requested by: $($Headers.'x-ms-client-principal-name' ?? 'Unknown') - IPs: $($RequestParams.IPBlockList -join ', ')"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Warning'
                $Failed++
                "Operation blocked for tenant $TenantFilter : $($SafetyCheck.Reason)"
                continue
            }
        }
    }

    $Result = foreach ($TenantFilter in $Tenants) {
        # Skip if already failed in safety check
        if ($null -ne $RequestParams.IPBlockList -and $RequestParams.IPBlockList.Count -gt 0) {
            $SafetyCheck = Test-CIPPIPBlockListSafety -TenantFilter $TenantFilter -IPsToCheck $RequestParams.IPBlockList
            if (-not $SafetyCheck.IsValid) {
                continue
            }
        }

        try {
            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-HostedConnectionFilterPolicy' -cmdParams $RequestParams
            "Successfully created Connection filter for $TenantFilter."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Successfully created Connection filter for $TenantFilter." -sev Info
        } catch {
            $Failed++
            $ErrorMessage = Get-CippException -Exception $_
            "Failed to create Connection Filter rule for $($TenantFilter): $($ErrorMessage.NormalizedError)"
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to create connection filter rule for $($TenantFilter): $($ErrorMessage.NormalizedError)" -sev Error -LogData $ErrorMessage
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = Get-CippBulkStatusCode -Total @($Tenants).Count -Failed $Failed
            Body       = @{Results = @($Result) }
        })

}
