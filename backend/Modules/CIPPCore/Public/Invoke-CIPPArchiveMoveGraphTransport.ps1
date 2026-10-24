function Get-CIPPArchiveMoveSafeFolderDisplayName {
    param([string]$Name)
    $Safe = if ([string]::IsNullOrWhiteSpace($Name)) { 'Folder' } else { $Name.Trim() }
    $Safe = ($Safe -replace '[\\/:*?"<>|]', '_').Trim()
    if ($Safe.Length -gt 120) { $Safe = $Safe.Substring(0, 120) }
    return $Safe
}

function Get-CIPPArchiveMoveGraphAllFolders {
    param(
        [string]$TenantFilter,
        [string]$MailboxId
    )
    $Base = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$MailboxId/folders"
    $Uri = "$Base`?`$top=100&`$select=id,displayName,totalItemCount,type,wellKnownName"
    $All = [System.Collections.Generic.List[object]]::new()
    do {
        $Page = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method GET -Uri $Uri
        foreach ($Row in @($Page.value)) { $All.Add($Row) }
        $Uri = $Page.'@odata.nextLink'
    } while ($Uri)
    return @($All)
}

function Get-CIPPArchiveMoveGraphEnsureFolder {
    param(
        [string]$TenantFilter,
        [string]$PrimaryMailboxId,
        [string]$ParentFolderId,
        [string]$DisplayName
    )
    $SafeName = Get-CIPPArchiveMoveSafeFolderDisplayName -Name $DisplayName
    $ChildUri = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$PrimaryMailboxId/folders/$ParentFolderId/childFolders?`$select=id,displayName&`$top=200"
    try {
        $Existing = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method GET -Uri $ChildUri
        $Match = @($Existing.value | Where-Object { $_.displayName -eq $SafeName -and $_.id })
        if ($Match.Count -gt 0) { return [string]$Match[0].id }
    } catch {
        Write-Verbose "childFolders listing unavailable, creating folder '$SafeName'."
    }

    $CreateUri = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$PrimaryMailboxId/folders"
    $Created = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method POST -Uri $CreateUri -Body @{
        displayName    = $SafeName
        parentFolderId = $ParentFolderId
    }
    return [string]$Created.id
}

