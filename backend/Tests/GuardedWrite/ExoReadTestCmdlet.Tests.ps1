BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Private/Resolve-CIPPGuardedWriteConfigPath.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Private/Test-CIPPExoParameterName.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Get-CIPPExoReadTestCmdletPlan.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GuardedWrite/Get-CIPPExoAllowlistedCmdletPlan.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Tools/Invoke-ListExoRequest.ps1')

    function Get-NormalizedError { param($Message) $Message }
    enum HttpStatusCode {
        OK = 200
        BadRequest = 400
        Forbidden = 403
        InternalServerError = 500
    }
    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
        [hashtable]$Headers
    }

    $script:LastExoParams = $null
    $script:AllowedPermissions = @('CIPP.Core.Read', 'Tenant.AppGovernance.Read')
    $script:ExoResults = @(
        [pscustomobject]@{ RoleName = 'Application Mail.Read'; ScopeType = 'Recipient'; InScope = $true }
    )
    $script:AuditCalled = $false

    function Get-CippRequestAllowedPermissions { return @($script:AllowedPermissions) }
    function New-ExoRequest {
        param(
            $Cmdlet,
            $cmdParams,
            $tenantid,
            $useSystemMailbox,
            $Select,
            $Anchor,
            $Compliance,
            $AsApp,
            $AvailableCmdlets
        )
        $script:LastExoParams = @{
            Cmdlet           = $Cmdlet
            cmdParams        = $cmdParams
            tenantid         = $tenantid
            useSystemMailbox = $useSystemMailbox
            AvailableCmdlets = $AvailableCmdlets
        }
        if ($AvailableCmdlets) { return @('Get-Mailbox') }
        return $script:ExoResults
    }
    function Add-CIPPGuardedWriteAudit {
        $script:AuditCalled = $true
        return 'audit-id'
    }
}

Describe 'Test-CIPPExoParameterName' {
    It 'accepts ASCII letter then letters or digits' {
        Test-CIPPExoParameterName -Name 'Identity' | Should -BeTrue
        Test-CIPPExoParameterName -Name 'AppId' | Should -BeTrue
        Test-CIPPExoParameterName -Name 'CustomAttribute1' | Should -BeTrue
    }

    It 'rejects names with punctuation or leading digits' {
        Test-CIPPExoParameterName -Name '1Identity' | Should -BeFalse
        Test-CIPPExoParameterName -Name 'App-Id' | Should -BeFalse
        Test-CIPPExoParameterName -Name 'App_Id' | Should -BeFalse
        Test-CIPPExoParameterName -Name '' | Should -BeFalse
    }
}

Describe 'Get-CIPPExoReadTestCmdletPlan' {
    It 'accepts Test-ServicePrincipalAuthorization with GUID Identity and Resource' {
        $Plan = Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ServicePrincipalAuthorization' -Parameters @{
            Identity = '11111111-1111-1111-1111-111111111111'
            Resource = 'user@contoso.com'
        }
        $Plan.Allowed | Should -BeTrue
        $Plan.Parameters.Identity | Should -Be '11111111-1111-1111-1111-111111111111'
        $Plan.Parameters.Resource | Should -Be 'user@contoso.com'
    }

    It 'accepts Test-ApplicationAccessPolicy with recipient Identity and GUID AppId' {
        $Plan = Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ApplicationAccessPolicy' -Parameters @{
            Identity = 'user@contoso.com'
            AppId    = '22222222-2222-2222-2222-222222222222'
        }
        $Plan.Allowed | Should -BeTrue
    }

    It 'rejects any other Test-* cmdlet' {
        $Plan = Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-MailFlow' -Parameters @{ Identity = 'x' }
        $Plan.Allowed | Should -BeFalse
        $Plan.Reason | Should -Match 'allowlist'
    }

    It 'rejects extra or misspelled parameters' {
        (Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ServicePrincipalAuthorization' -Parameters @{
                Identity = '11111111-1111-1111-1111-111111111111'
                Resource = 'user@contoso.com'
                Extra    = 'no'
            }).Allowed | Should -BeFalse
        (Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ApplicationAccessPolicy' -Parameters @{
                Identity = 'user@contoso.com'
                AppID    = '22222222-2222-2222-2222-222222222222'
            }).Allowed | Should -BeTrue
        (Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ApplicationAccessPolicy' -Parameters @{
                Identity = 'user@contoso.com'
                AppIdx   = '22222222-2222-2222-2222-222222222222'
            }).Allowed | Should -BeFalse
    }

    It 'rejects missing Resource, non-GUID Identity on SPA, wildcards, and arrays' {
        (Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ServicePrincipalAuthorization' -Parameters @{
                Identity = '11111111-1111-1111-1111-111111111111'
            }).Allowed | Should -BeFalse
        (Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ServicePrincipalAuthorization' -Parameters @{
                Identity = 'MyAppDisplayName'
                Resource = 'user@contoso.com'
            }).Allowed | Should -BeFalse
        (Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ServicePrincipalAuthorization' -Parameters @{
                Identity = '11111111-1111-1111-1111-111111111111'
                Resource = 'user*@contoso.com'
            }).Allowed | Should -BeFalse
        (Get-CIPPExoReadTestCmdletPlan -Cmdlet 'Test-ServicePrincipalAuthorization' -Parameters @{
                Identity = @('11111111-1111-1111-1111-111111111111')
                Resource = 'user@contoso.com'
            }).Allowed | Should -BeFalse
    }

    It 'still validates write allowlist param names via shared helper' {
        (Get-CIPPExoAllowlistedCmdletPlan -Cmdlet 'Remove-ServicePrincipal' -Parameters @{
                Identity = 'sp'
                'Bad-Name' = 'x'
            }).Allowed | Should -BeFalse
    }
}

