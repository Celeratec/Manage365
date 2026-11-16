BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $Guarded = Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite'
    foreach ($Name in @('Test-CIPPGuardedWriteRequest', 'Get-CIPPGraphWritePlan', 'Get-CIPPExoAllowlistedCmdletPlan', 'Test-CIPPTeamsAppPackage', 'ConvertTo-CIPPGuardedWriteRedacted', 'Protect-CIPPAuthMethod', 'Merge-CIPPCAPolicyUpdate', 'Test-CIPPCAPolicyRemoval')) {
        $Path = Join-Path $Guarded "$Name.ps1"
        if (-not (Test-Path $Path)) {
            $Path = Join-Path $RepoRoot "Modules/CIPPCore/Public/ConditionalAccess/$Name.ps1"
        }
        . $Path
    }
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Private/Resolve-CIPPGuardedWriteConfigPath.ps1')
    $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new()
}

Describe 'Guarded write envelope' {
    BeforeEach { $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new() }

    It 'rejects a missing or short ticket before any other work' {
        $Request = @{ Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; TicketNumber = '12' }; Headers = @{} }
        $Result = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
        $Result.Ok | Should -BeFalse
        $Result.StatusCode | Should -Be 400
    }

    It 'accepts a 6 to 8 digit ticket and treats the string false as WhatIf off' {
        $Request = @{ Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; TicketNumber = '327521'; WhatIf = 'false' }; Headers = @{ 'x-ms-client-principal-name' = 'tech@msp.com' } }
        $Result = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
        $Result.Ok | Should -BeTrue
        $Result.WhatIf | Should -BeFalse
        $Result.Caller | Should -Be 'tech@msp.com'
    }

    It 'accepts ticketNumber and dryRun, and rejects a missing ticket' {
        $Missing = Test-CIPPGuardedWriteRequest -Request @{ Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; dryRun = $true }; Headers = @{} } -IsWrite
        $Missing.Ok | Should -BeFalse
        $Missing.StatusCode | Should -Be 400
        $Missing.Message | Should -Match 'ticketNumber'

        $BlankTenant = Test-CIPPGuardedWriteRequest -Request @{ Body = @{ tenantFilter = ' '; ticketNumber = '3275215' }; Headers = @{} } -IsWrite
        $BlankTenant.StatusCode | Should -Be 400
        $BlankTenant.Message | Should -Match 'tenantFilter'

        $Dry = Test-CIPPGuardedWriteRequest -Request @{ Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '3275215'; dryRun = $true; reason = 'ticket 3275215' }; Headers = @{} } -IsWrite
        $Dry.Ok | Should -BeTrue
        $Dry.DryRun | Should -BeTrue
        $Dry.WhatIf | Should -BeTrue
        $Dry.Ticket | Should -Be '3275215'
        $Dry.Reason | Should -Be 'ticket 3275215'
    }

    It 'returns 429 after 10 writes for the same tenant in a minute' {
        $Request = @{ Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; TicketNumber = '327521' }; Headers = @{} }
        foreach ($Index in 1..10) { (Test-CIPPGuardedWriteRequest -Request $Request -IsWrite).Ok | Should -BeTrue }
        $Limited = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
        $Limited.Ok | Should -BeFalse
        $Limited.StatusCode | Should -Be 429
        $Limited.RetryAfter | Should -Be 60
    }
}

Describe 'ExecGraphWrite allowlist' {
    It 'rejects a path that is not on the allowlist' {
        $Plan = Get-CIPPGraphWritePlan -Method POST -Path 'users/1' -ApiVersion v1.0 -Body @{}
        $Plan.Allowed | Should -BeFalse
        $Plan.Reason | Should -Match 'not on the allowlist'
    }

    It 'defaults oauth grants to Principal and refuses AllPrincipals without the elevated role' {
        $Default = Get-CIPPGraphWritePlan -Method POST -Path 'oauth2PermissionGrants' -ApiVersion v1.0 -Body @{}
        $Default.Allowed | Should -BeTrue
        $Default.Body.consentType | Should -Be 'Principal'

        $Elevated = Get-CIPPGraphWritePlan -Method POST -Path 'oauth2PermissionGrants' -ApiVersion v1.0 -Body @{ consentType = 'AllPrincipals' }
        $Elevated.Allowed | Should -BeFalse
        $Elevated.Reason | Should -Match 'Principal'

        $AppId = '11111111-1111-1111-1111-111111111111'
        (Get-CIPPGraphWritePlan -Method DELETE -Path "servicePrincipals/$AppId/appRoleAssignments/$AppId" -ApiVersion v1.0 -Body $null).Allowed | Should -BeTrue
        (Get-CIPPGraphWritePlan -Method DELETE -Path "servicePrincipals/$AppId/appRoleAssignedTo/$AppId" -ApiVersion beta -Body $null).Allowed | Should -BeTrue
        (Get-CIPPGraphWritePlan -Method POST -Path 'chats/19:meeting/installedApps' -ApiVersion v1.0 -Body @{}).Allowed | Should -BeTrue
        (Get-CIPPGraphWritePlan -Method DELETE -Path "chats/19:meeting/installedApps/$AppId" -ApiVersion v1.0 -Body $null).Allowed | Should -BeTrue
        (Get-CIPPGraphWritePlan -Method DELETE -Path "appCatalogs/teamsApps/$AppId" -ApiVersion beta -Body $null).Allowed | Should -BeTrue
        (Get-CIPPGraphWritePlan -Method DELETE -Path "applications/$AppId" -ApiVersion v1.0 -Body $null).Allowed | Should -BeTrue
        (Get-CIPPGraphWritePlan -Method DELETE -Path "servicePrincipals/$AppId" -ApiVersion v1.0 -Body $null).Allowed | Should -BeTrue
        (Get-CIPPGraphWritePlan -Method DELETE -Path 'applications' -ApiVersion v1.0 -Body $null).Allowed | Should -BeFalse
    }
}

