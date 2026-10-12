# CIPP-NG containers show Manage365 Users in the nav because ListFeatureFlags forces
# SuperAdminNG on. The request gate must use the same override, or ListCIPPUsers stays
# disabled while the page is visible.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

    function Get-CippTable { param($TableName) @{ Context = $TableName } }
    function Get-CIPPAzDataTableEntity { param($Context, $Filter, $Property) }
    function Add-CIPPAzDataTableEntity { param($Context, $Entity, [switch]$Force) }

    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Get-CIPPFeatureFlag.ps1')

    $ConfigDir = Join-Path $TestDrive 'Config'
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    @(
        @{ Id = 'SuperAdminNG'; Name = 'Super Admin'; Description = 'Additional super admin pages'; Enabled = $false; AllowUserToggle = $false; Timers = @(); Endpoints = @('ListCIPPUsers'); Pages = @('/cipp/advanced/authentication/cipp-users'); Hidden = $true }
    ) | ConvertTo-Json -Depth 5 -AsArray | Set-Content -Path (Join-Path $ConfigDir 'FeatureFlags.json')
    $env:CIPPRootPath = $TestDrive
}

Describe 'Get-CIPPFeatureFlag SuperAdminNG on CIPP-NG' {
    BeforeEach {
        Mock Add-CIPPAzDataTableEntity {}
        Mock Get-CIPPAzDataTableEntity {
            @([PSCustomObject]@{ PartitionKey = 'FeatureFlag'; RowKey = 'SuperAdminNG'; Enabled = $false })
        }
    }

    AfterEach {
        Remove-Item Env:CIPPNG -ErrorAction SilentlyContinue
    }

    It 'enables the pages on a CIPP-NG container without rewriting the stored row' {
        $env:CIPPNG = 'true'

        $Flag = Get-CIPPFeatureFlag -Id 'SuperAdminNG'

        $Flag.Enabled | Should -BeTrue
        Should -Invoke Add-CIPPAzDataTableEntity -Times 0 -Exactly
    }

    It 'keeps the stored off state when the container is not CIPP-NG' {
        Remove-Item Env:CIPPNG -ErrorAction SilentlyContinue

        $Flag = Get-CIPPFeatureFlag -Id 'SuperAdminNG'

        $Flag.Enabled | Should -BeFalse
    }
}
