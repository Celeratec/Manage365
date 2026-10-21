function Invoke-CIPPPIMAssignmentAction {
    <#
    .SYNOPSIS
        Performs a secure-direction change to a directory role assignment through PIM.

    .DESCRIPTION
        The single write path for role assignments in CIPP's PIM surfaces, used by the
        ExecPIMRoleAssignment endpoint (and any future standard or automation that changes assignments).

        Actions:
          ConvertToEligible  permanent/time-bound active -> eligible. Creates the eligibility, READS
                             IT BACK to confirm it exists, and only then removes the active
                             assignment. A principal never loses access without gaining eligibility.
          GrantEligible      nothing (or a time-bound active) -> eligible, via adminAssign on
                             roleEligibilityScheduleRequests. A permanent assignment is left for
                             ConvertToEligible, which removes it only after eligibility exists.
          GrantActive        eligible (or nothing) -> time-bound active assignment (the JIT equivalent;
                             Entra removes it at the end date).
          Extend / Renew     push out the end of a time-bound active assignment or an eligibility.
          Remove             remove an eligibility or an active assignment.

        What it refuses, regardless of caller:
          - anything without an expiration (New-CIPPPIMScheduleRequest throws);
          - a lifetime above MaxRoleAssignmentDuration (Config/RoleAssignment.json, default P365D).
            A shorter tenant PIM policy is not applied here; Graph's own refusal is returned;
          - rows inherited through a group (MemberType 'Group') - the group's assignment is the
            real one;
          - the CIPP-SAM service principal's own assignments;
          - removing or converting the LAST active Global Administrator;
          - converting a service principal (PIM eligibility is users and groups only).

        Every change is logged with the assignment type before and after.

    .PARAMETER AssignmentType
        The row's current type (Permanent | Active | ActivatedFromEligible | Eligible). Decides
        whether Extend/Renew/Remove target the eligibility or the assignment schedule.

    .PARAMETER Duration
        ISO 8601 lifetime for the new/extended schedule. Mutually exclusive with -EndDateTime.

    .OUTPUTS
        PSCustomObject: resultText, state, Before, After, EndDateTime.

    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ConvertToEligible', 'GrantEligible', 'GrantActive', 'Extend', 'Renew', 'Remove')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$RoleDefinitionId,

        [string]$DirectoryScopeId = '/',

        [ValidateSet('', 'Permanent', 'Active', 'ActivatedFromEligible', 'Eligible')]
        [string]$AssignmentType = '',

        [string]$Duration,

        [datetime]$EndDateTime,

        [datetime]$StartDateTime,

        [string]$Justification,

        # IANA time zone of the caller (the browser sends it) used only to word end times in the
        # result text; UTC when absent or unknown. Never changes what is written to Graph.
        [string]$TimeZone,

        $Headers,

        [string]$APIName = 'PIMRoleAssignment'
    )

    $GlobalAdminTemplateId = '62e90394-69f5-4237-9190-012177145e10'
    # End times are stored in UTC; word them in the caller's zone so "until 08:06" reads as the
    # time the operator will see on their clock. Falls back to UTC (labelled) for an unknown zone.
    $Zone = $null
    if (-not [string]::IsNullOrWhiteSpace($TimeZone)) {
        try { $Zone = [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZone) } catch { $Zone = $null }
    }
    $FormatEnd = {
        param($Value)
        if ($null -eq $Value -or "$Value" -eq '') { return '' }
        $Utc = if ($Value -is [datetime]) {
            if ($Value.Kind -eq 'Local') { $Value.ToUniversalTime() } else { [datetime]::SpecifyKind($Value, 'Utc') }
        } else { ([datetime]$Value).ToUniversalTime() }
        if ($Zone) { "$([System.TimeZoneInfo]::ConvertTimeFromUtc($Utc, $Zone).ToString('yyyy-MM-dd HH:mm')) ($TimeZone)" } else { "$($Utc.ToString('yyyy-MM-dd HH:mm')) UTC" }
    }
    if ([string]::IsNullOrWhiteSpace($DirectoryScopeId)) { $DirectoryScopeId = '/' }
    if ([string]::IsNullOrWhiteSpace($Justification)) { $Justification = 'Changed via CIPP' }

    $PIMCapable = [bool](Test-CIPPStandardLicense -StandardName 'PIMRoleAssignment' -TenantFilter $TenantFilter -Preset EntraP2 -SkipLog)
    if (-not $PIMCapable) {
        throw [System.ArgumentException]::new("Tenant $TenantFilter is not licensed for Entra ID P2 / Privileged Identity Management, so PIM assignment changes are not available. Assignments can still be removed from the PIM page.")
    }

    # Current state for this principal (cheap: filtered at Graph) and the role's policy caps.
    $PrincipalRows = @(Get-CIPPPIMRoleAssignments -TenantFilter $TenantFilter -PrincipalId $PrincipalId)
    $RoleRows = @($PrincipalRows | Where-Object { $_.RoleDefinitionId -eq $RoleDefinitionId -and $_.DirectoryScopeId -eq $DirectoryScopeId })
    $RoleName = ($RoleRows | Select-Object -First 1).RoleDisplayName ?? $RoleDefinitionId
    $PrincipalName = ($PrincipalRows | Where-Object { $_.PrincipalUserPrincipalName -or $_.PrincipalDisplayName } | Select-Object -First 1)
    # Groups and service principals have no UPN (and the value may be '' rather than $null).
    $PrincipalLabel = @($PrincipalName.PrincipalUserPrincipalName, $PrincipalName.PrincipalDisplayName, $PrincipalId) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    $PrincipalType = ($PrincipalRows | Select-Object -First 1).PrincipalType
    $PrincipalAppId = ($PrincipalRows | Select-Object -First 1).PrincipalAppId

    $ActiveRow = $RoleRows | Where-Object { $_.AssignmentType -in @('Permanent', 'Active', 'ActivatedFromEligible') } | Select-Object -First 1
    $EligibleRow = $RoleRows | Where-Object { $_.AssignmentType -eq 'Eligible' } | Select-Object -First 1
    $TargetRow = switch ($AssignmentType) {
        'Eligible' { $EligibleRow }
        '' { $ActiveRow ?? $EligibleRow }
        default { $ActiveRow }
    }

    if ($TargetRow -and $TargetRow.MemberType -eq 'Group') {
        throw [System.ArgumentException]::new("$PrincipalLabel holds $RoleName through a role-assignable group. Change the group's assignment instead of the member's.")
    }
    if ($PrincipalAppId -and $env:ApplicationID -and $PrincipalAppId -eq $env:ApplicationID) {
        throw [System.ArgumentException]::new("Refusing to change the CIPP-SAM application's own role assignment for $RoleName.")
    }

    $Before = if ($TargetRow) {
        "$($TargetRow.AssignmentType)$(if ($TargetRow.EndDateTime) { " until $(& $FormatEnd $TargetRow.EndDateTime)" })"
    } else {
        'None'
    }

    $AssignmentCeiling = Get-CIPPMaxRoleAssignmentDuration
    $Caller = 'Unknown'
    if ($Headers -and $Headers.'x-ms-client-principal') {
        try {
            $Caller = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String([string]$Headers.'x-ms-client-principal')) | ConvertFrom-Json).userDetails
        } catch {
            Write-Information "Could not read the caller from the client principal: $($_.Exception.Message)"
        }
    }

    function Test-LastGlobalAdmin {
        if ($RoleDefinitionId -ne $GlobalAdminTemplateId) { return }
        $OtherActive = @(Get-CIPPPIMRoleAssignments -TenantFilter $TenantFilter -RoleDefinitionId $GlobalAdminTemplateId | Where-Object {
                $_.AssignmentType -in @('Permanent', 'Active', 'ActivatedFromEligible') -and $_.PrincipalId -ne $PrincipalId
            })
        if ($OtherActive.Count -eq 0) {
            throw [System.ArgumentException]::new("Refusing: $PrincipalLabel is the last active Global Administrator in $TenantFilter. Assign another active Global Administrator first.")
        }
    }

    function Send-ScheduleRequest {
        param($Request)
        $Json = ConvertTo-Json -InputObject $Request.Body -Depth 10 -Compress
        try {
            return New-GraphPOSTRequest -uri $Request.Uri -body $Json -tenantid $TenantFilter -AsApp $true
        } catch {
            $GraphMessage = Get-CIPPGraphErrorMessage -ErrorRecord $_
            if ($GraphMessage -match 'Expiration_Admin_|Expiration_EndUser_|policy rules failed|maximum duration|maximum allowed') {
                throw [System.ArgumentException]::new($GraphMessage)
            }
            if (-not [string]::IsNullOrWhiteSpace($GraphMessage)) {
                throw $GraphMessage
            }
            throw
        }
    }

    function Invoke-ActiveAssignmentRemoval {
        # adminRemove covers PIM-created and legacy direct assignments alike; the unified RBAC
        # delete is only a fallback for the rare record PIM does not recognise.
        $Request = New-CIPPPIMScheduleRequest -Kind Assignment -Action adminRemove -PrincipalId $PrincipalId -RoleDefinitionId $RoleDefinitionId -DirectoryScopeId $DirectoryScopeId -Justification $Justification
        try {
            $null = Send-ScheduleRequest -Request $Request
        } catch {
            # Entra refuses to retire an active assignment younger than five minutes
            # ("The Active duration is too short. Minimum Required is 5 minutes").
            if ($_.Exception.Message -match 'duration is too short') {
                throw [System.ArgumentException]::new("Entra requires an active assignment to exist for at least 5 minutes before it can be removed; $PrincipalLabel's $RoleName assignment was created too recently. Try again in a few minutes.")
            }
            if ($_.Exception.Message -notmatch 'RoleAssignmentDoesNotExist|does not exist|NotFound|not found') { throw }
            $Existing = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$PrincipalId' and roleDefinitionId eq '$RoleDefinitionId'" -tenantid $TenantFilter | Where-Object { ($_.directoryScopeId ?? '/') -eq $DirectoryScopeId })
            if ($Existing.Count -eq 0) { throw }
            foreach ($Assignment in $Existing) {
                $null = New-GraphPOSTRequest -type DELETE -uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments/$($Assignment.id)" -tenantid $TenantFilter
            }
        }
        # Graph accepts the removal (status Revoked) and retires the instance a few seconds later;
        # wait for that so the reported state - and the table refresh behind it - is the real one.
        for ($Attempt = 0; $Attempt -lt 8; $Attempt++) {
            $Remaining = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?`$filter=principalId eq '$PrincipalId' and roleDefinitionId eq '$RoleDefinitionId'" -tenantid $TenantFilter -AsApp $true | Where-Object { ($_.directoryScopeId ?? '/') -eq $DirectoryScopeId })
            if ($Remaining.Count -eq 0) { return $true }
            Start-Sleep -Seconds 3
        }
        return $false
    }

    $DurationParams = @{}
    if (-not [string]::IsNullOrWhiteSpace($Duration)) { $DurationParams.Duration = $Duration }
    if ($PSBoundParameters.ContainsKey('EndDateTime') -and $EndDateTime -gt [datetime]::MinValue) { $DurationParams.EndDateTime = $EndDateTime }
    if ($PSBoundParameters.ContainsKey('StartDateTime') -and $StartDateTime -gt [datetime]::MinValue) { $DurationParams.StartDateTime = $StartDateTime }

    if (-not $PSCmdlet.ShouldProcess("$PrincipalLabel / $RoleName in $TenantFilter", $Action)) { return }

    $After = $Before
    $ResultEnd = $null
    $ResultStart = $null
    $Request = $null
    switch ($Action) {
        'ConvertToEligible' {
            if (-not $ActiveRow) { throw [System.ArgumentException]::new("$PrincipalLabel has no active $RoleName assignment to convert.") }
            if ($PrincipalType -eq 'ServicePrincipal') { throw [System.ArgumentException]::new("$PrincipalLabel is a service principal; PIM eligibility is only supported for users and groups. Remove the assignment instead if it is not needed.") }
            Test-LastGlobalAdmin

            if ($DurationParams.Count -eq 0) { $DurationParams.Duration = $AssignmentCeiling }
            if (-not $EligibleRow) {
                $Request = New-CIPPPIMScheduleRequest -Kind Eligibility -Action adminAssign -PrincipalId $PrincipalId -RoleDefinitionId $RoleDefinitionId -DirectoryScopeId $DirectoryScopeId -Justification $Justification @DurationParams
                try {
                    $null = Send-ScheduleRequest -Request $Request
                } catch {
                    if ($_.Exception.Message -notmatch 'RoleAssignmentExists|already exists') { throw }
                }
                $ResultEnd = $Request.EndDateTime
            } else {
                $ResultEnd = $EligibleRow.EndDateTime
            }

            # Verify the eligibility is really there before taking the active assignment away.
            $Confirmed = $null
            for ($Attempt = 0; $Attempt -lt 6 -and -not $Confirmed; $Attempt++) {
                if ($Attempt -gt 0) { Start-Sleep -Seconds 2 }
                $Confirmed = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilitySchedules?`$filter=principalId eq '$PrincipalId' and roleDefinitionId eq '$RoleDefinitionId'" -tenantid $TenantFilter -AsApp $true | Where-Object { ($_.directoryScopeId ?? '/') -eq $DirectoryScopeId } | Select-Object -First 1
            }
            if (-not $Confirmed) {
                throw "The eligibility for $PrincipalLabel on $RoleName could not be confirmed; the active assignment was left in place."
            }

            $RemovalSeen = Invoke-ActiveAssignmentRemoval
            $After = "Eligible$(if ($ResultEnd) { " until $(& $FormatEnd $ResultEnd)" })"
            $ResultText = "Converted $PrincipalLabel on $RoleName from $Before to $After.$(if (-not $RemovalSeen) { ' The removal of the active assignment was accepted by Entra and is still propagating; refresh in a minute.' })"
            if ($Request) { $ResultStart = $Request.StartDateTime }
        }
        'GrantEligible' {
            if ($DurationParams.Count -eq 0) { throw [System.ArgumentException]::new('GrantEligible needs a Duration or EndDateTime.') }
            if ($PrincipalType -eq 'ServicePrincipal') { throw [System.ArgumentException]::new("$PrincipalLabel is a service principal; PIM eligibility is only supported for users and groups.") }
            if ($EligibleRow) { throw [System.ArgumentException]::new("$PrincipalLabel already holds an eligible $RoleName assignment.") }
            if ($ActiveRow -and $ActiveRow.AssignmentType -eq 'Permanent') { throw [System.ArgumentException]::new("$PrincipalLabel holds $RoleName permanently. Convert it to eligible instead of granting a second eligibility.") }
            $Request = New-CIPPPIMScheduleRequest -Kind Eligibility -Action adminAssign -PrincipalId $PrincipalId -RoleDefinitionId $RoleDefinitionId -DirectoryScopeId $DirectoryScopeId -Justification $Justification @DurationParams
            $null = Send-ScheduleRequest -Request $Request
            $ResultEnd = $Request.EndDateTime
            $ResultStart = $Request.StartDateTime
            $After = "Eligible until $(& $FormatEnd $ResultEnd)"
            $ResultText = "Granted $PrincipalLabel an eligible $RoleName assignment until $(& $FormatEnd $ResultEnd)."
        }
        'GrantActive' {
            if ($DurationParams.Count -eq 0) { throw [System.ArgumentException]::new('GrantActive needs a Duration or EndDateTime.') }
            if ($ActiveRow -and $ActiveRow.AssignmentType -eq 'Permanent') { throw [System.ArgumentException]::new("$PrincipalLabel already holds $RoleName permanently; convert it to eligible instead.") }
            $Request = New-CIPPPIMScheduleRequest -Kind Assignment -Action adminAssign -PrincipalId $PrincipalId -RoleDefinitionId $RoleDefinitionId -DirectoryScopeId $DirectoryScopeId -Justification $Justification @DurationParams
            $null = Send-ScheduleRequest -Request $Request
            $ResultEnd = $Request.EndDateTime
            $ResultStart = $Request.StartDateTime
            $After = "Active until $(& $FormatEnd $ResultEnd)"
            $ResultText = "Granted $PrincipalLabel a time-bound active $RoleName assignment until $(& $FormatEnd $ResultEnd)."
        }
        { $_ -in @('Extend', 'Renew') } {
            if (-not $TargetRow) { throw [System.ArgumentException]::new("$PrincipalLabel has no $RoleName assignment to $($Action.ToLower()).") }
            if ($TargetRow.AssignmentType -eq 'Permanent') { throw [System.ArgumentException]::new("A permanent assignment cannot be extended; convert it to eligible instead.") }
            if ($DurationParams.Count -eq 0) { throw [System.ArgumentException]::new("$Action needs a Duration or EndDateTime.") }
            $Kind = if ($TargetRow.AssignmentType -eq 'Eligible') { 'Eligibility' } else { 'Assignment' }
            $GraphAction = if ($Action -eq 'Extend') { 'adminExtend' } else { 'adminRenew' }
            $Request = New-CIPPPIMScheduleRequest -Kind $Kind -Action $GraphAction -PrincipalId $PrincipalId -RoleDefinitionId $RoleDefinitionId -DirectoryScopeId $DirectoryScopeId -Justification $Justification @DurationParams
            $null = Send-ScheduleRequest -Request $Request
            $ResultEnd = $Request.EndDateTime
            $ResultStart = $Request.StartDateTime
            $After = "$($TargetRow.AssignmentType) until $(& $FormatEnd $ResultEnd)"
            $ResultText = "$($Action)ed $PrincipalLabel's $($TargetRow.AssignmentType.ToLower()) $RoleName assignment until $(& $FormatEnd $ResultEnd)."
        }
        'Remove' {
            if (-not $TargetRow) { throw [System.ArgumentException]::new("$PrincipalLabel has no $RoleName assignment to remove.") }
            $RemovalSeen = $true
            if ($TargetRow.AssignmentType -eq 'Eligible') {
                $Request = New-CIPPPIMScheduleRequest -Kind Eligibility -Action adminRemove -PrincipalId $PrincipalId -RoleDefinitionId $RoleDefinitionId -DirectoryScopeId $DirectoryScopeId -Justification $Justification
                $null = Send-ScheduleRequest -Request $Request
            } else {
                Test-LastGlobalAdmin
                $RemovalSeen = Invoke-ActiveAssignmentRemoval
            }
            $After = 'None'
            $ResultText = "Removed $PrincipalLabel's $($TargetRow.AssignmentType.ToLower()) $RoleName assignment.$(if (-not $RemovalSeen) { ' Entra accepted the removal and is still propagating it; refresh in a minute.' })"
        }
    }

    $LogData = @{
        Action           = $Action
        PrincipalId      = $PrincipalId
        Principal        = $PrincipalLabel
        RoleDefinitionId = $RoleDefinitionId
        Role             = $RoleName
        DirectoryScopeId = $DirectoryScopeId
        Before           = $Before
        After            = $After
        Justification    = $Justification
        Start            = $ResultStart
        End              = $ResultEnd
        Caller           = $Caller
    }
    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "$ResultText Tenant: $TenantFilter. User: $PrincipalLabel. Role: $RoleName. Start: $ResultStart. End: $ResultEnd. Caller: $Caller. (before: $Before, after: $After)" -Sev 'Info' -LogData $LogData

    return [PSCustomObject]@{
        resultText  = $ResultText
        state       = 'success'
        Before      = $Before
        After       = $After
        EndDateTime = $ResultEnd
    }
}
