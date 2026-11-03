function Join-CIPPMailboxJunkSenderList {
    <#
    .SYNOPSIS
        Merges additions and removals into an existing junk-sender list.

    .DESCRIPTION
        Set-MailboxJunkEmailConfiguration's TrustedSendersToAdd parameter fails through the
        Exchange Online REST proxy. Callers get the current list, merge it here, and write
        the full list back with TrustedSendersAndDomains or BlockedSendersAndDomains.
        A value present in both Add and Remove is removed.
    #>
    [CmdletBinding()]
    param(
        $Existing,
        $Add,
        $Remove
    )

    $Current = [System.Collections.Generic.List[string]]::new()
    $Seen = @{}
    foreach ($Item in @(ConvertTo-CIPPMailFilterStringList $Existing)) {
        if ($Item -match '[\s<>]') { throw "Junk sender '$Item' contains invalid characters." }
        if ($Item -eq '*' -or $Item.Contains('*')) { throw 'A junk sender entry cannot include a wildcard.' }
        $Key = $Item.ToLowerInvariant()
        if (-not $Seen.ContainsKey($Key)) {
            $Seen[$Key] = $true
            $Current.Add($Item)
        }
    }

    $Added = [System.Collections.Generic.List[string]]::new()
    foreach ($Item in @(ConvertTo-CIPPMailFilterStringList $Add)) {
        if ($Item -match '[\s<>]') { throw "Junk sender '$Item' contains invalid characters." }
        if ($Item -eq '*' -or $Item.Contains('*')) { throw 'A junk sender entry cannot include a wildcard.' }
        $Key = $Item.ToLowerInvariant()
        if (-not $Seen.ContainsKey($Key)) {
            $Seen[$Key] = $true
            $Current.Add($Item)
            $Added.Add($Item)
        }
    }

    $Removed = [System.Collections.Generic.List[string]]::new()
    $RemoveKeys = @{}
    foreach ($Item in @(ConvertTo-CIPPMailFilterStringList $Remove)) {
        $RemoveKeys[$Item.ToLowerInvariant()] = $Item
    }
    foreach ($Key in @($RemoveKeys.Keys)) {
        if ($Seen.ContainsKey($Key)) {
            $Seen.Remove($Key)
            $Removed.Add([string]$RemoveKeys[$Key])
        }
    }

    $List = [System.Collections.Generic.List[string]]::new()
    foreach ($Item in $Current) {
        if ($Seen.ContainsKey($Item.ToLowerInvariant())) { $List.Add($Item) }
    }

    [pscustomobject]@{
        List    = @($List)
        Added   = @($Added)
        Removed = @($Removed)
    }
}
