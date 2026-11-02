function Invoke-ExecEnhancedFiltering {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SecurityPolicy.ReadWrite
    .DESCRIPTION
        Configure Enhanced Filtering for Connectors on an inbound connector.
        Manages EFSkipIPs, EFSkipLastIP, and EFUsers settings with strict validation.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $ConnectorIdentity = Get-CippQuarantineInputValue $Request.Body.connectorIdentity
    $Action = $Request.Body.action ?? 'Set'

    try {
        # Normalize tenantFilter inside try block
        $TenantFilter = Get-CippNormalizedTenantFilter -TenantFilter $Request.Body.tenantFilter
        
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($ConnectorIdentity)) { throw 'connectorIdentity is required.' }
        if ($Action -notin @('Get', 'Set')) { throw 'action must be Get or Set.' }

        # Read current connector
        $CurrentConnector = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-InboundConnector' -cmdParams @{ Identity = $ConnectorIdentity } -useSystemMailbox $true | Select-Object -First 1
        if (-not $CurrentConnector) {
            throw "Inbound connector '$ConnectorIdentity' not found"
        }

        # If action is Get, return current settings
        if ($Action -eq 'Get') {
            $CurrentSettings = @{
                ConnectorIdentity = $ConnectorIdentity
                EFSkipIPs        = $CurrentConnector.EFSkipIPs ?? @()
                EFSkipLastIP     = $CurrentConnector.EFSkipLastIP
                EFUsers          = $CurrentConnector.EFUsers ?? @()
            }
            $Result = "Retrieved Enhanced Filtering settings for connector '$ConnectorIdentity'"
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = @{ 
                Results = $Result
                Settings = $CurrentSettings
            }
            return ([HttpResponseContext]@{
                StatusCode = $StatusCode
                Body       = $Body
            })
        }

        # For Set action, continue with existing logic
        $BeforeSettings = @{
            EFSkipIPs     = $CurrentConnector.EFSkipIPs ?? @()
            EFSkipLastIP  = $CurrentConnector.EFSkipLastIP
            EFUsers       = $CurrentConnector.EFUsers ?? @()
        }

        # Build connector parameters
        $ConnectorParams = @{
            Identity = $ConnectorIdentity
        }

        # EFSkipIPs - IP addresses to skip (validate as IPs/CIDRs/ranges)
        if ($null -ne $Request.Body.efSkipIPs) {
            $EFSkipIPs = $Request.Body.efSkipIPs
            
            # Reject if it's a single string (not an array)
            if ($EFSkipIPs -is [string]) {
                throw 'efSkipIPs must be an array, not a single string'
            }
            
            # Ensure it's an array
            if ($EFSkipIPs -isnot [array]) {
                throw 'efSkipIPs must be an array'
            }

            if ($EFSkipIPs.Count -gt 0) {
                # Validate count cap (50 entries)
                if ($EFSkipIPs.Count -gt 50) {
                    throw "efSkipIPs exceeds maximum of 50 entries (received $($EFSkipIPs.Count))"
                }

                # Validate each IP/CIDR/range with strict mode
                $Validation = Test-CippExchangeInputValidation -IPAddresses $EFSkipIPs -StrictIPValidation -MaxIPCount 50
                if (-not $Validation.IsValid) {
                    throw ($Validation.Errors -join '; ')
                }
                
                # Send validated, normalized (trimmed) values to Exchange
                $NormalizedIPs = $EFSkipIPs | ForEach-Object { $_.Trim() }
                $ConnectorParams.EFSkipIPs = $NormalizedIPs
            } else {
                # Clear the setting
                $ConnectorParams.EFSkipIPs = @()
            }
        }

        # EFSkipLastIP - Skip the last IP (boolean)
        if ($null -ne $Request.Body.efSkipLastIP) {
            $EFSkipLastIP = [bool]$Request.Body.efSkipLastIP
            $ConnectorParams.EFSkipLastIP = $EFSkipLastIP
            
            # Warn if EFSkipIPs is being set along with EFSkipLastIP=$true
            if ($EFSkipLastIP -eq $true -and $ConnectorParams.ContainsKey('EFSkipIPs') -and $ConnectorParams.EFSkipIPs.Count -gt 0) {
                Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Warning: EFSkipIPs is being set along with EFSkipLastIP=`$true. This combination may cause unexpected behavior - typically use one or the other." -Sev 'Warning'
            }
        }

        # EFUsers - Email addresses to enable Enhanced Filtering for
        if ($null -ne $Request.Body.efUsers) {
            $EFUsers = $Request.Body.efUsers
            if ($EFUsers -is [array] -and $EFUsers.Count -gt 0) {
                # Validate email addresses
                $Validation = Test-CippExchangeInputValidation -EmailAddresses $EFUsers
                if (-not $Validation.IsValid) {
                    throw ($Validation.Errors -join '; ')
                }
                $ConnectorParams.EFUsers = $EFUsers
            } elseif ($EFUsers -eq $null -or ($EFUsers -is [array] -and $EFUsers.Count -eq 0)) {
                # Clear the setting
                $ConnectorParams.EFUsers = @()
            }
        }

        # Check if anything changed
        $Changed = $false
        if ($ConnectorParams.ContainsKey('EFSkipIPs')) {
            if (($ConnectorParams.EFSkipIPs -join ',') -ne (($BeforeSettings.EFSkipIPs ?? @()) -join ',')) {
                $Changed = $true
            }
        }
        if ($ConnectorParams.ContainsKey('EFSkipLastIP')) {
            if ($ConnectorParams.EFSkipLastIP -ne $BeforeSettings.EFSkipLastIP) {
                $Changed = $true
            }
        }
        if ($ConnectorParams.ContainsKey('EFUsers')) {
            if (($ConnectorParams.EFUsers -join ',') -ne (($BeforeSettings.EFUsers ?? @()) -join ',')) {
                $Changed = $true
            }
        }

        if (-not $Changed) {
            $Result = "No changes to Enhanced Filtering for connector '$ConnectorIdentity' (already matches requested settings)"
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = @{ Results = $Result }
        } else {
            # Update the connector
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-InboundConnector' -cmdParams $ConnectorParams -useSystemMailbox $true

            $SettingsApplied = @()
            if ($ConnectorParams.ContainsKey('EFSkipIPs')) {
                if ($ConnectorParams.EFSkipIPs.Count -eq 0) {
                    $SettingsApplied += 'EFSkipIPs cleared'
                } else {
                    $SettingsApplied += "EFSkipIPs set to: $($ConnectorParams.EFSkipIPs -join ', ')"
                }
            }
            if ($ConnectorParams.ContainsKey('EFSkipLastIP')) {
                $SettingsApplied += "EFSkipLastIP set to $($ConnectorParams.EFSkipLastIP)"
            }
            if ($ConnectorParams.ContainsKey('EFUsers')) {
                if ($ConnectorParams.EFUsers.Count -eq 0) {
                    $SettingsApplied += 'EFUsers cleared'
                } else {
                    $SettingsApplied += "EFUsers set to: $($ConnectorParams.EFUsers -join ', ')"
                }
            }

            $AfterSettings = @{
                EFSkipIPs    = $ConnectorParams.EFSkipIPs ?? $BeforeSettings.EFSkipIPs
                EFSkipLastIP = $ConnectorParams.EFSkipLastIP ?? $BeforeSettings.EFSkipLastIP
                EFUsers      = $ConnectorParams.EFUsers ?? $BeforeSettings.EFUsers
            }

            $AuditMessage = "Enhanced Filtering configured for connector '$ConnectorIdentity': $($SettingsApplied -join ', '). Before: $($BeforeSettings | ConvertTo-Json -Compress), After: $($AfterSettings | ConvertTo-Json -Compress)"
            $Result = "Enhanced Filtering configured for connector '$ConnectorIdentity': $($SettingsApplied -join ', ')"
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $AuditMessage -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = @{ Results = $Result }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to configure Enhanced Filtering for connector '$ConnectorIdentity' in $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
