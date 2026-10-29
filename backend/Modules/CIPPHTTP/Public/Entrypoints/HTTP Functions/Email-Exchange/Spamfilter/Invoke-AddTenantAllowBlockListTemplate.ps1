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
        # Validate Block+IP template entries against known relay list at save time
        if ($Request.body.listMethod -eq 'Block' -and $Request.body.listType -eq 'IP') {
            # Load known relay IPs using shared loader (fails closed)
            try {
                $KnownRelayIPs = Get-CIPPKnownMailRelayIPs
            } catch {
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::BadRequest
                        Body       = @{ Results = "Failed to load known relay IP configuration: $($_.Exception.Message)" }
                    })
            }
            
            $Entries = @($Request.body.entries -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
            
            # Sanitize entries for logging (remove control chars, cap length)
            $SanitizedEntries = @($Entries | ForEach-Object {
                    $c = $_ -replace '[\x00-\x1F\x7F]', ''
                    $c.Substring(0, [Math]::Min($c.Length, 200))
                })
            
            # Check each entry against known relays using Test-CIPPIPOverlap
            $Refusals = @()
            foreach ($Entry in $Entries) {
                foreach ($KnownIP in $KnownRelayIPs) {
                    $OverlapResult = Test-CIPPIPOverlap -IP1 $Entry -IP2 $KnownIP
                    if ($OverlapResult.Overlaps) {
                        $Refusals += "Entry '$Entry' overlaps with known mail relay IP '$KnownIP'"
                    }
                }
            }
            
            if ($Refusals.Count -gt 0) {
                Write-LogMessage -Headers $Headers -API $APIName -Message "Refused Block+IP template save: $($Refusals -join '; '). Entries: $($SanitizedEntries -join ', ')" -Sev 'Warning'
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::BadRequest
                        Body       = @{ Results = "Cannot create template: $($Refusals -join ' '). Blocking these IPs would disrupt mail relay services." }
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
