function Test-CIPPMoveArchiveItemsRequest {
    <#
    .SYNOPSIS
        Validate parameters for archive-to-primary move operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [string]$TicketNumber,

        [bool]$DryRun = $true,

        [bool]$HoldAcknowledged = $false,

        [bool]$Force = $false,

        [string]$SourceFolder,

        [string]$TargetFolder,

        [string]$Reason
    )

    if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
        throw 'TenantFilter is required.'
    }
    if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) {
        throw 'UserPrincipalName is required.'
    }
    if ([string]::IsNullOrWhiteSpace($TicketNumber)) {
        throw 'TicketNumber is required (Freshdesk ticket ID).'
    }
    if ($TicketNumber -notmatch '^\d+$') {
        throw 'TicketNumber must be numeric (Freshdesk ticket ID).'
    }

    return [PSCustomObject]@{
        TenantFilter      = $TenantFilter.Trim()
        UserPrincipalName = $UserPrincipalName.Trim()
        TicketNumber      = $TicketNumber.Trim()
        DryRun            = [bool]$DryRun
        HoldAcknowledged  = [bool]$HoldAcknowledged
        Force             = [bool]$Force
        SourceFolder      = if ([string]::IsNullOrWhiteSpace($SourceFolder)) { $null } else { $SourceFolder.Trim() }
        TargetFolder      = if ([string]::IsNullOrWhiteSpace($TargetFolder)) { $null } else { $TargetFolder.Trim() }
        Reason            = if ([string]::IsNullOrWhiteSpace($Reason)) { $null } else { $Reason.Trim() }
    }
}
