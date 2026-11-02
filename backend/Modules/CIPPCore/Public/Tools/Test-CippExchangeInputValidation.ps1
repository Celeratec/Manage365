function Test-CippExchangeInputValidation {
    <#
    .SYNOPSIS
        Validates common Exchange Online input parameters with strict security checks.
    .DESCRIPTION
        Provides validation for policy names, email addresses, domains, IP addresses,
        CIDR ranges, and other Exchange Online configuration parameters.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PolicyName,

        [Parameter(Mandatory = $false)]
        [string]$RuleName,

        [Parameter(Mandatory = $false)]
        [string]$EmailAddress,

        [Parameter(Mandatory = $false)]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [string[]]$EmailAddresses,

        [Parameter(Mandatory = $false)]
        [string[]]$Domains,

        [Parameter(Mandatory = $false)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $false)]
        [string]$IPAddress,

        [Parameter(Mandatory = $false)]
        [string[]]$IPAddresses,

        [Parameter(Mandatory = $false)]
        $Priority,

        [Parameter(Mandatory = $false)]
        [switch]$StrictIPValidation,

        [Parameter(Mandatory = $false)]
        [int]$MaxIPCount = 50,

        [Parameter(Mandatory = $false)]
        [string[]]$SentToMemberOf,

        [Parameter(Mandatory = $false)]
        [string]$QuarantineTag,

        [Parameter(Mandatory = $false)]
        [string[]]$LanguageBlockList,

        [Parameter(Mandatory = $false)]
        [string[]]$RegionBlockList
    )

    $Result = @{
        IsValid = $true
        Errors  = @()
    }

    # Validate policy/rule names: must match ^\w .-]{1,64}\z (use \z not $)
    if ($PolicyName) {
        # Check for embedded newlines/LF first
        if ($PolicyName -match '[\r\n]') {
            $Result.IsValid = $false
            $Result.Errors += "Policy name cannot contain newline characters"
        } else {
            # Trim and validate pattern
            $PolicyNameTrimmed = $PolicyName.Trim()
            if ($PolicyNameTrimmed -notmatch '\A[\w .-]{1,64}\z') {
                $Result.IsValid = $false
                $Result.Errors += "Policy name must match pattern ^\w .-]{1,64}\z (alphanumeric, spaces, dots, hyphens, underscores, 1-64 chars)"
            }
        }
    }

    if ($RuleName) {
        # Check for embedded newlines/LF first
        if ($RuleName -match '[\r\n]') {
            $Result.IsValid = $false
            $Result.Errors += "Rule name cannot contain newline characters"
        } else {
            # Trim and validate pattern
            $RuleNameTrimmed = $RuleName.Trim()
            if ($RuleNameTrimmed -notmatch '\A[\w .-]{1,64}\z') {
                $Result.IsValid = $false
                $Result.Errors += "Rule name must match pattern ^\w .-]{1,64}\z (alphanumeric, spaces, dots, hyphens, underscores, 1-64 chars)"
            }
        }
    }

    # Validate email addresses (use \z instead of $ to prevent newline bypass)
    $EmailRegex = '\A[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z'
    if ($EmailAddress) {
        # Check for LF/CR BEFORE trimming
        if ($EmailAddress -match '[\r\n]') {
            $Result.IsValid = $false
            $Result.Errors += "Email address cannot contain newline characters"
        } else {
            $EmailAddress = $EmailAddress.Trim()
            if ($EmailAddress -notmatch $EmailRegex) {
                $Result.IsValid = $false
                $Result.Errors += "Invalid email address format: $EmailAddress"
            }
        }
    }

    if ($EmailAddresses -and $EmailAddresses.Count -gt 0) {
        foreach ($Email in $EmailAddresses) {
            # Check RAW value for LF/CR BEFORE trim
            $EmailRaw = [string]$Email
            if ($EmailRaw -match '[\r\n]') {
                $Result.IsValid = $false
                $Result.Errors += "Email address cannot contain newline characters"
                continue
            }
            
            $EmailStr = $EmailRaw.Trim()
            if (![string]::IsNullOrWhiteSpace($EmailStr)) {
                if ($EmailStr -notmatch $EmailRegex) {
                    $Result.IsValid = $false
                    $Result.Errors += "Invalid email address format: $EmailStr"
                }
            }
        }
        # Cap check
        if ($EmailAddresses.Count -gt 1000) {
            $Result.IsValid = $false
            $Result.Errors += "Email address list exceeds maximum of 1000 entries"
        }
    }

    # Validate domains (use \z instead of $)
    $DomainRegex = '\A[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\z'
    if ($Domain) {
        # Check for LF/CR BEFORE trimming
        if ($Domain -match '[\r\n]') {
            $Result.IsValid = $false
            $Result.Errors += "Domain cannot contain newline characters"
        } else {
            $Domain = $Domain.Trim()
            if ($Domain -notmatch $DomainRegex) {
                $Result.IsValid = $false
                $Result.Errors += "Invalid domain format: $Domain"
            }
        }
    }

    if ($Domains -and $Domains.Count -gt 0) {
        foreach ($Dom in $Domains) {
            $DomStr = [string]$Dom
            if (![string]::IsNullOrWhiteSpace($DomStr) -and $DomStr -notmatch $DomainRegex) {
                $Result.IsValid = $false
                $Result.Errors += "Invalid domain format: $DomStr"
            }
        }
        # Cap check
        if ($Domains.Count -gt 1000) {
            $Result.IsValid = $false
            $Result.Errors += "Domain list exceeds maximum of 1000 entries"
        }
    }

    # Validate UPN (email or GUID, use \z)
    if ($UserPrincipalName) {
        $GuidRegex = '\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z'
        # Check for LF/CR BEFORE trimming
        if ($UserPrincipalName -match '[\r\n]') {
            $Result.IsValid = $false
            $Result.Errors += "UserPrincipalName cannot contain newline characters"
        } else {
            $UserPrincipalName = $UserPrincipalName.Trim()
            if ($UserPrincipalName -notmatch $EmailRegex -and $UserPrincipalName -notmatch $GuidRegex) {
                $Result.IsValid = $false
                $Result.Errors += "UserPrincipalName must be a valid email address or GUID"
            }
        }
    }

    # Validate IP addresses and CIDR ranges
    if ($IPAddress) {
        $IPValidation = Test-CippIPAddressStrict -IPAddress $IPAddress -StrictMode:$StrictIPValidation
        if (-not $IPValidation.IsValid) {
            $Result.IsValid = $false
            $Result.Errors += $IPValidation.Errors
        }
    }

    if ($IPAddresses -and $IPAddresses.Count -gt 0) {
        # Check count cap
        if ($IPAddresses.Count -gt $MaxIPCount) {
            $Result.IsValid = $false
            $Result.Errors += "IP address list exceeds maximum of $MaxIPCount entries"
        }

        foreach ($IP in $IPAddresses) {
            $IPStr = [string]$IP
            if (![string]::IsNullOrWhiteSpace($IPStr)) {
                $IPValidation = Test-CippIPAddressStrict -IPAddress $IPStr -StrictMode:$StrictIPValidation
                if (-not $IPValidation.IsValid) {
                    $Result.IsValid = $false
                    $Result.Errors += $IPValidation.Errors
                }
            }
        }
    }

    # Validate priority (must be integer between 0 and 9999, accept Int16/32/64 and whole doubles, reject booleans and non-whole floats)
    if ($null -ne $Priority) {
        # Reject booleans explicitly
        if ($Priority -is [bool]) {
            $Result.IsValid = $false
            $Result.Errors += "Priority must be an integer, not a boolean"
            return $Result
        }
        
        # Accept any whole-number integer type: Int16, Int32, Int64
        if ($Priority -is [int16] -or $Priority -is [int32] -or $Priority -is [int64]) {
            # Already a valid integer type, just range check
            if ($Priority -lt 0 -or $Priority -gt 9999) {
                $Result.IsValid = $false
                $Result.Errors += "Priority must be between 0 and 9999"
            }
        }
        # Accept whole doubles (like 5.0) but reject non-whole (like 5.7)
        elseif ($Priority -is [double] -or $Priority -is [float] -or $Priority -is [decimal]) {
            if ($Priority -ne [Math]::Floor($Priority)) {
                $Result.IsValid = $false
                $Result.Errors += "Priority must be a whole number, not a decimal: $Priority"
                return $Result
            }
            # Convert to int for range check
            $PriorityInt = [int]$Priority
            if ($PriorityInt -lt 0 -or $PriorityInt -gt 9999) {
                $Result.IsValid = $false
                $Result.Errors += "Priority must be between 0 and 9999"
            }
        }
        # For strings, try to parse as integer
        elseif ($Priority -is [string]) {
            if ($Priority -match '\.') {
                $Result.IsValid = $false
                $Result.Errors += "Priority must be an integer, not a decimal: $Priority"
                return $Result
            }
            $PriorityInt = 0
            if (-not [int]::TryParse($Priority, [ref]$PriorityInt)) {
                $Result.IsValid = $false
                $Result.Errors += "Priority must be a valid integer"
                return $Result
            }
            if ($PriorityInt -lt 0 -or $PriorityInt -gt 9999) {
                $Result.IsValid = $false
                $Result.Errors += "Priority must be between 0 and 9999"
            }
        }
        else {
            # Reject any other type
            $Result.IsValid = $false
            $Result.Errors += "Priority must be an integer, got $($Priority.GetType().Name)"
            return $Result
        }
    }

    # Validate SentToMemberOf (group emails or GUIDs)
    if ($SentToMemberOf -and $SentToMemberOf.Count -gt 0) {
        $GuidRegex = '\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z'
        foreach ($Member in $SentToMemberOf) {
            # Check RAW value for LF/CR BEFORE trim
            if ($Member -match '[\r\n]') {
                $Result.IsValid = $false
                $Result.Errors += "SentToMemberOf entry cannot contain newline characters"
                continue
            }
            
            $MemberStr = $Member.Trim()
            if ($MemberStr -notmatch $EmailRegex -and $MemberStr -notmatch $GuidRegex) {
                $Result.IsValid = $false
                $Result.Errors += "SentToMemberOf entry must be a valid email address or GUID: $MemberStr"
            }
        }
        if ($SentToMemberOf.Count -gt 1000) {
            $Result.IsValid = $false
            $Result.Errors += "SentToMemberOf list exceeds maximum of 1000 entries"
        }
    }

    # Validate QuarantineTag (alphanumeric, hyphens, 1-64 chars, \z-anchored)
    if ($QuarantineTag) {
        # Check RAW value for LF/CR BEFORE trim
        if ($QuarantineTag -match '[\r\n]') {
            $Result.IsValid = $false
            $Result.Errors += "QuarantineTag cannot contain newline characters"
        } else {
            $QuarantineTag = $QuarantineTag.Trim()
            if ($QuarantineTag -notmatch '\A[a-zA-Z0-9-]{1,64}\z') {
                $Result.IsValid = $false
                $Result.Errors += "QuarantineTag must be 1-64 alphanumeric characters or hyphens: $QuarantineTag"
            }
        }
    }

    # Validate LanguageBlockList (2-letter ISO 639-1 codes, case-sensitive)
    if ($LanguageBlockList -and $LanguageBlockList.Count -gt 0) {
        foreach ($Lang in $LanguageBlockList) {
            # Check for LF/CR before trimming
            if ($Lang -match '[\r\n]') {
                $Result.IsValid = $false
                $Result.Errors += "Language code cannot contain newline characters"
            } else {
                $LangStr = $Lang.Trim()
                # Use -cnotmatch for case-sensitive check
                if ($LangStr -cnotmatch '\A[a-z]{2}\z') {
                    $Result.IsValid = $false
                    $Result.Errors += "Invalid language code '$LangStr' (must be 2-letter lowercase ISO 639-1 code)"
                }
            }
        }
    }

    # Validate RegionBlockList (2-letter uppercase ISO 3166-1 codes, case-sensitive)
    if ($RegionBlockList -and $RegionBlockList.Count -gt 0) {
        foreach ($Region in $RegionBlockList) {
            # Check RAW value for LF/CR BEFORE trim
            if ($Region -match '[\r\n]') {
                $Result.IsValid = $false
                $Result.Errors += "Region code cannot contain newline characters"
                continue
            }
            
            $RegionStr = $Region.Trim()
            if ($RegionStr -cnotmatch '\A[A-Z]{2}\z') {
                $Result.IsValid = $false
                $Result.Errors += "Invalid region code '$RegionStr' (must be 2-letter uppercase ISO 3166-1 code)"
            }
        }
    }

    return $Result
}

