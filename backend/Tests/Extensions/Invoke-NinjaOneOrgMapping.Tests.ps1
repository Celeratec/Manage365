BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    Add-Type -Path (Join-Path $RepoRoot 'Shared/CIPPSharp/bin/CIPPSharp.dll')

    function Get-CIPPTable { param($TableName) @{} }
    function Get-CIPPAzDataTableEntity {
        # Returns config for Extensionsconfig table
        [pscustomobject]@{ config = (@{ NinjaOne = @{ Instance = 'ninja.example.com' } } | ConvertTo-Json -Compress) }
    }
    function Get-AzDataTableEntity {
        param($Filter, $Table)
        if ($Filter -like '*NinjaOneMapping*') {
            # Already tenant (t1) has an existing mapping to org 1
            @([pscustomobject]@{ RowKey = 't1'; IntegrationId = '1'; IntegrationName = 'Already' })
        } else {
            [pscustomobject]@{ config = (@{ NinjaOne = @{ Instance = 'ninja.example.com' } } | ConvertTo-Json -Compress) }
        }
    }
    function Add-AzDataTableEntity { param($Entity, [switch]$Force) $script:Added.Add($Entity) }
    function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) $script:Added.Add($Entity) }
    function Get-NinjaOneToken { param($configuration) @{ access_token = 'token' } }
    function Write-LogMessage { param($API, $tenant, $message, $Sev) }
    function Start-CIPPOrchestrator { param($InputObject) "Craft-$($InputObject.OrchestratorName)" }
    function Get-ExtensionMapping { param($Extension) @([pscustomobject]@{ RowKey = 't1'; IntegrationId = '1' }) }
    function Get-Tenants {
        param([switch]$IncludeErrors)
        foreach ($Name in 'Already', 'Contoso', 'Fabrikam', 'Tied', 'Taken', 'DupSerial', 'Broken', 'NameOnly') {
            [pscustomobject]@{ customerId = "t$($script:TenantIds[$Name])"; displayName = $Name; defaultDomainName = "$Name.test".ToLower() }
        }
    }
    function Get-CIPPDbItem {
        param($TenantFilter, $Type)
        if ($TenantFilter -eq 'broken.test') { throw "Tenant '$TenantFilter' not found" }
        [pscustomobject]@{ RowKey = 'ManagedDevices-Count'; Data = '{}' }
        foreach ($Device in $script:IntuneDevices[$TenantFilter]) {
            [pscustomobject]@{ RowKey = [guid]::NewGuid().ToString(); Data = ($Device | ConvertTo-Json -Compress) }
        }
    }
    function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) $script:Added.Add($Entity) }

    . (Join-Path $RepoRoot 'Modules/CippExtensions/Public/NinjaOne/Invoke-NinjaOneOrgMapping.ps1')

    $script:TenantIds = @{ Already = 1; Contoso = 2; Fabrikam = 3; Tied = 4; Taken = 5; DupSerial = 6; NameOnly = 7; Broken = 8 }
    $script:Orgs = @(1..7 | ForEach-Object { @{ id = $_; name = @{ 1 = 'Already'; 2 = 'Contoso'; 3 = 'Fabrikam Pty Ltd'; 4 = 'Other'; 5 = 'Tied A'; 6 = 'Tied B'; 7 = 'Name Only Org' }[$_] } })
    $script:NinjaDevices = @(
        @{ id = 1; organizationId = 3; systemName = 'FAB-1'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'S1' } }
        @{ id = 2; organizationId = 3; systemName = 'FAB-2'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'S2' } }
        @{ id = 3; organizationId = 4; systemName = 'PC-X'; nodeClass = 'MAC'; system = @{ serialNumber = 'SX' } }
        @{ id = 4; organizationId = 5; systemName = 'TIE-A'; nodeClass = 'WINDOWS_SERVER'; system = @{ serialNumber = 'S3' } }
        @{ id = 5; organizationId = 6; systemName = 'TIE-B'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'S4' } }
        @{ id = 6; organizationId = 1; systemName = 'TAKEN'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'S5' } }
        @{ id = 7; organizationId = 5; systemName = 'DUP-A'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'DUP' } }
        @{ id = 8; organizationId = 6; systemName = 'DUP-B'; nodeClass = 'MAC'; system = @{ serialNumber = 'DUP' } }
        @{ id = 9; organizationId = 7; systemName = 'NAMEPC'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'To Be Filled By O.E.M.' } }
        @{ id = 10; organizationId = 7; systemName = 'NAMEPC2'; nodeClass = 'MAC'; system = @{ serialNumber = 'To Be Filled By O.E.M.' } }
    )
    $script:IntuneDevices = @{
        'fabrikam.test'  = @(@{ deviceName = 'a'; serialNumber = 'S1' }, @{ deviceName = 'b'; serialNumber = 'S2' }, @{ deviceName = 'PC-X'; serialNumber = 'nope' })
        'tied.test'      = @(@{ deviceName = 'a'; serialNumber = 'S3' }, @{ deviceName = 'b'; serialNumber = 'S4' })
        'taken.test'     = @(@{ deviceName = 'a'; serialNumber = 'S5' })
        'dupserial.test' = @(@{ deviceName = 'a'; serialNumber = 'DUP' })
        'nameonly.test'  = @(@{ deviceName = 'NAMEPC'; serialNumber = 'To Be Filled By O.E.M.' }, @{ deviceName = 'NAMEPC2'; serialNumber = 'To Be Filled By O.E.M.' })
    }
}

