function Invoke-AddTenantAllowBlockListTemplate {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Exchange.SpamFilter.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    try {
        if ($Request.body.listMethod -eq 'Block' -and $Request.body.listType -eq 'IP') {
            $Entries = @($Request.body.entries -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
            
            # Call guard to refuse Block+IP templates containing relay IPs
            $SafetyCheck = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck $Entries -SkipConnectorCheck
            if (-not $SafetyCheck.IsValid) {
                $SanitizedEntries = @($Entries | ForEach-Object {
                        $c = $_ -replace '[\x00-\x1F\x7F]', ''
                        $c.Substring(0, [Math]::Min($c.Length, 50))
                    })
                Write-LogMessage -Headers $Headers -API $APIName -Message "Refused Block+IP template save: $($SafetyCheck.Reason). Entries: $($SanitizedEntries -join ', ')" -Sev 'Warning'
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::BadRequest
                        Body       = @{ Results = "Cannot create template: $($SafetyCheck.Reason)" }
                    })
            }
        }
        
        $GUID = (New-Guid).GUID
        $JSON = @{
            entries      = $Request.body.entries
            listType     = $Request.body.listType
            listMethod   = $Request.body.listMethod
            notes        = $Request.body.notes
            NoExpiration = [bool]$Request.body.NoExpiration
            RemoveAfter  = [bool]$Request.body.RemoveAfter
            templateName = $Request.body.templateName
        } | ConvertTo-Json -Depth 10

        $Table = Get-CippTable -tablename 'templates'
        $Table.Force = $true
        Add-CIPPAzDataTableEntity @Table -Entity @{
            JSON         = "$JSON"
            RowKey       = "$GUID"
            PartitionKey = 'TenantAllowBlockListTemplate'
        }
        Write-LogMessage -Headers $Headers -API $APIName -message "Created Tenant Allow/Block List Template $($Request.body.templateName) with GUID $GUID" -Sev Info
        $body = [pscustomobject]@{ 'Results' = "Created Tenant Allow/Block List Template $($Request.body.templateName) with GUID $GUID" }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorDetail = "$($ErrorMessage.NormalizedError)"
        Write-LogMessage -Headers $Headers -API $APIName -message "Failed to create Tenant Allow/Block List Template: $ErrorDetail" -Sev Error -LogData $ErrorMessage
        $body = [pscustomobject]@{ 'Results' = "Failed to create Tenant Allow/Block List Template." }
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $body
        })
}
