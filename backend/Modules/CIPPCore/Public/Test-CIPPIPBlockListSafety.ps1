function Get-CIPPKnownMailRelayIPs {
    <#
    .SYNOPSIS
    Loads known mail relay IPs from config file.
    
    .DESCRIPTION
    Resolves backend/Config/KnownMailRelayIPs.json from $PSScriptRoot and fails closed:
    throws if the file is missing, unreadable, JSON is bad, list is empty, or any IP fails to parse.
    #>
    [CmdletBinding()]
    param()
    
    # Resolve config path from CIPPRootPath environment variable (set in production)
    # Falls back to script location for local development
    if ($env:CIPPRootPath) {
        $BackendRoot = $env:CIPPRootPath
    } else {
        $BackendRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    }
    $ConfigPath = Join-Path $BackendRoot 'Config/KnownMailRelayIPs.json'
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Known relay IP config file not found at $ConfigPath"
    }
    
    try {
        $ConfigData = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse known relay IP config file: $_"
    }
    
    if (-not ($ConfigData.PSObject.Properties.Name -contains 'KnownMailRelayIPs')) {
        throw "Config file missing KnownMailRelayIPs property"
    }
    
    $KnownRelayIPs = @($ConfigData.KnownMailRelayIPs)
    if ($KnownRelayIPs.Count -eq 0) {
        throw "Known relay IP list is empty"
    }
    
    # Validate all IPs parse correctly
    foreach ($IP in $KnownRelayIPs) {
        # Require dotted-quad IPv4 or colon for IPv6 before TryParse
        if ($IP -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -and $IP -notmatch ':') {
            throw "Invalid IP address format in config: $IP"
        }
        
        $TestAddr = $null
        if (-not [System.Net.IPAddress]::TryParse($IP, [ref]$TestAddr)) {
            throw "Invalid IP address in config: $IP"
        }
    }
    
    return $KnownRelayIPs
}

