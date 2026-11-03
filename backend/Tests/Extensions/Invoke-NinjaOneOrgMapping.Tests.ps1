BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    Add-Type -Path (Join-Path $RepoRoot 'Shared/CIPPSharp/bin/CIPPSharp.dll')

    function Get-CIPPTable { param($TableName) @{} }
    function Get-AzDataTableEntity { param($Context, $Filter) }
    function Add-AzDataTableEntity { param($Context, $Entity, [switch]$Force) }
    function Get-NinjaOneToken { param($configuration) @{ access_token = 'token' } }
    function Write-LogMessage { param($API, $tenant, $message, $Sev) }
    function Start-CIPPOrchestrator { param($InputObject) }
    function Get-Tenants {
        param([switch]$IncludeErrors)
        foreach ($Name in 'Already', 'Contoso', 'Fabrikam', 'Tied', 'Taken', 'DupSerial', 'Broken', 'NameOnly') {
            [pscustomobject]@{ customerId = "t$($script:TenantIds[$Name])"; displayName = $Name; defaultDomainName = "$Name.test".ToLower() }
        }
    }

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
}

Describe 'Invoke-NinjaOneOrgMapping' {
    BeforeAll {
        $script:Added = [System.Collections.Generic.List[object]]::new()
        Mock Get-AzDataTableEntity {
            if ($Filter -like '*NinjaOneMapping*') {
                [pscustomobject]@{ RowKey = 't1'; IntegrationName = 'Already'; IntegrationId = '1' }
            } else {
                [pscustomobject]@{ config = (@{ NinjaOne = @{ Instance = 'ninja.example.com' } } | ConvertTo-Json -Compress) }
            }
        }
        Mock Add-AzDataTableEntity { param($Entity) $script:Added.Add($Entity) }
        Mock Invoke-WebRequest {
            $Data = if ($Uri -like '*/organizations?*') { $script:Orgs } else { $script:NinjaDevices }
            [pscustomobject]@{ content = (ConvertTo-Json -InputObject @($Data) -Depth 5 -Compress) }
        }
        Mock Start-CIPPOrchestrator {
            param($InputObject)
            $script:OrchestratorInput = $InputObject
            'orch-1'
        }
        Invoke-NinjaOneOrgMapping
        $script:ByTenant = @{}
        foreach ($Row in $script:Added) { $script:ByTenant[$Row.RowKey] = $Row.IntegrationId }
    }

    It 'maps an exact organization name match inline' {
        $script:ByTenant['t2'] | Should -Be '2'
    }

    It 'queues device-based automap for tenants without an exact org name match' {
        $script:OrchestratorInput.OrchestratorName | Should -Be 'NinjaOneOrchestrator'
        @($script:OrchestratorInput.Batch.TenantFilter) | Should -Contain 'fabrikam.test'
        @($script:OrchestratorInput.Batch.TenantFilter) | Should -Contain 'nameonly.test'
        $script:OrchestratorInput.Batch[0].NinjaDevices | Should -Not -BeNullOrEmpty
    }

    It 'does not inline-map tenants that need device correlation' {
        $script:ByTenant.Keys | Should -Not -Contain 't3'
        $script:ByTenant.Keys | Should -Not -Contain 't7'
    }

    It 'never rewrites an existing mapping' {
        $script:ByTenant.Keys | Should -Not -Contain 't1'
        $script:Added.Count | Should -Be 1
    }

    It 'starts the NinjaOne orchestrator when unmapped tenants remain' {
        $script:OrchestratorInput.OrchestratorName | Should -Be 'NinjaOneOrchestrator'
        @($script:OrchestratorInput.Batch).Count | Should -BeGreaterThan 0
    }
}
