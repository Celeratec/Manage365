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
        # Validate Block + IP entries against known relay IPs at save time
        if ($Request.body.listMethod -eq 'Block' -and $Request.body.listType -eq 'IP') {
            $Entries = @($Request.body.entries -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
            
            # Load known relay IPs (same logic as the guard function, using defaults as fallback)
            $KnownRelayIPs = @('3.19.206.53', '3.142.175.190')
            try {
                # Try to load from config, but don't fail if it doesn't exist
                $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))))
                $ConfigPath = Join-Path $RepoRoot 'backend/Config/KnownMailRelayIPs.json'
                if (Test-Path $ConfigPath) {
                    $KnownRelayConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
                    if ($null -ne $KnownRelayConfig.KnownMailRelayIPs) {
                        $KnownRelayIPs = @($KnownRelayConfig.KnownMailRelayIPs)
                    }
                }
            } catch {
                # Use defaults
            }
            
            # Check entries against known relays
            foreach ($Entry in $Entries) {
                foreach ($KnownRelay in $KnownRelayIPs) {
                    if ($Entry -eq $KnownRelay) {
                        return ([HttpResponseContext]@{
                                StatusCode = [HttpStatusCode]::BadRequest
                                Body       = @{ Results = "Cannot create template: IP '$Entry' matches known mail relay IP. Blocking this IP would disrupt mail relay services." }
                            })
                    }
                }
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
