# Purview eDiscovery Stats-First Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship dedicated per-tenant Graph eDiscovery (config + readiness + migrated Cases endpoints + stats-only `ExecEdiscoverySearch`) behind `EdiscoverySearch` (Enabled true), then cut over production.

**Architecture:** AzureArm twin: `EdiscoveryConfig` table (appId + Key Vault cert name only), `Get-CIPPEdiscoveryAccessToken` (refuse SAM), `Invoke-CIPPEdiscoveryRequest` (graph.microsoft.com + allowlist), guarded writes with `DefaultDryRun`, counts-only redaction. SAM Graph blocklist stays. Hold-remove / case-delete / purge always refuse.

**Tech Stack:** PowerShell Azure Functions (CIPP modules), Azure Table Storage, Key Vault cert refs, Microsoft Graph eDiscovery API, Pester, FeatureFlags.json.

**Spec:** `docs/superpowers/specs/2026-11-23-ediscovery-search-design.md`  
**Client ticket:** #3276171 (client matter only)  
**Build ticket:** open dedicated internal ticket before non-dry-run audits (placeholder in docs until known)

## Global Constraints

- Synthetic fixtures only: `contoso.onmicrosoft.com`, GUIDs like `11111111-1111-1111-1111-111111111111`, `custodian@contoso.example`, case label `Example Matter 2026-001`, terms `"project falcon"`, ticket `1234567`.
- No client names, real tenant IDs, mailboxes, custodians, app IDs, or ticket body text in code, tests, docs, commits, or PR text.
- Never store or accept PFX/private key/secret values in API bodies or tables — Key Vault **names** only.
- Never use CIPP SAM (`$env:ApplicationID`) for eDiscovery tokens.
- Never log access tokens, report `downloadUrl`s, subjects, snippets, or item content.
- `dryRun` defaults **true** on every new write path (`-DefaultDryRun`).
- `reason` required (non-empty) on every guarded eDiscovery write.
- Purge, hold-remove, case-delete: always 400, no network.
- Branch: `clint/<short-desc>` per PR; draft PRs; lint/typecheck/tests; Aikido on first-party code; no `--no-verify`.
- Spike defaults until test-tenant note exists: per-term = N estimates if keyword report has content; KQL dates use `sent`; mailbox-only (archive TBD).

## File map

| Path | Responsibility |
|------|----------------|
| `backend/Config/FeatureFlags.json` | `EdiscoverySearch` flag, Enabled true, endpoint list |
| `backend/Config/GuardedWrites/EdiscoveryAllowlist.json` | Exact Graph method/path templates |
| `backend/Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryTenantConfig.ps1` | Table read |
| `backend/Modules/CIPPCore/Public/Ediscovery/Set-CIPPEdiscoveryTenantConfig.ps1` | Table upsert (refs only) |
| `backend/Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryAccessToken.ps1` | Cert client-credentials; refuse SAM |
| `backend/Modules/CIPPCore/Public/Ediscovery/Invoke-CIPPEdiscoveryRequest.ps1` | Hardened Graph client + poll |
| `backend/Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryGraphPlan.ps1` | Allowlist path builder |
| `backend/Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryReadiness.ps1` | Readiness result object |
| `backend/Modules/CIPPCore/Public/Ediscovery/Test-CIPPEdiscoveryForbiddenAction.ps1` | Refuse purge/delete/hold-remove |
| `backend/Modules/CIPPCore/Public/Ediscovery/New-CIPPEdiscoveryKql.ps1` | Validated KQL builder |
| `backend/Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoverySearchPlan.ps1` | Stats dry-run / live plan |
| `backend/Modules/CIPPCore/Public/Ediscovery/Invoke-CIPPEdiscoverySearchAction.ps1` | Stats orchestration |
| `backend/Modules/CIPPCore/Public/Ediscovery/ConvertTo-CIPPEdiscoveryCountsOnly.ps1` | Strip content-like fields |
| `backend/Modules/CIPPHTTP/.../Security/Invoke-ExecEdiscoveryConfig.ps1` | Config upsert entrypoint |
| `backend/Modules/CIPPHTTP/.../Security/Invoke-ListEdiscoveryConfig.ps1` | Sanitized config |
| `backend/Modules/CIPPHTTP/.../Security/Invoke-ListEdiscoveryReadiness.ps1` | Readiness |
| `backend/Modules/CIPPHTTP/.../Security/Invoke-ExecEdiscoverySearch.ps1` | Stats-only entrypoint |
| Existing `Invoke-*Ediscovery*` | Dedicated token + forbid dangerous actions |
| `backend/Tests/Ediscovery/*.Tests.ps1` | Pester |
| `docs/api-documentation/ediscovery-search.md` | API + runbook |
| `frontend` Cases banner | Point at readiness / dedicated app (minimal copy change) |

