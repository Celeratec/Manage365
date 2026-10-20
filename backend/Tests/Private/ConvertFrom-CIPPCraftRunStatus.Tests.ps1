BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/CippQueue/ConvertFrom-CIPPCraftRunStatus.ps1')
}

Describe 'ConvertFrom-CIPPCraftRunStatus' {
    It 'maps a running Craft run onto the queue fields the recycle bin status reads' {
        $Run = [pscustomobject]@{
            runName    = 'EmptySiteRecycleBin-11111111-1111-1111-1111-111111111111'
            reference  = 'site-recycle'
            label      = 'Empty recycle bin'
            link       = '/site'
            status     = 'Running'
            total      = 4
            queued     = 1
            running    = 1
            completed  = 2
            failed     = 0
            ahead      = 0
            runsAhead  = 0
            startedUtc = '2026-10-20T20:00:00Z'
            tasks      = @(
                [pscustomobject]@{ name = 'Empty_contoso'; status = 'Completed'; at = '2026-10-20T20:01:00Z' }
            )
        }

        $Queue = ConvertFrom-CIPPCraftRunStatus -Run $Run

        $Queue.Status | Should -Be 'Running'
        $Queue.QueueId | Should -Be '11111111-1111-1111-1111-111111111111'
        $Queue.TotalTasks | Should -Be 4
        $Queue.CompletedTasks | Should -Be 2
        $Queue.RunningTasks | Should -Be 1
        $Queue.Name | Should -Be 'Empty recycle bin'
        $Queue.Tasks[0].Name | Should -Be 'contoso'
        $Queue.Tasks[0].Status | Should -Be 'Completed'
    }

    It 'turns CompletedWithErrors into the queue tracker status' {
        $Run = [pscustomobject]@{ status = 'CompletedWithErrors'; total = 1; completed = 0; failed = 1; runName = 'run' }
        (ConvertFrom-CIPPCraftRunStatus -Run $Run).Status | Should -Be 'Completed (with errors)'
    }
}
