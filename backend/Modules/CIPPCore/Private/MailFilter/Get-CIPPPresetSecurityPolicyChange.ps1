function Get-CIPPPresetSecurityPolicyIdentity {
    param([Parameter(Mandatory)][string]$Preset)

    switch ($Preset) {
        { $_ -in 'Standard', 'standard' } { return 'Standard Preset Security Policy' }
        { $_ -in 'Strict', 'strict' } { return 'Strict Preset Security Policy' }
        default { throw 'preset must be Standard or Strict.' }
    }
}

function Get-CIPPPresetRuleView {
    param($Rule)

    [ordered]@{
        Identity                     = Get-CIPPMailFilterProperty $Rule 'Identity'
        Name                         = Get-CIPPMailFilterProperty $Rule 'Name'
        State                        = [string](Get-CIPPMailFilterProperty $Rule 'State')
        SentTo                       = @(ConvertTo-CIPPMailFilterStringList (Get-CIPPMailFilterProperty $Rule 'SentTo'))
        SentToMemberOf               = @(ConvertTo-CIPPMailFilterStringList (Get-CIPPMailFilterProperty $Rule 'SentToMemberOf'))
        RecipientDomainIs            = @(ConvertTo-CIPPMailFilterStringList (Get-CIPPMailFilterProperty $Rule 'RecipientDomainIs'))
        ExceptIfSentTo               = @(ConvertTo-CIPPMailFilterStringList (Get-CIPPMailFilterProperty $Rule 'ExceptIfSentTo'))
        ExceptIfSentToMemberOf       = @(ConvertTo-CIPPMailFilterStringList (Get-CIPPMailFilterProperty $Rule 'ExceptIfSentToMemberOf'))
        ExceptIfRecipientDomainIs    = @(ConvertTo-CIPPMailFilterStringList (Get-CIPPMailFilterProperty $Rule 'ExceptIfRecipientDomainIs'))
    }
}

function Get-CIPPPresetSecurityPolicyChange {
    <#
    .SYNOPSIS
        Builds the Exchange commands, diff, and rollback for a preset security policy change.
    #>
    param(
        [Parameter(Mandatory)][string]$Preset,
        [string]$State,
        $EopRule,
        $AtpRule,
        [bool]$HasUsers,
        $Users,
        [bool]$HasGroups,
        $Groups,
        [bool]$HasDomains,
        $Domains,
        [bool]$HasExceptUsers,
        $ExceptUsers,
        [bool]$HasExceptGroups,
        $ExceptGroups,
        [bool]$HasExceptDomains,
        $ExceptDomains
    )

    $Identity = Get-CIPPPresetSecurityPolicyIdentity -Preset $Preset
    if ($null -eq $EopRule) { throw "Preset rule '$Identity' was not found." }

    $TargetState = ConvertTo-CIPPMailFilterState $State
    $ScopeMap = @(
        @{ Set = $HasUsers; Field = 'SentTo'; Value = $Users }
        @{ Set = $HasGroups; Field = 'SentToMemberOf'; Value = $Groups }
        @{ Set = $HasDomains; Field = 'RecipientDomainIs'; Value = $Domains }
        @{ Set = $HasExceptUsers; Field = 'ExceptIfSentTo'; Value = $ExceptUsers }
        @{ Set = $HasExceptGroups; Field = 'ExceptIfSentToMemberOf'; Value = $ExceptGroups }
        @{ Set = $HasExceptDomains; Field = 'ExceptIfRecipientDomainIs'; Value = $ExceptDomains }
    )

    $Rules = @(@{ Kind = 'EOP'; CmdletStem = 'EOPProtectionPolicyRule'; Rule = $EopRule })
    if ($null -ne $AtpRule) {
        $Rules += @{ Kind = 'ATP'; CmdletStem = 'ATPProtectionPolicyRule'; Rule = $AtpRule }
    }

    $Diff = [System.Collections.Generic.List[object]]::new()
    $Commands = [System.Collections.Generic.List[object]]::new()
    $Rollback = [System.Collections.Generic.List[object]]::new()
    $Snapshot = [ordered]@{}

    foreach ($Entry in $Rules) {
        $View = Get-CIPPPresetRuleView $Entry.Rule
        $Snapshot[$Entry.Kind] = $View
        $ResultingState = if ($TargetState) { $TargetState } else { $(if ($View.State) { $View.State } else { 'Disabled' }) }
        $WasActive = $View.State -eq 'Enabled'
        $Active = $WasActive -and ($ResultingState -eq 'Enabled')

        if ($TargetState -and $TargetState -ne $View.State) {
            $Row = Get-CIPPMailFilterDiffRow -Field 'State' -Label "$($Entry.Kind).State" -Before $View.State -After $TargetState -ProtectionActive $true
            if ($Row) { $Diff.Add($Row) }
        }

        $SetParams = @{ Identity = $Identity }
        $RollbackParams = @{ Identity = $Identity }
        $ScopeChanged = $false
        foreach ($Scope in $ScopeMap) {
            if (-not $Scope.Set) { continue }
            $Before = $View[$Scope.Field]
            $AfterList = @(ConvertTo-CIPPMailFilterStringList $Scope.Value)
            $AfterValue = if ($AfterList.Count -eq 0) { $null } else { $AfterList }
            $SetParams[$Scope.Field] = $AfterValue
            $RollbackParams[$Scope.Field] = if (@($Before).Count -eq 0) { $null } else { @($Before) }
            $ScopeChanged = $true
            $Row = Get-CIPPMailFilterDiffRow -Field $Scope.Field -Label "$($Entry.Kind).$($Scope.Field)" -Before $Before -After $AfterList -ProtectionActive $Active
            if ($Row) { $Diff.Add($Row) }
        }

        if ($ScopeChanged) {
            $Commands.Add(@{ Cmdlet = "Set-$($Entry.CmdletStem)"; Parameters = $SetParams })
            $Rollback.Add(@{ Cmdlet = "Set-$($Entry.CmdletStem)"; Parameters = $RollbackParams })
        }

        if ($TargetState -eq 'Enabled' -and $View.State -ne 'Enabled') {
            $Commands.Add(@{ Cmdlet = "Enable-$($Entry.CmdletStem)"; Parameters = @{ Identity = $Identity } })
            $Rollback.Add(@{ Cmdlet = "Disable-$($Entry.CmdletStem)"; Parameters = @{ Identity = $Identity } })
        } elseif ($TargetState -eq 'Disabled' -and $View.State -ne 'Disabled') {
            $Commands.Add(@{ Cmdlet = "Disable-$($Entry.CmdletStem)"; Parameters = @{ Identity = $Identity } })
            $Rollback.Add(@{ Cmdlet = "Enable-$($Entry.CmdletStem)"; Parameters = @{ Identity = $Identity } })
        }
    }

    if ($Commands.Count -eq 0) { throw 'No preset change was requested. Send state or a scope field.' }

    @{
        Snapshot = $Snapshot
        Diff     = @($Diff)
        Commands = @($Commands)
        Rollback = @($Rollback)
    }
}
