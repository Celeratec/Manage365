function Invoke-ListMoveArchiveItemsJobs {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter
    $UserPrincipalName = $Request.Query.UserPrincipalName
    $JobId = $Request.Query.JobId

    try {
        $Table = Get-CippTable -tablename 'MoveArchiveItemsJobs'
        $Filter = "PartitionKey eq '$TenantFilter'"
        if ($JobId) {
            $Filter += " and RowKey eq '$JobId'"
        }
        $Rows = @(Get-CIPPAzDataTableEntity @Table -Filter $Filter)
        if ($UserPrincipalName) {
            $Rows = @($Rows | Where-Object { $_.UserPrincipalName -eq $UserPrincipalName })
        }
        $GraphRequest = @($Rows | Sort-Object CreatedUtc -Descending)
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $GraphRequest = (Get-CippException -Exception $_).NormalizedError
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @($GraphRequest)
        })
}
