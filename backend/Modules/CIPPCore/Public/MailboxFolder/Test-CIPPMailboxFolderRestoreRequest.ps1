function Test-CIPPMailboxFolderRestoreRequest {
    [CmdletBinding()]
    param($Request)

    $Body = $Request.Body
    $UserId = [string]($Body.userId ?? $Body.userid ?? $Body.UserPrincipalName)
    $DeletedFolderId = [string]$Body.deletedFolderId
    $OriginalParentId = [string]$Body.originalParentId
    $FolderType = ([string]$Body.folderType).ToLowerInvariant()
    $Reason = [string]($Body.Reason ?? $Body.reason)

    # preview / dryRun / WhatIf: fail closed toward preview. Any true wins; a true/false disagreement is a 400.
    $FlagValues = [System.Collections.Generic.List[bool]]::new()
    foreach ($Raw in @($Body.preview, $Body.dryRun, $Body.WhatIf)) {
        if ($null -eq $Raw -or "$Raw" -eq '') { continue }
        if ("$Raw" -notin @('true', 'false', '1', '0', 'True', 'False')) {
            return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'preview/dryRun must be true or false.' }
        }
        $FlagValues.Add("$Raw" -in @('true', 'True', '1'))
    }
    if ($FlagValues.Contains($true) -and $FlagValues.Contains($false)) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'preview and dryRun conflict; send the same value for both or only one.' }
    }
    $Preview = ($FlagValues.Count -eq 0) -or $FlagValues.Contains($true)
    # Force dryRun on body so Test-CIPPGuardedWriteRequest does not default WhatIf to false
    if ($Body -is [hashtable] -or $Body -is [System.Collections.IDictionary]) {
        $Body['dryRun'] = $Preview
    } else {
        $Body | Add-Member -NotePropertyName dryRun -NotePropertyValue $Preview -Force
    }

    if ([string]::IsNullOrWhiteSpace($UserId)) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'userId is required.' }
    }
    if ([string]::IsNullOrWhiteSpace($Reason)) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'Reason is required.' }
    }
    if ([string]::IsNullOrWhiteSpace($DeletedFolderId)) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'deletedFolderId is required.' }
    }
    if ([string]::IsNullOrWhiteSpace($OriginalParentId)) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'originalParentId is required.' }
    }
    if ($FolderType -notin @('mail', 'calendar')) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = "folderType must be 'mail' or 'calendar'." }
    }

    return [pscustomobject]@{
        Ok               = $true
        StatusCode       = 200
        UserId           = $UserId
        DeletedFolderId  = $DeletedFolderId
        OriginalParentId = $OriginalParentId
        FolderType       = $FolderType
        Preview          = $Preview
        Reason           = $Reason
    }
}
