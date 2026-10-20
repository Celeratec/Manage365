# Pester tests for site recycle bin list, summary, and empty.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $SharePointDir = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint'
    $RecycleDir = Join-Path $RepoRoot 'Modules/CIPPCore/Public/SharePoint/RecycleBin'

    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
    }
    $Accelerators = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not ('HttpStatusCode' -as [type])) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Resolve-CIPPSharePointRestContext {
        param($TenantFilter, $SiteUrl)
        [PSCustomObject]@{
            Scope   = 'https://contoso.sharepoint.com/.default'
            Headers = @{ Accept = 'application/json;odata=nometadata' }
            BaseUri = 'https://contoso.sharepoint.com/sites/a/_api'
            SiteUrl = 'https://contoso.sharepoint.com/sites/a'
            WebUri  = 'https://contoso.sharepoint.com/sites/a/_api/web'
        }
    }
    function Write-LogMessage { param($Headers, $API, $tenant, $message, $sev, $LogData) $script:Logs += $message }
    function Get-CippException { param($Exception) [PSCustomObject]@{ NormalizedError = $Exception.Message } }

    function script:New-RecycleItem {
        param([string]$Id, [int]$State, [int64]$Size = 1)
        [PSCustomObject]@{
            Id            = $Id
            Size          = $Size
            ItemState     = $State
            Title         = "title-$Id"
            LeafName      = "leaf-$Id"
            DirName       = 'Shared Documents'
            ItemType      = 1
            DeletedByName = 'Ada'
            DeletedDate   = '2026-01-01T00:00:00Z'
        }
    }

    function script:Reset-RecycleBin {
        param([object[]]$Items, [string]$Mode = 'Move')
        $script:Bin = [System.Collections.Generic.List[object]]::new()
        foreach ($Item in @($Items)) { $script:Bin.Add($Item) }
        $script:DeleteMode = $Mode
        $script:PartialRemoved = $false
        $script:DeleteCalls = [System.Collections.Generic.List[object]]::new()
        $script:GetUris = [System.Collections.Generic.List[string]]::new()
        $script:PostUris = [System.Collections.Generic.List[string]]::new()
        $script:GraphPostCalls = 0
        $script:Logs = [System.Collections.Generic.List[string]]::new()
    }

    . (Join-Path $RecycleDir 'Get-CIPPSiteRecycleBinItems.ps1')
    . (Join-Path $RecycleDir 'Invoke-CIPPEmptySiteRecycleBin.ps1')
    . (Join-Path $SharePointDir 'Invoke-ExecEmptySiteRecycleBin.ps1')
    . (Join-Path $SharePointDir 'Invoke-ListSiteRecycleBin.ps1')
    . (Join-Path $SharePointDir 'Invoke-ListSiteRecycleBinSummary.ps1')
    . (Join-Path $SharePointDir 'Invoke-ListEmptySiteRecycleBinStatus.ps1')

    function script:Read-MockRecycleBinPage {
        param([string]$uri)
        $script:GetUris.Add($uri)
        if ($uri -notmatch 'GetRecycleBinItems') { throw "Unexpected recycle uri: $uri" }
        $State = 1
        $Row = 200
        $Paging = ''
        if ($uri -match 'itemState=(\d+)') { $State = [int]$Matches[1] }
        if ($uri -match 'rowLimit=(\d+)') { $Row = [int]$Matches[1] }
        if ($uri -match "pagingInfo='([^']*)'") { $Paging = $Matches[1] }

        $All = @($script:Bin | Where-Object { [int]$_.ItemState -eq $State })
        $Start = 0
        if ($Paging) {
            for ($i = 0; $i -lt $All.Count; $i++) {
                if ([string]$All[$i].Id -eq $Paging) { $Start = $i + 1; break }
            }
        }
        $Slice = @()
        if ($Start -lt $All.Count) {
            $End = [Math]::Min($Start + $Row, $All.Count) - 1
            $Slice = @($All[$Start..$End])
        }
        $Next = ''
        if ($Slice.Count -gt 0 -and ($Start + $Slice.Count) -lt $All.Count) {
            $Next = [string]$Slice[-1].Id
        }
        [PSCustomObject]@{
            value      = $Slice
            PagingInfo = $Next
        }
    }

    function global:New-GraphGetRequest {
        param(
            $uri, $tenantid, $scope, $AsApp, $extraHeaders,
            [switch]$UseCertificate,
            [bool]$noPagination,
            [switch]$SkipValueExtraction
        )
        throw "GetRecycleBinItems must be posted, not read with GET: $uri"
    }

    function global:New-GraphPostRequest {
        param(
            $uri, $tenantid, $scope, $type, $body, $contentType, $AddedHeaders,
            [switch]$UseCertificate,
            $AsApp
        )
        $script:PostUris.Add([string]$uri)
        $script:GraphPostCalls++
        if ($uri -match 'GetRecycleBinItems') {
            if ($type -ne 'POST') { throw "GetRecycleBinItems type was '$type'" }
            return Read-MockRecycleBinPage -uri ([string]$uri)
        }
        if ($uri -match 'deleteAll|web/RecycleBin') { throw "Refusing no-op recycle endpoint: $uri" }
        $Parsed = $body | ConvertFrom-Json
        $Ids = @($Parsed.ids)
        $CallStage = 'Second'
        foreach ($Id in $Ids) {
            $Existing = $script:Bin | Where-Object { [string]$_.Id -eq [string]$Id } | Select-Object -First 1
            if ($Existing -and [int]$Existing.ItemState -eq 1) { $CallStage = 'First'; break }
        }
        $script:DeleteCalls.Add([PSCustomObject]@{ Stage = $CallStage; Ids = @($Ids) })
        if ($script:DeleteMode -eq 'Noop') { return }
        if ($script:DeleteMode -eq 'Partial') {
            if ($script:PartialRemoved) { return }
            $Target = [string]$Ids[0]
            $Item = $script:Bin | Where-Object { [string]$_.Id -eq $Target } | Select-Object -First 1
            if ($Item) { [void]$script:Bin.Remove($Item) }
            $script:PartialRemoved = $true
            return
        }
        foreach ($Id in $Ids) {
            $Item = $script:Bin | Where-Object { [string]$_.Id -eq [string]$Id } | Select-Object -First 1
            if (-not $Item) { continue }
            if ([int]$Item.ItemState -eq 1) {
                $Item.ItemState = 2
            } else {
                [void]$script:Bin.Remove($Item)
            }
        }
    }
}