function Test-CippIPAddressStrict {
    <#
    .SYNOPSIS
        Validates IP addresses with strict security checks for Enhanced Filtering.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [Parameter(Mandatory = $false)]
        [switch]$StrictMode
    )

    $Result = @{
        IsValid = $true
        Errors  = @()
    }

    # Check for LF/CR BEFORE trimming (trim would remove trailing newlines)
    if ($IPAddress -match '[\r\n]') {
        $Result.IsValid = $false
        $Result.Errors += "IP address cannot contain newline characters"
        return $Result
    }
    
    $IPString = $IPAddress.Trim()

    # Check for IP range notation (a-b) which Exchange supports
    if ($IPString -match '\A(.+)-(.+)\z') {
        $StartIP = $matches[1].Trim()
        $EndIP = $matches[2].Trim()
        
        # Validate both IPs
        $StartAddr = $null
        $EndAddr = $null
        if (-not [System.Net.IPAddress]::TryParse($StartIP, [ref]$StartAddr)) {
            $Result.IsValid = $false
            $Result.Errors += "Invalid start IP address in range: $IPString"
            return $Result
        }
        if (-not [System.Net.IPAddress]::TryParse($EndIP, [ref]$EndAddr)) {
            $Result.IsValid = $false
            $Result.Errors += "Invalid end IP address in range: $IPString"
            return $Result
        }

        # Ensure both are same address family
        if ($StartAddr.AddressFamily -ne $EndAddr.AddressFamily) {
            $Result.IsValid = $false
            $Result.Errors += "IP range must use same address family (both IPv4 or both IPv6): $IPString"
            return $Result
        }

        # Strict mode: validate format and breadth for IPv4
        if ($StrictMode -and $StartAddr.AddressFamily -eq 'InterNetwork') {
            # Require strict dotted-quad format (reject 10/16, 010.1.1.1)
            if ($StartIP -notmatch '\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z' -or $EndIP -notmatch '\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z') {
                $Result.IsValid = $false
                $Result.Errors += "IPv4 addresses in range must be in dotted-quad notation: $IPString"
                return $Result
            }
            
            # Check for leading zeros (010.1.1.1)
            $StartOctets = $StartIP -split '\.'
            $EndOctets = $EndIP -split '\.'
            foreach ($Octet in ($StartOctets + $EndOctets)) {
                if ($Octet.Length -gt 1 -and $Octet.StartsWith('0')) {
                    $Result.IsValid = $false
                    $Result.Errors += "IPv4 addresses cannot have leading zeros (octal notation): $IPString"
                    return $Result
                }
            }
            
            # Calculate range breadth - must cover at most a /16 (65536 addresses)
            $StartBytes = $StartAddr.GetAddressBytes()
            $EndBytes = $EndAddr.GetAddressBytes()
            $StartInt = [BitConverter]::ToUInt32($StartBytes[3..0], 0)
            $EndInt = [BitConverter]::ToUInt32($EndBytes[3..0], 0)
            
            if ($EndInt -lt $StartInt) {
                $Result.IsValid = $false
                $Result.Errors += "IP range end must be >= start: $IPString"
                return $Result
            }
            
            $RangeSize = $EndInt - $StartInt + 1
            if ($RangeSize -gt 65536) {
                $Result.IsValid = $false
                $Result.Errors += "IPv4 range covers $RangeSize addresses, exceeds /16 maximum (65536): $IPString"
                return $Result
            }
        }
        
        # Strict mode: validate breadth for IPv6
        if ($StrictMode -and $StartAddr.AddressFamily -eq 'InterNetworkV6') {
            # Calculate range breadth - must cover at most a /32 (2^96 addresses)
            $StartBytes = $StartAddr.GetAddressBytes()
            $EndBytes = $EndAddr.GetAddressBytes()
            
            # Compare the first 4 bytes (top 32 bits)
            $StartPrefix = [BitConverter]::ToUInt32($StartBytes[0..3], 0)
            $EndPrefix = [BitConverter]::ToUInt32($EndBytes[0..3], 0)
            
            if ($StartPrefix -ne $EndPrefix) {
                $Result.IsValid = $false
                $Result.Errors += "IPv6 range exceeds /32 maximum (top 32 bits differ): $IPString"
                return $Result
            }
        }

        return $Result
    }

    # Check for CIDR notation
    if ($IPString -match '\A(.+)/(\d+)\z') {
        $IPAddr = $matches[1]
        $PrefixLengthStr = $matches[2]
        
        # Validate prefix length is numeric and has no leading zeros
        if ($PrefixLengthStr -notmatch '\A\d+\z') {
            $Result.IsValid = $false
            $Result.Errors += "Invalid CIDR prefix length: $IPString"
            return $Result
        }
        
        # Reject leading zeros in prefix (e.g., /032)
        if ($PrefixLengthStr.Length -gt 1 -and $PrefixLengthStr.StartsWith('0')) {
            $Result.IsValid = $false
            $Result.Errors += "CIDR prefix length cannot have leading zeros: $IPString"
            return $Result
        }

        $PrefixLength = [int]$PrefixLengthStr

        # Validate IP address
        $TestAddr = $null
        if (-not [System.Net.IPAddress]::TryParse($IPAddr, [ref]$TestAddr)) {
            $Result.IsValid = $false
            $Result.Errors += "Invalid IP address in CIDR notation: $IPString"
            return $Result
        }

        # Strict mode: require dotted-quad for IPv4 (reject 10/16, 010.1.1.1)
        if ($StrictMode -and $TestAddr.AddressFamily -eq 'InterNetwork') {
            if ($IPAddr -notmatch '\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z') {
                $Result.IsValid = $false
                $Result.Errors += "IPv4 address in CIDR must be in dotted-quad notation (reject shorthand like 10/16): $IPString"
                return $Result
            }
            
            # Check for leading zeros
            $Octets = $IPAddr -split '\.'
            foreach ($Octet in $Octets) {
                if ($Octet.Length -gt 1 -and $Octet.StartsWith('0')) {
                    $Result.IsValid = $false
                    $Result.Errors += "IPv4 address cannot have leading zeros (octal notation): $IPString"
                    return $Result
                }
            }
        }

        # Validate prefix length range
        $MaxPrefix = if ($TestAddr.AddressFamily -eq 'InterNetwork') { 32 } else { 128 }
        if ($PrefixLength -lt 0 -or $PrefixLength -gt $MaxPrefix) {
            $Result.IsValid = $false
            $Result.Errors += "Invalid CIDR prefix length for address family: $IPString"
            return $Result
        }

        # Strict mode: enforce minimum prefix lengths
        if ($StrictMode) {
            if ($TestAddr.AddressFamily -eq 'InterNetwork') {
                # IPv4: require /16 or more specific (reject /0 to /15)
                if ($PrefixLength -lt 16) {
                    $Result.IsValid = $false
                    $Result.Errors += "IPv4 CIDR prefix must be /16 or more specific (reject overly broad ranges like 0.0.0.0/0): $IPString"
                    return $Result
                }
            } else {
                # IPv6: require /32 or more specific (reject /0 to /31)
                if ($PrefixLength -lt 32) {
                    $Result.IsValid = $false
                    $Result.Errors += "IPv6 CIDR prefix must be /32 or more specific (reject overly broad ranges like ::/0): $IPString"
                    return $Result
                }
            }
        }
    } else {
        # Standalone IP - must be a valid IP address, not shorthand
        $TestAddr = $null
        if (-not [System.Net.IPAddress]::TryParse($IPString, [ref]$TestAddr)) {
            $Result.IsValid = $false
            $Result.Errors += "Invalid IP address: $IPString"
            return $Result
        }

        # Strict mode: reject shorthand like '1' and leading zeros
        if ($StrictMode) {
            if ($TestAddr.AddressFamily -eq 'InterNetwork') {
                # IPv4 must have exactly 4 octets
                if ($IPString -notmatch '\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z') {
                    $Result.IsValid = $false
                    $Result.Errors += "IPv4 address must be in dotted-quad notation (reject shorthand like '1'): $IPString"
                    return $Result
                }
                
                # Check for leading zeros
                $Octets = $IPString -split '\.'
                foreach ($Octet in $Octets) {
                    if ($Octet.Length -gt 1 -and $Octet.StartsWith('0')) {
                        $Result.IsValid = $false
                        $Result.Errors += "IPv4 address cannot have leading zeros (octal notation): $IPString"
                        return $Result
                    }
                }
            }
        }
    }

    return $Result
}
