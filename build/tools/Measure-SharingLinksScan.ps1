<#
.SYNOPSIS
    Measures sharing-links scan throughput on a drive and projects site-scan wall time
    against the Craft background activity budget (Worker:BgTimeoutSeconds).

.DESCRIPTION
    Times the two Graph phases Push-DBCacheSharePointSiteSharingLinks actually runs:

      Phase A - full delta enumeration of the drive (same URI shape as the scan:
                /beta/drives/{id}/root/delta?$select=...&$top=999), per-page latency.
      Phase B - permission reads for the shared items found, via New-GraphBulkRequest
                in the same 20-per-$batch shape as Add-CIPPSharingRows.
      Phase C - (optional, -RunActivity) end-to-end run of the real site activity with a
                synthetic scan row, timing the whole thing including table writes.

    Then extrapolates: given measured seconds/page and seconds/permission-batch, at what
    item count does one site activity exceed the platform kill limit (BgTimeoutSeconds,
    default 1200s)? Craft marks a timed-out task Failed without retry, so a site that
    cannot finish inside the budget never completes its scan.

    Requires a dev session: dot-source build/tools/Initialize-DevEnvironment.ps1 first.

.EXAMPLE
    ./Measure-SharingLinksScan.ps1 -TenantFilter zacgoose.onmicrosoft.com -DriveId b!xxxx
.EXAMPLE
    ./Measure-SharingLinksScan.ps1 -TenantFilter zacgoose.onmicrosoft.com -SiteUrl https://zacgoose.sharepoint.com/sites/ZacRichards -LibraryName CippSharingPerfTest -RunActivity
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantFilter,

    [string]$DriveId,

    [string]$SiteUrl,

    [string]$LibraryName = 'CippSharingPerfTest',

    # Also run the real Push-DBCacheSharePointSiteSharingLinks end-to-end (writes to the
    # dev reporting DB tables).
    [switch]$RunActivity,

    # Activity wall-clock budget to project against (Craft Worker:BgTimeoutSeconds).
    [int]$BudgetSeconds = 1200
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-GraphToken -ErrorAction SilentlyContinue)) {
    throw 'Dev session not initialized. Dot-source build/tools/Initialize-DevEnvironment.ps1 first.'
}

# --- resolve drive -----------------------------------------------------------------------------
$Site = $null
if (-not $DriveId) {
    if (-not $SiteUrl) { throw 'Provide -DriveId or -SiteUrl + -LibraryName.' }
    $SiteUri = [uri]$SiteUrl
    $SitePath = $SiteUri.AbsolutePath.TrimEnd('/')
    $SiteLookup = if ([string]::IsNullOrEmpty($SitePath)) { $SiteUri.Host } else { "$($SiteUri.Host):$SitePath" }
    $Site = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteLookup" -tenantid $TenantFilter -asapp $true
    $Lists = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/lists?`$filter=displayName eq '$LibraryName'" -tenantid $TenantFilter -asapp $true
    $List = @($Lists) | Where-Object { $_.displayName -eq $LibraryName } | Select-Object -First 1
    if (-not $List) { throw "Library '$LibraryName' not found on $SiteUrl" }
    $Drive = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/lists/$($List.id)/drive?`$select=id,name" -tenantid $TenantFilter -asapp $true
    $DriveId = $Drive.id
}
Write-Host "Drive: $DriveId"

