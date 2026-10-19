function Invoke-ExecEmptySiteRecycleBin {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.SiteRecycleBin.ReadWrite
    .DESCRIPTION
        Permanently empty a site recycle bin (first stage, second stage, or both).
        Item ids are used only server-side; the response never includes file names.
        Bins larger than a single HTTP window are queued. Poll ListEmptySiteRecycleBinStatus.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter ?? $Request.Body.TenantFilter
    $SiteUrl = $Request.Body.SiteUrl
    $Stage = [string]($Request.Body.Stage ?? 'Both')
    # Stay under the ~230s gateway. Larger bins are queued.
    $InlineItemLimit = 250

    if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'tenantFilter is required.' } })
    }
    if ([string]::IsNullOrWhiteSpace($SiteUrl)) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'SiteUrl is required.' } })
    }
    if ($Stage -notin @('First', 'Second', 'Both')) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = "Invalid Stage '$Stage'. Valid values: First, Second, Both." }
            })
    }

    try {
        $RestContext = Resolve-CIPPSharePointRestContext -TenantFilter $TenantFilter -SiteUrl $SiteUrl
        $PreviewState = switch ($Stage) {
            'First' { 1 }
            'Second' { 2 }
            default { 0 }
        }
        $Preview = Get-CIPPSiteRecycleBinItems -TenantFilter $TenantFilter -SiteUrl $SiteUrl -RestContext $RestContext -ItemState $PreviewState -MaxItems ($InlineItemLimit + 1) -RowLimit 200
        $PreviewCount = [int]$Preview.ScannedItems

        if ($Preview.Capped -or $PreviewCount -gt $InlineItemLimit) {
            $QueueReference = "EmptyRecycleBin-$TenantFilter-$($SiteUrl.TrimEnd('/'))-$Stage"
            $Queue = New-CippQueueEntry -Name "Empty recycle bin ($Stage)" -Link '/teams-share/sharepoint' -Reference $QueueReference -TotalTasks 1
            $Queued = Add-CippQueueMessage -Cmdlet 'Start-CIPPEmptySiteRecycleBin' -Parameters @{
                QueueId      = $Queue.RowKey
                TenantFilter = $TenantFilter
                SiteUrl      = $SiteUrl
                Stage        = $Stage
            }
            if (-not $Queued) { throw 'Failed to queue the recycle bin empty job.' }

            $Results = "Queued recycle bin empty ($Stage) for $($SiteUrl.TrimEnd('/')). About $PreviewCount items are too large to finish in one request. Poll status with queue $($Queue.RowKey)."
            Write-LogMessage -Headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Info
            return ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body       = @{
                        Results         = $Results
                        Queued          = $true
                        QueueId         = $Queue.RowKey
                        Status          = 'Queued'
                        deletedCount    = 0
                        deletedBytes    = 0
                        remainingFirst  = [int64]$Preview.FirstStageCount
                        remainingSecond = [int64]$Preview.SecondStageCount
                        emptied         = $false
                        capped          = [bool]$Preview.Capped
                    }
                })
        }

        $Outcome = Invoke-CIPPEmptySiteRecycleBin -TenantFilter $TenantFilter -SiteUrl $SiteUrl -RestContext $RestContext -Stage $Stage -Headers $Headers -APIName $APIName
        $StatusCode = switch ($Outcome.Outcome) {
            'Empty' { [HttpStatusCode]::OK }
            'Partial' { [HttpStatusCode]::MultiStatus }
            default { [HttpStatusCode]::InternalServerError }
        }
        $Body = @{
            Results              = [string]$Outcome.Results
            Queued               = $false
            emptied              = [bool]$Outcome.emptied
            deletedCount         = [int64]$Outcome.deletedCount
            deletedBytes         = [int64]$Outcome.deletedBytes
            remainingFirst       = [int64]$Outcome.remainingFirst
            remainingSecond      = [int64]$Outcome.remainingSecond
            remainingFirstBytes  = [int64]$Outcome.remainingFirstBytes
            remainingSecondBytes = [int64]$Outcome.remainingSecondBytes
            remainingCapped      = [bool]$Outcome.remainingCapped
            errors               = @($Outcome.errors)
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Results = "Failed to empty recycle bin on $($SiteUrl): $($ErrorMessage.NormalizedError)"
        Write-LogMessage -Headers $Headers -API $APIName -tenant $TenantFilter -message $Results -sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = @{ Results = $Results; emptied = $false; deletedCount = 0; deletedBytes = 0 }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