function script:New-EmptyRequest {
    param([string]$Stage = 'Both')
    [pscustomobject]@{
        Params  = @{ CIPPEndpoint = 'ExecEmptySiteRecycleBin' }
        Headers = @{}
        Body    = [pscustomobject]@{
            tenantFilter = 'contoso.onmicrosoft.com'
            SiteUrl      = 'https://contoso.sharepoint.com/sites/a'
            Stage        = $Stage
        }
    }
}

Describe 'Invoke-ExecEmptySiteRecycleBin' {
    It 'returns BadRequest when SiteUrl is missing' {
        Reset-RecycleBin @()
        $Response = Invoke-ExecEmptySiteRecycleBin -Request ([pscustomobject]@{
                Params  = @{ CIPPEndpoint = 'ExecEmptySiteRecycleBin' }
                Headers = @{}
                Body    = [pscustomobject]@{ tenantFilter = 'contoso.onmicrosoft.com'; Stage = 'Both' }
            })
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
    }

    It 'returns BadRequest for invalid Stage' {
        Reset-RecycleBin @()
        $Response = Invoke-ExecEmptySiteRecycleBin -Request ([pscustomobject]@{
                Params  = @{ CIPPEndpoint = 'ExecEmptySiteRecycleBin' }
                Headers = @{}
                Body    = [pscustomobject]@{
                    tenantFilter = 'contoso.onmicrosoft.com'
                    SiteUrl      = 'https://contoso.sharepoint.com/sites/a'
                    Stage        = 'Nope'
                }
            })
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'Invalid Stage'
    }

    It 'fails a no-op delete instead of reporting the bin emptied' {
        Reset-RecycleBin -Mode 'Noop' -Items @(
            (New-RecycleItem -Id 'a' -State 1 -Size 10)
            (New-RecycleItem -Id 'b' -State 1 -Size 20)
        )
        $Response = Invoke-ExecEmptySiteRecycleBin -Request (New-EmptyRequest)
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::InternalServerError)
        $Response.Body.Results | Should -Not -Match 'Emptied'
        $Response.Body.deletedCount | Should -Be 0
        $Response.Body.remainingFirst | Should -Be 2
        $script:PostUris | Should -Not -BeNullOrEmpty
        @($script:PostUris | Where-Object { $_ -match 'deleteAll|web/RecycleBin' }).Count | Should -Be 0
        @($script:PostUris | Where-Object { $_ -match 'site/RecycleBin/DeleteByIds' }).Count | Should -BeGreaterThan 0
    }

    It 'deletes first stage then second stage and only then says emptied' {
        Reset-RecycleBin -Items @(
            (New-RecycleItem -Id 'first-item' -State 1 -Size 10)
            (New-RecycleItem -Id 'second-item' -State 2 -Size 20)
        )
        $Response = Invoke-ExecEmptySiteRecycleBin -Request (New-EmptyRequest)
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $Response.Body.Results | Should -Match 'Emptied recycle bin \(Both\)'
        $Response.Body.deletedCount | Should -Be 2
        $Response.Body.deletedBytes | Should -Be 30
        $Response.Body.remainingFirst | Should -Be 0
        $Response.Body.remainingSecond | Should -Be 0
        $Response.Body.emptied | Should -BeTrue
        @($script:DeleteCalls | Where-Object Stage -eq 'First').Ids | Should -Be @('first-item')
        $SecondIds = @(@($script:DeleteCalls | Where-Object Stage -eq 'Second') | ForEach-Object { $_.Ids })
        $SecondIds | Should -Contain 'first-item'
        $SecondIds | Should -Contain 'second-item'
        ($script:Logs -join "`n") | Should -Match 'stage=First'
        ($script:Logs -join "`n") | Should -Match 'stage=Second'
    }

    It 'returns partial when some items remain' {
        Reset-RecycleBin -Mode 'Partial' -Items @(
            (New-RecycleItem -Id 'gone' -State 1 -Size 5)
            (New-RecycleItem -Id 'stays' -State 1 -Size 7)
        )
        $Response = Invoke-ExecEmptySiteRecycleBin -Request (New-EmptyRequest)
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::MultiStatus)
        $Response.Body.Results | Should -Not -Match 'Emptied'
        $Response.Body.deletedCount | Should -Be 1
        $Response.Body.remainingFirst | Should -Be 1
        $Response.Body.emptied | Should -BeFalse
    }

    It 'queues a bin larger than the inline limit without calling DeleteByIds' {
        $Items = foreach ($Number in 1..251) { New-RecycleItem -Id ('item-{0:D4}' -f $Number) -State 1 -Size 1 }
        Reset-RecycleBin -Items $Items
        function global:New-CippQueueEntry { param($Name, $Link, $Reference, $TotalTasks) @{ RowKey = 'queue-1' } }
        function global:Add-CippQueueMessage { param($Cmdlet, $Parameters) $script:QueuedCmdlet = $Cmdlet; $script:QueuedParameters = $Parameters; $true }

        $Response = Invoke-ExecEmptySiteRecycleBin -Request (New-EmptyRequest)
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $Response.Body.Queued | Should -BeTrue
        $Response.Body.QueueId | Should -Be 'queue-1'
        $Response.Body.Results | Should -Not -Match 'Emptied'
        $script:QueuedCmdlet | Should -Be 'Start-CIPPEmptySiteRecycleBin'
        @($script:PostUris | Where-Object { $_ -match 'DeleteByIds' }).Count | Should -Be 0
        @($script:PostUris | Where-Object { $_ -match 'GetRecycleBinItems' }).Count | Should -BeGreaterThan 0
    }
}