# --- Phase A: delta enumeration ----------------------------------------------------------------
$DeltaSelect = 'id,name,webUrl,folder,shared,deleted,size,lastModifiedDateTime'
$Uri = "https://graph.microsoft.com/beta/drives/$DriveId/root/delta?`$select=$DeltaSelect&`$top=999"
$PageTimes = [System.Collections.Generic.List[double]]::new()
$Items = 0
$SharedItems = [System.Collections.Generic.List[object]]::new()
$TotalSw = [System.Diagnostics.Stopwatch]::StartNew()
while ($Uri) {
    $PageSw = [System.Diagnostics.Stopwatch]::StartNew()
    $Page = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -asapp $true -noPagination $true -SkipValueExtraction
    $PageSw.Stop()
    $PageTimes.Add($PageSw.Elapsed.TotalMilliseconds)
    $PageItems = @($Page.value)
    $Items += $PageItems.Count
    foreach ($PageItem in $PageItems) {
        if ($PageItem.shared -and -not $PageItem.deleted) { $SharedItems.Add($PageItem) }
    }
    Write-Host ("  page {0,3}: {1,4} items, {2,6:N0} ms" -f $PageTimes.Count, $PageItems.Count, $PageSw.Elapsed.TotalMilliseconds)
    $Uri = if ($Page.'@odata.deltaLink') { $null } else { [string]$Page.'@odata.nextLink' }
}
$TotalSw.Stop()
$Sorted = @($PageTimes | Sort-Object)
$AvgPage = ($PageTimes | Measure-Object -Average).Average
$P50 = $Sorted[[Math]::Floor($Sorted.Count * 0.5)]
$P95 = $Sorted[[Math]::Min([Math]::Floor($Sorted.Count * 0.95), $Sorted.Count - 1)]
$ItemsPerPage = if ($PageTimes.Count -gt 0) { $Items / $PageTimes.Count } else { 0 }

Write-Host ''
Write-Host ('Phase A (delta): {0:N0} items, {1} shared, {2} pages in {3:N1}s' -f $Items, $SharedItems.Count, $PageTimes.Count, $TotalSw.Elapsed.TotalSeconds)
Write-Host ('  page ms  avg {0:N0} / p50 {1:N0} / p95 {2:N0}; items/page avg {3:N0}; items/s {4:N0}' -f $AvgPage, $P50, $P95, $ItemsPerPage, ($Items / $TotalSw.Elapsed.TotalSeconds))

