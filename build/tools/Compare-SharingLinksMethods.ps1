<#
.SYNOPSIS
    Benchmarks alternative ways to collect SharePoint sharing-link data for the report
    cache, against the same drive, and reports requests + wall time per method.

.DESCRIPTION
    Methods compared (full-scan collection for one document library):

      A. delta + permissions-for-all-shared  (current Push-DBCacheSharePointSiteSharingLinks
         shape). On group-connected team sites every item carries the shared facet, so this
         permission-reads EVERY item: items/20 $batch requests.

      B. list-items PrincipalCount pre-filter + permissions-for-flagged. Enumerates
         /sites/{sid}/lists/{lid}/items with $expand=fields($select=...,PrincipalCount).
         An item whose PrincipalCount exceeds the list's inherited baseline has extra role
         assignments - i.e. a sharing link or unique grant. Only those items get a
         $batch driveItem?$expand=permissions read (metadata + permissions in one call).

      C. Graph Search API discovery (informational): KQL queries for user-specific,
         external and anonymous shares. Cheap but cannot see organization-scope links,
         and depends on index freshness - reported for completeness.

    Requires a dev session: dot-source build/tools/Initialize-DevEnvironment.ps1 first.

.EXAMPLE
    ./Compare-SharingLinksMethods.ps1 -TenantFilter zacgoose.onmicrosoft.com -SiteUrl https://zacgoose.sharepoint.com/sites/ZacRichards -LibraryName CippSharingPerfTest -SearchRegion AUS
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantFilter,

    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [string]$LibraryName = 'CippSharingPerfTest',

    # Graph Search app-only requires the tenant's region (the API error names the right one).
    [string]$SearchRegion = 'AUS',

    [switch]$SkipMethodA
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-GraphToken -ErrorAction SilentlyContinue)) {
    throw 'Dev session not initialized. Dot-source build/tools/Initialize-DevEnvironment.ps1 first.'
}

$SiteUri = [uri]$SiteUrl
$SitePath = $SiteUri.AbsolutePath.TrimEnd('/')
$SiteLookup = if ([string]::IsNullOrEmpty($SitePath)) { $SiteUri.Host } else { "$($SiteUri.Host):$SitePath" }
$Site = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$SiteLookup" -tenantid $TenantFilter -asapp $true
$Lists = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/lists?`$filter=displayName eq '$LibraryName'" -tenantid $TenantFilter -asapp $true
$List = @($Lists) | Where-Object { $_.displayName -eq $LibraryName } | Select-Object -First 1
if (-not $List) { throw "Library '$LibraryName' not found." }
$Drive = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/sites/$($Site.id)/lists/$($List.id)/drive?`$select=id,name" -tenantid $TenantFilter -asapp $true
Write-Host "Site $($Site.id)"
Write-Host "List $($List.id), Drive $($Drive.id)"
$Results = [System.Collections.Generic.List[object]]::new()