Describe 'Invoke-CIPPEmptySiteRecycleBin paging' {
    It 'deletes more than 500 items across pages and both stages' {
        $Items = foreach ($Number in 1..501) { New-RecycleItem -Id ('id-{0:D4}' -f $Number) -State 1 -Size 2 }
        Reset-RecycleBin -Items $Items
        $Context = Resolve-CIPPSharePointRestContext -TenantFilter 'contoso.onmicrosoft.com' -SiteUrl 'https://contoso.sharepoint.com/sites/a'
        $Result = Invoke-CIPPEmptySiteRecycleBin -TenantFilter 'contoso.onmicrosoft.com' -SiteUrl 'https://contoso.sharepoint.com/sites/a' -RestContext $Context -Stage 'Both'

        $Result.Outcome | Should -Be 'Empty'
        $Result.deletedCount | Should -Be 501
        $Result.deletedBytes | Should -Be 1002
        $Result.remainingFirst | Should -Be 0
        $Result.remainingSecond | Should -Be 0

        $FirstCalls = @($script:DeleteCalls | Where-Object Stage -eq 'First')
        $SecondCalls = @($script:DeleteCalls | Where-Object Stage -eq 'Second')
        $FirstCalls.Count | Should -Be 11
        $FirstCalls[0].Ids.Count | Should -Be 50
        $FirstCalls[-1].Ids.Count | Should -Be 1
        $FirstIds = @(foreach ($Call in $FirstCalls) { $Call.Ids })
        $SecondIds = @(foreach ($Call in $SecondCalls) { $Call.Ids })
        @($FirstIds | Select-Object -Unique).Count | Should -Be 501
        @($SecondIds | Select-Object -Unique).Count | Should -Be 501
        $SecondIds | Should -Contain 'id-0001'
        $SecondIds | Should -Contain 'id-0501'

        $SeenSecond = $false
        foreach ($Call in $script:DeleteCalls) {
            if ($Call.Stage -eq 'Second') { $SeenSecond = $true }
            if ($SeenSecond -and $Call.Stage -eq 'First') { throw 'First-stage delete ran after the second stage.' }
        }
    }
}

