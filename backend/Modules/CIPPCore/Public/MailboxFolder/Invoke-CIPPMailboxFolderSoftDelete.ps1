function Invoke-CIPPMailboxFolderSoftDelete {
    <#
    .SYNOPSIS
        Soft-remove a mailbox folder by moving it under Deleted Items (Graph move), with preview and verification.
    .DESCRIPTION
        Flow: resolve folder -> before-state -> guards -> (Preview: return DryRun, zero writes) -> POST move -> verify.
        The only write is POST .../mailFolders/{id}/move with destinationId 'deleteditems' (New-GraphPOSTRequest -AsApp $true).
        No hard-removal verb is used anywhere in this path. Success is returned only when the moved folder (read by its
        NEW id) sits under Deleted Items with the same item count, and the old id (if it still resolves) is either the
        same folder now under Deleted Items or gone. Graph may preserve the id across a move, so the old id is NOT required
        to 404. Any Failed outcome after a successful POST carries deletedFolderId and originalParentId so an operator can restore.
        Resolve errors (folder not found, ambiguous path) propagate to the caller. Guard refusals return
        Status 'Failed' with StatusCode 400 and a Reason.
    .PARAMETER Parsed
        Output of Test-CIPPMailboxFolderSoftDeleteRequest (UserId, FolderId, FolderPath, FolderType).
    .PARAMETER Preview
        Defaults to $true. When $true, no Graph write is issued.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$UserId,
        [Parameter(Mandatory)]$Parsed,
        [bool]$Preview = $true
    )

    $FolderType = if ([string]::IsNullOrWhiteSpace([string]$Parsed.FolderType)) { 'mail' } else { [string]$Parsed.FolderType }
    $ResolveParams = @{ TenantFilter = $TenantFilter; UserId = $UserId; FolderType = $FolderType }
    if (-not [string]::IsNullOrWhiteSpace([string]$Parsed.FolderId)) { $ResolveParams.FolderId = [string]$Parsed.FolderId }
    if (-not [string]::IsNullOrWhiteSpace([string]$Parsed.FolderPath)) { $ResolveParams.FolderPath = [string]$Parsed.FolderPath }

    $Resolved = Resolve-CIPPMailboxFolder @ResolveParams
    $Folder = $Resolved.Folder
    $DeletedItemsId = [string]$Resolved.DeletedItemsId

    $Guard = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId $DeletedItemsId -MailboxUpn $UserId -ReservedFolderIds @($Resolved.ReservedFolderIds) -FolderType $FolderType
    if (-not $Guard.Ok) {
        return [pscustomobject]@{
            Status     = 'Failed'
            StatusCode = 400
            Reason     = $Guard.Reason
            Before     = $null
            PlannedMove = $null
            After      = $null
            Results    = @($Guard.Reason)
        }
    }

    $Before = Get-CIPPMailboxFolderBeforeState -TenantFilter $TenantFilter -UserId $UserId -Folder $Folder -Path $Resolved.Path -FolderType $FolderType
    $PlannedMove = [ordered]@{
        folderId      = [string]$Folder.id
        path          = $Resolved.Path
        destinationId = 'deleteditems'
    }

    # Preview returns before any write is attempted.
    if ($Preview) {
        return [pscustomobject]@{
            Status      = 'DryRun'
            StatusCode  = 200
            Before      = $Before
            PlannedMove = $PlannedMove
            After       = $null
            Results     = @("Preview: would move '$($Resolved.Path)' to Deleted Items. No changes made.")
        }
    }

    $UserSeg = [System.Uri]::EscapeDataString($UserId)
    $OriginalParentId = [string]$Folder.parentFolderId

    # Failed outcome. Once the move POST has succeeded, PostSucceeded is $true so the operator always gets the ids to restore.
    $Fail = {
        param([string]$Message, $After, [bool]$PostSucceeded = $false, [string]$MovedId = $null)
        $Out = [ordered]@{
            Status      = 'Failed'
            StatusCode  = 500
            Before      = $Before
            PlannedMove = $PlannedMove
            After       = $After
            Results     = @($Message)
        }
        if ($PostSucceeded) {
            $Out.deletedFolderId = if ([string]::IsNullOrWhiteSpace($MovedId)) { $null } else { $MovedId }
            $Out.originalParentId = $OriginalParentId
        }
        [pscustomobject]$Out
    }

    $Uri = "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString([string]$Folder.id))/move"
    try {
        $Moved = New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -type 'POST' -body (@{ destinationId = 'deleteditems' } | ConvertTo-Json -Compress)
    } catch {
        return & $Fail "Move to Deleted Items failed: $($_.Exception.Message)" $null
    }

    $NewId = [string]$Moved.id
    if ([string]::IsNullOrWhiteSpace($NewId)) {
        return & $Fail 'Move response did not include a new folder id; outcome could not be verified. Check the mailbox for the folder under Deleted Items.' $null $true $null
    }

    # Verify 1: read the moved folder by its NEW id; it must sit under Deleted Items with the same item count.
    try {
        $New = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString($NewId))?`$select=id,displayName,parentFolderId,totalItemCount" -tenantid $TenantFilter -AsApp $true
    } catch {
        return & $Fail "Verification failed: could not read the moved folder ($($_.Exception.Message))." $null $true $NewId
    }
    $After = [ordered]@{
        id        = [string]$New.id
        parentId  = [string]$New.parentFolderId
        itemCount = $New.totalItemCount
    }
    if ([string]$New.parentFolderId -ne $DeletedItemsId) {
        return & $Fail 'Verification failed: the moved folder is not under Deleted Items.' $After $true $NewId
    }
    if ($null -eq $Before.itemCount -or $null -eq $New.totalItemCount -or [int]$Before.itemCount -ne [int]$New.totalItemCount) {
        return & $Fail "Verification failed: item count mismatch (before: $($Before.itemCount), after: $($New.totalItemCount))." $After $true $NewId
    }

    # Verify 2: if the old id still resolves, it must be the same folder now under Deleted Items (id preserved).
    # A copy left behind under the original parent (or anywhere else) is a failure.
    if ($NewId -cne [string]$Folder.id) {
        $Old = $null
        try {
            $Old = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString([string]$Folder.id))?`$select=id,parentFolderId" -tenantid $TenantFilter -AsApp $true
        } catch {
            if ($_.Exception.Message -notmatch '404|NotFound|not found|ErrorItemNotFound|ResourceNotFound') {
                return & $Fail "Verification failed: could not check the original folder id ($($_.Exception.Message))." $After $true $NewId
            }
        }
        if ($null -ne $Old -and -not [string]::IsNullOrWhiteSpace([string]$Old.id) -and [string]$Old.parentFolderId -ne $DeletedItemsId) {
            return & $Fail 'Verification failed: the original folder id still exists outside Deleted Items after the move.' $After $true $NewId
        }
    }

    [pscustomobject]@{
        Status           = 'Success'
        StatusCode       = 200
        Before           = $Before
        PlannedMove      = $PlannedMove
        After            = $After
        deletedFolderId  = $NewId
        originalParentId = $OriginalParentId
        Results          = @("Moved '$($Resolved.Path)' to Deleted Items and verified item count ($($Before.itemCount)).")
    }
}
