BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Private/Resolve-CIPPGuardedWriteConfigPath.ps1')
    foreach ($Name in @(
            'Test-CIPPAzArmSegment',
            'Get-CIPPAzArmWritePlan',
            'Invoke-CIPPAzArmRequest',
            'Get-CIPPAzArmTenantConfig',
            'Get-CIPPAzArmAccessToken',
            'Invoke-CIPPAzArmWriteAction'
        )) {
        . (Join-Path $RepoRoot "Modules/CIPPCore/Public/AzureArm/$Name.ps1")
    }
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Test-CIPPGuardedWriteRequest.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Add-CIPPGuardedWriteAudit.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/ConvertTo-CIPPGuardedWriteRedacted.ps1')

    enum HttpStatusCode {
        OK = 200
        BadRequest = 400
        Forbidden = 403
        InternalServerError = 500
    }
    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
        [object]$ContentType
    }

    function Write-LogMessage { param($API, $tenant, $message, $Sev) }
    function Get-CippTable { param($TableName) @{ Fake = $true } }
    function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) }

    $script:Allowlist = Get-Content (Join-Path $RepoRoot 'Config/GuardedWrites/AzureArmAllowlist.json') -Raw | ConvertFrom-Json
    $script:Config = [pscustomobject]@{
        TenantFilter          = 'contoso.onmicrosoft.com'
        Mode                  = 'servicePrincipal'
        SubscriptionId        = '11111111-1111-1111-1111-111111111111'
        AllowedResourceGroups = @('rg-example-demo')
        Profiles              = @{
            change = @{ appId = '33333333-3333-3333-3333-333333333333'; clientSecretName = 'arm-change-secret' }
        }
        Enabled               = $true
        ChangeWindow          = $null
        Notes                 = ''
        ManagingTenantId      = ''
    }
    $script:Recorded = [System.Collections.Generic.List[object]]::new()
}

Describe 'Get-CIPPAzArmWritePlan' {
    It 'builds storage create with secure defaults' {
        $Plan = Get-CIPPAzArmWritePlan -Action 'ExecAzStorageAccount' -Config $script:Config -TicketNumber '1234567' -Allowlist $script:Allowlist -Params @{
            resourceGroupName = 'rg-example-demo'
            name              = 'stexampledemo01'
            location          = 'eastus'
        }
        $Plan.Allowed | Should -BeTrue
        $Plan.Profile | Should -Be 'change'
        $Plan.Requests[0].Body.properties.allowSharedKeyAccess | Should -BeFalse
        $Plan.Requests[0].Body.properties.allowBlobPublicAccess | Should -BeFalse
        $Plan.Requests[0].Body.tags.managedBy | Should -Be 'manage365'
        $Plan.Requests[0].Body.tags.ticket | Should -Be '1234567'
    }

    It 'refuses shared key and public blob overrides' {
        $Shared = Get-CIPPAzArmWritePlan -Action 'ExecAzStorageAccount' -Config $script:Config -TicketNumber '1234567' -Allowlist $script:Allowlist -Params @{
            resourceGroupName = 'rg-example-demo'; name = 'stexampledemo01'; location = 'eastus'; allowSharedKeyAccess = $true
        }
        $Shared.Allowed | Should -BeFalse
        $Public = Get-CIPPAzArmWritePlan -Action 'ExecAzStorageAccount' -Config $script:Config -TicketNumber '1234567' -Allowlist $script:Allowlist -Params @{
            resourceGroupName = 'rg-example-demo'; name = 'stexampledemo01'; location = 'eastus'; allowBlobPublicAccess = $true
        }
        $Public.Allowed | Should -BeFalse
    }

    It 'requires confirmPurgeProtection for Key Vault and refuses accessPolicies' {
        $NoConfirm = Get-CIPPAzArmWritePlan -Action 'ExecAzKeyVault' -Config $script:Config -TicketNumber '1234567' -Allowlist $script:Allowlist -Params @{
            resourceGroupName = 'rg-example-demo'; name = 'kv-example'; location = 'eastus'; tenantId = '44444444-4444-4444-4444-444444444444'
        }
        $NoConfirm.Allowed | Should -BeFalse
        $Policies = Get-CIPPAzArmWritePlan -Action 'ExecAzKeyVault' -Config $script:Config -TicketNumber '1234567' -Allowlist $script:Allowlist -Params @{
            resourceGroupName = 'rg-example-demo'; name = 'kv-example'; location = 'eastus'
            tenantId = '44444444-4444-4444-4444-444444444444'; confirmPurgeProtection = $true
            accessPolicies = @(@{ tenantId = 'x' })
        }
        $Policies.Allowed | Should -BeFalse
    }

    It 'refuses RG outside allowlist and unknown provider namespace' {
        $Rg = Get-CIPPAzArmWritePlan -Action 'ExecAzIdentity' -Config $script:Config -TicketNumber '1234567' -Allowlist $script:Allowlist -Params @{
            resourceGroupName = 'rg-other'; name = 'id-example'; location = 'eastus'
        }
        $Rg.Allowed | Should -BeFalse
        $Ns = Get-CIPPAzArmWritePlan -Action 'ExecAzResourceProvider' -Config $script:Config -TicketNumber '1234567' -Allowlist $script:Allowlist -Params @{
            namespace = 'Microsoft.Hack'
        }
        $Ns.Allowed | Should -BeFalse
    }

    It 'refuses connection-string AzureWebJobsStorage in setAppSettings' {
        $Plan = Get-CIPPAzArmWritePlan -Action 'ExecAzFunctionApp' -Config $script:Config -TicketNumber '1234567' -Allowlist $script:Allowlist -Params @{
            operation = 'setAppSettings'; resourceGroupName = 'rg-example-demo'; name = 'func-example'
            settings = @{ AzureWebJobsStorage = 'DefaultEndpointsProtocol=https;AccountKey=abc' }
        }
        $Plan.Allowed | Should -BeFalse
    }
}

