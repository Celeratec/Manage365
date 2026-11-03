function Invoke-CIPPFocusedInbox {
    <#
    .SYNOPSIS
        Turns Focused Inbox on or off for one mailbox or the whole organisation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$TicketNumber,
        [Parameter(Mandatory)][string]$Caller,
        [Parameter(Mandatory)][string]$Scope,
        [string]$Mailbox,
        $Enabled,
        $DryRun,
        [string]$ApiName = 'ExecFocusedInbox'
    )

    $Tenant = Test-CIPPMailFilterIdentity -Value $TenantFilter -Label 'tenantFilter'
    $Ticket = Test-CIPPMailFilterTicket -TicketNumber $TicketNumber
    $NormalScope = switch ($Scope) {
        { $_ -in 'Mailbox', 'mailbox' } { 'Mailbox' }
        { $_ -in 'Organization', 'Org', 'organisation', 'organization' } { 'Organization' }
        default { throw 'scope must be Mailbox or Organization.' }
    }

    if ($NormalScope -eq 'Mailbox') {
        $Identity = Test-CIPPMailFilterIdentity -Value $Mailbox -Label 'mailbox'
        $Current = New-ExoRequest -tenantid $Tenant -Anchor $Identity -cmdlet 'Get-FocusedInbox' -cmdParams @{ Identity = $Identity } -useSystemMailbox $true
    } else {
        $Identity = $null
        $Current = New-ExoRequest -tenantid $Tenant -cmdlet 'Get-OrganizationConfig' -useSystemMailbox $true
    }

    $Plan = Get-CIPPFocusedInboxChange -Scope $NormalScope -Mailbox $Identity -Enabled $Enabled -Current $Current
    return Invoke-CIPPMailFilterApply -TenantFilter $Tenant -TicketNumber $Ticket -Caller $Caller `
        -Operation "focused inbox $NormalScope" -DryRun (ConvertTo-CIPPMailFilterBool $DryRun) `
        -AllowWeakerProtection $false -Plan $Plan -ApiName $ApiName
}
