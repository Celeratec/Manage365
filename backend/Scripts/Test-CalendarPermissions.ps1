<#
.SYNOPSIS
    Smoke-test calendar permission read/write against a live Manage365 / CIPP API deployment.

.PARAMETER BaseUrl
    API root, e.g. https://manage365.celeratec.cloud

.PARAMETER TenantFilter
    Tenant default domain or customer id.

.PARAMETER MailboxUpn
    Mailbox whose calendar is modified.

.PARAMETER GranteeUpn
    User receiving calendar access (Reviewer, etc.).

.PARAMETER AccessLevel
    Exchange calendar folder access right (AvailabilityOnly, LimitedDetails, Reviewer, Editor, etc.).

.EXAMPLE
    ./Test-CalendarPermissions.ps1 -BaseUrl https://manage365.celeratec.cloud `
        -TenantFilter aaronmillerlaw.com -MailboxUpn csc@aaronmillerlaw.com `
        -GranteeUpn aaron@aaronmillerlaw.com -AccessLevel Reviewer
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$TenantFilter,

    [Parameter(Mandatory = $true)]
    [string]$MailboxUpn,

    [Parameter(Mandatory = $true)]
    [string]$GranteeUpn,

    [string]$AccessLevel = 'Reviewer'
)

$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')

function Invoke-Manage365Api {
    param([string]$Method, [string]$Path, [hashtable]$Query, [object]$Body)
    $Uri = "$BaseUrl$Path"
    if ($Query -and $Query.Count -gt 0) {
        $Uri += '?' + (($Query.GetEnumerator() | ForEach-Object { "{0}={1}" -f [uri]::EscapeDataString($_.Key), [uri]::EscapeDataString([string]$_.Value) }) -join '&')
    }
    $Params = @{ Method = $Method; Uri = $Uri; Headers = @{ Accept = 'application/json' } }
    if ($Body) {
        $Params.ContentType = 'application/json'
        $Params.Body = ($Body | ConvertTo-Json -Depth 6 -Compress)
    }
    Write-Host ">> $Method $Uri"
    return Invoke-RestMethod @Params
}

Write-Host '--- List (before) ---'
$Before = Invoke-Manage365Api -Method GET -Path '/api/ListCalendarPermissions' -Query @{
    tenantFilter = $TenantFilter
    UserID       = $MailboxUpn
}
$Before | ConvertTo-Json -Depth 8

Write-Host '--- Add / Set ---'
$EditBody = @{
    tenantFilter           = $TenantFilter
    userid                 = $MailboxUpn
    FolderName             = 'Calendar'
    UserToGetPermissions   = @{ value = $GranteeUpn }
    Permissions            = @{ value = $AccessLevel }
    CanViewPrivateItems    = $false
}
$Edit = Invoke-Manage365Api -Method POST -Path '/api/ExecEditCalendarPermissions' -Body $EditBody
$Edit | ConvertTo-Json -Depth 6

Write-Host '--- List (after) ---'
$After = Invoke-Manage365Api -Method GET -Path '/api/ListCalendarPermissions' -Query @{
    tenantFilter = $TenantFilter
    UserID       = $MailboxUpn
}
$After | ConvertTo-Json -Depth 8

$Found = @($After | Where-Object { $_.UserEmail -eq $GranteeUpn -or $_.User -eq $GranteeUpn })
if ($Found.Count -lt 1) {
    throw "Grantee $GranteeUpn not found on calendar after set."
}

Write-Host '--- Remove ---'
$RemoveBody = @{
    tenantFilter = $TenantFilter
    userid       = $MailboxUpn
    FolderName   = 'Calendar'
    RemoveAccess = @{ value = $GranteeUpn }
}
$Removed = Invoke-Manage365Api -Method POST -Path '/api/ExecEditCalendarPermissions' -Body $RemoveBody
$Removed | ConvertTo-Json -Depth 6

Write-Host 'Calendar permission smoke test completed successfully.'
