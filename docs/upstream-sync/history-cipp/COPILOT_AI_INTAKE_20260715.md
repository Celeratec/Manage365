# Copilot & AI Feature Intake — 2026-07-15

Dedicated feature intake cycle: ports the upstream **Copilot & AI** feature family
(deferred in the 2026-07-13 major sync) into Manage365, plus the upstream
**CIPP-API 10.6.2 hotfix**.

- Frontend branch: `manage365/copilot-intake-20260715` (backup tag `backup/pre-copilot-intake-20260715`)
- API branch: `manage365/copilot-intake-20260715` (backup tag `backup/pre-copilot-intake-20260715`)
- Fork version: **5.18.0** (upstream baseline 10.6.1 frontend / 10.6.2 API)

## CIPP-API — Copilot & AI

Ported from upstream tip (files were near-fully additive, so taken wholesale
rather than by cherry-pick chain):

| Area | Files |
| --- | --- |
| Shadow AI catalog | `Config/ShadowAI.json` (curated, PR-editable AI tool catalog) |
| HTTP endpoints | `Invoke-ListShadowAI`, `Invoke-ExecShadowAISanction`, `Invoke-ListCopilotSettings`, `Invoke-ExecCopilotSettings`, `Invoke-ListCopilotUsage`, `Invoke-ListAgent365Packages`, `Invoke-ListAgent365PackageDetail` (all under `Tenant/Standards`) |
| Standards | `Invoke-CIPPStandardCopilotSettings`, `Invoke-CIPPStandardCopilotLimitedMode` + their `Config/standards.json` entries (cat: "Copilot (M365) Standards") |
| DB cache setters | Refreshed the four `Set-CIPPDBCacheCopilot*` functions to upstream tip (consolidated `-AddCount` call pattern) |

Already present from the 2026-07-13 sync (no action needed): CopilotReadiness
test suite (17 tests), the four Copilot DB cache types in
`Config/CIPPDBCacheTypes.json`, and the `CopilotUsage` group in
`Invoke-CIPPDBCacheCollection.ps1`.

### SAM Manifest permissions added (both `Config/SAMManifest.json` and `Modules/CIPPCore/lib/data/SAMManifest.json`)

| Permission | GUID | Type |
| --- | --- | --- |
| CopilotPackages.ReadWrite.All | `ed31732f-9495-47ed-ba3b-4ed0948c1c64` | Role |
| CopilotPackages.Read.All | `72f0655d-6228-4ddc-8e1b-164973b9213b` | Role |
| CopilotPolicySettings.Read | `556d5e2e-1081-4452-8147-26c3a1b06f58` | Role |

**Action required:** add these three application permissions to the SAM app
registration in the MSP tenant and run a CPV refresh so they reach client
tenants. Graph endpoints used are `/beta/copilot/admin/*` and
`/beta/copilot/reports/*`.

### Dependencies verified in fork

`New-CIPPDbRequest`, `Get-CIPPDbItem -CountsOnly`, `Add-CIPPDbItem -AddCount`,
and the `DetectedApps` / `ServicePrincipals` / `OAuth2PermissionGrants` caches
all exist. Shadow AI sign-in enrichment degrades gracefully without Entra P1.

## CIPP-API — 10.6.2 hotfix intake

Cherry-picked from upstream `Dev to hf (#2140)`:

- `610ec61e7` fix(graph): reconcile AppCache app id drift — merged into the
  fork's `Get-GraphToken.ps1` **preserving the fork's shared token cache /
  lock wrapper**; only the AppCache-vs-KeyVault reconcile block was adopted.
- `176d43baa` force external uri to be partner center (partner webhooks)
- `2da187218` move snooze endpoints to new `CIPP.AlertSnooze.*` permission
- Version bumped to **10.6.2** (`version_latest.txt` + `Config/version_latest.txt`)

Skipped:

- `ad9caf3ff` OneDrive root permissions cache — upstream marks it
  "boilerplate, not implemented yet"; revisit when upstream wires it up.
- `8c4cf8d94` MCP resolver fix — fork has no MCP module yet (MCP intake still
  deferred).

## CIPP frontend — Copilot & AI

- Ported all six pages under `src/pages/copilot/` (Shadow AI Discovery,
  Copilot Settings, Agent365 Packages, Adoption / Trend / User Activity
  reports) and `src/components/ShadowAIReportButton.js` from upstream tip.
- Added the **Copilot & AI** menu section to `src/layouts/config.js` between
  Security & Compliance and Email & Exchange (upstream placement), restyled to
  the fork's double-quote convention; added `SparklesIcon` import.
- All page dependencies (CippTablePage, CippChartCard, CippInfoBar,
  CippApiDialog, CippOffCanvas, CippJSONView, use-dialog) already exist in the
  fork.

## Verification

- `yarn build` (Node 22): success, all six `/copilot/*` routes emitted;
  `package.json` / `yarn.lock` intact after build (per the 20260713 build
  script fix).
- PowerShell parse check on all 13 added/changed API files plus
  `Get-GraphToken.ps1`: clean.
- `Config/standards.json` and both SAM manifests validated as JSON.
