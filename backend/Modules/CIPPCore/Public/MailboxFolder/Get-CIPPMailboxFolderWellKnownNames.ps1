function Get-CIPPMailboxFolderWellKnownNames {
    <#
    .SYNOPSIS
        Graph well-known mail folder names that must never be soft-deleted.
    #>
    [CmdletBinding()]
    param()
    @(
        'inbox', 'drafts', 'sentitems', 'deleteditems', 'junkemail', 'outbox',
        'archive', 'clutter', 'conflicts', 'conversationhistory', 'localfailures',
        'serverfailures', 'syncissues', 'msgfolderroot', 'root', 'calendar',
        'contacts', 'notes', 'tasks', 'recoverableitemsroot', 'recoverableitemsdeletions',
        'recoverableitemsversions', 'recoverableitemspurges', 'searchfolders', 'scheduled'
    )
}