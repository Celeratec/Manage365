# Custom Feature Map — Manage365 — 2026-11-21

Purpose: Protected areas that must not be overwritten during upstream sync. Refreshed for the 11.2.1 → 11.4.0 cycle from [`history-cipp/CUSTOM_FEATURE_MAP_20260617.md`](history-cipp/CUSTOM_FEATURE_MAP_20260617.md) with monorepo paths and post-v2 customizations.

## Git state at generation

| | Value |
|--|--|
| Branch | `clint/upstream-intake-20261121` |
| Tip | `b88ca6637` (Manage365 6.1.36) |
| Upstream baseline | **11.2.1** |
| Upstream tip | **v11.4.0** `12880df92` |

Paths below are monorepo-relative (`frontend/`, `backend/`).

## Protected custom areas

### Branding and versioning

- `frontend/public/manage365-version.json` — primary display version
- `frontend/public/version.json`, `backend/version_latest.txt` — CIPP baseline markers
- `Tools/Update-Version.ps1`, README Upstream Integration
- **Rule:** Never let an upstream version bump replace Manage365 version display

### Quarantine portal

- `frontend/src/components/CippComponents/quarantine/`
- `frontend/src/pages/email/administration/quarantine/`
- `backend/Modules/CIPPCore/Public/Tools/Build-CIPPQuarantineQueryParams.ps1` and related EXO helpers
- Quarantine HTTP entrypoints under `Email-Exchange/Spamfilter/`
- **Rule:** Adapt only; EXO portal filters/export/bulk stay

### Email troubleshooter

- Troubleshooter pages + `Invoke-ExecEmailTroubleshoot.ps1`
- Coupled to quarantine helpers

### Guarded tenant writes (Manage365)

- `backend/Config/GuardedWrites/`
- `Get-CIPPExoAllowlistedCmdletPlan.ps1`, `Get-CIPPGraphWritePlan.ps1`, `Resolve-CIPPGuardedWriteConfigPath`
- `ExecExoAllowlistedCmdlet`, `ExecGraphWrite`, mail-filter writes, soft-delete mailbox folder endpoints
- Feature flag **Guarded tenant writes** (default off)
- **Rule:** Never replace allowlists or audit/ticket/dryRun gates with upstream unrestricted writes

### Mailbox folder soft-delete

- Soft-delete / restore Graph folder endpoints (Deleted Items only)
- **Rule:** Permanent delete stays prohibited

### SharePoint recycle bin suite

- `Invoke-ListSiteRecycleBin*`, `Invoke-ExecEmptySiteRecycleBin*`, POST GetRecycleBinItems, paging
- **Rule:** Do not blind-replace with upstream recycle-bin commits; Adapt behavior hunks only

### Card views and DataTable

- `frontend/src/components/CippTable/` card mode, action categories, drawers
- Report/list pages with Manage365 card layouts
- **Rule:** Port upstream table fixes surgically; keep card view

### MCP role gating

- `Invoke-ExecMcp` and role/MCPAllowed catalog filtering
- MCPServer feature flag (DefaultOn once)
- **Rule:** Preserve fail-closed role gating; Entra app name may stay CIPP-MCP

### Navigation and search

- `frontend/src/layouts/config.js`, top-nav hybrid search, dashboard routing
- **Rule:** Union menus; Baselines stay flag-gated off

### Baselines flag

- Baselines UI/engine may exist; feature flag **off** while classic Standards run
- **Rule:** Standards-only fixes via Adapt; skip baselines product expansion this cycle

### Hudu / Halo / integrations posture

- Custom Hudu sync and Magic Dash behavior
- **Rule:** Skip upstream Hudu redesign and NinjaOne ticketing as primary PSA unless explicitly requested

### Auth / SSO / SAM

- EasyAuth, CIPP Users / SSO, SAM certificate-only setup
- **Rule:** Adapt auth hardening; do not drop certificate-only or fork SSO flows

## Conflict resolution rules

1. Never auto-resolve toward upstream for files in this map
2. Preserve Manage365 branding, quarantine, GuardedWrites, soft-delete, recycle-bin, MCP gating, card views
3. Integrate upstream bug fixes only when they do not regress custom behavior
4. Pause for approval on High-risk auth or GuardedWrite allowlist changes
5. Document every adaptation in `APPLIED_COMMITS_20261121.md`