**PR split:** Tasks 1–5 → draft PR1. Tasks 6–9 → draft PR2 (stack on PR1 or rebase after merge). Task 10 → prod cutover (Clint). PR3 MCP lists deferred after PR2.

---

### Task 1: Allowlist + forbidden-action helper + feature flag

**Files:**
- Create: `backend/Config/GuardedWrites/EdiscoveryAllowlist.json`
- Create: `backend/Modules/CIPPCore/Public/Ediscovery/Test-CIPPEdiscoveryForbiddenAction.ps1`
- Modify: `backend/Config/FeatureFlags.json` (append flag after `AzureArm`)
- Test: `backend/Tests/Ediscovery/EdiscoveryFlagAndForbid.Tests.ps1`

**Interfaces:**
- Produces: `Test-CIPPEdiscoveryForbiddenAction -Action <string> [-RawPath <string>]` → throws on forbidden; returns `$true` when allowed to proceed past forbid check
- Produces: flag `Id=EdiscoverySearch`, `Enabled=$true`, Endpoints listed below

- [ ] **Step 1: Write the failing test**

```powershell
# backend/Tests/Ediscovery/EdiscoveryFlagAndForbid.Tests.ps1
Describe 'EdiscoverySearch feature flag' {
    It 'ships enabled and lists config, readiness, cases, and search endpoints' {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        $Flags = Get-Content (Join-Path $RepoRoot 'Config/FeatureFlags.json') -Raw | ConvertFrom-Json
        $Flag = $Flags | Where-Object { $_.Id -eq 'EdiscoverySearch' }
        $Flag | Should -Not -BeNullOrEmpty
        $Flag.Enabled | Should -BeTrue
        foreach ($Name in @(
                'ListEdiscoveryConfig', 'ExecEdiscoveryConfig', 'ListEdiscoveryReadiness',
                'ListEdiscoveryCases', 'ExecEdiscoveryCase', 'ListEdiscoveryCaseSearches',
                'ExecEdiscoveryCaseSearch', 'ListEdiscoveryCaseHolds', 'ExecEdiscoveryCaseHold',
                'ListEdiscoveryCaseOperations', 'ExecEdiscoveryCaseExport', 'ExecEdiscoverySearch'
            )) {
            $Flag.Endpoints | Should -Contain $Name
        }
    }
}

Describe 'Test-CIPPEdiscoveryForbiddenAction' {
    BeforeAll {
        . (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) 'Modules/CIPPCore/Public/Ediscovery/Test-CIPPEdiscoveryForbiddenAction.ps1')
    }
    It 'refuses purge, case delete, hold remove, and purgeData paths' {
        { Test-CIPPEdiscoveryForbiddenAction -Action 'delete' -Resource 'case' } | Should -Throw '*refused*'
        { Test-CIPPEdiscoveryForbiddenAction -Action 'remove' -Resource 'hold' } | Should -Throw '*refused*'
        { Test-CIPPEdiscoveryForbiddenAction -Action 'purge' } | Should -Throw '*refused*'
        { Test-CIPPEdiscoveryForbiddenAction -RawPath '/security/cases/ediscoveryCases/x/searches/y/purgeData' } | Should -Throw '*refused*'
    }
    It 'allows create case and estimateStatistics' {
        Test-CIPPEdiscoveryForbiddenAction -Action 'create' -Resource 'case' | Should -BeTrue
        Test-CIPPEdiscoveryForbiddenAction -Action 'estimateStatistics' -Resource 'search' | Should -BeTrue
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -File ./backend/Scripts/RunPester.ps1 -Path backend/Tests/Ediscovery/EdiscoveryFlagAndForbid.Tests.ps1`  
(or project’s usual Pester invoker; if no wrapper: `Invoke-Pester -Path backend/Tests/Ediscovery/EdiscoveryFlagAndForbid.Tests.ps1 -CI`)  
Expected: FAIL — flag missing / function missing

- [ ] **Step 3: Write allowlist JSON**

