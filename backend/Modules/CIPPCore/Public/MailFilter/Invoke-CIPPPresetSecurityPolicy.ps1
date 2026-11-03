function Invoke-CIPPPresetSecurityPolicy {
    <#
    .SYNOPSIS
        Turns a Standard or Strict preset on or off, and changes who it covers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$TicketNumber,
        [Parameter(Mandatory)][string]$Caller,
        [Parameter(Mandatory)][string]$Preset,
        [string]$State,
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
        $ExceptDomains,
        $DryRun,
        $AllowWeakerProtection,
        [string]$ApiName = 'ExecPresetSecurityPolicy'
    )

    $Tenant = Test-CIPPMailFilterIdentity -Value $TenantFilter -Label 'tenantFilter'
    $Ticket = Test-CIPPMailFilterTicket -TicketNumber $TicketNumber
    $Identity = Get-CIPPPresetSecurityPolicyIdentity -Preset $Preset

    $EopRules = @(New-ExoRequest -tenantid $Tenant -cmdlet 'Get-EOPProtectionPolicyRule' -useSystemMailbox $true)
    $Eop = $EopRules | Where-Object { $_.Identity -eq $Identity -or $_.Name -eq $Identity } | Select-Object -First 1
    $AtpRules = @(New-ExoRequest -tenantid $Tenant -cmdlet 'Get-ATPProtectionPolicyRule' -useSystemMailbox $true)
    $Atp = $AtpRules | Where-Object { $_.Identity -eq $Identity -or $_.Name -eq $Identity } | Select-Object -First 1

    $Plan = Get-CIPPPresetSecurityPolicyChange -Preset $Preset -State $State -EopRule $Eop -AtpRule $Atp `
        -HasUsers $HasUsers -Users $Users -HasGroups $HasGroups -Groups $Groups -HasDomains $HasDomains -Domains $Domains `
        -HasExceptUsers $HasExceptUsers -ExceptUsers $ExceptUsers -HasExceptGroups $HasExceptGroups -ExceptGroups $ExceptGroups `
        -HasExceptDomains $HasExceptDomains -ExceptDomains $ExceptDomains

    return Invoke-CIPPMailFilterApply -TenantFilter $Tenant -TicketNumber $Ticket -Caller $Caller `
        -Operation "preset $Preset" -DryRun (ConvertTo-CIPPMailFilterBool $DryRun) `
        -AllowWeakerProtection (ConvertTo-CIPPMailFilterBool $AllowWeakerProtection) `
        -Plan $Plan -ApiName $ApiName
}
