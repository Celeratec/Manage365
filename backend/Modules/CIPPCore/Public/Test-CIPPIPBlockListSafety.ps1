function Test-CIPPIPBlockListSafety {
    <#
    .SYNOPSIS
        Guards against blocking tenant mail relay IPs

    .DESCRIPTION
        Validates that an IP or CIDR range does not overlap with:
        1. Tenant's inbound connector IPs (SenderIPAddresses)
        2. Tenant's outbound connector SmartHosts (IPs only)
        3. Known mail relay IPs (configured in KnownMailRelayIPs.json)

        Fails closed if connector lookup fails.

    .PARAMETER TenantFilter
        The tenant ID to check connectors for

    .PARAMETER IPsToCheck
        Array of IPs or CIDR ranges to validate

    .OUTPUTS
        Returns a hashtable with:
        - IsValid: $true if safe to block, $false if conflicts found
        - Reason: Error message if IsValid is $false
        - ConflictingIP: The IP that caused the conflict
        - ConflictingConnector: The connector name that contains the IP (if applicable)
        - ConflictingSource: 'InboundConnector', 'OutboundConnector', or 'KnownRelay'

    .EXAMPLE
        Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.1.1', '10.0.0.0/24')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string[]]$IPsToCheck
    )

    try {
        # Load known relay IPs from config, with fallback defaults
        $KnownRelayIPs = @('3.19.206.53', '3.142.175.190')
        try {
            # Resolve path from module root reliably (PSScriptRoot may not work when dot-sourced)
            $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            $ConfigPath = Join-Path $ModuleRoot 'Config/KnownMailRelayIPs.json'
            if (Test-Path $ConfigPath) {
                $KnownRelayConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
                if ($null -ne $KnownRelayConfig.KnownMailRelayIPs) {
                    $KnownRelayIPs = @($KnownRelayConfig.KnownMailRelayIPs)
                }
            }
        } catch {
            Write-Warning "Failed to load known relay IPs from config, using defaults: $_"
        }

        # Fail closed if no known relay IPs are configured
        if (@($KnownRelayIPs).Count -eq 0) {
            throw 'No known mail relay IPs configured. Cannot validate IP block list safety.'
        }

        Write-Verbose "Loaded $($KnownRelayIPs.Count) known relay IPs"

        # Normalize IPs to check - split by common delimiters and strip control characters
        $NormalizedIPs = @()
        foreach ($IP in $IPsToCheck) {
            if ([string]::IsNullOrWhiteSpace($IP)) {
                continue
            }
            # Strip control characters and cap length
            $IP = ($IP -replace '[\x00-\x1F\x7F]', '').Substring(0, [Math]::Min($IP.Length, 200))
            
            # Split by comma, semicolon, or whitespace and trim
            $SplitIPs = $IP -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
            
            foreach ($SplitIP in $SplitIPs) {
                # Block IP range notation (a-b) - fail closed
                if ($SplitIP -match '-') {
                    return @{
                        IsValid    = $false
                        Reason     = "IP range notation '$SplitIP' is not supported. The operation has been blocked as a safety precaution."
                        ConflictingIP = $SplitIP
                        ConflictingConnector = $null
                        ConflictingSource = 'InvalidFormat'
                    }
                }
                
                # Reject leading-zero octets (parsed as octal by .NET)
                if ($SplitIP -match '(^|\.)0\d') {
                    return @{
                        IsValid    = $false
                        Reason     = "IP '$SplitIP' contains leading-zero octets which are ambiguous. The operation has been blocked as a safety precaution."
                        ConflictingIP = $SplitIP
                        ConflictingConnector = $null
                        ConflictingSource = 'InvalidFormat'
                    }
                }
                
                $NormalizedIPs += $SplitIP
            }
        }

        if ($NormalizedIPs.Count -eq 0) {
            return @{
                IsValid    = $true
                Reason     = $null
                ConflictingIP = $null
                ConflictingConnector = $null
                ConflictingSource = $null
            }
        }

        Write-Verbose "Checking $($NormalizedIPs.Count) IPs: $($NormalizedIPs -join ', ')"

        # Check against known relay IPs first (no API call needed)
        foreach ($IPToCheck in $NormalizedIPs) {
            foreach ($KnownRelay in $KnownRelayIPs) {
                if (Test-IPOverlap -IP1 $IPToCheck -IP2 $KnownRelay) {
                    $SafeIP = $IPToCheck.Substring(0, [Math]::Min($IPToCheck.Length, 50))
                    return @{
                        IsValid    = $false
                        Reason     = "The IP '$SafeIP' matches known mail relay IP. Blocking this IP would disrupt mail relay services."
                        ConflictingIP = $SafeIP
                        ConflictingConnector = $null
                        ConflictingSource = 'KnownRelay'
                        ConflictingRelay = $KnownRelay
                    }
                }
            }
        }

        # Fetch inbound connectors
        $InboundConnectors = $null
        try {
            Write-Verbose "Fetching inbound connectors for tenant $TenantFilter"
            $InboundConnectors = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-InboundConnector' -ErrorAction Stop
            Write-Verbose "Retrieved $((@($InboundConnectors)).Count) inbound connectors"
        } catch {
            # Fail closed - if we can't get connectors, refuse the operation
            $ErrorDetail = "$($_.Exception.GetType().Name)"
            Write-Warning "Failed to fetch inbound connectors for tenant $TenantFilter : $ErrorDetail"
            return @{
                IsValid    = $false
                Reason     = "Unable to verify IP safety: Failed to fetch inbound connectors. The operation has been blocked as a safety precaution."
                ConflictingIP = $null
                ConflictingConnector = $null
                ConflictingSource = 'ConnectorLookupFailure'
            }
        }
        
        # Handle null result from New-ExoRequest (fail closed)
        if ($null -eq $InboundConnectors) {
            $InboundConnectors = @()
        }

        # Check against inbound connector IPs
        foreach ($Connector in @($InboundConnectors)) {
            if ($null -ne $Connector.SenderIPAddresses -and $Connector.SenderIPAddresses.Count -gt 0) {
                foreach ($ConnectorIP in $Connector.SenderIPAddresses) {
                    foreach ($IPToCheck in $NormalizedIPs) {
                        if (Test-IPOverlap -IP1 $IPToCheck -IP2 $ConnectorIP) {
                            $SafeIP = $IPToCheck.Substring(0, [Math]::Min($IPToCheck.Length, 50))
                            $SafeConnectorIP = $ConnectorIP.Substring(0, [Math]::Min($ConnectorIP.Length, 50))
                            $SafeConnectorName = $Connector.Name.Substring(0, [Math]::Min($Connector.Name.Length, 100))
                            return @{
                                IsValid    = $false
                                Reason     = "The IP '$SafeIP' overlaps with inbound connector '$SafeConnectorName' IP '$SafeConnectorIP'. Blocking this IP would disrupt inbound mail."
                                ConflictingIP = $SafeIP
                                ConflictingConnector = $SafeConnectorName
                                ConflictingSource = 'InboundConnector'
                            }
                        }
                    }
                }
            }
        }

        # Fetch outbound connectors
        $OutboundConnectors = $null
        try {
            Write-Verbose "Fetching outbound connectors for tenant $TenantFilter"
            $OutboundConnectors = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-OutboundConnector' -ErrorAction Stop
            Write-Verbose "Retrieved $((@($OutboundConnectors)).Count) outbound connectors"
        } catch {
            # Fail closed - if we can't get connectors, refuse the operation
            $ErrorDetail = "$($_.Exception.GetType().Name)"
            Write-Warning "Failed to fetch outbound connectors for tenant $TenantFilter : $ErrorDetail"
            return @{
                IsValid    = $false
                Reason     = "Unable to verify IP safety: Failed to fetch outbound connectors. The operation has been blocked as a safety precaution."
                ConflictingIP = $null
                ConflictingConnector = $null
                ConflictingSource = 'ConnectorLookupFailure'
            }
        }
        
        # Handle null result from New-ExoRequest (fail closed)
        if ($null -eq $OutboundConnectors) {
            $OutboundConnectors = @()
        }

        # Check against outbound connector SmartHosts (only IPs, not hostnames)
        foreach ($Connector in @($OutboundConnectors)) {
            if ($null -ne $Connector.SmartHosts -and $Connector.SmartHosts.Count -gt 0) {
                foreach ($SmartHost in $Connector.SmartHosts) {
                    # Use TryParse to validate if SmartHost is an IP (before any CIDR notation)
                    $SmartHostIP = if ($SmartHost -match '^(.+)/\d+$') { $Matches[1] } else { $SmartHost }
                    $ParsedIP = $null
                    if ([System.Net.IPAddress]::TryParse($SmartHostIP, [ref]$ParsedIP)) {
                        foreach ($IPToCheck in $NormalizedIPs) {
                            if (Test-IPOverlap -IP1 $IPToCheck -IP2 $SmartHost) {
                                $SafeIP = $IPToCheck.Substring(0, [Math]::Min($IPToCheck.Length, 50))
                                $SafeSmartHost = $SmartHost.Substring(0, [Math]::Min($SmartHost.Length, 50))
                                $SafeConnectorName = $Connector.Name.Substring(0, [Math]::Min($Connector.Name.Length, 100))
                                return @{
                                    IsValid    = $false
                                    Reason     = "The IP '$SafeIP' overlaps with outbound connector '$SafeConnectorName' SmartHost '$SafeSmartHost'. Blocking this IP would disrupt outbound mail."
                                    ConflictingIP = $SafeIP
                                    ConflictingConnector = $SafeConnectorName
                                    ConflictingSource = 'OutboundConnector'
                                }
                            }
                        }
                    }
                }
            }
        }

        # All checks passed
        return @{
            IsValid    = $true
            Reason     = $null
            ConflictingIP = $null
            ConflictingConnector = $null
            ConflictingSource = $null
        }

    } catch {
        # Unexpected error - fail closed
        $ErrorDetail = "$($_.Exception.GetType().Name)"
        Write-Warning "Unexpected error in Test-CIPPIPBlockListSafety: $ErrorDetail"
        return @{
            IsValid    = $false
            Reason     = "Unable to verify IP safety due to an unexpected error. The operation has been blocked as a safety precaution."
            ConflictingIP = $null
            ConflictingConnector = $null
            ConflictingSource = 'UnexpectedError'
        }
    }
}

