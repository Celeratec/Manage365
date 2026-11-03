function Invoke-CIPPMailboxJunkConfiguration {
    <#
    .SYNOPSIS
        Adds or removes trusted and blocked senders on a mailbox junk configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$TicketNumber,
        [Parameter(Mandatory)][string]$Caller,
        [Parameter(Mandatory)][string]$Mailbox,
        $TrustedToAdd,
        $TrustedToRemove,
        $BlockedToAdd,
        $BlockedToRemove,
        $DryRun,
        [string]$ApiName = 'ExecMailboxJunkConfiguration'
    )

    $Tenant = Test-CIPPMailFilterIdentity -Value $TenantFilter -Label 'tenantFilter'
    $Ticket = Test-CIPPMailFilterTicket -TicketNumber $TicketNumber
    $Identity = Test-CIPPMailFilterIdentity -Value $Mailbox -Label 'mailbox'
    $Current = New-ExoRequest -tenantid $Tenant -Anchor $Identity -cmdlet 'Get-MailboxJunkEmailConfiguration' -cmdParams @{ Identity = $Identity } -useSystemMailbox $true

    $Plan = Get-CIPPMailboxJunkChange -Mailbox $Identity -Configuration $Current `
        -TrustedToAdd $TrustedToAdd -TrustedToRemove $TrustedToRemove `
        -BlockedToAdd $BlockedToAdd -BlockedToRemove $BlockedToRemove

    return Invoke-CIPPMailFilterApply -TenantFilter $Tenant -TicketNumber $Ticket -Caller $Caller `
        -Operation "mailbox junk $Identity" -DryRun (ConvertTo-CIPPMailFilterBool $DryRun) `
        -AllowWeakerProtection $false -Plan $Plan -ApiName $ApiName
}
