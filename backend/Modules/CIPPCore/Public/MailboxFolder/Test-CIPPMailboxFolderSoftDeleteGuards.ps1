function Test-CIPPMailboxFolderSoftDeleteGuards {
    <#
    .SYNOPSIS
        Fail-closed guards for mailbox folder soft-delete (default/well-known, search, shared, type-mismatch folders).
    .PARAMETER ReservedFolderIds
        Resolved ids of well-known folders (inbox, calendar, contacts, tasks, notes, ...). A folder whose id is in
        this list is refused even when Graph did not return a wellKnownName for it.
    .PARAMETER FolderType
        'mail' or 'calendar' as requested by the caller; used to detect class/type mismatches and unenriched calendars.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Folder,
        [Parameter(Mandatory)][string]$DeletedItemsId,
        [string]$MailboxUpn,
        [string[]]$ReservedFolderIds = @(),
        [ValidateSet('mail', 'calendar')][string]$FolderType = 'mail'
    )
    $WellKnown = Get-CIPPMailboxFolderWellKnownNames
    $Wkn = [string]$Folder.wellKnownName
    $ODataType = [string]$Folder.'@odata.type'

    # Search folders (virtual, never movable via this path).
    if (
        $Folder.isSearchFolder -eq $true -or
        $ODataType -match 'mailSearchFolder' -or
        $Wkn -ieq 'searchfolders'
    ) {
        return [pscustomobject]@{ Ok = $false; Reason = 'Refusing search folders.' }
    }
    if (-not [string]::IsNullOrWhiteSpace($Wkn) -and $WellKnown -contains $Wkn.ToLowerInvariant()) {
        return [pscustomobject]@{ Ok = $false; Reason = "Refusing well-known/default folder '$Wkn'." }
    }
    # Default calendar / well-known ids: do not rely on wellKnownName alone.
    if ($Folder.isDefaultCalendar -eq $true) {
        return [pscustomobject]@{ Ok = $false; Reason = 'Refusing well-known/default folder (default calendar).' }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Folder.id) -and @($ReservedFolderIds) -ccontains [string]$Folder.id) {
        return [pscustomobject]@{ Ok = $false; Reason = 'Refusing well-known/default folder (matches a reserved folder id).' }
    }
    if ([string]$Folder.parentFolderId -eq $DeletedItemsId -or $Wkn -eq 'deleteditems') {
        return [pscustomobject]@{ Ok = $false; Reason = 'Folder is already under Deleted Items.' }
    }

    # Folder class / requested type mismatch (only when the class is known).
    $Class = [string]$Folder.folderClass
    if (-not [string]::IsNullOrWhiteSpace($Class)) {
        $IsAppointment = $Class -match '^IPF\.Appointment'
        if ($FolderType -eq 'mail' -and $IsAppointment) {
            return [pscustomobject]@{ Ok = $false; Reason = "Refusing: folderType is 'mail' but the folder class is '$Class' (calendar)." }
        }
        if ($FolderType -eq 'calendar' -and -not $IsAppointment) {
            return [pscustomobject]@{ Ok = $false; Reason = "Refusing: folderType is 'calendar' but the folder class is '$Class'." }
        }
    }
    # Calendar must have been positively matched to exactly one Graph calendar, or shared/default status is unknown.
    if ($FolderType -eq 'calendar' -and $Folder.calendarMatched -ne $true) {
        return [pscustomobject]@{ Ok = $false; Reason = 'Refusing calendar: no unique matching calendar was found to confirm it is not shared or default.' }
    }

    $Shared = ($Folder.isShared -eq $true) -or ($Folder.isRemovable -eq $false -and $null -ne $Folder.owner)
    if ($Folder.PSObject.Properties.Name -contains 'canShare' -and $Folder.isDefaultCalendar -eq $true -and $Folder.isShared -eq $true) {
        $Shared = $true
    }
    if ($null -ne $Folder.owner) {
        $OwnerAddr = [string]($Folder.owner.address ?? $Folder.owner.emailAddress ?? $Folder.owner)
        if (-not [string]::IsNullOrWhiteSpace($MailboxUpn) -and -not [string]::IsNullOrWhiteSpace($OwnerAddr) -and $OwnerAddr -ne $MailboxUpn) {
            $Shared = $true
        }
    }
    if ($Shared) {
        return [pscustomobject]@{ Ok = $false; Reason = 'Refusing shared, linked, or delegated calendars that point at another mailbox.' }
    }
    return [pscustomobject]@{ Ok = $true; Reason = $null }
}
