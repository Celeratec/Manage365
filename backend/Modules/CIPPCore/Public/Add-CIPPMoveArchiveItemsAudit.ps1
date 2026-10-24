function Add-CIPPMoveArchiveItemsAudit {
    <#
    .SYNOPSIS
        Persist an audit row for archive move operations (counts only, no message content).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [string]$TicketNumber,

        [Parameter(Mandatory = $true)]
        [string]$Operation,

        [Parameter(Mandatory = $true)]
        [string]$Result,

        [string]$JobId,
        [bool]$DryRun,
        [string]$Caller,
        [int]$ArchiveItemCountBefore,
        [int]$ArchiveItemCountAfter,
        [int]$PrimaryItemCountBefore,
        [int]$PrimaryItemCountAfter,
        [long]$ArchiveBytesBefore,
        [long]$PrimaryBytesBefore,
        [long]$PrimaryBytesAfterMoveProjected,
        [int]$DurationMs,
        [string]$ErrorSummary
    )

    $RowKey = if ($JobId) { $JobId } else { [Guid]::NewGuid().ToString() }
    $Entity = @{
        PartitionKey                   = $TenantFilter
        RowKey                         = $RowKey
        UserPrincipalName              = $UserPrincipalName
        TicketNumber                   = $TicketNumber
        Operation                      = $Operation
        Result                         = $Result
        JobId                          = $JobId
        DryRun                         = [bool]$DryRun
        Caller                         = $Caller
        ArchiveItemCountBefore         = $ArchiveItemCountBefore
        ArchiveItemCountAfter          = $ArchiveItemCountAfter
        PrimaryItemCountBefore         = $PrimaryItemCountBefore
        PrimaryItemCountAfter          = $PrimaryItemCountAfter
        ArchiveBytesBefore             = $ArchiveBytesBefore
        PrimaryBytesBefore             = $PrimaryBytesBefore
        PrimaryBytesAfterMoveProjected = $PrimaryBytesAfterMoveProjected
        DurationMs                     = $DurationMs
        ErrorSummary                   = $ErrorSummary
        TimestampUtc                   = (Get-Date).ToUniversalTime().ToString('o')
    }

    try {
        $Table = Get-CippTable -tablename 'MoveArchiveItemsAudit'
        Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null
    } catch {
        Write-Warning "MoveArchiveItems audit write failed: $($_.Exception.Message)"
    }

    return $Entity
}