# --- Phase B: permission batches ---------------------------------------------------------------
$BatchSeconds = $null
$PermBatches = 0
if ($SharedItems.Count -gt 0) {
    $RequestId = 0
    $PermissionRequests = foreach ($SharedItem in $SharedItems) {
        @{ id = "$RequestId"; method = 'GET'; url = "drives/$DriveId/items/$($SharedItem.id)/permissions" }
        $RequestId++
    }
    $PermSw = [System.Diagnostics.Stopwatch]::StartNew()
    $Responses = New-GraphBulkRequest -tenantid $TenantFilter -Requests @($PermissionRequests) -asapp $true
    $PermSw.Stop()
    $PermBatches = [Math]::Ceiling($SharedItems.Count / 20)
    $BatchSeconds = $PermSw.Elapsed.TotalSeconds / $PermBatches
    $OkCount = @($Responses | Where-Object { -not $_.status -or $_.status -eq 200 }).Count
    $ThrottledCount = @($Responses | Where-Object { $_.status -eq 429 }).Count
    Write-Host ''
    Write-Host ('Phase B (permissions): {0} items in {1} batches of 20, {2:N1}s total, {3:N2}s/batch ({4} ok, {5} throttled-and-dropped)' -f `
            $SharedItems.Count, $PermBatches, $PermSw.Elapsed.TotalSeconds, $BatchSeconds, $OkCount, $ThrottledCount)
} else {
    Write-Host 'Phase B skipped: no shared items found.'
}

# --- Phase C: real activity end-to-end ---------------------------------------------------------
if ($RunActivity) {
    if (-not $Site) { throw '-RunActivity needs -SiteUrl (site context for the activity payload).' }
    foreach ($Module in 'CIPPDB', 'CIPPActivityTriggers') {
        if (-not (Get-Module $Module)) { Import-Module (Join-Path $env:CIPPRootPath "Modules\$Module") -Force }
    }
    $ScanId = [guid]::NewGuid().ToString()
    $StateTable = Get-CippTable -tablename 'CippSharingLinksState'
    Add-CIPPAzDataTableEntity @StateTable -Entity @{
        PartitionKey = $TenantFilter
        RowKey       = 'scan'
        ScanId       = $ScanId
        PendingSites = 1
        TotalSites   = 1
        FailedSites  = '[]'
        FullSweep    = $false
        StartedUtc   = [string]([DateTimeOffset]::UtcNow.ToString('o'))
    } -Force

    $Domains = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/domains?`$select=id,isVerified" -tenantid $TenantFilter -asapp $true
    $Item = [PSCustomObject]@{
        TenantFilter    = $TenantFilter
        SiteId          = $Site.id
        SiteName        = $Site.displayName
        SiteUrl         = $SiteUrl
        IsPersonalSite  = $false
        InternalDomains = @(@($Domains | Where-Object { $_.isVerified }).id)
        ScanId          = $ScanId
        ForceFull       = $true
    }
    Write-Host ''
    Write-Host "Phase C: running Push-DBCacheSharePointSiteSharingLinks end-to-end (scan $ScanId)..."
    $ActSw = [System.Diagnostics.Stopwatch]::StartNew()
    $null = Push-DBCacheSharePointSiteSharingLinks -Item $Item
    $ActSw.Stop()
    Write-Host ('Phase C (full site activity incl. table writes + finalisation): {0:N1}s' -f $ActSw.Elapsed.TotalSeconds)
}

# --- Projection --------------------------------------------------------------------------------
Write-Host ''
Write-Host "=== Projection against the ${BudgetSeconds}s activity budget ==="
$PageSec = $AvgPage / 1000
$ShareRatio = if ($Items -gt 0) { $SharedItems.Count / $Items } else { 0.05 }
$BatchSec = $BatchSeconds ?? 1.0
Write-Host ('  model: {0:N2}s/page ({1:N0} items/page), {2:N2}s/permission-batch, {3:P1} items shared' -f $PageSec, $ItemsPerPage, $BatchSec, $ShareRatio)
Write-Host ''
Write-Host ('  {0,12} {1,10} {2,12} {3,14} {4,12}' -f 'items', 'pages', 'perm-batches', 'est wall (min)', 'vs budget')
foreach ($N in 10000, 25000, 50000, 100000, 250000, 500000, 1000000, 2000000, 5000000) {
    $Pages = [Math]::Ceiling($N / [Math]::Max($ItemsPerPage, 1))
    $Batches = [Math]::Ceiling(($N * $ShareRatio) / 20)
    $Est = $Pages * $PageSec + $Batches * $BatchSec
    $Flag = if ($Est -gt $BudgetSeconds) { 'OVER' } elseif ($Est -gt $BudgetSeconds * 0.75) { 'at risk' } else { 'ok' }
    Write-Host ('  {0,12:N0} {1,10:N0} {2,12:N0} {3,14:N1} {4,12}' -f $N, $Pages, $Batches, ($Est / 60), $Flag)
}
$MaxItems = [Math]::Floor($BudgetSeconds / ($PageSec / [Math]::Max($ItemsPerPage, 1) + $ShareRatio / 20 * $BatchSec))
Write-Host ''
Write-Host ('  -> one activity can scan roughly {0:N0} items inside {1}s at this share ratio (no throttling headroom included)' -f $MaxItems, $BudgetSeconds)

[PSCustomObject]@{
    DriveId          = $DriveId
    Items            = $Items
    SharedItems      = $SharedItems.Count
    Pages            = $PageTimes.Count
    AvgPageMs        = [Math]::Round($AvgPage, 0)
    P95PageMs        = [Math]::Round($P95, 0)
    ItemsPerPage     = [Math]::Round($ItemsPerPage, 0)
    SecPerPermBatch  = if ($BatchSeconds) { [Math]::Round($BatchSeconds, 2) } else { $null }
    MaxItemsInBudget = $MaxItems
}