Describe 'Invoke-NinjaOneOrgMapping' {
    BeforeAll {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-WebRequest {
            $Data = if ($Uri -like '*/organizations?*') { $script:Orgs } else { $script:NinjaDevices }
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($Data) -Depth 5 -Compress) }
        }
        $script:Result = Invoke-NinjaOneOrgMapping
        $script:ByTenant = @{}
        foreach ($Row in $script:Added) { $script:ByTenant[$Row.RowKey] = $Row.IntegrationId }
    }

    It 'maps an exact organization name match' {
        $script:ByTenant['t2'] | Should -Be '2'
    }

    It 'maps by the organization owning most of the tenant devices' {
        $script:ByTenant['t3'] | Should -Be '3'
    }

    It 'falls back to device name when the serial is excluded' {
        $script:ByTenant['t7'] | Should -Be '7'
    }

    It 'skips ties, serials shared across organizations, organizations already mapped and unreadable caches' {
        $script:ByTenant.Keys | Should -Not -Contain 't4'
        $script:ByTenant.Keys | Should -Not -Contain 't5'
        $script:ByTenant.Keys | Should -Not -Contain 't6'
        $script:ByTenant.Keys | Should -Not -Contain 't8'
    }

    It 'never rewrites an existing mapping' {
        $script:ByTenant.Keys | Should -Not -Contain 't1'
        $script:Added.Count | Should -Be 3
        $script:Result | Should -BeLike '*3 new tenant mapping*'
    }
}

Describe 'Invoke-NinjaOneOrgMapping -NameOnly' {
    BeforeAll {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-WebRequest {
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($script:Orgs) -Depth 5 -Compress) }
        }
        Invoke-NinjaOneOrgMapping -NameOnly
    }

    It 'maps by organization name without downloading devices' {
        @($script:Added.RowKey) | Should -Be @('t2')
        Should -Invoke Invoke-WebRequest -Times 0 -ParameterFilter { $Uri -like '*/devices-detailed?*' }
    }
}

