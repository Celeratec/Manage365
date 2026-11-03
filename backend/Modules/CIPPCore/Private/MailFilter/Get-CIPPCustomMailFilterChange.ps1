function Get-CIPPCustomMailFilterCatalog {
    param([Parameter(Mandatory)][string]$PolicyType)

    switch ($PolicyType) {
        { $_ -in 'AntiSpam', 'antispam' } {
            return @{
                Type         = 'AntiSpam'
                PolicyCmdlet = 'HostedContentFilterPolicy'
                RuleCmdlet   = 'HostedContentFilterRule'
                PolicyLink   = 'HostedContentFilterPolicy'
                Settings     = @('BulkThreshold', 'SpamAction', 'HighConfidenceSpamAction', 'BulkSpamAction')
            }
        }
        { $_ -in 'AntiPhish', 'antiphish' } {
            return @{
                Type         = 'AntiPhish'
                PolicyCmdlet = 'AntiPhishPolicy'
                RuleCmdlet   = 'AntiPhishRule'
                PolicyLink   = 'AntiPhishPolicy'
                Settings     = @('TargetedUserProtectionAction', 'TargetedDomainProtectionAction', 'MailboxIntelligenceProtectionAction')
            }
        }
        { $_ -in 'AntiMalware', 'antimalware' } {
            return @{
                Type         = 'AntiMalware'
                PolicyCmdlet = 'MalwareFilterPolicy'
                RuleCmdlet   = 'MalwareFilterRule'
                PolicyLink   = 'MalwareFilterPolicy'
                Settings     = @('EnableFileFilter', 'FileTypes', 'FileTypeAction')
            }
        }
        default { throw 'policyType must be AntiSpam, AntiPhish, or AntiMalware.' }
    }
}

function Resolve-CIPPCustomMailFilterOperation {
    param([string]$Operation)

    switch ($Operation) {
        { $_ -in 'Create', 'Add', 'New', 'create', 'add' } { return 'Create' }
        { $_ -in 'Update', 'Edit', 'Set', 'update', 'edit' } { return 'Update' }
        { $_ -in 'Delete', 'Remove', 'delete', 'remove' } { return 'Delete' }
        default { throw 'operation must be Create, Update, or Delete.' }
    }
}

function Test-CIPPCustomMailFilterReserved {
    param([string]$Name, $Policy)

    if ($Name -eq 'Default') { return $true }
    if ($Name -like '*Preset Security Policy*') { return $true }
    if ((Get-CIPPMailFilterProperty $Policy 'IsDefault') -eq $true) { return $true }
    return $false
}

function ConvertTo-CIPPCustomMailFilterSetting {
    param(
        [string]$Name,
        $Value
    )

    switch ($Name) {
        'BulkThreshold' {
            $Number = 0
            if (-not [int]::TryParse([string]$Value, [ref]$Number) -or $Number -lt 1 -or $Number -gt 9) {
                throw 'bulkThreshold must be an integer from 1 to 9.'
            }
            return $Number
        }
        'EnableFileFilter' { return [bool](ConvertTo-CIPPMailFilterBool $Value) }
        'FileTypes' { return @(ConvertTo-CIPPMailFilterStringList $Value) }
        'FileTypeAction' {
            if ([string]$Value -notin 'Reject', 'Quarantine') { throw 'fileTypeAction must be Reject or Quarantine.' }
            return [string]$Value
        }
        { $_ -in 'SpamAction', 'HighConfidenceSpamAction', 'BulkSpamAction' } {
            $null = Get-CIPPMailFilterActionRank ([string]$Value)
            if ([string]$Value -notin 'MoveToJmf', 'AddXHeader', 'ModifySubject', 'Redirect', 'Delete', 'Quarantine') {
                throw "$Name must be MoveToJmf, AddXHeader, ModifySubject, Redirect, Delete, or Quarantine."
            }
            return [string]$Value
        }
        { $_ -in 'TargetedUserProtectionAction', 'TargetedDomainProtectionAction', 'MailboxIntelligenceProtectionAction' } {
            $null = Get-CIPPMailFilterActionRank ([string]$Value)
            if ([string]$Value -notin 'NoAction', 'BccMessage', 'Delete', 'MoveToJmf', 'Quarantine', 'Redirect') {
                throw "$Name must be NoAction, BccMessage, Redirect, MoveToJmf, Delete, or Quarantine."
            }
            return [string]$Value
        }
        default { throw "Setting '$Name' is not supported." }
    }
}

