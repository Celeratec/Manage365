Describe 'Test-CIPPMailboxFolderSoftDeleteGuards' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderWellKnownNames.ps1')
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteGuards.ps1')
    }

    It 'refuses inbox by wellKnownName' {
        $Folder = [pscustomobject]@{ id = 'abc'; wellKnownName = 'inbox'; displayName = 'Not Inbox'; parentFolderId = 'parent' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'well-known|default'
    }

    It 'refuses calendar root by wellKnownName even if displayName differs' {
        $Folder = [pscustomobject]@{ id = 'cal'; wellKnownName = 'calendar'; displayName = 'My Calendar'; parentFolderId = 'msgroot' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
    }

    It 'refuses shared or linked calendars' {
        $Folder = [pscustomobject]@{
            id             = 'shared1'
            wellKnownName  = $null
            displayName    = 'Cody Rogers'
            parentFolderId = 'cal-root'
            isShared       = $true
            owner          = @{ address = 'other@contoso.com' }
        }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -MailboxUpn 'user@contoso.com'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'shared|linked|delegat'
    }

    It 'refuses a folder already under Deleted Items' {
        $Folder = [pscustomobject]@{ id = 'x'; wellKnownName = $null; parentFolderId = 'del-id'; displayName = 'Old' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'Deleted Items'
    }

    It 'refuses search folders' {
        $Folder = [pscustomobject]@{ id = 's'; wellKnownName = $null; parentFolderId = 'p'; isSearchFolder = $true; displayName = 'Search' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'search'
    }

    It 'allows a normal child calendar folder' {
        $Folder = [pscustomobject]@{
            id              = 'ok'
            wellKnownName   = $null
            parentFolderId  = 'cal-root'
            displayName     = 'Cody Rogers'
            isShared        = $false
            isSearchFolder  = $false
        }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -MailboxUpn 'user@contoso.com'
        $Result.Ok | Should -BeTrue
    }

    It 'refuses the default calendar by isDefaultCalendar even when wellKnownName is null' {
        $Folder = [pscustomobject]@{
            id = 'defcal'; wellKnownName = $null; displayName = 'Agenda'; parentFolderId = 'msgroot'
            isDefaultCalendar = $true; isShared = $false; calendarMatched = $true; folderClass = 'IPF.Appointment'
        }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -MailboxUpn 'user@contoso.com' -FolderType 'calendar'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'default'
    }

    It 'refuses a folder whose id matches a reserved well-known folder id' {
        $Folder = [pscustomobject]@{ id = 'CONTACTS-ID'; wellKnownName = $null; displayName = 'People'; parentFolderId = 'msgroot' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -ReservedFolderIds @('INBOX-ID', 'CONTACTS-ID')
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'well-known|default|reserved'
    }

    It 'allows a normal folder when ReservedFolderIds does not contain its id' {
        $Folder = [pscustomobject]@{ id = 'ok'; wellKnownName = $null; displayName = 'Projects'; parentFolderId = 'inbox' }
        (Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -ReservedFolderIds @('INBOX-ID')).Ok | Should -BeTrue
    }

    It 'refuses a calendar that was not matched to a unique Graph calendar (fail closed)' {
        $Folder = [pscustomobject]@{ id = 'c1'; wellKnownName = $null; displayName = 'Shared Thing'; parentFolderId = 'cal-root'; calendarMatched = $false }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -MailboxUpn 'user@contoso.com' -FolderType 'calendar'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'matching calendar'
    }

    It 'refuses a calendar with no calendarMatched flag at all (fail closed)' {
        $Folder = [pscustomobject]@{ id = 'c1'; wellKnownName = $null; displayName = 'X'; parentFolderId = 'cal-root' }
        (Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -FolderType 'calendar').Ok | Should -BeFalse
    }

    It 'allows a uniquely matched, non-shared, non-default calendar' {
        $Folder = [pscustomobject]@{
            id = 'c1'; wellKnownName = $null; displayName = 'Team'; parentFolderId = 'cal-root'
            calendarMatched = $true; isShared = $false; isDefaultCalendar = $false; folderClass = 'IPF.Appointment'
        }
        (Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -MailboxUpn 'user@contoso.com' -FolderType 'calendar').Ok | Should -BeTrue
    }

    It 'refuses folderType mail when the folder class is IPF.Appointment' {
        $Folder = [pscustomobject]@{ id = 'c1'; wellKnownName = $null; displayName = 'Team'; parentFolderId = 'cal-root'; folderClass = 'IPF.Appointment' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -FolderType 'mail'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'folder class|mismatch|calendar'
    }

    It 'refuses folderType calendar when the folder class is a mail class' {
        $Folder = [pscustomobject]@{ id = 'm1'; wellKnownName = $null; displayName = 'Projects'; parentFolderId = 'inbox'; folderClass = 'IPF.Note'; calendarMatched = $true }
        (Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -FolderType 'calendar').Ok | Should -BeFalse
    }

    It 'refuses search folders by @odata.type mailSearchFolder' {
        $Folder = [pscustomobject]@{ id = 's'; wellKnownName = $null; parentFolderId = 'p'; displayName = 'Saved search' }
        $Folder | Add-Member -NotePropertyName '@odata.type' -NotePropertyValue '#microsoft.graph.mailSearchFolder'
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'search'
    }

    It 'refuses search folders by wellKnownName searchfolders' {
        $Folder = [pscustomobject]@{ id = 's'; wellKnownName = 'searchfolders'; parentFolderId = 'p'; displayName = 'Search Folders' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'search'
    }

    It 'refuses the scheduled well-known folder' {
        $Folder = [pscustomobject]@{ id = 's'; wellKnownName = 'scheduled'; parentFolderId = 'p'; displayName = 'Scheduled' }
        (Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id').Ok | Should -BeFalse
    }

    It 'lists searchfolders and scheduled as well-known names' {
        $Names = Get-CIPPMailboxFolderWellKnownNames
        $Names | Should -Contain 'searchfolders'
        $Names | Should -Contain 'scheduled'
    }
}

Describe 'Test-CIPPMailboxFolderSoftDeleteRequest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteRequest.ps1')
    }

    It 'defaults preview to true when dryRun and preview omitted' {
        $Body = [pscustomobject]@{
            tenantFilter = 'contoso.onmicrosoft.com'
            userId       = 'user@contoso.com'
            folderId     = 'folder-1'
            folderType   = 'calendar'
            TicketNumber = '3281353'
            Reason       = 'stale calendar copy'
        }
        $Req = @{ Body = $Body; Headers = @{} }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request $Req
        $Parsed.Ok | Should -BeTrue
        $Parsed.Preview | Should -BeTrue
        [string]$Req.Body.dryRun | Should -Be 'True'
    }

    It 'rejects missing Reason' {
        $Body = [pscustomobject]@{
            tenantFilter = 't'; userId = 'u@t.com'; folderId = 'f'; folderType = 'mail'
            TicketNumber = '3281353'
        }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.StatusCode | Should -Be 400
        $Parsed.Message | Should -Match 'Reason'
    }

    It 'rejects both folderId and folderPath missing' {
        $Body = [pscustomobject]@{
            tenantFilter = 't'; userId = 'u@t.com'; folderType = 'mail'
            TicketNumber = '3281353'; Reason = 'x'
        }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.Message | Should -Match 'folderId|folderPath'
    }

    It 'rejects both folderId and folderPath set' {
        $Body = [pscustomobject]@{
            tenantFilter = 't'; userId = 'u@t.com'; folderType = 'mail'
            folderId = 'a'; folderPath = '\Inbox\X'
            TicketNumber = '3281353'; Reason = 'x'
        }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
    }

    It 'rejects invalid folderType' {
        $Body = [pscustomobject]@{
            tenantFilter = 't'; userId = 'u@t.com'; folderId = 'a'; folderType = 'notes'
            TicketNumber = '3281353'; Reason = 'x'
        }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.Message | Should -Match 'folderType'
    }

    It 'returns 400 when preview and dryRun conflict' {
        foreach ($Pair in @(@('true', 'false'), @('false', 'true'))) {
            $Body = @{ tenantFilter = 't'; userId = 'u@t.com'; folderId = 'f'; folderType = 'mail'; TicketNumber = '3281353'; Reason = 'x' }
            $Body.preview = $Pair[0]; $Body.dryRun = $Pair[1]
            $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
            $Parsed.Ok | Should -BeFalse
            $Parsed.StatusCode | Should -Be 400
            $Parsed.Message | Should -Match 'conflict'
        }
    }

    It 'returns 400 when preview and WhatIf conflict' {
        $Body = @{ tenantFilter = 't'; userId = 'u@t.com'; folderId = 'f'; folderType = 'mail'; TicketNumber = '3281353'; Reason = 'x' }
        $Body.preview = 'true'; $Body.WhatIf = 'false'
        (Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }).StatusCode | Should -Be 400
    }

    It 'treats either flag true as preview (other absent or also true)' {
        foreach ($Case in @(@{ preview = 'true' }, @{ dryRun = 'true' }, @{ WhatIf = 'true' }, @{ preview = 'true'; dryRun = 'true' })) {
            $Body = @{ tenantFilter = 't'; userId = 'u@t.com'; folderId = 'f'; folderType = 'mail'; TicketNumber = '3281353'; Reason = 'x' }
            foreach ($K in $Case.Keys) { $Body[$K] = $Case[$K] }
            $Req = @{ Body = $Body; Headers = @{} }
            $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request $Req
            $Parsed.Ok | Should -BeTrue
            $Parsed.Preview | Should -BeTrue
            $Req.Body.dryRun | Should -BeTrue
        }
    }

    It 'allows a real run only when every supplied flag is false' {
        $Body = @{ tenantFilter = 't'; userId = 'u@t.com'; folderId = 'f'; folderType = 'mail'; TicketNumber = '3281353'; Reason = 'x' }
        $Body.preview = 'false'; $Body.dryRun = 'false'
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeTrue
        $Parsed.Preview | Should -BeFalse
    }
}

Describe 'Resolve-CIPPMailboxFolder and Get-CIPPMailboxFolderBeforeState' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderWellKnownNames.ps1')
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteGuards.ps1')
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Resolve-CIPPMailboxFolder.ps1')
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderBeforeState.ps1')

        # Stubs so Pester can Mock them; POST/DELETE must never be called.
        function New-GraphGetRequest { param($uri, $tenantid, $AsApp, $noPagination, $NoAuthCheck, [switch]$ComplexFilter) }
        function New-GraphPOSTRequest { param($uri, $tenantid, $body, $type, $AsApp) }
        function New-GraphBulkRequest { param($tenantid, $Requests, $AsApp) }

        $script:Tree = @{
            'ROOT'  = [pscustomobject]@{ id = 'ROOT'; displayName = 'Top of Information Store'; parentFolderId = $null; wellKnownName = 'msgfolderroot' }
            'INBOX' = [pscustomobject]@{ id = 'INBOX'; displayName = 'Inbox'; parentFolderId = 'ROOT'; wellKnownName = 'inbox'; totalItemCount = 5; sizeInBytes = 100 }
            'PROJ'  = [pscustomobject]@{ id = 'PROJ'; displayName = 'Projects'; parentFolderId = 'INBOX'; wellKnownName = $null; totalItemCount = 12; unreadItemCount = 2; childFolderCount = 0; sizeInBytes = 4096; isHidden = $false }
            'DEL'   = [pscustomobject]@{ id = 'DEL'; displayName = 'Deleted Items'; parentFolderId = 'ROOT'; wellKnownName = 'deleteditems' }
            'DUP1'  = [pscustomobject]@{ id = 'DUP1'; displayName = 'Dup'; parentFolderId = 'ROOT'; wellKnownName = $null }
            'DUP2'  = [pscustomobject]@{ id = 'DUP2'; displayName = 'Dup'; parentFolderId = 'ROOT'; wellKnownName = $null }
            'CAL'   = [pscustomobject]@{ id = 'CAL'; displayName = 'Calendar'; parentFolderId = 'ROOT'; wellKnownName = 'calendar' }
            'CALW'  = [pscustomobject]@{ id = 'CALW'; displayName = 'Cody Rogers'; parentFolderId = 'CAL'; wellKnownName = $null }
        }
        $script:Tree['PROJ'] | Add-Member -NotePropertyName singleValueExtendedProperties -NotePropertyValue @([pscustomobject]@{ id = 'String 0x3613'; value = 'IPF.Note' })

        $script:GraphMock = {
            param($uri, $tenantid, $AsApp)
            $Path = ($uri -split '\?')[0]
            $Prefix = 'https://graph.microsoft.com/v1.0/users/user%40contoso.com/'
            if (-not $Path.StartsWith($Prefix)) { throw "Unexpected URI $uri" }
            $Rel = $Path.Substring($Prefix.Length)
            switch -Regex ($Rel) {
                '^mailFolders/deleteditems$' { return $script:Tree['DEL'] }
                '^mailFolders/msgfolderroot$' { return $script:Tree['ROOT'] }
                '^mailFolders/calendar$' { return $script:Tree['CAL'] }
                '^mailFolders/([^/]+)/childFolders$' {
                    $Parent = [uri]::UnescapeDataString($Matches[1])
                    if ($Parent -eq 'msgfolderroot') { $Parent = 'ROOT' }
                    return @($script:Tree.Values | Where-Object { $_.parentFolderId -eq $Parent })
                }
                '^mailFolders/([^/]+)/messages$' {
                    if ($uri -match 'asc') { return @([pscustomobject]@{ receivedDateTime = '2020-01-01T00:00:00Z'; createdDateTime = '2020-01-01T00:00:00Z' }) }
                    return @([pscustomobject]@{ receivedDateTime = '2026-05-01T00:00:00Z'; createdDateTime = '2026-05-01T00:00:00Z' })
                }
                '^mailFolders/([^/]+)$' {
                    $Id = [uri]::UnescapeDataString($Matches[1])
                    if ($script:Tree.ContainsKey($Id)) { return $script:Tree[$Id] }
                    throw "404 $Id"
                }
                '^calendars$' {
                    return @([pscustomobject]@{ id = 'calid1'; name = 'Cody Rogers'; isShared = $true; owner = [pscustomobject]@{ name = 'Cody'; address = 'cody@contoso.com' }; canEdit = $false; isDefaultCalendar = $false })
                }
                default { throw "Unmocked path $Rel" }
            }
        }
        Mock New-GraphGetRequest $script:GraphMock
        Mock New-GraphPOSTRequest { throw 'POST must not be called' }
        Mock New-GraphBulkRequest { throw 'Bulk must not be called' }
    }

    It 'resolves a mail folder by path and returns DeletedItemsId and Path' {
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderPath '\Inbox\Projects' -FolderType 'mail'
        $R.Folder.id | Should -Be 'PROJ'
        $R.DeletedItemsId | Should -Be 'DEL'
        $R.Path | Should -Be '\Inbox\Projects'
    }

    It 'resolves by folderId and builds the path from parents' {
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'PROJ' -FolderType 'mail'
        $R.Folder.id | Should -Be 'PROJ'
        $R.Path | Should -Be '\Inbox\Projects'
        $R.Folder.parentFolderId | Should -Be 'INBOX'
    }

    It 'surfaces folderClass from the extended property when available' {
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'PROJ' -FolderType 'mail'
        $R.Folder.folderClass | Should -Be 'IPF.Note'
    }

    It 'throws when a path segment is not found' {
        { Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderPath '\Inbox\Nope' -FolderType 'mail' } | Should -Throw '*not found*'
    }

    It 'throws when a path segment matches multiple folders' {
        { Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderPath '\Dup' -FolderType 'mail' } | Should -Throw '*multiple*'
    }

    It 'resolves calendar paths under \Calendar and merges isShared/owner onto the folder' {
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderPath '\Calendar\Cody Rogers' -FolderType 'calendar'
        $R.Folder.id | Should -Be 'CALW'
        $R.Path | Should -Be '\Calendar\Cody Rogers'
        $R.Folder.isShared | Should -BeTrue
        $R.Folder.owner.address | Should -Be 'cody@contoso.com'
        $Guard = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $R.Folder -DeletedItemsId $R.DeletedItemsId -MailboxUpn 'user@contoso.com'
        $Guard.Ok | Should -BeFalse
    }

    It 'returns resolved well-known folder ids as ReservedFolderIds' {
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'PROJ' -FolderType 'mail'
        $R.ReservedFolderIds | Should -Contain 'INBOX'
        $R.ReservedFolderIds | Should -Contain 'DEL'
        $R.ReservedFolderIds | Should -Contain 'CAL'
        $R.ReservedFolderIds | Should -Not -Contain 'PROJ'
        $Guard = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $R.Folder -DeletedItemsId $R.DeletedItemsId -ReservedFolderIds $R.ReservedFolderIds
        $Guard.Ok | Should -BeTrue
    }

    It 'guards refuse the resolved Inbox by reserved id even if wellKnownName were missing' {
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'INBOX' -FolderType 'mail'
        $NoName = $R.Folder | Select-Object -Property * -ExcludeProperty wellKnownName
        $NoName | Add-Member -NotePropertyName wellKnownName -NotePropertyValue $null
        (Test-CIPPMailboxFolderSoftDeleteGuards -Folder $NoName -DeletedItemsId $R.DeletedItemsId -ReservedFolderIds $R.ReservedFolderIds).Ok | Should -BeFalse
    }

    It 'sets calendarMatched true for a unique calendar match and false when no calendar matches (guards refuse)' {
        $Matched = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'CALW' -FolderType 'calendar'
        $Matched.Folder.calendarMatched | Should -BeTrue

        Mock New-GraphGetRequest {
            if ($uri -match '/calendars\?') { return @([pscustomobject]@{ id = 'other'; name = 'Some Other Calendar'; isShared = $false; isDefaultCalendar = $false }) }
            & $script:GraphMock $uri $tenantid $AsApp
        }
        $Unmatched = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'CALW' -FolderType 'calendar'
        $Unmatched.Folder.calendarMatched | Should -BeFalse
        $Guard = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Unmatched.Folder -DeletedItemsId $Unmatched.DeletedItemsId -ReservedFolderIds $Unmatched.ReservedFolderIds -FolderType 'calendar'
        $Guard.Ok | Should -BeFalse
    }

    It 'treats multiple same-name calendars as unmatched (fail closed)' {
        Mock New-GraphGetRequest {
            if ($uri -match '/calendars\?') {
                return @(
                    [pscustomobject]@{ id = 'a'; name = 'Cody Rogers'; isShared = $false; isDefaultCalendar = $false },
                    [pscustomobject]@{ id = 'b'; name = 'Cody Rogers'; isShared = $true; isDefaultCalendar = $false }
                )
            }
            & $script:GraphMock $uri $tenantid $AsApp
        }
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'CALW' -FolderType 'calendar'
        $R.Folder.calendarMatched | Should -BeFalse
    }

    It 'merges isDefaultCalendar onto a calendar whose wellKnownName is null and the guard refuses it' {
        Mock New-GraphGetRequest {
            if ($uri -match '/calendars\?') { return @([pscustomobject]@{ id = 'd'; name = 'Cody Rogers'; isShared = $false; isDefaultCalendar = $true }) }
            & $script:GraphMock $uri $tenantid $AsApp
        }
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'CALW' -FolderType 'calendar'
        $R.Folder.wellKnownName | Should -BeNullOrEmpty
        $R.Folder.isDefaultCalendar | Should -BeTrue
        (Test-CIPPMailboxFolderSoftDeleteGuards -Folder $R.Folder -DeletedItemsId $R.DeletedItemsId -ReservedFolderIds $R.ReservedFolderIds -FolderType 'calendar').Ok | Should -BeFalse
    }

    It 'only issues read-only Graph GETs with -AsApp $true and never POSTs' {
        Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderPath '\Inbox\Projects' -FolderType 'mail' | Out-Null
        Should -Invoke New-GraphGetRequest -ParameterFilter { $AsApp -ne $true } -Times 0 -Exactly
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
        Should -Invoke New-GraphBulkRequest -Times 0 -Exactly
    }

    It 'url-encodes user and folder ids in the URI' {
        Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'PROJ' -FolderType 'mail' | Out-Null
        Should -Invoke New-GraphGetRequest -ParameterFilter { $uri -match 'users/user%40contoso\.com/' } -Times 1
    }

    It 'collects before-state with expected shape and no subjects or bodies' {
        $R = Resolve-CIPPMailboxFolder -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -FolderId 'PROJ' -FolderType 'mail'
        $S = Get-CIPPMailboxFolderBeforeState -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Folder $R.Folder -Path $R.Path
        $S.path | Should -Be '\Inbox\Projects'
        $S.id | Should -Be 'PROJ'
        $S.parentId | Should -Be 'INBOX'
        $S.parentPath | Should -Be '\Inbox'
        $S.folderClass | Should -Be 'IPF.Note'
        $S.itemCount | Should -Be 12
        $S.size | Should -Be 4096
        [string]$S.oldestItemDate | Should -Match '^2020-01-01'
        [string]$S.newestItemDate | Should -Match '^2026-05-01'
        $Names = @($S.Keys)
        foreach ($Bad in 'subject', 'body', 'bodyPreview') { $Names | Should -Not -Contain $Bad }
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'returns null item dates when the folder has no messages' {
        Mock New-GraphGetRequest {
            if ($uri -match '/messages') { return @() }
            & $script:GraphMock $uri $tenantid $AsApp
        }
        $Folder = $script:Tree['PROJ']
        $S = Get-CIPPMailboxFolderBeforeState -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Folder $Folder -Path '\Inbox\Projects'
        $S.oldestItemDate | Should -BeNullOrEmpty
        $S.newestItemDate | Should -BeNullOrEmpty
    }

    It 'skips date Graph queries when totalItemCount is zero' {
        $Folder = [pscustomobject]@{
            id               = 'EMPTY'
            parentFolderId   = 'INBOX'
            totalItemCount   = 0
            childFolderCount = 0
            sizeInBytes      = 0
        }
        $S = Get-CIPPMailboxFolderBeforeState -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Folder $Folder -Path '\Inbox\Empty'
        Should -Not -Invoke New-GraphGetRequest -ParameterFilter { $uri -match '/messages|/events' }
        $S.oldestItemDate | Should -BeNullOrEmpty
        $S.newestItemDate | Should -BeNullOrEmpty
    }

    It 'writes a warning when messages date lookup fails' {
        Mock New-GraphGetRequest {
            if ($uri -match '/messages') { throw 'Graph throttled' }
            & $script:GraphMock $uri $tenantid $AsApp
        }
        $Folder = $script:Tree['PROJ']
        $S = Get-CIPPMailboxFolderBeforeState -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Folder $Folder -Path '\Inbox\Projects' -WarningVariable dateWarn -WarningAction SilentlyContinue
        $S.oldestItemDate | Should -BeNullOrEmpty
        $S.newestItemDate | Should -BeNullOrEmpty
        @($dateWarn) | Should -Not -BeNullOrEmpty
        ($dateWarn -join ' ') | Should -Match 'PROJ'
        ($dateWarn -join ' ') | Should -Match 'date lookup failed'
    }
}

Describe 'Invoke-CIPPMailboxFolderSoftDelete' {
    BeforeAll {
        foreach ($F in 'Get-CIPPMailboxFolderWellKnownNames', 'Test-CIPPMailboxFolderSoftDeleteGuards', 'Resolve-CIPPMailboxFolder', 'Get-CIPPMailboxFolderBeforeState', 'Invoke-CIPPMailboxFolderSoftDelete') {
            . (Join-Path $PSScriptRoot "../../Modules/CIPPCore/Public/MailboxFolder/$F.ps1")
        }

        function New-GraphGetRequest { param($uri, $tenantid, $AsApp, $noPagination, $NoAuthCheck, [switch]$ComplexFilter) }
        function New-GraphPOSTRequest { param($uri, $tenantid, $body, $type, $AsApp) }
        function New-GraphBulkRequest { param($tenantid, $Requests, $AsApp) }

        $script:Tree = @{
            'ROOT'  = [pscustomobject]@{ id = 'ROOT'; displayName = 'Top of Information Store'; parentFolderId = $null; wellKnownName = 'msgfolderroot' }
            'INBOX' = [pscustomobject]@{ id = 'INBOX'; displayName = 'Inbox'; parentFolderId = 'ROOT'; wellKnownName = 'inbox'; totalItemCount = 5; sizeInBytes = 100 }
            'PROJ'  = [pscustomobject]@{ id = 'PROJ'; displayName = 'Projects'; parentFolderId = 'INBOX'; wellKnownName = $null; totalItemCount = 12; unreadItemCount = 2; childFolderCount = 0; sizeInBytes = 4096; isHidden = $false }
            'DEL'   = [pscustomobject]@{ id = 'DEL'; displayName = 'Deleted Items'; parentFolderId = 'ROOT'; wellKnownName = 'deleteditems' }
        }

        # State flags driven per test.
        $script:Moved = $false
        $script:NewFolder = $null
        $script:OldIdError = '404 ErrorItemNotFound: The specified object was not found in the store.'

        $script:GraphMock = {
            param($uri, $tenantid, $AsApp)
            $Path = ($uri -split '\?')[0]
            $Prefix = 'https://graph.microsoft.com/v1.0/users/user%40contoso.com/'
            if (-not $Path.StartsWith($Prefix)) { throw "Unexpected URI $uri" }
            $Rel = $Path.Substring($Prefix.Length)
            switch -Regex ($Rel) {
                '^mailFolders/deleteditems$' { return $script:Tree['DEL'] }
                '^mailFolders/msgfolderroot$' { return $script:Tree['ROOT'] }
                '^mailFolders/([^/]+)/messages$' { return @([pscustomobject]@{ receivedDateTime = '2020-01-01T00:00:00Z' }) }
                '^mailFolders/([^/]+)$' {
                    $Id = [uri]::UnescapeDataString($Matches[1])
                    if ($Id -eq 'PROJ' -and $script:Moved) { throw $script:OldIdError }
                    if ($null -ne $script:NewFolder -and $Id -eq $script:NewFolder.id -and $script:Moved) { return $script:NewFolder }
                    if ($script:Tree.ContainsKey($Id)) { return $script:Tree[$Id] }
                    throw "404 $Id"
                }
                default { throw "Unmocked path $Rel" }
            }
        }
        $script:Parsed = [pscustomobject]@{ UserId = 'user@contoso.com'; FolderId = 'PROJ'; FolderPath = $null; FolderType = 'mail' }
    }

    BeforeEach {
        $script:Moved = $false
        $script:PostCalls = 0
        $script:PostUris = @()
        $script:OldIdError = '404 ErrorItemNotFound: The specified object was not found in the store.'
        $script:NewFolder = [pscustomobject]@{ id = 'NEWID'; displayName = 'Projects'; parentFolderId = 'DEL'; totalItemCount = 12 }
        Mock New-GraphGetRequest $script:GraphMock
        Mock New-GraphBulkRequest { throw 'Bulk must not be called' }
        Mock New-GraphPOSTRequest {
            $script:PostCalls++
            $script:PostUris += $uri
            $script:Moved = $true
            return [pscustomobject]@{ id = 'NEWID'; parentFolderId = 'DEL'; displayName = 'Projects' }
        }
    }

    It 'makes zero Graph write calls in preview and returns DryRun with Before and PlannedMove' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; throw 'write should not run in preview' }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $true
        $Result.Status | Should -Be 'DryRun'
        $script:PostCalls | Should -Be 0
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
        Should -Invoke New-GraphBulkRequest -Times 0 -Exactly
        $Result.Before.id | Should -Be 'PROJ'
        $Result.Before.path | Should -Be '\Inbox\Projects'
        $Result.Before.itemCount | Should -Be 12
        $Result.PlannedMove.destinationId | Should -Be 'deleteditems'
        $Result.PlannedMove.folderId | Should -Be 'PROJ'
        $Result.PSObject.Properties.Name | Should -Not -Contain 'deletedFolderId'
    }

    It 'defaults to preview when -Preview is omitted' {
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed
        $Result.Status | Should -Be 'DryRun'
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses guarded folders with Failed/400 and never POSTs, even on a real run' {
        $Parsed = [pscustomobject]@{ UserId = 'user@contoso.com'; FolderId = 'INBOX'; FolderPath = $null; FolderType = 'mail' }
        foreach ($P in $true, $false) {
            $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $Parsed -Preview $P
            $Result.Status | Should -Be 'Failed'
            $Result.StatusCode | Should -Be 400
            $Result.Reason | Should -Match 'well-known|default'
        }
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'returns Success with deletedFolderId and originalParentId when verification matches' {
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Success'
        $Result.deletedFolderId | Should -Be 'NEWID'
        $Result.originalParentId | Should -Be 'INBOX'
        $Result.After.parentId | Should -Be 'DEL'
        $Result.After.itemCount | Should -Be 12
        $Result.Before.id | Should -Be 'PROJ'
    }

    It 'POSTs exactly one move to deleteditems with -AsApp $true and the POST verb' {
        Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false | Out-Null
        Should -Invoke New-GraphPOSTRequest -Times 1 -Exactly -ParameterFilter {
            $uri -eq 'https://graph.microsoft.com/v1.0/users/user%40contoso.com/mailFolders/PROJ/move' -and
            $AsApp -eq $true -and $type -eq 'POST' -and $tenantid -eq 'contoso.com' -and
            (($body | ConvertFrom-Json).destinationId -eq 'deleteditems')
        }
        Should -Invoke New-GraphPOSTRequest -ParameterFilter { $type -eq 'DELETE' } -Times 0 -Exactly
    }

    It 'fails loudly when after-state item count mismatches' {
        $script:NewFolder = [pscustomobject]@{ id = 'NEWID'; displayName = 'Projects'; parentFolderId = 'DEL'; totalItemCount = 3 }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        $Result.Status | Should -Not -Be 'Success'
        ($Result.Results -join ' ') | Should -Match 'item count'
    }

    It 'fails when the moved folder is not under Deleted Items' {
        $script:NewFolder = [pscustomobject]@{ id = 'NEWID'; displayName = 'Projects'; parentFolderId = 'SOMEWHERE'; totalItemCount = 12 }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        ($Result.Results -join ' ') | Should -Match 'Deleted Items'
    }

    It 'fails when the old folder id still exists under its original parent after the move' {
        Mock New-GraphGetRequest {
            if ($uri -match '/mailFolders/PROJ\?') { return $script:Tree['PROJ'] }
            & $script:GraphMock $uri $tenantid $AsApp
        }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        ($Result.Results -join ' ') | Should -Match 'still exists'
        $Result.deletedFolderId | Should -Be 'NEWID'
        $Result.originalParentId | Should -Be 'INBOX'
    }

    It 'succeeds when the move preserves the folder id (old id resolves to the same folder under Deleted Items)' {
        Mock New-GraphPOSTRequest {
            $script:PostCalls++
            $script:Moved = $true
            return [pscustomobject]@{ id = 'PROJ'; parentFolderId = 'DEL'; displayName = 'Projects' }
        }
        Mock New-GraphGetRequest {
            if ($uri -match '/mailFolders/PROJ\?' -and $script:Moved) {
                return [pscustomobject]@{ id = 'PROJ'; displayName = 'Projects'; parentFolderId = 'DEL'; totalItemCount = 12 }
            }
            & $script:GraphMock $uri $tenantid $AsApp
        }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Success'
        $Result.deletedFolderId | Should -Be 'PROJ'
        $Result.originalParentId | Should -Be 'INBOX'
    }

    It 'succeeds when the old id still resolves but is now under Deleted Items (different new id)' {
        Mock New-GraphGetRequest {
            if ($uri -match '/mailFolders/PROJ\?' -and $script:Moved) {
                return [pscustomobject]@{ id = 'PROJ'; parentFolderId = 'DEL' }
            }
            & $script:GraphMock $uri $tenantid $AsApp
        }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Success'
    }

    It 'includes deletedFolderId and originalParentId on every Failed outcome after a successful POST' {
        # parent mismatch
        $script:NewFolder = [pscustomobject]@{ id = 'NEWID'; displayName = 'Projects'; parentFolderId = 'SOMEWHERE'; totalItemCount = 12 }
        $R1 = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        # count mismatch
        $script:Moved = $false
        $script:NewFolder = [pscustomobject]@{ id = 'NEWID'; displayName = 'Projects'; parentFolderId = 'DEL'; totalItemCount = 3 }
        $R2 = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        # new-id read throws
        $script:Moved = $false
        $script:NewFolder = $null
        $R3 = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        foreach ($R in $R1, $R2, $R3) {
            $R.Status | Should -Be 'Failed'
            $R.deletedFolderId | Should -Be 'NEWID'
            $R.originalParentId | Should -Be 'INBOX'
        }
    }

    It 'includes originalParentId (null deletedFolderId) when the move response has no id' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; return $null }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        $Result.PSObject.Properties.Name | Should -Contain 'deletedFolderId'
        $Result.deletedFolderId | Should -BeNullOrEmpty
        $Result.originalParentId | Should -Be 'INBOX'
    }

    It 'omits recovery ids when the move POST itself failed' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; throw 'Graph 403 forbidden' }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.PSObject.Properties.Name | Should -Not -Contain 'deletedFolderId'
    }

    It 'refuses a search folder (odata type) with Failed/400 and never POSTs' {
        $script:Tree['SRCH'] = [pscustomobject]@{ id = 'SRCH'; displayName = 'Saved'; parentFolderId = 'ROOT'; wellKnownName = $null; totalItemCount = 1 }
        $script:Tree['SRCH'] | Add-Member -NotePropertyName '@odata.type' -NotePropertyValue '#microsoft.graph.mailSearchFolder'
        $Parsed = [pscustomobject]@{ UserId = 'user@contoso.com'; FolderId = 'SRCH'; FolderPath = $null; FolderType = 'mail' }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $Parsed -Preview $false
        $script:Tree.Remove('SRCH')
        $Result.Status | Should -Be 'Failed'
        $Result.StatusCode | Should -Be 400
        $Result.Reason | Should -Match 'search'
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'fails (not Success) when the old-id lookup errors with something other than not-found' {
        $script:OldIdError = '429 Too Many Requests'
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
    }

    It 'returns Failed when the move POST throws' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; throw 'Graph 403 forbidden' }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        ($Result.Results -join ' ') | Should -Match 'forbidden'
    }

    It 'returns Failed when the move response has no new folder id' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; return $null }
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
    }

    It 'contains no DELETE verb in the implementation' {
        $Src = Get-Content -Raw (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Invoke-CIPPMailboxFolderSoftDelete.ps1')
        ($Src -cmatch '\bDELETE\b') | Should -BeFalse
        ($Src -match "(?i)type\s*=\s*['""]DELETE['""]") | Should -BeFalse
    }
}