function Test-CIPPIPBlockListSafetyCached {
    <#
    .SYNOPSIS
        Cached wrapper for Test-CIPPIPBlockListSafety
    
    .DESCRIPTION
        Performs the same validation as Test-CIPPIPBlockListSafety but caches results per tenant
        to avoid redundant connector lookups within a single execution context.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string[]]$IPsToCheck
    )
    
    if ($null -eq $script:IPBlockListSafetyCache) {
        $script:IPBlockListSafetyCache = @{}
    }
    
    if (-not $script:IPBlockListSafetyCache.ContainsKey($TenantFilter)) {
        $script:IPBlockListSafetyCache[$TenantFilter] = Test-CIPPIPBlockListSafety -TenantFilter $TenantFilter -IPsToCheck $IPsToCheck
    }
    
    return $script:IPBlockListSafetyCache[$TenantFilter]
}

function Test-IPOverlap {
    <#
    .SYNOPSIS
        Tests if two IPs or CIDR ranges overlap

    .DESCRIPTION
        Compares two IP addresses or CIDR ranges to determine if they overlap.
        Handles both IPv4 and IPv6 addresses.

    .PARAMETER IP1
        First IP or CIDR range

    .PARAMETER IP2
        Second IP or CIDR range

    .OUTPUTS
        Returns $true if the IPs overlap, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IP1,

        [Parameter(Mandatory = $true)]
        [string]$IP2
    )

    try {
        # Parse IP1
        $IP1Address = $null
        $IP1Prefix = 32
        if ($IP1 -match '^(.+)/(\d+)$') {
            $IP1Address = [System.Net.IPAddress]::Parse($Matches[1])
            $IP1Prefix = [int]$Matches[2]
        } else {
            $IP1Address = [System.Net.IPAddress]::Parse($IP1)
            $IP1Prefix = if ($IP1Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) { 128 } else { 32 }
        }
        
        # Map IPv4-mapped IPv6 to IPv4
        if ($IP1Address.IsIPv4MappedToIPv6) {
            $IP1Address = $IP1Address.MapToIPv4()
            $IP1Prefix = [Math]::Max(0, $IP1Prefix - 96)
        }

        # Parse IP2
        $IP2Address = $null
        $IP2Prefix = 32
        if ($IP2 -match '^(.+)/(\d+)$') {
            $IP2Address = [System.Net.IPAddress]::Parse($Matches[1])
            $IP2Prefix = [int]$Matches[2]
        } else {
            $IP2Address = [System.Net.IPAddress]::Parse($IP2)
            $IP2Prefix = if ($IP2Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) { 128 } else { 32 }
        }
        
        # Map IPv4-mapped IPv6 to IPv4
        if ($IP2Address.IsIPv4MappedToIPv6) {
            $IP2Address = $IP2Address.MapToIPv4()
            $IP2Prefix = [Math]::Max(0, $IP2Prefix - 96)
        }

        # Check if address families match
        if ($IP1Address.AddressFamily -ne $IP2Address.AddressFamily) {
            return $false
        }

        # For IPv4, use bitwise comparison
        if ($IP1Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
            # Convert to bytes and then to uint32
            $IP1Bytes = $IP1Address.GetAddressBytes()
            $IP2Bytes = $IP2Address.GetAddressBytes()

            # Reverse for little-endian systems
            [Array]::Reverse($IP1Bytes)
            [Array]::Reverse($IP2Bytes)

            $IP1Int = [BitConverter]::ToUInt32($IP1Bytes, 0)
            $IP2Int = [BitConverter]::ToUInt32($IP2Bytes, 0)

            # Determine the smaller prefix length (more specific)
            $MinPrefix = [Math]::Min($IP1Prefix, $IP2Prefix)

            # Create mask for the minimum prefix
            if ($MinPrefix -eq 0) {
                $Mask = 0
            } else {
                $Mask = [uint32]([uint32]::MaxValue -shl (32 - $MinPrefix))
            }

            # Compare network portions
            return (($IP1Int -band $Mask) -eq ($IP2Int -band $Mask))
        } elseif ($IP1Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            # For IPv6, compare byte by byte
            $IP1Bytes = $IP1Address.GetAddressBytes()
            $IP2Bytes = $IP2Address.GetAddressBytes()

            # Determine the smaller prefix length
            $MinPrefix = [Math]::Min($IP1Prefix, $IP2Prefix)

            # Compare full bytes
            $FullBytes = [Math]::Floor($MinPrefix / 8)
            for ($i = 0; $i -lt $FullBytes; $i++) {
                if ($IP1Bytes[$i] -ne $IP2Bytes[$i]) {
                    return $false
                }
            }

            # Compare remaining bits
            $RemainingBits = $MinPrefix % 8
            if ($RemainingBits -gt 0) {
                $Mask = [byte](0xFF -shl (8 - $RemainingBits))
                if (($IP1Bytes[$FullBytes] -band $Mask) -ne ($IP2Bytes[$FullBytes] -band $Mask)) {
                    return $false
                }
            }

            return $true
        }

        return $false

    } catch {
        $ErrorDetail = "$($_.Exception.GetType().Name)"
        Write-Warning "Error comparing IPs '$IP1' and '$IP2': $ErrorDetail"
        # If we can't parse, assume they might overlap (fail safe)
        return $true
    }
}