function Initialize-CIPPArchiveMoveGraphCheckpoint {
    param(
        [string]$TenantFilter,
        [string]$PrimaryMailboxId,
        [string]$ArchiveMailboxId,
        [string]$TargetFolderName,
        [string]$SourceFolderFilter
    )

    $RestoreRootName = if ($TargetFolderName) { $TargetFolderName } else { 'Restored from Archive' }
    $InboxUri = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$PrimaryMailboxId/folders/inbox?`$select=id,displayName"
    $Inbox = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method GET -Uri $InboxUri
    if (-not $Inbox.id) { throw 'Could not resolve primary inbox folder for restore target.' }
    $RestoreRootId = Get-CIPPArchiveMoveGraphEnsureFolder -TenantFilter $TenantFilter -PrimaryMailboxId $PrimaryMailboxId -ParentFolderId ([string]$Inbox.id) -DisplayName $RestoreRootName

    $ArchiveFolders = Get-CIPPArchiveMoveGraphAllFolders -TenantFilter $TenantFilter -MailboxId $ArchiveMailboxId
    $Candidates = @($ArchiveFolders | Where-Object {
            $_.totalItemCount -gt 0 -and
            $_.type -like 'IPF*' -and
            $_.wellKnownName -notin @('recoverableitemsroot', 'recoverableitemsdeletions', 'recoverableitemsversions', 'recoverableitemspurges')
        })

    if ($SourceFolderFilter) {
        $Candidates = @($Candidates | Where-Object { $_.id -eq $SourceFolderFilter -or $_.displayName -eq $SourceFolderFilter })
    }

    $FolderRows = foreach ($Folder in $Candidates) {
        $TargetId = Get-CIPPArchiveMoveGraphEnsureFolder -TenantFilter $TenantFilter -PrimaryMailboxId $PrimaryMailboxId -ParentFolderId $RestoreRootId -DisplayName $Folder.displayName
        [PSCustomObject]@{
            archiveFolderId  = [string]$Folder.id
            primaryFolderId  = [string]$TargetId
            displayName      = [string]$Folder.displayName
            itemsNextLink    = $null
        }
    }

    return [PSCustomObject]@{
        primaryMailboxId  = $PrimaryMailboxId
        archiveMailboxId  = $ArchiveMailboxId
        restoreRootFolderId = $RestoreRootId
        folders           = @($FolderRows)
        folderIndex       = 0
    }
}

function Invoke-CIPPArchiveMoveGraphExportImportBatch {
    param(
        [string]$TenantFilter,
        [string]$ArchiveMailboxId,
        [string]$PrimaryMailboxId,
        [string]$ArchiveFolderId,
        [string]$PrimaryFolderId,
        [string]$ItemsUri,
        [int]$BatchSize = 20
    )

    if (-not $ItemsUri) {
        $ItemsUri = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$ArchiveMailboxId/folders/$ArchiveFolderId/items?`$top=$BatchSize&`$select=id,size,changeKey"
    }

    $Page = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method GET -Uri $ItemsUri
    $Items = @($Page.value)
    if ($Items.Count -eq 0) {
        return [PSCustomObject]@{ moved = 0; nextItemsLink = $Page.'@odata.nextLink' }
    }

    $ItemMap = @{}
    foreach ($Item in $Items) { $ItemMap[[string]$Item.id] = $Item }

    $ExportUri = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$ArchiveMailboxId/exportItems"
    $ExportBody = @{ itemIds = @($Items | ForEach-Object { [string]$_.id }) }
    $ExportResult = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method POST -Uri $ExportUri -Body $ExportBody
    $ExportRows = @($ExportResult.value)
    if ($ExportRows.Count -eq 0 -and $ExportResult.itemId) { $ExportRows = @($ExportResult) }

    $SessionUri = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$PrimaryMailboxId/createImportSession"
    $Session = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method POST -Uri $SessionUri -Body @{}
    $ImportUrl = [string]$Session.importUrl
    if (-not $ImportUrl) { throw 'createImportSession did not return importUrl.' }

    $Moved = 0
    foreach ($Row in $ExportRows) {
        if ($Row.error) {
            if ($Row.error.code -eq 'ErrorArchiveFolderMovedPermanently' -and $Row.error.message -match 'https://') {
                throw "Archive item requires redirect re-export: $($Row.error.message)"
            }
            throw "exportItems failed for item: $($Row.error.code) $($Row.error.message)"
        }
        if (-not $Row.data) { throw 'exportItems returned empty data for an item.' }

        $SourceMeta = $ItemMap[[string]$Row.itemId]
        $ImportBody = @{
            FolderId = $PrimaryFolderId
            Mode     = 'create'
            Data     = [string]$Row.data
        }
        $ImportedRaw = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method POST -Uri $ImportUrl -Body $ImportBody -SkipAuth
        $Imported = if ($ImportedRaw -is [string]) { $ImportedRaw | ConvertFrom-Json } else { $ImportedRaw }

        $ImportedSize = $null
        if ($Imported.itemId) {
            $VerifyUri = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$PrimaryMailboxId/folders/$PrimaryFolderId/items/$($Imported.itemId)?`$select=id,size"
            $Verified = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method GET -Uri $VerifyUri
            $ImportedSize = [long]$Verified.size
        }

        if ($null -eq $ImportedSize -or ($SourceMeta -and [long]$SourceMeta.size -ne $ImportedSize)) {
            throw "Verification failed after import for archive item $($Row.itemId) (expected size $($SourceMeta.size), got $ImportedSize)."
        }

        $DeleteUri = "https://graph.microsoft.com/v1.0/admin/exchange/mailboxes/$ArchiveMailboxId/folders/$ArchiveFolderId/items/$($Row.itemId)?disposalType=softDelete"
        Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method DELETE -Uri $DeleteUri | Out-Null
        $Moved++
    }

    return [PSCustomObject]@{
        moved         = $Moved
        nextItemsLink = $Page.'@odata.nextLink'
    }
}