```json
{
  "ListEdiscoveryCases": {
    "method": "GET",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases",
    "role": "Security.Ediscovery.Read",
    "classification": "read"
  },
  "GetEdiscoveryCase": {
    "method": "GET",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}",
    "role": "Security.Ediscovery.Read",
    "classification": "read"
  },
  "CreateEdiscoveryCase": {
    "method": "POST",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "UpdateEdiscoveryCase": {
    "method": "PATCH",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "CloseEdiscoveryCase": {
    "method": "POST",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/close",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "ReopenEdiscoveryCase": {
    "method": "POST",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/reopen",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "ListEdiscoverySearches": {
    "method": "GET",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/searches",
    "role": "Security.Ediscovery.Read",
    "classification": "read"
  },
  "CreateEdiscoverySearch": {
    "method": "POST",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/searches",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "UpdateEdiscoverySearch": {
    "method": "PATCH",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/searches/{searchId}",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "EstimateEdiscoverySearch": {
    "method": "POST",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/searches/{searchId}/estimateStatistics",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "GetEdiscoveryCaseOperation": {
    "method": "GET",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/operations/{operationId}",
    "role": "Security.Ediscovery.Read",
    "classification": "read"
  },
  "ListEdiscoveryCaseOperations": {
    "method": "GET",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/operations",
    "role": "Security.Ediscovery.Read",
    "classification": "read"
  },
  "CreateEdiscoveryCustodian": {
    "method": "POST",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/custodians",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "CreateEdiscoveryUserSource": {
    "method": "POST",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/custodians/{custodianId}/userSources",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write"
  },
  "ListEdiscoveryHolds": {
    "method": "GET",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/legalHolds",
    "role": "Security.Ediscovery.Read",
    "classification": "read"
  },
  "CreateEdiscoveryHold": {
    "method": "POST",
    "pathTemplate": "/v1.0/security/cases/ediscoveryCases/{caseId}/legalHolds",
    "role": "Security.Ediscovery.ReadWrite",
    "classification": "write",
    "requiresApprovalReference": true
  }
}
```

Do **not** include delete case, delete search, remove hold, `purgeData`, or export download actions.

- [ ] **Step 4: Implement forbid helper + flag**

```powershell
function Test-CIPPEdiscoveryForbiddenAction {
    [CmdletBinding()]
    param(
        [string]$Action,
        [string]$Resource,
        [string]$RawPath
    )
    $ActionL = ([string]$Action).ToLowerInvariant()
    $ResourceL = ([string]$Resource).ToLowerInvariant()
    $PathL = ([string]$RawPath).ToLowerInvariant()

    if ($PathL -match 'purgedata' -or $ActionL -eq 'purge' -or $ActionL -eq 'purgedata') {
        throw 'Purge is refused by Manage365 eDiscovery policy.'
    }
    if ($ResourceL -eq 'case' -and $ActionL -eq 'delete') {
        throw 'Case delete is refused by Manage365 eDiscovery policy.'
    }
    if ($ResourceL -eq 'hold' -and $ActionL -in @('remove', 'delete')) {
        throw 'Hold removal is refused by Manage365 eDiscovery policy.'
    }
    if ($ResourceL -eq 'search' -and $ActionL -eq 'delete') {
        throw 'Search delete is refused by Manage365 eDiscovery policy.'
    }
    if ($PathL -match '/ediscoverycases/[^/]+$' -and $ActionL -eq 'delete') {
        throw 'Case delete is refused by Manage365 eDiscovery policy.'
    }
    return $true
}
```

Append to `FeatureFlags.json` (Enabled **true**):

```json
{
  "Id": "EdiscoverySearch",
  "Name": "eDiscovery search",
  "Description": "Per-tenant Purview eDiscovery via a dedicated app (not CIPP SAM). Config, readiness, Cases UI, and stats-only search. dryRun defaults true on writes. Hold remove, case delete, and purge are refused.",
  "Enabled": true,
  "AllowUserToggle": true,
  "Timers": [],
  "Endpoints": [
    "ListEdiscoveryConfig",
    "ExecEdiscoveryConfig",
    "ListEdiscoveryReadiness",
    "ListEdiscoveryCases",
    "ExecEdiscoveryCase",
    "ListEdiscoveryCaseSearches",
    "ExecEdiscoveryCaseSearch",
    "ListEdiscoveryCaseHolds",
    "ExecEdiscoveryCaseHold",
    "ListEdiscoveryCaseOperations",
    "ExecEdiscoveryCaseExport",
    "ExecEdiscoverySearch"
  ],
  "Pages": [],
  "Hidden": false
}
```

- [ ] **Step 5: Run tests — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add backend/Config/FeatureFlags.json backend/Config/GuardedWrites/EdiscoveryAllowlist.json \
  backend/Modules/CIPPCore/Public/Ediscovery/Test-CIPPEdiscoveryForbiddenAction.ps1 \
  backend/Tests/Ediscovery/EdiscoveryFlagAndForbid.Tests.ps1
