function ConvertFrom-CIPPCraftRunStatus {
    <#
    .SYNOPSIS
        Shape a Craft run status as a CIPP queue entry.
    .DESCRIPTION
        Craft reports runs through QueueStatusBridge.GetRun and GetRuns. Queue trackers and
        ListEmptySiteRecycleBinStatus use the CippQueue shape, so this maps one onto the other.
    .PARAMETER Run
        A run status as Craft returns it (ConvertFrom-Json of its camelCase JSON).
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Run
    )

    $Total = [int]$Run.total
    $Done = [int]$Run.completed + [int]$Run.failed
    $Divisor = [Math]::Max($Total, 1)

    [PSCustomObject]@{
        PartitionKey    = 'CippQueue'
        RowKey          = $Run.runName
        QueueId         = if ($Run.runName -match '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { $Matches[0] } else { $Run.runName }
        Name            = if ($Run.label) { $Run.label } else { $Run.runName }
        Link            = [string]$Run.link
        Reference       = $Run.reference
        TotalTasks      = $Total
        CompletedTasks  = $Done
        RunningTasks    = [int]$Run.running
        FailedTasks     = [int]$Run.failed
        PercentComplete = [math]::Round($Done / $Divisor * 100, 1, [MidpointRounding]::AwayFromZero)
        PercentFailed   = [math]::Round([int]$Run.failed / $Divisor * 100, 1, [MidpointRounding]::AwayFromZero)
        PercentRunning  = [math]::Round([int]$Run.running / $Divisor * 100, 1, [MidpointRounding]::AwayFromZero)
        QueuedAhead     = [int]$Run.ahead
        RunsAhead       = [int]$Run.runsAhead
        Tasks           = @(foreach ($Task in @($Run.tasks)) {
                if (-not $Task) { continue }
                [PSCustomObject]@{ Timestamp = $Task.at; Name = $Task.name -replace '^[^_]*_(?=.)', ''; Status = $Task.status }
            })
        Status          = switch ($Run.status) {
            'CompletedWithErrors' { 'Completed (with errors)' }
            'NotFound' { 'Not found' }
            default { [string]$Run.status }
        }
        Timestamp       = if ($Run.startedUtc) { $Run.startedUtc } else { (Get-Date).ToUniversalTime().ToString('o') }
    }
}
