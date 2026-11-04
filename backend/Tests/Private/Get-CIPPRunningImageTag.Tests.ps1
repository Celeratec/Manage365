BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Functions/Get-CIPPRunningImageTag.ps1')
}

Describe 'Get-CIPPRunningImageTag' {
    BeforeEach {
        $script:PreviousRoot = $env:CIPPRootPath
        $script:PreviousTag = $env:IMAGE_TAG
    }

    AfterEach {
        $env:CIPPRootPath = $script:PreviousRoot
        $env:IMAGE_TAG = $script:PreviousTag
    }

    It 'reads the tag from version.json instead of a stale history value' {
        $Root = Join-Path ([System.IO.Path]::GetTempPath()) ("cipp-tag-" + [guid]::NewGuid().ToString('n'))
        $Frontend = Join-Path $Root 'Frontend'
        New-Item -ItemType Directory -Path $Frontend | Out-Null
        try {
            @{ version = '11.2.1'; tag = 'v6.1.32'; commit = 'abc' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Frontend 'version.json')
            $env:CIPPRootPath = Join-Path $Root 'API'
            $env:IMAGE_TAG = 'v6.1.17'
            Get-CIPPRunningImageTag | Should -Be 'v6.1.32'
        } finally {
            Remove-Item -LiteralPath $Root -Recurse -Force
        }
    }

    It 'uses IMAGE_TAG when version.json is not on disk' {
        $env:CIPPRootPath = Join-Path ([System.IO.Path]::GetTempPath()) ("missing-" + [guid]::NewGuid().ToString('n'))
        $env:IMAGE_TAG = 'v6.1.32'
        Get-CIPPRunningImageTag | Should -Be 'v6.1.32'
    }
}