git commit -m "feat(ediscovery): add flag, allowlist, and forbidden-action guard"
```

---

### Task 2: Tenant config get/set (Key Vault refs only)

**Files:**
- Create: `backend/Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryTenantConfig.ps1`
- Create: `backend/Modules/CIPPCore/Public/Ediscovery/Set-CIPPEdiscoveryTenantConfig.ps1`
- Test: `backend/Tests/Ediscovery/EdiscoveryConfig.Tests.ps1`

**Interfaces:**
- Consumes: `Get-CIPPTable`, `Get-CIPPAzDataTableEntity`, `Add-CIPPAzDataTableEntity`
- Produces: `Get-CIPPEdiscoveryTenantConfig -TenantFilter <string> [-Table <hashtable>]` → `$null` or object `{ TenantFilter, AppId, CertificateSecretName, CertificatePasswordSecretName, Enabled, Notes }`
- Produces: `Set-CIPPEdiscoveryTenantConfig -TenantFilter -AppId -CertificateSecretName [-CertificatePasswordSecretName] [-Enabled] [-Notes] [-Table]` → refreshed config
- Rejects: AppId equal to `$env:ApplicationID`; body fields named like `pfx`, `privateKey`, `clientSecret` values

- [ ] **Step 1: Write failing tests**

```powershell
Describe 'Set-CIPPEdiscoveryTenantConfig' {
    It 'stores appId and certificate secret name only' {
        $Table = @{ mock = $true }
        Mock Get-CIPPTable { $Table }
        $Stored = $null
        Mock Add-CIPPAzDataTableEntity { param($Entity) $script:Stored = $Entity }
        Mock Get-CIPPEdiscoveryTenantConfig {
            [pscustomobject]@{
                TenantFilter = 'contoso.onmicrosoft.com'
                AppId = '11111111-1111-1111-1111-111111111111'
                CertificateSecretName = 'ediscovery-contoso-cert'
                CertificatePasswordSecretName = ''
                Enabled = $true
                Notes = ''
            }
        }
        $Result = Set-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' `
            -AppId '11111111-1111-1111-1111-111111111111' -CertificateSecretName 'ediscovery-contoso-cert'
        $Result.AppId | Should -Be '11111111-1111-1111-1111-111111111111'
        $Result.CertificateSecretName | Should -Be 'ediscovery-contoso-cert'
    }
    It 'refuses SAM application id' {
        $env:ApplicationID = '22222222-2222-2222-2222-222222222222'
        { Set-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' `
            -AppId '22222222-2222-2222-2222-222222222222' -CertificateSecretName 'x' } | Should -Throw '*SAM*'
        $env:ApplicationID = $null
    }
    It 'refuses non-GUID appId and empty cert name' {
        { Set-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' -AppId 'not-a-guid' -CertificateSecretName 'x' } | Should -Throw '*GUID*'
        { Set-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' -AppId '11111111-1111-1111-1111-111111111111' -CertificateSecretName '' } | Should -Throw '*certificate*'
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement Get/Set** (mirror `Get-CIPPAzArmTenantConfig` / `Set-CIPPAzArmTenantConfig`; table name `EdiscoveryConfig`; RowKey `config`; fields `AppId`, `CertificateSecretName`, `CertificatePasswordSecretName`, `Enabled`, `Notes`)

```powershell
function Get-CIPPEdiscoveryTenantConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$TenantFilter, [hashtable]$Table)
    if (-not $Table) { $Table = Get-CIPPTable -TableName 'EdiscoveryConfig' }
    $SafeTenant = $TenantFilter.Replace("'", "''")
    $Entity = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq '$SafeTenant' and RowKey eq 'config'" | Select-Object -First 1
    if (-not $Entity) { return $null }
    return [pscustomobject]@{
        TenantFilter                  = [string]$Entity.PartitionKey
        AppId                         = [string]$Entity.AppId
        CertificateSecretName         = [string]$Entity.CertificateSecretName
        CertificatePasswordSecretName = [string]$Entity.CertificatePasswordSecretName
        Enabled                       = [bool]$Entity.Enabled
        Notes                         = [string]$Entity.Notes
    }
}

function Set-CIPPEdiscoveryTenantConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$AppId,
        [Parameter(Mandatory)][string]$CertificateSecretName,
        [string]$CertificatePasswordSecretName,
        [bool]$Enabled = $true,
        [string]$Notes,
        [hashtable]$Table
    )
    if ($AppId -notmatch '\A[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\z') {
        throw 'AppId must be a GUID.'
    }
    $Sam = [string]$env:ApplicationID
    if (-not [string]::IsNullOrWhiteSpace($Sam) -and $AppId -eq $Sam) {
        throw 'The CIPP SAM application identity cannot be used for eDiscovery.'
    }
    if ([string]::IsNullOrWhiteSpace($CertificateSecretName)) {
        throw 'CertificateSecretName (Key Vault secret name) is required.'
    }
    if ($CertificateSecretName -match '(?i)-----BEGIN|private.?key|\.pfx') {
        throw 'CertificateSecretName must be a Key Vault secret name, not certificate material.'
    }
    if (-not $Table) { $Table = Get-CIPPTable -TableName 'EdiscoveryConfig' }
    $Entity = @{
        PartitionKey                  = $TenantFilter
        RowKey                        = 'config'
        AppId                         = $AppId
        CertificateSecretName         = $CertificateSecretName
        CertificatePasswordSecretName = [string]$CertificatePasswordSecretName
        Enabled                       = $Enabled
        Notes                         = [string]$Notes
    }
    Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
    return Get-CIPPEdiscoveryTenantConfig -TenantFilter $TenantFilter -Table $Table
}
```

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(ediscovery): per-tenant config table helpers"
```

---

### Task 3: Access token + Graph request + path plan

**Files:**
- Create: `Get-CIPPEdiscoveryAccessToken.ps1`
- Create: `Get-CIPPEdiscoveryGraphPlan.ps1`
- Create: `Invoke-CIPPEdiscoveryRequest.ps1`
- Test: `backend/Tests/Ediscovery/EdiscoveryTokenAndRequest.Tests.ps1`

**Interfaces:**
- `Get-CIPPEdiscoveryAccessToken -TenantFilter [-Config]` → `{ AccessToken, ExpiresOn, AppId, TenantId }` (never log token)
- `Get-CIPPEdiscoveryGraphPlan -Action -Params [-Allowlist]` → `{ Allowed, Method, Path, Classification, Reason }`
- `Invoke-CIPPEdiscoveryRequest -AccessToken -Method -Path [-Body] [-Classification] [-Transport] [-PollTimeoutSeconds]` → result object; host only `https://graph.microsoft.com`; strip/`throw` if response contains `downloadUrl` when classification is counts-only path

- [ ] **Step 1: Failing tests** — SAM refuse; path traversal refuse; non-graph host refuse; allowlist miss `Allowed=$false`; transport mock GET cases returns value; `purgeData` path throws via forbid check inside request builder

```powershell
Describe 'Get-CIPPEdiscoveryAccessToken' {
    It 'refuses SAM app id' {
        $env:ApplicationID = '22222222-2222-2222-2222-222222222222'
        $Cfg = [pscustomobject]@{
            Enabled = $true
            AppId = '22222222-2222-2222-2222-222222222222'
            CertificateSecretName = 'cert'
        }
        { Get-CIPPEdiscoveryAccessToken -TenantFilter 'contoso.onmicrosoft.com' -Config $Cfg } | Should -Throw '*SAM*'
        $env:ApplicationID = $null
    }
}
Describe 'Get-CIPPEdiscoveryGraphPlan' {
    It 'builds list cases path and rejects unknown action' {
        $Ok = Get-CIPPEdiscoveryGraphPlan -Action 'ListEdiscoveryCases' -Params @{}
        $Ok.Allowed | Should -BeTrue
        $Ok.Path | Should -Be '/v1.0/security/cases/ediscoveryCases'
        (Get-CIPPEdiscoveryGraphPlan -Action 'Hack' -Params @{}).Allowed | Should -BeFalse
    }
    It 'rejects path params with traversal' {
        $Bad = Get-CIPPEdiscoveryGraphPlan -Action 'GetEdiscoveryCase' -Params @{ caseId = '../evil' }
        $Bad.Allowed | Should -BeFalse
    }
}
Describe 'Invoke-CIPPEdiscoveryRequest' {
    It 'only calls graph.microsoft.com' {
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            $Uri | Should -Match '^https://graph\.microsoft\.com'
            return @{ value = @() }
        }
        $null = Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method GET `
            -Path '/v1.0/security/cases/ediscoveryCases' -Classification read -Transport $Transport
    }
}
```

- [ ] **Step 2: Implement** — copy patterns from `Get-CIPPAzArmAccessToken` (cert via `Get-CippKeyVaultSecret` + `Get-GraphTokenFromCert` with scope `https://graph.microsoft.com/.default`) and `Invoke-CIPPAzArmRequest` (injectable `-Transport`, deny `..`, schemes in path, call forbid helper on path). Resolve customer tenant id via `Get-Tenants` like AzureArm servicePrincipal mode.

GUID segment validation for `{caseId}`, `{searchId}`, `{custodianId}`, `{operationId}`: `\A[a-fA-F0-9\-]{1,64}\z` without `..` or `/`.

- [ ] **Step 3: Tests PASS + commit**

```bash
git commit -m "feat(ediscovery): dedicated token and Graph request client"
```

---

### Task 4: Readiness + config HTTP entrypoints

**Files:**
- Create: `Get-CIPPEdiscoveryReadiness.ps1`
- Create: `Invoke-ListEdiscoveryConfig.ps1`
- Create: `Invoke-ExecEdiscoveryConfig.ps1`
- Create: `Invoke-ListEdiscoveryReadiness.ps1`
- Test: `backend/Tests/Ediscovery/EdiscoveryReadinessAndConfigHttp.Tests.ps1`

**Interfaces:**
- `Get-CIPPEdiscoveryReadiness -TenantFilter [-Transport]` →  
  `{ ConfigPresent, Enabled, TokenOk, CasesListOk, Status, Remediation[string[]] }`  
  Status: `Ready` | `MissingConfig` | `Disabled` | `TokenFailed` | `Forbidden` | `Error`
- `ExecEdiscoveryConfig`: `Test-CIPPGuardedWriteRequest -IsWrite -DefaultDryRun`; require non-empty `reason`; reject body keys `pfx`, `privateKey`, `clientSecret`, `certificateBase64`

- [ ] **Step 1: Tests**

```powershell
Describe 'Invoke-ExecEdiscoveryConfig' {
    It 'defaults dryRun true and does not call Set when dryRun' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $true; Reason = 'setup'; Caller = 'test' }
        }
        Mock Set-CIPPEdiscoveryTenantConfig { throw 'should not set' }
        Mock Add-CIPPGuardedWriteAudit { 'audit-1' }
        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '1234567'
                reason = 'setup'
                appId = '11111111-1111-1111-1111-111111111111'
                certificateSecretName = 'ediscovery-contoso-cert'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }
        $Response.Body.Status | Should -Be 'DryRun'
    }
    It 'refuses PFX material in body' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $false; Reason = 'setup'; Caller = 'test' }
        }
        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'; ticketNumber = '1234567'; reason = 'setup'
                appId = '11111111-1111-1111-1111-111111111111'; certificateSecretName = 'x'
                pfx = 'AAAABBBB'
            }
            Headers = @{}; Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }
        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
    }
}
```

- [ ] **Step 2: Implement readiness** — if no config → `MissingConfig` + remediation steps (create app, consent `eDiscovery.ReadWrite.All`, store cert name, `New-ServicePrincipal`, add to `eDiscoveryManager`). If config: try token (mockable); then GET list cases via `Invoke-CIPPEdiscoveryRequest`; 403 → `Forbidden`.

- [ ] **Step 3: HTTP wrappers** under `backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/` with roles `Security.Ediscovery.Read` / `ReadWrite`.

- [ ] **Step 4: Tests PASS + commit**

```bash
git commit -m "feat(ediscovery): config and readiness endpoints"
```

---

### Task 5: Migrate existing Cases endpoints + docs (end of PR1)

**Files:**
- Modify: all `Invoke-ListEdiscovery*` / `Invoke-ExecEdiscovery*` under Security/
- Create: `docs/api-documentation/ediscovery-search.md` (runbook + identity model)
- Modify: Cases setup banner copy in frontend if present (search `eDiscovery Administrator` / CPV)
- Test: extend `EdiscoveryForbid` coverage via entrypoint mocks

**Rules for each Exec*:**
1. Call `Test-CIPPEdiscoveryForbiddenAction` first for the action.
2. For writes: `Test-CIPPGuardedWriteRequest -IsWrite -DefaultDryRun` + require `reason`.
3. Replace `New-GraphPostRequest` / `New-GraphGetRequest` with token from `Get-CIPPEdiscoveryAccessToken` + `Invoke-CIPPEdiscoveryRequest` using allowlisted actions only.
4. `ExecEdiscoveryCase` action `delete` → 400 refused.
5. `ExecEdiscoveryCaseHold` action remove/delete → 400.
6. `ExecEdiscoveryCaseSearch` action `delete` → 400; `estimateStatistics` allowed (PR1 keeps thin estimate; PR2 adds counts-only orchestrator).
7. `ExecEdiscoveryCaseExport` → refuse content download / return guidance that export is not available in Manage365 v1 (or require `approvalReference` and still do not return downloadUrl — prefer hard refuse download until PR later).

- [ ] **Step 1: Tests proving delete/purge/hold-remove return 400 with zero transport calls**

```powershell
It 'ExecEdiscoveryCase delete does not call transport' {
    $script:Calls = 0
    Mock Get-CIPPEdiscoveryAccessToken { [pscustomobject]@{ AccessToken = 'tok' } }
    Mock Invoke-CIPPEdiscoveryRequest { $script:Calls++; throw 'should not run' }
    $Response = Invoke-ExecEdiscoveryCase -Request @{
        Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; action = 'delete'; caseId = '11111111-1111-1111-1111-111111111111'; ticketNumber = '1234567'; reason = 'nope'; dryRun = $false }
        Headers = @{}; Params = @{ CIPPEndpoint = 'ExecEdiscoveryCase' }
    }
    $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
    $script:Calls | Should -Be 0
}
```

- [ ] **Step 2: Implement migrations**

- [ ] **Step 3: Write `docs/api-documentation/ediscovery-search.md`** — identity blast radius, setup runbook, flag, dryRun, counts-only, forbidden actions, link to guarded-writes.md

- [ ] **Step 4: Aikido scan all new/changed `.ps1` + json; Pester green**

- [ ] **Step 5: Push branch `clint/ediscovery-config-readiness` and open draft PR1** into main (summary, risk, test plan, rollback, note App Security reviews identity). Reference design PR #95.

---

### Task 6: KQL builder + search plan (PR2 start)

**Files:**
- Create: `New-CIPPEdiscoveryKql.ps1`
- Create: `Get-CIPPEdiscoverySearchPlan.ps1`
- Test: `backend/Tests/Ediscovery/EdiscoveryKql.Tests.ps1`

**Interfaces:**
- `New-CIPPEdiscoveryKql -Terms <string[]> [-DateFrom <datetime>] [-DateTo <datetime>]` → `{ Kql, TermCount, KqlHash }`
- Validation: max 25 terms; each term length 1–128; allow letters/numbers/spaces/`"`/`*`/`()` and simple `AND`/`OR`/`NOT` tokens **or** treat each array element as a quoted phrase and join with `OR` (prefer: each term becomes `"escaped"` and join with ` AND ` for phrase search — document choice: **OR across terms** for hit-union stats, matching attorney keyword lists). Reject `;`, `|`, raw `contentQuery` passthrough.
- Dates: append `AND sent>=yyyy-MM-dd AND sent<=yyyy-MM-dd` (spike may switch property).
- Max span 1825 days (5 years).
- `Get-CIPPEdiscoverySearchPlan` builds dry-run object: displayName `"$ticket - $caseLabel"`, externalId ticket, custodian, kql, limits.

```powershell
function New-CIPPEdiscoveryKql {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Terms,
        [datetime]$DateFrom,
        [datetime]$DateTo
    )
    $Clean = @($Terms | ForEach-Object { [string]$_.Trim() } | Where-Object { $_ })
    if ($Clean.Count -lt 1 -or $Clean.Count -gt 25) { throw 'terms must contain 1 to 25 items.' }
    $Parts = foreach ($T in $Clean) {
        if ($T.Length -gt 128) { throw 'Each term must be 128 characters or fewer.' }
        if ($T -match '[;\n\r]|contentQuery') { throw 'Invalid term.' }
        $Esc = $T.Replace('\', '\\').Replace('"', '\"')
        '"{0}"' -f $Esc
    }
    $Kql = '(' + ($Parts -join ' OR ') + ')'
    if ($DateFrom -and $DateTo) {
        if (($DateTo.Date - $DateFrom.Date).TotalDays -gt 1825) { throw 'Date range exceeds 5 years.' }
        if ($DateTo -lt $DateFrom) { throw 'dateTo must be on or after dateFrom.' }
        $Kql = "$Kql AND sent>=$($DateFrom.ToString('yyyy-MM-dd')) AND sent<=$($DateTo.ToString('yyyy-MM-dd'))"
    } elseif ($DateFrom -or $DateTo) {
        throw 'dateFrom and dateTo must be supplied together.'
    }
    $Hash = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($Kql))).Replace('-', '').ToLowerInvariant()
    [pscustomobject]@{ Kql = $Kql; TermCount = $Clean.Count; KqlHash = $Hash; Terms = $Clean }
}
```

- [ ] **Steps:** failing tests → implement → PASS → commit `feat(ediscovery): KQL builder and search plan`

---

### Task 7: Counts-only converter + search action orchestrator

**Files:**
- Create: `ConvertTo-CIPPEdiscoveryCountsOnly.ps1`
- Create: `Invoke-CIPPEdiscoverySearchAction.ps1`
- Test: `backend/Tests/Ediscovery/EdiscoverySearchAction.Tests.ps1`

**Interfaces:**
- `ConvertTo-CIPPEdiscoveryCountsOnly -Value` removes/redacts keys matching `(?i)subject|sender|preview|snippet|downloadUrl|fileName|content|recipient|body`
- `Invoke-CIPPEdiscoverySearchAction -Request` orchestrates dryRun vs live:
  - Gate + reason
  - In-flight lock: script/table key per tenant; refuse second concurrent estimate
  - Live: create/reuse case by externalId; custodian + userSource mailbox; create search; estimateStatistics; poll GetEdiscoveryCaseOperation until succeeded/failed/timeout (e.g. 300s)
  - Per-term: default **one estimate per term** (safer until spike proves keyword report is counts-only); include note that per-term counts may overlap
  - Return `{ Status, AuditId, Before, After, Rollback, Results: { indexedItemCount, indexedItemsSize, mailboxCount, unindexedItemCount, perTerm: @{ term, itemCount, size } } }` with terms present only in After for the operator response — **audit/logs store TermCount + KqlHash only** (pass redacted request to `Add-CIPPGuardedWriteAudit`)

- [ ] **Test:** dryRun → Status DryRun, transport call count 0  
- [ ] **Test:** fixture response with `subject`/`downloadUrl` → converter strips them  
- [ ] **Test:** missing reason → 400  
- [ ] **Test:** >25 terms → 400  

- [ ] **Commit:** `feat(ediscovery): stats search orchestrator and counts-only redaction`

---

### Task 8: `ExecEdiscoverySearch` entrypoint + OpenAPI/Pester

**Files:**
- Create: `Invoke-ExecEdiscoverySearch.ps1` (role `Security.Ediscovery.ReadWrite`)
- Wire: calls `Invoke-CIPPEdiscoverySearchAction`
- Ensure function discovery picks it up (same folder as other Security entrypoints)
- Test: endpoint envelope tests
- Run full related Pester + OpenAPI spec tests if repo regenerates from attributes

```powershell
function Invoke-ExecEdiscoverySearch {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    .DESCRIPTION
        Stats-only Purview eDiscovery search (case/custodian/search/estimate). dryRun defaults true. Counts only.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPEdiscoverySearchAction -Request $Request
}
```

- [ ] **Commit:** `feat(ediscovery): ExecEdiscoverySearch endpoint`

---

### Task 9: PR2 docs, Aikido, draft PR, frontend banner

**Files:**
- Update: `docs/api-documentation/ediscovery-search.md` with `ExecEdiscoverySearch` request/response examples (synthetic)
- Update: Cases UI banner → dedicated app + `ListEdiscoveryReadiness`
- Aikido on all touched first-party files
- Draft PR2 `clint/ediscovery-stats-search` → main (note stacks on PR1; conflict risk on FeatureFlags / Security entrypoints)

- [ ] **Commit + push + `gh pr create --draft`**

---

### Task 10: Production ship (after PR1+PR2 merged)

Not code — operator checklist:

1. Confirm internal build ticket number exists; use it for config upserts.
2. Merge draft PRs after App QA / App Security / CodeRabbit.
3. Bump Manage365 release / build image (`v6.1.x`) with `APP_VERSION` per repo release practice.
4. App Service cutover to new digest; health ready.
5. Flag already Enabled true in image — verify in CIPP Features UI.
6. For first tenant: human Purview setup → `ExecEdiscoveryConfig` dryRun then live → `ListEdiscoveryReadiness` Ready → `ExecEdiscoverySearch` dryRun → live only after attorney auth on ticket.
7. Rollback: previous image tag; or disable `EdiscoverySearch`; or delete tenant config row.

**PR3 (later plan):** MCP-safe List* only — do not implement in this plan unless Clint asks.

---

## Self-review (plan vs spec)

| Spec item | Task |
|-----------|------|
| Dedicated app + cert, refuse SAM | 2, 3 |
| Flag on, gates endpoints | 1, 5 |
| Config + readiness | 4 |
| Allowlist; no purge/delete/hold-remove | 1, 5, 7 |
| Stats ExecEdiscoverySearch, dryRun default, counts-only | 6–8 |
| Migrate existing Cases UI/API | 5 |
| Audit term count + KQL hash | 7 |
| Docs/runbook | 5, 9 |
| Prod enable | 10 |
| Spike items (archive, keyword report, premium) | Defaults in Global Constraints; record spike note before changing defaults |
| Hold-add / export approval | Deferred (allowlist marks CreateHold requiresApprovalReference; export refuse in Task 5) |
| MCP PR3 | Explicitly deferred |

No TBD placeholders remain in task steps. Types/names consistent: `Get/Set-CIPPEdiscoveryTenantConfig`, `Get-CIPPEdiscoveryAccessToken`, `Invoke-CIPPEdiscoveryRequest`, `ExecEdiscoverySearch`.
