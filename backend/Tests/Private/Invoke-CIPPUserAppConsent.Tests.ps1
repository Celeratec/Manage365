# User-scoped app consent. These endpoints create a service principal and a Principal
# oauth2PermissionGrant for named users. They never write an AllPrincipals grant.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $AppRoot = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Applications'

    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
    }
    $Accelerators = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not ('HttpStatusCode' -as [type])) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function New-GraphGetRequest { param($uri, $tenantid, $NoAuthCheck, $AsApp) }
    function New-GraphPOSTRequest { param($uri, $tenantid, $type, $body, $NoAuthCheck, $AsApp) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }

    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GraphHelper/Get-CIPPGraphErrorMessage.ps1')
    . (Join-Path $AppRoot 'ConvertTo-CIPPRequestValue.ps1')
    . (Join-Path $AppRoot 'Get-CIPPGraphFailure.ps1')
    . (Join-Path $AppRoot 'Get-CIPPAppConsentContext.ps1')
    . (Join-Path $AppRoot 'Invoke-CIPPServicePrincipalAction.ps1')
    . (Join-Path $AppRoot 'Invoke-CIPPAppRoleAssignment.ps1')
    . (Join-Path $AppRoot 'Invoke-CIPPOAuth2PermissionGrant.ps1')
    . (Join-Path $AppRoot 'Invoke-CIPPAppConsentRequest.ps1')
    . (Join-Path $AppRoot 'Invoke-CIPPGrantAppToUsers.ps1')

    $EndpointRoot = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions'
    . (Join-Path $EndpointRoot 'CIPP/Core/Invoke-ExecServicePrincipals.ps1')
    . (Join-Path $EndpointRoot 'Tenant/Administration/Application Approval/Invoke-ExecAppRoleAssignment.ps1')
    . (Join-Path $EndpointRoot 'Tenant/Administration/Application Approval/Invoke-ExecOAuth2PermissionGrant.ps1')
    . (Join-Path $EndpointRoot 'Tenant/Administration/Application Approval/Invoke-ExecAppConsentRequest.ps1')
    . (Join-Path $EndpointRoot 'Tenant/Administration/Application Approval/Invoke-ExecGrantAppToUsers.ps1')

    $script:AppId = '11111111-1111-1111-1111-111111111111'
    $script:UserId = '22222222-2222-2222-2222-222222222222'
    $script:GraphAppId = '00000003-0000-0000-c000-000000000000'
    $script:DefaultRole = '00000000-0000-0000-0000-000000000000'
    $script:Caller = 'caller@contoso.com'
    $script:Principal = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"userDetails":"caller@contoso.com"}'))

    function New-ConsentRequest {
        param([hashtable]$Body = @{}, [hashtable]$Query = @{})
        [pscustomobject]@{
            Body    = [pscustomobject]$Body
            Query   = $Query
            Headers = @{ 'x-ms-client-principal' = $script:Principal }
            Params  = @{ CIPPEndpoint = 'ExecGrantAppToUsers' }
        }
    }
}

