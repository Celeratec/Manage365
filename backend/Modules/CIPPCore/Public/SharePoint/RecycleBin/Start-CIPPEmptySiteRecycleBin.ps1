function Start-CIPPEmptySiteRecycleBin {
    <#
    .FUNCTIONALITY
        Internal
    .SYNOPSIS
        Background worker that empties a SharePoint site recycle bin.
    .DESCRIPTION
        Invoked from the CIPP queue. Large bins cannot finish inside the HTTP gateway window,
        so Invoke-ExecEmptySiteRecycleBin queues this command and ListEmptySiteRecycleBinStatus
        reads CacheSiteRecycleBin for progress.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$QueueId,

        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$SiteUrl,

        [ValidateSet('First', 'Second', 'Both')]
        [string]$Stage = 'Both'
    )

    $QueueTask = @{
        QueueId = $QueueId
        Name    = "Emptying recycle bin ($Stage)"
        Status  = 'Running'
    }
    $TaskStatus = Set-CippQueueTask @QueueTask
    $QueueTask.TaskId = $TaskStatus.RowKey

    try {
        Update-CippQueueEntry -RowKey $QueueId -Status 'Running'
        try {
            Write-LogMessage -API 'Start-CIPPEmptySiteRecycleBin' -tenant $TenantFilter -message "Starting recycle bin empty (stage=$Stage, site=$SiteUrl, queueId=$QueueId)" -Sev Info
        } catch {
            Write-Warning "Recycle bin start log failed: $($_.Exception.Message)"
        }

        $RestContext = Resolve-CIPPSharePointRestContext -TenantFilter $TenantFilter -SiteUrl $SiteUrl
        $Result = Invoke-CIPPEmptySiteRecycleBin -TenantFilter $TenantFilter -SiteUrl $SiteUrl -RestContext $RestContext -Stage $Stage -QueueId $QueueId -APIName 'ExecEmptySiteRecycleBin'

        $QueueStatus = if ($Result.Outcome -eq 'Failed') { 'Failed' } else { 'Completed' }
        Update-CippQueueEntry -RowKey $QueueId -Status $QueueStatus
        $QueueTask.Status = if ($Result.Outcome -eq 'Failed') { 'Failed' } else { 'Completed' }
        Set-CippQueueTask @QueueTask
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        try {
            Write-LogMessage -API 'Start-CIPPEmptySiteRecycleBin' -tenant $TenantFilter -message "Recycle bin empty failed: $($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
        } catch {
            Write-Warning "Recycle bin failure log failed: $($_.Exception.Message)"
        }
        try {
            $CacheTable = Get-CippTable -tablename 'CacheSiteRecycleBin'
            $Entity = @{
                PartitionKey = $TenantFilter
                RowKey       = $QueueId
                Error        = [string]$ErrorMessage.NormalizedError
                Data         = [string](@{
                        Outcome = 'Failed'
                        Status  = 'Failed'
                        Results = "Failed to empty recycle bin ($Stage) for $($SiteUrl.TrimEnd('/')). $($ErrorMessage.NormalizedError)"
                    } | ConvertTo-Json -Compress)
                CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            Add-CIPPAzDataTableEntity @CacheTable -Entity $Entity -Force | Out-Null
        } catch {
            Write-Warning "Failed to store recycle bin empty error: $($_.Exception.Message)"
        }
        Update-CippQueueEntry -RowKey $QueueId -Status 'Failed'
        $QueueTask.Status = 'Failed'
        Set-CippQueueTask @QueueTask
    }
}
