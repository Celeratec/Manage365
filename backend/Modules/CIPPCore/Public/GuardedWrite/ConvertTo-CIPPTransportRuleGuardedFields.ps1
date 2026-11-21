function ConvertTo-CIPPTransportRuleGuardedFields {
    <#
    .SYNOPSIS
        Normalizes Enabled/State, Priority, StopRuleProcessing, and RuleErrorAction for guarded mode.
    .DESCRIPTION
        Accepts bool, true/false, Enabled/Disabled for state; plain integer Priority; bool
        StopRuleProcessing; RuleErrorAction Ignore or Defer (case-normalized). Invalid values
        return Ok false with a Message. Omitted RuleErrorAction is not sent (Exchange default).
    #>
    [CmdletBinding()]
    param(
        $Enabled,
        $State,
        $Priority,
        $StopRuleProcessing,
        $RuleErrorAction
    )

    $Result = [ordered]@{
        Ok                 = $true
        Message            = $null
        EnabledBool        = $null
        HasEnabled         = $false
        Priority           = $null
        HasPriority        = $false
        StopRuleProcessing = $null
        HasStop            = $false
        RuleErrorAction    = $null
        HasRuleErrorAction = $false
    }

    $RawState = if ($null -ne $State -and "$State" -ne '') { $State } else { $Enabled }
    if ($null -ne $RawState -and "$RawState" -ne '') {
        $Normalized = if ($RawState -is [hashtable] -or $RawState -is [PSCustomObject]) {
            if ($null -ne $RawState.value) { "$($RawState.value)" } else { "$RawState" }
        } else { "$RawState" }
        switch -Regex ($Normalized.Trim()) {
            '^(?i)true$' { $Result.EnabledBool = $true; $Result.HasEnabled = $true }
            '^(?i)false$' { $Result.EnabledBool = $false; $Result.HasEnabled = $true }
            '^(?i)enabled$' { $Result.EnabledBool = $true; $Result.HasEnabled = $true }
            '^(?i)disabled$' { $Result.EnabledBool = $false; $Result.HasEnabled = $true }
            '^(?i)1$' { $Result.EnabledBool = $true; $Result.HasEnabled = $true }
            '^(?i)0$' { $Result.EnabledBool = $false; $Result.HasEnabled = $true }
            default {
                $Result.Ok = $false
                $Result.Message = 'Enabled/State must be true, false, Enabled, or Disabled.'
                return [pscustomobject]$Result
            }
        }
    }

    if ($null -ne $Priority -and "$Priority" -ne '') {
        $PriorityRaw = if ($Priority -is [hashtable] -or $Priority -is [PSCustomObject]) {
            if ($null -ne $Priority.value) { $Priority.value } else { $Priority }
        } else { $Priority }
        if ("$PriorityRaw" -notmatch '^\d+$') {
            $Result.Ok = $false
            $Result.Message = 'Priority must be an integer greater than or equal to 0.'
            return [pscustomobject]$Result
        }
        $Result.Priority = [int]$PriorityRaw
        $Result.HasPriority = $true
    }

    if ($null -ne $StopRuleProcessing -and "$StopRuleProcessing" -ne '') {
        $StopRaw = if ($StopRuleProcessing -is [hashtable] -or $StopRuleProcessing -is [PSCustomObject]) {
            if ($null -ne $StopRuleProcessing.value) { "$($StopRuleProcessing.value)" } else { "$StopRuleProcessing" }
        } else { "$StopRuleProcessing" }
        if ($StopRaw -notin @('true', 'false', 'True', 'False', '1', '0')) {
            $Result.Ok = $false
            $Result.Message = 'StopRuleProcessing must be true or false.'
            return [pscustomobject]$Result
        }
        $Result.StopRuleProcessing = $StopRaw -in @('true', 'True', '1')
        $Result.HasStop = $true
    }

    if ($null -ne $RuleErrorAction -and "$RuleErrorAction" -ne '') {
        $ActionRaw = if ($RuleErrorAction -is [hashtable] -or $RuleErrorAction -is [PSCustomObject]) {
            if ($null -ne $RuleErrorAction.value) { "$($RuleErrorAction.value)" } else { "$RuleErrorAction" }
        } else { "$RuleErrorAction" }
        switch -Regex ($ActionRaw.Trim()) {
            '^(?i)ignore$' { $Result.RuleErrorAction = 'Ignore'; $Result.HasRuleErrorAction = $true }
            '^(?i)defer$' { $Result.RuleErrorAction = 'Defer'; $Result.HasRuleErrorAction = $true }
            default {
                $Result.Ok = $false
                $Result.Message = 'RuleErrorAction must be Ignore or Defer.'
                return [pscustomobject]$Result
            }
        }
    }

    return [pscustomobject]$Result
}

function Merge-CIPPTransportRuleGuardedRequestBody {
    <#
    .SYNOPSIS
        Copies guarded envelope fields from Query onto Body when Body omits them.
    #>
    [CmdletBinding()]
    param($Request)

    if ($null -eq $Request) { return $Request }
    $Body = $Request.Body
    if ($null -eq $Body) {
        $Body = [pscustomobject]@{}
        $Request | Add-Member -NotePropertyName Body -NotePropertyValue $Body -Force
    }
    $Query = $Request.Query
    if ($null -eq $Query) { return $Request }

    $Hashtable = @{}
    foreach ($Prop in $Body.PSObject.Properties) {
        $Hashtable[$Prop.Name] = $Prop.Value
    }
    foreach ($Name in @('ticketNumber', 'TicketNumber', 'dryRun', 'WhatIf', 'preview', 'Preview', 'reason', 'Reason', 'tenantFilter', 'confirmRuleName')) {
        $Existing = $Hashtable[$Name]
        if (($null -eq $Existing -or "$Existing" -eq '') -and $null -ne $Query.$Name -and "$($Query.$Name)" -ne '') {
            $Hashtable[$Name] = $Query.$Name
        }
    }
    $Request | Add-Member -NotePropertyName Body -NotePropertyValue ([pscustomobject]$Hashtable) -Force
    return $Request
}