Describe 'Invoke-ListExoRequest Test path' {
    BeforeEach {
        $script:LastExoParams = $null
        $script:AllowedPermissions = @('CIPP.Core.Read', 'Tenant.AppGovernance.Read')
        $script:AuditCalled = $false
        $script:ExoResults = @(
            [pscustomobject]@{ RoleName = 'Application Mail.Read'; ScopeType = 'Recipient'; InScope = $true }
        )
    }

    It 'runs SPA through New-ExoRequest with useSystemMailbox and no audit' {
        $Request = @{
            Body = @{
                TenantFilter = 'contoso.onmicrosoft.com'
                Cmdlet       = 'Test-ServicePrincipalAuthorization'
                cmdParams    = @{
                    Identity = '11111111-1111-1111-1111-111111111111'
                    Resource = 'user@contoso.com'
                }
            }
        }
        $Response = Invoke-ListExoRequest -Request $Request -TriggerMetadata @{}
        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $script:LastExoParams.useSystemMailbox | Should -BeTrue
        $script:LastExoParams.Cmdlet | Should -Be 'Test-ServicePrincipalAuthorization'
        $script:AuditCalled | Should -BeFalse
        $Parsed = $Response.Body | ConvertFrom-Json
        $Parsed.Meta.OrganizationScopedGrant | Should -BeFalse
    }

    It 'sets OrganizationScopedGrant when a row has ScopeType Organization' {
        $script:ExoResults = @(
            [pscustomobject]@{ RoleName = 'Application Mail.Read'; ScopeType = 'Organization'; InScope = $true }
        )
        $Request = @{
            Body = @{
                TenantFilter = 'contoso.onmicrosoft.com'
                Cmdlet       = 'Test-ServicePrincipalAuthorization'
                cmdParams    = @{
                    Identity = '11111111-1111-1111-1111-111111111111'
                    Resource = 'user@contoso.com'
                }
            }
        }
        $Parsed = (Invoke-ListExoRequest -Request $Request -TriggerMetadata @{}).Body | ConvertFrom-Json
        $Parsed.Meta.OrganizationScopedGrant | Should -BeTrue
    }

    It 'refuses Test path without Tenant.AppGovernance.Read' {
        $script:AllowedPermissions = @('CIPP.Core.Read')
        $Request = @{
            Body = @{
                TenantFilter = 'contoso.onmicrosoft.com'
                Cmdlet       = 'Test-ServicePrincipalAuthorization'
                cmdParams    = @{
                    Identity = '11111111-1111-1111-1111-111111111111'
                    Resource = 'user@contoso.com'
                }
            }
        }
        $Response = Invoke-ListExoRequest -Request $Request -TriggerMetadata @{}
        $Response.StatusCode | Should -Be ([HttpStatusCode]::Forbidden)
        $script:LastExoParams | Should -BeNullOrEmpty
    }

    It 'returns 400 for other Test-* cmdlets' {
        $Request = @{
            Body = @{
                TenantFilter = 'contoso.onmicrosoft.com'
                Cmdlet       = 'Test-MailFlow'
                cmdParams    = @{ Identity = 'x' }
            }
        }
        $Response = Invoke-ListExoRequest -Request $Request -TriggerMetadata @{}
        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
    }

    It 'leaves Get-* behavior unchanged (optional UseSystemMailbox)' {
        $Request = @{
            Body = @{
                TenantFilter = 'contoso.onmicrosoft.com'
                Cmdlet       = 'Get-Mailbox'
                cmdParams    = @{ Identity = 'user@contoso.com' }
            }
        }
        $Response = Invoke-ListExoRequest -Request $Request -TriggerMetadata @{}
        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $script:LastExoParams.Cmdlet | Should -Be 'Get-Mailbox'
        $script:LastExoParams.useSystemMailbox | Should -BeNullOrEmpty
    }
}
