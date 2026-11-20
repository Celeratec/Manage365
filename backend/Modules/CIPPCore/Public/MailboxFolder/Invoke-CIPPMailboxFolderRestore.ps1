function Invoke-CIPPMailboxFolderRestore {
    <#
    .SYNOPSIS
        Restore a soft-deleted mailbox folder from Deleted Items back to its original parent (Graph move), with preview and verify.
    .DESCRIPTION
        Flow: resolve deleted folder -> guards -> (Preview: return DryRun, zero writes) -> POST move -> verify.
        The folder must currently sit directly under Deleted Items. The only write is
        POST .../mailFolders/{id}/move with destinationId = OriginalParentId (New-GraphPOSTRequest -AsApp $true);
        there is no arbitrary relocate and no hard-removal verb. Success is returned only when the restored folder sits
        under the original parent with the same item count; otherwise Status is 'Failed'.
        Resolve errors (folder not found) propagate to the caller. Guard refusals return Status 'Failed', StatusCode 400.
    .PARAMETER Parsed
        Output of Test-CIPPMailboxFolderRestoreRequest (DeletedFolderId, OriginalParentId, FolderType).
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
    $DeletedFolderId = [string]$Parsed.DeletedFolderId
    $OriginalParentId = [string]$Parsed.OriginalParentId

    $Refuse = {
        param([string]$Message)
        [pscustomobject]@{
            Status      = 'Failed'
            StatusCode  = 400
            Reason      = $Message
            Before      = $null
            PlannedMove = $null
            After       = $null
            Results     = @($Message)
        }
    }

    if ([string]::IsNullOrWhiteSpace($DeletedFolderId) -or [string]::IsNullOrWhiteSpace($OriginalParentId)) {
        return & $Refuse 'deletedFolderId and originalParentId are required.'
    }

    $Resolved = Resolve-CIPPMailboxFolder -TenantFilter $TenantFilter -UserId $UserId -FolderId $DeletedFolderId -FolderType $FolderType
    $Folder = $Resolved.Folder
    $DeletedItemsId = [string]$Resolved.DeletedItemsId

    # Guard 1: the folder being restored must currently be directly under Deleted Items.
    if ([string]$Folder.parentFolderId -ne $DeletedItemsId) {
        return & $Refuse 'Folder is not currently under Deleted Items; only soft-deleted folders can be restored.'
    }
    # Guard 2: never restore a well-known/default folder (by name, default-calendar flag, or reserved id).
    if (-not [string]::IsNullOrWhiteSpace([string]$Folder.wellKnownName)) {
        return & $Refuse "Refusing to restore a well-known/default folder ('$($Folder.wellKnownName)')."
    }
    if ($Folder.isDefaultCalendar -eq $true -or @($Resolved.ReservedFolderIds) -ccontains [string]$Folder.id) {
        return & $Refuse 'Refusing to restore a well-known/default folder.'
    }
    # Guard 3: destination is the original parent only and must not be Deleted Items or the folder itself.
    if ($OriginalParentId -eq $DeletedItemsId) {
        return & $Refuse 'originalParentId must not be Deleted Items.'
    }
    if ($OriginalParentId -eq [string]$Folder.id) {
        return & $Refuse 'originalParentId must not be the folder being restored.'
    }

    $UserSeg = [System.Uri]::EscapeDataString($UserId)
    try {
        $Parent = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString($OriginalParentId))?`$select=id,displayName,parentFolderId" -tenantid $TenantFilter -AsApp $true
    } catch {
        return & $Refuse "Original parent folder could not be found: $($_.Exception.Message)"
    }
    if ($null -eq $Parent -or [string]::IsNullOrWhiteSpace([string]$Parent.id)) {
        return & $Refuse 'Original parent folder could not be found.'
    }
    if ([string]$Parent.parentFolderId -eq $DeletedItemsId) {
        return & $Refuse 'Original parent folder is itself under Deleted Items; restore it first.'
    }

    $Before = Get-CIPPMailboxFolderBeforeState -TenantFilter $TenantFilter -UserId $UserId -Folder $Folder -Path $Resolved.Path -FolderType $FolderType
    $PlannedMove = [ordered]@{
        folderId      = [string]$Folder.id
        path          = $Resolved.Path
        destinationId = $OriginalParentId
        destination   = [string]$Parent.displayName
    }

    # Preview returns before any write is attempted.
    if ($Preview) {
        return [pscustomobject]@{
            Status      = 'DryRun'
            StatusCode  = 200
            Before      = $Before
            PlannedMove = $PlannedMove
            After       = $null
            Results     = @("Preview: would restore '$($Folder.displayName)' from Deleted Items to '$($Parent.displayName)'. No changes made.")
        }
    }

    # Failed outcome. After a successful move POST, PostSucceeded carries restoredFolderId/originalParentId for the operator.
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
            $Out.restoredFolderId = if ([string]::IsNullOrWhiteSpace($MovedId)) { $null } else { $MovedId }
            $Out.originalParentId = $OriginalParentId
        }
        [pscustomobject]$Out
    }

    $Uri = "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString([string]$Folder.id))/move"
    try {
        $Moved = New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -type 'POST' -body (@{ destinationId = $OriginalParentId } | ConvertTo-Json -Compress)
    } catch {
        return & $Fail "Restore move failed: $($_.Exception.Message)" $null
    }

    $NewId = [string]$Moved.id
    if ([string]::IsNullOrWhiteSpace($NewId)) {
        return & $Fail 'Move response did not include a restored folder id; outcome could not be verified.' $null $true $null
    }

    try {
        $New = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString($NewId))?`$select=id,displayName,parentFolderId,totalItemCount" -tenantid $TenantFilter -AsApp $true
    } catch {
        return & $Fail "Verification failed: could not read the restored folder ($($_.Exception.Message))." $null $true $NewId
    }
    $After = [ordered]@{
        id        = [string]$New.id
        parentId  = [string]$New.parentFolderId
        itemCount = $New.totalItemCount
    }
    if ([string]$New.parentFolderId -ne $OriginalParentId) {
        return & $Fail 'Verification failed: the restored folder is not under the original parent.' $After $true $NewId
    }
    if ($null -eq $Before.itemCount -or $null -eq $New.totalItemCount -or [int]$Before.itemCount -ne [int]$New.totalItemCount) {
        return & $Fail "Verification failed: item count mismatch (before: $($Before.itemCount), after: $($New.totalItemCount))." $After $true $NewId
    }

    [pscustomobject]@{
        Status           = 'Success'
        StatusCode       = 200
        Before           = $Before
        PlannedMove      = $PlannedMove
        After            = $After
        restoredFolderId = $NewId
        originalParentId = $OriginalParentId
        Results          = @("Restored '$($Folder.displayName)' to '$($Parent.displayName)' and verified item count ($($Before.itemCount)).")
    }
}
