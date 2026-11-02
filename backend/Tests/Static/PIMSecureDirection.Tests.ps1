# Source invariant: CIPP's PIM surfaces only move privileged access in the secure direction.
#
# The maintainer's rule is that CIPP must be able to convert permanent assignments to eligible and
# create time-bound active assignments, but must never - through any UI, standard, template, API
# or MCP path - create a permanent assignment, convert eligible to permanent, or weaken PIM role
# settings below the secure floor. New-CIPPPIMScheduleRequest enforces the expiration rule and
# Test-CIPPPIMRoleSettingsFloor the settings rule; this test makes sure nothing routes around them:
#
#   1. the PIM schedule-request endpoints are only addressed from the builder, so every request
#      body passes its expiration checks;
#   2. no PIM-related source assigns a 'noExpiration' schedule;
#   3. no PIM-related source re-introduces the legacy permanent directoryRoles/members/$ref write;
#   4. every file that PATCHes a PIM role policy rule validates against the floor first.

BeforeAll {
    $BackendRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $ModulesRoot = Join-Path $BackendRoot 'Modules'

    $script:PIMFiles = @(
        Get-ChildItem -Path (Join-Path $ModulesRoot 'CIPPCore/Public/PIM') -Filter '*.ps1' -File
        Get-ChildItem -Path (Join-Path $ModulesRoot 'CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Roles') -Filter '*.ps1' -File
        Get-ChildItem -Path (Join-Path $ModulesRoot 'CIPPStandards/Public/Standards') -Filter 'Invoke-CIPPStandardPIM*.ps1' -File
        Get-ChildItem -Path (Join-Path $ModulesRoot 'CIPPAlerts/Public/Alerts') -Filter 'Get-CIPPAlertPermanentActiveAdminAssigned.ps1' -File
    )
    if ($script:PIMFiles.Count -lt 10) { throw "Expected the PIM source set to be present; found $($script:PIMFiles.Count) files" }

    $script:Sources = foreach ($File in $script:PIMFiles) {
        [pscustomobject]@{ Name = $File.Name; Text = [System.IO.File]::ReadAllText($File.FullName) }
    }

    $script:AllSources = foreach ($File in (Get-ChildItem -Path $ModulesRoot -Filter '*.ps1' -File -Recurse)) {
        [pscustomobject]@{ Name = $File.Name; Text = [System.IO.File]::ReadAllText($File.FullName) }
    }
}

