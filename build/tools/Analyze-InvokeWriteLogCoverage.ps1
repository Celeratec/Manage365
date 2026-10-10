<#
.SYNOPSIS
  Refined analysis: mutating CIPPHTTP Invoke-* endpoints vs customer Write-LogMessage.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BackendRoot,
    [Parameter(Mandatory)][string]$OutJson
)

$ErrorActionPreference = 'Stop'
$httpRoot = Join-Path $BackendRoot 'Modules\CIPPHTTP\Public\Entrypoints\HTTP Functions'
$modulesRoot = Join-Path $BackendRoot 'Modules'

Write-Host 'Indexing functions...'
$functionIndex = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
Get-ChildItem -Path $modulesRoot -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\CIPP(Core|HTTP|Standards|Applications|Extensions)\\' -and $_.FullName -notmatch '\\Tests\\' } |
    ForEach-Object {
        $text = [IO.File]::ReadAllText($_.FullName)
        foreach ($m in [regex]::Matches($text, '(?im)^\s*function\s+([A-Za-z][\w-]*)')) {
            $fn = $m.Groups[1].Value
            if (-not $functionIndex.ContainsKey($fn)) { $functionIndex[$fn] = $_.FullName }
        }
    }
Write-Host "Indexed $($functionIndex.Count) functions"

function Get-LogSevs([string]$Content) {
    $sevs = [System.Collections.Generic.List[string]]::new()
    $lines = $Content -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch 'Write-LogMessage') { continue }
        $window = ($lines[$i..([Math]::Min($i + 4, $lines.Count - 1))] -join ' ')
        $sev = 'Unknown'
        if ($window -match '(?i)-sev(?:erity)?\s+[''"]?(\w+)') { $sev = $Matches[1] }
        $sevs.Add($sev)
    }
    return $sevs
}

function Test-HasCustomerLog([string]$Content) {
    $sevs = Get-LogSevs $Content
    $customer = @($sevs | Where-Object { $_ -notmatch '^(?i)Debug$' })
    return [pscustomobject]@{
        Any      = ($sevs.Count -gt 0)
        Customer = ($customer.Count -gt 0)
        DebugOnly = ($sevs.Count -gt 0 -and $customer.Count -eq 0)
        Sevs     = @($sevs | Select-Object -Unique)
        Count    = $sevs.Count
    }
}

function Get-MutationCallees([string]$Content, [string]$SelfName) {
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    # Mutation-oriented CIPP helpers (include New-/Request-/Get- for create and sensitive retrievals)
    $pat = '(?i)(?<!function\s)(?<![\w-])((?:New|Set|Add|Remove|Update|Clear|Reset|Save|Send|Start|Stop|Deploy|Apply|Grant|Revoke|Assign|Restore|Empty|Sync|Edit|Delete|Create|Offboard|Onboard|Queue|Convert|Copy|Clone|Enable|Disable|Toggle|Snooze|Wipe|Publish|Import|Export|Submit|Register|Unregister|Process|Handle|Ensure|Merge|Dismiss|Escalate|Invite|Approve|Reject|Cancel|Schedule|Trigger|Retry|Unblock|Upload|Rename|Extend|Deny|Hijack|Refresh|Push|Request|Get)-Cipp[\w-]*)'
    foreach ($m in [regex]::Matches($Content, $pat)) {
        $fn = $m.Groups[1].Value
        if ($fn -eq $SelfName) { continue }
        if ($fn -match '(?i)^(Add|Remove|Get)-CIPPAzDataTableEntity$') { continue }
        if ($fn -match '(?i)^Get-CIPP(Table|Exception|TextReplacement|QueueData|Hostname|SiteHostname|Authentication|AzDataTableEntity)') { continue }
        [void]$set.Add($fn)
    }
    foreach ($m in [regex]::Matches($Content, '(?i)(?<!function\s)(?<![\w-])(Invoke-CIPP[\w-]*)')) {
        $fn = $m.Groups[1].Value
        if ($fn -eq $SelfName) { continue }
        if ($functionIndex.ContainsKey($fn) -and $functionIndex[$fn] -match 'HTTP Functions') { continue }
        [void]$set.Add($fn)
    }
    foreach ($m in [regex]::Matches($Content, '(?i)(?<!function\s)(?<![\w-])((?:Start-\w+Orchestrator|Remove-ExtensionAPIKey)\b)')) {
        [void]$set.Add($m.Groups[1].Value)
    }
    return @($set)
}

