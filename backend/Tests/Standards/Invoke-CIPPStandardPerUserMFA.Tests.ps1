# Pester tests for Invoke-CIPPStandardPerUserMFA
# Verifies that the Standards path passes user GUIDs to Set-CIPPPerUserMFA instead of UPNs,
# avoiding Graph 400 errors when a UPN appears in another user's proxyAddresses.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $Modules = Join-Path $RepoRoot 'Modules'
    # Resolve by name under Modules/ so the test survives the function moving between modules.
    $StandardPath = Get-ChildItem -Path $Modules -Recurse -Filter 'Invoke-CIPPStandardPerUserMFA.ps1' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $StandardPath) { throw 'Could not locate Invoke-CIPPStandardPerUserMFA.ps1 under Modules/' }

    # Stubs mirror the real signatures and are advanced functions on purpose: strict parameter
    # binding makes signature drift in the standard fail loudly here instead of silently
    # landing in $args.
    function New-CIPPDbRequest { [CmdletBinding()] param($TenantFilter, $Type) }
    function Set-CIPPPerUserMFA { [CmdletBinding()] param($TenantFilter, $UserId, $State, $APIName) }
    function Set-CIPPDBCacheUsers { [CmdletBinding()] param($TenantFilter) }
    function Write-LogMessage { [CmdletBinding()] param($API, $tenant, $message, $sev) }
    function Write-StandardsAlert { [CmdletBinding()] param($message, $object, $tenant, $standardName, $standardId) }
    function Set-CIPPStandardsCompareField { [CmdletBinding()] param($FieldName, $CurrentValue, $ExpectedValue, $Tenant) }
    function Get-NormalizedError { [CmdletBinding()] param($Message) $Message }

    . $StandardPath

    # Script scope: Pester 5 evaluates the Describe body at discovery, so plain variables
    # declared there are not in scope inside It blocks or mocks at run time.
    $script:Tenant = 'contoso.onmicrosoft.com'

    function script:New-TestUser {
        param(
            [string]$Id,
            [string]$Upn,
            [string]$DisplayName,
            [string]$PerUserMfaState = 'disabled',
            [bool]$AccountEnabled = $true,
            [string]$UserType = 'Member'
        )
        [ordered]@{
            id                = $Id
            userPrincipalName = $Upn
            displayName       = $DisplayName
            perUserMfaState   = $PerUserMfaState
            accountEnabled    = $AccountEnabled
            userType          = $UserType
        } | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    }
}

Describe 'Invoke-CIPPStandardPerUserMFA' {
    BeforeEach {
        $script:logs = [System.Collections.Generic.List[object]]::new()
        $script:alerts = [System.Collections.Generic.List[object]]::new()
        $script:compare = [System.Collections.Generic.List[object]]::new()
        $script:mfaCalls = [System.Collections.Generic.List[object]]::new()
        $script:users = @()

        Mock -CommandName Set-CIPPDBCacheUsers -MockWith { }
        Mock -CommandName Write-LogMessage -MockWith {
            param($API, $tenant, $message, $sev)
            $script:logs.Add(@{ Message = $message; Sev = $sev })
        }
        Mock -CommandName Write-StandardsAlert -MockWith {
            param($message, $object, $tenant, $standardName, $standardId)
            $script:alerts.Add(@{ Message = $message; Object = @($object) })
        }
        Mock -CommandName Set-CIPPStandardsCompareField -MockWith {
            param($FieldName, $CurrentValue, $ExpectedValue, $Tenant)
            $script:compare.Add(@{ Current = $CurrentValue; Expected = $ExpectedValue })
        }
        Mock -CommandName New-CIPPDbRequest -MockWith { $script:users }
        Mock -CommandName Set-CIPPPerUserMFA -MockWith {
            param($TenantFilter, $UserId, $State, $APIName)
            $script:mfaCalls.Add(@{ UserId = $UserId; State = $State })
            # Return success results for each user
            foreach ($Id in $UserId) {
                [pscustomobject]@{
                    Success = $true
                    UPN     = "user@contoso.com"
                    Result  = "Set MFA to enforced for user@contoso.com"
                }
            }
        }
    }

    Context 'Passes GUIDs to Set-CIPPPerUserMFA' {
        It 'passes user object IDs (GUIDs) instead of userPrincipalNames when remediating' {
            $script:users = @(
                New-TestUser -Id 'a1b2c3d4-e5f6-4789-a012-b3c4d5e6f789' -Upn 'user1@contoso.com' -DisplayName 'User One' -PerUserMfaState 'disabled'
                New-TestUser -Id 'b2c3d4e5-f6a7-5890-b123-c4d5e6f7a890' -Upn 'user2@contoso.com' -DisplayName 'User Two' -PerUserMfaState 'disabled'
            )

            Invoke-CIPPStandardPerUserMFA -Tenant $script:Tenant -Settings @{ remediate = $true }

            Should -Invoke Set-CIPPPerUserMFA -Times 1 -Exactly -ParameterFilter {
                $TenantFilter -eq $script:Tenant -and
                $State -eq 'enforced' -and
                $UserId -is [array] -and
                $UserId.Count -eq 2 -and
                $UserId[0] -eq 'a1b2c3d4-e5f6-4789-a012-b3c4d5e6f789' -and
                $UserId[1] -eq 'b2c3d4e5-f6a7-5890-b123-c4d5e6f7a890' -and
                ([guid]::TryParse($UserId[0], [ref][guid]::Empty)) -and
                ([guid]::TryParse($UserId[1], [ref][guid]::Empty))
            }
        }

        It 'only remediates Member users with enabled accounts and without enforced MFA' {
            $script:users = @(
                New-TestUser -Id 'user1' -Upn 'user1@contoso.com' -DisplayName 'User One' -PerUserMfaState 'disabled'
                New-TestUser -Id 'user2' -Upn 'user2@contoso.com' -DisplayName 'User Two' -PerUserMfaState 'enforced'
                New-TestUser -Id 'user3' -Upn 'user3@contoso.com' -DisplayName 'User Three' -PerUserMfaState 'disabled' -AccountEnabled $false
                New-TestUser -Id 'guest1' -Upn 'guest@contoso.com' -DisplayName 'Guest' -PerUserMfaState 'disabled' -UserType 'Guest'
            )

            Invoke-CIPPStandardPerUserMFA -Tenant $script:Tenant -Settings @{ remediate = $true }

            Should -Invoke Set-CIPPPerUserMFA -Times 1 -Exactly -ParameterFilter {
                $UserId.Count -eq 1 -and
                $UserId[0] -eq 'user1'
            }
        }

        It 'logs a message when all users already have MFA enforced' {
            $script:users = @(
                New-TestUser -Id 'user1' -Upn 'user1@contoso.com' -DisplayName 'User One' -PerUserMfaState 'enforced'
            )

            Invoke-CIPPStandardPerUserMFA -Tenant $script:Tenant -Settings @{ remediate = $true }

            Should -Invoke Set-CIPPPerUserMFA -Times 0 -Exactly
            @($script:logs | Where-Object { $_.Message -like '*All users already have Legacy MFA enforced*' }).Count | Should -Be 1
        }
    }
}
