# Pester tests for Invoke-CIPPPIMAssignmentAction - the guards around PIM assignment changes.
#
# What must hold regardless of caller:
#   - no PIM write on a tenant without Entra ID P2;
#   - the last active Global Administrator is never converted or removed;
#   - CIPP-SAM's own assignment, group-inherited rows and service-principal conversions are refused;
#   - ConvertToEligible confirms the eligibility exists BEFORE the active assignment is removed;
#   - lifetimes above the policy cap are refused (never clamped);
#   - nothing is ever posted with a noExpiration schedule.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/PIM/Get-CIPPMaxRoleAssignmentDuration.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GraphHelper/Get-CIPPGraphErrorMessage.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/PIM/New-CIPPPIMScheduleRequest.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/PIM/Invoke-CIPPPIMAssignmentAction.ps1')

    function Test-CIPPStandardLicense { param($StandardName, $TenantFilter, $Preset, [switch]$SkipLog) $true }
    function Get-CIPPPIMRoleAssignments { param($TenantFilter, $PrincipalId, $RoleDefinitionId, [switch]$FromCache, [switch]$IncludePolicy) }
    function Get-CIPPPIMRolePolicies { param($TenantFilter, $RoleDefinitionId, [switch]$FromCache) }
    function New-GraphPOSTRequest { param($uri, $tenantid, $body, $type, $AsApp) }
    function New-GraphGetRequest { param($uri, $tenantid, $AsApp) }
    function Get-CIPPTable { param($TableName) @{} }
    function Get-CIPPAzDataTableEntity { param($Filter) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }

    $script:GA = '62e90394-69f5-4237-9190-012177145e10'
    $script:Target = 'user-1'

    function New-Row {
        param([string]$Principal = 'user-1', [string]$Type = 'Permanent', [string]$MemberType = 'Direct', [string]$PrincipalType = 'User', [string]$Role = $script:GA, [string]$AppId = $null, [datetime]$End = [datetime]::MinValue)
        [pscustomobject]@{
            PrincipalId                = $Principal
            PrincipalDisplayName       = "Name $Principal"
            PrincipalUserPrincipalName = "$Principal@contoso.com"
            PrincipalType              = $PrincipalType
            PrincipalAppId             = $AppId
            RoleDefinitionId           = $Role
            RoleDisplayName            = 'Global Administrator'
            AssignmentType             = $Type
            MemberType                 = $MemberType
            DirectoryScopeId           = '/'
            EndDateTime                = if ($End -eq [datetime]::MinValue) { $null } else { $End }
            RoleAssignmentId           = 'ra-1'
        }
    }

    function Invoke-Convert {
        param([hashtable]$Extra = @{})
        Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action ConvertToEligible -PrincipalId $script:Target -RoleDefinitionId $script:GA -AssignmentType Permanent -Justification 'test' @Extra
    }
}

