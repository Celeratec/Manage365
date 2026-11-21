BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Private/Resolve-CIPPGuardedWriteConfigPath.ps1')
    foreach ($Name in @(
            'Test-CIPPAzArmSegment',
            'Get-CIPPAzArmReadPlan',
            'Invoke-CIPPAzArmRequest',
            'Get-CIPPAzArmTenantConfig',
            'Set-CIPPAzArmTenantConfig',
            'Get-CIPPAzArmAccessToken',
            'Invoke-CIPPAzArmListAction'
        )) {
        . (Join-Path $RepoRoot "Modules/CIPPCore/Public/AzureArm/$Name.ps1")
    }

    enum HttpStatusCode {
        OK = 200
        BadRequest = 400
        Forbidden = 403
        BadGateway = 502
        ServiceUnavailable = 503
    }
    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
        [hashtable]$Headers
    }

    $script:Allowlist = Get-Content (Join-Path $RepoRoot 'Config/GuardedWrites/AzureArmReadAllowlist.json') -Raw | ConvertFrom-Json
    $script:Config = [pscustomobject]@{
        TenantFilter          = 'contoso.onmicrosoft.com'
        Mode                  = 'servicePrincipal'
        SubscriptionId        = '11111111-1111-1111-1111-111111111111'
        AllowedResourceGroups = @('rg-example-demo')
        Profiles              = @{
            reader = @{ appId = '22222222-2222-2222-2222-222222222222'; clientSecretName = 'arm-reader-secret' }
        }
        Enabled               = $true
        ChangeWindow          = $null
        Notes                 = ''
        ManagingTenantId      = ''
    }
    $script:Recorded = [System.Collections.Generic.List[object]]::new()
}

Describe 'Test-CIPPAzArmSegment' {
    It 'accepts GUID and resource group names' {
        Test-CIPPAzArmSegment -Value '11111111-1111-1111-1111-111111111111' -Kind guid | Should -BeTrue
        Test-CIPPAzArmSegment -Value 'rg-example-demo' -Kind resourceGroup | Should -BeTrue
    }
    It 'rejects traversal and schemes' {
        Test-CIPPAzArmSegment -Value '../etc' -Kind resourceGroup | Should -BeFalse
        Test-CIPPAzArmSegment -Value 'https://evil' -Kind resourceName | Should -BeFalse
        Test-CIPPAzArmSegment -Value 'a/b' -Kind resourceGroup | Should -BeFalse
    }
}

Describe 'Get-CIPPAzArmReadPlan' {
    It 'builds a pinned subscription path' {
        $Plan = Get-CIPPAzArmReadPlan -Action 'ListAzProviders' -Config $script:Config -Params @{} -Allowlist $script:Allowlist
        $Plan.Allowed | Should -BeTrue
        $Plan.Path | Should -Be '/subscriptions/11111111-1111-1111-1111-111111111111/providers'
        $Plan.Method | Should -Be 'GET'
        $Plan.Profile | Should -Be 'reader'
    }
    It 'requires resource group for RG-scoped actions and pins allowlist' {
        $Missing = Get-CIPPAzArmReadPlan -Action 'ListAzResources' -Config $script:Config -Params @{} -Allowlist $script:Allowlist
        $Missing.Allowed | Should -BeFalse
        $Bad = Get-CIPPAzArmReadPlan -Action 'ListAzResources' -Config $script:Config -Params @{ resourceGroupName = 'rg-other' } -Allowlist $script:Allowlist
        $Bad.Allowed | Should -BeFalse
        $Ok = Get-CIPPAzArmReadPlan -Action 'ListAzResources' -Config $script:Config -Params @{ resourceGroupName = 'rg-example-demo' } -Allowlist $script:Allowlist
        $Ok.Allowed | Should -BeTrue
        $Ok.Path | Should -Match 'rg-example-demo'
    }
    It 'rejects unknown actions' {
        (Get-CIPPAzArmReadPlan -Action 'ListAzHack' -Config $script:Config -Params @{} -Allowlist $script:Allowlist).Allowed | Should -BeFalse
    }
}

