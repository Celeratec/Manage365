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