Describe 'ExecExoAllowlistedCmdlet allowlist' {
    It 'rejects Remove-Mailbox and an unknown parameter' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Remove-Mailbox' -Parameters @{ Identity = 'a' }).Allowed | Should -BeFalse
        $Unknown = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-Mailbox' -Parameters @{ Identity = 'a'; ForwardingSmtpAddress = 'x' }
        $Unknown.Allowed | Should -BeFalse
        $Unknown.Reason | Should -Match 'not allowed'
    }

    It 'rejects TrustedSendersToAdd on junk configuration' {
        $Plan = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-MailboxJunkEmailConfiguration' -Parameters @{
            Identity            = 'user@contoso.com'
            TrustedSendersToAdd = @('sender@example.com')
        }
        $Plan.Allowed | Should -BeFalse
        $Plan.Reason | Should -Match 'TrustedSendersToAdd'
    }

    It 'accepts a junk list and an Application role assignment' {
        $Junk = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-MailboxJunkEmailConfiguration' -Parameters @{
            Identity                 = 'user@contoso.com'
            TrustedSendersAndDomains = @{ Add = @('sender@example.com'); Remove = @() }
        }
        $Junk.Allowed | Should -BeTrue
        $Role = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'New-ManagementRoleAssignment' -Parameters @{ App = 'app'; Role = 'Application Mail.Read' }
        $Role.Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'New-ManagementRoleAssignment' -Parameters @{ App = 'app'; Role = 'Application Calendars.Read' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'New-ManagementRoleAssignment' -Parameters @{ App = 'app'; Role = 'Application Mail.ReadBasic' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'New-ManagementRoleAssignment' -Parameters @{ App = 'app'; Role = 'Application Mail.ReadWrite' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'New-ManagementRoleAssignment' -Parameters @{ App = 'app'; Role = 'Organization Management' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Remove-ServicePrincipal' -Parameters @{ Identity = 'sp' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Remove-ManagementScope' -Parameters @{ Identity = 'scope' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Remove-ManagementScope' -Parameters @{ Identity = 'scope'; Name = 'extra' }).Allowed | Should -BeFalse
    }

    It 'accepts Set-AcceptedDomain with valid Identity and DomainType' {
        $Valid = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com'; DomainType = 'Authoritative' }
        $Valid.Allowed | Should -BeTrue
        $Valid.Parameters.Identity | Should -Be 'contoso.com'
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'example.com'; DomainType = 'InternalRelay' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'example.com'; DomainType = 'ExternalRelay' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'sub.domain.example.org'; DomainType = 'Authoritative' }).Parameters.Identity | Should -Be 'sub.domain.example.org'
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = '  sub.domain.example.org  '; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
    }

    It 'rejects Set-AcceptedDomain with missing required parameters' {
        $NoIdentity = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ DomainType = 'Authoritative' }
        $NoIdentity.Allowed | Should -BeFalse
        $NoIdentity.Reason | Should -Match 'requires Identity'
        $NoDomainType = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com' }
        $NoDomainType.Allowed | Should -BeFalse
        $NoDomainType.Reason | Should -Match 'requires DomainType'
    }

    It 'rejects Set-AcceptedDomain with extra parameters or invalid DomainType' {
        $Extra = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com'; DomainType = 'Authoritative'; DomainName = 'extra' }
        $Extra.Allowed | Should -BeFalse
        $Extra.Reason | Should -Match 'not allowed'
        $InvalidType = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com'; DomainType = 'InvalidType' }
        $InvalidType.Allowed | Should -BeFalse
        $InvalidType.Reason | Should -Match 'Authoritative, InternalRelay, or ExternalRelay'
    }

    It 'rejects Set-AcceptedDomain Identity with invalid characters or format' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = ''; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = '   '; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = "contoso.com`n"; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = "contoso.com`r"; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = "contoso.com`0"; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = '*.contoso.com'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = '%var%.contoso.com'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso com'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = ('a' * 254); DomainType = 'Authoritative' }).Allowed | Should -BeFalse
    }

    It 'rejects Set-AcceptedDomain Identity with injection characters' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com;whoami'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com|whoami'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com`whoami'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com$(whoami)'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = "contoso.com`nwhoami"; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = "contoso.com`0"; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = "contoso.com$([char]0x2028)"; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = "contoso.com$([char]0x2029)"; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
    }

    It 'rejects Set-AcceptedDomain with common parameter names and abbreviations' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com'; DomainType = 'Authoritative'; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com'; DomainType = 'Authoritative'; WhatIf = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com'; DomainType = 'Authoritative'; ErrorAction = 'Stop' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com'; DomainType = 'Authoritative'; Ident = 'contoso.com' }).Allowed | Should -BeFalse
    }

    It 'rejects Set-AcceptedDomain with array or hashtable parameters' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = @('contoso.com'); DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = 'contoso.com'; DomainType = @('Authoritative') }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ Identity = @{ Name = 'contoso.com' }; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
    }

    It 'accepts Set-DkimSigningConfig with valid Identity and Enabled' {
        $Valid = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = $true }
        $Valid.Allowed | Should -BeTrue
        $Valid.Parameters.Enabled | Should -Be $true
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'example.com'; Enabled = $false }).Parameters.Enabled | Should -Be $false
    }

    It 'coerces Set-DkimSigningConfig Enabled to boolean' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = 'true' }).Parameters.Enabled | Should -Be $true
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = 'True' }).Parameters.Enabled | Should -Be $true
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = '1' }).Parameters.Enabled | Should -Be $true
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = 1 }).Parameters.Enabled | Should -Be $true
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = 'false' }).Parameters.Enabled | Should -Be $false
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = 'False' }).Parameters.Enabled | Should -Be $false
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = '0' }).Parameters.Enabled | Should -Be $false
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = 0 }).Parameters.Enabled | Should -Be $false
    }

    It 'rejects Set-DkimSigningConfig with missing required parameters' {
        $NoIdentity = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Enabled = $true }
        $NoIdentity.Allowed | Should -BeFalse
        $NoIdentity.Reason | Should -Match 'requires Identity'
        $NoEnabled = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com' }
        $NoEnabled.Allowed | Should -BeFalse
        $NoEnabled.Reason | Should -Match 'requires Enabled'
    }

    It 'rejects Set-DkimSigningConfig with extra parameters or invalid Enabled' {
        $Extra = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = $true; KeySize = 2048 }
        $Extra.Allowed | Should -BeFalse
        $Extra.Reason | Should -Match 'not allowed'
        $ExtraForce = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = $true; Force = $true }
        $ExtraForce.Allowed | Should -BeFalse
        $ExtraForce.Reason | Should -Match 'not allowed'
        $InvalidEnabled = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = 'yes' }
        $InvalidEnabled.Allowed | Should -BeFalse
        $InvalidEnabled.Reason | Should -Match 'boolean'
    }

    It 'rejects Set-DkimSigningConfig Identity with invalid characters or format' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = ''; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = '   '; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = "contoso.com`n"; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = '*.contoso.com'; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = '%var%.contoso.com'; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso com'; Enabled = $true }).Allowed | Should -BeFalse
    }

    It 'rejects Set-DkimSigningConfig Identity with injection characters' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com;whoami'; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com|whoami'; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com`whoami'; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com$(whoami)'; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = "contoso.com$([char]0x2028)"; Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = "contoso.com$([char]0x2029)"; Enabled = $true }).Allowed | Should -BeFalse
    }

    It 'rejects Set-DkimSigningConfig with common parameter names and abbreviations' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = $true; WhatIf = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = $true; ErrorAction = 'Stop' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = $true; Ident = 'contoso.com' }).Allowed | Should -BeFalse
    }

    It 'rejects Set-DkimSigningConfig with array or hashtable parameters' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = @('contoso.com'); Enabled = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = 'contoso.com'; Enabled = @($true) }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ Identity = @{ Name = 'contoso.com' }; Enabled = $true }).Allowed | Should -BeFalse
    }

    It 'accepts case-insensitive parameter names for new cmdlets' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ identity = 'contoso.com'; domaintype = 'Authoritative' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-DkimSigningConfig' -Parameters @{ IDENTITY = 'contoso.com'; ENABLED = $true }).Allowed | Should -BeTrue
    }

    It 'accepts Disable-Mailbox with Archive true and Confirm false' {
        $Valid = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
        $Valid.Allowed | Should -BeTrue
        $Valid.Parameters.Archive | Should -Be $true
        $Valid.Parameters.Confirm | Should -Be $false
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = 'true'; Confirm = 'false' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = '1'; Confirm = '0' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = 1; Confirm = 0 }).Allowed | Should -BeTrue
    }

    It 'rejects Disable-Mailbox with missing required parameters' {
        $NoIdentity = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Archive = $true; Confirm = $false }
        $NoIdentity.Allowed | Should -BeFalse
        $NoIdentity.Reason | Should -Match 'requires Identity'
        $NoArchive = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Confirm = $false }
        $NoArchive.Allowed | Should -BeFalse
        $NoArchive.Reason | Should -Match 'requires Archive'
        $NoConfirm = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true }
        $NoConfirm.Allowed | Should -BeFalse
        $NoConfirm.Reason | Should -Match 'requires Confirm'
    }

    It 'rejects Disable-Mailbox with Archive false or Confirm true' {
        $ArchiveFalse = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $false; Confirm = $false }
        $ArchiveFalse.Allowed | Should -BeFalse
        $ArchiveFalse.Reason | Should -Match 'Archive must be true'
        $ArchiveFalseStr = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = 'false'; Confirm = $false }
        $ArchiveFalseStr.Allowed | Should -BeFalse
        $ArchiveFalseStr.Reason | Should -Match 'Archive must be true'
        $ConfirmTrue = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $true }
        $ConfirmTrue.Allowed | Should -BeFalse
        $ConfirmTrue.Reason | Should -Match 'Confirm must be false'
    }

    It 'rejects Disable-Mailbox with extra parameters' {
        $ExtraPermanently = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false; PermanentlyDisable = $true }
        $ExtraPermanently.Allowed | Should -BeFalse
        $ExtraPermanently.Reason | Should -Match 'not allowed'
        $ExtraIgnoreLegal = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false; IgnoreLegalHold = $true }
        $ExtraIgnoreLegal.Allowed | Should -BeFalse
        $ExtraIgnoreLegal.Reason | Should -Match 'not allowed'
        $ExtraRemoveLast = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false; RemoveLastArbitrationMailbox = $true }
        $ExtraRemoveLast.Allowed | Should -BeFalse
        $ExtraRemoveLast.Reason | Should -Match 'not allowed'
        $ExtraPublicFolder = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false; PublicFolder = $true }
        $ExtraPublicFolder.Allowed | Should -BeFalse
        $ExtraPublicFolder.Reason | Should -Match 'not allowed'
        $ExtraRemoteArchive = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false; RemoteArchive = $true }
        $ExtraRemoteArchive.Allowed | Should -BeFalse
        $ExtraRemoteArchive.Reason | Should -Match 'not allowed'
        $ExtraArbitration = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false; Arbitration = $true }
        $ExtraArbitration.Allowed | Should -BeFalse
        $ExtraArbitration.Reason | Should -Match 'not allowed'
    }

    It 'rejects Disable-Mailbox with invalid Archive or Confirm values' {
        $InvalidArchive = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = 'yes'; Confirm = $false }
        $InvalidArchive.Allowed | Should -BeFalse
        $InvalidArchive.Reason | Should -Match 'Archive must be a boolean'
        $InvalidConfirm = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = 'no' }
        $InvalidConfirm.Allowed | Should -BeFalse
        $InvalidConfirm.Reason | Should -Match 'Confirm must be a boolean'
    }

    It 'rejects Disable-Mailbox with array or hashtable parameters' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = @('user@contoso.com'); Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = @($true); Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = @($false) }).Allowed | Should -BeFalse
    }

    It 'accepts case-insensitive parameter names for Disable-Mailbox' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ identity = 'user@contoso.com'; archive = $true; confirm = $false }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ IDENTITY = 'user@contoso.com'; ARCHIVE = $true; CONFIRM = $false }).Allowed | Should -BeTrue
    }

    It 'rejects Disable-Mailbox Identity with invalid format' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = ''; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = '   '; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = $null; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = @('user@contoso.com'); Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = @{ Name = 'user' }; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = ('a' * 321); Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = ('a' * 10000); Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
    }

    It 'rejects Disable-Mailbox Identity with control characters or wildcards' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = "user@contoso.com`n"; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = "user@contoso.com`r"; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = "user@contoso.com`0"; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = '*@contoso.com'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'Discovery*'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = '%UserName%'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = '  user@contoso.com  '; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
    }

    It 'rejects Disable-Mailbox Identity that is not a UPN, SMTP or GUID' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'notanemail'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'bad@'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = '@bad.com'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'not-a-guid-12345'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = '..@example.com'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@localhost'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = "user`u{212A}@example.com"; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
    }

    It 'accepts valid UPN, SMTP and GUID formats for Disable-Mailbox Identity' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'SMTP:user@contoso.com'; Archive = $true; Confirm = $false }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'smtp:user@contoso.com'; Archive = $true; Confirm = $false }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ Identity = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'; Archive = $true; Confirm = $false }).Allowed | Should -BeTrue
    }

    It 'rejects parameter names with Unicode tricks' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ "Arch`u{200B}ive" = $true; Identity = 'user@contoso.com'; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ "Con`u{200D}firm" = $false; Identity = 'user@contoso.com'; Archive = $true }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Disable-Mailbox' -Parameters @{ "Identity`0" = 'user@contoso.com'; Archive = $true; Confirm = $false }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ 'Ｉdentity' = 'contoso.com'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ 'Identity-Extra' = 'contoso.com'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' -Parameters @{ '1Identity' = 'contoso.com'; DomainType = 'Authoritative' }).Allowed | Should -BeFalse
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-Mailbox' -Parameters @{ Identity123 = 'not-allowed'; Identity = 'user@contoso.com' }).Allowed | Should -BeFalse
    }

    It 'accepts alphanumeric parameter names like CustomAttribute1' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; CustomAttribute1 = 'value' }).Allowed | Should -BeTrue
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-Mailbox' -Parameters @{ Identity = 'user@contoso.com'; CustomAttribute15 = 'value' }).Allowed | Should -BeTrue
    }
}

