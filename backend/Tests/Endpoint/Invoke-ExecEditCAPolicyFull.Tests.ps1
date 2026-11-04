# Pester tests for Invoke-ExecEditCAPolicyFull
# The save is a PATCH, so what the body leaves out keeps whatever the tenant policy already had.
# These pin the two halves of that: emptied collections go out as [], and a condition block the
# editor emptied goes out as null rather than being dropped or sent half-populated.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Get-ChildItem -Path (Join-Path $RepoRoot 'Modules') -Recurse -Filter 'Invoke-ExecEditCAPolicyFull.ps1' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $FunctionPath) { throw 'Could not locate Invoke-ExecEditCAPolicyFull.ps1 under Modules/' }

    # The Functions worker exposes [HttpStatusCode] as an accelerator; register it for tests.
    ([PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')).GetMethod('Add').Invoke(
        $null, @('HttpStatusCode', [System.Net.HttpStatusCode]))

    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
    }

    # The canonicalizer is the real one - that is the behaviour under test.
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Functions/Format-CIPPCAPolicy.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/ConditionalAccess/Merge-CIPPCAPolicyUpdate.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/ConditionalAccess/Test-CIPPCAPolicyRemoval.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GraphHelper/Get-CIPPGraphErrorMessage.ps1')

    function New-GraphGetRequest {
        [CmdletBinding()] param($uri, $tenantid, $asApp, $noPagination)
        if ($script:CurrentPolicy) { return $script:CurrentPolicy }
        [pscustomobject]@{
            id              = 'policy-guid'
            displayName     = 'CA201'
            grantControls   = $null
            sessionControls = $null
            conditions      = [pscustomobject]@{
                users = [pscustomobject]@{ excludeUsers = @(); excludeGroups = @() }
            }
        }
    }
    function New-GraphPOSTRequest {
        [CmdletBinding()] param($uri, $tenantid, $type, $body, $asApp)
        $script:LastPatch = @{ Uri = $uri; Type = $type; Body = $body }
        if ($script:GraphErrorBody) {
            $Exception = [System.Exception]::new('Response status code does not indicate success: BadRequest')
            $Record = [System.Management.Automation.ErrorRecord]::new(
                $Exception,
                'GraphError',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            $Record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new([string]$script:GraphErrorBody)
            $Exception.Data['StatusCode'] = 400
            $Exception.Data['RawErrorBody'] = [string]$script:GraphErrorBody
            throw $Record
        }
    }
    function Write-LogMessage {
        [CmdletBinding()] param($API, $tenant, $headers, $message, $sev, $LogData)
        $script:LogMessage = $message
        $script:LogData = $LogData
    }
    function Get-CippException { [CmdletBinding()] param($Exception) $Exception }

    . $FunctionPath

    function Get-PolicyPropertyNames ($Node, [System.Collections.Generic.List[string]]$Names) {
        if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) { return }
        if ($Node -isnot [System.Management.Automation.PSCustomObject]) {
            foreach ($Item in @($Node)) { Get-PolicyPropertyNames -Node $Item -Names $Names }
            return
        }
        foreach ($Prop in @($Node.PSObject.Properties)) {
            $Names.Add($Prop.Name)
            Get-PolicyPropertyNames -Node $Prop.Value -Names $Names
        }
    }

    function Invoke-Edit ($PolicyBody) {
        $script:LastPatch = $null
        $Request = @{
            Params  = @{ CIPPEndpoint = 'ExecEditCAPolicyFull' }
            Headers = @{}
            Query   = @{}
            Body    = [pscustomobject]@{
                tenantFilter = 'contoso.onmicrosoft.com'
                PolicyId     = 'policy-guid'
                PolicyBody   = ($PolicyBody | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
            }
        }
        $Response = Invoke-ExecEditCAPolicyFull -Request $Request
        $Sent = if ($script:LastPatch.Body) { $script:LastPatch.Body | ConvertFrom-Json } else { $null }
        return @{ Response = $Response; Sent = $Sent }
    }
}

