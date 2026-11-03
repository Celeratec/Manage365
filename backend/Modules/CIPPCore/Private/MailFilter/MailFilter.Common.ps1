function ConvertTo-CIPPMailFilterStringList {
    <#
    .SYNOPSIS
        Normalises a request value into a list of trimmed strings.
    #>
    param($Value)

    $Items = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $Value) { return @() }

    $Pending = [System.Collections.Generic.Queue[object]]::new()
    foreach ($Entry in @($Value)) { $Pending.Enqueue($Entry) }

    while ($Pending.Count -gt 0) {
        $Entry = $Pending.Dequeue()
        if ($null -eq $Entry) { continue }

        if ($Entry -is [System.Collections.IEnumerable] -and $Entry -isnot [string]) {
            foreach ($Child in $Entry) { $Pending.Enqueue($Child) }
            continue
        }

        $Text = if ($Entry -isnot [string] -and $Entry.PSObject.Properties.Name -contains 'value') {
            [string]$Entry.value
        } else {
            [string]$Entry
        }

        foreach ($Part in ($Text -split '[,;]')) {
            $Trimmed = $Part.Trim()
            if (-not [string]::IsNullOrWhiteSpace($Trimmed)) { $Items.Add($Trimmed) }
        }
    }

    return @($Items)
}

function ConvertTo-CIPPMailFilterBool {
    param(
        $Value,
        [bool]$Default = $false
    )

    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }

    switch ([string]$Value) {
        { $_ -in 'true', 'True', '1' } { return $true }
        { $_ -in 'false', 'False', '0' } { return $false }
        default { throw "Expected true or false, received '$Value'." }
    }
}

function ConvertTo-CIPPMailFilterState {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    switch ([string]$Value) {
        { $_ -in 'Enable', 'Enabled', 'enable', 'enabled', 'true', 'True' } { return 'Enabled' }
        { $_ -in 'Disable', 'Disabled', 'disable', 'disabled', 'false', 'False' } { return 'Disabled' }
        default { throw 'State must be Enable or Disable.' }
    }
}

function Test-CIPPMailFilterTicket {
    param([string]$TicketNumber)

    if ([string]::IsNullOrWhiteSpace($TicketNumber) -or $TicketNumber -notmatch '^\d+$') {
        throw 'ticketNumber is required and must be a numeric ticket ID.'
    }
    return $TicketNumber.Trim()
}