Describe 'Invoke-ListSiteRecycleBinSummary' {
    It 'returns BadRequest when SiteUrl is missing' {
        Reset-RecycleBin @()
        $Response = Invoke-ListSiteRecycleBinSummary -Request ([pscustomobject]@{
                Params  = @{ CIPPEndpoint = 'ListSiteRecycleBinSummary' }
                Headers = @{}
                Query   = @{ tenantFilter = 'contoso.onmicrosoft.com' }
                Body    = @{}
            })
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
    }

    It 'aggregates sizes without returning names' {
        Reset-RecycleBin -Items @(
            (New-RecycleItem -Id '1' -State 1 -Size 100)
            (New-RecycleItem -Id '2' -State 2 -Size 50)
        )
        $Response = Invoke-ListSiteRecycleBinSummary -Request ([pscustomobject]@{
                Params  = @{ CIPPEndpoint = 'ListSiteRecycleBinSummary' }
                Headers = @{}
                Query   = @{
                    tenantFilter = 'contoso.onmicrosoft.com'
                    SiteUrl      = 'https://contoso.sharepoint.com/sites/a'
                }
                Body    = @{}
            })
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $Response.Body.Results.totalBytes | Should -Be 150
        $Response.Body.Results.firstStageBytes | Should -Be 100
        $Response.Body.Results.secondStageBytes | Should -Be 50
        $Response.Body.Results.capped | Should -BeFalse
        ($Response.Body.Results.PSObject.Properties.Name -contains 'Title') | Should -BeFalse
        ($Response.Body.Results.PSObject.Properties.Name -contains 'LeafName') | Should -BeFalse
    }

    It 'pages past 500 items and leaves capped false' {
        $Items = foreach ($Number in 1..501) { New-RecycleItem -Id ('sum-{0:D4}' -f $Number) -State 1 -Size 3 }
        Reset-RecycleBin -Items $Items
        $Response = Invoke-ListSiteRecycleBinSummary -Request ([pscustomobject]@{
                Params  = @{ CIPPEndpoint = 'ListSiteRecycleBinSummary' }
                Headers = @{}
                Query   = @{
                    tenantFilter = 'contoso.onmicrosoft.com'
                    SiteUrl      = 'https://contoso.sharepoint.com/sites/a'
                }
                Body    = @{}
            })
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        $Response.Body.Results.itemCount | Should -Be 501
        $Response.Body.Results.totalBytes | Should -Be 1503
        $Response.Body.Results.capped | Should -BeFalse
        $Response.Body.Results.scannedItems | Should -Be 501
        @($script:GetUris | Where-Object { $_ -match 'itemState=1' }).Count | Should -BeGreaterThan 1
    }

    It 'sets capped when the scan stops before the bin is exhausted' {
        $Items = foreach ($Number in 1..501) { New-RecycleItem -Id ('cap-{0:D4}' -f $Number) -State 1 -Size 1 }
        Reset-RecycleBin -Items $Items
        $Response = Invoke-ListSiteRecycleBinSummary -Request ([pscustomobject]@{
                Params  = @{ CIPPEndpoint = 'ListSiteRecycleBinSummary' }
                Headers = @{}
                Query   = @{
                    tenantFilter = 'contoso.onmicrosoft.com'
                    SiteUrl      = 'https://contoso.sharepoint.com/sites/a'
                    MaxItems     = 500
                }
                Body    = @{}
            })
        $Response.Body.Results.capped | Should -BeTrue
        $Response.Body.Results.scannedItems | Should -Be 500
        $Response.Body.Results.itemCount | Should -Be 500
    }
}

