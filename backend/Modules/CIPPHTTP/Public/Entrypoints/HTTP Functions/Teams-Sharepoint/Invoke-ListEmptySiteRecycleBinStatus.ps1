function Invoke-ListEmptySiteRecycleBinStatus {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.SiteRecycleBin.Read
    .SYNOPSIS
        Poll a queued site recycle bin empty job.
    .DESCRIPTION
        Companion to Invoke-ExecEmptySiteRecycleBin. Returns Queued or Running while the
        background worker is in progress, then the verified counts once it finishes.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $QueueId = $Request.Query.queueId ?? $Request.Query.QueueId ?? $Request.Body.queueId ?? $Request.Body.QueueId
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Query.TenantFilter ?? $Request.Body.tenantFilter ?? $Request.Body.TenantFilter

    if ([string]::IsNullOrWhiteSpace($QueueId)) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'queueId is required.' }
            })
    }

    try {
        $QueueData = Get-CIPPQueueData -QueueId $QueueId | Select-Object -First 1
        if (-not $QueueData) {
            return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::NotFound
                    Body       = @{ Results = 'Recycle bin job not found.' }
                })
        }

        $CacheTable = Get-CippTable -tablename 'CacheSiteRecycleBin'
        $SafeQueueId = ConvertTo-CIPPODataFilterValue -Value $QueueId -Type String
        $Filter = "RowKey eq '$SafeQueueId'"
        if ($TenantFilter) {
            $SafeTenant = ConvertTo-CIPPODataFilterValue -Value $TenantFilter -Type String
            $Filter = "PartitionKey eq '$SafeTenant' and RowKey eq '$SafeQueueId'"
        }
        $Cached = Get-CIPPAzDataTableEntity @CacheTable -Filter $Filter | Select-Object -First 1
        $Payload = $null
        if ($Cached.Data) {
            $Payload = $Cached.Data | ConvertFrom-Json -Depth 8
        }

        if ($QueueData.Status -eq 'Running' -or $QueueData.Status -eq 'Queued') {
            return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body       = @{
                        Status          = [string]$QueueData.Status
                        QueueId         = $QueueId
                        Results         = if ($Payload.Results) { [string]$Payload.Results } else { 'Recycle bin empty is still running.' }
                        stage           = $Payload.stage
                        deletedCount    = $Payload.deletedCount
                        deletedBytes    = $Payload.deletedBytes
                        remainingFirst  = $Payload.remainingFirst
                        remainingSecond = $Payload.remainingSecond
                        emptied         = $false
                    }
                })
        }

        if ($Cached.Error -and -not $Payload) {
            return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body       = @{
                        Status   = 'Failed'
                        QueueId  = $QueueId
                        Results  = "Recycle bin empty failed: $($Cached.Error)"
                        emptied  = $false
                    }
                })
        }

        if (-not $Payload) {
            if ($QueueData.Status -match 'Failed') {
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::OK
                        Body       = @{
                            Status  = 'Failed'
                            QueueId = $QueueId
                            Results = 'Recycle bin empty failed.'
                            emptied = $false
                        }
                    })
            }
            return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body       = @{
                        Status  = 'Running'
                        QueueId = $QueueId
                        Results = 'Recycle bin empty is still running.'
                        emptied = $false
                    }
                })
        }

        $Status = switch ([string]$Payload.Outcome) {
            'Empty' { 'Completed' }
            'Partial' { 'Partial' }
            'Failed' { 'Failed' }
            default { if ($Payload.Status) { [string]$Payload.Status } else { [string]$QueueData.Status } }
        }
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{
                    Status               = $Status
                    QueueId              = $QueueId
                    Results              = [string]$Payload.Results
                    emptied              = [bool]$Payload.emptied
                    deletedCount         = $Payload.deletedCount
                    deletedBytes         = $Payload.deletedBytes
                    remainingFirst       = $Payload.remainingFirst
                    remainingSecond      = $Payload.remainingSecond
                    remainingFirstBytes  = $Payload.remainingFirstBytes
                    remainingSecondBytes = $Payload.remainingSecondBytes
                    remainingCapped      = [bool]$Payload.remainingCapped
                    errors               = @($Payload.errors)
                }
            })
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to load recycle bin empty status: $($ErrorMessage.NormalizedError)" -sev Error -LogData $ErrorMessage
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::InternalServerError
                Body       = @{ Results = "Failed to load recycle bin empty status: $($ErrorMessage.NormalizedError)" }
            })
    }
}