function Get-CIPPCustomMailFilterChange {
    <#
    .SYNOPSIS
        Builds create, update, or delete commands for a custom mail filter policy and its rule.
    #>
    param(
        [Parameter(Mandatory)][string]$PolicyType,
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$Name,
        [string]$RuleName,
        $Policy,
        $Rule,
        $BaselinePolicy,
        [hashtable]$Settings = @{},
        [hashtable]$RuleSettings = @{}
    )

    $Catalog = Get-CIPPCustomMailFilterCatalog -PolicyType $PolicyType
    $Verb = Resolve-CIPPCustomMailFilterOperation -Operation $Operation
    $PolicyName = Test-CIPPMailFilterIdentity -Value $Name -Label 'name'
    $ResolvedRuleName = if ([string]::IsNullOrWhiteSpace($RuleName)) { $PolicyName } else { Test-CIPPMailFilterIdentity -Value $RuleName -Label 'ruleName' }
    $Reserved = Test-CIPPCustomMailFilterReserved -Name $PolicyName -Policy $Policy

    $Snapshot = [ordered]@{
        PolicyType = $Catalog.Type
        Name       = $PolicyName
        RuleName   = $ResolvedRuleName
        Policy     = [ordered]@{}
        Rule       = [ordered]@{}
    }
    foreach ($SettingName in $Catalog.Settings) {
        $Snapshot.Policy[$SettingName] = Get-CIPPMailFilterProperty $Policy $SettingName
    }
    foreach ($RuleField in @('State', 'Priority', 'SentTo', 'SentToMemberOf', 'RecipientDomainIs')) {
        $Snapshot.Rule[$RuleField] = Get-CIPPMailFilterProperty $Rule $RuleField
    }

    $Diff = [System.Collections.Generic.List[object]]::new()
    $Commands = [System.Collections.Generic.List[object]]::new()
    $Rollback = [System.Collections.Generic.List[object]]::new()

    if ($Verb -eq 'Delete') {
        if ($Reserved) { throw "Policy '$PolicyName' is built in and cannot be deleted." }
        if ($null -eq $Policy) { throw "Policy '$PolicyName' was not found." }
        $RuleState = [string](Get-CIPPMailFilterProperty $Rule 'State')
        $WasOn = ($null -eq $Rule) -or ($RuleState -eq '' -or $RuleState -eq 'Enabled')
        $Row = Get-CIPPMailFilterDiffRow -Field 'State' -Label 'Rule.State' -Before $(if ($WasOn) { 'Enabled' } else { 'Disabled' }) -After 'Deleted' -ProtectionActive $true
        if ($Row) {
            if ($WasOn) { $Row.Weaker = $true }
            $Diff.Add($Row)
        }

        if ($null -ne $Rule) {
            $Commands.Add(@{ Cmdlet = "Remove-$($Catalog.RuleCmdlet)"; Parameters = @{ Identity = $ResolvedRuleName } })
        }
        $Commands.Add(@{ Cmdlet = "Remove-$($Catalog.PolicyCmdlet)"; Parameters = @{ Identity = $PolicyName } })

        $RestorePolicy = @{ Name = $PolicyName }
        foreach ($SettingName in $Catalog.Settings) {
            $CurrentValue = $Snapshot.Policy[$SettingName]
            if ($null -ne $CurrentValue -and -not [string]::IsNullOrWhiteSpace([string]$CurrentValue)) {
                $RestorePolicy[$SettingName] = $CurrentValue
            }
        }
        $Rollback.Add(@{ Cmdlet = "New-$($Catalog.PolicyCmdlet)"; Parameters = $RestorePolicy })
        if ($null -ne $Rule) {
            $RestoreRule = @{
                Name                  = $ResolvedRuleName
                ($Catalog.PolicyLink) = $PolicyName
            }
            $State = [string]$Snapshot.Rule.State
            if ($State) { $RestoreRule.Enabled = ($State -eq 'Enabled') }
            if ($null -ne $Snapshot.Rule.Priority) { $RestoreRule.Priority = $Snapshot.Rule.Priority }
            foreach ($ScopeField in @('SentTo', 'SentToMemberOf', 'RecipientDomainIs')) {
                $ScopeValue = @(ConvertTo-CIPPMailFilterStringList $Snapshot.Rule[$ScopeField])
                if ($ScopeValue.Count -gt 0) { $RestoreRule[$ScopeField] = $ScopeValue }
            }
            $Rollback.Add(@{ Cmdlet = "New-$($Catalog.RuleCmdlet)"; Parameters = $RestoreRule })
        }
    } else {
        $Proposed = @{}
        $WasEnabled = ([string](Get-CIPPMailFilterProperty $Rule 'State')) -eq 'Enabled'
        $ResultingEnabled = $true
        if ($RuleSettings.ContainsKey('Enabled')) {
            $ResultingEnabled = [bool](ConvertTo-CIPPMailFilterBool $RuleSettings.Enabled)
        } elseif ($Verb -eq 'Update') {
            $ResultingEnabled = $WasEnabled
        }
        $ScopeActive = $WasEnabled -and $ResultingEnabled

        foreach ($SettingName in $Catalog.Settings) {
            $CurrentValue = if ($Verb -eq 'Create') { Get-CIPPMailFilterProperty $BaselinePolicy $SettingName } else { $Snapshot.Policy[$SettingName] }
            if ($Settings.ContainsKey($SettingName)) {
                $Proposed[$SettingName] = ConvertTo-CIPPCustomMailFilterSetting -Name $SettingName -Value $Settings[$SettingName]
            } elseif ($Verb -eq 'Create' -and $null -ne $CurrentValue) {
                $Proposed[$SettingName] = $CurrentValue
            }
            if ($Proposed.ContainsKey($SettingName)) {
                $Active = if ($SettingName -eq 'FileTypes') { [bool]($Proposed['EnableFileFilter'] ?? (ConvertTo-CIPPMailFilterBool $CurrentValue)) } else { $ResultingEnabled }
                if ($SettingName -eq 'FileTypes' -and $Proposed.ContainsKey('EnableFileFilter')) {
                    $Active = [bool]$Proposed['EnableFileFilter']
                }
                $Row = Get-CIPPMailFilterDiffRow -Field $SettingName -Before $CurrentValue -After $Proposed[$SettingName] -ProtectionActive $Active
                if ($Row -and -not $ResultingEnabled) { $Row.Weaker = $false }
                if ($Row) { $Diff.Add($Row) }
            }
        }

        if ($Verb -eq 'Create') {
            if ($null -ne $Policy) { throw "Policy '$PolicyName' already exists." }
            if ($Reserved) { throw "Policy name '$PolicyName' is reserved." }
            $HasScope = $false
            foreach ($ScopeField in @('SentTo', 'SentToMemberOf', 'RecipientDomainIs')) {
                if ($RuleSettings.ContainsKey($ScopeField) -and @(ConvertTo-CIPPMailFilterStringList $RuleSettings[$ScopeField]).Count -gt 0) {
                    $HasScope = $true
                }
            }
            if (-not $HasScope) { throw 'A new custom policy needs users, groups, or domains on its rule.' }

            $PolicyParams = @{ Name = $PolicyName }
            foreach ($Key in $Proposed.Keys) { $PolicyParams[$Key] = $Proposed[$Key] }
            $Commands.Add(@{ Cmdlet = "New-$($Catalog.PolicyCmdlet)"; Parameters = $PolicyParams })

            $RuleParams = @{ Name = $ResolvedRuleName; ($Catalog.PolicyLink) = $PolicyName; Enabled = $ResultingEnabled }
            foreach ($ScopeField in @('SentTo', 'SentToMemberOf', 'RecipientDomainIs')) {
                if ($RuleSettings.ContainsKey($ScopeField)) {
                    $ScopeValue = @(ConvertTo-CIPPMailFilterStringList $RuleSettings[$ScopeField])
                    if ($ScopeValue.Count -gt 0) { $RuleParams[$ScopeField] = $ScopeValue }
                }
            }
            if ($RuleSettings.ContainsKey('Priority')) { $RuleParams.Priority = [int]$RuleSettings.Priority }
            $Commands.Add(@{ Cmdlet = "New-$($Catalog.RuleCmdlet)"; Parameters = $RuleParams })
            $Rollback.Add(@{ Cmdlet = "Remove-$($Catalog.RuleCmdlet)"; Parameters = @{ Identity = $ResolvedRuleName } })
            $Rollback.Add(@{ Cmdlet = "Remove-$($Catalog.PolicyCmdlet)"; Parameters = @{ Identity = $PolicyName } })
        } else {
            if ($null -eq $Policy) { throw "Policy '$PolicyName' was not found." }
            if ($Proposed.Count -eq 0 -and $RuleSettings.Count -eq 0) { throw 'No policy or rule settings were supplied.' }

            if ($Proposed.Count -gt 0) {
                $SetPolicy = @{ Identity = $PolicyName }
                $UndoPolicy = @{ Identity = $PolicyName }
                foreach ($Key in @($Proposed.Keys)) {
                    $SetPolicy[$Key] = $Proposed[$Key]
                    $UndoPolicy[$Key] = $Snapshot.Policy[$Key]
                }
                $Commands.Add(@{ Cmdlet = "Set-$($Catalog.PolicyCmdlet)"; Parameters = $SetPolicy })
                $Rollback.Add(@{ Cmdlet = "Set-$($Catalog.PolicyCmdlet)"; Parameters = $UndoPolicy })
            }

            if ($RuleSettings.Count -gt 0) {
                if ($null -eq $Rule) { throw "Rule '$ResolvedRuleName' was not found." }
                $SetRule = @{ Identity = $ResolvedRuleName }
                $UndoRule = @{ Identity = $ResolvedRuleName }
                if ($RuleSettings.ContainsKey('Enabled')) {
                    $SetRule.Enabled = $ResultingEnabled
                    $UndoRule.Enabled = ([string]$Snapshot.Rule.State) -eq 'Enabled'
                    $Row = Get-CIPPMailFilterDiffRow -Field 'State' -Label 'Rule.State' -Before $Snapshot.Rule.State -After $(if ($ResultingEnabled) { 'Enabled' } else { 'Disabled' })
                    if ($Row) { $Diff.Add($Row) }
                }
                if ($RuleSettings.ContainsKey('Priority')) {
                    $SetRule.Priority = [int]$RuleSettings.Priority
                    $UndoRule.Priority = $Snapshot.Rule.Priority
                    $Row = Get-CIPPMailFilterDiffRow -Field 'Priority' -Before $Snapshot.Rule.Priority -After $RuleSettings.Priority -ProtectionActive $ResultingEnabled
                    if ($Row) { $Diff.Add($Row) }
                }
                foreach ($ScopeField in @('SentTo', 'SentToMemberOf', 'RecipientDomainIs')) {
                    if (-not $RuleSettings.ContainsKey($ScopeField)) { continue }
                    $AfterList = @(ConvertTo-CIPPMailFilterStringList $RuleSettings[$ScopeField])
                    $SetRule[$ScopeField] = if ($AfterList.Count -eq 0) { $null } else { $AfterList }
                    $BeforeList = @(ConvertTo-CIPPMailFilterStringList $Snapshot.Rule[$ScopeField])
                    $UndoRule[$ScopeField] = if ($BeforeList.Count -eq 0) { $null } else { $BeforeList }
                    $Row = Get-CIPPMailFilterDiffRow -Field $ScopeField -Label "Rule.$ScopeField" -Before $BeforeList -After $AfterList -ProtectionActive $ScopeActive
                    if ($Row) { $Diff.Add($Row) }
                }
                $Commands.Add(@{ Cmdlet = "Set-$($Catalog.RuleCmdlet)"; Parameters = $SetRule })
                $Rollback.Add(@{ Cmdlet = "Set-$($Catalog.RuleCmdlet)"; Parameters = $UndoRule })
            }
        }
    }

    @{
        Snapshot = $Snapshot
        Diff     = @($Diff)
        Commands = @($Commands)
        Rollback = @($Rollback)
    }
}
