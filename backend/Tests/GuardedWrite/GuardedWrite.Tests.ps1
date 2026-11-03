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
        $Allowed = Get-CIPPGraphWritePlan -Method POST -Path 'oauth2PermissionGrants' -ApiVersion v1.0 -Body @{ consentType = 'AllPrincipals' } -AllowAllPrincipals
        $Allowed.Allowed | Should -BeTrue
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
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'New-ManagementRoleAssignment' -Parameters @{ App = 'app'; Role = 'Organization Management' }).Allowed | Should -BeFalse
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
        $script:StoredSecretName | Should -Be 'appreg-app-1-key-1'
        ($Response | ConvertTo-Json -Depth 8) | Should -Not -Match 'super-secret-value'
        $script:LogMessage | Should -Not -Match 'super-secret-value'
        ($script:AuditEntity | ConvertTo-Json -Depth 6) | Should -Not -Match 'super-secret-value'
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
        $Flag.Endpoints | Should -Not -Contain 'ListUserAuthMethods'
    }
}
