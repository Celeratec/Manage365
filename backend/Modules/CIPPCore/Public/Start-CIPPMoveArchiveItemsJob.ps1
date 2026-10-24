function Start-CIPPMoveArchiveItemsJob {
    <#
    .SYNOPSIS
        Queue a real archive-to-primary move job.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Request,

        $Headers,
        [string]$APIName = 'Move Archive Items',
        [string]$Caller
    )

    if (-not $PSCmdlet.ShouldProcess($Request.UserPrincipalName, 'Queue archive item move')) {
        return
    }

    $JobId = [Guid]::NewGuid().ToString()
    $Entity = @{
        PartitionKey      = $Request.TenantFilter
        RowKey            = $JobId
        UserPrincipalName = $Request.UserPrincipalName
        TicketNumber      = $Request.TicketNumber
        Status            = 'Queued'
        SourceFolder      = $Request.SourceFolder
        TargetFolder      = $Request.TargetFolder
        HoldAcknowledged  = [bool]$Request.HoldAcknowledged
        Caller            = $Caller
        CreatedUtc        = (Get-Date).ToUniversalTime().ToString('o')
        UpdatedUtc        = (Get-Date).ToUniversalTime().ToString('o')
        ArchiveItemsBefore = $null
        PrimaryItemsBefore = $null
        MovedCount         = 0
        ErrorSummary       = $null
    }

    $Table = Get-CippTable -tablename 'MoveArchiveItemsJobs'
    Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null

    $Task = [pscustomobject]@{
        TenantFilter = $Request.TenantFilter
        Name         = "Move archive items: $($Request.UserPrincipalName) (ticket $($Request.TicketNumber))"
        Command      = @{ value = 'Invoke-CIPPMoveArchiveItemsWorker' }
        Parameters   = [pscustomobject]@{
            JobId             = $JobId
            TenantFilter      = $Request.TenantFilter
            UserPrincipalName = $Request.UserPrincipalName
            TicketNumber      = $Request.TicketNumber
            SourceFolder      = $Request.SourceFolder
            TargetFolder      = $Request.TargetFolder
            HoldAcknowledged  = [bool]$Request.HoldAcknowledged
            APIName           = $APIName
        }
    }

    $Queued = Add-CIPPScheduledTask -Task $Task -hidden $false -RunNow -Headers $Headers
    if ([string]$Queued -match '^(Error|Could not)') {
        $Entity.Status = 'Failed'
        $Entity.ErrorSummary = [string]$Queued
        Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null
        throw [string]$Queued
    }

    return $JobId
}