Describe 'Invoke-CIPPPIMAssignmentAction' {
    BeforeEach {
        $script:Posts = [System.Collections.Generic.List[object]]::new()
        $env:ApplicationID = 'sam-app-id'
        Mock Test-CIPPStandardLicense { $true }
        Mock Get-CIPPPIMRolePolicies { [pscustomobject]@{ RoleDefinitionId = $script:GA; PolicyId = 'pol'; Settings = [pscustomobject]@{ eligibilityMaxDuration = 'P365D'; activeAssignmentMaxDuration = 'P180D' } } }
        Mock Get-CIPPTable { @{} }
        Mock Get-CIPPAzDataTableEntity { $null }
        Mock Write-LogMessage {}
        Mock Start-Sleep {}
        Mock New-GraphPOSTRequest {
            $script:Posts.Add([pscustomobject]@{ Uri = $uri; Body = ($body | ConvertFrom-Json); Type = $type })
            [pscustomobject]@{ id = 'req' }
        }
        # Default tenant: the target holds GA permanently, another admin also holds it permanently.
        Mock Get-CIPPPIMRoleAssignments {
            $Rows = @((New-Row -Principal 'user-1'), (New-Row -Principal 'user-2'))
            if ($PrincipalId) { $Rows = $Rows | Where-Object { $_.PrincipalId -eq $PrincipalId } }
            if ($RoleDefinitionId) { $Rows = $Rows | Where-Object { $_.RoleDefinitionId -eq $RoleDefinitionId } }
            @($Rows)
        }
        # Eligibility read-back after creation: present.
        # Eligibility read-back: present. Post-removal instance poll: already gone.
        Mock New-GraphGetRequest {
            if ($uri -match 'roleAssignmentScheduleInstances') { @() }
            else { @([pscustomobject]@{ id = 'elig-1'; principalId = 'user-1'; roleDefinitionId = $script:GA; directoryScopeId = '/' }) }
        }
    }

    It 'refuses on a tenant without Entra ID P2 and posts nothing' {
        Mock Test-CIPPStandardLicense { $false }
        { Invoke-Convert } | Should -Throw '*not licensed for Entra ID P2*' -ExceptionType ([System.ArgumentException])
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses to convert the last active Global Administrator' {
        Mock Get-CIPPPIMRoleAssignments {
            $Rows = @((New-Row -Principal 'user-1'), (New-Row -Principal 'user-2' -Type 'Eligible'))
            if ($PrincipalId) { $Rows = $Rows | Where-Object { $_.PrincipalId -eq $PrincipalId } }
            @($Rows)
        }
        { Invoke-Convert } | Should -Throw '*last active Global Administrator*' -ExceptionType ([System.ArgumentException])
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses to remove the last active Global Administrator' {
        Mock Get-CIPPPIMRoleAssignments {
            $Rows = @((New-Row -Principal 'user-1'))
            if ($PrincipalId) { $Rows = $Rows | Where-Object { $_.PrincipalId -eq $PrincipalId } }
            @($Rows)
        }
        { Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action Remove -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Permanent -Justification 'test' } | Should -Throw '*last active Global Administrator*' -ExceptionType ([System.ArgumentException])
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses to touch the CIPP-SAM application' {
        Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -PrincipalType 'ServicePrincipal' -AppId 'sam-app-id'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
        { Invoke-Convert } | Should -Throw '*CIPP-SAM*'
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses a row inherited through a group' {
        Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -MemberType 'Group'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
        { Invoke-Convert } | Should -Throw '*role-assignable group*'
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses to convert a service principal (PIM eligibility is users and groups only)' {
        Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -PrincipalType 'ServicePrincipal' -AppId 'other-app'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
        { Invoke-Convert } | Should -Throw '*service principal*'
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    Context 'ConvertToEligible' {
        It 'creates the eligibility, confirms it, then removes the active assignment - in that order' {
            $Result = Invoke-Convert
            $Result.state | Should -Be 'success'
            $script:Posts.Count | Should -Be 2
            $script:Posts[0].Uri | Should -Match 'roleEligibilityScheduleRequests$'
            $script:Posts[0].Body.action | Should -Be 'adminAssign'
            $script:Posts[0].Body.scheduleInfo.expiration.type | Should -Be 'afterDuration'
            $script:Posts[0].Body.scheduleInfo.expiration.duration | Should -Be 'P365D'
            $script:Posts[1].Uri | Should -Match 'roleAssignmentScheduleRequests$'
            $script:Posts[1].Body.action | Should -Be 'adminRemove'
            Should -Invoke New-GraphGetRequest -Times 1 -ParameterFilter { $uri -match 'roleEligibilitySchedules' }
            $Result.Before | Should -Be 'Permanent'
            $Result.After | Should -Match '^Eligible until'
        }

        It 'leaves the active assignment alone when the eligibility cannot be confirmed' {
            Mock New-GraphGetRequest { @() }
            $Err = { Invoke-Convert } | Should -Throw '*could not be confirmed*' -PassThru
            $Err.Exception | Should -Not -BeOfType ([System.ArgumentException])
            $script:Posts.Count | Should -Be 1
            $script:Posts[0].Body.action | Should -Be 'adminAssign'
        }

        It 'sends P365D when the tenant policy maximum is shorter, so Entra can reject it itself' {
            Mock Get-CIPPPIMRolePolicies { [pscustomobject]@{ RoleDefinitionId = $script:GA; PolicyId = 'pol'; Settings = [pscustomobject]@{ eligibilityMaxDuration = 'PT1H'; activeAssignmentMaxDuration = 'PT1H' } } }
            $Result = Invoke-Convert @{ Duration = 'P365D' }
            $Result.state | Should -Be 'success'
            $script:Posts[0].Body.scheduleInfo.expiration.duration | Should -Be 'P365D'
        }

        It 'refuses an eligibility longer than 365 days instead of truncating it' {
            { Invoke-Convert @{ Duration = 'P366D' } } | Should -Throw '*P365D*' -ExceptionType ([System.ArgumentException])
            Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
        }

        It 'never posts a noExpiration schedule' {
            $null = Invoke-Convert
            foreach ($Post in $script:Posts) {
                (ConvertTo-Json -InputObject $Post.Body -Depth 10 -Compress) | Should -Not -Match 'noExpiration'
            }
        }
    }

    Context 'GrantActive' {
        It 'posts a time-bound assignment within the cap' {
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Eligible'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            $Result = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -Duration 'PT4H' -Justification 'test'
            $Result.state | Should -Be 'success'
            $script:Posts.Count | Should -Be 1
            $script:Posts[0].Uri | Should -Match 'roleAssignmentScheduleRequests$'
            $script:Posts[0].Body.scheduleInfo.expiration.duration | Should -Be 'PT4H'
        }

        It 'does not let the JIT admin MaxDuration setting shorten a PIM assignment' {
            Mock Get-CIPPAzDataTableEntity { [pscustomobject]@{ MaxDuration = 'PT1H' } }
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Eligible'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            $Result = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -Duration 'P30D' -Justification 'test'
            $Result.state | Should -Be 'success'
            $script:Posts[0].Body.scheduleInfo.expiration.duration | Should -Be 'P30D'
        }

        It 'posts <_> as afterDuration' -ForEach @('PT1H', 'P30D', 'P365D') {
            $ExpectedDuration = $_
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Eligible'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            $Result = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -Duration $ExpectedDuration -Justification 'test'
            $Result.state | Should -Be 'success'
            $script:Posts[0].Body.scheduleInfo.expiration.type | Should -Be 'afterDuration'
            $script:Posts[0].Body.scheduleInfo.expiration.duration | Should -Be $ExpectedDuration
        }

        It 'rejects an active assignment longer than 365 days' {
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Eligible'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            { Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -Duration 'P366D' -Justification 'test' } | Should -Throw '*P365D*' -ExceptionType ([System.ArgumentException])
            Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
        }

        It 'rejects an end date in the past' {
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Eligible'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            { Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -EndDateTime ([datetime]::UtcNow.AddHours(-1)) -Justification 'test' } | Should -Throw '*not in the future*' -ExceptionType ([System.ArgumentException])
            Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
        }

        It 'logs tenant, user, role, start, end and caller' {
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Eligible'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            $Principal = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"userDetails":"caller@contoso.com"}'))
            $null = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -Duration 'PT1H' -Justification 'test' -Headers @{ 'x-ms-client-principal' = $Principal }
            Should -Invoke Write-LogMessage -Times 1 -ParameterFilter {
                $tenant -eq 'contoso.onmicrosoft.com' -and $LogData.Principal -eq 'user-1@contoso.com' -and $LogData.Role -eq 'Global Administrator' -and $LogData.Caller -eq 'caller@contoso.com' -and $LogData.Start -and $LogData.End
            }
        }

        It 'grants eligibility with adminAssign and does not remove an active assignment' {
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Active' -End ([datetime]::UtcNow.AddHours(2))), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            $Result = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantEligible -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Active -Duration 'P180D' -Justification 'test'
            $Result.state | Should -Be 'success'
            $script:Posts.Count | Should -Be 1
            $script:Posts[0].Uri | Should -Match 'roleEligibilityScheduleRequests$'
            $script:Posts[0].Body.action | Should -Be 'adminAssign'
            $script:Posts[0].Body.scheduleInfo.expiration.type | Should -Be 'afterDuration'
            $script:Posts[0].Body.scheduleInfo.expiration.duration | Should -Be 'P180D'
        }

        It 'refuses without an expiration' {
            { Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -Justification 'test' } | Should -Throw '*needs a Duration or EndDateTime*' -ExceptionType ([System.ArgumentException])
            Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
        }

        It 'words the end time in the caller''s time zone, and in labelled UTC when the zone is unknown or absent' {
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Eligible'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            # A future instant (the builder refuses a past end), at 08:06 UTC on some day next month:
            # Perth is UTC+8 all year, so the worded time is 16:06 on the same date.
            $End = [datetime]::SpecifyKind([datetime]::UtcNow.AddDays(30).Date.AddHours(8).AddMinutes(6).AddSeconds(36), 'Utc')
            $UtcText = $End.ToString('yyyy-MM-dd') + ' 08:06'
            $PerthText = $End.ToString('yyyy-MM-dd') + ' 16:06'
            $Perth = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -EndDateTime $End -Justification 'test' -TimeZone 'Australia/Perth'
            $Perth.resultText | Should -Match "until $PerthText \(Australia/Perth\)\.$"
            $Perth.After | Should -Be "Active until $PerthText (Australia/Perth)"
            $Perth.EndDateTime | Should -Be $End -Because 'the zone only changes the wording, never the stored end'
            $Unknown = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -EndDateTime $End -Justification 'test' -TimeZone 'Mars/Olympus_Mons'
            $Unknown.resultText | Should -Match "until $UtcText UTC\.$"
            $None = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action GrantActive -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -EndDateTime $End -Justification 'test'
            $None.resultText | Should -Match "until $UtcText UTC\.$"
            # the Graph request itself always carries the UTC instant
            ([datetime]$script:Posts[-1].Body.scheduleInfo.expiration.endDateTime).ToUniversalTime().ToString('s') | Should -Be $End.ToString('s')
        }
    }

    Context 'Remove' {
        It 'removes an eligibility through the eligibility schedule' {
            Mock Get-CIPPPIMRoleAssignments { @((New-Row -Principal 'user-1' -Type 'Eligible'), (New-Row -Principal 'user-2')) | Where-Object { -not $PrincipalId -or $_.PrincipalId -eq $PrincipalId } }
            $Result = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action Remove -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Eligible -Justification 'test'
            $Result.After | Should -Be 'None'
            $script:Posts[0].Uri | Should -Match 'roleEligibilityScheduleRequests$'
            $script:Posts[0].Body.action | Should -Be 'adminRemove'
        }

        It 'removes an active assignment when another Global Administrator remains' {
            $Result = Invoke-CIPPPIMAssignmentAction -TenantFilter 'contoso.onmicrosoft.com' -Action Remove -PrincipalId 'user-1' -RoleDefinitionId $script:GA -AssignmentType Permanent -Justification 'test'
            $Result.After | Should -Be 'None'
            $script:Posts[0].Uri | Should -Match 'roleAssignmentScheduleRequests$'
            $script:Posts[0].Body.action | Should -Be 'adminRemove'
        }
    }
}
