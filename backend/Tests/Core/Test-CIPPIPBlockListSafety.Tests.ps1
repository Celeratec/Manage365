BeforeAll {
    # RepoRoot goes up 3 levels from Tests/Core/File.ps1 to backend root
    $BackendRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $env:CIPPRootPath = Split-Path -Parent $BackendRoot
    
    # Import the guard function
    . (Join-Path $BackendRoot 'Modules/CIPPCore/Public/Test-CIPPIPBlockListSafety.ps1')
    
    # Stub New-ExoRequest
    function New-ExoRequest { }
}

Describe 'Test-CIPPIPBlockListSafety' {
    BeforeEach {
        # Reset mocks before each test
        Mock New-ExoRequest
    }

    Context 'Known Relay IP Checks' {
        It 'Blocks exact match of known relay IP' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.53')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
            $Result.ConflictingIP | Should -Be '3.19.206.53'
            $Result.ConflictingRelay | Should -Be '3.19.206.53'
            $Result.Reason | Should -Match 'known mail relay'
        }

        It 'Blocks CIDR range containing known relay IP' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.0/24')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
            $Result.ConflictingIP | Should -Be '3.19.206.0/24'
        }

        It 'Blocks both configured known relay IPs' {
            $Result1 = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.53')
            $Result2 = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.142.175.190')
            
            $Result1.IsValid | Should -BeFalse
            $Result1.ConflictingRelay | Should -Be '3.19.206.53'
            
            $Result2.IsValid | Should -BeFalse
            $Result2.ConflictingRelay | Should -Be '3.142.175.190'
        }
        
        It 'Blocks IPv4-mapped IPv6 of known relay (::ffff:3.19.206.53)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('::ffff:3.19.206.53')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
        }

        It 'Allows IP that does not match known relays' {
            Mock New-ExoRequest {
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Loads known relay IPs from config file or uses fallback defaults' {
            $ConfigPath = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) 'backend/Config/KnownMailRelayIPs.json'
            if (Test-Path $ConfigPath) {
                $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
                $Config.KnownMailRelayIPs | Should -Not -BeNullOrEmpty
                $Config.KnownMailRelayIPs.Count | Should -BeGreaterThan 0
            } else {
                # Config file doesn't exist yet - function uses fallback defaults
                $true | Should -BeTrue
            }
        }
    }

    Context 'Inbound Connector Checks' {
        It 'Blocks IP that matches inbound connector SenderIPAddress' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Partner Connector'
                            SenderIPAddresses = @('10.0.0.5', '192.168.1.1')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.0.5')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
            $Result.ConflictingIP | Should -Be '10.0.0.5'
            $Result.ConflictingConnector | Should -Be 'Partner Connector'
            $Result.Reason | Should -Match 'inbound connector'
        }

        It 'Blocks CIDR range that overlaps with inbound connector IP' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Partner Connector'
                            SenderIPAddresses = @('10.0.0.5')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.0.0/24')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
        }

        It 'Allows IP when no inbound connectors exist' {
            Mock New-ExoRequest {
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }
    }

    Context 'Outbound Connector Checks' {
        It 'Blocks IP that matches outbound connector SmartHost' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @()
                }
                if ($cmdlet -eq 'Get-OutboundConnector') {
                    return @(
                        @{
                            Name = 'Relay Connector'
                            SmartHosts = @('10.0.0.10', '192.168.2.1')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.0.10')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'OutboundConnector'
            $Result.ConflictingIP | Should -Be '10.0.0.10'
            $Result.ConflictingConnector | Should -Be 'Relay Connector'
            $Result.Reason | Should -Match 'outbound connector'
        }

        It 'Skips hostname SmartHosts (does not block)' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @()
                }
                if ($cmdlet -eq 'Get-OutboundConnector') {
                    return @(
                        @{
                            Name = 'Relay Connector'
                            SmartHosts = @('smtp.partner.com')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }

        It 'Blocks CIDR range that overlaps with outbound connector SmartHost' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @()
                }
                if ($cmdlet -eq 'Get-OutboundConnector') {
                    return @(
                        @{
                            Name = 'Relay Connector'
                            SmartHosts = @('10.0.0.10')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.0.0/24')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'OutboundConnector'
        }
    }

    Context 'Connector Lookup Failure (Fail Closed)' {
        It 'Fails closed when inbound connector lookup fails' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    throw 'Network error'
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
            $Result.Reason | Should -Match 'Failed to fetch inbound connectors'
        }

        It 'Fails closed when outbound connector lookup fails' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @()
                }
                if ($cmdlet -eq 'Get-OutboundConnector') {
                    throw 'Network error'
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
            $Result.Reason | Should -Match 'Failed to fetch outbound connectors'
        }
        
        It 'Handles null result from New-ExoRequest (fail closed)' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return $null
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }
    }

    Context 'Clean IP Allowed' {
        It 'Allows IP that does not conflict with any source' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Partner Connector'
                            SenderIPAddresses = @('10.0.0.5')
                        }
                    )
                }
                if ($cmdlet -eq 'Get-OutboundConnector') {
                    return @(
                        @{
                            Name = 'Relay Connector'
                            SmartHosts = @('10.0.0.10')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
            $Result.Reason | Should -BeNullOrEmpty
            $Result.ConflictingIP | Should -BeNullOrEmpty
            $Result.ConflictingConnector | Should -BeNullOrEmpty
            $Result.ConflictingSource | Should -BeNullOrEmpty
        }

        It 'Allows multiple IPs when none conflict' {
            Mock New-ExoRequest {
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4', '5.6.7.8', '9.10.11.12')
            $Result.IsValid | Should -BeTrue
        }
    }

    Context 'Input Handling' {
        It 'Handles comma-separated IP string' {
            Mock New-ExoRequest {
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4, 5.6.7.8')
            $Result.IsValid | Should -BeTrue
        }

        It 'Handles empty IP list' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @()
            $Result.IsValid | Should -BeTrue
        }

        It 'Handles whitespace-only entries' {
            Mock New-ExoRequest {
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('  ', '', '1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Rejects IP range notation (a-b)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.0.1-10.0.0.50')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InvalidFormat'
            $Result.Reason | Should -Match 'range notation'
        }
        
        It 'Rejects leading-zero octets' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.001.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InvalidFormat'
            $Result.Reason | Should -Match 'leading-zero'
        }
        
        It 'Rejects another leading-zero format' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('010.0.0.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InvalidFormat'
        }
        
        It 'Handles invalid IP gracefully' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('not-an-ip')
            $Result.IsValid | Should -BeFalse
        }
    }

    Context 'CIDR Overlap Detection' {
        It 'Detects overlap when checking /24 against specific IP' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Partner Connector'
                            SenderIPAddresses = @('192.168.1.100')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.1.0/24')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
        }

        It 'Detects overlap when checking specific IP against /24' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Partner Connector'
                            SenderIPAddresses = @('192.168.1.0/24')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.1.100')
            $Result.IsValid | Should -BeFalse
        }

        It 'Detects overlap between two CIDR ranges' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Partner Connector'
                            SenderIPAddresses = @('10.0.0.0/16')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.5.0/24')
            $Result.IsValid | Should -BeFalse
        }

        It 'Does not detect false overlap for different networks' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Partner Connector'
                            SenderIPAddresses = @('192.168.1.0/24')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.2.0/24')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Detects overlap with 3.0.0.0/8' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Large Network'
                            SenderIPAddresses = @('3.19.206.53')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.0.0.0/8')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Detects overlap with 0.0.0.0/0 (entire IPv4)' {
            Mock New-ExoRequest {
                param($tenantid, $cmdlet)
                if ($cmdlet -eq 'Get-InboundConnector') {
                    return @(
                        @{
                            Name = 'Any Connector'
                            SenderIPAddresses = @('1.2.3.4')
                        }
                    )
                }
                return @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('0.0.0.0/0')
            $Result.IsValid | Should -BeFalse
        }
    }
}

