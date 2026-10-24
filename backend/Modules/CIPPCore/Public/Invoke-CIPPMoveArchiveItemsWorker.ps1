function Invoke-CIPPMoveArchiveItemsWorker {
    <#
    .SYNOPSIS
        Background worker for archive-to-primary moves (Graph import/export, EWS fallback).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JobId,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [string]$TicketNumber,

        [string]$SourceFolder,
        [string]$TargetFolder,
        [bool]$HoldAcknowledged,
        [string]$APIName = 'Move Archive Items Worker'
    )

    $Table = Get-CippTable -tablename 'MoveArchiveItemsJobs'
    $Job = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq '$TenantFilter' and RowKey eq '$JobId'"
    if (-not $Job) {
        throw "Move archive job $JobId not found."
    }

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $PreviewBefore = $null
    $Result = 'Succeeded'
    $ErrorSummary = $null

    $UpdateRunning = @{
        PartitionKey = $TenantFilter
        RowKey       = $JobId
        Status       = 'Running'
        UpdatedUtc   = (Get-Date).ToUniversalTime().ToString('o')
    }
    Add-CIPPAzDataTableEntity @Table -Entity $UpdateRunning -Force | Out-Null

    try {
        if ($null -eq $Job.ArchiveItemsBefore -or $null -eq $Job.PrimaryItemsBefore) {
            $PreviewBefore = Get-CIPPMoveArchiveItemsPreview -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -SourceFolder $SourceFolder -TargetFolder $TargetFolder
            $Seed = @{
                PartitionKey         = $TenantFilter
                RowKey               = $JobId
                ArchiveItemsBefore   = $PreviewBefore.ArchiveItemCount
                PrimaryItemsBefore   = $PreviewBefore.PrimaryItemCount
                ArchiveBytesBefore   = $PreviewBefore.ArchiveTotalBytes
                PrimaryBytesBefore   = $PreviewBefore.PrimaryTotalBytes
            }
            Add-CIPPAzDataTableEntity @Table -Entity $Seed -Force | Out-Null
            $Job = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq '$TenantFilter' and RowKey eq '$JobId'"
        }

        $JobHash = @{}
        foreach ($Prop in $Job.PSObject.Properties) { $JobHash[$Prop.Name] = $Prop.Value }

        $TransportResult = $null
        $PreferEws = [string]$Job.Transport -eq 'EWS'

        if ($PreferEws) {
            $TransportResult = Invoke-CIPPArchiveMoveEwsTransport -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -JobEntity $JobHash -TargetFolder $TargetFolder -SourceFolder $SourceFolder
        } else {
            try {
                $TransportResult = Invoke-CIPPArchiveMoveGraphTransport -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -JobEntity $JobHash -TargetFolder $TargetFolder -SourceFolder $SourceFolder
            } catch {
                Write-Warning "Graph archive move failed, attempting EWS fallback: $($_.Exception.Message)"
                $TransportResult = Invoke-CIPPArchiveMoveEwsTransport -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -JobEntity $JobHash -TargetFolder $TargetFolder -SourceFolder $SourceFolder
            }
        }

        $PriorMoved = [int]($Job.MovedCount ?? 0)
        $MovedTotal = $PriorMoved + [int]$TransportResult.MovedThisRun
        $Status = if ($TransportResult.Complete) { 'Succeeded' } else { 'Partial' }

        $Progress = @{
            PartitionKey       = $TenantFilter
            RowKey             = $JobId
            Status             = $Status
            MovedCount         = $MovedTotal
            Transport          = [string]$TransportResult.Transport
            CheckpointJson     = [string]$TransportResult.CheckpointJson
            PrimaryMailboxId   = [string]$TransportResult.PrimaryMailboxId
            ArchiveMailboxId   = [string]$TransportResult.ArchiveMailboxId
            UpdatedUtc         = (Get-Date).ToUniversalTime().ToString('o')
            ErrorSummary       = $null
        }
        Add-CIPPAzDataTableEntity @Table -Entity $Progress -Force | Out-Null

        if (-not $TransportResult.Complete) {
            $Task = [pscustomobject]@{
                TenantFilter = $TenantFilter
                Name         = "Resume archive move: $UserPrincipalName (ticket $TicketNumber)"
                Command      = @{ value = 'Invoke-CIPPMoveArchiveItemsWorker' }
                Parameters   = [pscustomobject]@{
                    JobId             = $JobId
                    TenantFilter      = $TenantFilter
                    UserPrincipalName = $UserPrincipalName
                    TicketNumber      = $TicketNumber
                    SourceFolder      = $SourceFolder
                    TargetFolder      = $TargetFolder
                    HoldAcknowledged  = [bool]$HoldAcknowledged
                    APIName           = $APIName
                }
            }
            $null = Add-CIPPScheduledTask -Task $Task -hidden $true -RunNow
            Write-LogMessage -API $APIName -tenant $TenantFilter -message "Archive move job $JobId partial: moved $MovedTotal items so far; requeued worker." -sev Info
            return
        }

        $PreviewAfter = Get-CIPPMoveArchiveItemsPreview -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -SourceFolder $SourceFolder -TargetFolder $TargetFolder
        $Final = @{
            PartitionKey        = $TenantFilter
            RowKey              = $JobId
            Status              = 'Succeeded'
            MovedCount          = $MovedTotal
            ArchiveItemsAfter   = $PreviewAfter.ArchiveItemCount
            PrimaryItemsAfter   = $PreviewAfter.PrimaryItemCount
            UpdatedUtc          = (Get-Date).ToUniversalTime().ToString('o')
        }
        Add-CIPPAzDataTableEntity @Table -Entity $Final -Force | Out-Null

        $null = Add-CIPPMoveArchiveItemsAudit -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -TicketNumber $TicketNumber -Operation 'MoveComplete' -Result 'Succeeded' -JobId $JobId -DryRun $false -Caller ([string]$Job.Caller) -ArchiveItemCountBefore ([int]$Job.ArchiveItemsBefore) -ArchiveItemCountAfter $PreviewAfter.ArchiveItemCount -PrimaryItemCountBefore ([int]$Job.PrimaryItemsBefore) -PrimaryItemCountAfter $PreviewAfter.PrimaryItemCount -ArchiveBytesBefore ([long]$Job.ArchiveBytesBefore) -PrimaryBytesBefore ([long]$Job.PrimaryBytesBefore) -PrimaryBytesAfterMoveProjected $PreviewAfter.PrimaryTotalBytes -DurationMs [int]$Stopwatch.ElapsedMilliseconds

        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Archive move job $JobId completed for ${UserPrincipalName}: moved $MovedTotal items (archive $($Job.ArchiveItemsBefore) -> $($PreviewAfter.ArchiveItemCount))." -sev Info
    } catch {
        $Result = 'Failed'
        $ErrorSummary = (Get-CippException -Exception $_).NormalizedError
        $Fail = @{
            PartitionKey  = $TenantFilter
            RowKey        = $JobId
            Status        = 'Failed'
            ErrorSummary  = $ErrorSummary
            UpdatedUtc    = (Get-Date).ToUniversalTime().ToString('o')
        }
        Add-CIPPAzDataTableEntity @Table -Entity $Fail -Force | Out-Null

        if ($PreviewBefore -or $Job.ArchiveItemsBefore) {
            $null = Add-CIPPMoveArchiveItemsAudit -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -TicketNumber $TicketNumber -Operation 'MoveComplete' -Result 'Failed' -JobId $JobId -DryRun $false -Caller ([string]$Job.Caller) -ArchiveItemCountBefore ([int]($Job.ArchiveItemsBefore ?? 0)) -PrimaryItemCountBefore ([int]($Job.PrimaryItemsBefore ?? 0)) -DurationMs [int]$Stopwatch.ElapsedMilliseconds -ErrorSummary $ErrorSummary
        }

        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Archive move job $JobId failed for ${UserPrincipalName}: $ErrorSummary" -sev Error
        throw
    }
}