Describe 'PIM secure-direction invariants' {
    It 'addresses the schedule-request endpoints only from New-CIPPPIMScheduleRequest' {
        # Use AST to ignore doc comments, check both string literals and interpolated strings
        $Offenders = @()
        foreach ($Source in $script:AllSources | Where-Object { $_.Name -ne 'New-CIPPPIMScheduleRequest.ps1' }) {
            $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Source.Text, [ref]$null, [ref]$null)
            $Strings = $Ast.FindAll({
                $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                $args[0] -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
            }, $true)
            $Pattern = [regex]'role(Eligibility|Assignment)ScheduleRequests'
            foreach ($String in $Strings) {
                if ($Pattern.IsMatch($String.Value)) {
                    $Offenders += $Source.Name
                    break
                }
            }
        }
        # The builder's tests mention the URIs in assertions; sources elsewhere may not.
        $Offenders | Should -BeNullOrEmpty -Because 'every schedule request must go through the builder that refuses no-expiration schedules'
    }

    It 'never assigns a noExpiration schedule type' {
        # The string may appear in a rejection regex or in read-side detection, never as a value
        # being set on a request.
        $Pattern = [regex]"(type|expiration)\s*=\s*['""]noExpiration['""]"
        $Offenders = @($script:Sources | Where-Object { $Pattern.IsMatch($_.Text) } | ForEach-Object { $_.Name })
        $Offenders | Should -BeNullOrEmpty
    }

    It 'does not re-introduce the permanent directoryRoles member write' {
        $Pattern = [regex]'directoryRoles[^\r\n]*members/\$ref'
        $Offenders = @($script:Sources | Where-Object { $Pattern.IsMatch($_.Text) } | ForEach-Object { $_.Name })
        $Offenders | Should -BeNullOrEmpty -Because 'the PIM surfaces must not create permanent role memberships'
    }

    It 'validates against the secure floor wherever role policy rules are written' {
        $Writers = @($script:AllSources | Where-Object { $_.Text -match 'roleManagementPolicies/[^\r\n]*?/rules/' -and $_.Text -match 'PATCH' })
        $Writers.Count | Should -BeGreaterThan 0
        foreach ($Writer in $Writers) {
            # Set-CIPPPIMRoleSettings is the writer; its callers must have run the floor check.
            $Writer.Name | Should -Be 'Set-CIPPPIMRoleSettings.ps1'
        }
        $Callers = @($script:AllSources | Where-Object { $_.Name -ne 'Set-CIPPPIMRoleSettings.ps1' -and $_.Text -match 'Set-CIPPPIMRoleSettings\b' -and $_.Name -notlike '*.Tests.ps1' })
        $Callers.Count | Should -BeGreaterThan 0
        foreach ($Caller in $Callers) {
            $Caller.Text | Should -Match 'Test-CIPPPIMRoleSettingsFloor' -Because "$($Caller.Name) writes PIM policy rules and must validate the floor first"
        }
    }

    It 'keeps every secure-direction action inside Invoke-CIPPPIMAssignmentAction or the builder' {
        # Use AST to find all CommandAst nodes named New-CIPPPIMScheduleRequest, ignoring comments.
        # PIM-VALIDATION-ONLY marker at Invoke-ExecPIMRoleAssignment.ps1:~100 exempts that one call.
        $Direct = @()
        foreach ($Source in $script:Sources | Where-Object { $_.Name -notin @('New-CIPPPIMScheduleRequest.ps1', 'Invoke-CIPPPIMAssignmentAction.ps1') }) {
            $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Source.Text, [ref]$null, [ref]$null)
            $Commands = $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
            foreach ($Cmd in $Commands) {
                $CmdName = $Cmd.GetCommandName()
                if ($CmdName -eq 'New-CIPPPIMScheduleRequest') {
                    # Check if this line has the PIM-VALIDATION-ONLY marker
                    $Line = $Source.Text.Substring(0, $Cmd.Extent.StartOffset) + $Source.Text.Substring($Cmd.Extent.StartOffset, $Cmd.Extent.EndOffset - $Cmd.Extent.StartOffset)
                    $FullLine = ($Source.Text -split "`r?`n")[$Cmd.Extent.StartLineNumber - 1]
                    if ($FullLine -notmatch 'PIM-VALIDATION-ONLY') {
                        $Direct += "$($Source.Name):$($Cmd.Extent.StartLineNumber)"
                    }
                }
            }
        }
        $Direct | Should -BeNullOrEmpty -Because 'every secure-direction action must go through Invoke-CIPPPIMAssignmentAction or the builder'
    }

    It 'PIM-VALIDATION-ONLY marker appears only in Invoke-ExecPIMRoleAssignment.ps1 at about line 100' {
        $Violations = @()
        foreach ($Source in $script:AllSources) {
            $Lines = $Source.Text -split "`r?`n"
            for ($i = 0; $i -lt $Lines.Count; $i++) {
                if ($Lines[$i] -match 'PIM-VALIDATION-ONLY') {
                    if ($Source.Name -ne 'Invoke-ExecPIMRoleAssignment.ps1' -or ($i + 1) -lt 95 -or ($i + 1) -gt 105) {
                        $Violations += "$($Source.Name):$($i + 1)"
                    }
                }
            }
        }
        $Violations | Should -BeNullOrEmpty -Because 'the PIM-VALIDATION-ONLY marker must only appear at Invoke-ExecPIMRoleAssignment.ps1:~100'
    }

    It 'fixture: AST filter detects command calls, ignores strings/comments, catches interpolated URIs, validates marker scope' {
        # Test 1: Named-parameter call - should be detected
        $NamedCall = 'New-CIPPPIMScheduleRequest -Kind adminAssign -Duration P365D'
        $Ast1 = [System.Management.Automation.Language.Parser]::ParseInput($NamedCall, [ref]$null, [ref]$null)
        $Cmds1 = @($Ast1.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true))
        $Cmds1.Count | Should -Be 1
        $Cmds1[0].GetCommandName() | Should -Be 'New-CIPPPIMScheduleRequest'

        # Test 2: '#' in a string should not be treated as a comment
        $InString = 'Write-Host "New-CIPPPIMScheduleRequest # not a call"'
        $Ast2 = [System.Management.Automation.Language.Parser]::ParseInput($InString, [ref]$null, [ref]$null)
        $Cmds2 = @($Ast2.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true))
        @($Cmds2 | Where-Object { $_.GetCommandName() -eq 'New-CIPPPIMScheduleRequest' }).Count | Should -Be 0

        # Test 3: Block comment should be ignored
        $BlockComment = @'
<# 
New-CIPPPIMScheduleRequest -Kind adminAssign
#>
Write-Host "test"
'@
        $Ast3 = [System.Management.Automation.Language.Parser]::ParseInput($BlockComment, [ref]$null, [ref]$null)
        $Cmds3 = @($Ast3.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true))
        @($Cmds3 | Where-Object { $_.GetCommandName() -eq 'New-CIPPPIMScheduleRequest' }).Count | Should -Be 0

        # Test 4: Interpolated URI with roleAssignmentScheduleRequests should be detected
        $InterpolatedUri = '$Uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests/$Id"'
        $Ast4 = [System.Management.Automation.Language.Parser]::ParseInput($InterpolatedUri, [ref]$null, [ref]$null)
        $Strings4 = $Ast4.FindAll({
            $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            $args[0] -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
        }, $true)
        $Pattern = [regex]'role(Eligibility|Assignment)ScheduleRequests'
        @($Strings4 | Where-Object { $Pattern.IsMatch($_.Value) }).Count | Should -Be 1

        # Test 5: Marker in wrong file should be detected (tested by separate It block)
        $WrongFile = '# PIM-VALIDATION-ONLY marker here'
        ($WrongFile -match 'PIM-VALIDATION-ONLY') | Should -BeTrue
    }
}
