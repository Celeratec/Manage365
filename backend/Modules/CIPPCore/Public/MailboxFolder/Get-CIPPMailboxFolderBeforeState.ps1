function Get-CIPPMailboxFolderBeforeState {
    <#
    .SYNOPSIS
        Capture a metadata-only snapshot of a mailbox folder before it is moved (read-only Graph).
    .DESCRIPTION
        Never records subjects or bodies. Oldest/newest item dates come from a single-item
        $orderby query on messages in the folder. For calendar folders with no messages, falls back to
        calendar events (createdDateTime) when the resolver supplied a calendarId.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$UserId,
        [Parameter(Mandatory)]$Folder,
        [string]$Path,
        [ValidateSet('mail', 'calendar')][string]$FolderType = 'mail'
    )

    $Base = "https://graph.microsoft.com/v1.0/users/$([System.Uri]::EscapeDataString($UserId))"
    $FolderSeg = [System.Uri]::EscapeDataString([string]$Folder.id)

    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = [string]$Folder.path }
    $ParentPath = [string]$Folder.parentPath
    if ([string]::IsNullOrWhiteSpace($ParentPath) -and -not [string]::IsNullOrWhiteSpace($Path)) {
        $Idx = $Path.LastIndexOf('\')
        $ParentPath = if ($Idx -gt 0) { $Path.Substring(0, $Idx) } else { '\' }
    }

    $FolderId = [string]$Folder.id
    $SkipDateQueries = $false
    if ($null -ne $Folder.totalItemCount) {
        $SkipDateQueries = ([int]$Folder.totalItemCount -eq 0)
    } elseif (
        (($null -eq $Folder.childFolderCount) -or ([int]$Folder.childFolderCount -eq 0)) -and
        (($null -eq $Folder.unreadItemCount) -or ([int]$Folder.unreadItemCount -eq 0)) -and
        (($null -ne $Folder.childFolderCount) -or ($null -ne $Folder.unreadItemCount))
    ) {
        $SkipDateQueries = $true
    }

    $Oldest = $null
    $Newest = $null

    if (-not $SkipDateQueries) {
        $GetDate = {
            param([string]$Order)
            try {
                $Item = New-GraphGetRequest -uri "$Base/mailFolders/$FolderSeg/messages?`$select=receivedDateTime,createdDateTime&`$orderby=receivedDateTime $Order&`$top=1" -tenantid $TenantFilter -AsApp $true |
                    Select-Object -First 1
            } catch {
                Write-Warning "Mailbox folder before-state: date lookup failed for folder id $FolderId (messages)."
                $Item = $null
            }
            if ($null -ne $Item) { return ($Item.receivedDateTime ?? $Item.createdDateTime) }
            if ($FolderType -eq 'calendar' -and -not [string]::IsNullOrWhiteSpace([string]$Folder.calendarId)) {
                try {
                    $Event = New-GraphGetRequest -uri "$Base/calendars/$([System.Uri]::EscapeDataString([string]$Folder.calendarId))/events?`$select=createdDateTime&`$orderby=createdDateTime $Order&`$top=1" -tenantid $TenantFilter -AsApp $true |
                        Select-Object -First 1
                    if ($null -ne $Event) { return $Event.createdDateTime }
                } catch {
                    Write-Warning "Mailbox folder before-state: date lookup failed for folder id $FolderId (calendar events)."
                }
            }
            return $null
        }

        $Oldest = & $GetDate 'asc'
        $Newest = & $GetDate 'desc'
    }

    [ordered]@{
        path           = $Path
        id             = [string]$Folder.id
        parentId       = [string]$Folder.parentFolderId
        parentPath     = $ParentPath
        # Graph v1.0 mailFolder has no folderClass; Resolve-CIPPMailboxFolder fills it from extended prop 0x3613 (may be $null).
        folderClass    = $Folder.folderClass
        itemCount      = $Folder.totalItemCount
        size           = $Folder.sizeInBytes
        oldestItemDate = $Oldest
        newestItemDate = $Newest
    }
}
