function Invoke-EditTenantAllowBlockListTemplate {
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

    $ID = $Request.body.GUID
    if (-not $ID) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'GUID is required to edit a template.' }
            })
    }

    try {
        $Table = Get-CippTable -tablename 'templates'
        $SafeID = ConvertTo-CIPPODataFilterValue -Value $ID -Type Guid
        $Filter = "PartitionKey eq 'TenantAllowBlockListTemplate' and RowKey eq '$SafeID'"
        $ExistingEntity = Get-CIPPAzDataTableEntity @Table -Filter $Filter

        if (-not $ExistingEntity) {
            return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::NotFound
                    Body       = @{ Results = "Template with ID $ID not found." }
                })
        }

        # Validate Block+IP template entries at save time
        if ($Request.body.listMethod -eq 'Block' -and $Request.body.listType -eq 'IP') {
            # Load known relay IPs using shared loader (fails closed)
            try {
                $KnownRelayIPs = Get-CIPPKnownMailRelayIPs
            } catch {
                Write-LogMessage -Headers $Headers -API $APIName -message "Failed to load relay IP config: $_" -Sev Error
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::BadRequest
                        Body       = @{ Results = "Failed to load known relay IP configuration. Please contact support." }
                    })
            }
            
            $Entries = @($Request.body.entries -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
            
            # Sanitize entries for logging (remove control chars, cap length)
            $SanitizedEntries = @($Entries | ForEach-Object {
                    $c = $_ -replace '[\x00-\x1F\x7F]', ''
                    $c.Substring(0, [Math]::Min($c.Length, 50))
                })
            
            # Check each entry against known relays using Test-CIPPIPOverlap
            $Refusals = @()
            foreach ($Entry in $Entries) {
                $CleanedEntry = $Entry -replace '[\x00-\x1F\x7F]', ''
                $SanitizedEntry = $CleanedEntry.Substring(0, [Math]::Min($CleanedEntry.Length, 50))
                foreach ($KnownIP in $KnownRelayIPs) {
                    $OverlapResult = Test-CIPPIPOverlap -IP1 $Entry -IP2 $KnownIP
                    if ($OverlapResult.Overlaps) {
                        $Refusals += "Entry '$SanitizedEntry' overlaps with known mail relay IP '$KnownIP'"
                    }
                }
            }
            
            if ($Refusals.Count -gt 0) {
                Write-LogMessage -Headers $Headers -API $APIName -Message "Refused Block+IP template edit: $($Refusals -join '; '). Entries: $($SanitizedEntries -join ', ')" -Sev 'Warning'
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::BadRequest
                        Body       = @{ Results = "Cannot update template: $($Refusals -join ' '). Blocking these IPs would disrupt mail relay services." }
                    })
            }
        }

        $JSON = @{
            entries      = $Request.body.entries
            listType     = $Request.body.listType
            listMethod   = $Request.body.listMethod
            notes        = $Request.body.notes
            NoExpiration = [bool]$Request.body.NoExpiration
            RemoveAfter  = [bool]$Request.body.RemoveAfter
            templateName = $Request.body.templateName
        } | ConvertTo-Json -Depth 10

        $Table.Force = $true
        Add-CIPPAzDataTableEntity @Table -Entity @{
            JSON         = "$JSON"
            RowKey       = "$ID"
            PartitionKey = 'TenantAllowBlockListTemplate'
        }

        Write-LogMessage -Headers $Headers -API $APIName -message "Edited Tenant Allow/Block List Template $($Request.body.templateName) with GUID $ID" -Sev Info
        $body = [pscustomobject]@{ 'Results' = "Successfully edited Tenant Allow/Block List Template $($Request.body.templateName)" }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $ErrorDetail = "$($ErrorMessage.NormalizedError)"
        Write-LogMessage -Headers $Headers -API $APIName -message "Failed to edit Tenant Allow/Block List Template: $ErrorDetail" -Sev Error -LogData $ErrorMessage
        $body = [pscustomobject]@{ 'Results' = "Failed to edit Tenant Allow/Block List Template." }
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $body
        })
}