Describe 'Test-CIPPMailboxFolderRestoreRequest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderRestoreRequest.ps1')
        $script:NewBody = {
            @{
                tenantFilter = 't'; userId = 'u@t.com'; deletedFolderId = 'DELF'; originalParentId = 'PARENT'
                folderType = 'mail'; TicketNumber = '3281353'; Reason = 'restore please'
            }
        }
    }

    It 'defaults preview to true and forces dryRun on the body' {
        $Req = @{ Body = (& $script:NewBody); Headers = @{} }
        $Parsed = Test-CIPPMailboxFolderRestoreRequest -Request $Req
        $Parsed.Ok | Should -BeTrue
        $Parsed.Preview | Should -BeTrue
        $Parsed.DeletedFolderId | Should -Be 'DELF'
        $Parsed.OriginalParentId | Should -Be 'PARENT'
        [string]$Req.Body.dryRun | Should -Be 'True'
    }

    It 'honours preview=false' {
        $Body = & $script:NewBody
        $Body.preview = $false
        $Parsed = Test-CIPPMailboxFolderRestoreRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeTrue
        $Parsed.Preview | Should -BeFalse
    }

    It 'rejects missing Reason' {
        $Body = & $script:NewBody
        $Body.Remove('Reason')
        $Parsed = Test-CIPPMailboxFolderRestoreRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.StatusCode | Should -Be 400
        $Parsed.Message | Should -Match 'Reason'
    }

    It 'rejects missing <Field>' -ForEach @(
        @{ Field = 'deletedFolderId' }, @{ Field = 'originalParentId' }, @{ Field = 'userId' }
    ) {
        $Body = & $script:NewBody
        $Body.Remove($Field)
        $Parsed = Test-CIPPMailboxFolderRestoreRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.Message | Should -Match $Field
    }

    It 'rejects invalid folderType' {
        $Body = & $script:NewBody
        $Body.folderType = 'notes'
        $Parsed = Test-CIPPMailboxFolderRestoreRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.Message | Should -Match 'folderType'
    }

    It 'rejects non-boolean preview' {
        $Body = & $script:NewBody
        $Body.preview = 'maybe'
        (Test-CIPPMailboxFolderRestoreRequest -Request @{ Body = $Body; Headers = @{} }).Ok | Should -BeFalse
    }

    It 'returns 400 when preview and dryRun conflict' {
        foreach ($Pair in @(@('true', 'false'), @('false', 'true'))) {
            $Body = & $script:NewBody
            $Body.preview = $Pair[0]; $Body.dryRun = $Pair[1]
            $Parsed = Test-CIPPMailboxFolderRestoreRequest -Request @{ Body = $Body; Headers = @{} }
            $Parsed.Ok | Should -BeFalse
            $Parsed.StatusCode | Should -Be 400
            $Parsed.Message | Should -Match 'conflict'
        }
    }

    It 'returns 400 when preview and WhatIf conflict' {
        $Body = & $script:NewBody
        $Body.preview = 'true'; $Body.WhatIf = 'false'
        (Test-CIPPMailboxFolderRestoreRequest -Request @{ Body = $Body; Headers = @{} }).StatusCode | Should -Be 400
    }

    It 'treats either flag true as preview (other absent or also true)' {
        foreach ($Case in @(@{ preview = 'true' }, @{ dryRun = 'true' }, @{ WhatIf = 'true' }, @{ preview = 'true'; dryRun = 'true' })) {
            $Body = & $script:NewBody
            foreach ($K in $Case.Keys) { $Body[$K] = $Case[$K] }
            $Req = @{ Body = $Body; Headers = @{} }
            $Parsed = Test-CIPPMailboxFolderRestoreRequest -Request $Req
            $Parsed.Ok | Should -BeTrue
            $Parsed.Preview | Should -BeTrue
            $Req.Body.dryRun | Should -BeTrue
        }
    }

    It 'allows a real run only when every supplied flag is false' {
        $Body = & $script:NewBody
        $Body.preview = 'false'; $Body.dryRun = 'false'
        $Parsed = Test-CIPPMailboxFolderRestoreRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeTrue
        $Parsed.Preview | Should -BeFalse
    }
}