Describe 'Invoke-CIPPAzArmRequest' {
    BeforeEach { $script:Recorded = [System.Collections.Generic.List[object]]::new() }

    It 'rejects deny-listed paths and non-management hosts via nextLink' {
        { Invoke-CIPPAzArmRequest -AccessToken 'tok' -Method GET -Path '/subscriptions/x/listKeys' -ApiVersion '2023-05-01' -Classification read } | Should -Throw '*deny-listed*'
    }

    It 'refuses GET with write classification' {
        { Invoke-CIPPAzArmRequest -AccessToken 'tok' -Method GET -Path '/subscriptions' -ApiVersion '2022-12-01' -Classification write } | Should -Throw '*not allowed for ARM writes*'
    }

    It 'paginates with a hard page cap and only management.azure.com' {
        $Pages = @{ n = 0 }
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            $script:Recorded.Add([pscustomobject]@{ Method = $Method; Uri = $Uri })
            $Uri | Should -Match '^https://management\.azure\.com'
            $Headers.Authorization | Should -Match '^Bearer '
            $Pages.n++
            if ($Pages.n -lt 3) {
                return @{ value = @(@{ id = $Pages.n }); nextLink = "https://management.azure.com/subscriptions?api-version=2022-12-01&`$skiptoken=$($Pages.n)" }
            }
            return @{ value = @(@{ id = $Pages.n }) }
        }
        $Result = Invoke-CIPPAzArmRequest -AccessToken 'tok' -Method GET -Path '/subscriptions' -ApiVersion '2022-12-01' -Classification read -Transport $Transport -MaxPages 5
        $Result.Results.Count | Should -Be 3
        $script:Recorded.Count | Should -Be 3
    }

    It 'throws when a non-allowlisted write-like URI is forced through deny list' {
        { Invoke-CIPPAzArmRequest -AccessToken 'tok' -Method POST -Path '/subscriptions/x/providers/Microsoft.Storage/storageAccounts/a/listKeys' -ApiVersion '2023-05-01' -Classification read } | Should -Throw '*deny-listed*'
    }
}

Describe 'Get-CIPPAzArmAccessToken guards' {
    It 'refuses the SAM application id' {
        $env:ApplicationID = '22222222-2222-2222-2222-222222222222'
        { Get-CIPPAzArmAccessToken -TenantFilter 'contoso.onmicrosoft.com' -Profile reader -Config $script:Config } | Should -Throw '*SAM*'
        $env:ApplicationID = $null
    }
    It 'fails closed when profile is missing' {
        $Cfg = $script:Config | Select-Object *
        $Cfg.Profiles = @{ change = @{ appId = '33333333-3333-3333-3333-333333333333'; clientSecretName = 'x' } }
        { Get-CIPPAzArmAccessToken -TenantFilter 'contoso.onmicrosoft.com' -Profile reader -Config $Cfg } | Should -Throw '*reader*'
    }
}

Describe 'AzureArm feature flag' {
    It 'ships disabled and names ListAz endpoints' {
        $Flags = Get-Content (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) 'Config/FeatureFlags.json') -Raw | ConvertFrom-Json
        $Flag = $Flags | Where-Object { $_.Id -eq 'AzureArm' }
        $Flag.Enabled | Should -BeFalse
        $Flag.Endpoints | Should -Contain 'ListAzSubscriptions'
        $Flag.Endpoints | Should -Contain 'ExecAzArmConfig'
        $Flag.Endpoints | Should -Contain 'ListAzWebAppSettingNames'
        $Flag.Endpoints | Should -Contain 'ExecAzStorageAccount'
        $Flag.Endpoints | Should -Contain 'ExecAzDelete'
    }
}

Describe 'Invoke-CIPPAzArmListAction' {
    BeforeAll {
        function Get-CIPPAzArmTenantConfig { $script:Config }
        function Get-CIPPAzArmAccessToken {
            [pscustomobject]@{ AccessToken = 'tok'; AppId = '22222222-2222-2222-2222-222222222222'; Mode = 'servicePrincipal'; Profile = 'reader'; TenantId = 't' }
        }
    }

    It 'returns sanitized local config without calling ARM' {
        $Response = Invoke-CIPPAzArmListAction -Action 'ListAzArmConfig' -Request @{ Body = @{ tenantFilter = 'contoso.onmicrosoft.com' } }
        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Results.SubscriptionId | Should -Be '11111111-1111-1111-1111-111111111111'
        $Response.Body.Results.PSObject.Properties.Name | Should -Not -Contain 'Profiles'
    }

    It 'lists providers through the transport and records only allowlisted GETs' {
        $script:Recorded = [System.Collections.Generic.List[object]]::new()
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            if ($Method -ne 'GET') { throw "Unexpected write method $Method for $Uri" }
            if ($Uri -notmatch 'management\.azure\.com') { throw "Bad host $Uri" }
            if ($Uri -match 'listKeys|listSecrets|config/list') { throw "Deny hit $Uri" }
            $script:Recorded.Add($Uri)
            return @{ value = @(@{ namespace = 'Microsoft.Web'; registrationState = 'Registered' }) }
        }
        $Response = Invoke-CIPPAzArmListAction -Action 'ListAzProviders' -Request @{ Body = @{ tenantFilter = 'contoso.onmicrosoft.com' } } -Transport $Transport
        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Results.Count | Should -Be 1
        $script:Recorded.Count | Should -Be 1
    }
}
