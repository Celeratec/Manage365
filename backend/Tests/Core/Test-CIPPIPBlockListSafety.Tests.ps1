BeforeAll {
    # QA's proven approach for Azure Functions types
    if (-not ('HttpStatusCode' -as [type])) {
        ([PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')).GetMethod('Add').Invoke($null, @('HttpStatusCode', [System.Net.HttpStatusCode]))
    }
    
    # HttpResponseContext as simple class
    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
    }
    
    # Set CIPPRootPath to backend root
    $BackendRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $env:CIPPRootPath = $BackendRoot
    
    # Import CIPPCore module - handler tests use real module, internal function tests use InModuleScope
    Import-Module "$BackendRoot/Modules/CIPPCore/CIPPCore.psd1" -Force -WarningAction SilentlyContinue 3>$null
    
    # Import handlers for integration tests
    $H = "$BackendRoot/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange"
    . "$H/Spamfilter/Invoke-AddTenantAllowBlockList.ps1"
    . "$H/Spamfilter/Invoke-AddTenantAllowBlockListTemplate.ps1"
    . "$H/Spamfilter/Invoke-EditTenantAllowBlockListTemplate.ps1"
    . "$H/Transport/Invoke-AddConnectionFilter.ps1"
    
    # Stub storage and helper functions (QA's approach)
    function Get-CippTable { @{} }
    function Add-CIPPAzDataTableEntity { $script:Saved++ }
    function Get-CIPPAzDataTableEntity { $script:TplEntity }
    function Update-CIPPAzDataTableEntity { $script:Updated++ }
    function Get-CippException { param($Exception) @{ NormalizedError = "$Exception" } }
    function ConvertTo-CIPPODataFilterValue { param($Value,$Type) $Value }
    function Get-NormalizedError { param($Message) $Message }
    function Get-Tenants { param($TriggerMetadata) @(@{defaultDomainName='contoso.onmicrosoft.com'; customerId='test-tenant-id'}) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Push-OutputBinding { param($Name, $Value) }
}

Describe 'Get-CIPPKnownMailRelayIPs' {
    Context 'Config file loading' {
        It 'Loads the real config file successfully' {
            InModuleScope CIPPCore {
                $IPs = Get-CIPPKnownMailRelayIPs
                $IPs | Should -Not -BeNullOrEmpty
                $IPs | Should -Contain '3.19.206.53'
                $IPs | Should -Contain '3.142.175.190'
            }
        }
        
        It 'Uses CIPPRootPath against real temp file (QA #3)' {
            InModuleScope CIPPCore {
                $TempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
                $ConfigDir = New-Item -ItemType Directory -Path (Join-Path $TempDir 'Config')
                $ConfigPath = Join-Path $ConfigDir 'KnownMailRelayIPs.json'
                '{"KnownMailRelayIPs":["203.0.113.99"]}' | Set-Content $ConfigPath
                
                $OrigPath = $env:CIPPRootPath
                $env:CIPPRootPath = $TempDir.FullName
                
                try {
                    $IPs = Get-CIPPKnownMailRelayIPs
                    $IPs | Should -Contain '203.0.113.99'
                } finally {
                    $env:CIPPRootPath = $OrigPath
                    Remove-Item $TempDir -Recurse -Force
                }
            }
        }
        
        It 'Throws when config file is missing' {
            InModuleScope CIPPCore {
                Mock Test-Path { $false } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
                { Get-CIPPKnownMailRelayIPs } | Should -Throw '*not found*'
            }
        }
        
        It 'Throws when config JSON is invalid' {
            InModuleScope CIPPCore {
                Mock Get-Content -ModuleName CIPPCore { '{invalid json' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
                { Get-CIPPKnownMailRelayIPs } | Should -Throw '*parse*'
            }
        }
        
        It 'Throws when config missing KnownMailRelayIPs property' {
            InModuleScope CIPPCore {
                Mock Get-Content -ModuleName CIPPCore { '{"OtherProperty":[]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
                { Get-CIPPKnownMailRelayIPs } | Should -Throw '*missing*'
            }
        }
        
        It 'Throws when relay list is empty (M14 - real empty array)' {
            InModuleScope CIPPCore {
                Mock Get-Content -ModuleName CIPPCore { '{"KnownMailRelayIPs":[]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
                { Get-CIPPKnownMailRelayIPs } | Should -Throw '*empty*'
            }
        }
        
        It 'Throws when config file is empty' {
            InModuleScope CIPPCore {
                Mock Get-Content -ModuleName CIPPCore { '' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
                { Get-CIPPKnownMailRelayIPs } | Should -Throw '*missing*'
            }
        }
        
        It 'Rejects IP that parses as 0.0.0.3 from input "3"' {
            InModuleScope CIPPCore {
                Mock Get-Content -ModuleName CIPPCore { '{"KnownMailRelayIPs":["3"]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
                { Get-CIPPKnownMailRelayIPs } | Should -Throw '*format*'
            }
        }
        
        It 'Throws when config contains invalid IP' {
            InModuleScope CIPPCore {
                Mock Get-Content -ModuleName CIPPCore { '{"KnownMailRelayIPs":["999.999.999.999"]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
                { Get-CIPPKnownMailRelayIPs } | Should -Throw '*Invalid IP*'
            }
        }
    }
}

Describe 'Test-CIPPIPBlockListSafety' {
    BeforeEach {
        Mock New-ExoRequest -ModuleName CIPPCore { , @() }
        Mock -ModuleName CIPPCore New-ExoRequest { , @() }
    }
    
    Context 'SkipConnectorCheck for Templates (Security R5 #1)' {
        It 'Template validation allows clean IP with -SkipConnectorCheck' {
            Mock New-ExoRequest -ModuleName CIPPCore { throw 'No such tenant' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck @('203.0.113.9') -SkipConnectorCheck
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Template validation refuses relay IP even with -SkipConnectorCheck' {
            Mock New-ExoRequest -ModuleName CIPPCore { throw 'No such tenant' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck @('3.19.206.53') -SkipConnectorCheck
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingRelay | Should -Be '3.19.206.53'
        }
    }
    
    Context 'No-Connector Scenarios (Security R4 #1)' {
        It 'Allows clean IP when connectors return $null' {
            Mock New-ExoRequest -ModuleName CIPPCore { return $null } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore { return $null } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Allows clean IP when connectors return @()' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('1.2.3.4')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Allows 49-char IPv6 CIDR when connectors return @()' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() }
            
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
        
        It 'Blocks both configured known relay IPs' {
            $Result1 = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.53')
            $Result2 = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.142.175.190')
            $Result1.IsValid | Should -BeFalse
            $Result2.IsValid | Should -BeFalse
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
        
        It 'Blocks IPv4-mapped IPv6 of known relay (::ffff:3.19.206.53)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('::ffff:3.19.206.53')
            $Result.IsValid | Should -BeFalse
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
        
        It 'Allows pure IPv6 ranges that do not overlap (QA #2 - kills M18)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('2001:db8::/32')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Allows IP that does not conflict with any source' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.100')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Allows multiple IPs when none conflict' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1', '198.51.100.2', '198.51.100.3')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Uses custom config with additional relay IP' {
            Mock Get-Content -ModuleName CIPPCore { '{"KnownMailRelayIPs":["10.99.88.77","3.19.206.53"]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.99.88.77')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingRelay | Should -Be '10.99.88.77'
        }
    }
    
    Context 'Inbound Connector Checks' {
        It 'Blocks IP that matches inbound connector' {
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestInbound'; SenderIPAddresses = @('198.51.100.5') })
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.5')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
        }
        
        It 'Blocks IP that matches inbound connector SenderIPAddress' {
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestInbound'; SenderIPAddresses = @('198.51.100.5') })
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.5')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Blocks CIDR overlapping with inbound connector' {
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestInbound'; SenderIPAddresses = @('198.51.100.10') })
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.0/24')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Blocks CIDR range that overlaps with inbound connector IP' {
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestInbound'; SenderIPAddresses = @('198.51.100.10') })
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.0/24')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Fails closed when inbound connector uses range notation (M15)' {
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestInbound'; SenderIPAddresses = @('198.51.100.1-198.51.100.10') })
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('8.8.8.8')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'InboundConnector'
            $Result.ConflictingIP | Should -Be '198.51.100.1-198.51.100.10'
        }
        
        It 'Allows IP when no inbound connectors exist' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Allows IP when tenant has no inbound connectors' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeTrue
        }
    }
    
    Context 'Outbound Connector Checks' {
        It 'Blocks IP matching outbound connector SmartHost' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestOutbound'; SmartHosts = @('198.51.100.20') })
            } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.20')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'OutboundConnector'
        }
        
        It 'Blocks IP that matches outbound connector SmartHost' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestOutbound'; SmartHosts = @('198.51.100.20') })
            } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.20')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Skips hostname SmartHosts' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestOutbound'; SmartHosts = @('mail.example.com') })
            } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.20')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Skips hostname SmartHosts (does not block)' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestOutbound'; SmartHosts = @('mail.example.com') })
            } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.20')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Blocks CIDR range that overlaps with outbound connector SmartHost' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(@{ Name = 'TestOutbound'; SmartHosts = @('198.51.100.25') })
            } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.0/24')
            $Result.IsValid | Should -BeFalse
        }
    }
    
    Context 'Fail Closed Behavior' {
        It 'Fails closed when inbound lookup throws' {
            Mock New-ExoRequest -ModuleName CIPPCore { throw 'Connection timeout' } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
        }
        
        It 'Fails closed when inbound connector lookup fails' {
            Mock New-ExoRequest -ModuleName CIPPCore { throw 'Connection timeout' } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Fails closed when outbound lookup throws' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore { throw 'Connection timeout' } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'ConnectorLookupFailure'
        }
        
        It 'Fails closed when outbound connector lookup fails' {
            Mock New-ExoRequest -ModuleName CIPPCore { , @() } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore { throw 'Connection timeout' } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Treats null connector result as no connectors' {
            Mock New-ExoRequest -ModuleName CIPPCore { return $null } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            Mock New-ExoRequest -ModuleName CIPPCore { return $null } -ParameterFilter { $cmdlet -eq 'Get-OutboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1')
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Fails closed on unexpected error (M13b)' {
            Mock Get-CIPPKnownMailRelayIPs -ModuleName CIPPCore { throw 'Unexpected database error' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('8.8.8.8')
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingSource | Should -Be 'UnexpectedError'
        }
        
        It 'Does not leak exception message to client (Security R4 #3)' {
            Mock Get-CIPPKnownMailRelayIPs -ModuleName CIPPCore { throw 'SECRET_DATABASE_CONNECTION_STRING' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('8.8.8.8')
            $Result.IsValid | Should -BeFalse
            $Result.Reason | Should -Not -Match 'SECRET_DATABASE_CONNECTION_STRING'
            $Result.Reason | Should -Be 'Unable to verify IP safety due to an unexpected error. The operation has been blocked as a safety precaution.'
        }
    }
    
    Context 'Input Validation' {
        It 'Handles comma-separated IP string' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('198.51.100.1, 198.51.100.2')
            $Result.IsValid | Should -BeTrue
        }
        
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
        
        It 'Rejects another leading-zero format' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('192.168.001.1')
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
        
        It 'Detects overlap when checking /24 against specific IP' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.0/24')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Detects overlap when checking specific IP against /24' {
            Mock Get-Content -ModuleName CIPPCore { '{"KnownMailRelayIPs":["3.19.206.0/24"]}' } -ParameterFilter { $Path -like '*KnownMailRelayIPs.json' }
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('3.19.206.53')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Detects overlap with 0.0.0.0/0' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('0.0.0.0/0')
            $Result.IsValid | Should -BeFalse
        }
        
        It 'Detects overlap between two CIDR ranges' {
            Mock New-ExoRequest -ModuleName CIPPCore {
                , @(
                    @{
                        Name              = 'TestInbound'
                        SenderIPAddresses = @('10.0.0.0/16')
                    }
                )
            } -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('10.0.5.0/24')
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
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '192.168.1.0/33' -IP2 '192.168.1.1'
                $Result.Valid | Should -BeFalse
                $Result.Error | Should -Be 'Unparseable IP or CIDR'
            }
        }
        
        It 'Rejects /-1 prefix' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '1.1.1.1/-1' -IP2 '1.1.1.1'
                $Result.Valid | Should -BeFalse
                $Result.Error | Should -Be 'Unparseable IP or CIDR'
            }
        }
        
        It 'Rejects /129 prefix on IPv6' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '2001:db8::/129' -IP2 '2001:db8::1'
                $Result.Valid | Should -BeFalse
                $Result.Error | Should -Be 'Unparseable IP or CIDR'
            }
        }
    }
    
    Context 'Overlap Detection' {
        It 'Returns Overlaps=true for identical IPs' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '192.168.1.1'
                $Result.Overlaps | Should -BeTrue
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Returns Overlaps=false for different IPs' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '192.168.1.2'
                $Result.Overlaps | Should -BeFalse
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Detects IP in CIDR range' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '192.168.1.100' -IP2 '192.168.1.0/24'
                $Result.Overlaps | Should -BeTrue
            }
        }
        
        It 'Handles IPv4-mapped IPv6' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '::ffff:192.168.1.1' -IP2 '192.168.1.1'
                $Result.Overlaps | Should -BeTrue
            }
        }
        
        It 'Returns Valid=false for unparseable IP' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '999.999.999.999' -IP2 '192.168.1.1'
                $Result.Valid | Should -BeFalse
            }
        }
        
        It 'Does not leak exception in Error (Security R5 #2)' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 'INTERNAL_SECRET_KEY' -IP2 '192.168.1.1'
                $Result.Valid | Should -BeFalse
                $Result.Error | Should -Be 'Unparseable IP or CIDR'
                $Result.Error | Should -Not -Match 'INTERNAL_SECRET_KEY'
            }
        }
        
        # Restored from original tests (deleted in 5d56f881d)
        It 'Returns Overlaps=false when IP is outside CIDR range' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '10.0.0.1' -IP2 '192.168.1.0/24'
                $Result.Overlaps | Should -BeFalse
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Returns Overlaps=true for overlapping CIDR ranges' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '10.0.0.0/16' -IP2 '10.0.5.0/24'
                $Result.Overlaps | Should -BeTrue
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Returns Overlaps=false for non-overlapping CIDR ranges' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '192.168.1.0/24' -IP2 '10.0.0.0/8'
                $Result.Overlaps | Should -BeFalse
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Handles /32 CIDR notation' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1/32' -IP2 '192.168.1.1'
                $Result.Overlaps | Should -BeTrue
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Returns Overlaps=true for identical IPv6 addresses' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '2001:db8::1' -IP2 '2001:db8::1'
                $Result.Overlaps | Should -BeTrue
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Returns Overlaps=false for different IPv6 addresses' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '2001:db8::1' -IP2 '2001:db8::2'
                $Result.Overlaps | Should -BeFalse
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Returns Overlaps=true when IPv6 is in CIDR range' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '2001:db8::100' -IP2 '2001:db8::/64'
                $Result.Overlaps | Should -BeTrue
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Returns Overlaps=false for IPv4 vs IPv6' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '192.168.1.1' -IP2 '2001:db8::1'
                $Result.Overlaps | Should -BeFalse
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Handles IPv4-mapped IPv6 addresses (::ffff:192.168.1.1)' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '::ffff:192.168.1.1' -IP2 '::ffff:192.168.1.1'
                $Result.Overlaps | Should -BeTrue
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Handles IPv4-mapped IPv6 against CIDR' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '::ffff:192.168.1.10' -IP2 '192.168.1.0/24'
                $Result.Overlaps | Should -BeTrue
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Handles /0 CIDR (matches all)' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 '0.0.0.0/0' -IP2 '192.168.1.1'
                $Result.Overlaps | Should -BeTrue
                $Result.Valid | Should -BeTrue
            }
        }
        
        It 'Returns Valid=false for invalid IP' {
            InModuleScope CIPPCore {
                $Result = Test-CIPPIPOverlap -IP1 'not-an-ip' -IP2 '192.168.1.1'
                $Result.Valid | Should -BeFalse
            }
        }
    }
}

