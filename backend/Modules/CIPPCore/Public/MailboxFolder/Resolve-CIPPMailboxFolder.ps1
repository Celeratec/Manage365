function Resolve-CIPPMailboxFolder {
    <#
    .SYNOPSIS
        Resolve a mailbox folder (by id or path) via read-only Graph GETs.
    .DESCRIPTION
        Returns Folder (Graph mailFolder, enriched with folderClass, path, parentPath and, for calendars,
        isShared/owner/isDefaultCalendar/calendarMatched), DeletedItemsId, Path and ReservedFolderIds (resolved
        ids of well-known folders, for id-based default-folder protection). Uses New-GraphGetRequest -AsApp $true only; never writes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$UserId,
        [string]$FolderId,
        [string]$FolderPath,
        [ValidateSet('mail', 'calendar')][string]$FolderType = 'mail'
    )

    $MaxDepth = 32
    $UserSeg = [System.Uri]::EscapeDataString($UserId)
    $Base = "https://graph.microsoft.com/v1.0/users/$UserSeg"
    $FolderSelect = 'id,displayName,parentFolderId,wellKnownName,totalItemCount,unreadItemCount,childFolderCount,sizeInBytes,isHidden'
    # PR_CONTAINER_CLASS (IPF.*) is not a first-class mailFolder property in Graph v1.0; read it as an extended property.
    $ClassExpand = "`$expand=singleValueExtendedProperties(`$filter=id eq 'String 0x3613')"

    $HasId = -not [string]::IsNullOrWhiteSpace($FolderId)
    $HasPath = -not [string]::IsNullOrWhiteSpace($FolderPath)
    if ($HasId -eq $HasPath) { throw 'Provide exactly one of FolderId or FolderPath.' }

    $Get = {
        param([string]$Uri)
        New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true
    }

    $DeletedItems = & $Get "$Base/mailFolders/deleteditems?`$select=id,displayName,wellKnownName"
    $DeletedItemsId = [string]$DeletedItems.id
    if ([string]::IsNullOrWhiteSpace($DeletedItemsId)) { throw 'Could not resolve the Deleted Items folder for this mailbox.' }

    $Root = & $Get "$Base/mailFolders/msgfolderroot?`$select=id,displayName"
    $RootId = [string]$Root.id

    # Resolve well-known folder ids so default folders are protected by id, not only by wellKnownName/displayName.
    # Not every mailbox has every folder (e.g. archive), so individual lookup failures are tolerated.
    $ReservedFolderIds = [System.Collections.Generic.List[string]]::new()
    foreach ($ReservedName in 'inbox', 'drafts', 'sentitems', 'junkemail', 'outbox', 'archive', 'calendar', 'contacts', 'tasks', 'notes') {
        try {
            $Reserved = & $Get "$Base/mailFolders/$ReservedName`?`$select=id"
            if ($null -ne $Reserved -and -not [string]::IsNullOrWhiteSpace([string]$Reserved.id)) { $ReservedFolderIds.Add([string]$Reserved.id) }
        } catch {
            Write-Verbose "Well-known folder '$ReservedName' could not be resolved: $($_.Exception.Message)"
        }
    }
    foreach ($Id in @($DeletedItemsId, $RootId)) {
        if (-not [string]::IsNullOrWhiteSpace($Id)) { $ReservedFolderIds.Add($Id) }
    }

    if ($HasPath) {
        $Segments = @($FolderPath -split '\\' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($Segments.Count -eq 0) { throw 'FolderPath must contain at least one folder name.' }
        if ($Segments.Count -gt $MaxDepth) { throw "FolderPath exceeds maximum depth of $MaxDepth." }

        $Remaining = $Segments
        if ($FolderType -eq 'calendar' -and $Segments[0] -ieq 'Calendar') {
            $Current = & $Get "$Base/mailFolders/calendar?`$select=id,displayName"
            $CurrentId = [string]$Current.id
            $Remaining = @($Segments | Select-Object -Skip 1)
        } else {
            $CurrentId = $RootId
        }

        $Walked = [System.Collections.Generic.List[string]]::new()
        foreach ($Segment in $Remaining) {
            $Walked.Add($Segment)
            $ParentSeg = [System.Uri]::EscapeDataString($CurrentId)
            $Children = @(& $Get "$Base/mailFolders/$ParentSeg/childFolders?`$select=id,displayName,parentFolderId,wellKnownName&`$top=999")
            $Matched = @($Children | Where-Object { $_.displayName -ieq $Segment })
            if ($Matched.Count -eq 0) { throw "Folder segment '$Segment' not found under '$($Walked -join '\')'." }
            if ($Matched.Count -gt 1) { throw "Folder segment '$Segment' matches multiple folders; use folderId instead." }
            $CurrentId = [string]$Matched[0].id
        }
        $ResolvedId = $CurrentId
    } else {
        $ResolvedId = $FolderId
    }

    $Folder = & $Get "$Base/mailFolders/$([System.Uri]::EscapeDataString($ResolvedId))?`$select=$FolderSelect&$ClassExpand"
    if ($null -eq $Folder -or [string]::IsNullOrWhiteSpace([string]$Folder.id)) { throw "Folder '$ResolvedId' not found." }

    # Build path by walking parents to the message root.
    $Names = [System.Collections.Generic.List[string]]::new()
    $Names.Add([string]$Folder.displayName)
    $ParentId = [string]$Folder.parentFolderId
    $Depth = 0
    while (-not [string]::IsNullOrWhiteSpace($ParentId) -and $ParentId -ne $RootId) {
        $Depth++
        if ($Depth -ge $MaxDepth) { throw "Folder path exceeds maximum depth of $MaxDepth." }
        $Parent = & $Get "$Base/mailFolders/$([System.Uri]::EscapeDataString($ParentId))?`$select=id,displayName,parentFolderId"
        $Names.Insert(0, [string]$Parent.displayName)
        $ParentId = [string]$Parent.parentFolderId
    }
    $Path = '\' + ($Names -join '\')
    $ParentPath = if ($Names.Count -gt 1) { '\' + (($Names | Select-Object -First ($Names.Count - 1)) -join '\') } else { '\' }

    $FolderClass = $null
    foreach ($Prop in @($Folder.singleValueExtendedProperties)) {
        if ($Prop.id -eq 'String 0x3613') { $FolderClass = [string]$Prop.value }
    }
    $Folder | Add-Member -NotePropertyName folderClass -NotePropertyValue $FolderClass -Force
    $Folder | Add-Member -NotePropertyName path -NotePropertyValue $Path -Force
    $Folder | Add-Member -NotePropertyName parentPath -NotePropertyValue $ParentPath -Force

    if ($FolderType -eq 'calendar') {
        # Shared/linked calendar detection: match the Graph calendar by name and merge isShared/owner for the guards.
        $Calendars = @(& $Get "$Base/calendars?`$select=id,name,isShared,owner,canEdit,isDefaultCalendar")
        $CalMatches = @($Calendars | Where-Object { $_.name -ieq $Folder.displayName })
        # Fail closed: only enrich when exactly one calendar matches; otherwise calendarMatched stays $false and the guards refuse.
        $Folder | Add-Member -NotePropertyName calendarMatched -NotePropertyValue ($CalMatches.Count -eq 1) -Force
        if ($CalMatches.Count -eq 1) {
            $Cal = $CalMatches[0]
            $Folder | Add-Member -NotePropertyName isShared -NotePropertyValue ($Cal.isShared -eq $true) -Force
            $Folder | Add-Member -NotePropertyName owner -NotePropertyValue $Cal.owner -Force
            $Folder | Add-Member -NotePropertyName isDefaultCalendar -NotePropertyValue ($Cal.isDefaultCalendar -eq $true) -Force
            $Folder | Add-Member -NotePropertyName calendarId -NotePropertyValue $Cal.id -Force
        }
    }

    [pscustomobject]@{
        Folder            = $Folder
        DeletedItemsId    = $DeletedItemsId
        ReservedFolderIds = @($ReservedFolderIds)
        Path              = $Path
        ParentPath        = $ParentPath
    }
}