Describe 'Invoke-CIPPAzArmWriteAction dryRun and delete guards' {
    BeforeEach {
        $script:Recorded = [System.Collections.Generic.List[object]]::new()
        $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new()
        Mock Get-CIPPAzArmTenantConfig { $script:Config }
        Mock Get-CIPPAzArmAccessToken { 'fake-token' }
        Mock Add-CIPPGuardedWriteAudit { return 'audit-arm' }
    }

    It 'defaults dryRun true and issues zero writes' {
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            $script:Recorded.Add([pscustomobject]@{ Method = $Method; Uri = $Uri })
            if ($Method -ne 'GET') { throw "Unexpected write in preview: $Method $Uri" }
            # Resource does not exist yet — Before stays null for create-only preview.
            throw 'ARM request failed: 404 Not Found'
        }
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAzStorageAccount' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter      = 'contoso.onmicrosoft.com'
                ticketNumber      = '1234567'
                reason            = 'create storage preview'
                resourceGroupName = 'rg-example-demo'
                name              = 'stexampledemo01'
                location          = 'eastus'
            }
        }
        $Response = Invoke-CIPPAzArmWriteAction -Action 'ExecAzStorageAccount' -Request $Request -Transport $Transport
        $Response.StatusCode | Should -Be 200
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.WhatIfPlan | Should -Not -BeNullOrEmpty
        $Writes = @($script:Recorded | Where-Object { $_.Method -ne 'GET' })
        $Writes.Count | Should -Be 0
    }

    It 'refuses ExecAzDelete without matching managedBy/ticket tags' {
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            $script:Recorded.Add([pscustomobject]@{ Method = $Method; Uri = $Uri })
            return @{
                id   = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-example-demo/providers/Microsoft.Storage/storageAccounts/stpreexisting'
                tags = @{ managedBy = 'other'; ticket = '9999999' }
            }
        }
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAzDelete' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter      = 'contoso.onmicrosoft.com'
                ticketNumber      = '1234567'
                reason            = 'rollback'
                resourceGroupName = 'rg-example-demo'
                resourceId        = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-example-demo/providers/Microsoft.Storage/storageAccounts/stpreexisting'
                dryRun            = $true
            }
        }
        $Response = Invoke-CIPPAzArmWriteAction -Action 'ExecAzDelete' -Request $Request -Transport $Transport
        $Response.StatusCode | Should -Be 403
        $Response.Body.Results | Should -Match 'managedBy=manage365'
        $Deletes = @($script:Recorded | Where-Object { $_.Method -eq 'DELETE' })
        $Deletes.Count | Should -Be 0
    }

    It 'requires ticket and reason' {
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecAzIdentity' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                dryRun       = $false
            }
        }
        $Response = Invoke-CIPPAzArmWriteAction -Action 'ExecAzIdentity' -Request $Request
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -Match 'ticketNumber'
    }

    It 'ListAzWebAppSettingNames returns names and KV refs only' {
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            $script:Recorded.Add([pscustomobject]@{ Method = $Method; Uri = $Uri })
            $Uri | Should -Match 'appsettings/list'
            return @{
                properties = @{
                    WEBSITE_RUN_FROM_PACKAGE = '1'
                    SECRET_THING             = 'super-secret-value'
                    AppSecret                = '@Microsoft.KeyVault(VaultName=kv-example;SecretName=app-secret)'
                }
            }
        }
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ListAzWebAppSettingNames' }
            Headers = @{}
            Body    = [pscustomobject]@{
                tenantFilter      = 'contoso.onmicrosoft.com'
                ticketNumber      = '1234567'
                reason            = 'list setting names'
                resourceGroupName = 'rg-example-demo'
                name              = 'func-example'
            }
        }
        $Response = Invoke-CIPPAzArmWriteAction -Action 'ListAzWebAppSettingNames' -Request $Request -Transport $Transport
        $Response.StatusCode | Should -Be 200
        $Response.Body.Results.Names | Should -Contain 'SECRET_THING'
        $Response.Body.Results.KeyVaultReferences.AppSecret | Should -Match 'KeyVault'
        ($Response | ConvertTo-Json -Depth 6) | Should -Not -Match 'super-secret-value'
    }
}
