<#
.SYNOPSIS
    Seeds a SharePoint document library with many small files (and sharing links on a
    fraction of them) to measure sharing-links scan performance on large drives.

.DESCRIPTION
    Dev tool for sizing the SharePoint sharing-links cache fan-out
    (Set-CIPPDBCacheSharePointSharingLinks / Push-DBCacheSharePointSiteSharingLinks).

    Creates (or reuses) a dedicated document library on the target site, uploads
    -FileCount small text files into per-500-file subfolders with a shared pooled
    HttpClient (parallel PUTs, Retry-After-aware), then creates an organization-scope
    view link on every -ShareEvery'th file so the scan's permission-read phase has
    realistic work to do.

    Idempotent: file names are deterministic (file-000001.txt ...), so re-running with a
    larger -FileCount tops the library up; existing files are simply overwritten.

    Requires a dev session: dot-source build/tools/Initialize-DevEnvironment.ps1 first.

    Cleanup: -Cleanup deletes the seed folder (one call), leaving the empty library.

.EXAMPLE
    ./New-SharingLinksTestData.ps1 -TenantFilter zacgoose.onmicrosoft.com -SiteUrl https://zacgoose.sharepoint.com/sites/ZacRichards -FileCount 20000

.EXAMPLE
    ./New-SharingLinksTestData.ps1 -TenantFilter zacgoose.onmicrosoft.com -SiteUrl https://zacgoose.sharepoint.com/sites/ZacRichards -Cleanup
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantFilter,

    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [string]$LibraryName = 'CippSharingPerfTest',

    [int]$FileCount = 5000,

    # First file index to upload (1-based). Lets a large seed run in chunks:
    # -StartIndex 10001 -FileCount 20000 uploads files 10001..20000.
    [int]$StartIndex = 1,

    # Create a sharing link on every Nth file. 20 = 5% of files shared.
    [int]$ShareEvery = 20,

    [int]$Concurrency = 8,

    # Files per subfolder; keeps any single folder from getting huge.
    [int]$FolderSize = 500,

    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-GraphToken -ErrorAction SilentlyContinue)) {
    throw 'Dev session not initialized. Dot-source build/tools/Initialize-DevEnvironment.ps1 first.'
}

# --- resolve site and library ------------------------------------------------------------------
$SiteUri = [uri]$SiteUrl
$SitePath = $SiteUri.AbsolutePath.TrimEnd('/')
$SiteLookup = if ([string]::IsNullOrEmpty($SitePath)) { $SiteUri.Host } else { "$($SiteUri.Host):$SitePath" }
$Site = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteLookup" -tenantid $TenantFilter -asapp $true
Write-Host "Site: $($Site.displayName) ($($Site.id))"

$Lists = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/lists?`$filter=displayName eq '$LibraryName'" -tenantid $TenantFilter -asapp $true
$List = @($Lists) | Where-Object { $_.displayName -eq $LibraryName } | Select-Object -First 1
if (-not $List) {
    if ($Cleanup) { Write-Host "Library '$LibraryName' does not exist; nothing to clean."; return }
    Write-Host "Creating document library '$LibraryName'..."
    $List = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/lists" -tenantid $TenantFilter -asApp $true -type POST -body (@{
            displayName = $LibraryName
            list        = @{ template = 'documentLibrary' }
        } | ConvertTo-Json -Compress)
}
$Drive = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/lists/$($List.id)/drive?`$select=id,name,webUrl" -tenantid $TenantFilter -asapp $true
Write-Host "Drive: $($Drive.id)"

$Token = (Get-GraphToken -tenantid $TenantFilter -AsApp $true).Authorization

if ($Cleanup) {
    Write-Host 'Deleting seed folder...'
    $Handler = [System.Net.Http.HttpClientHandler]::new()
    $Client = [System.Net.Http.HttpClient]::new($Handler)
    try {
        $Req = [System.Net.Http.HttpRequestMessage]::new('DELETE', "https://graph.microsoft.com/v1.0/drives/$($Drive.id)/root:/SeedData")
        $Req.Headers.TryAddWithoutValidation('Authorization', $Token) | Out-Null
        $Resp = $Client.Send($Req)
        Write-Host "Delete returned $([int]$Resp.StatusCode). Library '$LibraryName' kept (empty)."
    } finally { $Client.Dispose() }
    return
}

# --- seed files --------------------------------------------------------------------------------
# One pooled HttpClient shared across parallel workers; each worker PUTs file content and
# retries on 429/503 honoring Retry-After. Item ids are collected for the share step.
$Client = [System.Net.Http.HttpClient]::new()
$Client.Timeout = [TimeSpan]::FromSeconds(100)

$Sw = [System.Diagnostics.Stopwatch]::StartNew()
$AllItems = [System.Collections.Generic.List[object]]::new()
$ChunkSize = 500
$Throttle429 = 0