Describe 'Handler Integration Tests (QA #1 - real handler invocations)' {
    BeforeEach {
        $script:Saved = 0
        $script:Updated = 0
        $script:Adds = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName CIPPCore New-ExoRequest { if ($cmdlet -and $cmdlet -notlike 'Get-*') { $script:Adds.Add(@($tenantid,$cmdlet)) } ; , @() }
        Mock New-ExoRequest { if ($cmdlet -and $cmdlet -notlike 'Get-*') { $script:Adds.Add(@($tenantid,$cmdlet)) } ; , @() }
        Mock Write-LogMessage { }
        Mock -ModuleName CIPPCore Write-LogMessage { }
    }
    
    Context 'Invoke-AddTenantAllowBlockListTemplate' {
        It 'Returns 200 and saves for clean IP (8.8.8.8)' {
            $Request = @{
                body = [pscustomobject]@{
                    entries = '8.8.8.8'
                    listMethod = 'Block'
                    listType = 'IP'
                    templateName = 'CleanTest'
                    notes = 'Test'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 200
            $script:Saved | Should -Be 1
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
        
        It 'Returns 400 and does not save for relay IP 3.19.206.53' {
            $Request = @{
                body = [pscustomobject]@{
                    entries = '3.19.206.53'
                    listMethod = 'Block'
                    listType = 'IP'
                    templateName = 'RelayTest'
                    notes = 'Test'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 400
            $Result.Body.Results | Should -Match 'overlaps'
            $script:Saved | Should -Be 0
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
        
        It 'Returns 400 and does not save for 3.19.206.0/24' {
            $Request = @{
                body = [pscustomobject]@{
                    entries = '3.19.206.0/24'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 400
            $script:Saved | Should -Be 0
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
        
        It 'Returns 400 and does not save for ::ffff:3.19.206.53' {
            $Request = @{
                body = [pscustomobject]@{
                    entries = '::ffff:3.19.206.53'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 400
            $script:Saved | Should -Be 0
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
        
        It 'Returns 400 and does not save for invalid input' {
            $Request = @{
                body = [pscustomobject]@{
                    entries = 'not-an-ip'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 400
            $script:Saved | Should -Be 0
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
    }
    
    Context 'Invoke-EditTenantAllowBlockListTemplate' {
        It 'Returns 200 and saves for clean IP' {
            $script:TplEntity = @{ RowKey='test-guid' }
            $Request = @{
                body = [pscustomobject]@{
                    GUID = 'test-guid'
                    entries = '8.8.8.8'
                    listMethod = 'Block'
                    listType = 'IP'
                    templateName = 'EditTest'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-EditTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 200
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
        
        It 'Returns 400 and does not save for relay IP (3.142.175.190)' {
            $script:TplEntity = @{ RowKey='test-guid' }
            $Request = @{
                body = [pscustomobject]@{
                    GUID = 'test-guid'
                    entries = '3.142.175.190'
                    listMethod = 'Block'
                    listType = 'IP'
                    templateName = 'EditRelay'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-EditTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 400
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
        
        It 'Returns 400 for ::ffff:3.19.206.53' {
            $script:TplEntity = @{ RowKey='test-guid' }
            $Request = @{
                body = [pscustomobject]@{
                    GUID = 'test-guid'
                    entries = '::ffff:3.19.206.53'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-EditTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 400
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
        
        It 'Returns 400 for relay CIDR 3.19.206.0/24' {
            $script:TplEntity = @{ RowKey='test-guid' }
            $Request = @{
                body = [pscustomobject]@{
                    GUID = 'test-guid'
                    entries = '3.19.206.0/24'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-EditTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 400
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
        
        It 'Returns 400 for invalid input' {
            $script:TplEntity = @{ RowKey='test-guid' }
            $Request = @{
                body = [pscustomobject]@{
                    GUID = 'test-guid'
                    entries = 'invalid-ip'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-EditTenantAllowBlockListTemplate -Request $Request
            [int]$Result.StatusCode | Should -Be 400
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 0 -Exactly
        }
    }
    
    Context 'Invoke-AddTenantAllowBlockList' {
        It 'Returns 200 for clean IP (8.8.8.8)' {
            $Request = @{
                body = [pscustomobject]@{
                    tenantID = 'contoso.onmicrosoft.com'
                    entries = '8.8.8.8'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockList -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 200
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 1 -Exactly
        }
        
        It 'Returns 400 for relay IP 3.19.206.53' {
            $Request = @{
                body = [pscustomobject]@{
                    tenantID = 'contoso.onmicrosoft.com'
                    entries = '3.19.206.53'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockList -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 400
            $script:Adds.Count | Should -Be 0
        }
        
        It 'Returns 400 for 3.19.206.0/24' {
            $Request = @{
                body = [pscustomobject]@{
                    tenantID = 'contoso.onmicrosoft.com'
                    entries = '3.19.206.0/24'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockList -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 400
        }
        
        It 'Returns 400 for IPv6-wrapped relay ::ffff:3.19.206.53' {
            $Request = @{
                body = [pscustomobject]@{
                    tenantID = 'contoso.onmicrosoft.com'
                    entries = '::ffff:3.19.206.53'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockList -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 400
        }
        
        It 'Returns 400 for invalid input' {
            $Request = @{
                body = [pscustomobject]@{
                    tenantID = 'contoso.onmicrosoft.com'
                    entries = 'invalid-ip'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockList -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 400
        }
    }
    
    Context 'Invoke-AddConnectionFilter' {
        It 'Returns 200 for clean IP' {
            $Request = @{
                body = [pscustomobject]@{
                    selectedTenants = @(@{value='contoso.onmicrosoft.com'})
                    PowerShellCommand = (@{name='Default';IPBlockList='8.8.8.8'}|ConvertTo-Json)
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddConnectionFilter -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -BeIn @(200, 207)
            Should -Invoke -ModuleName CIPPCore New-ExoRequest -ParameterFilter { $cmdlet -eq 'Get-InboundConnector' } -Times 1 -Exactly
        }
        
        It 'Returns 400 for relay IP in IPBlockList' {
            $Request = @{
                body = [pscustomobject]@{
                    selectedTenants = @(@{value='contoso.onmicrosoft.com'})
                    PowerShellCommand = (@{name='Default';IPBlockList='3.19.206.53'}|ConvertTo-Json)
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddConnectionFilter -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 400
            @($script:Adds | ? { $_[1] -eq 'Set-HostedConnectionFilterPolicy' }).Count | Should -Be 0
        }
        
        It 'Returns 400 for 3.19.206.0/24' {
            $Request = @{
                body = [pscustomobject]@{
                    selectedTenants = @(@{value='contoso.onmicrosoft.com'})
                    PowerShellCommand = (@{name='Default';IPBlockList='3.19.206.0/24'}|ConvertTo-Json)
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddConnectionFilter -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 400
        }
        
        It 'Returns 400 for IPv6-wrapped relay ::ffff:3.19.206.53' {
            $Request = @{
                body = [pscustomobject]@{
                    selectedTenants = @(@{value='contoso.onmicrosoft.com'})
                    PowerShellCommand = (@{name='Default';IPBlockList='::ffff:3.19.206.53'}|ConvertTo-Json)
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddConnectionFilter -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 400
        }
        
        It 'Returns 400 for invalid input' {
            $Request = @{
                body = [pscustomobject]@{
                    selectedTenants = @(@{value='contoso.onmicrosoft.com'})
                    PowerShellCommand = (@{name='Default';IPBlockList='not-ip'}|ConvertTo-Json)
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddConnectionFilter -Request $Request -TriggerMetadata @{}
            [int]$Result.StatusCode | Should -Be 400
        }
    }
}

Describe 'New-ExoRequest Signature (Security R5 #3 - real AST parsing)' {
    It 'Real New-ExoRequest.ps1 has correct parameters' {
        $RealPath = Join-Path $BackendRoot 'Modules/CIPPCore/Public/GraphHelper/New-ExoRequest.ps1'
        $AST = [System.Management.Automation.Language.Parser]::ParseFile($RealPath, [ref]$null, [ref]$null)
        $ParamAsts = $AST.FindAll({$args[0] -is [System.Management.Automation.Language.ParameterAst]}, $true)
        $ParamNames = $ParamAsts.Name.VariablePath.UserPath
        
        $ParamNames | Should -Contain 'tenantid'
        $ParamNames | Should -Contain 'cmdlet'
        $ParamNames | Should -Contain 'cmdParams'
    }
}
