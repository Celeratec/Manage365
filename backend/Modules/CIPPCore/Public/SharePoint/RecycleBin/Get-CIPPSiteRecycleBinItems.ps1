function Get-CIPPSiteRecycleBinItems {
    <#
    .SYNOPSIS
        Page a SharePoint site collection recycle bin.
    .DESCRIPTION
        Reads /_api/site/GetRecycleBinItems. SharePoint rejects that method as a GET (400).
        It is a POST, with the parameters in the URL. SharePoint's site/RecycleBin list does
        not return @odata.nextLink, so $top paging stops at the first page and reports a full
        bin as complete.

        CSOM argument order, which SharePoint binds by position:
          site/GetRecycleBinItems(pagingInfo, rowLimit, isAscending, orderBy, itemState)
        pagingInfo is the search position. The first page sends null. An empty string, and a
        bare item id, are both ArgumentOutOfRangeException on searchPosition. Later pages send
        the form id, title, and searchValue. orderBy 0 is the default (Title). itemState 1 is
        the first stage and 2 is the second stage.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [string]$SiteUrl,

        [object]$RestContext,

        [ValidateRange(0, 2)]
        [int]$ItemState = 0,

        [ValidateRange(1, 100000)]
        [int]$MaxItems = 20000,

        [ValidateRange(1, 500)]
        [int]$RowLimit = 200
    )

    if (-not $RestContext) {
        if ([string]::IsNullOrWhiteSpace($SiteUrl)) {
            throw 'SiteUrl is required to read the site recycle bin.'
        }
        $RestContext = Resolve-CIPPSharePointRestContext -TenantFilter $TenantFilter -SiteUrl $SiteUrl
    }

    $Scope = $RestContext.Scope
    $JsonAccept = $RestContext.Headers
    $BaseUri = [string]$RestContext.BaseUri

    function ConvertTo-CippRecycleODataLiteral {
        param([string]$Value)
        $Safe = if ([string]::IsNullOrEmpty($Value)) { '' } else { $Value }
        return [uri]::EscapeDataString($Safe)
    }

    function New-CippRecyclePagingInfo {
        param($Item)
        $Id = [string]$Item.Id
        $Title = [string]$Item.Title
        if ([string]::IsNullOrWhiteSpace($Title)) { $Title = [string]$Item.LeafName }
        $EncodedId = [uri]::EscapeDataString($Id)
        $EncodedTitle = [uri]::EscapeDataString($Title)
        # orderBy=0 sorts by Title, so the search position value is the title.
        "id=$EncodedId&title=$EncodedTitle&searchValue=$EncodedTitle"
    }

    function Read-CippRecycleBinPage {
        param($Page)
        $Items = @()
        $Next = $null
        if ($null -eq $Page) {
            return @{ Items = @(); PagingInfo = $null }
        }
        if ($Page -is [System.Array]) {
            $Items = @($Page)
        } elseif ($Page.PSObject.Properties.Name -contains 'value' -and $null -ne $Page.value) {
            $Items = @($Page.value)
        } elseif ($Page.PSObject.Properties.Name -contains 'Id') {
            $Items = @($Page)
        }
        if ($Page -isnot [System.Array]) {
            foreach ($Name in @('PagingInfo', 'pagingInfo')) {
                if ($Page.PSObject.Properties.Name -contains $Name -and -not [string]::IsNullOrWhiteSpace([string]$Page.$Name)) {
                    $Next = [string]$Page.$Name
                    break
                }
            }
            if (-not $Next -and -not [string]::IsNullOrWhiteSpace([string]$Page.'@odata.nextLink')) {
                $Next = [string]$Page.'@odata.nextLink'
            }
        }
        return @{ Items = @($Items | Where-Object { $null -ne $_ }); PagingInfo = $Next }
    }

    $States = if ($ItemState -eq 0) { @(1, 2) } else { @($ItemState) }
    $Collected = [System.Collections.Generic.List[object]]::new()
    $Seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $Capped = $false

    foreach ($State in $States) {
        if ($Collected.Count -ge $MaxItems) {
            $Capped = $true
            break
        }

        $Paging = ''
        $Guard = 0
        $MaxPages = [Math]::Ceiling($MaxItems / $RowLimit) + 3
        $EndedNaturally = $false

        while ($Guard -lt $MaxPages) {
            $Guard++
            $Uri = if ($Paging -match '^https?://') {
                $Paging
            } elseif ([string]::IsNullOrWhiteSpace($Paging)) {
                "$BaseUri/site/GetRecycleBinItems(pagingInfo=null,rowLimit=$RowLimit,isAscending=false,orderBy=0,itemState=$State)"
            } else {
                $Literal = ConvertTo-CippRecycleODataLiteral -Value $Paging
                "$BaseUri/site/GetRecycleBinItems(pagingInfo='$Literal',rowLimit=$RowLimit,isAscending=false,orderBy=0,itemState=$State)"
            }

            $Raw = New-GraphPostRequest -uri $Uri -tenantid $TenantFilter -scope $Scope -type POST -body '{}' -contentType 'application/json;odata=nometadata' -AddedHeaders $JsonAccept -UseCertificate -AsApp $true
            $Parsed = Read-CippRecycleBinPage -Page $Raw
            $Items = @($Parsed.Items)
            if ($Items.Count -eq 0) {
                $EndedNaturally = $true
                break
            }

            $Fresh = [System.Collections.Generic.List[object]]::new()
            foreach ($Item in $Items) {
                $Id = [string]$Item.Id
                if ([string]::IsNullOrWhiteSpace($Id)) { continue }
                if ($Seen.Add($Id)) { $Fresh.Add($Item) }
            }

            if ($Fresh.Count -eq 0) {
                if ($Items.Count -ge $RowLimit) { $Capped = $true }
                $EndedNaturally = $true
                break
            }

            $Room = $MaxItems - $Collected.Count
            $Take = [Math]::Min($Room, $Fresh.Count)
            for ($i = 0; $i -lt $Take; $i++) { $Collected.Add($Fresh[$i]) }

            $Next = [string]$Parsed.PagingInfo
            $PageWasFull = $Items.Count -ge $RowLimit
            if ($PageWasFull -and $Collected.Count -lt $MaxItems -and ($Next -notmatch '(^|&)id=')) {
                $Built = New-CippRecyclePagingInfo -Item $Items[-1]
                if (-not [string]::IsNullOrWhiteSpace($Built) -and $Built -ne $Paging) {
                    $Next = $Built
                }
            }

            if ($Collected.Count -ge $MaxItems) {
                $MoreKnown = $Fresh.Count -gt $Take -or -not [string]::IsNullOrWhiteSpace($Next) -or $PageWasFull
                if ($MoreKnown) { $Capped = $true }
                $EndedNaturally = $true
                break
            }

            if ([string]::IsNullOrWhiteSpace($Next)) {
                $EndedNaturally = $true
                break
            }
            if ($Next -eq $Paging) {
                if ($PageWasFull) { $Capped = $true }
                $EndedNaturally = $true
                break
            }
            $Paging = $Next
        }

        if (-not $EndedNaturally) { $Capped = $true }
        if ($Capped) { break }
    }

    $FirstCount = [int64]0
    $FirstBytes = [int64]0
    $SecondCount = [int64]0
    $SecondBytes = [int64]0
    foreach ($Item in $Collected) {
        $Size = [int64]0
        try { $Size = [int64][double]$Item.Size } catch { $Size = 0 }
        $StateValue = 0
        try { $StateValue = [int]$Item.ItemState } catch { $StateValue = 0 }
        if ($StateValue -eq 2) {
            $SecondCount++
            $SecondBytes += $Size
        } else {
            $FirstCount++
            $FirstBytes += $Size
        }
    }

    [PSCustomObject]@{
        Items            = @($Collected)
        Capped           = [bool]$Capped
        ScannedItems     = [int]$Collected.Count
        FirstStageCount  = $FirstCount
        FirstStageBytes  = $FirstBytes
        SecondStageCount = $SecondCount
        SecondStageBytes = $SecondBytes
    }
}