# Exec endpoints that are clearly read/search/diagnostic (not tenant/config mutation for audit purposes)
$excludeAsNonMutating = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@(
    'Invoke-ExecAPIPermissionList','Invoke-ExecBackendURLs','Invoke-ExecLicenseSearch','Invoke-ExecBreachSearch',
    'Invoke-ExecGeoIPLookup','Invoke-ExecAppInsightsQuery','Invoke-ExecAzBobbyTables','Invoke-ExecBECCheck',
    'Invoke-ExecCompareIntunePolicy','Invoke-ExecListAppId','Invoke-ExecMcp','Invoke-PublicPing',
    'Invoke-ExecUniversalSearch','Invoke-ExecUniversalSearchV2','Invoke-ExecBitlockerSearch',
    'Invoke-ExecIncidentsList','Invoke-ExecMdoAlertsList','Invoke-ExecAlertsList','Invoke-ExecMailTest','Invoke-ExecAccessChecks',
    'Invoke-ExecExtensionTest','Invoke-ExecSamSecretStatus','Invoke-ExecListBackup','Invoke-ExecCACheck',
    'Invoke-ExecGraphRequestProfile','Invoke-ExecDeviceCodeLogon','Invoke-ExecDurableFunctions',
    'Invoke-ExecCippFunction','Invoke-ExecCombinedSetup','Invoke-PublicPhishingCheck','Invoke-ExecAppApproval'
) | ForEach-Object { [void]$excludeAsNonMutating.Add($_) }

$results = [System.Collections.Generic.List[object]]::new()
$files = Get-ChildItem -Path $httpRoot -Recurse -Filter 'Invoke-*.ps1'
Write-Host "Scanning $($files.Count) endpoints..."

foreach ($f in $files) {
    $name = $f.BaseName
    $short = $name -replace '^Invoke-', ''
    $rel = $f.FullName.Substring($httpRoot.Length + 1)
    $area = if ($rel -match '^([^\\]+)\\') { $Matches[1] } else { 'Root' }
    $content = [IO.File]::ReadAllText($f.FullName)

    if ($excludeAsNonMutating.Contains($name)) { continue }
    if ($short -match '^(List|Get)') { continue }

    $nameLooksMutating = $short -match '^(Exec|Add|Edit|Remove|Set|Update|Delete|Create|Push|Patch|New|Save|Send|Deploy|Apply|Clear|Reset|Start|Stop|Enable|Disable|Assign|Revoke|Restore|Empty|Offboard|Refresh|Clone|Queue|Bulk|Convert|Dismiss|Invite|Move|Publish|Retry|Sync|Toggle|Unblock|Upload|Wipe|Rename|Extend|Grant|Deny|Approve|Reject|Cancel|Schedule|Trigger|Import|Export|Copy|Duplicate|Hijack|Snooze|Public)'

    $signals = @()
    if ($content -match 'New-GraphPostRequest|New-GraphPOSTRequest|New-GraphBulkRequest') { $signals += 'GraphWrite' }
    if ($content -match 'New-ExoRequest') { $signals += 'Exo' }
    if ($content -match 'Add-CIPPAzDataTableEntity|Remove-CIPPAzDataTableEntity') { $signals += 'TableWrite' }
    if ($content -match 'New-CippQueueEntry|Push-OutputBinding') { $signals += 'Queue' }
    if ($content -match '(?i)-type\s+[''"]?(PATCH|POST|PUT|DELETE)|type\s*=\s*[''"]?(PATCH|POST|PUT|DELETE)') { $signals += 'HttpWrite' }

    if (-not $nameLooksMutating -and $signals.Count -eq 0) { continue }

    # Soft-exclude pure "search/list disguised as Exec" if no write signals
    if ($short -match 'Search$' -and $signals.Count -eq 0 -and $content -notmatch 'Add-CIPPAzDataTableEntity') { continue }

    $direct = Test-HasCustomerLog $content
    $coverage = 'missing'
    $via = $null
    $notes = @()

    if ($direct.Customer) {
        $coverage = 'direct'
        $via = $name
    } else {
        $callees = Get-MutationCallees -Content $content -SelfName $name
        $found = $false
        foreach ($fn in $callees) {
            if (-not $functionIndex.ContainsKey($fn)) { continue }
            $calContent = [IO.File]::ReadAllText($functionIndex[$fn])
            $cal = Test-HasCustomerLog $calContent
            if ($cal.Customer) {
                $coverage = 'via-helper'
                $via = $fn
                $found = $true
                $notes += "helper:$fn sevs=$($cal.Sevs -join '|')"
                break
            }
            # one more level of mutation helpers
            $nested = Get-MutationCallees -Content $calContent -SelfName $fn
            foreach ($nfn in $nested) {
                if (-not $functionIndex.ContainsKey($nfn)) { continue }
                $ncal = Test-HasCustomerLog ([IO.File]::ReadAllText($functionIndex[$nfn]))
                if ($ncal.Customer) {
                    $coverage = 'via-helper'
                    $via = "$fn -> $nfn"
                    $found = $true
                    $notes += "nested:$via sevs=$($ncal.Sevs -join '|')"
                    break
                }
            }
            if ($found) { break }
        }

        if (-not $found) {
            if ($direct.DebugOnly) {
                $coverage = 'debug-only'
                $notes += "direct debug sevs=$($direct.Sevs -join '|')"
            } else {
                $coverage = 'missing'
            }
        }
    }

    # Classify mutation kind
    $kind = 'tenant-or-config'
    if ($signals -contains 'TableWrite' -and $signals.Count -eq 1 -and $area -eq 'CIPP') { $kind = 'cipp-settings' }
    if ($short -match 'Bookmark|UserSettings|DiagnosticsPreset|PartnerMode|Extension|Branding|DnsConfig|CustomRole|ApiClient|Notification|TenantGroup|Offload|Replacemap|CloneTemplate|SAMRoles|Webhook|TrustedIP|Container|Permission|CPV|RefreshMyAccess|TokenExchange|CreateSAM|AddTenant') {
        $kind = 'cipp-settings'
    }

    $results.Add([pscustomobject]@{
            Name         = $name
            Area         = $area
            Rel          = $rel
            Kind         = $kind
            Signals      = ($signals -join ',')
            Coverage     = $coverage
            CoverageVia  = $via
            DirectSevs   = ($direct.Sevs -join ',')
            Notes        = ($notes -join '; ')
        })
}

