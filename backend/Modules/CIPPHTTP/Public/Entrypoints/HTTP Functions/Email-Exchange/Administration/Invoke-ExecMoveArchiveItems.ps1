function Invoke-ExecMoveArchiveItems {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $Body = $Request.Body

    $TenantFilter = $Request.Query.tenantFilter ?? $Body.tenantFilter
    $UserPrincipalName = $Request.Query.UserPrincipalName ?? $Body.UserPrincipalName ?? $Body.userid ?? $Request.Query.userid
    $TicketNumber = $Request.Query.TicketNumber ?? $Body.TicketNumber
    if ($TicketNumber -is [psobject] -and ($TicketNumber.PSObject.Properties.Name -contains 'value')) {
        $TicketNumber = $TicketNumber.value
    }

    $DryRunRaw = $Request.Query.DryRun ?? $Body.DryRun
    if ($null -eq $DryRunRaw) { $DryRun = $true } else { $DryRun = [bool]$DryRunRaw }

    $HoldAckRaw = $Request.Query.HoldAcknowledged ?? $Body.HoldAcknowledged
    $HoldAcknowledged = if ($null -eq $HoldAckRaw) { $false } else { [bool]$HoldAckRaw }

    $SourceFolder = $Request.Query.SourceFolder ?? $Body.SourceFolder
    $TargetFolder = $Request.Query.TargetFolder ?? $Body.TargetFolder

    try {
        $Validated = Test-CIPPMoveArchiveItemsRequest -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -TicketNumber ([string]$TicketNumber) -DryRun $DryRun -HoldAcknowledged $HoldAcknowledged -SourceFolder $SourceFolder -TargetFolder $TargetFolder
        $Caller = $Headers.'x-ms-client-principal-name' ?? $Headers.'X-MS-CLIENT-PRINCIPAL-NAME' ?? 'API'
        $Outcome = Invoke-CIPPMoveArchiveItems -Request $Validated -Headers $Headers -APIName $APIName -Caller $Caller
        $GraphRequest = $Outcome
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $GraphRequest = @{ Results = (Get-CippException -Exception $_).NormalizedError }
        $StatusCode = [HttpStatusCode]::BadRequest
        Write-Warning "ExecMoveArchiveItems: $($_.Exception.Message)"
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $GraphRequest
        })
}
