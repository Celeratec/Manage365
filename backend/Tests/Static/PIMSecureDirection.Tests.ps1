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
#
# ACCEPTED LIMITS of FindDirectPIMCalls detection:
# Static AST analysis cannot catch fully dynamic invocation. This test catches:
#   - Direct calls: New-CIPPPIMScheduleRequest
#   - Module-qualified: CIPPCore\New-CIPPPIMScheduleRequest
#   - Invoke-Expression and iex alias: iex 'New-CIPPPIMScheduleRequest ...'
#   - Call operator with constant string: & 'New-CIPPPIMScheduleRequest' or & ("New-CIPPPIM" + "ScheduleRequest")
#   - Get-Command with wildcard: & (Get-Command New-CIPPPIM*)
#
# NOT DETECTED (accepted limits):
#   - Variable holding the name: $c = 'New-CIPPPIMScheduleRequest'; & $c
#   - Invoke-Expression with computed string: iex $dynamicCommand
#   - Format operator: 'New-{0}' -f 'CIPPPIMScheduleRequest'
#   - [string]::Concat, [string]::Join, -join operator
#   - Variable + string concatenation: $prefix + 'PIMScheduleRequest'
#   - Get-Command piped to &: Get-Command New-CIPPPIM* | & $_
#
# The PIM-VALIDATION-ONLY marker at Invoke-ExecPIMRoleAssignment.ps1:~100 exempts one validation call.

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

    # Helper: Find direct calls to New-CIPPPIMScheduleRequest
    # Catches: direct, module-qualified, iex alias, & with constant string/concatenation, & (Get-Command New-CIPPPIM*)
    $script:FindDirectPIMCalls = {
        param($SourceText, $SourceName)
        $Offenders = @()
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput($SourceText, [ref]$null, [ref]$null)
        $Lines = $SourceText -split "`r?`n"
        $Pattern = [regex]'New-CIPPPIMScheduleRequest'
        $DetectedLines = [System.Collections.Generic.HashSet[int]]::new()
        
        # 1. Check & or . with parenthesized string or concatenation whose constant-folded value matches
        # Do this FIRST to avoid double-counting with CommandAst
        $InvokeOps = $Ast.FindAll({ 
            $args[0] -is [System.Management.Automation.Language.CommandAst] -and 
            ($args[0].InvocationOperator -in @('Ampersand', 'Dot'))
        }, $true)
        foreach ($Invoke in $InvokeOps) {
            $LineNum = $Invoke.Extent.StartLineNumber
            if ($DetectedLines.Contains($LineNum)) { continue }
            
            # Get the first element (the command expression after & or .)
            if ($Invoke.CommandElements.Count -gt 0) {
                $First = $Invoke.CommandElements[0]
                # Check if it's a string constant, expandable string, or binary expression (concatenation)
                $Value = $null
                if ($First -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $Value = $First.Value
                } elseif ($First -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                    $Value = $First.Value
                } elseif ($First -is [System.Management.Automation.Language.ParenExpressionAst]) {
                    # Parenthesized expression: try to constant-fold string or check for Get-Command
                    $Inner = $First.Pipeline.GetPureExpression()
                    if ($Inner -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                        $Value = $Inner.Value
                    } elseif ($Inner -is [System.Management.Automation.Language.BinaryExpressionAst] -and $Inner.Operator -eq 'Plus') {
                        # Try to fold string concatenation
                        $Value = $Inner.Extent.Text -replace '["''\s+()]', ''
                    }
                    # Check for & (Get-Command New-CIPPPIM*)
                    if ($First.Pipeline.PipelineElements.Count -gt 0) {
                        $PipeEl = $First.Pipeline.PipelineElements[0]
                        if ($PipeEl -is [System.Management.Automation.Language.CommandAst]) {
                            $InnerCmd = $PipeEl.GetCommandName()
                            if ($InnerCmd -eq 'Get-Command' -and $PipeEl.Extent.Text -match 'New-CIPPPIM') {
                                $FullLine = $Lines[$LineNum - 1]
                                if ($FullLine -notmatch 'PIM-VALIDATION-ONLY') {
                                    $Offenders += "$($SourceName):$LineNum"
                                    [void]$DetectedLines.Add($LineNum)
                                }
                            }
                        }
                    }
                }
                
                if ($Value -and $Pattern.IsMatch($Value)) {
                    $FullLine = $Lines[$LineNum - 1]
                    if ($FullLine -notmatch 'PIM-VALIDATION-ONLY') {
                        $Offenders += "$($SourceName):$LineNum"
                        [void]$DetectedLines.Add($LineNum)
                    }
                }
            }
        }
        
        # 2. Find CommandAst nodes (direct and module-qualified calls)
        $Commands = $Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
        foreach ($Cmd in $Commands) {
            $LineNum = $Cmd.Extent.StartLineNumber
            if ($DetectedLines.Contains($LineNum)) { continue }
            
            $CmdName = $Cmd.GetCommandName()
            # Match: New-CIPPPIMScheduleRequest, CIPPCore\New-CIPPPIMScheduleRequest
            if ($CmdName -match '(^|\\)New-CIPPPIMScheduleRequest$') {
                $FullLine = $Lines[$LineNum - 1]
                if ($FullLine -notmatch 'PIM-VALIDATION-ONLY') {
                    $Offenders += "$($SourceName):$LineNum"
                    [void]$DetectedLines.Add($LineNum)
                }
            }
            # Match: Invoke-Expression and iex alias (resolve aliases)
            if ($CmdName -in @('Invoke-Expression', 'iex')) {
                if ($Cmd.Extent.Text -match 'New-CIPPPIMScheduleRequest') {
                    $FullLine = $Lines[$LineNum - 1]
                    if ($FullLine -notmatch 'PIM-VALIDATION-ONLY') {
                        $Offenders += "$($SourceName):$LineNum"
                        [void]$DetectedLines.Add($LineNum)
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
        # Catches cheap forms (see ACCEPTED LIMITS at top). Variable-based invocation is not detected.
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
        # Anchor the regex to match a single statement on the line
        $MarkedLines[0] | Should -Match '^\s*\$null\s*=\s*New-CIPPPIMScheduleRequest\s+@Window\s*#.*PIM-VALIDATION-ONLY' -Because 'the marked call must be in the shape: $null = New-CIPPPIMScheduleRequest @Window'
    }

    It 'fixture: helpers detect all invocation forms and validate marker scope on test cases' {
        # Test 1: Named-parameter call - FindDirectPIMCalls should detect it
        $NamedCall = 'New-CIPPPIMScheduleRequest -Kind adminAssign -Duration P365D'
        $Offenders1 = & $script:FindDirectPIMCalls $NamedCall 'test1.ps1'
        $Offenders1.Count | Should -Be 1

        # Test 2: DETECTED - iex alias - FindDirectPIMCalls should detect it
        $IexAlias = "iex 'New-CIPPPIMScheduleRequest -Kind adminAssign'"
        $Offenders2 = & $script:FindDirectPIMCalls $IexAlias 'test2.ps1'
        $Offenders2.Count | Should -Be 1

        # Test 3: DETECTED - & with constant string - FindDirectPIMCalls should detect it
        $CallWithString = "& 'New-CIPPPIMScheduleRequest' -Kind adminAssign"
        $Offenders3 = & $script:FindDirectPIMCalls $CallWithString 'test3.ps1'
        $Offenders3.Count | Should -Be 1

        # Test 4: DETECTED - & with parenthesized concatenation - FindDirectPIMCalls should detect it
        $CallWithConcat = '& ("New-CIPPPIM" + "ScheduleRequest") -Kind adminAssign'
        $Offenders4 = & $script:FindDirectPIMCalls $CallWithConcat 'test4.ps1'
        $Offenders4.Count | Should -Be 1

        # Test 5: DETECTED - & (Get-Command New-CIPPPIM*) - FindDirectPIMCalls should detect it
        $CallWithGetCommand = '& (Get-Command New-CIPPPIM*) -Kind adminAssign'
        $Offenders5 = & $script:FindDirectPIMCalls $CallWithGetCommand 'test5.ps1'
        $Offenders5.Count | Should -Be 1

        # Test 6: NOT DETECTED - Variable holding name - documented limit
        $VarName = '$c = "New-CIPPPIMScheduleRequest"; & $c -Kind adminAssign'
        $Offenders6 = & $script:FindDirectPIMCalls $VarName 'test6.ps1'
        $Offenders6.Count | Should -Be 0 -Because 'variable-based invocation is an accepted limit'

        # Test 7: NOT DETECTED - Invoke-Expression with computed string - documented limit
        $IexComputed = '$cmd = "New-" + "CIPPPIMScheduleRequest"; iex $cmd'
        $Offenders7 = & $script:FindDirectPIMCalls $IexComputed 'test7.ps1'
        $Offenders7.Count | Should -Be 0 -Because 'dynamic string construction is an accepted limit'

        # Test 8: DETECTED - . (dot sourcing) with constant string - FindDirectPIMCalls should detect it
        $DotSource = ". 'New-CIPPPIMScheduleRequest' -Kind adminAssign"
        $Offenders8 = & $script:FindDirectPIMCalls $DotSource 'test8.ps1'
        $Offenders8.Count | Should -Be 1 -Because 'dot operator is also caught'

        # Test 9: DETECTED - Invoke-Expression with constant string - FindDirectPIMCalls should detect it
        $IexConstant = "Invoke-Expression 'New-CIPPPIMScheduleRequest -Kind adminAssign'"
        $Offenders9 = & $script:FindDirectPIMCalls $IexConstant 'test9.ps1'
        $Offenders9.Count | Should -Be 1 -Because 'Invoke-Expression with literal function name is detected'

        # Test 10: Block comment - FindDirectPIMCalls should NOT detect it
        $BlockComment = @'
<# 
New-CIPPPIMScheduleRequest -Kind adminAssign
#>
Write-Host "test"
'@
        $Offenders10 = & $script:FindDirectPIMCalls $BlockComment 'test10.ps1'
        $Offenders10.Count | Should -Be 0

        # Test 11: Module-qualified call - FindDirectPIMCalls should detect it
        $ModuleQualified = 'CIPPCore\New-CIPPPIMScheduleRequest -Kind adminAssign'
        $Offenders11 = & $script:FindDirectPIMCalls $ModuleQualified 'test11.ps1'
        $Offenders11.Count | Should -Be 1

        # Test 12: Marker in wrong file - CheckMarkerScope should detect violation
        $WrongFile = '# PIM-VALIDATION-ONLY marker here'
        $Violations12 = & $script:CheckMarkerScope $WrongFile 'WrongFile.ps1'
        $Violations12.Count | Should -Be 1

        # Test 13: Marker in correct file but wrong line - CheckMarkerScope should detect violation
        $WrongLine = '# PIM-VALIDATION-ONLY marker at wrong line'
        $Violations13 = & $script:CheckMarkerScope $WrongLine 'Invoke-ExecPIMRoleAssignment.ps1'
        $Violations13.Count | Should -Be 1 -Because 'line 1 is outside the allowed 95-105 range'

        # Test 14: Marker in correct file and line range - CheckMarkerScope should NOT detect violation
        # Build a file with 100 lines where line 100 has the marker
        $CorrectLocation = (1..99 | ForEach-Object { "# Line $_" }) -join "`n"
        $CorrectLocation += "`n" + '# PIM-VALIDATION-ONLY marker at line 100'
        $Violations14 = & $script:CheckMarkerScope $CorrectLocation 'Invoke-ExecPIMRoleAssignment.ps1'
        $Violations14.Count | Should -Be 0 -Because 'line 100 is within the allowed 95-105 range'

        # Test 15: Call with PIM-VALIDATION-ONLY marker - FindDirectPIMCalls should NOT detect it
        $MarkedCall = 'New-CIPPPIMScheduleRequest -Kind adminAssign  # PIM-VALIDATION-ONLY'
        $Offenders15 = & $script:FindDirectPIMCalls $MarkedCall 'test15.ps1'
        $Offenders15.Count | Should -Be 0 -Because 'PIM-VALIDATION-ONLY marker exempts the call'
    }
}
