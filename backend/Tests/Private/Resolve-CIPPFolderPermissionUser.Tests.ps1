# Pester tests for Resolve-CIPPFolderPermissionUser (User + Permissions parameter sets).

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Get-ChildItem -Path (Join-Path $RepoRoot 'Modules') -Recurse -Filter 'Resolve-CIPPFolderPermissionUser.ps1' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $FunctionPath) { throw 'Could not locate Resolve-CIPPFolderPermissionUser.ps1 under Modules/' }

    function New-ExoRequest { param($tenantid, $cmdlet, $cmdParams, $Select, $useSystemMailbox, $Anchor) }
    function New-ExoBulkRequest { param($tenantid, $cmdletArray, $useSystemMailbox, $Select) }

    . $FunctionPath
}

Describe 'Resolve-CIPPFolderPermissionUser (-User)' {
    It 'accepts -User without binding errors and returns candidates for an SMTP address' {
        Mock -CommandName New-ExoRequest -MockWith {
            param($tenantid, $cmdlet, $cmdParams)
            if ($cmdlet -eq 'Get-Recipient' -and $cmdParams.Identity) {
                return [pscustomobject]@{
                    PrimarySmtpAddress         = 'grantee@contoso.com'
                    Guid                       = '11111111-1111-1111-1111-111111111111'
                    DisplayName                = 'Grantee User'
                    ExternalDirectoryObjectId  = '22222222-2222-2222-2222-222222222222'
                }
            }
        }

        $Result = Resolve-CIPPFolderPermissionUser -TenantFilter 'contoso.com' -User 'grantee@contoso.com'

        $Result.UserEmail | Should -Be 'grantee@contoso.com'
        $Result.UserId | Should -Be '11111111-1111-1111-1111-111111111111'
        $Result.UserAmbiguous | Should -BeFalse
        @($Result.Candidates) | Should -Contain 'grantee@contoso.com'
        @($Result.Candidates) | Should -Contain '11111111-1111-1111-1111-111111111111'
    }

    It 'returns system mailbox ACE keys unchanged' {
        $Result = Resolve-CIPPFolderPermissionUser -TenantFilter 'contoso.com' -User 'Default'
        $Result.User | Should -Be 'Default'
        @($Result.Candidates) | Should -Be @('Default')
        $Result.UserAmbiguous | Should -BeFalse
    }
}

Describe 'Resolve-CIPPFolderPermissionUser (-Permissions)' {
    It 'adds UserId when display name resolves to one recipient' {
        Mock -CommandName New-ExoBulkRequest -MockWith {
            param($tenantid, $cmdletArray)
            return @(
                [pscustomobject]@{
                    OperationGuid       = 'Grantee User'
                    PrimarySmtpAddress  = 'grantee@contoso.com'
                    Guid                = '11111111-1111-1111-1111-111111111111'
                }
            )
        }

        $Rows = @(
            [pscustomobject]@{ User = 'Grantee User'; AccessRights = @('Reviewer'); Identity = 'mbx:\Calendar' }
        )
        $Out = @(Resolve-CIPPFolderPermissionUser -TenantFilter 'contoso.com' -FolderIdentity 'mbx@contoso.com:\Calendar' -Permissions $Rows)

        $Out.Count | Should -Be 1
        $Out[0].UserId | Should -Be '11111111-1111-1111-1111-111111111111'
    }

    It 'does not call Get-MailboxFolderPermission with a User parameter' {
        Mock -CommandName New-ExoBulkRequest -MockWith {
            param($tenantid, $cmdletArray)
            foreach ($Req in @($cmdletArray)) {
                $Params = $Req.CmdletInput.Parameters
                if ($Params.User) {
                    throw 'Get-MailboxFolderPermission must not receive User'
                }
            }
            return @()
        }

        $Rows = @([pscustomobject]@{ User = 'Default'; AccessRights = @('AvailabilityOnly'); Identity = 'x:\Calendar' })
        { Resolve-CIPPFolderPermissionUser -TenantFilter 'contoso.com' -FolderIdentity 'mbx:\Calendar' -Permissions $Rows } | Should -Not -Throw
    }
}
