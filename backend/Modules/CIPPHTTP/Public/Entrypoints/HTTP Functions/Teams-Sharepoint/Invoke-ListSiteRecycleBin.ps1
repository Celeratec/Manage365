function Invoke-ListSiteRecycleBin {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.SiteRecycleBin.Read
    .DESCRIPTION
        Lists the contents of a SharePoint site's recycle bin (first and second stage) via the
        SharePoint REST API with certificate authentication. Pages with GetRecycleBinItems
        because site/RecycleBin does not return @odata.nextLink.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Query.TenantFilter ?? $Request.Body.tenantFilter ?? $Request.Body.TenantFilter
    $SiteUrl = $Request.Query.SiteUrl ?? $Request.Body.SiteUrl
    $MaxItems = [int]($Request.Query.MaxItems ?? $Request.Body.MaxItems ?? 5000)
    if ($MaxItems -lt 1) { $MaxItems = 5000 }
    if ($MaxItems -gt 20000) { $MaxItems = 20000 }

    $ItemTypeNames = @{ 1 = 'File'; 2 = 'File Version'; 3 = 'List Item'; 4 = 'List'; 5 = 'Folder'; 6 = 'Folder'; 7 = 'Attachment'; 8 = 'List Item Version'; 10 = 'Web' }
    $ItemStateNames = @{ 1 = 'First Stage'; 2 = 'Second Stage' }

    if (-not $SiteUrl) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ 'Results' = 'SiteUrl is required.' } })
    }
    if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ 'Results' = 'tenantFilter is required.' } })
    }

    try {
        $Scan = Get-CIPPSiteRecycleBinItems -TenantFilter $TenantFilter -SiteUrl $SiteUrl -ItemState 0 -MaxItems $MaxItems -RowLimit 200
        $Items = @(
            foreach ($Item in @($Scan.Items)) {
                $TypeCode = 0
                $StateCode = 0
                try { $TypeCode = [int]$Item.ItemType } catch { $TypeCode = 0 }
                try { $StateCode = [int]$Item.ItemState } catch { $StateCode = 0 }
                [PSCustomObject]@{
                    Id            = $Item.Id
                    Title         = $Item.Title
                    LeafName      = $Item.LeafName
                    DirName       = $Item.DirName
                    ItemType      = $ItemTypeNames[$TypeCode] ?? $Item.ItemType
                    ItemState     = $ItemStateNames[$StateCode] ?? $Item.ItemState
                    Size          = $Item.Size
                    DeletedByName = $Item.DeletedByName
                    DeletedDate   = $Item.DeletedDate
                }
            }
        )
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{
            Results          = $Items
            capped           = [bool]$Scan.Capped
            scannedItems     = [int]$Scan.ScannedItems
            firstStageCount  = [int64]$Scan.FirstStageCount
            firstStageBytes  = [int64]$Scan.FirstStageBytes
            secondStageCount = [int64]$Scan.SecondStageCount
            secondStageBytes = [int64]$Scan.SecondStageBytes
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Body = @{ Results = "Failed to list the recycle bin for $($SiteUrl): $($ErrorMessage.NormalizedError)" }
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
