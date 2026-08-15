# CIPP Frontend Sync Checkpoint — 2026-06-17

## Branch

| Field | Value |
|-------|-------|
| Branch | `manage365/upstream-sync-cipp-20260617` |
| Base | `main` @ `f2d87612ec80b9be24c303137c9604590992b144` |
| Tip | Latest — `docs: update CIPP frontend sync checkpoint` (run `git rev-parse HEAD` on branch) |
| Backup tag | `backup/pre-upstream-sync-cipp-20260617` (local, not pushed) |
| Working tree | Clean |
| Remote push | Nothing pushed |

## Mini-batches Completed

### Mini-batch 1

| Upstream | Title | Outcome |
|----------|-------|---------|
| `1e59d2d4` | Update ListTests.json | Applied → `623ac8590` |
| `98d5d94a` | Custom Test — Alert on X statuses | Applied → `f3c917c1a` |
| `c8d61c07` | JIT admin — remove creatable | Already implemented; noisy cherry-pick reverted → `af5c9a905` |

### Mini-batch 2

| Upstream | Title | Outcome |
|----------|-------|---------|
| `cfbf3508` | Remove duplicate appliesToTest | Already implemented — skipped |
| `db57e52a` | TemplateList optional/non-creatable | Already implemented — skipped |
| `b1902421` | Tab layout first-tab margin | Skipped/deferred — layout conflict |
| `7a85827e` | Bulk patch wizard contact/UPN | Applied → `bb5150d99` |

### Mini-batch 3

| Upstream | Title | Outcome |
|----------|-------|---------|
| `1cd1ef72` | TAP audit log template filter | Adapted → `dc44bd9d1` + `1688fbca0` |
| `4b9efd82` | Licenses report apiDataKey | Applied → `dce16f09c` |
| `3734adee` | User defaults license label | Applied → `7a6c71950` |

### Mini-batch 4

| Upstream | Title | Outcome |
|----------|-------|---------|
| `7054bfc4` | UserReportedPhishing alert | Applied → `de565d5f9`, then deferred → `b0fcc3129` |
| `1e7aef11` | Quota alert intervals | Adapted → `ad8f64688` |
| `0c32a84e` | Extensions portal links | Applied → `52cf36559` |

### Post mini-batch 4

| Upstream | Title | Outcome |
|----------|-------|---------|
| `2e9b9fd5` | Drawer button guard | Adapted → `ac59795fb` |

### Mini-batch 5 — Standards alignment pair

| Upstream | Title | Outcome |
|----------|-------|---------|
| `d7e8b0b5` | Toggle button size | Already implemented in `377ce394b` — verified parity |
| `1cb6a11c` | Standard name retrieval | Already implemented in `377ce394b` — verified parity |

## Applied Commits (sync branch code)

| Upstream | Applied SHA | Files |
|----------|-------------|-------|
| `1e59d2d4` | `623ac8590` | `Tests/Shapes/ListTests.json` |
| `98d5d94a` | `f3c917c1a` | `src/pages/tools/custom-tests/add.jsx` |
| `7a85827e` | `bb5150d99` | `src/pages/identity/administration/users/patch-wizard.jsx` |
| `1cd1ef72` | `dc44bd9d1`, `1688fbca0` | `src/data/AuditLogTemplates.json` |
| `4b9efd82` | `dce16f09c` | `src/pages/tenant/reports/list-licenses/index.js` |
| `3734adee` | `7a6c71950` | `src/pages/tenant/manage/user-defaults.js` |
| `1e7aef11` | `ad8f64688` | `src/data/alerts.json` |
| `0c32a84e` | `52cf36559` | `src/data/Extensions.json` |
| `2e9b9fd5` | `ac59795fb` | `CippTenantAllowBlockListTemplateDrawer.jsx` |

## Adapted Commits

| Upstream | Applied SHA | Adaptation |
|----------|-------------|------------|
| `1cd1ef72` | `dc44bd9d1` + `1688fbca0` | Manual TAP filter: `*PassId*` + remove duplicate `ne []` |
| `1e7aef11` | `ad8f64688` | Quota intervals only; fork `QuotaUsed` schema differs |
| `2e9b9fd5` | `ac59795fb` | Partial guard without full controlled/edit drawer stack |

## Already Implemented (pre-sync or prior fork port)

| Upstream / Fork | Title | Evidence |
|-----------------|-------|----------|
| `c8d61c07` | JIT creatable guard | Five `creatable={false}` on JIT admin autocompletes |
| `cfbf3508` | Duplicate appliesToTest | Single merged `appliesToTest` in standards.json |
| `db57e52a` | TemplateList optional/non-creatable | CA TemplateList already configured |
| `377ce394b` | By-standard alignment view + fixes | Includes `d7e8b0b5` toggle sx and `1cb6a11c` name retrieval |

## Reverted / Deferred

| Upstream | Applied then reverted | Reason |
|----------|----------------------|--------|
| `c8d61c07` | `aebf6ada5` → `af5c9a905` | Formatting-only cherry-pick; already implemented |
| `7054bfc4` | `de565d5f9` → `b0fcc3129` | No matching CIPP-API handler or ThreatSubmission SAM chain |

## Skipped (conflict — not applied)

| Upstream | Title | Reason |
|----------|-------|--------|
| `b1902421` | Tab layout first-tab margin | Layout conflict in tab components |

## Known Concerns

1. **UserReportedPhishing deferred** — Revisit only as paired frontend (`7054bfc4`) + CIPP-API (`Get-CIPPAlertUserReportedPhishing.ps1`, `ThreatSubmission.ReadWrite.All` SAM/CPV).
2. **`b1902421` tab margin** — Still deferred; needs adapted manual apply in fork responsive layout.
3. **`7a85827e` patch wizard** — Smoke test UPN suffix rebuild and bulk contact updates in a test tenant.
4. **Drawer guard partial** — `2e9b9fd5` adapted without full upstream controlled/edit drawer stack (`bc412396b` / `20e2f554d`).
5. **Build/lint** — Full frontend build/lint not validated; known pre-existing dependency/tooling blockers may remain.

## Recommendation

**Ready for frontend PR review** after a final code-review-only pass on the branch diff vs `main`.

Do **not** continue upstream cherry-picks without explicit approval per candidate. Remaining isolated picks (`b1902421`, `7054bfc4`+API, allow/block edit mode, `4c0c058f`) should be triaged individually.

## Tracking Docs

- `docs/upstream-sync/APPLIED_COMMITS_CIPP_20260617.md`
- `docs/upstream-sync/UPSTREAM_SYNC_CIPP_20260617.md`