function Invoke-CIPPArchiveMoveGraphTransport {
    <#
    .SYNOPSIS
        Process one slice of an archive-to-primary move using Graph import/export APIs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [hashtable]$JobEntity,

        [string]$TargetFolder,
        [string]$SourceFolder,
        [int]$MaxItemsPerRun = 60,
        [int]$ExportBatchSize = 20
    )

    $MailboxSet = Get-CIPPArchiveMoveGraphMailboxes -TenantFilter $TenantFilter -UserPrincipalName $UserPrincipalName

    $Checkpoint = $null
    if ($JobEntity.CheckpointJson) {
        try { $Checkpoint = $JobEntity.CheckpointJson | ConvertFrom-Json } catch { $Checkpoint = $null }
    }
    if (-not $Checkpoint) {
        $Checkpoint = Initialize-CIPPArchiveMoveGraphCheckpoint -TenantFilter $TenantFilter `
            -PrimaryMailboxId $MailboxSet.PrimaryMailboxId `
            -ArchiveMailboxId $MailboxSet.ArchiveMailboxId `
            -TargetFolderName $TargetFolder `
            -SourceFolderFilter $SourceFolder
    }

    $MovedThisRun = 0
    $FolderList = @($Checkpoint.folders)
    $FolderIndex = [int]$Checkpoint.folderIndex

    while ($FolderIndex -lt $FolderList.Count -and $MovedThisRun -lt $MaxItemsPerRun) {
        $Folder = $FolderList[$FolderIndex]
        $ItemsLink = if ($Folder.itemsNextLink) { [string]$Folder.itemsNextLink } else { $null }

        $Batch = Invoke-CIPPArchiveMoveGraphExportImportBatch -TenantFilter $TenantFilter `
            -ArchiveMailboxId ([string]$Checkpoint.archiveMailboxId) `
            -PrimaryMailboxId ([string]$Checkpoint.primaryMailboxId) `
            -ArchiveFolderId ([string]$Folder.archiveFolderId) `
            -PrimaryFolderId ([string]$Folder.primaryFolderId) `
            -ItemsUri $ItemsLink `
            -BatchSize $ExportBatchSize

        $MovedThisRun += [int]$Batch.moved
        $FolderList[$FolderIndex] = [PSCustomObject]@{
            archiveFolderId = $Folder.archiveFolderId
            primaryFolderId = $Folder.primaryFolderId
            displayName     = $Folder.displayName
            itemsNextLink   = $Batch.nextItemsLink
        }

        if (-not $Batch.nextItemsLink) {
            $FolderIndex++
        }
    }

    $Complete = ($FolderIndex -ge $FolderList.Count)
    $CheckpointOut = [PSCustomObject]@{
        primaryMailboxId    = $Checkpoint.primaryMailboxId
        archiveMailboxId    = $Checkpoint.archiveMailboxId
        restoreRootFolderId = $Checkpoint.restoreRootFolderId
        folders             = @($FolderList)
        folderIndex         = $FolderIndex
    }

    return [PSCustomObject]@{
        Complete         = $Complete
        MovedThisRun     = $MovedThisRun
        CheckpointJson   = ($CheckpointOut | ConvertTo-Json -Depth 12 -Compress)
        Transport        = 'Graph'
        PrimaryMailboxId = [string]$Checkpoint.primaryMailboxId
        ArchiveMailboxId = [string]$Checkpoint.archiveMailboxId
    }
}
