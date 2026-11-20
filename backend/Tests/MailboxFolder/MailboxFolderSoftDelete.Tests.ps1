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
}