Describe 'Invoke-ExecEditCAPolicyFull' {
    BeforeEach {
        $script:CurrentPolicy = $null
        $script:GraphErrorBody = $null
        $script:LogMessage = $null
    }

    Context 'a policy whose blocks the editor emptied' {
        BeforeAll {
            $script:Result = Invoke-Edit @{
                displayName     = 'CA201'
                state           = 'disabled'
                conditions      = @{
                    clientAppTypes = @('all')
                    applications   = @{ includeApplications = @('All'); excludeApplications = @() }
                    users          = @{ includeUsers = @('All'); includeGroups = @(); excludeGroups = @() }
                    platforms      = $null
                    devices        = $null
                }
                grantControls   = @{ operator = 'OR'; builtInControls = @('mfa') }
                sessionControls = $null
            }
            $script:Sent = $script:Result.Sent
        }

        It 'returns OK' {
            $script:Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        }

        It 'PATCHes the policy by id' {
            $script:LastPatch.Type | Should -Be 'PATCH'
            $script:LastPatch.Uri | Should -Be 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies/policy-guid'
        }

        It 'sends the emptied collections as [] so Graph clears them' {
            $script:LastPatch.Body | Should -Match '"includeGroups":\[\]'
            $script:LastPatch.Body | Should -Match '"excludeApplications":\[\]'
        }

        It 'restores collections the body omitted as [] - a partial body must still clear them' {
            # The form never sent excludeUsers at all; the canonicalizer says its absence out loud.
            $script:LastPatch.Body | Should -Match '"excludeUsers":\[\]'
            $script:Sent.conditions.users.PSObject.Properties.Name | Should -Contain 'excludeRoles'
        }

        It 'sends the emptied <Block> block as null rather than dropping it' -ForEach @(
            @{ Block = 'platforms' }
            @{ Block = 'devices' }
        ) {
            $script:Sent.conditions.PSObject.Properties.Name | Should -Contain $Block
            $script:Sent.conditions.$Block | Should -BeNullOrEmpty
        }

        It 'sends sessionControls as null rather than dropping it' {
            $script:Sent.PSObject.Properties.Name | Should -Contain 'sessionControls'
            $script:Sent.sessionControls | Should -BeNullOrEmpty
        }

        It 'leaves the assignments the user kept alone' {
            $script:Sent.conditions.users.includeUsers | Should -Be @('All')
            $script:Sent.grantControls.builtInControls | Should -Be @('mfa')
            $script:Sent.displayName | Should -Be 'CA201'
        }
    }

    Context 'a half-populated block that Graph would reject' {
        It 'collapses platforms with no includePlatforms to null' {
            $Result = Invoke-Edit @{
                displayName = 'CA201'
                conditions  = @{
                    users     = @{ includeUsers = @('All') }
                    platforms = @{ includePlatforms = @(); excludePlatforms = @() }
                }
            }
            $Result.Sent.conditions.platforms | Should -BeNullOrEmpty
        }

        It 'keeps a platforms block that names a platform' {
            $Result = Invoke-Edit @{
                displayName = 'CA201'
                conditions  = @{
                    users     = @{ includeUsers = @('All') }
                    platforms = @{ includePlatforms = @('android'); excludePlatforms = @() }
                }
            }
            $Result.Sent.conditions.platforms.includePlatforms | Should -Be @('android')
        }
    }

    Context 'read-only properties' {
        It 'never PATCHes id or createdDateTime back to Graph' {
            $Result = Invoke-Edit @{
                displayName     = 'CA201'
                id              = 'policy-guid'
                createdDateTime = '2026-01-01T00:00:00Z'
                templateId      = 'template-guid'
                conditions      = @{ users = @{ includeUsers = @('All') } }
            }
            $Names = $Result.Sent.PSObject.Properties.Name
            $Names | Should -Not -Contain 'id'
            $Names | Should -Not -Contain 'createdDateTime'
            $Names | Should -Not -Contain 'templateId'
        }
    }

    Context 'protected fields' {
        It 'refuses a partial body that would drop excluded users' {
            $script:CurrentPolicy = [pscustomobject]@{
                id            = 'policy-guid'
                displayName   = 'CA201'
                grantControls = [pscustomobject]@{ operator = 'OR'; builtInControls = @('mfa') }
                conditions    = [pscustomobject]@{
                    users = [pscustomobject]@{ includeUsers = @('All'); excludeUsers = @('breakglass@contoso.com'); excludeGroups = @() }
                }
            }
            $Result = Invoke-Edit @{
                displayName = 'CA201'
                conditions  = @{ users = @{ includeUsers = @('All'); excludeUsers = @() } }
            }
            $script:CurrentPolicy = $null
            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Result.Response.Body.Results | Should -Match 'excludeUsers'
            $script:LastPatch | Should -BeNullOrEmpty
        }

        It 'drops excluded users only when ConfirmRemoval names that field' {
            $script:CurrentPolicy = [pscustomobject]@{
                id            = 'policy-guid'
                displayName   = 'CA201'
                grantControls = [pscustomobject]@{ operator = 'OR'; builtInControls = @('mfa') }
                conditions    = [pscustomobject]@{
                    users = [pscustomobject]@{ includeUsers = @('All'); excludeUsers = @('breakglass@contoso.com'); excludeGroups = @() }
                }
            }
            $script:LastPatch = $null
            $Request = @{
                Params  = @{ CIPPEndpoint = 'ExecEditCAPolicyFull' }
                Headers = @{}
                Query   = @{}
                Body    = [pscustomobject]@{
                    tenantFilter   = 'contoso.onmicrosoft.com'
                    PolicyId       = 'policy-guid'
                    ConfirmRemoval = @('excludeUsers')
                    PolicyBody     = (@{
                            displayName = 'CA201'
                            conditions  = @{ users = @{ includeUsers = @('All'); excludeUsers = @() } }
                        } | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
                }
            }
            $Response = Invoke-ExecEditCAPolicyFull -Request $Request
            $script:CurrentPolicy = $null
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            ($script:LastPatch.Body | ConvertFrom-Json).conditions.users.excludeUsers | Should -BeNullOrEmpty
        }
    }

    Context 'a live Graph beta policy' {
        It 'drops annotations and read-only fields from the GET and the request before PATCH' {
            $script:CurrentPolicy = @'
{
  "@odata.context": "https://graph.microsoft.com/beta/$metadata#identity/conditionalAccess/policies/$entity",
  "id": "policy-guid",
  "templateId": "template-guid",
  "createdDateTime": "2026-01-01T00:00:00Z",
  "modifiedDateTime": "2026-11-03T16:09:00Z",
  "deletedDateTime": null,
  "partialEnablementStrategy": "disabled",
  "displayName": "CA201",
  "state": "enabledForReportingButNotEnforced",
  "conditions": {
    "clientAppTypes": ["all"],
    "users": {
      "includeUsers": ["All"],
      "excludeUsers": [],
      "includeUsers@odata.type": "#Collection(String)",
      "excludeGuestsOrExternalUsers": {
        "guestOrExternalUserTypes": "b2bCollaborationGuest",
        "externalTenants": { "@odata.type": "#microsoft.graph.conditionalAccessAllExternalTenants", "membershipKind": "all" }
      }
    },
    "applications": { "includeApplications": ["All"], "excludeApplications": [] }
  },
  "grantControls": {
    "@odata.type": "#microsoft.graph.conditionalAccessGrantControls",
    "operator": "OR",
    "builtInControls": ["mfa"],
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "authenticationStrength": {
      "@odata.context": "https://graph.microsoft.com/beta/$metadata#identity/conditionalAccess/authenticationStrength/policies/$entity",
      "id": "00000000-0000-0000-0000-000000000002",
      "displayName": "Multifactor authentication",
      "createdDateTime": "2026-01-01T00:00:00Z",
      "modifiedDateTime": "2026-01-01T00:00:00Z"
    },
    "authenticationStrength@odata.context": "https://graph.microsoft.com/beta/$metadata#policies('policy-guid')/grantControls/authenticationStrength"
  },
  "sessionControls": null
}
'@ | ConvertFrom-Json

            $Result = Invoke-Edit @{
                '@odata.context'          = 'https://graph.microsoft.com/beta/$metadata#identity/conditionalAccess/policies/$entity'
                id                        = 'policy-guid'
                createdDateTime           = '2026-01-01T00:00:00Z'
                modifiedDateTime          = '2026-11-03T16:09:00Z'
                deletedDateTime           = $null
                templateId                = 'template-guid'
                partialEnablementStrategy = 'disabled'
                displayName               = 'CA201'
                state                     = 'enabled'
                conditions                = @{
                    clientAppTypes = @('all')
                    users          = @{
                        includeUsers   = @('All')
                        excludeUsers   = @()
                        excludeGuestsOrExternalUsers = @{
                            guestOrExternalUserTypes = 'b2bCollaborationGuest'
                            externalTenants          = @{
                                '@odata.type'  = '#microsoft.graph.conditionalAccessAllExternalTenants'
                                membershipKind = 'all'
                            }
                        }
                    }
                    applications   = @{ includeApplications = @('All'); excludeApplications = @() }
                }
                grantControls             = @{
                    '@odata.type'          = '#microsoft.graph.conditionalAccessGrantControls'
                    operator               = 'OR'
                    builtInControls        = @('mfa')
                    customAuthenticationFactors = @()
                    termsOfUse             = @()
                    authenticationStrength = @{
                        id             = '00000000-0000-0000-0000-000000000002'
                        displayName    = 'Multifactor authentication'
                        createdDateTime = '2026-01-01T00:00:00Z'
                    }
                }
                sessionControls           = $null
            }
            $script:CurrentPolicy = $null

            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $Names = [System.Collections.Generic.List[string]]::new()
            Get-PolicyPropertyNames -Node $Result.Sent -Names $Names
            $Names | Should -Not -Contain '@odata.context'
            $Names | Should -Not -Contain 'includeUsers@odata.type'
            $Names | Should -Not -Contain 'authenticationStrength@odata.context'
            $Names | Should -Not -Contain 'createdDateTime'
            $Names | Should -Not -Contain 'modifiedDateTime'
            $Names | Should -Not -Contain 'deletedDateTime'
            $Names | Should -Not -Contain 'templateId'
            $Names | Should -Not -Contain 'partialEnablementStrategy'
            $Result.Sent.PSObject.Properties.Name | Should -Not -Contain 'id'
            $Result.Sent.grantControls.authenticationStrength.PSObject.Properties.Name | Should -Be @('id')
            $Result.Sent.grantControls.authenticationStrength.id | Should -Be '00000000-0000-0000-0000-000000000002'
            $Result.Sent.conditions.users.excludeGuestsOrExternalUsers.externalTenants.'@odata.type' | Should -Be '#microsoft.graph.conditionalAccessAllExternalTenants'
        }

        It 'sends a state-only change when the full payload otherwise matches the live policy' {
            $script:CurrentPolicy = @'
{
  "@odata.context": "https://graph.microsoft.com/beta/$metadata#identity/conditionalAccess/policies/$entity",
  "id": "policy-guid",
  "createdDateTime": "2026-01-01T00:00:00Z",
  "modifiedDateTime": "2026-11-03T16:09:00Z",
  "deletedDateTime": null,
  "displayName": "CA201",
  "state": "enabledForReportingButNotEnforced",
  "conditions": {
    "clientAppTypes": ["all"],
    "signInRiskLevels": [],
    "userRiskLevels": [],
    "servicePrincipalRiskLevels": [],
    "platforms": null,
    "locations": null,
    "devices": null,
    "clientApplications": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "users": {
      "includeUsers": ["All"],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGroups": [],
      "includeRoles": [],
      "excludeRoles": [],
      "includeGuestsOrExternalUsers": null,
      "excludeGuestsOrExternalUsers": null
    },
    "applications": {
      "includeApplications": ["All"],
      "excludeApplications": [],
      "includeUserActions": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null
    }
  },
  "grantControls": {
    "operator": "OR",
    "builtInControls": ["mfa"],
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "authenticationStrength": null
  },
  "sessionControls": null
}
'@ | ConvertFrom-Json

            $Result = Invoke-Edit @{
                id               = 'policy-guid'
                createdDateTime  = '2026-01-01T00:00:00Z'
                modifiedDateTime = '2026-11-03T16:09:00Z'
                deletedDateTime  = $null
                displayName      = 'CA201'
                state            = 'enabled'
                conditions       = @{
                    clientAppTypes              = @('all')
                    signInRiskLevels            = @()
                    userRiskLevels              = @()
                    servicePrincipalRiskLevels  = @()
                    platforms                   = $null
                    locations                   = $null
                    devices                     = $null
                    clientApplications          = $null
                    authenticationFlows         = $null
                    insiderRiskLevels           = $null
                    users                       = @{
                        includeUsers                     = @('All')
                        excludeUsers                     = @()
                        includeGroups                    = @()
                        excludeGroups                    = @()
                        includeRoles                     = @()
                        excludeRoles                     = @()
                        includeGuestsOrExternalUsers     = $null
                        excludeGuestsOrExternalUsers     = $null
                    }
                    applications                = @{
                        includeApplications                         = @('All')
                        excludeApplications                         = @()
                        includeUserActions                          = @()
                        includeAuthenticationContextClassReferences = @()
                        applicationFilter                           = $null
                    }
                }
                grantControls    = @{
                    operator                    = 'OR'
                    builtInControls             = @('mfa')
                    customAuthenticationFactors = @()
                    termsOfUse                  = @()
                    authenticationStrength      = $null
                }
                sessionControls  = $null
            }
            $script:CurrentPolicy = $null

            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $Result.Sent.state | Should -Be 'enabled'
            $Result.Sent.displayName | Should -Be 'CA201'
            $Result.Sent.sessionControls | Should -BeNullOrEmpty
            $Result.Sent.grantControls.authenticationStrength | Should -BeNullOrEmpty
            $Result.Sent.grantControls.builtInControls | Should -Be @('mfa')
            $Result.Sent.conditions.users.includeUsers | Should -Be @('All')
            $Result.Sent.conditions.users.excludeUsers | Should -BeNullOrEmpty
            $Result.Sent.conditions.platforms | Should -BeNullOrEmpty
            $Names = $Result.Sent.PSObject.Properties.Name
            @($Names | Where-Object { $_ -notin @('displayName', 'state', 'conditions', 'grantControls', 'sessionControls') }) | Should -BeNullOrEmpty
            $script:LastPatch.Body | Should -Not -Match '@odata|createdDateTime|modifiedDateTime|deletedDateTime|templateId|policy-guid'
        }
    }

    Context 'validation' {
        It 'rejects a request with no PolicyBody' {
            $Request = @{
                Params  = @{ CIPPEndpoint = 'ExecEditCAPolicyFull' }
                Headers = @{}
                Query   = @{}
                Body    = [pscustomobject]@{ tenantFilter = 'contoso.onmicrosoft.com'; PolicyId = 'policy-guid' }
            }
            (Invoke-ExecEditCAPolicyFull -Request $Request).StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        }

        It 'rejects a request with no PolicyId' {
            $Request = @{
                Params  = @{ CIPPEndpoint = 'ExecEditCAPolicyFull' }
                Headers = @{}
                Query   = @{}
                Body    = [pscustomobject]@{ tenantFilter = 'contoso.onmicrosoft.com'; PolicyBody = [pscustomobject]@{ displayName = 'CA201' } }
            }
            (Invoke-ExecEditCAPolicyFull -Request $Request).StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        }
    }

    Context 'ticket 3277327, a report-only policy with one added exclusion' {
        It 'PATCHes both exclusion ids as an array and keeps the report-only state' {
            $OldUser = '11111111-1111-1111-1111-111111111111'
            $NewUser = 'd5a90120-e6b5-4166-922e-0799284aeeae'
            $script:CurrentPolicy = @"
{
  "@odata.context": "https://graph.microsoft.com/beta/`$metadata#identity/conditionalAccess/policies/`$entity",
  "id": "policy-guid",
  "templateId": "template-guid",
  "createdDateTime": "2026-01-01T00:00:00Z",
  "modifiedDateTime": "2026-11-03T23:15:00Z",
  "deletedDateTime": null,
  "partialEnablementStrategy": "disabled",
  "displayName": "Cortalis - Block device code flow",
  "state": "enabledForReportingButNotEnforced",
  "conditions": {
    "clientAppTypes": ["all"],
    "users": {
      "includeUsers": ["All"],
      "excludeUsers": ["$OldUser"],
      "includeUsers@odata.type": "#Collection(String)",
      "excludeGuestsOrExternalUsers": {
        "guestOrExternalUserTypes": "b2bCollaborationGuest",
        "externalTenants": { "@odata.type": "#microsoft.graph.conditionalAccessAllExternalTenants", "membershipKind": "all" }
      }
    },
    "applications": { "includeApplications": ["All"], "excludeApplications": [] },
    "authenticationFlows": { "transferMethods": "deviceCodeFlow" }
  },
  "grantControls": {
    "operator": "OR",
    "builtInControls": ["block"],
    "authenticationStrength": {
      "@odata.context": "https://graph.microsoft.com/beta/`$metadata#identity/conditionalAccess/authenticationStrength/policies/`$entity",
      "id": "00000000-0000-0000-0000-000000000004",
      "displayName": "Phishing-resistant MFA",
      "createdDateTime": "2026-01-01T00:00:00Z",
      "modifiedDateTime": "2026-01-01T00:00:00Z"
    }
  },
  "sessionControls": null
}
"@ | ConvertFrom-Json

            $Result = Invoke-Edit @{
                displayName = 'Cortalis - Block device code flow'
                state       = 'enabledForReportingButNotEnforced'
                conditions  = @{
                    clientAppTypes       = @('all')
                    users                = @{
                        includeUsers = @('All')
                        excludeUsers = @($OldUser, $NewUser)
                        excludeGuestsOrExternalUsers = @{
                            guestOrExternalUserTypes = 'b2bCollaborationGuest'
                            externalTenants          = @{
                                '@odata.type'  = '#microsoft.graph.conditionalAccessAllExternalTenants'
                                membershipKind = 'all'
                            }
                        }
                    }
                    applications         = @{ includeApplications = @('All'); excludeApplications = @() }
                    authenticationFlows  = @{ transferMethods = 'deviceCodeFlow' }
                }
                grantControls = @{
                    operator         = 'OR'
                    builtInControls  = @('block')
                    authenticationStrength = @{ id = '00000000-0000-0000-0000-000000000004'; displayName = 'Phishing-resistant MFA' }
                }
                sessionControls = $null
            }

            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $Result.Sent.state | Should -Be 'enabledForReportingButNotEnforced'
            $script:LastPatch.Body | Should -Match '"excludeUsers":\["11111111-1111-1111-1111-111111111111","d5a90120-e6b5-4166-922e-0799284aeeae"\]'
            $script:LastPatch.Body | Should -Not -Match '@odata\.context|deletedDateTime|partialEnablementStrategy|templateId|createdDateTime|modifiedDateTime|Phishing-resistant MFA'
            $Result.Sent.conditions.users.excludeGuestsOrExternalUsers.externalTenants.'@odata.type' | Should -Be '#microsoft.graph.conditionalAccessAllExternalTenants'
            $Result.Sent.grantControls.authenticationStrength.PSObject.Properties.Name | Should -Be @('id')
            $Result.Sent.conditions.authenticationFlows.transferMethods | Should -Be 'deviceCodeFlow'
        }
    }

    Context 'array values Graph would reject as scalars or null' {
        It 'writes a one-item exclusion and an empty collection as JSON arrays' {
            $Request = @{
                Params  = @{ CIPPEndpoint = 'ExecEditCAPolicyFull' }
                Headers = @{}
                Query   = @{}
                Body    = [pscustomobject]@{
                    tenantFilter = 'contoso.onmicrosoft.com'
                    PolicyId     = 'policy-guid'
                    PolicyBody   = [pscustomobject]@{
                        displayName = 'CA201'
                        state       = 'enabled'
                        conditions  = [pscustomobject]@{
                            clientAppTypes = 'all'
                            users          = [pscustomobject]@{
                                includeUsers  = 'All'
                                excludeUsers  = 'd5a90120-e6b5-4166-922e-0799284aeeae'
                                includeGroups = $null
                            }
                        }
                    }
                }
            }
            $Response = Invoke-ExecEditCAPolicyFull -Request $Request
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $script:LastPatch.Body | Should -Match '"excludeUsers":\["d5a90120-e6b5-4166-922e-0799284aeeae"\]'
            $script:LastPatch.Body | Should -Match '"includeUsers":\["All"\]'
            $script:LastPatch.Body | Should -Match '"includeGroups":\[\]'
            $script:LastPatch.Body | Should -Match '"clientAppTypes":\["all"\]'
        }
    }

    Context 'a live block the request did not clear' {
        It 'does not send devices null when the saved block was half populated' {
            $script:CurrentPolicy = [pscustomobject]@{
                id          = 'policy-guid'
                displayName = 'CA201'
                state       = 'enabled'
                conditions  = [pscustomobject]@{
                    clientAppTypes = @('all')
                    users          = [pscustomobject]@{ includeUsers = @('All'); excludeUsers = @(); excludeGroups = @() }
                    devices        = [pscustomobject]@{ deviceFilter = [pscustomobject]@{} }
                }
                grantControls = [pscustomobject]@{ operator = 'OR'; builtInControls = @('mfa') }
            }
            $Result = Invoke-Edit @{
                displayName   = 'CA201'
                state         = 'enabled'
                conditions    = @{
                    clientAppTypes = @('all')
                    users          = @{ includeUsers = @('All') }
                }
                grantControls = @{ operator = 'OR'; builtInControls = @('mfa') }
            }
            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $Result.Sent.conditions.PSObject.Properties.Name | Should -Not -Contain 'devices'
            $script:LastPatch.Body | Should -Not -Match '"devices":null'
        }

        It 'sends devices null when the caller clears that block' {
            $script:CurrentPolicy = [pscustomobject]@{
                id          = 'policy-guid'
                displayName = 'CA201'
                state       = 'enabled'
                conditions  = [pscustomobject]@{
                    clientAppTypes = @('all')
                    users          = [pscustomobject]@{ includeUsers = @('All'); excludeUsers = @(); excludeGroups = @() }
                    devices        = [pscustomobject]@{
                        deviceFilter = [pscustomobject]@{ mode = 'include'; rule = 'device.trustType -eq "ServerAD"' }
                    }
                }
                grantControls = [pscustomobject]@{ operator = 'OR'; builtInControls = @('mfa') }
            }
            $Result = Invoke-Edit @{
                displayName   = 'CA201'
                state         = 'enabled'
                conditions    = @{
                    clientAppTypes = @('all')
                    users          = @{ includeUsers = @('All') }
                    devices        = $null
                }
                grantControls = @{ operator = 'OR'; builtInControls = @('mfa') }
            }
            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $Result.Sent.conditions.PSObject.Properties.Name | Should -Contain 'devices'
            $Result.Sent.conditions.devices | Should -BeNullOrEmpty
        }
    }

    Context 'HPDArch report-only edits on the beta schema' {
        # Documented Microsoft Graph beta conditionalAccessPolicy update shape.
        # includeAgentActions, agents, and actionsAndDestinations are not in it.
        BeforeAll {
        $script:BetaSchema = @{
            '' = @('displayName', 'state', 'conditions', 'grantControls', 'sessionControls')
            'conditions' = @('users', 'applications', 'clientAppTypes', 'platforms', 'locations', 'devices', 'clientApplications', 'signInRiskLevels', 'userRiskLevels', 'servicePrincipalRiskLevels', 'insiderRiskLevels', 'authenticationFlows', 'agentIdRiskLevels')
            'conditions.users' = @('includeUsers', 'excludeUsers', 'includeGroups', 'excludeGroups', 'includeRoles', 'excludeRoles', 'includeGuestsOrExternalUsers', 'excludeGuestsOrExternalUsers')
            'conditions.applications' = @('includeApplications', 'excludeApplications', 'includeUserActions', 'includeAuthenticationContextClassReferences', 'applicationFilter')
            'conditions.platforms' = @('includePlatforms', 'excludePlatforms')
            'conditions.locations' = @('includeLocations', 'excludeLocations')
            'conditions.devices' = @('includeDevices', 'excludeDevices', 'deviceFilter')
            'conditions.clientApplications' = @('includeServicePrincipals', 'excludeServicePrincipals', 'servicePrincipalFilter')
            'conditions.authenticationFlows' = @('transferMethods')
            'grantControls' = @('operator', 'builtInControls', 'customAuthenticationFactors', 'termsOfUse', 'authenticationStrength')
            'grantControls.authenticationStrength' = @('id')
            'sessionControls' = @('applicationEnforcedRestrictions', 'cloudAppSecurity', 'signInFrequency', 'persistentBrowser', 'disableResilienceDefaults', 'continuousAccessEvaluation', 'secureSignInSession', 'globalSecureAccessFilteringProfile')
        }

        function Get-SchemaViolations ($Node, [string]$Path) {
            $Found = [System.Collections.Generic.List[string]]::new()
            if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) { return $Found }
            if ($Node -isnot [System.Management.Automation.PSCustomObject]) {
                foreach ($Item in @($Node)) {
                    foreach ($Violation in @(Get-SchemaViolations -Node $Item -Path $Path)) { $Found.Add($Violation) }
                }
                return $Found
            }
            $Allowed = $script:BetaSchema[$Path]
            foreach ($Prop in @($Node.PSObject.Properties)) {
                if ($Prop.Name -eq '@odata.type') { continue }
                if ($null -ne $Allowed -and $Prop.Name -notin $Allowed) {
                    $Found.Add($(if ($Path) { "$Path.$($Prop.Name)" } else { $Prop.Name }))
                }
                $ChildPath = if ($Path) { "$Path.$($Prop.Name)" } else { $Prop.Name }
                if ($script:BetaSchema.ContainsKey($ChildPath)) {
                    foreach ($Violation in @(Get-SchemaViolations -Node $Prop.Value -Path $ChildPath)) { $Found.Add($Violation) }
                }
            }
            return $Found
        }

        function New-HpdLivePolicy ([string]$Kind) {
            $Conditions = @{
                clientAppTypes = @('all')
                userRiskLevels = @()
                signInRiskLevels = @()
                applications = @{
                    includeApplications = @('All')
                    excludeApplications = @()
                    includeUserActions = @()
                    includeAgentActions = @()
                    includeAuthenticationContextClassReferences = @()
                }
                users = @{
                    includeUsers = @('All')
                    excludeUsers = @('896e0c37-d911-4742-b291-a0b57058ff06')
                    includeGroups = @()
                    excludeGroups = @()
                    includeRoles = @()
                    excludeRoles = @()
                }
                agents = @{}
                actionsAndDestinations = @{}
            }
            if ($Kind -eq 'deviceCode') {
                $Conditions.authenticationFlows = @{ transferMethods = 'deviceCodeFlow' }
            } else {
                $Conditions.locations = @{ includeLocations = @('05ad0683-c39f-4830-aef0-1442d3890313'); excludeLocations = @() }
            }
            return [pscustomobject]@{
                '@odata.context' = 'https://graph.microsoft.com/beta/$metadata#identity/conditionalAccess/policies/$entity'
                id = 'policy-guid'
                createdDateTime = '2026-01-01T00:00:00Z'
                modifiedDateTime = '2026-11-04T00:00:00Z'
                deletedDateTime = $null
                templateId = 'template-guid'
                partialEnablementStrategy = 'disabled'
                displayName = 'Cortalis - Block device code flow (#3277327)'
                state = 'enabledForReportingButNotEnforced'
                conditions = ($Conditions | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
                grantControls = [pscustomobject]@{
                    operator = 'OR'
                    builtInControls = @('block')
                    customAuthenticationFactors = @()
                    termsOfUse = @()
                }
                sessionControls = $null
            }
        }

        function New-HpdRequest ([string]$Kind) {
            $Body = @{
                displayName = 'Cortalis - Block device code flow (#3277327)'
                state = 'enabledForReportingButNotEnforced'
                conditions = @{
                    userRiskLevels = @()
                    signInRiskLevels = @()
                    clientAppTypes = @('all')
                    applications = @{
                        includeApplications = @('All')
                        excludeApplications = @()
                        includeUserActions = @()
                        includeAgentActions = @()
                        includeAuthenticationContextClassReferences = @()
                    }
                    users = @{
                        includeUsers = @('All')
                        excludeUsers = @('896e0c37-d911-4742-b291-a0b57058ff06', 'd5a90120-e6b5-4166-922e-0799284aeeae')
                        includeGroups = @()
                        excludeGroups = @()
                        includeRoles = @()
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    operator = 'OR'
                    builtInControls = @('block')
                    customAuthenticationFactors = @()
                    termsOfUse = @()
                }
                sessionControls = $null
            }
            if ($Kind -eq 'deviceCode') {
                $Body.conditions.authenticationFlows = @{ transferMethods = 'deviceCodeFlow' }
            } else {
                $Body.displayName = 'Cortalis - Block one named location'
                $Body.conditions.locations = @{ includeLocations = @('05ad0683-c39f-4830-aef0-1442d3890313') }
            }
            return $Body
        }
        }

        It 'PATCHes beta and keeps the device-code exclusion inside the schema' {
            $script:CurrentPolicy = New-HpdLivePolicy -Kind 'deviceCode'
            $Result = Invoke-Edit (New-HpdRequest -Kind 'deviceCode')
            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $script:LastPatch.Uri | Should -Be 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies/policy-guid'
            $script:LastPatch.Type | Should -Be 'PATCH'
            $Violations = @(Get-SchemaViolations -Node $Result.Sent -Path '')
            $Violations | Should -BeNullOrEmpty
            $script:LastPatch.Body | Should -Not -Match 'includeAgentActions|actionsAndDestinations|"agents"'
            $script:LastPatch.Body | Should -Match '"excludeUsers":\["896e0c37-d911-4742-b291-a0b57058ff06","d5a90120-e6b5-4166-922e-0799284aeeae"\]'
            $Result.Sent.state | Should -Be 'enabledForReportingButNotEnforced'
            $Result.Sent.grantControls.builtInControls | Should -Be @('block')
            $Result.Sent.conditions.authenticationFlows.transferMethods | Should -Be 'deviceCodeFlow'
            $Result.Sent.sessionControls | Should -BeNullOrEmpty
        }

        It 'PATCHes beta and keeps the named-location exclusion inside the schema' {
            $script:CurrentPolicy = New-HpdLivePolicy -Kind 'location'
            $Result = Invoke-Edit (New-HpdRequest -Kind 'location')
            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $script:LastPatch.Uri | Should -Be 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies/policy-guid'
            $Violations = @(Get-SchemaViolations -Node $Result.Sent -Path '')
            $Violations | Should -BeNullOrEmpty
            $script:LastPatch.Body | Should -Not -Match 'includeAgentActions|actionsAndDestinations|"agents"'
            $script:LastPatch.Body | Should -Match '"excludeUsers":\["896e0c37-d911-4742-b291-a0b57058ff06","d5a90120-e6b5-4166-922e-0799284aeeae"\]'
            $script:LastPatch.Body | Should -Match '"includeLocations":\["05ad0683-c39f-4830-aef0-1442d3890313"\]'
            $Result.Sent.state | Should -Be 'enabledForReportingButNotEnforced'
            $Result.Sent.grantControls.builtInControls | Should -Be @('block')
            $Result.Sent.PSObject.Properties.Name | Should -Not -Contain 'authenticationFlows'
        }

        It 'does not wipe grant controls the request left out' {
            $script:CurrentPolicy = New-HpdLivePolicy -Kind 'deviceCode'
            $Request = New-HpdRequest -Kind 'deviceCode'
            $Request.Remove('grantControls')
            $Result = Invoke-Edit $Request
            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $Result.Sent.grantControls.builtInControls | Should -Be @('block')
        }
    }

    Context 'a Graph schema rejection' {
        It 'returns the Graph 1007 error instead of a generic failure and logs the outgoing body' {
            $script:GraphErrorBody = '{"error":{"code":"1007","message":"Incoming ConditionalAccessPolicy object is null or does not match the schema of ConditionalAccessPolicy type."}}'
            $Result = Invoke-Edit @{
                displayName = 'Bearer eyJhbGciOiJub25lIn0.secret'
                state       = 'enabled'
                conditions  = @{ users = @{ includeUsers = @('All') } }
                grantControls = @{ operator = 'OR'; builtInControls = @('mfa') }
            }
            $Result.Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Result.Response.Body.Results | Should -Match '1007'
            $Result.Response.Body.Results | Should -Match 'does not match the schema of ConditionalAccessPolicy type'
            $script:LogMessage | Should -Match 'Outgoing body:'
            $script:LogMessage | Should -Match '"includeUsers":\["All"\]'
            $script:LogMessage | Should -Not -Match 'eyJhbGciOiJub25lIn0'
            $script:LogMessage | Should -Match 'Bearer \[redacted\]'
        }
    }
}