Describe 'Invoke-NinjaOneOrgMapping device matching thresholds' {
    BeforeAll {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        # Tenant with only 1 device match (below minimum of 2)
        $script:IntuneDevices = @{
            'single.test' = @(@{ deviceName = 'PC-1'; serialNumber = 'S1' })
            'majority.test' = @(
                @{ deviceName = 'MAJ-1'; serialNumber = 'M1' }
                @{ deviceName = 'MAJ-2'; serialNumber = 'M2' }
                @{ deviceName = 'MAJ-3'; serialNumber = 'M3' }
            )
        }
        $script:Orgs = @(
            @{ id = 10; name = 'Single Org' }
            @{ id = 11; name = 'Majority Org' }
        )
        $script:NinjaDevices = @(
            @{ id = 100; organizationId = 10; systemName = 'PC-1'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'S1' } }
            @{ id = 101; organizationId = 11; systemName = 'MAJ-1'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'M1' } }
            @{ id = 102; organizationId = 11; systemName = 'MAJ-2'; nodeClass = 'MAC'; system = @{ serialNumber = 'M2' } }
        )
        $script:TenantIds = @{ Single = 10; Majority = 11 }
        $script:Tenants = @(
            [pscustomobject]@{ customerId = 't10'; displayName = 'Single'; defaultDomainName = 'single.test' }
            [pscustomobject]@{ customerId = 't11'; displayName = 'Majority'; defaultDomainName = 'majority.test' }
        )
        Mock Invoke-WebRequest {
            $Data = if ($Uri -like '*/organizations?*') { $script:Orgs } else { $script:NinjaDevices }
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($Data) -Depth 5 -Compress) }
        }
        Mock Get-Tenants { param([switch]$IncludeErrors) $script:Tenants }
        Invoke-NinjaOneOrgMapping
        $script:ByTenant = @{}
        foreach ($Row in $script:Added) { $script:ByTenant[$Row.RowKey] = $Row.IntegrationId }
    }

    It 'skips tenant with only 1 device match (below minimum of 2)' {
        $script:ByTenant.Keys | Should -Not -Contain 't10'
    }

    It 'maps tenant with majority of devices matching (2 out of 3)' {
        $script:ByTenant['t11'] | Should -Be '11'
    }
}


Describe 'Invoke-NinjaOneOrgMapping mobile OS exclusion' {
    BeforeAll {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        $script:IntuneDevices = @{
            'mobile.test' = @(
                @{ deviceName = 'WIN-PC'; serialNumber = 'W1'; operatingSystem = 'Windows' }
                @{ deviceName = 'MAC-1'; serialNumber = 'M1'; operatingSystem = 'macOS' }
                @{ deviceName = 'iPhone'; serialNumber = 'I1'; operatingSystem = 'iOS' }
                @{ deviceName = 'iPad'; serialNumber = 'P1'; operatingSystem = 'iPadOS' }
                @{ deviceName = 'Android'; serialNumber = 'A1'; operatingSystem = 'Android' }
            )
        }
        $script:Orgs = @(@{ id = 30; name = 'Mobile Test Org' })
        $script:NinjaDevices = @(
            @{ id = 300; organizationId = 30; systemName = 'WIN-PC'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'W1' } }
            @{ id = 301; organizationId = 30; systemName = 'MAC-1'; nodeClass = 'MAC'; system = @{ serialNumber = 'M1' } }
        )
        Mock Invoke-WebRequest {
            $Data = if ($Uri -like '*/organizations?*') { $script:Orgs } else { $script:NinjaDevices }
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($Data) -Depth 5 -Compress) }
        }
        Mock Get-Tenants {
            @([pscustomobject]@{ customerId = 't30'; displayName = 'Mobile Test'; defaultDomainName = 'mobile.test' })
        }
        Invoke-NinjaOneOrgMapping
        $script:ByTenant = @{}
        foreach ($Row in $script:Added) { $script:ByTenant[$Row.RowKey] = $Row.IntegrationId }
    }

    It 'excludes iOS, iPadOS, and Android from device total, keeping only Windows and macOS' {
        # Should match: 2 devices (Windows, macOS) out of 2 counted = 100% match
        # Would NOT match if all 5 devices were counted: 2 out of 5 = 40% < 50%
        $script:ByTenant['t30'] | Should -Be '30' -Because 'iOS, iPadOS, and Android are excluded from majority calculation'
    }
}

