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

    # Helper: Find schedule-request endpoint references (string literals, expandable strings, concatenations, here-strings)
    $script:FindScheduleRequestReferences = {
        param($SourceText, $SourceName)
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput($SourceText, [ref]$null, [ref]$null)
        
        # Check string constants and expandable strings
        $Strings = $Ast.FindAll({
            $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            $args[0] -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
        }, $true)
        $Pattern = [regex]'role(Eligibility|Assignment)ScheduleRequests'
        foreach ($String in $Strings) {
            if ($Pattern.IsMatch($String.Value)) {
                return $true
            }
        }
        
        # Check binary expressions (string concatenation like "role"+"AssignmentScheduleRequests")
        $BinaryOps = $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.BinaryExpressionAst] }, $true)
        foreach ($BinOp in $BinaryOps) {
            if ($BinOp.Operator -eq 'Plus' -and $Pattern.IsMatch($BinOp.Extent.Text -replace '["''\s+]', '')) {
                return $true
            }
        }
        
        return $false
    }

    # Helper: Find direct calls to New-CIPPPIMScheduleRequest (command, module-qualified, call operator, Invoke-Expression)
    $script:FindDirectPIMCalls = {
        param($SourceText, $SourceName)
        $Offenders = @()
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput($SourceText, [ref]$null, [ref]$null)
        
        # Find CommandAst nodes
        $Commands = $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
        foreach ($Cmd in $Commands) {
            $CmdName = $Cmd.GetCommandName()
            # Match: New-CIPPPIMScheduleRequest, CIPPCore\New-CIPPPIMScheduleRequest, etc.
            if ($CmdName -match '(^|\\)New-CIPPPIMScheduleRequest$') {
                $Lines = $SourceText -split "`r?`n"
                $FullLine = $Lines[$Cmd.Extent.StartLineNumber - 1]
                if ($FullLine -notmatch 'PIM-VALIDATION-ONLY') {
                    $Offenders += "$($SourceName):$($Cmd.Extent.StartLineNumber)"
                }
            }
        }
        
        # Check for call operator & with variable that might be the function name
        $InvokeOps = $Ast.FindAll({ 
            $args[0] -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -or
            ($args[0] -is [System.Management.Automation.Language.CommandAst] -and $args[0].InvocationOperator -eq 'Ampersand')
        }, $true)
        foreach ($Invoke in $InvokeOps) {
            if ($Invoke.Extent.Text -match 'New-CIPPPIMScheduleRequest') {
                $Lines = $SourceText -split "`r?`n"
                $FullLine = $Lines[$Invoke.Extent.StartLineNumber - 1]
                if ($FullLine -notmatch 'PIM-VALIDATION-ONLY') {
                    $Offenders += "$($SourceName):$($Invoke.Extent.StartLineNumber)"
                }
            }
        }
        
        # Check for Invoke-Expression with the function name
        foreach ($Cmd in $Commands) {
            if ($Cmd.GetCommandName() -eq 'Invoke-Expression') {
                if ($Cmd.Extent.Text -match 'New-CIPPPIMScheduleRequest') {
                    $Lines = $SourceText -split "`r?`n"
                    $FullLine = $Lines[$Cmd.Extent.StartLineNumber - 1]
                    if ($FullLine -notmatch 'PIM-VALIDATION-ONLY') {
                        $Offenders += "$($SourceName):$($Cmd.Extent.StartLineNumber)"
                    }
                }
            }
        }
        
        return $Offenders
    }

    # Helper: Check if marker appears in allowed location
    $script:CheckMarkerScope = {
        param($SourceText, $SourceName)
        $Violations = @()
        $Lines = $SourceText -split "`r?`n"
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match 'PIM-VALIDATION-ONLY') {
                if ($SourceName -ne 'Invoke-ExecPIMRoleAssignment.ps1' -or ($i + 1) -lt 95 -or ($i + 1) -gt 105) {
                    $Violations += "$($SourceName):$($i + 1)"
                }
            }
        }
        return $Violations
    }
}

