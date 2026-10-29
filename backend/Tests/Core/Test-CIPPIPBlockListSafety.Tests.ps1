BeforeAll {
    # Set CIPPRootPath to backend root
    $BackendRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $env:CIPPRootPath = $BackendRoot
    
    # Import the guard function
    . (Join-Path $BackendRoot 'Modules/CIPPCore/Public/Test-CIPPIPBlockListSafety.ps1')
    
    # Define stub function matching real New-ExoRequest signature
    function New-ExoRequest { 
        param(
            [string]$tenantid,
            [string]$cmdlet,
            $cmdParams,
            [string]$Select,
            [string]$Anchor,
            [bool]$useSystemMailbox,
            [bool]$NoAuthCheck
        )
    }
}

Describe 'Get-CIPPKnownMailRelayIPs' {
    Context 'Config file loading' {
        It 'Loads the real config file successfully' {
            $IPs = Get-CIPPKnownMailRelayIPs
            $IPs | Should -Not -BeNullOrEmpty
            $IPs | Should -Contain '3.19.206.53'
            $IPs | Should -Contain '3.142.175.190'
        }
        
        It 'Uses CIPPRootPath when set (QA #2)' {
            $OrigPath = $env:CIPPRootPath
            $env:CIPPRootPath = $BackendRoot
            
            $IPs = Get-CIPPKnownMailRelayIPs
            $IPs | Should -Contain '3.19.206.53'
            
            $env:CIPPRootPath = $OrigPath
        }
        
        It 'Throws when config file is missing' {
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            { Get-CIPPKnownMailRelayIPs } | Should -Throw '*not found*'
        }
        
        It 'Throws when config JSON is invalid' {
            Mock Get-Content { '{invalid json' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            { Get-CIPPKnownMailRelayIPs } | Should -Throw '*parse*'
        }
        
        It 'Throws when config missing KnownMailRelayIPs property' {
            Mock Get-Content { '{"OtherProperty":[]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            { Get-CIPPKnownMailRelayIPs } | Should -Throw '*missing*'
        }
        
        It 'Throws when relay list is empty (M14 - real empty array)' {
            Mock Get-Content { '{"KnownMailRelayIPs":[]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            { Get-CIPPKnownMailRelayIPs } | Should -Throw '*empty*'
        }
        
        It 'Rejects IP that parses as 0.0.0.3 from input "3"' {
            Mock Get-Content { '{"KnownMailRelayIPs":["3"]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            { Get-CIPPKnownMailRelayIPs } | Should -Throw '*format*'
        }
        
        It 'Throws when config contains invalid IP' {
            Mock Get-Content { '{"KnownMailRelayIPs":["999.999.999.999"]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            { Get-CIPPKnownMailRelayIPs } | Should -Throw '*Invalid IP*'
        }
    }
}

Describe 'Test-CIPPIPBlockListSafety' {
    BeforeEach {
        Mock New-ExoRequest { , @() }
    }
    
    Context 'No-Connector Scenarios (Security R4 #1)' {
        It 'Allows clean IP when connectors return $null' {
            Mock New-ExoRequest { return $null } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest { return $null } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Allows clean IP when connectors return @()' {
            Mock New-ExoRequest { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest { , @() } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Allows 49-char IPv6 CIDR when connectors return @()' {
            Mock New-ExoRequest { , @() }
            
            $IPv6CIDR = '2001:0db8:85a3:0000:0000:8a2e:0370:7334/64'
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @($IPv6CIDR)
            $Result.IsValid | Should -BeTrue
        }
    }
    
    Context 'Known Relay IP Checks' {
        It 'Blocks exact match of known relay IP' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.53')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
            $Result.ConflictingRelay | Should -Be '3.19.206.53'
        }
        
        It 'Blocks second known relay IP (M5)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.142.175.190')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
            $Result.ConflictingRelay | Should -Be '3.142.175.190'
        }
        
        It 'Blocks CIDR range containing known relay IP' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.0/24')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
        }
        
        It 'Blocks IPv4-mapped IPv6 of known relay' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('::ffff:3.19.206.53')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
        }
        
        It 'Blocks IPv6 CIDR containing known relay (M18)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('::ffff:3.19.0.0/96')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'KnownRelay'
        }
        
        It 'Allows IP that does not match known relays' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('203.0.113.1')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Uses custom config with additional relay IP' {
            Mock Get-Content { '{"KnownMailRelayIPs":["10.99.88.77","3.19.206.53"]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.99.88.77')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingRelay | Should -Be '10.99.88.77'
        }
    }
    
    Context 'Inbound Connector Checks' {
        It 'Blocks IP that matches inbound connector' {
            Mock New-ExoRequest {
                , @(@{ Name = 'TestInbound'; SenderIPAddresses = @('198.51.100.5') })
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.5')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
        }
        
        It 'Blocks CIDR overlapping with inbound connector' {
            Mock New-ExoRequest {
                , @(@{ Name = 'TestInbound'; SenderIPAddresses = @('198.51.100.10') })
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.0/24')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Fails closed when inbound connector uses range notation (M15)' {
            Mock New-ExoRequest {
                , @(@{ Name = 'TestInbound'; SenderIPAddresses = @('198.51.100.1-198.51.100.10') })
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('8.8.8.8')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
            $Result.ConflictingIP | Should -Be '198.51.100.1-198.51.100.10'
        }
        
        It 'Allows clean IP when tenant has no inbound connectors' {
            Mock New-ExoRequest { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest { , @() } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeTrue
        }
    }
    
    Context 'Outbound Connector Checks' {
        It 'Blocks IP matching outbound connector SmartHost' {
            Mock New-ExoRequest { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest {
                , @(@{ Name = 'TestOutbound'; SmartHosts = @('198.51.100.20') })
            } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.20')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'OutboundConnector'
        }
        
        It 'Skips hostname SmartHosts' {
            Mock New-ExoRequest { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest {
                , @(@{ Name = 'TestOutbound'; SmartHosts = @('mail.example.com') })
            } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.20')
            $Result.IsValid | Should -BeTrue
        }
    }
    
    Context 'Fail Closed Behavior' {
        It 'Fails closed when inbound lookup throws' {
            Mock New-ExoRequest { throw 'Connection timeout' } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
        }
        
        It 'Fails closed when outbound lookup throws' {
            Mock New-ExoRequest { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest { throw 'Connection timeout' } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
        }
        
        It 'Fails closed on unexpected error (M13b)' {
            Mock Get-CIPPKnownMailRelayIPs { throw 'Unexpected database error' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('8.8.8.8')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'UnexpectedError'
        }
        
        It 'Does not leak exception message to client (Security R4 #3)' {
            Mock Get-CIPPKnownMailRelayIPs { throw 'SECRET_DATABASE_CONNECTION_STRING' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('8.8.8.8')
            $Result.IsValid | Should -BeFalse
            $Result.Reason | Should -Not -Match 'SECRET_DATABASE_CONNECTION_STRING'
            $Result.Reason | Should -Be 'Unable to verify IP safety due to an unexpected error. The operation has been blocked as a safety precaution.'
        }
    }
    
    Context 'Input Validation' {
        It 'Handles empty IP list' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @()
            $Result.IsValid | Should -BeTrue
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
            $Result.Reason | Should -Match 'leading zero'
        }
        
        It 'Rejects partial dotted IP (3.19.206)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206')
            $Result.IsValid | Should -BeFalse
            $Result.Reason | Should -Match 'four octets'
        }
        
        It 'Refuses token longer than 50 chars' {
            $LongString = '1.2.3.4,' + ('x' * 60)
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @($LongString)
            $Result.IsValid | Should -BeFalse
            $Result.Reason | Should -Match 'exceeds maximum'
        }
        
        It 'Removes control characters from input' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @("203.0.113.1`t`n")
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Refuses unparseable input without dash (M12)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('notanipaddress')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ValidationError'
        }
    }
    
    Context 'CIDR and IPv6' {
        It 'Detects overlap with /24 CIDR' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.0/24')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Detects overlap with 0.0.0.0/0' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('0.0.0.0/0')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Allows non-overlapping CIDR' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.1.0/24')
            $Result.IsValid | Should -BeTrue
        }
    }
}

Describe 'Test-CIPPIPOverlap' {
    Context 'Prefix Validation (M9)' {
        It 'Rejects /33 prefix on IPv4' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.0/33' -IP2 '192.168.1.1'
            $Result.Valid | Should -BeFalse
            $Result.Error | Should -Match '/33'
        }
        
        It 'Rejects /-1 prefix' {
            $Result = Test-CIPPIPOverlap -IP1 '1.1.1.1/-1' -IP2 '1.1.1.1'
            $Result.Valid | Should -BeFalse
            $Result.Error | Should -Match '/-1'
        }
        
        It 'Rejects /129 prefix on IPv6' {
            $Result = Test-CIPPIPOverlap -IP1 '2001:db8::/129' -IP2 '2001:db8::1'
            $Result.Valid | Should -BeFalse
            $Result.Error | Should -Match '/129'
        }
    }
    
    Context 'Overlap Detection' {
        It 'Returns Overlaps=true for identical IPs' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '192.168.1.1'
            $Result.Overlaps | Should -BeTrue
            $Result.Valid | Should -BeTrue
        }
        
        It 'Returns Overlaps=false for different IPs' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '192.168.1.2'
            $Result.Overlaps | Should -BeFalse
            $Result.Valid | Should -BeTrue
        }
        
        It 'Detects IP in CIDR range' {
            $Result = Test-CIPPIPOverlap -IP1 '192.168.1.100' -IP2 '192.168.1.0/24'
            $Result.Overlaps | Should -BeTrue
        }
        
        It 'Handles IPv4-mapped IPv6' {
            $Result = Test-CIPPIPOverlap -IP1 '::ffff:192.168.1.1' -IP2 '192.168.1.1'
            $Result.Overlaps | Should -BeTrue
        }
        
        It 'Returns Valid=false for unparseable IP' {
            $Result = Test-CIPPIPOverlap -IP1 '999.999.999.999' -IP2 '192.168.1.1'
            $Result.Valid | Should -BeFalse
        }
    }
}

Describe 'Handler Integration Tests (QA #3 - guards work in handlers)' {
    BeforeAll {
        Mock New-ExoRequest { , @() }
    }
    
    Context 'Template Validation via Guard' {
        It 'Guard allows clean IP for template validation' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck @('8.8.8.8')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Guard refuses relay IP for template validation (QA #1)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck @('3.19.206.53')
            $Result.IsValid | Should -BeFalse
            $Result.Reason | Should -Match 'relay'
        }
        
        It 'Guard refuses CIDR overlapping relay for template' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck @('3.19.206.0/24')
            $Result.IsValid | Should -BeFalse
        }
    }
}
