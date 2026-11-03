function Invoke-CIPPCustomMailFilterPolicy {
    <#
    .SYNOPSIS
        Creates, updates, or deletes a custom anti-spam, anti-phish, or anti-malware policy and its rule.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$TicketNumber,
        [Parameter(Mandatory)][string]$Caller,
        [Parameter(Mandatory)][string]$PolicyType,
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$Name,
        [string]$RuleName,
        [hashtable]$Settings = @{},
        [hashtable]$RuleSettings = @{},
        $DryRun,
        $AllowWeakerProtection,
        [string]$ApiName = 'ExecCustomMailFilterPolicy'
    )

    $Tenant = Test-CIPPMailFilterIdentity -Value $TenantFilter -Label 'tenantFilter'
    $Ticket = Test-CIPPMailFilterTicket -TicketNumber $TicketNumber
    $Catalog = Get-CIPPCustomMailFilterCatalog -PolicyType $PolicyType
    $PolicyName = $Name.Trim()
    $ResolvedRule = if ([string]::IsNullOrWhiteSpace($RuleName)) { $PolicyName } else { $RuleName.Trim() }

    $Policies = @(New-ExoRequest -tenantid $Tenant -cmdlet "Get-$($Catalog.PolicyCmdlet)" -useSystemMailbox $true)
    $Policy = $Policies | Where-Object { $_.Identity -eq $PolicyName -or $_.Name -eq $PolicyName } | Select-Object -First 1
    $Baseline = $Policies | Where-Object { $_.Name -eq 'Default' -or $_.IsDefault -eq $true } | Select-Object -First 1
    $Rules = @(New-ExoRequest -tenantid $Tenant -cmdlet "Get-$($Catalog.RuleCmdlet)" -useSystemMailbox $true)
    $Rule = $Rules | Where-Object {
        $_.Identity -eq $ResolvedRule -or $_.Name -eq $ResolvedRule -or $_.($Catalog.PolicyLink) -eq $PolicyName
    } | Select-Object -First 1

    $Plan = Get-CIPPCustomMailFilterChange -PolicyType $Catalog.Type -Operation $Operation -Name $PolicyName `
        -RuleName $ResolvedRule -Policy $Policy -Rule $Rule -BaselinePolicy $Baseline `
        -Settings $Settings -RuleSettings $RuleSettings

    return Invoke-CIPPMailFilterApply -TenantFilter $Tenant -TicketNumber $Ticket -Caller $Caller `
        -Operation "$($Catalog.Type) $Operation $PolicyName" -DryRun (ConvertTo-CIPPMailFilterBool $DryRun) `
        -AllowWeakerProtection (ConvertTo-CIPPMailFilterBool $AllowWeakerProtection) `
        -Plan $Plan -ApiName $ApiName
}
