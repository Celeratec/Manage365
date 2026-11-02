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
        @{ id = 1; organizationId = 3; systemName = 'FAB-1'; system = @{ serialNumber = 'S1' } }
        @{ id = 2; organizationId = 3; systemName = 'FAB-2'; system = @{ serialNumber = 'S2' } }
        @{ id = 3; organizationId = 4; systemName = 'PC-X'; system = @{ serialNumber = 'SX' } }
        @{ id = 4; organizationId = 5; systemName = 'TIE-A'; system = @{ serialNumber = 'S3' } }
        @{ id = 5; organizationId = 6; systemName = 'TIE-B'; system = @{ serialNumber = 'S4' } }
        @{ id = 6; organizationId = 1; systemName = 'TAKEN'; system = @{ serialNumber = 'S5' } }
        @{ id = 7; organizationId = 5; systemName = 'DUP-A'; system = @{ serialNumber = 'DUP' } }
        @{ id = 8; organizationId = 6; systemName = 'DUP-B'; system = @{ serialNumber = 'DUP' } }
        @{ id = 9; organizationId = 7; systemName = 'NAMEPC'; system = @{ serialNumber = 'To Be Filled By O.E.M.' } }
    )
    $script:IntuneDevices = @{
        'fabrikam.test'  = @(@{ deviceName = 'a'; serialNumber = 'S1' }, @{ deviceName = 'b'; serialNumber = 'S2' }, @{ deviceName = 'PC-X'; serialNumber = 'nope' })
        'tied.test'      = @(@{ deviceName = 'a'; serialNumber = 'S3' }, @{ deviceName = 'b'; serialNumber = 'S4' })
        'taken.test'     = @(@{ deviceName = 'a'; serialNumber = 'S5' })
        'dupserial.test' = @(@{ deviceName = 'a'; serialNumber = 'DUP' })
        'nameonly.test'  = @(@{ deviceName = 'NAMEPC'; serialNumber = 'To Be Filled By O.E.M.' })
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
            @{ id = 100; organizationId = 10; systemName = 'PC-1'; system = @{ serialNumber = 'S1' } }
            @{ id = 101; organizationId = 11; systemName = 'MAJ-1'; system = @{ serialNumber = 'M1' } }
            @{ id = 102; organizationId = 11; systemName = 'MAJ-2'; system = @{ serialNumber = 'M2' } }
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

Describe 'Invoke-NinjaOneOrgMapping 429 retry and page cap' {
    It 'retries once after 429 rate limit' {
        Mock Invoke-WebRequest {
            if ($script:Attempt -eq 0) {
                $script:Attempt = 1
                $Response = [PSCustomObject]@{
                    StatusCode = 429
                    Headers = @{ 'Retry-After' = '1' }
                }
                $Ex = New-Object System.Net.WebException('Rate limited', $null, [System.Net.WebExceptionStatus]::ProtocolError, $Response)
                throw [System.Net.Http.HttpRequestException]::new('Rate limited', $Ex)
            } else {
                [pscustomobject]@{ content = '[]' }
            }
        } -ParameterFilter { $Uri -like '*/devices-detailed?*' }
        Mock Invoke-WebRequest {
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($script:Orgs) -Depth 5 -Compress) }
        } -ParameterFilter { $Uri -like '*/organizations?*' }
        $script:Attempt = 0
        { Invoke-NinjaOneOrgMapping } | Should -Not -Throw
        Should -Invoke Invoke-WebRequest -Times 2 -ParameterFilter { $Uri -like '*/devices-detailed?*' }
    }

    It 'stops fetching devices after 50 pages' {
        $script:PageCount = 0
        Mock Invoke-WebRequest {
            $script:PageCount++
            # Return full page of results to trigger continuation
            $Devices = @(1..1000 | ForEach-Object { @{ id = $_; organizationId = 1; systemName = "PC$_"; system = @{ serialNumber = "S$_" } } })
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject $Devices -Depth 5 -Compress) }
        } -ParameterFilter { $Uri -like '*/devices-detailed?*' }
        Mock Invoke-WebRequest {
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($script:Orgs) -Depth 5 -Compress) }
        } -ParameterFilter { $Uri -like '*/organizations?*' }
        Invoke-NinjaOneOrgMapping
        $script:PageCount | Should -BeLessOrEqual 50
    }
}