function Test-CIPPIPBlockListSafety {
    <#
    .SYNOPSIS
    Guards against blocking tenant mail relay IPs.
    
    .DESCRIPTION
    Validates that an IP or CIDR range does not overlap with:
    1. Tenant's inbound connector IPs (SenderIPAddresses)
    2. Tenant's outbound connector SmartHosts (IPs only)
    3. Known mail relay IPs (from backend/Config/KnownMailRelayIPs.json)
    
    Fails closed if connector lookup fails or config cannot be loaded.
    
    .PARAMETER TenantFilter
    The tenant domain (e.g., contoso.onmicrosoft.com).
    
    .PARAMETER IPsToCheck
    Array of IPs or CIDR ranges to validate.
    
    .OUTPUTS
    Returns a hashtable with:
    - IsValid: $true if safe to block, $false if conflicts found
    - Reason: Error message if IsValid is $false
    - ConflictingIP: The IP that caused the conflict
    - ConflictingConnector: The connector name (if applicable)
    - ConflictingSource: 'InboundConnector', 'OutboundConnector', or 'KnownRelay'
    - ConflictingRelay: The specific relay IP that matched (for KnownRelay)
    
    .PARAMETER SkipConnectorCheck
    When set, skips the inbound and outbound connector lookups. Use for template validation only,
    where no real tenant exists. Standard and Baseline executors must NOT pass this flag.
    
    .EXAMPLE
    Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.1.1', '10.0.0.0/24')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,
        
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$IPsToCheck,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipConnectorCheck
    )
    
    try {
        # Load known relay IPs from config (fails closed)
        try {
            $KnownRelayIPs = Get-CIPPKnownMailRelayIPs
        } catch {
            throw "Failed to load known relay IP configuration: $_"
        }
        
    # Sanitize and validate input IPs - split FIRST, then cap per-token
    $CleanedIPs = @()
    foreach ($IP in $IPsToCheck) {
        if ([string]::IsNullOrWhiteSpace($IP)) { continue }
        
        # Remove control characters first
        $cleaned = $IP -replace '[\x00-\x1F\x7F]', ''
        
        # Split by comma, semicolon, or whitespace
        $SplitIPs = $cleaned -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        
        foreach ($token in $SplitIPs) {
            $trimmed = $token.Trim()
            
            # Refuse any single token longer than 50 chars (fail closed)
            if ($trimmed.Length -gt 50) {
                return @{
                    IsValid              = $false
                    Reason               = "IP entry '$($trimmed.Substring(0,50))' exceeds maximum length of 50 characters."
                    ConflictingIP        = $trimmed.Substring(0, 50)
                    ConflictingConnector = $null
                    ConflictingSource    = 'ValidationError'
                    ConflictingRelay     = $null
                }
            }
            
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            # Block IP range notation (a-b) - fail closed
            if ($trimmed -match '-') {
                return @{
                    IsValid              = $false
                    Reason               = "Exchange IP range notation '$trimmed' is not supported. Please enter individual IPs or CIDR ranges."
                    ConflictingIP        = $trimmed
                    ConflictingConnector = $null
                    ConflictingSource    = 'ValidationError'
                    ConflictingRelay     = $null
                }
            }
            
            # Block leading zeros (010.0.0.1)
            if ($trimmed -match '(^|\.)0\d') {
                return @{
                    IsValid              = $false
                    Reason               = "IP address '$trimmed' contains leading zeros, which are not allowed."
                    ConflictingIP        = $trimmed
                    ConflictingConnector = $null
                    ConflictingSource    = 'ValidationError'
                    ConflictingRelay     = $null
                }
            }
            
            # Require full dotted-quad for IPv4 (reject 3.19.206)
            if ($trimmed -match '^[0-9./:]+$' -and $trimmed -notmatch '^(\d{1,3}\.){3}\d{1,3}(/\d+)?$' -and $trimmed -notmatch ':') {
                return @{
                    IsValid              = $false
                    Reason               = "IP address '$trimmed' is not a valid format. IPv4 requires four octets (e.g., 192.168.1.1)."
                    ConflictingIP        = $trimmed
                    ConflictingConnector = $null
                    ConflictingSource    = 'ValidationError'
                    ConflictingRelay     = $null
                }
            }
            
            $CleanedIPs += $trimmed
        }
    }
        
        if ($CleanedIPs.Count -eq 0) {
            return @{
                IsValid              = $true
                Reason               = 'No IPs to check'
                ConflictingIP        = $null
                ConflictingConnector = $null
                ConflictingSource    = $null
                ConflictingRelay     = $null
            }
        }
        
        # Check each IP against known relay IPs
        foreach ($IPToCheck in $CleanedIPs) {
            foreach ($KnownIP in $KnownRelayIPs) {
                $OverlapResult = Test-CIPPIPOverlap -IP1 $IPToCheck -IP2 $KnownIP
                
                # Fail closed if either IP is unparseable
                if (-not $OverlapResult.Valid) {
                    return @{
                        IsValid              = $false
                        Reason               = "IP '$IPToCheck' is not valid: $($OverlapResult.Error)"
                        ConflictingIP        = $IPToCheck
                        ConflictingConnector = $null
                        ConflictingSource    = 'ValidationError'
                        ConflictingRelay     = $null
                    }
                }
                
                if ($OverlapResult.Overlaps) {
                    return @{
                        IsValid              = $false
                        Reason               = "IP '$IPToCheck' overlaps with known mail relay IP '$KnownIP'. Blocking this IP would break mail delivery."
                        ConflictingIP        = $IPToCheck
                        ConflictingConnector = $null
                        ConflictingSource    = 'KnownRelay'
                        ConflictingRelay     = $KnownIP
                    }
                }
            }
        }
        
        # Skip connector checks if requested (for template validation only)
        if ($SkipConnectorCheck) {
            # All checks passed (only known relay IPs were checked)
            return @{
                IsValid              = $true
                Reason               = $null
                ConflictingIP        = $null
                ConflictingConnector = $null
                ConflictingSource    = $null
                ConflictingRelay     = $null
            }
        }
        
        # Fetch inbound connectors
        try {
            $InboundConnectors = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-InboundConnector' -ErrorAction Stop
        } catch {
            Write-Warning "Failed to fetch inbound connectors for tenant $TenantFilter : $($_.Exception.GetType().Name)"
            return @{
                IsValid              = $false
                Reason               = "Failed to verify inbound connectors. The operation has been blocked as a safety precaution."
                ConflictingIP        = $null
                ConflictingConnector = $null
                ConflictingSource    = 'ConnectorLookupFailure'
                ConflictingRelay     = $null
            }
        }
        
        # Empty array or null both OK - tenant may have no connectors
        $InboundConnectors = @($InboundConnectors)
        
        # Check against inbound connector IPs
        foreach ($Connector in $InboundConnectors) {
            if ($Connector.SenderIPAddresses) {
                foreach ($ConnectorIP in $Connector.SenderIPAddresses) {
                    # Fail closed if connector uses range notation (a-b)
                    if ($ConnectorIP -match '-') {
                        return @{
                            IsValid              = $false
                            Reason               = "Inbound connector '$($Connector.Name)' uses range notation '$ConnectorIP'. Cannot safely validate. The operation has been blocked."
                            ConflictingIP        = $ConnectorIP
                            ConflictingConnector = $Connector.Name
                            ConflictingSource    = 'InboundConnector'
                            ConflictingRelay     = $null
                        }
                    }
                    
                    foreach ($IPToCheck in $CleanedIPs) {
                        $OverlapResult = Test-CIPPIPOverlap -IP1 $IPToCheck -IP2 $ConnectorIP
                        if ($OverlapResult.Overlaps) {
                            return @{
                                IsValid              = $false
                                Reason               = "IP '$IPToCheck' overlaps with inbound connector '$($Connector.Name)' SenderIPAddress '$ConnectorIP'. Blocking this IP would break mail delivery."
                                ConflictingIP        = $IPToCheck
                                ConflictingConnector = $Connector.Name
                                ConflictingSource    = 'InboundConnector'
                                ConflictingRelay     = $null
                            }
                        }
                    }
                }
            }
        }
        
        # Fetch outbound connectors
        try {
            $OutboundConnectors = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-OutboundConnector' -ErrorAction Stop
        } catch {
            Write-Warning "Failed to fetch outbound connectors for tenant $TenantFilter : $($_.Exception.GetType().Name)"
            return @{
                IsValid              = $false
                Reason               = "Failed to verify outbound connectors. The operation has been blocked as a safety precaution."
                ConflictingIP        = $null
                ConflictingConnector = $null
                ConflictingSource    = 'ConnectorLookupFailure'
                ConflictingRelay     = $null
            }
        }
        
        # Empty array or null both OK
        $OutboundConnectors = @($OutboundConnectors)
        
        # Check against outbound connector SmartHosts (IPs only)
        if ($OutboundConnectors) {
            foreach ($Connector in $OutboundConnectors) {
                if ($Connector.SmartHosts) {
                    foreach ($SmartHost in $Connector.SmartHosts) {
                        # Only check IPs, skip hostnames
                        $SmartHostIP = $null
                        if ([System.Net.IPAddress]::TryParse($SmartHost, [ref]$SmartHostIP)) {
                            foreach ($IPToCheck in $CleanedIPs) {
                                $OverlapResult = Test-CIPPIPOverlap -IP1 $IPToCheck -IP2 $SmartHost
                                if ($OverlapResult.Overlaps) {
                                    return @{
                                        IsValid              = $false
                                        Reason               = "IP '$IPToCheck' overlaps with outbound connector '$($Connector.Name)' SmartHost '$SmartHost'. Blocking this IP would break mail delivery."
                                        ConflictingIP        = $IPToCheck
                                        ConflictingConnector = $Connector.Name
                                        ConflictingSource    = 'OutboundConnector'
                                        ConflictingRelay     = $null
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        # All checks passed
        return @{
            IsValid              = $true
            Reason               = $null
            ConflictingIP        = $null
            ConflictingConnector = $null
            ConflictingSource    = $null
            ConflictingRelay     = $null
        }
    } catch {
        Write-Warning "Guard check error for tenant $TenantFilter : $($_.Exception.Message)"
        return @{
            IsValid              = $false
            Reason               = 'Unable to verify IP safety due to an unexpected error. The operation has been blocked as a safety precaution.'
            ConflictingIP        = $null
            ConflictingConnector = $null
            ConflictingSource    = 'UnexpectedError'
            ConflictingRelay     = $null
        }
    }
}

function Test-CIPPIPOverlap {
    <#
    .SYNOPSIS
    Tests whether two IPs or CIDR ranges overlap.
    
    .PARAMETER IP1
    First IP or CIDR range.
    
    .PARAMETER IP2
    Second IP or CIDR range.
    
    .OUTPUTS
    Returns a hashtable with:
    - Overlaps: $true if the IPs/ranges overlap, $false otherwise
    - Valid: $true if both inputs are valid, $false if either is invalid
    - Error: Error message if inputs are invalid
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
        $Addr1 = $null
        $Prefix1 = 0
        if ($IP1 -match '^(.+?)/(-?\d+)$') {
            $IP1Str = $Matches[1]
            $PrefixStr = $Matches[2]
            $Prefix1 = [int]$PrefixStr
            
            # Reject negative prefix
            if ($Prefix1 -lt 0) {
                Write-Warning "Invalid prefix /$Prefix1 in IP1"
                return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
            }
            
            if (-not [System.Net.IPAddress]::TryParse($IP1Str, [ref]$Addr1)) {
                Write-Warning "Failed to parse IP1 base address"
                return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
            }
            
            # Validate prefix
            $MaxPrefix = if ($Addr1.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { 32 } else { 128 }
            if ($Prefix1 -gt $MaxPrefix) {
                Write-Warning "Invalid prefix /$Prefix1 for address family (max $MaxPrefix)"
                return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
            }
        } else {
            if (-not [System.Net.IPAddress]::TryParse($IP1, [ref]$Addr1)) {
                Write-Warning "Failed to parse IP1"
                return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
            }
            $Prefix1 = if ($Addr1.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { 32 } else { 128 }
        }
        
        # Parse IP2
        $Addr2 = $null
        $Prefix2 = 0
        if ($IP2 -match '^(.+?)/(-?\d+)$') {
            $IP2Str = $Matches[1]
            $PrefixStr = $Matches[2]
            $Prefix2 = [int]$PrefixStr
            
            # Reject negative prefix
            if ($Prefix2 -lt 0) {
                Write-Warning "Invalid prefix /$Prefix2 in IP2"
                return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
            }
            
            if (-not [System.Net.IPAddress]::TryParse($IP2Str, [ref]$Addr2)) {
                Write-Warning "Failed to parse IP2 base address"
                return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
            }
            
            # Validate prefix
            $MaxPrefix = if ($Addr2.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { 32 } else { 128 }
            if ($Prefix2 -gt $MaxPrefix) {
                Write-Warning "Invalid prefix /$Prefix2 for address family (max $MaxPrefix)"
                return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
            }
        } else {
            if (-not [System.Net.IPAddress]::TryParse($IP2, [ref]$Addr2)) {
                Write-Warning "Failed to parse IP2"
                return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
            }
            $Prefix2 = if ($Addr2.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { 32 } else { 128 }
        }
        
        # Normalize IPv4-mapped IPv6 addresses
        if ($Addr1.IsIPv4MappedToIPv6) {
            $Addr1 = $Addr1.MapToIPv4()
            if ($Prefix1 -ge 96) { $Prefix1 = $Prefix1 - 96 }
        }
        if ($Addr2.IsIPv4MappedToIPv6) {
            $Addr2 = $Addr2.MapToIPv4()
            if ($Prefix2 -ge 96) { $Prefix2 = $Prefix2 - 96 }
        }
        
        # Different address families don't overlap
        if ($Addr1.AddressFamily -ne $Addr2.AddressFamily) {
            return @{ Overlaps = $false; Valid = $true; Error = $null }
        }
        
        # Validate prefix lengths
        $MaxPrefix = if ($Addr1.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { 32 } else { 128 }
        if ($Prefix1 -lt 0 -or $Prefix1 -gt $MaxPrefix) {
            Write-Warning "Invalid prefix length $Prefix1"
            return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
        }
        if ($Prefix2 -lt 0 -or $Prefix2 -gt $MaxPrefix) {
            Write-Warning "Invalid prefix length $Prefix2"
            return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
        }
        
        # Convert to byte arrays
        $Bytes1 = $Addr1.GetAddressBytes()
        $Bytes2 = $Addr2.GetAddressBytes()
        
        # Check overlap: compare bits up to the shorter prefix
        $CheckBits = [Math]::Min($Prefix1, $Prefix2)
        for ($i = 0; $i -lt $CheckBits; $i++) {
            $ByteIndex = [Math]::Floor($i / 8)
            $BitMask = 1 -shl (7 - ($i % 8))
            if (($Bytes1[$ByteIndex] -band $BitMask) -ne ($Bytes2[$ByteIndex] -band $BitMask)) {
                return @{ Overlaps = $false; Valid = $true; Error = $null }
            }
        }
        
        return @{ Overlaps = $true; Valid = $true; Error = $null }
    } catch {
        Write-Warning "Overlap check error: $($_.Exception.Message)"
        return @{ Overlaps = $false; Valid = $false; Error = 'Unparseable IP or CIDR' }
    }
}
