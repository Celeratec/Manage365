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