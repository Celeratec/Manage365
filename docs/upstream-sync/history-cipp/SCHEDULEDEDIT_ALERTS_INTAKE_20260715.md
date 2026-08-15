# Scheduled User Edit + Dashboard Alerts Card Intake — 2026-07-15

**Type:** Feature intake (batch)
**Upstream baseline:** 10.6.1 (commits from upstream main, late June – early July 2026)
**Fork version:** 5.23.0 → 5.24.0
**Backup tags:** `backup/pre-schedulededit-alerts-intake-20260715` (CIPP), `backup/pre-schedulededit-intake-20260715` (CIPP-API)
**Branches:** `manage365/schedulededit-alerts-intake-20260715` (CIPP), `manage365/schedulededit-intake-20260715` (CIPP-API)

## Upstream commits covered

| Commit | Repo | Subject | Disposition |
| --- | --- | --- | --- |
| `506d75ab2` | CIPP | edit user schedule (show scheduling on edit form) | Taken (adapted to fork's FormSection layout) |
| `7b3514493` | CIPP | improve user data handling / clearable fields | Already integrated in an earlier intake — no action |
| `3db7206d0` / PR #6260 | CIPP | Alerts card on dashboard | Taken |
| `0fc6459db` (remainder) | CIPP | Bulk-result rollup in CippApiResults (#6265) | Taken (missed in the previous intake — see note) |
| upstream `Invoke-EditUser` refactor + `Set-CIPPUser` | CIPP-API | Schedulable user edits | Taken (Set-CIPPUser built from the fork's richer edit logic) |

> Note: in the MEM devices intake, the `CippApiResults.jsx` part of `0fc6459db` was
> dismissed as formatting-only based on a prettier diff that silently produced empty
> output (broken `.prettierrc` reference — the repo uses `.prettierrc.json`). Re-diffing
> with the correct config surfaced a real feature: per-action grouping of bulk results
> plus a summary alert ("X of Y actions failed"). That is now included here.

## Changes — CIPP (frontend)

### Dashboard Alerts card

- `src/components/CippComponents/AlertsOverviewCard.jsx` — **new**, adopted upstream
  wholesale. Shows fired alert instances for the selected tenant: active alerts on
  top (snoozable per item), snoozed alerts greyed at the bottom with time remaining
  and who snoozed them.
- `src/utils/format-alert-item.js` — **new**, adopted upstream wholesale. Humanizes
  alert cmdlet names and extracts display fields from alert items.
- `src/components/CippComponents/CippAlertSnoozeDialog.jsx` — adopted upstream
  wholesale (fork copy was an older upstream revision with no fork-only commits).
  Now renders a structured field preview via `format-alert-item` instead of a
  single-line string.
- `src/pages/dashboardv2/index.js` — full-width Alerts section inserted between the
  Tenant Overview and Identity sections, matching upstream placement. All fork
  dashboard customizations (dynamic imports, portals menu, report toolbar) untouched.
- Backend endpoints required by the card (`ListAlertResults`, `ListSnoozedAlerts`,
  `ExecRemoveSnooze`, `ExecSnoozeAlert`) already exist in the fork's API.

### Scheduled user edit

- `src/components/CippFormPages/CippAddEditUser.jsx` — the Scheduling section now
  renders for both add and edit, with mode-appropriate labels ("Schedule this user
  edit for later"). Fork's FormSection layout preserved (upstream's flat layout not
  adopted).
- `src/pages/identity/administration/users/user/edit.jsx` — no change needed; the
  fork already had the dirtyFields/clearProperties handling from upstream
  `7b3514493`, plus its own license-name mapping.

### Bulk result rollup

- `src/components/CippComponents/CippApiResults.jsx` — results are tagged with the
  index of the bulk action they came from (`groupIndex`); when more than one action
  ran, a summary alert is shown ("All N actions completed successfully" / "X of N
  actions failed, Y succeeded"). Fork's detail toggles, CSV download, and table
  dialog untouched.

## Changes — CIPP-API

### `Modules/CIPPCore/Public/Set-CIPPUser.ps1` (new)

Upstream extracted the user-edit logic out of `Invoke-EditUser` into a shared
`Set-CIPPUser` so scheduled tasks can run the same code. The fork's version is
built from the **fork's** `Invoke-EditUser` body, preserving:

- Granular `$BodyToship` construction (only non-null fields PATCHed; hashtable style)
- `clearProperties` explicit-clear support (null scalars / empty collections)
- UPN/mail/proxyAddress conflict lookup with actionable error details
- License short-circuit when assignments already match, `businessPhones` filtering,
  `otherMails` normalization, `UserDisplay` fallback logging

Upstream's Sherweb license block was not carried over (Sherweb intake still deferred).

### `Invoke-EditUser.ps1` (rewritten as thin wrapper)

- Keeps the fork's no-user-ID 400 guard.
- `Scheduled.Enabled` requests now create a scheduled task via
  `Add-CIPPScheduledTask` (Command = `Set-CIPPUser`, `DisallowDuplicateName`),
  honoring `Scheduled.date`, `reference`, and webhook/email/PSA post-execution.
- Immediate edits delegate to `Set-CIPPUser`.

### Tests

- `Tests/Endpoint/Invoke-EditUser.Tests.ps1` updated to dot-source `Set-CIPPUser.ps1`.
  All 5 clear-vs-omit tests pass.

## Verification

- Pester: 5/5 passed (`Invoke-EditUser.Tests.ps1`).
- PowerShell parse check: both changed .ps1 files clean.
- ESLint: no new errors (one pre-existing `set-state-in-effect` error in
  CippApiResults exists on the clean tree too).
- `yarn build`: passed (66s, node 22.13.0 — note node 24 fails the engine check).

## iCloud sync note

Two more " 2" duplicate files appeared during this intake (checkpoint doc and
CippIntuneDeviceActions from the previous intake). Both were byte-identical and
deleted. Repos remain inside `~/Documents` (iCloud-synced); moving them is still
recommended.

## Still deferred

- **Frontend:** config.js menu changes, top-nav tweaks, PrivateRoute/login tweaks,
  Shadow AI report button removal, tenant metrics grid style, build optimisations,
  container management, dependency bumps.
- **API:** Custom Test Alerting overhaul, MCP support, Purview DLP standard, Intune
  policy sync / device app collection, IP lookup + audit log improvements, Sherweb,
  and the remaining small items listed in prior checkpoint docs.