# ---- Method A: delta + permissions for every shared-facet item --------------------------------
if (-not $SkipMethodA) {
    Write-Host ''
    Write-Host '--- Method A: delta + permissions for all shared-facet items (current) ---'
    $DeltaSelect = 'id,name,webUrl,folder,shared,deleted,size,lastModifiedDateTime'
    $Uri = "https://graph.microsoft.com/beta/drives/$($Drive.id)/root/delta?`$select=$DeltaSelect&`$top=999"
    $Sw = [System.Diagnostics.Stopwatch]::StartNew()
    $Pages = 0
    $Items = 0
    $SharedIds = [System.Collections.Generic.List[string]]::new()
    while ($Uri) {
        $Page = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -asapp $true -noPagination $true -SkipValueExtraction
        $Pages++
        foreach ($PageItem in @($Page.value)) {
            if ($PageItem.name -eq 'root') { continue }
            $Items++
            if ($PageItem.shared -and -not $PageItem.deleted) { $SharedIds.Add([string]$PageItem.id) }
        }
        $Uri = if ($Page.'@odata.deltaLink') { $null } else { [string]$Page.'@odata.nextLink' }
    }
    $DeltaSeconds = $Sw.Elapsed.TotalSeconds

    $RequestId = 0
    $PermRequests = foreach ($ItemId in $SharedIds) {
        @{ id = "$RequestId"; method = 'GET'; url = "drives/$($Drive.id)/items/$ItemId/permissions" }
        $RequestId++
    }
    $PermSw = [System.Diagnostics.Stopwatch]::StartNew()
    $PermResponses = @(New-GraphBulkRequest -tenantid $TenantFilter -Requests @($PermRequests) -asapp $true)
    $PermSw.Stop()
    $Sw.Stop()
    $LinkRows = 0
    foreach ($Response in $PermResponses) {
        if ($Response.status -and $Response.status -ne 200) { continue }
        $LinkRows += @($Response.body.value | Where-Object { $_.link -and -not $_.inheritedFrom }).Count
    }
    $BatchCount = [Math]::Ceiling($SharedIds.Count / 20)
    $Results.Add([PSCustomObject]@{
            Method       = 'A: delta + perms for all shared'
            Items        = $Items
            PermTargets  = $SharedIds.Count
            LinkPerms    = $LinkRows
            Requests     = $Pages + $BatchCount
            EnumSeconds  = [Math]::Round($DeltaSeconds, 1)
            PermSeconds  = [Math]::Round($PermSw.Elapsed.TotalSeconds, 1)
            TotalSeconds = [Math]::Round($Sw.Elapsed.TotalSeconds, 1)
        })
    Write-Host ("  items {0}, perm-targets {1}, {2} delta pages + {3} batches, {4:N1}s (delta {5:N1}s + perms {6:N1}s)" -f `
            $Items, $SharedIds.Count, $Pages, $BatchCount, $Sw.Elapsed.TotalSeconds, $DeltaSeconds, $PermSw.Elapsed.TotalSeconds)
}

# ---- Method B: list-items PrincipalCount pre-filter -------------------------------------------
Write-Host ''
Write-Host '--- Method B: list-items PrincipalCount pre-filter + perms for flagged ---'
$Uri = "https://graph.microsoft.com/v1.0/sites/$($Site.id)/lists/$($List.id)/items?`$top=999&`$select=id&`$expand=fields(`$select=FileLeafRef,FileRef,PrincipalCount)"
$Sw = [System.Diagnostics.Stopwatch]::StartNew()
$Pages = 0
$Items = 0
$Rows = [System.Collections.Generic.List[object]]::new()
while ($Uri) {
    $Page = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -asapp $true -noPagination $true -SkipValueExtraction
    $Pages++
    foreach ($ListItem in @($Page.value)) {
        $Items++
        $Rows.Add([PSCustomObject]@{ FileRef = [string]$ListItem.fields.FileRef; PrincipalCount = [int]$ListItem.fields.PrincipalCount })
    }
    $Uri = [string]$Page.'@odata.nextLink'
}
$EnumSeconds = $Sw.Elapsed.TotalSeconds

# Baseline = the list's dominant (inherited) principal count; anything above it has extra
# role assignments. Items BELOW the mode (rare custom-permission cases) are read too.
$Mode = ($Rows | Group-Object PrincipalCount | Sort-Object Count -Descending | Select-Object -First 1).Name
$Flagged = @($Rows | Where-Object { [string]$_.PrincipalCount -ne $Mode })
Write-Host ("  enumerated {0} items in {1} pages / {2:N1}s; baseline PrincipalCount={3}; flagged {4}" -f $Items, $Pages, $EnumSeconds, $Mode, $Flagged.Count)

# Permissions + metadata in one batched call per flagged item, addressed by server-relative path.
$SitePathLength = ([uri]$SiteUrl).AbsolutePath.TrimEnd('/').Length
$RequestId = 0
$PermRequests = foreach ($FlaggedItem in $Flagged) {
    # FileRef is server-relative (/sites/x/Lib/folder/file); drive addressing wants the
    # path relative to the drive root, so strip "/sites/x/<libraryUrlSegment>/".
    $DriveRelative = $FlaggedItem.FileRef.Substring($SitePathLength).TrimStart('/')
    $DriveRelative = ($DriveRelative -split '/', 2)[1]
    if (-not $DriveRelative) { continue }
    $Encoded = ($DriveRelative -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    @{ id = "$RequestId"; method = 'GET'; url = "drives/$($Drive.id)/root:/${Encoded}?`$select=id,name,size,webUrl,lastModifiedDateTime,folder&`$expand=permissions" }
    $RequestId++
}
$PermSw = [System.Diagnostics.Stopwatch]::StartNew()
$PermResponses = if (@($PermRequests).Count -gt 0) { @(New-GraphBulkRequest -tenantid $TenantFilter -Requests @($PermRequests) -asapp $true) } else { @() }
$PermSw.Stop()
$Sw.Stop()
$LinkRows = 0
foreach ($Response in $PermResponses) {
    if ($Response.status -and $Response.status -ne 200) { continue }
    $LinkRows += @($Response.body.permissions | Where-Object { $_.link -and -not $_.inheritedFrom }).Count
}
$BatchCount = [Math]::Ceiling([Math]::Max(@($PermRequests).Count, 1) / 20)
$Results.Add([PSCustomObject]@{
        Method       = 'B: PrincipalCount pre-filter'
        Items        = $Items
        PermTargets  = $Flagged.Count
        LinkPerms    = $LinkRows
        Requests     = $Pages + $BatchCount
        EnumSeconds  = [Math]::Round($EnumSeconds, 1)
        PermSeconds  = [Math]::Round($PermSw.Elapsed.TotalSeconds, 1)
        TotalSeconds = [Math]::Round($Sw.Elapsed.TotalSeconds, 1)
    })
Write-Host ("  perm-read {0} flagged items in {1} batches / {2:N1}s; {3} link permissions found; total {4:N1}s" -f `
        $Flagged.Count, $BatchCount, $PermSw.Elapsed.TotalSeconds, $LinkRows, $Sw.Elapsed.TotalSeconds)

# ---- Method C: Graph Search discovery (informational) -----------------------------------------
Write-Host ''
Write-Host '--- Method C: Graph Search API discovery (informational) ---'
foreach ($Query in @(
        @{ Label = 'user-specific shares'; KQL = "SharedWithUsersOWSUSER:* path:$SiteUrl" },
        @{ Label = 'external-viewable'; KQL = "ViewableByExternalUsers:true path:$SiteUrl" },
        @{ Label = 'anonymous-viewable'; KQL = "ViewableByAnonymousUsers:true path:$SiteUrl" }
    )) {
    $Body = @{ requests = @(@{ entityTypes = @('driveItem'); query = @{ queryString = $Query.KQL }; from = 0; size = 25; region = $SearchRegion }) } | ConvertTo-Json -Depth 8 -Compress
    try {
        $Sw = [System.Diagnostics.Stopwatch]::StartNew()
        $SearchResult = New-GraphPOSTRequest -uri 'https://graph.microsoft.com/v1.0/search/query' -tenantid $TenantFilter -asApp $true -type POST -body $Body
        $Sw.Stop()
        $Container = if ($SearchResult.hitsContainers) { $SearchResult.hitsContainers[0] } else { $SearchResult.value[0].hitsContainers[0] }
        Write-Host ("  [{0}] total={1} ({2:N0} ms) - org-scope links are NOT visible to search" -f $Query.Label, $Container.total, $Sw.Elapsed.TotalMilliseconds)
    } catch {
        Write-Host ("  [{0}] FAILED: {1}" -f $Query.Label, $_.Exception.Message)
    }
}

Write-Host ''
$Results | Format-Table -AutoSize
$Results