Describe 'Invoke-CIPPMailboxFolderRestore' {
    BeforeAll {
        foreach ($F in 'Get-CIPPMailboxFolderWellKnownNames', 'Resolve-CIPPMailboxFolder', 'Get-CIPPMailboxFolderBeforeState', 'Invoke-CIPPMailboxFolderRestore') {
            . (Join-Path $PSScriptRoot "../../Modules/CIPPCore/Public/MailboxFolder/$F.ps1")
        }

        function New-GraphGetRequest { param($uri, $tenantid, $AsApp, $noPagination, $NoAuthCheck, [switch]$ComplexFilter) }
        function New-GraphPOSTRequest { param($uri, $tenantid, $body, $type, $AsApp) }
        function New-GraphBulkRequest { param($tenantid, $Requests, $AsApp) }

        $script:Tree = @{
            'ROOT'  = [pscustomobject]@{ id = 'ROOT'; displayName = 'Top of Information Store'; parentFolderId = $null; wellKnownName = 'msgfolderroot' }
            'INBOX' = [pscustomobject]@{ id = 'INBOX'; displayName = 'Inbox'; parentFolderId = 'ROOT'; wellKnownName = 'inbox'; totalItemCount = 5 }
            'DEL'   = [pscustomobject]@{ id = 'DEL'; displayName = 'Deleted Items'; parentFolderId = 'ROOT'; wellKnownName = 'deleteditems' }
            'DELF'  = [pscustomobject]@{ id = 'DELF'; displayName = 'Projects'; parentFolderId = 'DEL'; wellKnownName = $null; totalItemCount = 12; unreadItemCount = 2; childFolderCount = 0; sizeInBytes = 4096 }
            'LIVE'  = [pscustomobject]@{ id = 'LIVE'; displayName = 'Live'; parentFolderId = 'INBOX'; wellKnownName = $null; totalItemCount = 1 }
            'DELPAR' = [pscustomobject]@{ id = 'DELPAR'; displayName = 'DeletedParent'; parentFolderId = 'DEL'; wellKnownName = $null; totalItemCount = 0 }
        }

        $script:GraphMock = {
            param($uri, $tenantid, $AsApp)
            $Path = ($uri -split '\?')[0]
            $Prefix = 'https://graph.microsoft.com/v1.0/users/user%40contoso.com/'
            if (-not $Path.StartsWith($Prefix)) { throw "Unexpected URI $uri" }
            $Rel = $Path.Substring($Prefix.Length)
            switch -Regex ($Rel) {
                '^mailFolders/deleteditems$' { return $script:Tree['DEL'] }
                '^mailFolders/msgfolderroot$' { return $script:Tree['ROOT'] }
                '^mailFolders/([^/]+)/messages$' { return @([pscustomobject]@{ receivedDateTime = '2020-01-01T00:00:00Z' }) }
                '^mailFolders/([^/]+)$' {
                    $Id = [uri]::UnescapeDataString($Matches[1])
                    if ($null -ne $script:NewFolder -and $Id -eq $script:NewFolder.id -and $script:Moved) { return $script:NewFolder }
                    if ($script:Tree.ContainsKey($Id)) { return $script:Tree[$Id] }
                    throw "404 $Id"
                }
                default { throw "Unmocked path $Rel" }
            }
        }
        $script:Parsed = [pscustomobject]@{ UserId = 'user@contoso.com'; DeletedFolderId = 'DELF'; OriginalParentId = 'INBOX'; FolderType = 'mail' }
    }

    BeforeEach {
        $script:Moved = $false
        $script:PostCalls = 0
        $script:NewFolder = [pscustomobject]@{ id = 'RESTORED'; displayName = 'Projects'; parentFolderId = 'INBOX'; totalItemCount = 12 }
        Mock New-GraphGetRequest $script:GraphMock
        Mock New-GraphBulkRequest { throw 'Bulk must not be called' }
        Mock New-GraphPOSTRequest {
            $script:PostCalls++
            $script:Moved = $true
            return [pscustomobject]@{ id = 'RESTORED'; parentFolderId = 'INBOX'; displayName = 'Projects' }
        }
    }

    It 'makes zero Graph write calls in preview and plans a move to the original parent' {
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $true
        $Result.Status | Should -Be 'DryRun'
        $script:PostCalls | Should -Be 0
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
        Should -Invoke New-GraphBulkRequest -Times 0 -Exactly
        $Result.PlannedMove.destinationId | Should -Be 'INBOX'
        $Result.PlannedMove.folderId | Should -Be 'DELF'
        $Result.Before.itemCount | Should -Be 12
        $Result.PSObject.Properties.Name | Should -Not -Contain 'restoredFolderId'
    }

    It 'defaults to preview when -Preview is omitted' {
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed
        $Result.Status | Should -Be 'DryRun'
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'returns Success with restoredFolderId when verification matches' {
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Success'
        $Result.restoredFolderId | Should -Be 'RESTORED'
        $Result.originalParentId | Should -Be 'INBOX'
        $Result.After.parentId | Should -Be 'INBOX'
        $Result.After.itemCount | Should -Be 12
    }

    It 'POSTs exactly one move with destinationId = originalParentId, -AsApp $true, POST verb' {
        Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false | Out-Null
        Should -Invoke New-GraphPOSTRequest -Times 1 -Exactly -ParameterFilter {
            $uri -eq 'https://graph.microsoft.com/v1.0/users/user%40contoso.com/mailFolders/DELF/move' -and
            $AsApp -eq $true -and $type -eq 'POST' -and $tenantid -eq 'contoso.com' -and
            (($body | ConvertFrom-Json).destinationId -eq 'INBOX')
        }
        Should -Invoke New-GraphPOSTRequest -ParameterFilter { $type -eq 'DELETE' } -Times 0 -Exactly
    }

    It 'refuses a folder that is not under Deleted Items, in preview and real runs, with no POST' {
        $Parsed = [pscustomobject]@{ UserId = 'user@contoso.com'; DeletedFolderId = 'LIVE'; OriginalParentId = 'INBOX'; FolderType = 'mail' }
        foreach ($P in $true, $false) {
            $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $Parsed -Preview $P
            $Result.Status | Should -Be 'Failed'
            $Result.StatusCode | Should -Be 400
            $Result.Reason | Should -Match 'Deleted Items'
        }
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses originalParentId equal to Deleted Items' {
        $Parsed = [pscustomobject]@{ UserId = 'user@contoso.com'; DeletedFolderId = 'DELF'; OriginalParentId = 'DEL'; FolderType = 'mail' }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        $Result.StatusCode | Should -Be 400
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses when the original parent no longer exists' {
        $Parsed = [pscustomobject]@{ UserId = 'user@contoso.com'; DeletedFolderId = 'DELF'; OriginalParentId = 'GONE'; FolderType = 'mail' }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        $Result.StatusCode | Should -Be 400
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses when the original parent is itself under Deleted Items' {
        $Parsed = [pscustomobject]@{ UserId = 'user@contoso.com'; DeletedFolderId = 'DELF'; OriginalParentId = 'DELPAR'; FolderType = 'mail' }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        $Result.StatusCode | Should -Be 400
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'fails loudly when after-state item count mismatches' {
        $script:NewFolder = [pscustomobject]@{ id = 'RESTORED'; displayName = 'Projects'; parentFolderId = 'INBOX'; totalItemCount = 3 }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        ($Result.Results -join ' ') | Should -Match 'item count'
    }

    It 'includes restoredFolderId and originalParentId on Failed outcomes after a successful POST' {
        $script:NewFolder = [pscustomobject]@{ id = 'RESTORED'; displayName = 'Projects'; parentFolderId = 'DEL'; totalItemCount = 12 }
        $R1 = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $script:Moved = $false
        $script:NewFolder = [pscustomobject]@{ id = 'RESTORED'; displayName = 'Projects'; parentFolderId = 'INBOX'; totalItemCount = 3 }
        $R2 = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        foreach ($R in $R1, $R2) {
            $R.Status | Should -Be 'Failed'
            $R.restoredFolderId | Should -Be 'RESTORED'
            $R.originalParentId | Should -Be 'INBOX'
        }
    }

    It 'includes originalParentId when the restore move response has no id' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; return $null }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        $Result.originalParentId | Should -Be 'INBOX'
        $Result.restoredFolderId | Should -BeNullOrEmpty
    }

    It 'omits recovery ids when the restore POST itself failed' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; throw 'Graph 403 forbidden' }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.PSObject.Properties.Name | Should -Not -Contain 'restoredFolderId'
    }

    It 'fails when the restored folder is not under the original parent' {
        $script:NewFolder = [pscustomobject]@{ id = 'RESTORED'; displayName = 'Projects'; parentFolderId = 'DEL'; totalItemCount = 12 }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        ($Result.Results -join ' ') | Should -Match 'original parent'
    }

    It 'returns Failed when the move POST throws' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; throw 'Graph 403 forbidden' }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
        ($Result.Results -join ' ') | Should -Match 'forbidden'
    }

    It 'returns Failed when the move response has no folder id' {
        Mock New-GraphPOSTRequest { $script:PostCalls++; return $null }
        $Result = Invoke-CIPPMailboxFolderRestore -TenantFilter 'contoso.com' -UserId 'user@contoso.com' -Parsed $script:Parsed -Preview $false
        $Result.Status | Should -Be 'Failed'
    }

    It 'contains no DELETE verb in the implementation' {
        $Src = Get-Content -Raw (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Invoke-CIPPMailboxFolderRestore.ps1')
        ($Src -cmatch '\bDELETE\b') | Should -BeFalse
        ($Src -match "(?i)type\s*=\s*['""]DELETE['""]") | Should -BeFalse
    }
}
