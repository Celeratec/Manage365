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
        
        It 'Uses CIPPRootPath against real temp file (QA #3)' {
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
    
    Context 'SkipConnectorCheck for Templates (Security R5 #1)' {
        It 'Template validation allows clean IP with -SkipConnectorCheck' {
            Mock New-ExoRequest { throw 'No such tenant' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck @('203.0.113.9') -SkipConnectorCheck
            $Result.IsValid | Should -BeTrue
        }
        
        It 'Template validation refuses relay IP even with -SkipConnectorCheck' {
            Mock New-ExoRequest { throw 'No such tenant' }
            
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck @('3.19.206.53') -SkipConnectorCheck
            $Result.IsValid | Should -BeFalse
            $Result.ConflictingRelay | Should -Be '3.19.206.53'
        }
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
        
        It 'Allows pure IPv6 ranges that do not overlap (QA #2 - kills M18)' {
            $Result = Test-CIPPIPBlockListSafety -TenantFilter 'contoso.onmicrosoft.com' -IPsToCheck @('2001:db8::/32')
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
            $Result.Error | Should -Be 'Unparseable IP or CIDR'
        }
        
        It 'Rejects /-1 prefix' {
            $Result = Test-CIPPIPOverlap -IP1 '1.1.1.1/-1' -IP2 '1.1.1.1'
            $Result.Valid | Should -BeFalse
            $Result.Error | Should -Be 'Unparseable IP or CIDR'
        }
        
        It 'Rejects /129 prefix on IPv6' {
            $Result = Test-CIPPIPOverlap -IP1 '2001:db8::/129' -IP2 '2001:db8::1'
            $Result.Valid | Should -BeFalse
            $Result.Error | Should -Be 'Unparseable IP or CIDR'
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
        
        It 'Does not leak exception in Error (Security R5 #2)' {
            $Result = Test-CIPPIPOverlap -IP1 'INTERNAL_SECRET_KEY' -IP2 '192.168.1.1'
            $Result.Valid | Should -BeFalse
            $Result.Error | Should -Be 'Unparseable IP or CIDR'
            $Result.Error | Should -Not -Match 'INTERNAL_SECRET_KEY'
        }
    }
}

Describe 'Template guard tests (QA #1 - renamed)' {
    Context 'Template Handler Guard Calls' {
        BeforeEach {
            Mock New-ExoRequest { throw 'Tenant not found: template-validation' }
        }
        
        It 'Template guard allows clean IP with -SkipConnectorCheck (Add handler flow)' {
            $Entries = @('203.0.113.9')
            $SafetyCheck = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck $Entries -SkipConnectorCheck
            $SafetyCheck.IsValid | Should -BeTrue
        }
        
        It 'Template guard refuses relay IP with -SkipConnectorCheck (Add handler flow)' {
            $Entries = @('3.19.206.53')
            $SafetyCheck = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck $Entries -SkipConnectorCheck
            $SafetyCheck.IsValid | Should -BeFalse
            $SafetyCheck.ConflictingRelay | Should -Be '3.19.206.53'
        }
        
        It 'Template guard allows clean IP with -SkipConnectorCheck (Edit handler flow)' {
            $Entries = @('203.0.113.10')
            $SafetyCheck = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck $Entries -SkipConnectorCheck
            $SafetyCheck.IsValid | Should -BeTrue
        }
        
        It 'Template guard refuses second relay IP with -SkipConnectorCheck (Edit handler flow)' {
            $Entries = @('3.142.175.190')
            $SafetyCheck = Test-CIPPIPBlockListSafety -TenantFilter 'template-validation' -IPsToCheck $Entries -SkipConnectorCheck
            $SafetyCheck.IsValid | Should -BeFalse
            $SafetyCheck.ConflictingRelay | Should -Be '3.142.175.190'
        }
    }
}

Describe 'Handler Integration Tests (QA #1 - real handler invocations)' {
    BeforeAll {
        # Add Azure Functions types as stubs
        if (-not ('HttpStatusCode' -as [type])) {
            Add-Type -TypeDefinition @'
                public enum HttpStatusCode {
                    OK = 200,
                    BadRequest = 400,
                    MultiStatus = 207
                }
'@
        }
        
        if (-not ('HttpResponseContext' -as [type])) {
            Add-Type -TypeDefinition @'
                public class HttpResponseContext {
                    public int StatusCode { get; set; }
                    public object Body { get; set; }
                }
'@
        }
        
        # Import actual handlers and dependencies
        . (Join-Path $BackendRoot 'Modules/CIPPCore/Public/GraphHelper/Get-NormalizedError.ps1')
        . (Join-Path $BackendRoot 'Modules/CIPPCore/Public/GraphHelper/Get-CippException.ps1')
        . (Join-Path $BackendRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-AddTenantAllowBlockListTemplate.ps1')
        . (Join-Path $BackendRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-EditTenantAllowBlockListTemplate.ps1')
    }
    
    BeforeEach {
        # Stub external I/O (scoped for each test)
        Mock Write-LogMessage {}
        Mock Get-CippTable { @{} }
        Mock Add-CIPPAzDataTableEntity {}
        Mock Get-CIPPAzDataTableEntity { 
            @{
                GUID='test-guid'
                listMethod='Block'
                listType='IP'
                PartitionKey='TenantAllowBlockListTemplate'
                RowKey='test-guid'
                entries='old-entry'
                templateName='Test'
            }
        }
        Mock Update-CIPPAzDataTableEntity {}
        Mock New-ExoRequest { , @() }
    }
    
    Context 'Invoke-AddTenantAllowBlockListTemplate' {
        It 'Returns 200 and saves for clean IP' {
            $Request = @{
                body = @{
                    entries = '203.0.113.9'
                    listMethod = 'Block'
                    listType = 'IP'
                    templateName = 'CleanTest'
                    notes = 'Test'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            $Result.StatusCode | Should -Be 200
            $Result.body | Should -Not -BeNullOrEmpty
        }
        
        It 'Returns 400 and does not save for relay IP 3.19.206.53' {
            Mock Add-CIPPAzDataTableEntity { throw 'Should not save' }
            
            $Request = @{
                body = @{
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
            $Result.StatusCode | Should -Be 400
            $Result.body.Results | Should -Match 'relay|mail'
        }
        
        It 'Returns 400 and does not save for 3.19.206.0/24' {
            Mock Add-CIPPAzDataTableEntity { throw 'Should not save' }
            
            $Request = @{
                body = @{
                    entries = '3.19.206.0/24'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            $Result.StatusCode | Should -Be 400
        }
        
        It 'Returns 400 and does not save for ::ffff:3.19.206.53' {
            Mock Add-CIPPAzDataTableEntity { throw 'Should not save' }
            
            $Request = @{
                body = @{
                    entries = '::ffff:3.19.206.53'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            $Result.StatusCode | Should -Be 400
        }
        
        It 'Returns 400 and does not save for invalid input' {
            Mock Add-CIPPAzDataTableEntity { throw 'Should not save' }
            
            $Request = @{
                body = @{
                    entries = 'not-an-ip'
                    listMethod = 'Block'
                    listType = 'IP'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-AddTenantAllowBlockListTemplate -Request $Request
            $Result.StatusCode | Should -Be 400
        }
    }
    
    Context 'Invoke-EditTenantAllowBlockListTemplate' {
        It 'Returns 200 and saves for clean IP' {
            $Request = @{
                body = @{
                    GUID = 'test-guid'
                    entries = '203.0.113.10'
                    listMethod = 'Block'
                    listType = 'IP'
                    templateName = 'EditTest'
                }
                Params = @{ CIPPEndpoint = 'Test' }
                Headers = @{}
            }
            
            $Result = Invoke-EditTenantAllowBlockListTemplate -Request $Request
            $Result.StatusCode | Should -Be 200
        }
        
        It 'Returns 400 and does not save for relay IP' {
            Mock Update-CIPPAzDataTableEntity { throw 'Should not save' }
            
            $Request = @{
                body = @{
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
            $Result.StatusCode | Should -Be 400
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
