function Invoke-CIPPEmptySiteRecycleBin {
    <#
    .SYNOPSIS
        Permanently empty a SharePoint site recycle bin by id.
    .DESCRIPTION
        Deletes from /_api/site/RecycleBin/DeleteByIds. web/RecycleBin/deleteAll() is not used:
        as the app-only principal it returns 2xx and deletes nothing, because it only covers
        items that principal deleted.

        SharePoint moves a first-stage item into the second stage when it is deleted. A Both
        request therefore always runs a second-stage pass after the first-stage pass. Success
        is a re-read that shows the requested stages empty, not a POST that did not throw.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$SiteUrl,

        [Parameter(Mandatory = $true)]
        [object]$RestContext,

        [ValidateSet('First', 'Second', 'Both')]
        [string]$Stage = 'Both',

        [ValidateRange(25, 100)]
        [int]$ChunkSize = 50,

        [ValidateRange(1, 100000)]
        [int]$MaxIterations = 100000,

        [ValidateRange(1, 100000)]
        [int]$MaxScan = 100000,

        $Headers,

        [string]$APIName = 'ExecEmptySiteRecycleBin',

        [string]$QueueId
    )

    $SiteLabel = if ($RestContext.SiteUrl) { [string]$RestContext.SiteUrl } else { $SiteUrl.TrimEnd('/') }
    $Posted = @{}
    $StageErrors = [System.Collections.Generic.List[string]]::new()
    $StageSummaries = [System.Collections.Generic.List[object]]::new()

    function Write-RecycleLog {
        param([string]$Message, [string]$Severity = 'Info')
        try {
            if ($Headers) {
                Write-LogMessage -Headers $Headers -API $APIName -tenant $TenantFilter -message $Message -sev $Severity
            } else {
                Write-LogMessage -API $APIName -tenant $TenantFilter -message $Message -sev $Severity
            }
        } catch {
            Write-Warning "Recycle bin log failed: $($_.Exception.Message)"
        }
    }

    function Save-RecycleProgress {
        param([hashtable]$Payload)
        if ([string]::IsNullOrWhiteSpace($QueueId)) { return }
        try {
            $CacheTable = Get-CippTable -tablename 'CacheSiteRecycleBin'
            $Entity = @{
                PartitionKey = $TenantFilter
                RowKey       = $QueueId
                Data         = [string]($Payload | ConvertTo-Json -Depth 8 -Compress)
                CachedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            Add-CIPPAzDataTableEntity @CacheTable -Entity $Entity -Force | Out-Null
        } catch {
            Write-Warning "Failed to store recycle bin job progress: $($_.Exception.Message)"
        }
    }

    function Measure-RecycleBin {
        param([int]$StateFilter)
        Get-CIPPSiteRecycleBinItems -TenantFilter $TenantFilter -SiteUrl $SiteLabel -RestContext $RestContext -ItemState $StateFilter -MaxItems $MaxScan -RowLimit 200
    }

    function Get-DeletedByIdsBody {
        param([string[]]$Ids)
        $JsonIds = foreach ($Id in $Ids) { ConvertTo-Json -InputObject ([string]$Id) -Compress }
        return '{"ids":[' + ($JsonIds -join ',') + ']}'
    }

    # First-stage deletes land in the second stage, so Both must run second after first.
    $StagePlan = [System.Collections.Generic.List[int]]::new()
    if ($Stage -in @('First', 'Both')) { $StagePlan.Add(1) }
    if ($Stage -in @('Second', 'Both')) { $StagePlan.Add(2) }

    foreach ($StateValue in $StagePlan) {
        $Label = if ($StateValue -eq 2) { 'Second' } else { 'First' }
        $Before = Measure-RecycleBin -StateFilter $StateValue
        $Submitted = 0
        $PreviousSignature = $null
        $Iteration = 0
        $StageErrorCount = 0
        $PageItems = @()

        Save-RecycleProgress @{
            Status           = 'Running'
            stage            = $Label
            deletedCount     = $Posted.Count
            deletedBytes     = 0
            remainingFirst   = $null
            remainingSecond  = $null
            submittedCount   = $Submitted
        }

        while ($Iteration -lt $MaxIterations) {
            $Iteration++
            $Page = Get-CIPPSiteRecycleBinItems -TenantFilter $TenantFilter -SiteUrl $SiteLabel -RestContext $RestContext -ItemState $StateValue -MaxItems $ChunkSize -RowLimit $ChunkSize
            $PageItems = @($Page.Items)
            if ($PageItems.Count -eq 0) { break }

            $Ids = @(
                foreach ($Item in $PageItems) {
                    $Id = [string]$Item.Id
                    if (-not [string]::IsNullOrWhiteSpace($Id)) { $Id }
                }
            )
            if ($Ids.Count -eq 0) { break }

            $Signature = (@($Ids | Sort-Object) -join '|')
            if ($Signature -eq $PreviousSignature) {
                $StageErrors.Add("$Label stage: DeleteByIds made no progress; the same items are still in the recycle bin.")
                $StageErrorCount++
                break
            }
            $PreviousSignature = $Signature

            $DeleteBody = Get-DeletedByIdsBody -Ids $Ids
            try {
                $null = New-GraphPostRequest -uri "$($RestContext.BaseUri)/site/RecycleBin/DeleteByIds" -tenantid $TenantFilter -scope $RestContext.Scope -type POST -body $DeleteBody -contentType 'application/json;odata=nometadata' -AddedHeaders $RestContext.Headers -UseCertificate -AsApp $true
            } catch {
                $StageErrors.Add("$Label stage: $($_.Exception.Message)")
                $StageErrorCount++
                break
            }

            foreach ($Item in $PageItems) {
                $Id = [string]$Item.Id
                if ([string]::IsNullOrWhiteSpace($Id)) { continue }
                if (-not $Posted.ContainsKey($Id)) {
                    $Size = [int64]0
                    try { $Size = [int64][double]$Item.Size } catch { $Size = 0 }
                    $Posted[$Id] = $Size
                }
            }
            $Submitted += $Ids.Count

            if ($QueueId -and ($Iteration % 5 -eq 0)) {
                Save-RecycleProgress @{
                    Status         = 'Running'
                    stage          = $Label
                    deletedCount   = $Posted.Count
                    submittedCount = $Submitted
                }
            }
        }

        if ($Iteration -ge $MaxIterations -and $PageItems.Count -gt 0) {
            $StageErrors.Add("$Label stage: stopped after $MaxIterations passes.")
            $StageErrorCount++
        }

        $After = Measure-RecycleBin -StateFilter $StateValue
        $Summary = [PSCustomObject]@{
            stage        = $Label
            beforeCount  = [int64]$Before.ScannedItems
            beforeBytes  = [int64]$(if ($StateValue -eq 2) { $Before.SecondStageBytes } else { $Before.FirstStageBytes })
            afterCount   = [int64]$After.ScannedItems
            afterBytes   = [int64]$(if ($StateValue -eq 2) { $After.SecondStageBytes } else { $After.FirstStageBytes })
            beforeCapped = [bool]$Before.Capped
            afterCapped  = [bool]$After.Capped
            submitted    = [int]$Submitted
            errors       = $StageErrorCount
        }
        $StageSummaries.Add($Summary)
        Write-RecycleLog -Message ("Recycle bin stage={0} site={1} beforeCount={2} beforeBytes={3} afterCount={4} afterBytes={5} submitted={6} errors={7} beforeCapped={8} afterCapped={9}" -f $Summary.stage, $SiteLabel, $Summary.beforeCount, $Summary.beforeBytes, $Summary.afterCount, $Summary.afterBytes, $Summary.submitted, $Summary.errors, $Summary.beforeCapped, $Summary.afterCapped)
    }

    $Final = Measure-RecycleBin -StateFilter 0
    $RemainingIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Item in @($Final.Items)) {
        $Id = [string]$Item.Id
        if (-not [string]::IsNullOrWhiteSpace($Id)) { [void]$RemainingIds.Add($Id) }
    }

    $DeletedCount = [int64]0
    $DeletedBytes = [int64]0
    if (-not $Final.Capped) {
        foreach ($Entry in @($Posted.GetEnumerator())) {
            if (-not $RemainingIds.Contains([string]$Entry.Key)) {
                $DeletedCount++
                $DeletedBytes += [int64]$Entry.Value
            }
        }
    }

    $RemainingFirst = [int64]$Final.FirstStageCount
    $RemainingSecond = [int64]$Final.SecondStageCount
    $RequestedRemain = [int64]0
    if ($Stage -in @('First', 'Both')) { $RequestedRemain += $RemainingFirst }
    if ($Stage -in @('Second', 'Both')) { $RequestedRemain += $RemainingSecond }

    $Emptied = ($RequestedRemain -eq 0) -and (-not $Final.Capped)
    if ($Emptied) {
        $Outcome = 'Empty'
        $Results = "Emptied recycle bin ($Stage) for $SiteLabel. Deleted $DeletedCount items ($DeletedBytes bytes)."
        if ($Stage -eq 'First' -and $RemainingSecond -gt 0) {
            $Results += " First-stage deletes move items into the second stage; $RemainingSecond items remain there."
        }
    } elseif ($DeletedCount -gt 0) {
        $Outcome = 'Partial'
        $Results = "Recycle bin ($Stage) for $SiteLabel is not empty. Deleted $DeletedCount items ($DeletedBytes bytes). Remaining first stage $RemainingFirst, second stage $RemainingSecond."
    } else {
        $Outcome = 'Failed'
        $Results = "Failed to empty recycle bin ($Stage) for $SiteLabel. Deleted 0 items. Remaining first stage $RemainingFirst, second stage $RemainingSecond."
    }
    if ($Final.Capped) {
        $Results += ' The verification read hit its scan limit, so this result is incomplete.'
    }
    if ($StageErrors.Count -gt 0) {
        $Results += ' ' + ($StageErrors -join ' ')
    }

    $Payload = @{
        Outcome              = $Outcome
        Results              = $Results
        emptied              = $Emptied
        deletedCount         = $DeletedCount
        deletedBytes         = $DeletedBytes
        remainingFirst       = $RemainingFirst
        remainingSecond      = $RemainingSecond
        remainingFirstBytes  = [int64]$Final.FirstStageBytes
        remainingSecondBytes = [int64]$Final.SecondStageBytes
        remainingCapped      = [bool]$Final.Capped
        errors               = @($StageErrors)
        stages               = @($StageSummaries)
        stage                = $Stage
        Status               = $(if ($Emptied) { 'Completed' } elseif ($Outcome -eq 'Partial') { 'Partial' } else { 'Failed' })
    }

    $Severity = if ($Emptied) { 'Info' } elseif ($Outcome -eq 'Partial') { 'Warning' } else { 'Error' }
    Write-RecycleLog -Severity $Severity -Message ("Recycle bin result stage={0} site={1} deletedCount={2} deletedBytes={3} remainingFirst={4} remainingSecond={5} emptied={6} capped={7}" -f $Stage, $SiteLabel, $DeletedCount, $DeletedBytes, $RemainingFirst, $RemainingSecond, $Emptied, $Final.Capped)
    Save-RecycleProgress -Payload $Payload
    return [PSCustomObject]$Payload
}