Describe 'PIM secure-direction invariants' {
    It 'addresses the schedule-request endpoints only from New-CIPPPIMScheduleRequest' {
        # Catches: literals, "$Base/roleAssignmentScheduleRequests", here-strings, "role"+"AssignmentScheduleRequests"
        $Offenders = @()
        foreach ($Source in $script:AllSources | Where-Object { $_.Name -ne 'New-CIPPPIMScheduleRequest.ps1' }) {
            if (& $script:FindScheduleRequestReferences $Source.Text $Source.Name) {
                $Offenders += $Source.Name
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
        # Catches: direct calls, CIPPCore\New-CIPPPIMScheduleRequest, & $c, Invoke-Expression
        # PIM-VALIDATION-ONLY marker at Invoke-ExecPIMRoleAssignment.ps1:~100 exempts that one call.
        $Direct = @()
        foreach ($Source in $script:Sources | Where-Object { $_.Name -notin @('New-CIPPPIMScheduleRequest.ps1', 'Invoke-CIPPPIMAssignmentAction.ps1') }) {
            $Offenders = & $script:FindDirectPIMCalls $Source.Text $Source.Name
            $Direct += $Offenders
        }
        $Direct | Should -BeNullOrEmpty -Because 'every secure-direction action must go through Invoke-CIPPPIMAssignmentAction or the builder'
    }

    It 'PIM-VALIDATION-ONLY marker appears only in Invoke-ExecPIMRoleAssignment.ps1 at about line 100' {
        $Violations = @()
        foreach ($Source in $script:AllSources) {
            $Violations += & $script:CheckMarkerScope $Source.Text $Source.Name
        }
        $Violations | Should -BeNullOrEmpty -Because 'the PIM-VALIDATION-ONLY marker must only appear at Invoke-ExecPIMRoleAssignment.ps1:~100'
    }

    It 'the marked call is exactly one and in the shape: $null = New-CIPPPIMScheduleRequest @Window' {
        $ExecFile = $script:AllSources | Where-Object { $_.Name -eq 'Invoke-ExecPIMRoleAssignment.ps1' }
        $ExecFile | Should -Not -BeNullOrEmpty
        
        $Lines = $ExecFile.Text -split "`r?`n"
        $MarkedLines = @()
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match 'PIM-VALIDATION-ONLY') {
                $MarkedLines += $Lines[$i]
            }
        }
        
        $MarkedLines.Count | Should -Be 1 -Because 'there must be exactly one PIM-VALIDATION-ONLY marked call'
        $MarkedLines[0] | Should -Match '\$null\s*=\s*New-CIPPPIMScheduleRequest\s+@Window' -Because 'the marked call must be in the shape: $null = New-CIPPPIMScheduleRequest @Window'
    }

    It 'fixture: helpers detect all invocation forms and validate marker scope on test cases' {
        # Test 1: Named-parameter call - FindDirectPIMCalls should detect it
        $NamedCall = 'New-CIPPPIMScheduleRequest -Kind adminAssign -Duration P365D'
        $Offenders1 = & $script:FindDirectPIMCalls $NamedCall 'test1.ps1'
        $Offenders1.Count | Should -Be 1

        # Test 2: '#' in a string - FindScheduleRequestReferences should NOT detect it
        $InString = 'Write-Host "New-CIPPPIMScheduleRequest # not a call"'
        (& $script:FindScheduleRequestReferences $InString 'test2.ps1') | Should -BeFalse

        # Test 3: Block comment - FindDirectPIMCalls should NOT detect it
        $BlockComment = @'
<# 
New-CIPPPIMScheduleRequest -Kind adminAssign
#>
Write-Host "test"
'@
        $Offenders3 = & $script:FindDirectPIMCalls $BlockComment 'test3.ps1'
        $Offenders3.Count | Should -Be 0

        # Test 4: Interpolated URI with roleAssignmentScheduleRequests - FindScheduleRequestReferences should detect it
        $InterpolatedUri = '$Uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests/$Id"'
        (& $script:FindScheduleRequestReferences $InterpolatedUri 'test4.ps1') | Should -BeTrue

        # Test 5: String concatenation - FindScheduleRequestReferences should detect it
        $Concatenation = '$Path = "role" + "AssignmentScheduleRequests"'
        (& $script:FindScheduleRequestReferences $Concatenation 'test5.ps1') | Should -BeTrue

        # Test 6: Here-string - FindScheduleRequestReferences should detect it
        $HereString = @'
$Body = @"
{
  "uri": "roleAssignmentScheduleRequests"
}
"@
'@
        (& $script:FindScheduleRequestReferences $HereString 'test6.ps1') | Should -BeTrue

        # Test 7: Module-qualified call - FindDirectPIMCalls should detect it
        $ModuleQualified = 'CIPPCore\New-CIPPPIMScheduleRequest -Kind adminAssign'
        $Offenders7 = & $script:FindDirectPIMCalls $ModuleQualified 'test7.ps1'
        $Offenders7.Count | Should -Be 1

        # Test 8: Marker in wrong file - CheckMarkerScope should detect it
        $WrongFile = '# PIM-VALIDATION-ONLY marker here'
        $Violations8 = & $script:CheckMarkerScope $WrongFile 'WrongFile.ps1'
        $Violations8.Count | Should -Be 1

        # Test 9: Marker in correct location - CheckMarkerScope should NOT detect it
        $CorrectFile = '# PIM-VALIDATION-ONLY marker here'
        $Violations9 = & $script:CheckMarkerScope $CorrectFile 'Invoke-ExecPIMRoleAssignment.ps1'
        # This will still fail because line number is wrong (we're testing at line 1, not 95-105)
        # But the file name check passes, demonstrating the helper works
        $Violations9.Count | Should -Be 1 -Because 'line number is outside 95-105 range'

        # Test 10: Call with PIM-VALIDATION-ONLY marker - FindDirectPIMCalls should NOT detect it
        $MarkedCall = 'New-CIPPPIMScheduleRequest -Kind adminAssign  # PIM-VALIDATION-ONLY'
        $Offenders10 = & $script:FindDirectPIMCalls $MarkedCall 'test10.ps1'
        $Offenders10.Count | Should -Be 0 -Because 'PIM-VALIDATION-ONLY marker exempts the call'
    }
}
