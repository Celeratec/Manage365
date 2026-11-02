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
    $Refusals = [System.Collections.Generic.List[string]]::new()

    # Run guard once per tenant for IPBlockList and IPAllowList, cache results
    $SafetyChecksBlock = @{}
    $SafetyChecksAllow = @{}
    $SanitizedIPBlockList = @()
    $SanitizedIPAllowList = @()
    
    # Check IPBlockList
    if ($null -ne $RequestParams.IPBlockList -and $RequestParams.IPBlockList.Count -gt 0) {
        # Sanitize IP list for logging (cap at 50 chars)
        $SanitizedIPBlockList = @($RequestParams.IPBlockList | ForEach-Object {
                $c = $_ -replace '[\x00-\x1F\x7F]', ''
                $c.Substring(0, [Math]::Min($c.Length, 50))
            })
        
        foreach ($TenantFilter in $Tenants) {
            $SafetyChecksBlock[$TenantFilter] = Test-CIPPIPBlockListSafety -TenantFilter $TenantFilter -IPsToCheck $RequestParams.IPBlockList
            if (-not $SafetyChecksBlock[$TenantFilter].IsValid) {
                $AuditMessage = "BLOCKED connection filter IPBlockList add for tenant $TenantFilter - Reason: $($SafetyChecksBlock[$TenantFilter].Reason) - Requested by: $($Headers.'x-ms-client-principal-name' ?? 'Unknown') - IPs: $($SanitizedIPBlockList -join ', ')"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Warning'
                $Failed++
                $Refusals.Add("IPBlockList operation blocked for tenant $TenantFilter : $($SafetyChecksBlock[$TenantFilter].Reason)")
            }
        }
    }
    
    # Check IPAllowList (Enhanced Filtering IPs must not be in allow list either)
    if ($null -ne $RequestParams.IPAllowList -and $RequestParams.IPAllowList.Count -gt 0) {
        # Sanitize IP list for logging (cap at 50 chars)
        $SanitizedIPAllowList = @($RequestParams.IPAllowList | ForEach-Object {
                $c = $_ -replace '[\x00-\x1F\x7F]', ''
                $c.Substring(0, [Math]::Min($c.Length, 50))
            })
        
        foreach ($TenantFilter in $Tenants) {
            $SafetyChecksAllow[$TenantFilter] = Test-CIPPIPBlockListSafety -TenantFilter $TenantFilter -IPsToCheck $RequestParams.IPAllowList
            if (-not $SafetyChecksAllow[$TenantFilter].IsValid) {
                $AuditMessage = "BLOCKED connection filter IPAllowList add for tenant $TenantFilter - Reason: $($SafetyChecksAllow[$TenantFilter].Reason) - Requested by: $($Headers.'x-ms-client-principal-name' ?? 'Unknown') - IPs: $($SanitizedIPAllowList -join ', ')"
                Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Warning'
                $Failed++
                $Refusals.Add("IPAllowList operation blocked for tenant $TenantFilter : $($SafetyChecksAllow[$TenantFilter].Reason)")
            }
        }
    }

    $Result = foreach ($TenantFilter in $Tenants) {
        # Skip if either guard check failed
        if (($SafetyChecksBlock.ContainsKey($TenantFilter) -and -not $SafetyChecksBlock[$TenantFilter].IsValid) -or
            ($SafetyChecksAllow.ContainsKey($TenantFilter) -and -not $SafetyChecksAllow[$TenantFilter].IsValid)) {
            continue
        }

        try {
            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-HostedConnectionFilterPolicy' -cmdParams $RequestParams
            "Successfully created Connection filter for $TenantFilter."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Successfully created Connection filter for $TenantFilter." -sev Info
        } catch {
            $Failed++
            $ErrorMessage = Get-CippException -Exception $_
            "Failed to create Connection Filter rule for $($TenantFilter). Please try again."
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to create connection filter rule for $($TenantFilter): $($ErrorMessage.NormalizedError)" -sev Error -LogData $ErrorMessage
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = if ($Failed -eq @($Tenants).Count) { [HttpStatusCode]::BadRequest } else { Get-CippBulkStatusCode -Total @($Tenants).Count -Failed $Failed }
            Body       = @{Results = @($Refusals) + @($Result) }
        })

}