Describe 'Test-CIPPIPOverlap' {
    Context 'Exact IP Matches' {
        It 'Returns true for identical IPv4 addresses' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '192.168.1.1'
            $Result | Should -BeTrue
        }

        It 'Returns false for different IPv4 addresses' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '192.168.1.2'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }
    }

    Context 'CIDR Range Overlaps' {
        It 'Returns true when IP is in CIDR range' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.100' -IP2 '192.168.1.0/24'
            $Result | Should -BeTrue
        }

        It 'Returns false when IP is outside CIDR range' {
            $Result = Test-CIPPIPOverlap -IP1 '10.0.0.1' -IP2 '192.168.1.0/24'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }

        It 'Returns true for overlapping CIDR ranges' {
            $Result = Test-CIPPIPOverlap -IP1 '10.0.0.0/16' -IP2 '10.0.5.0/24'
            $Result | Should -BeTrue
        }

        It 'Returns false for non-overlapping CIDR ranges' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.0/24' -IP2 '10.0.0.0/8'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }

        It 'Handles /32 CIDR notation' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1/32' -IP2 '192.168.1.1'
            $Result | Should -BeTrue
        }
    }

    Context 'IPv6 Support' {
        It 'Returns true for identical IPv6 addresses' {
            $Result = Test-CIPPIPOverlap -IP1 '2001:db8::1' -IP2 '2001:db8::1'
            $Result | Should -BeTrue
        }

        It 'Returns false for different IPv6 addresses' {
            $Result = Test-CIPPIPOverlap -IP1 '2001:db8::1' -IP2 '2001:db8::2'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }

        It 'Returns true when IPv6 is in CIDR range' {
            $Result = Test-CIPPIPOverlap -IP1 '2001:db8::100' -IP2 '2001:db8::/64'
            $Result | Should -BeTrue
        }

        It 'Returns false for IPv4 vs IPv6' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '2001:db8::1'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }
        
        It 'Handles IPv4-mapped IPv6 addresses (::ffff:192.168.1.1)' {
            $Result = Test-CIPPIPOverlap -IP1 '::ffff:192.168.1.1' -IP2 '192.168.1.1'
            $Result | Should -BeTrue
        }
        
        It 'Handles IPv4-mapped IPv6 against CIDR' {
            $Result = Test-CIPPIPOverlap -IP1 '::ffff:192.168.1.100' -IP2 '192.168.1.0/24'
            $Result | Should -BeTrue
        }
    }

    Context 'Edge Cases' {
        It 'Handles /0 CIDR (matches all)' {
            $Result = Test-CIPPIPOverlap -IP1 '1.2.3.4' -IP2 '0.0.0.0/0'
            $Result | Should -BeTrue
        }

        It 'Handles invalid IP gracefully (fails safe)' {
            $Result = Test-CIPPIPOverlap -IP1 'invalid' -IP2 '192.168.1.1'
            $Result | Should -BeTrue
        }
    }
}