$covered = @($results | Where-Object Coverage -in @('direct','via-helper'))
$summary = [pscustomobject]@{
    MutatingTotal = $results.Count
    Direct        = @($results | Where-Object Coverage -eq 'direct').Count
    ViaHelper     = @($results | Where-Object Coverage -eq 'via-helper').Count
    DebugOnly     = @($results | Where-Object Coverage -eq 'debug-only').Count
    Missing       = @($results | Where-Object Coverage -eq 'missing').Count
    CoveredPct    = [math]::Round(100.0 * $covered.Count / [Math]::Max($results.Count,1), 1)
}

$byArea = $results | Group-Object Area | ForEach-Object {
    $g = $_.Group
    [pscustomobject]@{
        Area      = $_.Name
        Total     = $g.Count
        Covered   = @($g | Where-Object Coverage -in @('direct','via-helper')).Count
        Missing   = @($g | Where-Object Coverage -eq 'missing').Count
        DebugOnly = @($g | Where-Object Coverage -eq 'debug-only').Count
    }
} | Sort-Object Missing, DebugOnly -Descending

$payload = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Method = 'Mutating HTTP Invoke-* (non-List/Get); customer Write-LogMessage = sev not Debug; helpers = Set/Add/Remove-CIPP* etc.'
    Summary = $summary
    ByArea = @($byArea)
    Missing = @($results | Where-Object Coverage -eq 'missing' | Sort-Object Area, Name)
    DebugOnly = @($results | Where-Object Coverage -eq 'debug-only' | Sort-Object Area, Name)
    ViaHelper = @($results | Where-Object Coverage -eq 'via-helper' | Sort-Object Area, Name)
    All = @($results | Sort-Object Area, Name)
}
$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $OutJson -Encoding UTF8
Write-Host ''
$summary | Format-List
Write-Host '=== MISSING ==='
$payload.Missing | Select-Object Area, Name, Kind, Signals | Format-Table -AutoSize
Write-Host '=== DEBUG-ONLY ==='
$payload.DebugOnly | Select-Object Area, Name, DirectSevs, Notes | Format-Table -AutoSize -Wrap
Write-Host '=== VIA HELPER ==='
$payload.ViaHelper | Select-Object Area, Name, CoverageVia | Format-Table -AutoSize -Wrap
Write-Host "Wrote $OutJson"
