function Invoke-ListSiteRecycleBinSummary {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.SiteRecycleBin.Read
    .DESCRIPTION
        Aggregate recycle bin sizes for a site (counts + bytes by stage). Never returns
        item titles, leaf names, or paths — storage-report privacy ceiling.
        Pages with GetRecycleBinItems and sets capped when the scan stops early.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Query.TenantFilter ?? $Request.Query.tenantFilter ?? $Request.Body.TenantFilter ?? $Request.Body.tenantFilter
    $SiteUrl = $Request.Query.SiteUrl ?? $Request.Body.SiteUrl
    $MaxItems = [int]($Request.Query.MaxItems ?? $Request.Body.MaxItems ?? 5000)
    if ($MaxItems -lt 1) { $MaxItems = 5000 }
    if ($MaxItems -gt 20000) { $MaxItems = 20000 }

    if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'tenantFilter is required.' } })
    }
    if ([string]::IsNullOrWhiteSpace($SiteUrl)) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'SiteUrl is required.' } })
    }

    try {
        $Scan = Get-CIPPSiteRecycleBinItems -TenantFilter $TenantFilter -SiteUrl $SiteUrl -ItemState 0 -MaxItems $MaxItems -RowLimit 200
        $Body = [PSCustomObject]@{
            siteUrl          = $SiteUrl.TrimEnd('/')
            itemCount        = [int64]$Scan.FirstStageCount + [int64]$Scan.SecondStageCount
            totalBytes       = [int64]$Scan.FirstStageBytes + [int64]$Scan.SecondStageBytes
            firstStageCount  = [int64]$Scan.FirstStageCount
            firstStageBytes  = [int64]$Scan.FirstStageBytes
            secondStageCount = [int64]$Scan.SecondStageCount
            secondStageBytes = [int64]$Scan.SecondStageBytes
            capped           = [bool]$Scan.Capped
            scannedItems     = [int]$Scan.ScannedItems
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Body = "Failed to summarize recycle bin for $($SiteUrl): $($ErrorMessage.NormalizedError)"
        Write-LogMessage -Headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Body -sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ Results = $Body }
        })
}
