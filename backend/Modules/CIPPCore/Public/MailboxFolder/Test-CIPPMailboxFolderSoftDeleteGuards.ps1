function Test-CIPPMailboxFolderSoftDeleteGuards {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Folder,
        [Parameter(Mandatory)][string]$DeletedItemsId,
        [string]$MailboxUpn
    )
    $WellKnown = Get-CIPPMailboxFolderWellKnownNames
    $Wkn = [string]$Folder.wellKnownName
    if (-not [string]::IsNullOrWhiteSpace($Wkn) -and $WellKnown -contains $Wkn.ToLowerInvariant()) {
        return [pscustomobject]@{ Ok = $false; Reason = "Refusing well-known/default folder '$Wkn'." }
    }
    if ($Folder.isSearchFolder -eq $true) {
        return [pscustomobject]@{ Ok = $false; Reason = 'Refusing search folders.' }
    }
    if ([string]$Folder.parentFolderId -eq $DeletedItemsId -or $Wkn -eq 'deleteditems') {
        return [pscustomobject]@{ Ok = $false; Reason = 'Folder is already under Deleted Items.' }
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