Describe 'ExecExoAllowlistedCmdlet endpoint dryRun behavior' {
    BeforeAll {
        class HttpResponseContext { [int]$StatusCode; [object]$Body; [object]$Headers }
        $Accelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
        if (-not $Accelerators::Get.ContainsKey('HttpStatusCode')) { $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode]) }
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Test-CIPPGuardedWriteRequest.ps1')
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Get-CIPPExoAllowlistedCmdletPlan.ps1')
        function Add-CIPPGuardedWriteAudit { param($Endpoint, $Tenant, $Ticket, $Caller, $Request, $Before, $After, [bool]$DryRun, [string]$Result) 'audit-1' }
        function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev) }
        function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = 'exchange failed' } }
        $script:ForceNoArchive = $false
        $script:ForceMailboxReadError = $false
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, [switch]$useSystemMailbox)
            $script:ExoCalls.Add([pscustomobject]@{ Cmdlet = $cmdlet; Params = $cmdParams })
            if ($cmdlet -eq 'Get-AcceptedDomain') { return [pscustomobject]@{ Identity = 'contoso.com'; DomainType = 'Authoritative' } }
            if ($cmdlet -eq 'Get-DkimSigningConfig') { return [pscustomobject]@{ Identity = 'contoso.com'; Enabled = $false } }
            if ($cmdlet -eq 'Set-AcceptedDomain') { return [pscustomobject]@{ Identity = 'contoso.com'; DomainType = 'InternalRelay' } }
            if ($cmdlet -eq 'Set-DkimSigningConfig') { return [pscustomobject]@{ Identity = 'contoso.com'; Enabled = $true } }
            if ($cmdlet -eq 'Get-Mailbox') {
                if ($script:ForceMailboxReadError) { throw 'Mailbox not found' }
                if ($script:ForceNoArchive) { return [pscustomobject]@{ Identity = 'user@contoso.com'; ArchiveStatus = 'None'; ArchiveGuid = '00000000-0000-0000-0000-000000000000' } }
                return [pscustomobject]@{ Identity = 'user@contoso.com'; ArchiveStatus = 'Active'; ArchiveGuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' }
            }
            if ($cmdlet -eq 'Disable-Mailbox') { return [pscustomobject]@{ Identity = 'user@contoso.com'; ArchiveStatus = 'None' } }
            if ($cmdlet -eq 'Test-ApplicationAccessPolicy') { return [pscustomobject]@{ AccessGranted = $true } }
        }
        . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecExoAllowlistedCmdlet.ps1')
    }

    BeforeEach {
        $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new()
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
    }

    It 'calls only Get-AcceptedDomain on dryRun and never Set-AcceptedDomain' {
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $true
                Cmdlet       = 'Set-AcceptedDomain'
                Parameters   = @{ Identity = 'contoso.com'; DomainType = 'InternalRelay' }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.Before | Should -Not -BeNullOrEmpty
        $Response.Body.After | Should -BeNullOrEmpty
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Get-AcceptedDomain')
    }

    It 'calls only Get-DkimSigningConfig on dryRun and never Set-DkimSigningConfig' {
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $true
                Cmdlet       = 'Set-DkimSigningConfig'
                Parameters   = @{ Identity = 'contoso.com'; Enabled = $true }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.Before | Should -Not -BeNullOrEmpty
        $Response.Body.After | Should -BeNullOrEmpty
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Get-DkimSigningConfig')
    }

    It 'calls only Get-Mailbox on dryRun and never Disable-Mailbox' {
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $true
                Cmdlet       = 'Disable-Mailbox'
                Parameters   = @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.Before | Should -Not -BeNullOrEmpty
        $Response.Body.After | Should -BeNullOrEmpty
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Get-Mailbox')
    }

    It 'calls Get-AcceptedDomain then Set-AcceptedDomain when dryRun is false' {
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $false
                Cmdlet       = 'Set-AcceptedDomain'
                Parameters   = @{ Identity = 'contoso.com'; DomainType = 'InternalRelay' }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'Success'
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Get-AcceptedDomain', 'Set-AcceptedDomain')
    }

    It 'accepts case-insensitive Cmdlet and parameter names' {
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{}
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $true
                cmdlet       = 'set-accepteddomain'
                parameters   = @{ identity = 'contoso.com'; domaintype = 'Authoritative' }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
    }

    It 'calls Get-Mailbox then Disable-Mailbox then Get-Mailbox again when dryRun is false' {
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $false
                Cmdlet       = 'Disable-Mailbox'
                Parameters   = @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'Success'
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Get-Mailbox', 'Disable-Mailbox', 'Get-Mailbox')
        $script:ExoCalls[1].Params.Archive | Should -Be $true
        $script:ExoCalls[1].Params.Confirm | Should -Be $false
        $script:ExoCalls[1].Params.Identity | Should -Be 'user@contoso.com'
    }

    It 'returns After from Set-AcceptedDomain result when dryRun is false' {
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $false
                Cmdlet       = 'Set-AcceptedDomain'
                Parameters   = @{ Identity = 'contoso.com'; DomainType = 'InternalRelay' }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.After | Should -Not -BeNullOrEmpty
        $Response.Body.After.DomainType | Should -Be 'InternalRelay'
    }

    It 'returns After from Test-ApplicationAccessPolicy result when dryRun is false' {
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $false
                Cmdlet       = 'Test-ApplicationAccessPolicy'
                Parameters   = @{ Identity = 'user@contoso.com'; AppId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.After | Should -Not -BeNullOrEmpty
    }

    It 'refuses Disable-Mailbox on dryRun when mailbox has no archive' {
        $script:ForceNoArchive = $true
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $true
                Cmdlet       = 'Disable-Mailbox'
                Parameters   = @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
            }
        } -TriggerMetadata $null
        $script:ForceNoArchive = $false
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'no active archive'
    }

    It 'refuses Disable-Mailbox on real run when mailbox has no archive' {
        $script:ForceNoArchive = $true
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $false
                Cmdlet       = 'Disable-Mailbox'
                Parameters   = @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
            }
        } -TriggerMetadata $null
        $script:ForceNoArchive = $false
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'no active archive'
    }

    It 'reports read error when Get-Mailbox fails' {
        $script:ForceMailboxReadError = $true
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $true
                Cmdlet       = 'Disable-Mailbox'
                Parameters   = @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
            }
        } -TriggerMetadata $null
        $script:ForceMailboxReadError = $false
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'Failed to read mailbox'
    }

    It 'refuses Disable-Mailbox when ArchiveGuid is braced zero GUID' {
        Mock New-ExoRequest {
            if ($cmdlet -eq 'Get-Mailbox') {
                [pscustomobject]@{ Identity = 'user@contoso.com'; ArchiveGuid = '{00000000-0000-0000-0000-000000000000}'; ArchiveStatus = 'None'; ArchiveDatabase = $null }
            } else { [pscustomobject]@{ Identity = 'user@contoso.com' } }
        }
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $true
                Cmdlet       = 'Disable-Mailbox'
                Parameters   = @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'no active archive'
    }

    It 'refuses Disable-Mailbox when ArchiveGuid is string false' {
        Mock New-ExoRequest {
            if ($cmdlet -eq 'Get-Mailbox') {
                [pscustomobject]@{ Identity = 'user@contoso.com'; ArchiveGuid = 'false'; ArchiveStatus = 'None'; ArchiveDatabase = $null }
            } else { [pscustomobject]@{ Identity = 'user@contoso.com' } }
        }
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $true
                Cmdlet       = 'Disable-Mailbox'
                Parameters   = @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'no active archive'
    }

    It 'refuses Disable-Mailbox when valid GUID but ArchiveDatabase null and ArchiveStatus None' {
        Mock New-ExoRequest {
            if ($cmdlet -eq 'Get-Mailbox') {
                [pscustomobject]@{ Identity = 'user@contoso.com'; ArchiveGuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'; ArchiveStatus = 'None'; ArchiveDatabase = $null }
            } else { [pscustomobject]@{ Identity = 'user@contoso.com' } }
        }
        $Response = Invoke-ExecExoAllowlistedCmdlet -Request @{
            Params  = @{ CIPPEndpoint = 'ExecExoAllowlistedCmdlet' }
            Headers = @{ 'x-ms-client-principal-name' = 'admin@msp.com' }
            Body    = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '3280061'
                dryRun       = $false
                Cmdlet       = 'Disable-Mailbox'
                Parameters   = @{ Identity = 'user@contoso.com'; Archive = $true; Confirm = $false }
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'no active archive'
    }
}

Describe 'Set-CIPPMailboxArchive' {
    BeforeAll {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Set-CIPPMailboxArchive.ps1')
        function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
        function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = 'exchange failed' } }
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, [switch]$useSystemMailbox)
            $script:ExoCalls.Add([pscustomobject]@{ Cmdlet = $cmdlet; Params = $cmdParams })
            [pscustomobject]@{ Identity = 'user@contoso.com' }
        }
    }

    BeforeEach {
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
    }

    It 'calls Enable-Mailbox with Archive true when ArchiveEnabled is true' {
        $Result = Set-CIPPMailboxArchive -UserID 'user@contoso.com' -TenantFilter 'contoso.onmicrosoft.com' -ArchiveEnabled $true
        $Result | Should -Match 'enabled'
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Enable-Mailbox')
        $script:ExoCalls[0].Params.Archive | Should -Be $true
    }

    It 'calls Disable-Mailbox with Archive true and Confirm false when ArchiveEnabled is false' {
        $Result = Set-CIPPMailboxArchive -UserID 'user@contoso.com' -TenantFilter 'contoso.onmicrosoft.com' -ArchiveEnabled $false
        $Result | Should -Match 'disabled'
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Disable-Mailbox')
        $script:ExoCalls[0].Params.Archive | Should -Be $true
        $script:ExoCalls[0].Params.Confirm | Should -Be $false
    }

    It 'calls Enable-Mailbox with AutoExpandingArchive when passed' {
        $Result = Set-CIPPMailboxArchive -UserID 'user@contoso.com' -TenantFilter 'contoso.onmicrosoft.com' -ArchiveEnabled $true -AutoExpandingArchive
        $Result | Should -Match 'auto-expanding'
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Enable-Mailbox')
        $script:ExoCalls[0].Params.AutoExpandingArchive | Should -Be $true
    }
}

