function Get-CIPPFocusedInboxChange {
    <#
    .SYNOPSIS
        Builds a per-mailbox or organisation Focused Inbox change.
    #>
    param(
        [Parameter(Mandatory)][string]$Scope,
        [string]$Mailbox,
        $Enabled,
        $Current
    )

    $Target = [bool](ConvertTo-CIPPMailFilterBool -Value $Enabled)
    $Commands = @()
    $Rollback = @()
    $Snapshot = [ordered]@{ Scope = $null; FocusedInboxOn = $null }

    switch ($Scope) {
        { $_ -in 'Mailbox', 'mailbox' } {
            $Identity = Test-CIPPMailFilterIdentity -Value $Mailbox -Label 'mailbox'
            $Before = Get-CIPPMailFilterProperty $Current 'FocusedInboxOn'
            $BeforeBool = [bool](ConvertTo-CIPPMailFilterBool $Before)
            $Snapshot.Scope = 'Mailbox'
            $Snapshot.Mailbox = $Identity
            $Snapshot.FocusedInboxOn = $BeforeBool
            $Diff = @(Get-CIPPMailFilterDiffRow -Field 'FocusedInboxOn' -Before ([string]$BeforeBool) -After ([string]$Target) -ProtectionActive $false)
            if ($BeforeBool -ne $Target) {
                $Parameters = @{ Identity = $Identity; FocusedInboxOn = $Target }
                $Undo = @{ Identity = $Identity; FocusedInboxOn = $BeforeBool }
                $Commands = @(@{ Cmdlet = 'Set-FocusedInbox'; Parameters = $Parameters; Anchor = $Identity })
                $Rollback = @(@{ Cmdlet = 'Set-FocusedInbox'; Parameters = $Undo; Anchor = $Identity })
            }
        }
        { $_ -in 'Organization', 'Org', 'organisation', 'organization' } {
            $Before = Get-CIPPMailFilterProperty $Current 'FocusedInboxOn'
            $BeforeBool = [bool](ConvertTo-CIPPMailFilterBool $Before)
            $Snapshot.Scope = 'Organization'
            $Snapshot.FocusedInboxOn = $BeforeBool
            $Diff = @(Get-CIPPMailFilterDiffRow -Field 'FocusedInboxOn' -Before ([string]$BeforeBool) -After ([string]$Target) -ProtectionActive $false)
            if ($BeforeBool -ne $Target) {
                $Commands = @(@{ Cmdlet = 'Set-OrganizationConfig'; Parameters = @{ FocusedInboxOn = $Target } })
                $Rollback = @(@{ Cmdlet = 'Set-OrganizationConfig'; Parameters = @{ FocusedInboxOn = $BeforeBool } })
            }
        }
        default { throw 'scope must be Mailbox or Organization.' }
    }

    @{
        Snapshot = $Snapshot
        Diff     = @($Diff | Where-Object { $_ })
        Commands = $Commands
        Rollback = $Rollback
    }
}
