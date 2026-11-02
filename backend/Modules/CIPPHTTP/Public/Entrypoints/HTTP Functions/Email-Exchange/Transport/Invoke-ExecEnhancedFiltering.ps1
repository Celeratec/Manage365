function Invoke-ExecEnhancedFiltering {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Connector.ReadWrite
    .DESCRIPTION
        Configure Enhanced Filtering for Connectors on an inbound connector.
        Manages EFSkipIPs, EFSkipLastIP, and EFUsers settings.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter | Select-Object -First 1
    $ConnectorIdentity = Get-CippQuarantineInputValue $Request.Body.connectorIdentity

    try {
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($ConnectorIdentity)) { throw 'connectorIdentity is required.' }

        # Build connector parameters
        $ConnectorParams = @{
            Identity = $ConnectorIdentity
        }

        # EFSkipIPs - IP addresses to skip (validate as IPs/CIDRs)
        if ($null -ne $Request.Body.efSkipIPs) {
            $EFSkipIPs = $Request.Body.efSkipIPs
            if ($EFSkipIPs -is [array] -and $EFSkipIPs.Count -gt 0) {
                # Validate IPs/CIDRs
                foreach ($IP in $EFSkipIPs) {
                    $IPString = [string]$IP
                    # Check if it's a CIDR
                    if ($IPString -match '^(.+)/(\d+)$') {
                        $IPAddr = $matches[1]
                        $PrefixLength = [int]$matches[2]
                        # Validate IP address
                        $TestAddr = $null
                        if (-not [System.Net.IPAddress]::TryParse($IPAddr, [ref]$TestAddr)) {
                            throw "Invalid IP address in CIDR notation: $IPString"
                        }
                        # Validate prefix length
                        $MaxPrefix = if ($TestAddr.AddressFamily -eq 'InterNetwork') { 32 } else { 128 }
                        if ($PrefixLength -lt 0 -or $PrefixLength -gt $MaxPrefix) {
                            throw "Invalid CIDR prefix length: $IPString"
                        }
                    } else {
                        # Validate standalone IP
                        $TestAddr = $null
                        if (-not [System.Net.IPAddress]::TryParse($IPString, [ref]$TestAddr)) {
                            throw "Invalid IP address: $IPString"
                        }
                    }
                }
                $ConnectorParams.EFSkipIPs = $EFSkipIPs
            } elseif ($EFSkipIPs -eq $null -or ($EFSkipIPs -is [array] -and $EFSkipIPs.Count -eq 0)) {
                # Clear the setting
                $ConnectorParams.EFSkipIPs = @()
            }
        }

        # EFSkipLastIP - Skip the last IP (boolean)
        if ($null -ne $Request.Body.efSkipLastIP) {
            $ConnectorParams.EFSkipLastIP = [bool]$Request.Body.efSkipLastIP
        }

        # EFUsers - Email addresses to enable Enhanced Filtering for
        if ($null -ne $Request.Body.efUsers) {
            $EFUsers = $Request.Body.efUsers
            if ($EFUsers -is [array] -and $EFUsers.Count -gt 0) {
                # Validate email addresses
                foreach ($Email in $EFUsers) {
                    $EmailString = [string]$Email
                    if ($EmailString -notmatch '^[^@]+@[^@]+\.[^@]+$') {
                        throw "Invalid email address: $EmailString"
                    }
                }
                $ConnectorParams.EFUsers = $EFUsers
            } elseif ($EFUsers -eq $null -or ($EFUsers -is [array] -and $EFUsers.Count -eq 0)) {
                # Clear the setting
                $ConnectorParams.EFUsers = @()
            }
        }

        # Update the connector
        New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-InboundConnector' -cmdParams $ConnectorParams -useSystemMailbox $true

        $SettingsApplied = @()
        if ($ConnectorParams.ContainsKey('EFSkipIPs')) {
            if ($ConnectorParams.EFSkipIPs.Count -eq 0) {
                $SettingsApplied += 'EFSkipIPs cleared'
            } else {
                $SettingsApplied += "EFSkipIPs set to $($ConnectorParams.EFSkipIPs.Count) IP(s)"
            }
        }
        if ($ConnectorParams.ContainsKey('EFSkipLastIP')) {
            $SettingsApplied += "EFSkipLastIP set to $($ConnectorParams.EFSkipLastIP)"
        }
        if ($ConnectorParams.ContainsKey('EFUsers')) {
            if ($ConnectorParams.EFUsers.Count -eq 0) {
                $SettingsApplied += 'EFUsers cleared'
            } else {
                $SettingsApplied += "EFUsers set to $($ConnectorParams.EFUsers.Count) user(s)"
            }
        }

        $Result = "Enhanced Filtering configured for connector '$ConnectorIdentity': $($SettingsApplied -join ', ')"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
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
