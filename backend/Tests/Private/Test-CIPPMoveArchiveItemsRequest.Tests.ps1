BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Get-ChildItem -Path (Join-Path $RepoRoot 'Modules') -Recurse -Filter 'Test-CIPPMoveArchiveItemsRequest.ps1' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $FunctionPath) { throw 'Could not locate Test-CIPPMoveArchiveItemsRequest.ps1' }
    . $FunctionPath
}

Describe 'Test-CIPPMoveArchiveItemsRequest' {
    It 'rejects missing TicketNumber' {
        { Test-CIPPMoveArchiveItemsRequest -TenantFilter 'contoso.com' -UserPrincipalName 'a@contoso.com' -TicketNumber '   ' } |
            Should -Throw '*TicketNumber is required*'
    }

    It 'rejects non-numeric TicketNumber' {
        { Test-CIPPMoveArchiveItemsRequest -TenantFilter 'contoso.com' -UserPrincipalName 'a@contoso.com' -TicketNumber 'INC-1' } |
            Should -Throw '*TicketNumber must be numeric*'
    }

    It 'defaults DryRun to true when explicitly passed' {
        $R = Test-CIPPMoveArchiveItemsRequest -TenantFilter 'contoso.com' -UserPrincipalName 'a@contoso.com' -TicketNumber '12345' -DryRun $true
        $R.DryRun | Should -BeTrue
        $R.TicketNumber | Should -Be '12345'
    }

    It 'accepts numeric ticket and DryRun false' {
        $R = Test-CIPPMoveArchiveItemsRequest -TenantFilter 'contoso.com' -UserPrincipalName 'shared@contoso.com' -TicketNumber '999' -DryRun $false
        $R.DryRun | Should -BeFalse
    }
}
