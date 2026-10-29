BeforeAll {
    # RepoRoot goes up 3 levels from Tests/Core/File.ps1 to backend root
    $BackendRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $env:CIPPRootPath = Split-Path -Parent $BackendRoot
    
    # Import the guard function
    . (Join-Path $BackendRoot 'Modules/CIPPCore/Public/Test-CIPPIPBlockListSafety.ps1')
    
    # Define stub function for mocking
    function New-ExoRequest { }
}

Describe 'Test-CIPPIPBlockListSafety' {
    BeforeEach {
        # Stub New-ExoRequest with default empty connector response
        # Use , @() to force returning an array wrapper so it doesn't unwrap to $null
        Mock New-ExoRequest {
            , @()
        }
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
        }
        
        It 'Blocks both configured known relay IPs' {
            $Result1 = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.53')
            $Result2 = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.142.175.190')
            $Result1.IsValid | Should -BeFalse
            $Result2.IsValid | Should -BeFalse
        }
        
        It 'Blocks IPv4-mapped IPv6 of known relay (::ffff:3.19.206.53)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('::ffff:3.19.206.53')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
        }
        
        It 'Allows IP that does not match known relays' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('203.0.113.1')
            $Result.IsValid | Should -BeTrue
        }
    }
    
    Context 'Config Loader (Get-CIPPKnownMailRelayIPs)' {
        It 'Loads known relay IPs from config file when it exists' {
            $ConfigPath = Join-Path (Split-Path -Parent $BackendRoot) 'backend/Config/KnownMailRelayIPs.json'
            if (Test-Path $ConfigPath) {
                $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                $Config.KnownMailRelayIPs | Should -Contain '3.19.206.53'
                $Config.KnownMailRelayIPs | Should -Contain '3.142.175.190'
                $Config.KnownMailRelayIPs.Count | Should -BeGreaterThan 0
            } else {
                Set-ItResult -Skipped -Because 'Config file not present in test environment'
            }
        }
        
        It 'Throws when config file is missing' {
            # This test will fail unless we mock the file system properly
            # Just verify the error message contains expected text
            { 
                # Force a path that doesn't exist by mocking Test-Path at the module level
                Mock Test-Path { $false } -ModuleName CIPPCore -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
                Get-CIPPKnownMailRelayIPs 
            } | Should -Throw '*not found*'
        }
        
        It 'Throws when config file is empty' {
            Mock Get-Content { '{"KnownMailRelayIPs":[]}' } -ModuleName CIPPCore
            { Get-CIPPKnownMailRelayIPs } | Should -Throw '*empty*'
        }
        
        It 'Throws when config JSON is invalid' {
            Mock Get-Content { '{invalid json' } -ModuleName CIPPCore
            { Get-CIPPKnownMailRelayIPs } | Should -Throw
        }
        
        It 'Throws when config has invalid IP' {
            Mock Get-Content { '{"KnownMailRelayIPs":["999.999.999.999"]}' } -ModuleName CIPPCore
            { Get-CIPPKnownMailRelayIPs } | Should -Throw '*Invalid IP*'
        }
    }
    
    Context 'Inbound Connector Checks' {
        It 'Blocks IP that matches inbound connector SenderIPAddress' {
            Mock New-ExoRequest {
                , @(
                    @{
                        Name              = 'TestInbound'
                        SenderIPAddresses = @('198.51.100.5')
                    }
                )
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.5')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
            $Result.ConflictingConnector | Should -Be 'TestInbound'
        }
        
        It 'Blocks CIDR range that overlaps with inbound connector IP' {
            Mock New-ExoRequest {
                , @(
                    @{
                        Name              = 'TestInbound'
                        SenderIPAddresses = @('198.51.100.10')
                    }
                )
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.0/24')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
        }
        
        It 'Allows IP when no inbound connectors exist' {
            Mock New-ExoRequest { , @() } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.5')
            $Result.IsValid | Should -BeTrue
        }
    }
    
    Context 'Outbound Connector Checks' {
        It 'Blocks IP that matches outbound connector SmartHost' {
            Mock New-ExoRequest {
                , @()
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            Mock New-ExoRequest {
                , @(
                    @{
                        Name       = 'TestOutbound'
                        SmartHosts = @('198.51.100.20')
                    }
                )
            } -ParameterFilter { $CommandName -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.20')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'OutboundConnector'
            $Result.ConflictingConnector | Should -Be 'TestOutbound'
        }
        
        It 'Skips hostname SmartHosts (does not block)' {
            Mock New-ExoRequest {
                , @()
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            Mock New-ExoRequest {
                , @(
                    @{
                        Name       = 'TestOutbound'
                        SmartHosts = @('mail.example.com')
                    }
                )
            } -ParameterFilter { $CommandName -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.20')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Blocks CIDR range that overlaps with outbound connector SmartHost' {
            Mock New-ExoRequest {
                , @()
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            Mock New-ExoRequest {
                , @(
                    @{
                        Name       = 'TestOutbound'
                        SmartHosts = @('198.51.100.25')
                    }
                )
            } -ParameterFilter { $CommandName -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.0/24')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'OutboundConnector'
        }
    }
    
    Context 'Connector Lookup Failure (Fail Closed)' {
        It 'Fails closed when inbound connector lookup fails' {
            Mock New-ExoRequest {
                throw 'Connection timeout'
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
            $Result.Reason | Should -Match 'inbound'
        }
        
        It 'Fails closed when outbound connector lookup fails' {
            Mock New-ExoRequest {
                , @()
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            Mock New-ExoRequest {
                throw 'Connection timeout'
            } -ParameterFilter { $CommandName -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
            $Result.Reason | Should -Match 'outbound'
        }
        
        It 'Fails closed when inbound connector lookup returns null' {
            Mock New-ExoRequest {
                return $null
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
            $Result.Reason | Should -Match 'null'
        }
    }
    
    Context 'Clean IP Allowed' {
        It 'Allows IP that does not conflict with any source' {
            Mock New-ExoRequest {
                , @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('203.0.113.50')
            $Result.IsValid | Should -BeTrue
            $Result.ConflictingIP | Should -BeNullOrEmpty
            $Result.ConflictingSource | Should -BeNullOrEmpty
        }
        
        It 'Allows multiple IPs when none conflict' {
            Mock New-ExoRequest {
                , @()
            }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('203.0.113.1', '203.0.113.2')
            $Result.IsValid | Should -BeTrue
        }
    }
    
    Context 'Input Handling' {
        It 'Handles comma-separated IP string' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('203.0.113.1, 203.0.113.2')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Handles empty IP list' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @()
            $Result.IsValid | Should -BeTrue
            $Result.Reason | Should -Match 'No IPs'
        }
        
        It 'Handles whitespace-only entries' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('   ', '', '  ')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Rejects IP range notation (a-b)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.1.1-192.168.1.10')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ValidationError'
            $Result.Reason | Should -Match 'range notation'
        }
        
        It 'Rejects leading-zero octets' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('010.0.0.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ValidationError'
            $Result.Reason | Should -Match 'leading zero'
        }
        
        It 'Rejects another leading-zero format' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.01.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ValidationError'
        }
        
        It 'Removes control characters from input' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @("203.0.113.1`t`n")
            $Result.IsValid | Should -BeTrue
        }
    }
    
    Context 'CIDR Overlap Detection' {
        It 'Detects overlap when checking /24 against specific IP' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.0/24')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
        }
        
        It 'Detects overlap when checking specific IP against /24' {
            Mock New-ExoRequest {
                , @(
                    @{
                        Name              = 'TestInbound'
                        SenderIPAddresses = @('192.168.1.0/24')
                    }
                )
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.1.50')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Detects overlap between two CIDR ranges' {
            Mock New-ExoRequest {
                , @(
                    @{
                        Name              = 'TestInbound'
                        SenderIPAddresses = @('10.0.0.0/16')
                    }
                )
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.5.0/24')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Does not detect false overlap for different networks' {
            Mock New-ExoRequest {
                , @(
                    @{
                        Name              = 'TestInbound'
                        SenderIPAddresses = @('192.168.1.0/24')
                    }
                )
            } -ParameterFilter { $CommandName -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.0.1')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Detects overlap with 3.0.0.0/8' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.0.0.0/8')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Detects overlap with 0.0.0.0/0 (entire IPv4)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('0.0.0.0/0')
            $Result.IsValid | Should -BeFalse
        }
    }
}

Describe 'Test-CIPPIPOverlap' {
    Context 'Exact IP Matches' {
        It 'Returns Overlaps=true for identical IPv4 addresses' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '192.168.1.1'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Overlaps=false for different IPv4 addresses' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '192.168.1.2'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }
    }
    
    Context 'CIDR Range Overlaps' {
        It 'Returns Overlaps=true when IP is in CIDR range' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.100' -IP2 '192.168.1.0/24'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Overlaps=false when IP is outside CIDR range' {
            $Result = Test-CIPPIPOverlap -IP1 '10.0.0.1' -IP2 '192.168.1.0/24'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Overlaps=true for overlapping CIDR ranges' {
            $Result = Test-CIPPIPOverlap -IP1 '10.0.0.0/16' -IP2 '10.0.5.0/24'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Overlaps=false for non-overlapping CIDR ranges' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.0/24' -IP2 '10.0.0.0/8'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }
        
        It 'Handles /32 CIDR notation' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1/32' -IP2 '192.168.1.1'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
    }
    
    Context 'IPv6 Support' {
        It 'Returns Overlaps=true for identical IPv6 addresses' {
            $Result = Test-CIPPIPOverlap -IP1 '2001:db8::1' -IP2 '2001:db8::1'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Overlaps=false for different IPv6 addresses' {
            $Result = Test-CIPPIPOverlap -IP1 '2001:db8::1' -IP2 '2001:db8::2'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Overlaps=true when IPv6 is in CIDR range' {
            $Result = Test-CIPPIPOverlap -IP1 '2001:db8::100' -IP2 '2001:db8::/64'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Overlaps=false for IPv4 vs IPv6' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '2001:db8::1'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }
        
        It 'Handles IPv4-mapped IPv6 addresses (::ffff:192.168.1.1)' {
            $Result = Test-CIPPIPOverlap -IP1 '::ffff:192.168.1.1' -IP2 '192.168.1.1'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
        
        It 'Handles IPv4-mapped IPv6 against CIDR' {
            $Result = Test-CIPPIPOverlap -IP1 '::ffff:192.168.1.50' -IP2 '192.168.1.0/24'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
    }
    
    Context 'Edge Cases' {
        It 'Handles /0 CIDR (matches all)' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '0.0.0.0/0'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Valid=false for invalid IP' {
            $Result = Test-CIPPIPOverlap -IP1 '999.999.999.999' -IP2 '192.168.1.1'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeFalse
            $Result.Error | Should -Not -BeNullOrEmpty
        }
    }
}