Describe 'Invoke-ExecEnableAutoExpandingArchive' {
    BeforeAll {
        class HttpResponseContext { [int]$StatusCode; [object]$Body; [object]$Headers }
        $Accelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
        if (-not $Accelerators::Get.ContainsKey('HttpStatusCode')) { $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode]) }
        if (-not $Accelerators::Get.ContainsKey('HttpResponseContext')) { $Accelerators::Add('HttpResponseContext', [HttpResponseContext]) }
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Set-CIPPMailboxArchive.ps1')
        . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecEnableAutoExpandingArchive.ps1')
        function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
        function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = if ($Exception.Exception) { $Exception.Exception.Message } else { $Exception.Message } } }
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, [switch]$useSystemMailbox)
            $script:ExoCalls.Add([pscustomobject]@{ Cmdlet = $cmdlet; Params = $cmdParams })
            [pscustomobject]@{ Identity = 'user@contoso.com' }
        }
    }

    BeforeEach {
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
    }

    It 'passes ArchiveEnabled true to Set-CIPPMailboxArchive' {
        $Response = Invoke-ExecEnableAutoExpandingArchive -Request @{
            Headers = @{}
            Body    = @{ ID = 'user@contoso.com'; tenantFilter = 'contoso.onmicrosoft.com'; username = 'user@contoso.com' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Enable-Mailbox')
        $script:ExoCalls[0].Params.AutoExpandingArchive | Should -Be $true
    }
}

Describe 'ExecDisableArchive' {
    BeforeAll {
        class HttpResponseContext { [int]$StatusCode; [object]$Body; [object]$Headers }
        $Accelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
        if (-not $Accelerators::Get.ContainsKey('HttpStatusCode')) { $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode]) }
        if (-not $Accelerators::Get.ContainsKey('HttpResponseContext')) { $Accelerators::Add('HttpResponseContext', [HttpResponseContext]) }
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Set-CIPPMailboxArchive.ps1')
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Add-CIPPMoveArchiveItemsAudit.ps1')
        . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecDisableArchive.ps1')
        function Get-CIPPMoveArchiveItemsPreview { param($TenantFilter, $UserPrincipalName) [pscustomobject]@{ ArchiveItemCount = 0; ArchiveTotalBytes = 0; PrimaryItemCount = 100; PrimaryTotalBytes = 1000000 } }
        function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
        function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = if ($Exception.Exception) { $Exception.Exception.Message } else { $Exception.Message } } }
        function Get-CippTable { param($tablename) @{ TableName = $tablename } }
        function Add-CIPPAzDataTableEntity { param($Table, $Entity, [switch]$Force) }
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, [switch]$useSystemMailbox)
            $script:ExoCalls.Add([pscustomobject]@{ Cmdlet = $cmdlet; Params = $cmdParams })
            [pscustomobject]@{ Identity = 'user@contoso.com' }
        }
    }

    BeforeEach {
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
    }

    It 'rejects non-numeric TicketNumber' {
        $Response = Invoke-ExecDisableArchive -Request @{
            Params  = @{ CIPPEndpoint = 'ExecDisableArchive' }
            Headers = @{}
            Query   = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; UserPrincipalName = 'user@contoso.com'; TicketNumber = 'abc123' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match '6 to 8 digit'
    }

    It 'rejects TicketNumber shorter than 6 digits' {
        $Response = Invoke-ExecDisableArchive -Request @{
            Params  = @{ CIPPEndpoint = 'ExecDisableArchive' }
            Headers = @{}
            Query   = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; UserPrincipalName = 'user@contoso.com'; TicketNumber = '12345' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match '6 to 8 digit'
    }

    It 'accepts Force as boolean true' {
        $Response = Invoke-ExecDisableArchive -Request @{
            Params  = @{ CIPPEndpoint = 'ExecDisableArchive' }
            Headers = @{}
            Query   = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; UserPrincipalName = 'user@contoso.com'; TicketNumber = '3278856'; Force = $true; Reason = 'Test reason' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
    }

    It 'refuses Force string false when archive has items' {
        Mock Get-CIPPMoveArchiveItemsPreview { [pscustomobject]@{ ArchiveItemCount = 5; ArchiveTotalBytes = 1000; PrimaryItemCount = 100; PrimaryTotalBytes = 1000000 } }
        $Response = Invoke-ExecDisableArchive -Request @{
            Params  = @{ CIPPEndpoint = 'ExecDisableArchive' }
            Headers = @{}
            Query   = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; UserPrincipalName = 'user@contoso.com'; TicketNumber = '3278856'; Force = 'false' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'still contains 5 item'
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -BeNullOrEmpty
    }

    It 'rejects invalid Force value and writes audit' {
        $script:AuditEntities = [System.Collections.Generic.List[object]]::new()
        Mock Add-CIPPAzDataTableEntity { param($Table, $Entity, [switch]$Force) $script:AuditEntities.Add($Entity) }
        $Response = Invoke-ExecDisableArchive -Request @{
            Params  = @{ CIPPEndpoint = 'ExecDisableArchive' }
            Headers = @{}
            Query   = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; UserPrincipalName = 'user@contoso.com'; TicketNumber = '3278856'; Force = 'invalid' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'Failed'
        $script:AuditEntities.Count | Should -BeGreaterThan 0
        $script:AuditEntities[0].Result | Should -Match 'invalid'
    }

    It 'rejects ticket with trailing newline' {
        $Response = Invoke-ExecDisableArchive -Request @{
            Params  = @{ CIPPEndpoint = 'ExecDisableArchive' }
            Headers = @{}
            Query   = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; UserPrincipalName = 'user@contoso.com'; TicketNumber = "3278856`n" }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match '6 to 8 digit'
    }
}

Describe 'Teams app package' {
    It 'refuses a zip whose manifest id does not match' {
        Add-Type -AssemblyName System.IO.Compression
        $Stream = [System.IO.MemoryStream]::new()
        $Zip = [System.IO.Compression.ZipArchive]::new($Stream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
        $Entry = $Zip.CreateEntry('manifest.json')
        $Writer = [System.IO.StreamWriter]::new($Entry.Open())
        $Writer.Write('{"id":"actual-id"}')
        $Writer.Dispose()
        $Zip.Dispose()
        $Package = [Convert]::ToBase64String($Stream.ToArray())
        $Checked = Test-CIPPTeamsAppPackage -PackageBase64 $Package -ExpectedManifestId 'expected-id'
        $Checked.Allowed | Should -BeFalse
        $Checked.Reason | Should -Match 'does not match'
    }
}

Describe 'secrets and Conditional Access' {
    It 'redacts secret fields and exact secret values' {
        $Copy = ConvertTo-CIPPGuardedWriteRedacted -Value @{ displayName = 'App'; secretText = 'super-secret-value' } -SecretValues @('super-secret-value')
        $Copy.secretText | Should -Be '[redacted]'
        ($Copy | ConvertTo-Json -Compress) | Should -Not -Match 'super-secret-value'
    }

    It 'masks a phone number on an authentication method' {
        $Masked = Protect-CIPPAuthMethod -Method ([pscustomobject]@{ phoneNumber = '+15551212'; '@odata.type' = '#microsoft.graph.phoneAuthenticationMethod' })
        $Masked.phoneNumber | Should -Be '*******12'
        $Masked.phoneNumber | Should -Not -Match '555'
    }

    It 'keeps excluded users when the patch omits them and names a drop when the patch clears them' {
        $Current = [pscustomobject]@{
            grantControls = [pscustomobject]@{ builtInControls = @('mfa') }
            conditions    = [pscustomobject]@{ users = [pscustomobject]@{ excludeUsers = @('breakglass@contoso.com'); excludeGroups = @() } }
        }
        $Merged = Merge-CIPPCAPolicyUpdate -Current $Current -Patch ([pscustomobject]@{ displayName = 'CA201' })
        @(Test-CIPPCAPolicyRemoval -Current $Current -Proposed $Merged) | Should -BeNullOrEmpty
        $Cleared = Merge-CIPPCAPolicyUpdate -Current $Current -Patch ([pscustomobject]@{ conditions = [pscustomobject]@{ users = [pscustomobject]@{ excludeUsers = @() } } })
        @(Test-CIPPCAPolicyRemoval -Current $Current -Proposed $Cleared) | Should -Contain 'excludeUsers'
        @(Test-CIPPCAPolicyRemoval -Current $Current -Proposed $Cleared -ConfirmRemoval @('excludeUsers')) | Should -BeNullOrEmpty
    }
}

Describe 'ExecAppRegistration secret handling' {
    BeforeAll {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Test-CIPPGuardedWriteRequest.ps1')
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/ConvertTo-CIPPGuardedWriteRedacted.ps1')
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Add-CIPPGuardedWriteAudit.ps1')
        function Get-CippRequestAllowedPermissions { @() }
        function Get-CippKeyVaultName { 'manage365-vault' }
        function Set-CippKeyVaultSecret { param($VaultName, $Name, $SecretValue) $script:StoredSecretName = $Name }
        function Get-CippKeyVaultSecret {
            param($VaultName, $Name, [switch]$AsPlainText, [switch]$IncludeAttributes)
            $script:SecretReads++
            if ($script:SecretMissing) { throw 'SecretNotFound' }
            if ($script:SecretDeleteFails) { return @{ Value = 'super-secret-value'; Created = [datetimeoffset]::UtcNow } }
            return @{ Value = 'super-secret-value'; Created = $script:SecretCreated }
        }
        function Remove-CippKeyVaultSecret {
            param($VaultName, $Name)
            if ($script:SecretDeleteFails) { throw 'delete failed' }
            $script:RemovedSecret = $Name
        }
        function Get-CippTable { param($TableName) @{ TableName = $TableName } }
        function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) $script:AuditEntity = $Entity }
        function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev) $script:LogMessage = $message }
        function New-GraphPOSTRequest {
            param($uri, $tenantid, $type, $body, $asApp)
            if ($uri -like '*/applications' -and $uri -notlike '*/addPassword') { return [pscustomobject]@{ id = 'object-1'; appId = 'app-1' } }
            if ($uri -like '*/servicePrincipals') { return [pscustomobject]@{ id = 'sp-1' } }
            if ($uri -like '*/addPassword') { return [pscustomobject]@{ keyId = 'key-1'; secretText = 'super-secret-value' } }
        }
        class HttpResponseContext { [int]$StatusCode; [object]$Body; [object]$Headers }
        $Accelerators = [PowerShell].Assembly.GetType('System.Management.Automation.TypeAccelerators')
        if (-not $Accelerators::Get.ContainsKey('HttpStatusCode')) { $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode]) }
        . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Applications/Invoke-ExecAppRegistration.ps1')
        . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Applications/Invoke-GetAppRegistrationSecret.ps1')
        . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListMyApiRoles.ps1')
    }

    It 'stores the secret in Key Vault and leaves it out of the response, log, and audit' {
        $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new()
        $Request = @{
            Params  = @{ CIPPEndpoint = 'ExecAppRegistration' }
            Headers = @{}
            Body    = @{
                tenantFilter   = 'contoso.onmicrosoft.com'
                TicketNumber   = '327521'
                WhatIf         = $false
                DisplayName    = 'Contoso App'
                SignInAudience = 'AzureADMyOrg'
                Credential     = @{ Type = 'Secret'; ExpiryMonths = 6 }
            }
        }
        $Response = Invoke-ExecAppRegistration -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.SecretDelivery.SecretUri | Should -Match 'manage365-vault'
        $Response.Body.SecretDelivery.RetrievalEndpoint | Should -Be 'GetAppRegistrationSecret'
        $Response.Body.SecretDelivery.RetrievalExpiresAt | Should -Not -BeNullOrEmpty
        $script:StoredSecretName | Should -Be 'appreg-app-1-key-1'
        ($Response | ConvertTo-Json -Depth 8) | Should -Not -Match 'super-secret-value'
        $script:LogMessage | Should -Not -Match 'super-secret-value'
        ($script:AuditEntity | ConvertTo-Json -Depth 6) | Should -Not -Match 'super-secret-value'
    }

    It 'returns a stored secret once and leaves it out of the audit row' {
        $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new()
        $script:SecretReads = 0
        $script:SecretMissing = $false
        $script:SecretDeleteFails = $false
        $script:SecretCreated = [datetimeoffset]::UtcNow
        $script:RemovedSecret = $null
        $script:LogMessage = $null
        $AppId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $KeyId = '11111111-2222-3333-4444-555555555555'
        $Request = @{
            Params  = @{ CIPPEndpoint = 'GetAppRegistrationSecret' }
            Headers = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '3275215'; dryRun = $false; AppId = $AppId; CredentialKeyId = $KeyId }
        }
        $Response = Invoke-GetAppRegistrationSecret -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Secret | Should -Be 'super-secret-value'
        $script:RemovedSecret | Should -Be "appreg-$AppId-$KeyId"
        $script:SecretReads | Should -Be 1
        ($script:AuditEntity | ConvertTo-Json -Depth 6) | Should -Not -Match 'super-secret-value'
        $script:LogMessage | Should -Not -Match 'super-secret-value'

        $script:SecretReads = 0
        $Dry = Invoke-GetAppRegistrationSecret -Request @{
            Params  = @{ CIPPEndpoint = 'GetAppRegistrationSecret' }
            Headers = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '3275215'; dryRun = $true; AppId = $AppId; CredentialKeyId = $KeyId }
        } -TriggerMetadata $null
        $Dry.StatusCode | Should -Be 200
        $Dry.Body.Status | Should -Be 'DryRun'
        $Dry.Body.Secret | Should -BeNullOrEmpty
        $script:SecretReads | Should -Be 0
    }

    It 'refuses an expired secret and does not return it' {
        $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new()
        $script:SecretCreated = [datetimeoffset]::UtcNow.AddHours(-25)
        $script:SecretDeleteFails = $false
        $Response = Invoke-GetAppRegistrationSecret -Request @{
            Params  = @{ CIPPEndpoint = 'GetAppRegistrationSecret' }
            Headers = @{}
            Body    = @{
                tenantFilter    = 'contoso.onmicrosoft.com'
                ticketNumber    = '3275215'
                AppId           = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                CredentialKeyId = '11111111-2222-3333-4444-555555555555'
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 410
        ($Response | ConvertTo-Json -Depth 6) | Should -Not -Match 'super-secret-value'
    }
}

Describe 'ListMyApiRoles' {
    BeforeAll {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/CIPP/Core/Invoke-ListMyApiRoles.ps1')
    }

    It 'returns the permissions resolved for this request' {
        function Get-CippRequestAllowedPermissions { @('CIPP.Core.Read', 'Tenant.AppGovernance.ReadWrite') }
        $script:CippAccessUserContext = [pscustomobject]@{ Roles = @('admin') }
        $Response = Invoke-ListMyApiRoles -Request @{ Params = @{ CIPPEndpoint = 'ListMyApiRoles' } } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Results | Should -Contain 'Tenant.AppGovernance.ReadWrite'
        $Response.Body.Roles | Should -Contain 'admin'
    }
}

Describe 'GuardedTenantWrites feature flag' {
    It 'ships disabled and names the new write endpoints' {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        $Flags = Get-Content (Join-Path $RepoRoot 'Config/FeatureFlags.json') -Raw | ConvertFrom-Json
        $Flag = $Flags | Where-Object { $_.Id -eq 'GuardedTenantWrites' }
        $Flag.Enabled | Should -BeFalse
        $Flag.Endpoints | Should -Contain 'ExecGraphWrite'
        $Flag.Endpoints | Should -Contain 'ExecAppRegistration'
        $Flag.Endpoints | Should -Contain 'GetAppRegistrationSecret'
        foreach ($Name in @('ExecCustomMailFilterPolicy', 'ExecPresetSecurityPolicy', 'ExecInboundConnectorEnhancedFiltering', 'ExecMailboxJunkConfiguration', 'ExecFocusedInbox')) {
            $Flag.Endpoints | Should -Contain $Name
        }
        $Flag.Endpoints | Should -Not -Contain 'ListUserAuthMethods'
        $Flag.Endpoints | Should -Not -Contain 'ListMyApiRoles'
    }

    It 'publishes the allowlist in openapi.json' {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        $Spec = Get-Content (Join-Path $RepoRoot 'Config/openapi.json') -Raw
        foreach ($Phrase in @(
                'Remove-ServicePrincipal',
                'Remove-ManagementScope',
                'Application Mail.Read',
                'Application Calendars.Read',
                'Application Mail.ReadBasic',
                'TrustedSendersAndDomains',
                'DELETE servicePrincipals/{id}/appRoleAssignments/{id}',
                'POST chats/{id}/installedApps',
                'DELETE chats/{id}/installedApps/{id}',
                'DELETE appCatalogs/teamsApps/{id}',
                'DELETE applications/{id}',
                'DELETE servicePrincipals/{id}',
                'consentType Principal only',
                'GetAppRegistrationSecret',
                'ListMyApiRoles'
            )) {
            $Spec | Should -Match ([regex]::Escape($Phrase))
        }
    }
}

Describe 'ExecSetMailboxCustomAttributes guarded path' {
    BeforeAll {
        class HttpResponseContext { [int]$StatusCode; [object]$Body; [object]$Headers }
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Test-CIPPGuardedWriteRequest.ps1')
        function Add-CIPPGuardedWriteAudit { param($Endpoint, $Tenant, $Ticket, $Caller, $Request, $Before, $After, [bool]$DryRun, [string]$Result) 'audit-1' }
        function Write-LogMessage { param($API, $tenant, $message, $sev) }
        function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = 'exchange failed' } }
        function New-ExoRequest {
            param($tenantid, $cmdlet, $cmdParams, $Select)
            $script:ExoCalls.Add([pscustomobject]@{ Cmdlet = $cmdlet; Params = $cmdParams })
            if ($cmdlet -eq 'Get-Mailbox') { return [pscustomobject]@{ CustomAttribute3 = 'old-value' } }
        }
        . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecSetMailboxCustomAttributes.ps1')
    }

    BeforeEach {
        $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new()
        $script:ExoCalls = [System.Collections.Generic.List[object]]::new()
    }

    It 'rejects a missing ticket before reading the mailbox' {
        $Response = Invoke-ExecSetMailboxCustomAttributes -Request @{
            Params = @{ CIPPEndpoint = 'ExecSetMailboxCustomAttributes' }
            Body   = @{ tenantFilter = 'contoso.onmicrosoft.com'; AttributeNumber = 3; Value = 'new'; Identity = 'user@contoso.com' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'ticketNumber'
        $script:ExoCalls.Count | Should -Be 0
    }

    It 'rejects a blank tenantFilter' {
        $Response = Invoke-ExecSetMailboxCustomAttributes -Request @{
            Params = @{ CIPPEndpoint = 'ExecSetMailboxCustomAttributes' }
            Body   = @{ tenantFilter = ''; ticketNumber = '3275215'; AttributeNumber = 3; Value = 'new'; Identity = 'user@contoso.com' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'tenantFilter'
    }

    It 'returns the old and new values on a dry run and does not write' {
        $Response = Invoke-ExecSetMailboxCustomAttributes -Request @{
            Params  = @{ CIPPEndpoint = 'ExecSetMailboxCustomAttributes' }
            Headers = @{}
            Body    = @{
                tenantFilter    = 'contoso.onmicrosoft.com'
                ticketNumber    = '3275215'
                dryRun          = $true
                AttributeNumber = 3
                Value           = 'new-value'
                Identity        = 'user@contoso.com'
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.OldValue | Should -Be 'old-value'
        $Response.Body.NewValue | Should -Be 'new-value'
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Get-Mailbox')
    }

    It 'writes one attribute and keeps an empty value as a clear' {
        $Response = Invoke-ExecSetMailboxCustomAttributes -Request @{
            Params  = @{ CIPPEndpoint = 'ExecSetMailboxCustomAttributes' }
            Headers = @{}
            Body    = @{
                tenantFilter    = 'contoso.onmicrosoft.com'
                ticketNumber    = '3275215'
                dryRun          = $false
                AttributeNumber = 3
                Value           = ''
                Identity        = 'user@contoso.com'
            }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        $Response.Body.OldValue | Should -Be 'old-value'
        $Response.Body.NewValue | Should -Be ''
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Get-Mailbox', 'Set-Mailbox')
        $script:ExoCalls[1].Params.CustomAttribute3 | Should -Be ''
    }

    It 'still updates CustomAttribute1 for the mailbox editor without a ticket' {
        $Response = Invoke-ExecSetMailboxCustomAttributes -Request @{
            Params  = @{ CIPPEndpoint = 'ExecSetMailboxCustomAttributes' }
            Headers = @{}
            Body    = [pscustomobject]@{ tenantFilter = 'contoso.onmicrosoft.com'; userid = 'user@contoso.com'; Identity = 'user@contoso.com'; CustomAttribute1 = 'editor' }
        } -TriggerMetadata $null
        $Response.StatusCode | Should -Be 200
        @($script:ExoCalls | ForEach-Object { $_.Cmdlet }) | Should -Be @('Set-Mailbox')
        $script:ExoCalls[0].Params.CustomAttribute1 | Should -Be 'editor'
    }

    It 'rejects an attribute number outside 1 to 15 and a value over 1024 characters' {
        $High = Invoke-ExecSetMailboxCustomAttributes -Request @{
            Params  = @{ CIPPEndpoint = 'ExecSetMailboxCustomAttributes' }
            Headers = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '3275215'; AttributeNumber = 16; Value = 'x'; Identity = 'user@contoso.com' }
        } -TriggerMetadata $null
        $High.StatusCode | Should -Be 400
        $Long = Invoke-ExecSetMailboxCustomAttributes -Request @{
            Params  = @{ CIPPEndpoint = 'ExecSetMailboxCustomAttributes' }
            Headers = @{}
            Body    = @{ tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '3275215'; AttributeNumber = 1; Value = ('x' * 1025); Identity = 'user@contoso.com' }
        } -TriggerMetadata $null
        $Long.StatusCode | Should -Be 400
        $script:ExoCalls.Count | Should -Be 0
    }
}

Describe 'GuardedTenantWrites off returns 503' {
    BeforeAll {
        class HttpResponseContext { [int]$StatusCode; [object]$Body; [object]$Headers }
        $script:FlagRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        function Set-CippUserAgentContext { param($Headers) }
        function Get-CIPPFeatureFlag {
            $Flags = Get-Content (Join-Path $script:FlagRoot 'Config/FeatureFlags.json') -Raw | ConvertFrom-Json
            foreach ($Flag in $Flags) {
                if ($Flag.Id -eq 'GuardedTenantWrites') { $Flag.Enabled = $false }
            }
            return $Flags
        }
        . (Join-Path $script:FlagRoot 'Modules/CIPPCore/Public/Entrypoints/HTTP Functions/New-CippCoreRequest.ps1')
    }

    It 'returns 503 for every endpoint named on the flag' {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        $Flag = Get-Content (Join-Path $RepoRoot 'Config/FeatureFlags.json') -Raw | ConvertFrom-Json | Where-Object { $_.Id -eq 'GuardedTenantWrites' }
        foreach ($Name in @($Flag.Endpoints)) {
            $Response = New-CippCoreRequest -Request @{
                Params  = @{ CIPPEndpoint = $Name }
                Headers = @{}
                Body    = @{ tenantFilter = 'contoso.onmicrosoft.com' }
            } -TriggerMetadata @{}
            [int]$Response.StatusCode | Should -Be 503
        }
    }
}

Describe 'GuardedWrite config path resolution (Freshdesk #3280061)' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    }

    It 'resolves ExoCmdletAllowlist.json in the source layout' {
        $SourceLayout = Join-Path $script:RepoRoot 'Modules/CIPPCore/Public/GuardedWrite'
        $ConfigPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/ExoCmdletAllowlist.json' -PSScriptRoot $SourceLayout
        $ConfigPath | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $ConfigPath -PathType Leaf | Should -BeTrue
        $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        $Allowlist.PSObject.Properties['Set-AcceptedDomain'] | Should -Not -BeNullOrEmpty
        $Allowlist.'Set-AcceptedDomain' | Should -Contain 'Identity'
        $Allowlist.'Set-AcceptedDomain' | Should -Contain 'DomainType'
    }

    It 'resolves GraphAllowlist.json in the source layout' {
        $SourceLayout = Join-Path $script:RepoRoot 'Modules/CIPPCore/Public/GuardedWrite'
        $ConfigPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/GraphAllowlist.json' -PSScriptRoot $SourceLayout
        $ConfigPath | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $ConfigPath -PathType Leaf | Should -BeTrue
        $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        $Allowlist | Should -Not -BeNullOrEmpty
        ($Allowlist | Where-Object { $_.method -eq 'POST' -and $_.path -match 'oauth2PermissionGrants' }) | Should -Not -BeNullOrEmpty
    }

    It 'resolves ExoCmdletAllowlist.json in a simulated compiled layout' {
        $TempRoot = Join-Path $TestDrive 'SimulatedCompiled'
        $ModulePath = Join-Path $TempRoot 'Modules/CIPPCore'
        $ConfigPath = Join-Path $TempRoot 'Config/GuardedWrites'
        New-Item -ItemType Directory -Path $ModulePath -Force | Out-Null
        New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
        Copy-Item -Path (Join-Path $script:RepoRoot 'Config/GuardedWrites/ExoCmdletAllowlist.json') `
            -Destination (Join-Path $ConfigPath 'ExoCmdletAllowlist.json') -Force
        $ResolvedPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/ExoCmdletAllowlist.json' -PSScriptRoot $ModulePath
        $ResolvedPath | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $ResolvedPath -PathType Leaf | Should -BeTrue
        $Allowlist = Get-Content -LiteralPath $ResolvedPath -Raw | ConvertFrom-Json
        $Allowlist.'Set-AcceptedDomain' | Should -Contain 'Identity'
    }

    It 'resolves GraphAllowlist.json in a simulated compiled layout' {
        $TempRoot = Join-Path $TestDrive 'SimulatedCompiled'
        $ModulePath = Join-Path $TempRoot 'Modules/CIPPCore'
        $ConfigPath = Join-Path $TempRoot 'Config/GuardedWrites'
        New-Item -ItemType Directory -Path $ModulePath -Force | Out-Null
        New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
        Copy-Item -Path (Join-Path $script:RepoRoot 'Config/GuardedWrites/GraphAllowlist.json') `
            -Destination (Join-Path $ConfigPath 'GraphAllowlist.json') -Force
        $ResolvedPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/GraphAllowlist.json' -PSScriptRoot $ModulePath
        $ResolvedPath | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $ResolvedPath -PathType Leaf | Should -BeTrue
        $Allowlist = Get-Content -LiteralPath $ResolvedPath -Raw | ConvertFrom-Json
        $Allowlist | Should -Not -BeNullOrEmpty
    }

    It 'uses CIPPRootPath when set' {
        $TempRoot = Join-Path $TestDrive 'CIPPRootPathTest'
        $ConfigPath = Join-Path $TempRoot 'Config/GuardedWrites'
        New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
        Copy-Item -Path (Join-Path $script:RepoRoot 'Config/GuardedWrites/ExoCmdletAllowlist.json') `
            -Destination (Join-Path $ConfigPath 'ExoCmdletAllowlist.json') -Force
        $OriginalCIPPRootPath = $env:CIPPRootPath
        try {
            $env:CIPPRootPath = $TempRoot
            $ResolvedPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/ExoCmdletAllowlist.json' `
                -PSScriptRoot '/this/path/does/not/exist'
            $ResolvedPath | Should -Be (Join-Path $TempRoot 'Config/GuardedWrites/ExoCmdletAllowlist.json')
            Test-Path -LiteralPath $ResolvedPath -PathType Leaf | Should -BeTrue
        } finally {
            $env:CIPPRootPath = $OriginalCIPPRootPath
        }
    }

    It 'throws a clear error when no config file is found' {
        { Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/NonExistent.json' `
                -PSScriptRoot '/nonexistent/path' -ErrorAction Stop
        } | Should -Throw -ExpectedMessage '*GuardedWrite config file not found*'
    }

    It 'Get-CIPPExoAllowlistedCmdletPlan loads the allowlist and accepts Set-AcceptedDomain' {
        $Plan = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' `
            -Parameters @{ Identity = 'contoso.com'; DomainType = 'Authoritative' }
        $Plan.Allowed | Should -BeTrue
        $Plan.Cmdlet | Should -Be 'Set-AcceptedDomain'
    }

    It 'Get-CIPPGraphWritePlan loads the allowlist and accepts oauth2PermissionGrants' {
        $Plan = Get-CIPPGraphWritePlan -Method POST -Path 'oauth2PermissionGrants' -ApiVersion v1.0 -Body @{}
        $Plan.Allowed | Should -BeTrue
        $Plan.Method | Should -Be 'POST'
    }

    It 'throws when allowlist JSON is malformed' {
        $TempRoot = Join-Path $TestDrive 'MalformedJSON'
        $ConfigPath = Join-Path $TempRoot 'Config/GuardedWrites'
        New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
        Set-Content -Path (Join-Path $ConfigPath 'ExoCmdletAllowlist.json') -Value '{ invalid json' -Force
        $OriginalCIPPRootPath = $env:CIPPRootPath
        try {
            $env:CIPPRootPath = $TempRoot
            {
                Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Set-AcceptedDomain' `
                    -Parameters @{ Identity = 'contoso.com'; DomainType = 'Authoritative' }
            } | Should -Throw -ExpectedMessage '*Failed to load or parse*'
        } finally {
            $env:CIPPRootPath = $OriginalCIPPRootPath
        }
    }
}