Describe 'Invoke-ListSiteRecycleBin' {
    It 'pages past 500 and reports capped from the server' {
        $Items = foreach ($Number in 1..501) { New-RecycleItem -Id ('list-{0:D4}' -f $Number) -State 1 -Size 4 }
        Reset-RecycleBin -Items $Items
        $Response = Invoke-ListSiteRecycleBin -Request ([pscustomobject]@{
                Params  = @{ CIPPEndpoint = 'ListSiteRecycleBin' }
                Headers = @{}
                Query   = @{
                    tenantFilter = 'contoso.onmicrosoft.com'
                    SiteUrl      = 'https://contoso.sharepoint.com/sites/a'
                }
                Body    = @{}
            })
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        @($Response.Body.Results).Count | Should -Be 501
        $Response.Body.capped | Should -BeFalse
        $Response.Body.scannedItems | Should -Be 501
        $Response.Body.Results[0].LeafName | Should -Be 'leaf-list-0001'

        $Capped = Invoke-ListSiteRecycleBin -Request ([pscustomobject]@{
                Params  = @{ CIPPEndpoint = 'ListSiteRecycleBin' }
                Headers = @{}
                Query   = @{
                    tenantFilter = 'contoso.onmicrosoft.com'
                    SiteUrl      = 'https://contoso.sharepoint.com/sites/a'
                    MaxItems     = 500
                }
                Body    = @{}
            })
        $Capped.Body.capped | Should -BeTrue
        $Capped.Body.scannedItems | Should -Be 500
        @($Capped.Body.Results).Count | Should -Be 500
    }
}
