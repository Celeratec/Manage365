BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Get-ChildItem -Path (Join-Path $RepoRoot 'Modules') -Recurse -Filter 'Invoke-CIPPArchiveMoveGraphTransport.ps1' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $FunctionPath) { throw 'Could not locate Invoke-CIPPArchiveMoveGraphTransport.ps1' }
    . $FunctionPath
}

Describe 'Get-CIPPArchiveMoveSafeFolderDisplayName' {
    It 'replaces invalid path characters' {
        Get-CIPPArchiveMoveSafeFolderDisplayName -Name 'Reports:2024/backup' | Should -Be 'Reports_2024_backup'
    }

    It 'defaults blank names' {
        Get-CIPPArchiveMoveSafeFolderDisplayName -Name '   ' | Should -Be 'Folder'
    }
}
