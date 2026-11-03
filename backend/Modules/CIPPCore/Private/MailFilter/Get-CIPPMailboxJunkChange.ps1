function Get-CIPPMailboxJunkChange {
    <#
    .SYNOPSIS
        Builds a junk-sender change that merges into the current list.
    #>
    param(
        [Parameter(Mandatory)][string]$Mailbox,
        $Configuration,
        $TrustedToAdd,
        $TrustedToRemove,
        $BlockedToAdd,
        $BlockedToRemove
    )

    $Identity = Test-CIPPMailFilterIdentity -Value $Mailbox -Label 'mailbox'
    $TrustedAdd = @(ConvertTo-CIPPMailFilterStringList $TrustedToAdd)
    $TrustedRemove = @(ConvertTo-CIPPMailFilterStringList $TrustedToRemove)
    $BlockedAdd = @(ConvertTo-CIPPMailFilterStringList $BlockedToAdd)
    $BlockedRemove = @(ConvertTo-CIPPMailFilterStringList $BlockedToRemove)
    if (($TrustedAdd.Count + $TrustedRemove.Count + $BlockedAdd.Count + $BlockedRemove.Count) -eq 0) {
        throw 'Send a trusted or blocked sender to add or remove.'
    }

    $CurrentTrusted = Get-CIPPMailFilterProperty $Configuration 'TrustedSendersAndDomains'
    $CurrentBlocked = Get-CIPPMailFilterProperty $Configuration 'BlockedSendersAndDomains'
    $Parameters = @{ Identity = $Identity }
    $RollbackParameters = @{ Identity = $Identity }
    $Diff = [System.Collections.Generic.List[object]]::new()

    if ($TrustedAdd.Count -gt 0 -or $TrustedRemove.Count -gt 0) {
        $Merged = Join-CIPPMailboxJunkSenderList -Existing $CurrentTrusted -Add $TrustedAdd -Remove $TrustedRemove
        $Parameters.TrustedSendersAndDomains = @($Merged.List)
        $Before = @(ConvertTo-CIPPMailFilterStringList $CurrentTrusted)
        $RollbackParameters.TrustedSendersAndDomains = if ($Before.Count -eq 0) { @() } else { $Before }
        $Row = Get-CIPPMailFilterDiffRow -Field 'TrustedSendersAndDomains' -Before $Before -After @($Merged.List) -ProtectionActive $false
        if ($Row) { $Diff.Add($Row) }
    }
    if ($BlockedAdd.Count -gt 0 -or $BlockedRemove.Count -gt 0) {
        $MergedBlocked = Join-CIPPMailboxJunkSenderList -Existing $CurrentBlocked -Add $BlockedAdd -Remove $BlockedRemove
        $Parameters.BlockedSendersAndDomains = @($MergedBlocked.List)
        $BeforeBlocked = @(ConvertTo-CIPPMailFilterStringList $CurrentBlocked)
        $RollbackParameters.BlockedSendersAndDomains = if ($BeforeBlocked.Count -eq 0) { @() } else { $BeforeBlocked }
        $Row = Get-CIPPMailFilterDiffRow -Field 'BlockedSendersAndDomains' -Before $BeforeBlocked -After @($MergedBlocked.List) -ProtectionActive $false
        if ($Row) { $Diff.Add($Row) }
    }

    $Commands = @()
    $Rollback = @()
    if ($Diff.Count -gt 0) {
        $Commands = @(@{ Cmdlet = 'Set-MailboxJunkEmailConfiguration'; Parameters = $Parameters; Anchor = $Identity })
        $Rollback = @(@{ Cmdlet = 'Set-MailboxJunkEmailConfiguration'; Parameters = $RollbackParameters; Anchor = $Identity })
    }

    @{
        Snapshot = [ordered]@{
            Identity                  = $Identity
            TrustedSendersAndDomains  = @(ConvertTo-CIPPMailFilterStringList $CurrentTrusted)
            BlockedSendersAndDomains  = @(ConvertTo-CIPPMailFilterStringList $CurrentBlocked)
        }
        Diff     = @($Diff)
        Commands = $Commands
        Rollback = $Rollback
    }
}
