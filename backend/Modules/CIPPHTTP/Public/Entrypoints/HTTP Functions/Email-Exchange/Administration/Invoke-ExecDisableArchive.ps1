function Invoke-ExecDisableArchive {
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
    $UserPrincipalName = $Request.Query.UserPrincipalName ?? $Body.UserPrincipalName ?? $Body.userid
    $TicketNumber = $Request.Query.TicketNumber ?? $Body.TicketNumber
    if ($TicketNumber -is [psobject] -and ($TicketNumber.PSObject.Properties.Name -contains 'value')) {
        $TicketNumber = $TicketNumber.value
    }
    $ForceRaw = $Request.Query.Force ?? $Body.Force
    $Force = if ($null -eq $ForceRaw) { $false } else { [bool]$ForceRaw }
    $Reason = $Request.Query.Reason ?? $Body.Reason

    try {
        if ([string]::IsNullOrWhiteSpace($TicketNumber) -or $TicketNumber -notmatch '^\d+$') {
            throw 'TicketNumber is required and must be numeric (Freshdesk ticket ID).'
        }
        if ($Force -and [string]::IsNullOrWhiteSpace($Reason)) {
            throw 'Reason is required when Force is true.'
        }

        $Preview = Get-CIPPMoveArchiveItemsPreview -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName
        if ($Preview.ArchiveItemCount -gt 0 -and -not $Force) {
            throw "Archive still contains $($Preview.ArchiveItemCount) item(s). Move items first or use Force with Reason and ticket."
        }

        $StatsBackup = @{
            ArchiveItemCount  = $Preview.ArchiveItemCount
            ArchiveTotalBytes = $Preview.ArchiveTotalBytes
            PrimaryItemCount  = $Preview.PrimaryItemCount
            PrimaryTotalBytes = $Preview.PrimaryTotalBytes
            BackedUpUtc       = (Get-Date).ToUniversalTime().ToString('o')
        }

        $Result = Set-CIPPMailboxArchive -userid $UserPrincipalName -tenantFilter $TenantFilter -APIName $APIName -Headers $Headers -ArchiveEnabled $false -Username $UserPrincipalName
        if ($Result -like 'Failed*') { throw $Result }

        $Caller = $Headers.'x-ms-client-principal-name' ?? 'API'
        $null = Add-CIPPMoveArchiveItemsAudit -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName -TicketNumber $TicketNumber -Operation 'DisableArchive' -Result 'Succeeded' -DryRun $false -Caller $Caller -ArchiveItemCountBefore $Preview.ArchiveItemCount -ArchiveBytesBefore $Preview.ArchiveTotalBytes -PrimaryItemCountBefore $Preview.PrimaryItemCount -PrimaryBytesBefore $Preview.PrimaryTotalBytes -ErrorSummary $(if ($Force) { "Force: $Reason | Backup: $($StatsBackup | ConvertTo-Json -Compress)" } else { $null })

        $GraphRequest = @{ Results = $Result; StatsBackup = $StatsBackup }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $GraphRequest = @{ Results = (Get-CippException -Exception $_).NormalizedError }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $GraphRequest
        })
}