function Test-CIPPMailFilterIdentity {
    param(
        [string]$Value,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { throw "$Label is required." }
    $Trimmed = $Value.Trim()
    if ($Trimmed.Length -gt 256 -or $Trimmed -match '[\r\n\x00-\x1F]') {
        throw "$Label contains invalid characters."
    }
    return $Trimmed
}

function Get-CIPPMailFilterActionRank {
    param([string]$Action)

    if ([string]::IsNullOrWhiteSpace($Action)) { return $null }
    switch ($Action) {
        'NoAction' { return 0 }
        'AddXHeader' { return 1 }
        'ModifySubject' { return 1 }
        'BccMessage' { return 2 }
        'Redirect' { return 2 }
        'MoveToJmf' { return 3 }
        'Quarantine' { return 5 }
        'Delete' { return 5 }
        'Reject' { return 5 }
        default { throw "Unsupported filter action '$Action'." }
    }
}

function Test-CIPPMailFilterListRemoved {
    param($Before, $After)

    $AfterList = @(ConvertTo-CIPPMailFilterStringList $After)
    foreach ($Item in @(ConvertTo-CIPPMailFilterStringList $Before)) {
        $Found = $false
        foreach ($Other in $AfterList) {
            if ($Item.Equals([string]$Other, [System.StringComparison]::OrdinalIgnoreCase)) { $Found = $true; break }
        }
        if (-not $Found) { return $true }
    }
    return $false
}

function Test-CIPPMailFilterListAdded {
    param($Before, $After)

    $BeforeList = @(ConvertTo-CIPPMailFilterStringList $Before)
    foreach ($Item in @(ConvertTo-CIPPMailFilterStringList $After)) {
        $Found = $false
        foreach ($Other in $BeforeList) {
            if ($Item.Equals([string]$Other, [System.StringComparison]::OrdinalIgnoreCase)) { $Found = $true; break }
        }
        if (-not $Found) { return $true }
    }
    return $false
}

function Test-CIPPMailFilterSettingWeaker {
    param(
        [Parameter(Mandatory)]
        [string]$Field,
        $Before,
        $After,
        [bool]$ProtectionActive = $true
    )

    $ActionFields = @(
        'SpamAction', 'HighConfidenceSpamAction', 'BulkSpamAction',
        'TargetedUserProtectionAction', 'TargetedDomainProtectionAction', 'MailboxIntelligenceProtectionAction',
        'FileTypeAction'
    )
    $ScopeFields = @('SentTo', 'SentToMemberOf', 'RecipientDomainIs', 'FileTypes')
    $ExceptionFields = @('ExceptIfSentTo', 'ExceptIfSentToMemberOf', 'ExceptIfRecipientDomainIs')

    if ($Field -eq 'State' -or $Field -eq 'Enabled') {
        $BeforeOn = [string]$Before -in 'Enabled', 'True'
        $AfterOn = [string]$After -in 'Enabled', 'True'
        return ($BeforeOn -and -not $AfterOn)
    }

    if ($Field -eq 'BulkThreshold') {
        if ($null -eq $Before -or $null -eq $After) { return $false }
        return ([int]$After -gt [int]$Before)
    }

    if ($Field -eq 'EnableFileFilter') {
        $BeforeOn = ConvertTo-CIPPMailFilterBool $Before
        $AfterOn = ConvertTo-CIPPMailFilterBool $After
        return ($BeforeOn -and -not $AfterOn)
    }

    if ($ActionFields -contains $Field) {
        $BeforeRank = Get-CIPPMailFilterActionRank ([string]$Before)
        $AfterRank = Get-CIPPMailFilterActionRank ([string]$After)
        if ($null -eq $BeforeRank -or $null -eq $AfterRank) { return $false }
        return ($AfterRank -lt $BeforeRank)
    }

    if (-not $ProtectionActive) { return $false }

    if ($ScopeFields -contains $Field) { return (Test-CIPPMailFilterListRemoved -Before $Before -After $After) }
    if ($ExceptionFields -contains $Field) { return (Test-CIPPMailFilterListAdded -Before $Before -After $After) }

    return $false
}

function Get-CIPPMailFilterDiffRow {
    param(
        [string]$Field,
        [string]$Label,
        $Before,
        $After,
        [bool]$ProtectionActive = $true
    )

    $BeforeText = if ($null -eq $Before) { $null } elseif ($Before -is [System.Collections.IEnumerable] -and $Before -isnot [string]) {
        (@(ConvertTo-CIPPMailFilterStringList $Before)) -join ', '
    } else { [string]$Before }
    $AfterText = if ($null -eq $After) { $null } elseif ($After -is [System.Collections.IEnumerable] -and $After -isnot [string]) {
        (@(ConvertTo-CIPPMailFilterStringList $After)) -join ', '
    } else { [string]$After }

    if ($BeforeText -eq $AfterText) { return $null }

    [pscustomobject]@{
        Field   = $(if ($Label) { $Label } else { $Field })
        Before  = $BeforeText
        After   = $AfterText
        Weaker  = [bool](Test-CIPPMailFilterSettingWeaker -Field $Field -Before $Before -After $After -ProtectionActive $ProtectionActive)
    }
}

function Get-CIPPMailFilterProperty {
    param($Object, [string]$Name)

    if ($null -eq $Object) { return $null }
    $Property = $Object.PSObject.Properties[$Name]
    if ($Property) { return $Property.Value }
    return $null
}

function ConvertTo-CIPPMailFilterJson {
    param($Value, [int]$MaxLength = 24000)

    if ($null -eq $Value) { return $null }
    $Json = $Value | ConvertTo-Json -Depth 8 -Compress
    if ($Json.Length -le $MaxLength) { return $Json }
    return $Json.Substring(0, $MaxLength) + '...truncated'
}

function Add-CIPPMailFilterAudit {
    param(
        [string]$TenantFilter,
        [string]$TicketNumber,
        [string]$Caller,
        [string]$Operation,
        [string]$Result,
        [bool]$DryRun,
        [bool]$Blocked,
        [bool]$Applied,
        $Diff,
        $Snapshot,
        $Rollback,
        [string]$ErrorSummary
    )

    $Entity = @{
        PartitionKey  = $TenantFilter
        RowKey        = [guid]::NewGuid().ToString()
        TicketNumber  = $TicketNumber
        Caller        = $Caller
        Operation     = $Operation
        Result        = $Result
        DryRun        = [bool]$DryRun
        Blocked       = [bool]$Blocked
        Applied       = [bool]$Applied
        Diff          = ConvertTo-CIPPMailFilterJson $Diff
        Snapshot      = ConvertTo-CIPPMailFilterJson $Snapshot
        Rollback      = ConvertTo-CIPPMailFilterJson $Rollback
        ErrorSummary  = $ErrorSummary
        TimestampUtc  = (Get-Date).ToUniversalTime().ToString('o')
    }

    $Written = $false
    try {
        if (Get-Command -Name Get-CippTable -ErrorAction SilentlyContinue) {
            $Table = Get-CippTable -tablename 'MailFilterChangeAudit'
            if (Get-Command -Name Add-CIPPAzDataTableEntity -ErrorAction SilentlyContinue) {
                Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force | Out-Null
                $Written = $true
            }
        }
    } catch {
        Write-Warning "Mail filter audit write failed: $($_.Exception.Message)"
    }

    $Entity.AuditWritten = $Written
    return $Entity
}

function Invoke-CIPPMailFilterExo {
    param(
        [string]$TenantFilter,
        $Command
    )

    $Params = @{
        tenantid         = $TenantFilter
        cmdlet           = [string]$Command.Cmdlet
        cmdParams        = $Command.Parameters
        useSystemMailbox = $true
    }
    if ($Command.Anchor) { $Params.Anchor = [string]$Command.Anchor }
    return (New-ExoRequest @Params)
}

function Invoke-CIPPMailFilterApply {
    param(
        [Parameter(Mandatory)]
        [string]$TenantFilter,
        [Parameter(Mandatory)]
        [string]$TicketNumber,
        [Parameter(Mandatory)]
        [string]$Caller,
        [Parameter(Mandatory)]
        [string]$Operation,
        [bool]$DryRun,
        [bool]$AllowWeakerProtection,
        [Parameter(Mandatory)]
        $Plan,
        [string]$ApiName
    )

    $Diff = @($Plan.Diff | Where-Object { $null -ne $_ })
    $Weaker = @($Diff | Where-Object { $_.Weaker })
    $Blocked = $Weaker.Count -gt 0 -and -not $AllowWeakerProtection
    $Reasons = @($Weaker | ForEach-Object {
            "$($_.Field) would change from '$($_.Before)' to '$($_.After)', which weakens protection."
        })

    $Rollback = @{
        Description = 'Replay these Exchange commands to restore the snapshot taken before the change.'
        Commands    = @($Plan.Rollback)
    }

    $Outcome = [ordered]@{
        Results                 = $null
        DryRun                  = [bool]$DryRun
        Applied                 = $false
        Blocked                 = [bool]$Blocked
        BlockReasons            = @($Reasons)
        AllowWeakerProtection   = [bool]$AllowWeakerProtection
        TicketNumber            = $TicketNumber
        Caller                  = $Caller
        Operation               = $Operation
        ApiName                 = $ApiName
        Diff                    = @($Diff)
        Snapshot                = $Plan.Snapshot
        Rollback                = $Rollback
        Commands                = @($Plan.Commands)
        Error                   = $null
    }

    if ($Blocked) {
        $Outcome.Results = "Blocked $($Operation). Protection would be weaker than it is now. Pass allowWeakerProtection true to override. $($Reasons -join ' ')"
        $null = Add-CIPPMailFilterAudit -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller -Operation $Operation -Result 'Blocked' -DryRun $DryRun -Blocked $true -Applied $false -Diff $Diff -Snapshot $Plan.Snapshot -Rollback $Rollback.Commands -ErrorSummary ($Reasons -join ' ')
        return $Outcome
    }

    if ($DryRun) {
        $Outcome.Results = "Dry run for $($Operation). No changes were applied."
        $null = Add-CIPPMailFilterAudit -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller -Operation $Operation -Result 'DryRun' -DryRun $true -Blocked $false -Applied $false -Diff $Diff -Snapshot $Plan.Snapshot -Rollback $Rollback.Commands
        return $Outcome
    }

    if (@($Plan.Commands).Count -eq 0) {
        $Outcome.Applied = $true
        $Outcome.Results = "$Operation already matches the requested settings."
        $null = Add-CIPPMailFilterAudit -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller -Operation $Operation -Result 'Unchanged' -DryRun $false -Blocked $false -Applied $true -Diff $Diff -Snapshot $Plan.Snapshot -Rollback $Rollback.Commands
        return $Outcome
    }

    try {
        foreach ($Command in @($Plan.Commands)) {
            $null = Invoke-CIPPMailFilterExo -TenantFilter $TenantFilter -Command $Command
        }
        $Outcome.Applied = $true
        $OverrideNote = if ($AllowWeakerProtection -and $Weaker.Count -gt 0) { ' Weaker protection was applied because allowWeakerProtection was set.' } else { '' }
        $Outcome.Results = "Applied $($Operation) for ticket $TicketNumber by $Caller.$OverrideNote"
        $null = Add-CIPPMailFilterAudit -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller -Operation $Operation -Result 'Applied' -DryRun $false -Blocked $false -Applied $true -Diff $Diff -Snapshot $Plan.Snapshot -Rollback $Rollback.Commands
    } catch {
        $Outcome.Error = $_.Exception.Message
        $Outcome.Results = "Failed $($Operation) after snapshot. $($_.Exception.Message)"
        $null = Add-CIPPMailFilterAudit -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller -Operation $Operation -Result 'Failed' -DryRun $false -Blocked $false -Applied $false -Diff $Diff -Snapshot $Plan.Snapshot -Rollback $Rollback.Commands -ErrorSummary $_.Exception.Message
    }

    return $Outcome
}