for ($ChunkStart = $StartIndex; $ChunkStart -le $FileCount; $ChunkStart += $ChunkSize) {
    $ChunkEnd = [Math]::Min($ChunkStart + $ChunkSize - 1, $FileCount)
    $ChunkSw = [System.Diagnostics.Stopwatch]::StartNew()

    $Results = $ChunkStart..$ChunkEnd | ForEach-Object -ThrottleLimit $Concurrency -Parallel {
        $i = $_
        $Client = $using:Client
        $Token = $using:Token
        $DriveId = ($using:Drive).id
        $FolderSize = $using:FolderSize
        $Folder = 'f{0:D4}' -f [int][Math]::Floor(($i - 1) / $FolderSize)
        $Name = 'file-{0:D6}.txt' -f $i
        $Url = "https://graph.microsoft.com/v1.0/drives/$DriveId/root:/SeedData/$Folder/${Name}:/content"
        $Body = "CIPP sharing links perf seed file $i"
        $Attempt = 0
        $Throttled = 0
        while ($true) {
            $Attempt++
            $Req = [System.Net.Http.HttpRequestMessage]::new('PUT', $Url)
            $Req.Headers.TryAddWithoutValidation('Authorization', $Token) | Out-Null
            $Req.Content = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, 'text/plain')
            try {
                $Resp = $Client.Send($Req)
                $Status = [int]$Resp.StatusCode
                if ($Status -in 200, 201) {
                    $Json = $Resp.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
                    [PSCustomObject]@{ Index = $i; ItemId = $Json.id; Throttled = $Throttled }
                    break
                }
                if ($Status -in 429, 503, 504 -and $Attempt -lt 8) {
                    $Throttled++
                    $Wait = 5
                    $Vals = $null
                    if ($Resp.Headers.TryGetValues('Retry-After', [ref]$Vals)) { $Wait = [int](@($Vals)[0]) }
                    Start-Sleep -Seconds ([Math]::Min($Wait, 120))
                    continue
                }
                $ErrBody = $Resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                [PSCustomObject]@{ Index = $i; ItemId = $null; Error = "HTTP ${Status}: $ErrBody"; Throttled = $Throttled }
                break
            } catch {
                if ($Attempt -lt 8) { Start-Sleep -Seconds 5; continue }
                [PSCustomObject]@{ Index = $i; ItemId = $null; Error = $_.Exception.Message; Throttled = $Throttled }
                break
            } finally {
                $Req.Dispose()
            }
        }
    }

    foreach ($R in @($Results)) {
        if ($R.ItemId) { $AllItems.Add($R) } else { Write-Warning "file $($R.Index): $($R.Error)" }
        $Throttle429 += $R.Throttled
    }
    $Rate = [Math]::Round(($ChunkEnd - $ChunkStart + 1) / $ChunkSw.Elapsed.TotalSeconds, 1)
    Write-Host ("  {0}/{1} files  ({2}/s this chunk, {3} 429-retries total, {4:mm\:ss} elapsed)" -f $ChunkEnd, $FileCount, $Rate, $Throttle429, $Sw.Elapsed)
}

Write-Host ("Upload done: {0} files in {1:mm\:ss} ({2}/s overall)" -f $AllItems.Count, $Sw.Elapsed, [Math]::Round($AllItems.Count / $Sw.Elapsed.TotalSeconds, 1))

# --- create sharing links ----------------------------------------------------------------------
$ToShare = @($AllItems | Where-Object { $_.Index % $ShareEvery -eq 0 })
Write-Host "Creating $($ToShare.Count) sharing links (every $($ShareEvery)th file)..."
$ShareSw = [System.Diagnostics.Stopwatch]::StartNew()
$Shared = 0
$ShareResults = $ToShare | ForEach-Object -ThrottleLimit $Concurrency -Parallel {
    $Item = $_
    $Client = $using:Client
    $Token = $using:Token
    $DriveId = ($using:Drive).id
    $Url = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$($Item.ItemId)/createLink"
    $Body = '{"type":"view","scope":"organization"}'
    $Attempt = 0
    while ($true) {
        $Attempt++
        $Req = [System.Net.Http.HttpRequestMessage]::new('POST', $Url)
        $Req.Headers.TryAddWithoutValidation('Authorization', $Token) | Out-Null
        $Req.Content = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, 'application/json')
        try {
            $Resp = $Client.Send($Req)
            $Status = [int]$Resp.StatusCode
            if ($Status -in 200, 201) { $true; break }
            if ($Status -in 429, 503, 504 -and $Attempt -lt 8) {
                $Wait = 5
                $Vals = $null
                if ($Resp.Headers.TryGetValues('Retry-After', [ref]$Vals)) { $Wait = [int](@($Vals)[0]) }
                Start-Sleep -Seconds ([Math]::Min($Wait, 120))
                continue
            }
            Write-Warning "createLink $($Item.Index): HTTP $Status"
            $false; break
        } catch {
            if ($Attempt -lt 8) { Start-Sleep -Seconds 5; continue }
            Write-Warning "createLink $($Item.Index): $($_.Exception.Message)"
            $false; break
        } finally {
            $Req.Dispose()
        }
    }
}
$Shared = @($ShareResults | Where-Object { $_ }).Count
$Client.Dispose()
Write-Host ("Links done: {0}/{1} in {2:mm\:ss} ({3}/s)" -f $Shared, $ToShare.Count, $ShareSw.Elapsed, [Math]::Round($Shared / [Math]::Max($ShareSw.Elapsed.TotalSeconds, 1), 1))

[PSCustomObject]@{
    TenantFilter = $TenantFilter
    SiteId       = $Site.id
    SiteUrl      = $SiteUrl
    DriveId      = $Drive.id
    Files        = $AllItems.Count
    SharedFiles  = $Shared
}
