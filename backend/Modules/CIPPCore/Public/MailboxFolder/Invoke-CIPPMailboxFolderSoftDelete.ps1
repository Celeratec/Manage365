function Invoke-CIPPMailboxFolderSoftDelete {
    <#
    .SYNOPSIS
        Soft-remove a mailbox folder by moving it under Deleted Items (Graph move), with preview and verification.
    .DESCRIPTION
        Flow: resolve folder -> before-state -> guards -> (Preview: return DryRun, zero writes) -> POST move -> verify.
        The only write is POST .../mailFolders/{id}/move with destinationId 'deleteditems' (New-GraphPOSTRequest -AsApp $true).
        No hard-removal verb is used anywhere in this path. Success is returned only when the old folder id is gone
        and the moved folder sits under Deleted Items with the same item count; otherwise Status is 'Failed'.
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

    $Guard = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId $DeletedItemsId -MailboxUpn $UserId
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

    $Fail = {
        param([string]$Message, $After)
        [pscustomobject]@{
            Status      = 'Failed'
            StatusCode  = 500
            Before      = $Before
            PlannedMove = $PlannedMove
            After       = $After
            Results     = @($Message)
        }
    }

    $UserSeg = [System.Uri]::EscapeDataString($UserId)
    $Uri = "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString([string]$Folder.id))/move"
    try {
        $Moved = New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -type 'POST' -body (@{ destinationId = 'deleteditems' } | ConvertTo-Json -Compress)
    } catch {
        return & $Fail "Move to Deleted Items failed: $($_.Exception.Message)" $null
    }

    $NewId = [string]$Moved.id
    if ([string]::IsNullOrWhiteSpace($NewId)) {
        return & $Fail 'Move response did not include a new folder id; outcome could not be verified.' $null
    }

    # Verify 1: the old folder id must be gone (not found).
    $OldStillExists = $false
    try {
        $Old = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString([string]$Folder.id))?`$select=id" -tenantid $TenantFilter -AsApp $true
        if ($null -ne $Old -and -not [string]::IsNullOrWhiteSpace([string]$Old.id)) { $OldStillExists = $true }
    } catch {
        if ($_.Exception.Message -notmatch '404|NotFound|not found|ErrorItemNotFound|ResourceNotFound') {
            return & $Fail "Verification failed: could not confirm the original folder id is gone ($($_.Exception.Message))." $null
        }
    }
    if ($OldStillExists) {
        return & $Fail 'Verification failed: the original folder id still exists after the move.' $null
    }

    # Verify 2: moved folder sits under Deleted Items with the same item count.
    try {
        $New = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserSeg/mailFolders/$([System.Uri]::EscapeDataString($NewId))?`$select=id,displayName,parentFolderId,totalItemCount" -tenantid $TenantFilter -AsApp $true
    } catch {
        return & $Fail "Verification failed: could not read the moved folder ($($_.Exception.Message))." $null
    }
    $After = [ordered]@{
        id        = [string]$New.id
        parentId  = [string]$New.parentFolderId
        itemCount = $New.totalItemCount
    }
    if ([string]$New.parentFolderId -ne $DeletedItemsId) {
        return & $Fail 'Verification failed: the moved folder is not under Deleted Items.' $After
    }
    if ($null -eq $Before.itemCount -or $null -eq $New.totalItemCount -or [int]$Before.itemCount -ne [int]$New.totalItemCount) {
        return & $Fail "Verification failed: item count mismatch (before: $($Before.itemCount), after: $($New.totalItemCount))." $After
    }

    [pscustomobject]@{
        Status           = 'Success'
        StatusCode       = 200
        Before           = $Before
        PlannedMove      = $PlannedMove
        After            = $After
        deletedFolderId  = $NewId
        originalParentId = [string]$Folder.parentFolderId
        Results          = @("Moved '$($Resolved.Path)' to Deleted Items and verified item count ($($Before.itemCount)).")
    }
}