Describe 'Invoke-NinjaOneOrgMapping 429 retry and page cap' {
    It 'retries once after 429 rate limit with capped sleep' {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        $script:DeviceCallCount = 0
        $script:SleepCalled = $false
        $script:SleepSeconds = 0
        
        Mock Invoke-WebRequest {
            if ($Uri -like '*/devices-detailed?*') {
                $script:DeviceCallCount++
                if ($script:DeviceCallCount -eq 1) {
                    # First call: simulate 429 with proper exception structure
                    # Create Headers as a dictionary that supports indexer access
                    $Headers = @{
                        'Retry-After' = '2'  # Seconds format
                    }
                    $Response = [PSCustomObject]@{
                        StatusCode = 429
                        Headers = $Headers
                    }
                    # Create exception with nested Response property
                    $InnerException = [System.Exception]::new('429 Too Many Requests')
                    $InnerException | Add-Member -NotePropertyName Response -NotePropertyValue $Response -Force
                    
                    $OuterException = [System.Exception]::new('The remote server returned an error: (429) Too Many Requests.', $InnerException)
                    $OuterException | Add-Member -NotePropertyName Response -NotePropertyValue $Response -Force
                    
                    # Create error record
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $OuterException,
                        'WebException',
                        [System.Management.Automation.ErrorCategory]::InvalidOperation,
                        $null
                    )
                    throw $ErrorRecord
                }
                # Second call: succeed
                $Devices = @(@{ id = 1; organizationId = 1; systemName = 'PC'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'S1' } })
                return [pscustomobject]@{ content = (ConvertTo-Json -InputObject $Devices -Depth 5 -Compress) }
            } else {
                # Organizations
                return [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($script:Orgs) -Depth 5 -Compress) }
            }
        }
        
        Mock Start-Sleep {
            param($Seconds)
            $script:SleepCalled = $true
            $script:SleepSeconds = $Seconds
        }
        # Return a tenant that won't match by name, forcing device matching
        Mock Get-Tenants {
            @([pscustomobject]@{ customerId = 't99'; displayName = 'RateLimitTest'; defaultDomainName = 'ratelimit.test' })
        }
        Mock Get-CIPPDbItem {
            # Return a device to trigger device matching logic
            @([pscustomobject]@{ RowKey = 'dev1'; Data = '{"deviceName":"PC","serialNumber":"S1"}' })
        }
        
        Invoke-NinjaOneOrgMapping
        
        # Verify retry happened: device endpoint was called twice and sleep was called with correct duration
        $script:DeviceCallCount | Should -Be 2
        $script:SleepCalled | Should -BeTrue
        $script:SleepSeconds | Should -Be 2
    }

    It 'retries with HttpResponseMessage-style headers (production form)' {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        $script:DeviceCallCount = 0
        $script:SleepSeconds = 0
        
        Mock Invoke-WebRequest {
            if ($Uri -like '*/devices-detailed?*') {
                $script:DeviceCallCount++
                if ($script:DeviceCallCount -eq 1) {
                    # Use a real HttpResponseMessage with RetryAfter header
                    $HttpResponse = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                    $HttpResponse.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([TimeSpan]::FromSeconds(3))
                    
                    $Response = [PSCustomObject]@{
                        StatusCode = 429
                        Headers = $HttpResponse.Headers
                    }
                    $InnerException = [System.Exception]::new('429 Too Many Requests')
                    $InnerException | Add-Member -NotePropertyName Response -NotePropertyValue $Response -Force
                    $OuterException = [System.Exception]::new('Too Many Requests', $InnerException)
                    $OuterException | Add-Member -NotePropertyName Response -NotePropertyValue $Response -Force
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $OuterException, 'WebException', [System.Management.Automation.ErrorCategory]::InvalidOperation, $null
                    )
                    $HttpResponse.Dispose()
                    throw $ErrorRecord
                }
                $Devices = @(@{ id = 1; organizationId = 1; systemName = 'PC'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'S1' } })
                return [pscustomobject]@{ content = (ConvertTo-Json -InputObject $Devices -Depth 5 -Compress) }
            } else {
                return [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($script:Orgs) -Depth 5 -Compress) }
            }
        }
        Mock Start-Sleep { param($Seconds); $script:SleepSeconds = $Seconds }
        Mock Get-Tenants { @([pscustomobject]@{ customerId = 't99'; displayName = 'HttpHeaderTest'; defaultDomainName = 'httpheader.test' }) }
        Mock Get-CIPPDbItem { @([pscustomobject]@{ RowKey = 'dev1'; Data = '{"deviceName":"PC","serialNumber":"S1"}' }) }
        
        Invoke-NinjaOneOrgMapping
        
        $script:DeviceCallCount | Should -Be 2 -Because 'HttpResponseHeaders.RetryAfter.Delta should be parsed'
        $script:SleepSeconds | Should -Be 3
    }

    It 'stops fetching devices after 50 pages and skips device matching when last page is full' {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        $script:PageCount = 0
        Mock Invoke-WebRequest {
            $script:PageCount++
            # Return full page of results to trigger continuation, devices in unmapped org 999
            $Devices = @(1..1000 | ForEach-Object { @{ id = ($script:PageCount - 1) * 1000 + $_; organizationId = 999; systemName = "PC$_"; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = "S$_" } } })
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject $Devices -Depth 5 -Compress) }
        } -ParameterFilter { $Uri -like '*/devices-detailed?*' }
        Mock Invoke-WebRequest {
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($script:Orgs) -Depth 5 -Compress) }
        } -ParameterFilter { $Uri -like '*/organizations?*' }
        Mock Get-Tenants {
            @([pscustomobject]@{ customerId = 't99'; displayName = 'PageCapTest'; defaultDomainName = 'pagecap.test' })
        }
        Mock Get-CIPPDbItem {
            # Return 2+ devices that would match if org 999 were mapped - proves skip logic triggered, not just no match
            @(
                [pscustomobject]@{ RowKey = 'dev1'; Data = '{"deviceName":"PC1","serialNumber":"S1"}' }
                [pscustomobject]@{ RowKey = 'dev2'; Data = '{"deviceName":"PC2","serialNumber":"S2"}' }
            )
        }
        $Result = Invoke-NinjaOneOrgMapping
        $script:PageCount | Should -Be 50
        # No device mapping should have been written because of partial data (even though 2 devices would have matched)
        $script:Added.Count | Should -Be 0 -Because 'partial data skips device matching even when devices would match'
        $Result | Should -BeLike '*device matching skipped*'
    }

    It 'treats Retry-After=0 as 0 seconds, not as missing' {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        $script:DeviceCallCount = 0
        $script:SleepSeconds = -1
        
        Mock Invoke-WebRequest {
            if ($Uri -like '*/devices-detailed?*') {
                $script:DeviceCallCount++
                if ($script:DeviceCallCount -eq 1) {
                    # Retry-After: 0 means retry immediately
                    $Headers = @{ 'Retry-After' = '0' }
                    $Response = [PSCustomObject]@{
                        StatusCode = 429
                        Headers = $Headers
                    }
                    $InnerException = [System.Exception]::new('429 Too Many Requests')
                    $InnerException | Add-Member -NotePropertyName Response -NotePropertyValue $Response -Force
                    $OuterException = [System.Exception]::new('Too Many Requests', $InnerException)
                    $OuterException | Add-Member -NotePropertyName Response -NotePropertyValue $Response -Force
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $OuterException, 'WebException', [System.Management.Automation.ErrorCategory]::InvalidOperation, $null
                    )
                    throw $ErrorRecord
                }
                $Devices = @(@{ id = 1; organizationId = 1; systemName = 'PC'; nodeClass = 'WINDOWS_WORKSTATION'; system = @{ serialNumber = 'S1' } })
                return [pscustomobject]@{ content = (ConvertTo-Json -InputObject $Devices -Depth 5 -Compress) }
            } else {
                return [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($script:Orgs) -Depth 5 -Compress) }
            }
        }
        Mock Start-Sleep { param($Seconds); $script:SleepSeconds = $Seconds }
        Mock Get-Tenants { @([pscustomobject]@{ customerId = 't99'; displayName = 'ZeroRetryTest'; defaultDomainName = 'zeroretry.test' }) }
        Mock Get-CIPPDbItem { @([pscustomobject]@{ RowKey = 'dev1'; Data = '{"deviceName":"PC","serialNumber":"S1"}' }) }
        
        Invoke-NinjaOneOrgMapping
        
        $script:DeviceCallCount | Should -Be 2 -Because 'Retry-After=0 should retry immediately'
        $script:SleepSeconds | Should -Be 0 -Because 'Retry-After=0 should sleep 0 seconds, not default to 60'
    }
}