Describe 'user-scoped app consent' {
    BeforeEach {
        $script:Gets = [System.Collections.Generic.List[string]]::new()
        $script:Posts = [System.Collections.Generic.List[object]]::new()
        $script:ClientSp = $null
        $script:Assignments = @()
        $script:Grants = @()
        $script:Stages = @([pscustomobject]@{ id = 'stage-1'; status = 'InProgress'; assignedToMe = $true })
        $script:V1StagesMissing = $false
        $script:Me = [pscustomobject]@{ id = '33333333-3333-3333-3333-333333333333' }
        $script:ConsentPolicy = [pscustomobject]@{
            isEnabled             = $false
            notifyReviewers       = $false
            remindersEnabled      = $true
            requestDurationInDays = 14
            reviewers             = @([pscustomobject]@{ query = '/users/existing-reviewer'; queryType = 'MicrosoftGraph' })
        }

        Mock Write-LogMessage {}
        Mock New-GraphGetRequest {
            $script:Gets.Add([string]$uri)
            if ($uri -match 'expand=stages') {
                if ($uri -match 'graph\.microsoft\.com/v1\.0/' -and $script:V1StagesMissing) {
                    return [pscustomobject]@{ id = 'approval-1' }
                }
                return [pscustomobject]@{ stages = @($script:Stages) }
            }
            if ($uri -match '/me\?') { return $script:Me }
            if ($uri -match 'adminConsentRequestPolicy') { return $script:ConsentPolicy }
            if ($uri -match [regex]::Escape($script:GraphAppId) -or $uri -match 'servicePrincipals/graph-sp') {
                return [pscustomobject]@{
                    id                     = 'graph-sp'
                    appId                  = $script:GraphAppId
                    oauth2PermissionScopes = @(
                        [pscustomobject]@{ value = 'User.Read' }
                        [pscustomobject]@{ value = 'Mail.Read' }
                    )
                }
            }
            if ($uri -match 'oauth2PermissionGrants') { return @($script:Grants) }
            if ($uri -match 'appRoleAssignedTo') { return @($script:Assignments) }
            if ($uri -match 'servicePrincipals') { return $script:ClientSp }
            return $null
        }
        Mock New-GraphPOSTRequest {
            $script:Posts.Add([pscustomobject]@{
                    Uri    = [string]$uri
                    Type   = [string]$type
                    Body   = [string]$body
                    Tenant = [string]$tenantid
                    NoAuth = [bool]$NoAuthCheck
                })
            if ($uri -match '/servicePrincipals$' -and $type -eq 'POST') {
                return [pscustomobject]@{ id = 'sp-new'; appId = $script:AppId; displayName = 'Contoso App'; appRoleAssignmentRequired = $true }
            }
            if ($uri -match 'appRoleAssignedTo$' -and $type -eq 'POST') {
                return [pscustomobject]@{ id = 'assign-new'; principalId = $script:UserId }
            }
            if ($uri -match '/oauth2PermissionGrants$' -and $type -eq 'POST') {
                return [pscustomobject]@{ id = 'grant-new'; consentType = 'Principal'; scope = 'User.Read' }
            }
            return [pscustomobject]@{ id = 'patched' }
        }
    }

    It 'creates a service principal in the customer tenant and does not grant consent' {
        $Result = Invoke-CIPPServicePrincipalAction -TenantFilter 'contoso.onmicrosoft.com' -Action Create -AppId $script:AppId -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecServicePrincipals'
        $Result.ServicePrincipal.id | Should -Be 'sp-new'
        $Result.Created | Should -BeTrue
        $script:Posts.Count | Should -Be 1
        $script:Posts[0].Uri | Should -Be 'https://graph.microsoft.com/v1.0/servicePrincipals'
        $script:Posts[0].Tenant | Should -Be 'contoso.onmicrosoft.com'
        $script:Posts[0].NoAuth | Should -BeFalse
        ($script:Posts[0].Body | ConvertFrom-Json).appId | Should -Be $script:AppId
        $script:Posts.Uri -join ' ' | Should -Not -Match 'oauth2PermissionGrant'
    }

    It 'patches appRoleAssignmentRequired and does not grant consent' {
        $script:ClientSp = [pscustomobject]@{ id = 'sp-1'; appId = $script:AppId; appRoleAssignmentRequired = $false }
        $Result = Invoke-CIPPServicePrincipalAction -TenantFilter 'contoso.onmicrosoft.com' -Action Update -AppId $script:AppId -AppRoleAssignmentRequired $true -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecServicePrincipals'
        $Result.ServicePrincipal.id | Should -Be 'sp-1'
        $script:Posts[0].Type | Should -Be 'PATCH'
        $script:Posts[0].Uri | Should -Be 'https://graph.microsoft.com/v1.0/servicePrincipals/sp-1'
        ($script:Posts[0].Body | ConvertFrom-Json).appRoleAssignmentRequired | Should -BeTrue
        $script:Posts.Uri -join ' ' | Should -Not -Match 'oauth2PermissionGrant'
    }

    It 'assigns a user with the default app role' {
        $Result = Invoke-CIPPAppRoleAssignment -TenantFilter 'contoso.onmicrosoft.com' -Action Add -ServicePrincipalId 'sp-1' -PrincipalId $script:UserId -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecAppRoleAssignment'
        $Result.Assignment.id | Should -Be 'assign-new'
        $Body = $script:Posts[0].Body | ConvertFrom-Json
        $Body.principalId | Should -Be $script:UserId
        $Body.resourceId | Should -Be 'sp-1'
        $Body.appRoleId | Should -Be $script:DefaultRole
        $script:Posts[0].Tenant | Should -Be 'contoso.onmicrosoft.com'
    }

    It 'creates a Principal grant for the requested scopes' {
        $Result = Invoke-CIPPOAuth2PermissionGrant -TenantFilter 'contoso.onmicrosoft.com' -Action Add -ServicePrincipalId 'sp-1' -PrincipalId $script:UserId -Scope 'Mail.Read User.Read' -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecOAuth2PermissionGrant'
        $Result.Grant.id | Should -Be 'grant-new'
        $Body = $script:Posts[0].Body | ConvertFrom-Json
        $Body.consentType | Should -Be 'Principal'
        $Body.clientId | Should -Be 'sp-1'
        $Body.principalId | Should -Be $script:UserId
        $Body.resourceId | Should -Be 'graph-sp'
        $Body.scope | Should -Be 'Mail.Read User.Read'
    }

    It 'rejects an AllPrincipals grant' {
        { Invoke-CIPPOAuth2PermissionGrant -TenantFilter 'contoso.onmicrosoft.com' -Action Add -ServicePrincipalId 'sp-1' -PrincipalId $script:UserId -ConsentType 'AllPrincipals' -Scope 'User.Read' -Headers @{} -APIName 'ExecOAuth2PermissionGrant' } |
            Should -Throw '*AllPrincipals*' -ExceptionType ([System.ArgumentException])
        $script:Posts.Count | Should -Be 0
    }

    It 'rejects a scope the resource service principal does not publish' {
        { Invoke-CIPPOAuth2PermissionGrant -TenantFilter 'contoso.onmicrosoft.com' -Action Add -ServicePrincipalId 'sp-1' -PrincipalId $script:UserId -Scope 'User.Read NotAScope' -Headers @{} -APIName 'ExecOAuth2PermissionGrant' } |
            Should -Throw '*NotAScope*' -ExceptionType ([System.ArgumentException])
        $script:Posts.Count | Should -Be 0
    }

    It 'reuses an existing service principal, assignment, and grant, and merges scopes' {
        $script:ClientSp = [pscustomobject]@{ id = 'sp-1'; appId = $script:AppId; displayName = 'Contoso App'; appRoleAssignmentRequired = $true }
        $script:Assignments = @([pscustomobject]@{ id = 'assign-1'; principalId = $script:UserId; resourceId = 'sp-1' })
        $script:Grants = @([pscustomobject]@{ id = 'grant-1'; consentType = 'Principal'; principalId = $script:UserId; resourceId = 'graph-sp'; scope = 'User.Read' })

        $Result = Invoke-CIPPGrantAppToUsers -TenantFilter 'contoso.onmicrosoft.com' -AppId $script:AppId -UserIds @($script:UserId) -Scopes @('Mail.Read') -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecGrantAppToUsers'

        $Result.ServicePrincipal.id | Should -Be 'sp-1'
        @($script:Posts | Where-Object { $_.Uri -eq 'https://graph.microsoft.com/v1.0/servicePrincipals' -and $_.Type -eq 'POST' }).Count | Should -Be 0
        @($script:Posts | Where-Object { $_.Uri -match 'appRoleAssignedTo$' -and $_.Type -eq 'POST' }).Count | Should -Be 0
        $Patch = @($script:Posts | Where-Object { $_.Uri -eq 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants/grant-1' -and $_.Type -eq 'PATCH' })
        $Patch.Count | Should -Be 1
        ($Patch[0].Body | ConvertFrom-Json).scope | Should -Be 'Mail.Read User.Read'
        $Result.Created.servicePrincipalId | Should -BeNullOrEmpty
        $Result.Created.grantIds | Should -BeNullOrEmpty
        $script:Posts.Body -join ' ' | Should -Not -Match 'AllPrincipals'
    }

    It 'returns the ids it created so they can be removed' {
        $Result = Invoke-CIPPGrantAppToUsers -TenantFilter 'contoso.onmicrosoft.com' -AppId $script:AppId -UserIds @($script:UserId) -Scopes @('User.Read') -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecGrantAppToUsers'
        $Result.Created.servicePrincipalId | Should -Be 'sp-new'
        $Result.Created.appRoleAssignmentIds | Should -Be @('assign-new')
        $Result.Created.grantIds | Should -Be @('grant-new')

        $null = Invoke-CIPPAppRoleAssignment -TenantFilter 'contoso.onmicrosoft.com' -Action Remove -ServicePrincipalId 'sp-new' -AssignmentId 'assign-new' -Headers @{} -APIName 'ExecAppRoleAssignment'
        $null = Invoke-CIPPOAuth2PermissionGrant -TenantFilter 'contoso.onmicrosoft.com' -Action Remove -GrantId 'grant-new' -Headers @{} -APIName 'ExecOAuth2PermissionGrant'
        @($script:Posts | Where-Object { $_.Type -eq 'DELETE' -and $_.Uri -match 'appRoleAssignedTo/assign-new$' }).Count | Should -Be 1
        @($script:Posts | Where-Object { $_.Type -eq 'DELETE' -and $_.Uri -eq 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants/grant-new' }).Count | Should -Be 1
    }

    It 'approves a consent request without granting admin consent' {
        $Result = Invoke-CIPPAppConsentRequest -TenantFilter 'contoso.onmicrosoft.com' -Action Approve -AppConsentRequestId 'app-req' -UserConsentRequestId 'user-req' -Justification 'Approved for one user' -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecAppConsentRequest'
        $Result.ReviewResult | Should -Be 'Approve'
        $Result.AdminConsentGranted | Should -BeFalse
        $script:Gets -join ' ' | Should -Match 'v1\.0/identityGovernance/appConsent/appConsentRequests/app-req/userConsentRequests/user-req/approval\?\$expand=stages'
        @($script:Gets | Where-Object { $_ -match 'approval/stages(\?|$)' }).Count | Should -Be 0
        $script:Posts.Count | Should -Be 1
        $script:Posts[0].Type | Should -Be 'PATCH'
        $script:Posts[0].Uri | Should -Be 'https://graph.microsoft.com/v1.0/identityGovernance/appConsent/appConsentRequests/app-req/userConsentRequests/user-req/approval/stages/stage-1'
        ($script:Posts[0].Body | ConvertFrom-Json).reviewResult | Should -Be 'Approve'
        $script:Posts.Uri -join ' ' | Should -Not -Match 'oauth2PermissionGrant|adminConsent'
        Should -Invoke Write-LogMessage -Times 1 -ParameterFilter {
            $tenant -eq 'contoso.onmicrosoft.com' -and
            $message -match 'caller@contoso.com' -and
            $message -match 'app-req' -and
            $message -match 'user-req' -and
            $LogData.ReviewResult -eq 'Approve' -and
            $LogData.AppConsentRequestId -eq 'app-req' -and
            $LogData.UserConsentRequestId -eq 'user-req'
        }
    }

    It 'denies a consent request' {
        $null = Invoke-CIPPAppConsentRequest -TenantFilter 'contoso.onmicrosoft.com' -Action Deny -AppConsentRequestId 'app-req' -UserConsentRequestId 'user-req' -StageId 'stage-9' -Justification 'No' -Headers @{} -APIName 'ExecAppConsentRequest'
        ($script:Posts[0].Body | ConvertFrom-Json).reviewResult | Should -Be 'Deny'
        $script:Posts[0].Uri | Should -Match 'stages/stage-9$'
        $script:Gets -join ' ' | Should -Match 'expand=stages'
        $script:Posts.Uri -join ' ' | Should -Not -Match 'oauth2PermissionGrant'
    }

    It 'reads stages from beta when v1.0 does not return them' {
        $script:V1StagesMissing = $true
        $null = Invoke-CIPPAppConsentRequest -TenantFilter 'contoso.onmicrosoft.com' -Action Approve -AppConsentRequestId 'app-req' -UserConsentRequestId 'user-req' -Justification 'Approved for one user' -Headers @{} -APIName 'ExecAppConsentRequest'
        $script:Gets -join ' ' | Should -Match 'v1\.0/.+expand=stages'
        $script:Gets -join ' ' | Should -Match 'beta/.+expand=stages'
        $script:Posts[0].Uri | Should -Be 'https://graph.microsoft.com/beta/identityGovernance/appConsent/appConsentRequests/app-req/userConsentRequests/user-req/approval/stages/stage-1'
    }

    It 'rejects a consent request that has no approval stage' {
        $script:Stages = @()
        $script:V1StagesMissing = $true
        { Invoke-CIPPAppConsentRequest -TenantFilter 'contoso.onmicrosoft.com' -Action Deny -AppConsentRequestId 'app-req' -UserConsentRequestId 'user-req' -Justification 'No' -Headers @{} -APIName 'ExecAppConsentRequest' } |
            Should -Throw '*No approval stage*' -ExceptionType ([System.ArgumentException])
        $script:Gets -join ' ' | Should -Match 'v1\.0/.+expand=stages'
        $script:Gets -join ' ' | Should -Match 'beta/.+expand=stages'
        $script:Posts.Count | Should -Be 0
    }

    It 'closes a request it cannot review without granting admin consent' {
        $script:Stages = @([pscustomobject]@{ id = 'stage-1'; status = 'InProgress'; assignedToMe = $false })
        $Result = Invoke-CIPPAppConsentRequest -TenantFilter 'contoso.onmicrosoft.com' -Action Approve -AppConsentRequestId 'app-req' -UserConsentRequestId 'user-req' -Justification 'Approved for one user' -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecAppConsentRequest'
        $Result.ReviewResult | Should -Be 'Deny'
        $Result.AdminConsentGranted | Should -BeFalse
        $Result.RequestedAction | Should -Be 'Approve'
        $Puts = @($script:Posts | Where-Object { $_.Type -eq 'PUT' -and $_.Uri -eq 'https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy' })
        $Puts.Count | Should -Be 2
        $Added = $Puts[0].Body | ConvertFrom-Json
        $Added.isEnabled | Should -BeFalse
        $Added.notifyReviewers | Should -BeFalse
        $Added.remindersEnabled | Should -BeTrue
        $Added.requestDurationInDays | Should -Be 14
        @($Added.reviewers).Count | Should -Be 2
        @($Added.reviewers.query) | Should -Contain '/users/existing-reviewer'
        @($Added.reviewers.query) | Should -Contain '/users/33333333-3333-3333-3333-333333333333'
        $Restored = $Puts[1].Body | ConvertFrom-Json
        @($Restored.reviewers).Count | Should -Be 1
        $Restored.reviewers.query | Should -Be '/users/existing-reviewer'
        $Decision = @($script:Posts | Where-Object { $_.Type -eq 'PATCH' -and $_.Uri -match 'approval/stages/stage-1$' })
        $Decision.Count | Should -Be 1
        ($Decision[0].Body | ConvertFrom-Json).reviewResult | Should -Be 'Deny'
        ($Decision[0].Body | ConvertFrom-Json).justification | Should -Be 'Handled via per-user grant'
        $script:Posts.Body -join ' ' | Should -Not -Match 'AllPrincipals'
        $script:Posts.Uri -join ' ' | Should -Not -Match 'oauth2PermissionGrant'
        Should -Invoke Write-LogMessage -Times 1 -ParameterFilter {
            $tenant -eq 'contoso.onmicrosoft.com' -and
            $message -match 'caller@contoso.com' -and
            $LogData.AppConsentRequestId -eq 'app-req' -and
            $LogData.UserConsentRequestId -eq 'user-req' -and
            $LogData.ReviewResult -eq 'Deny'
        }
    }

    It 'returns the Graph status and error body when the stage decision is rejected' {
        Mock New-GraphPOSTRequest {
            $Exception = [System.Exception]::new('UnknownError')
            $Exception.Data['RawErrorBody'] = '{"error":{"code":"UnknownError","message":"","innerError":{"request-id":"req-1"}}}'
            $Exception.Data['StatusCode'] = 400
            throw $Exception
        }
        $Request = New-ConsentRequest -Body @{
            tenantFilter         = 'contoso.onmicrosoft.com'
            Action               = 'Approve'
            appConsentRequestId  = 'app-req'
            userConsentRequestId = 'user-req'
            justification        = 'Approved for one user'
        }
        $Request.Params.CIPPEndpoint = 'ExecAppConsentRequest'
        $Response = Invoke-ExecAppConsentRequest -Request $Request -TriggerMetadata $null
        [int]$Response.StatusCode | Should -Be 400
        [string]$Response.Body.Results | Should -Match 'UnknownError'
        [string]$Response.Body.Results | Should -Match 'req-1'
    }

    It 'logs the tenant, caller, app, users, scopes, and ids' {
        $null = Invoke-CIPPGrantAppToUsers -TenantFilter 'contoso.onmicrosoft.com' -AppId $script:AppId -UserIds @($script:UserId) -Scopes @('User.Read') -Headers @{ 'x-ms-client-principal' = $script:Principal } -APIName 'ExecGrantAppToUsers'
        Should -Invoke Write-LogMessage -Times 1 -ParameterFilter {
            $tenant -eq 'contoso.onmicrosoft.com' -and
            $message -match 'caller@contoso.com' -and
            $message -match $script:AppId -and
            $message -match $script:UserId -and
            $message -match 'User.Read' -and
            $LogData.Caller -eq 'caller@contoso.com' -and
            $LogData.GrantIds -contains 'grant-new'
        }
    }

    It 'surfaces the Graph status and message' {
        Mock New-GraphPOSTRequest { throw 'Graph said no' }
        $ErrorRecord = $null
        try { $null = Invoke-CIPPServicePrincipalAction -TenantFilter 'contoso.onmicrosoft.com' -Action Create -AppId $script:AppId -Headers @{} -APIName 'ExecServicePrincipals' }
        catch { $ErrorRecord = $_ }
        $Failure = Get-CIPPGraphFailure -ErrorRecord $ErrorRecord
        $Failure.Message | Should -Match 'Graph said no'
    }
}

Describe 'ExecServicePrincipals tenantFilter' {
    BeforeEach {
        Mock Write-LogMessage {}
        Mock Invoke-CIPPServicePrincipalAction { [pscustomobject]@{ ServicePrincipal = [pscustomobject]@{ id = 'sp-new'; displayName = 'Contoso App'; appId = $script:AppId }; Created = $true } }
    }

    It 'sends Action=Create to the customer tenant from tenantFilter' {
        $Request = New-ConsentRequest -Query @{ Action = 'Create'; AppId = $script:AppId; tenantFilter = 'contoso.onmicrosoft.com' }
        $Request.Params.CIPPEndpoint = 'ExecServicePrincipals'
        $Response = Invoke-ExecServicePrincipals -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        Should -Invoke Invoke-CIPPServicePrincipalAction -Times 1 -ParameterFilter { $TenantFilter -eq 'contoso.onmicrosoft.com' -and $Action -eq 'Create' -and $AppId -eq $script:AppId }
    }

    It 'requires tenantFilter for Update' {
        $Request = New-ConsentRequest -Query @{ Action = 'Update'; AppId = $script:AppId; appRoleAssignmentRequired = 'true' }
        $Request.Params.CIPPEndpoint = 'ExecServicePrincipals'
        $Response = Invoke-ExecServicePrincipals -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        Should -Invoke Invoke-CIPPServicePrincipalAction -Times 0 -Exactly
    }
}

Describe 'consent endpoints reject a missing tenant and AllPrincipals' {
    BeforeEach { Mock Write-LogMessage {} }

    It 'returns 400 from ExecOAuth2PermissionGrant for AllPrincipals and does not call Graph' {
        Mock New-GraphPOSTRequest {}
        $Request = New-ConsentRequest -Body @{
            tenantFilter       = 'contoso.onmicrosoft.com'
            Action             = 'Add'
            ServicePrincipalId = 'sp-1'
            PrincipalId        = $script:UserId
            ConsentType        = 'AllPrincipals'
            Scope              = 'User.Read'
        }
        $Request.Params.CIPPEndpoint = 'ExecOAuth2PermissionGrant'
        $Response = Invoke-ExecOAuth2PermissionGrant -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        [string]$Response.Body.Results | Should -Match 'AllPrincipals'
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'returns 400 when ExecGrantAppToUsers has no tenantFilter' {
        $Request = New-ConsentRequest -Body @{ appId = $script:AppId; userIds = @($script:UserId); scopes = @('User.Read') }
        $Response = Invoke-ExecGrantAppToUsers -Request $Request -TriggerMetadata $null
        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        [string]$Response.Body.Results | Should -Match 'tenantFilter'
    }
}

Describe 'SAM manifest includes the user-consent permissions' {
    It 'declares the Graph application and delegated permissions these endpoints need' {
        $Manifest = Get-Content (Join-Path $RepoRoot 'Config/SAMManifest.json') -Raw | ConvertFrom-Json
        $Graph = $Manifest.requiredResourceAccess | Where-Object { $_.resourceAppId -eq '00000003-0000-0000-c000-000000000000' }
        $Ids = @($Graph.resourceAccess | ForEach-Object { $_.id })
        $Ids | Should -Contain '1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9' # Application.ReadWrite.All (application)
        $Ids | Should -Contain '8e8e4742-1d95-4f68-9d56-6ee75648c72a' # DelegatedPermissionGrant.ReadWrite.All (application)
        $Ids | Should -Contain '06b708a9-e830-4db3-a914-8e69da51d44f' # AppRoleAssignment.ReadWrite.All (application)
        $Ids | Should -Contain '9f1b81a7-0223-4428-bfa4-0bcb5535f27d' # ConsentRequest.ReadWrite.All (application)
        $Ids | Should -Contain '497d9dfa-3bd1-481a-baab-90895e54568c' # ConsentRequest.ReadWrite.All (delegated)
    }
}
