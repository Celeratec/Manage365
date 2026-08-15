# Applied Commits Tracking — CIPP (Frontend)

Generated: 2026-06-17  
Branch: `manage365/upstream-sync-cipp-20260617`  
Backup tag: `backup/pre-upstream-sync-cipp-20260617`  
Branch tip: latest on `manage365/upstream-sync-cipp-20260617` (checkpoint pass complete)

## Summary

| Status | Count |
|--------|-------|
| Applied cleanly | 7 |
| Applied with adaptation | 3 |
| Deferred / reverted from branch | 1 |
| Reverted (formatting-only / no net change) | 1 |
| Already implemented | 5 |
| Skipped (conflict) | 1 |
| Conflicts | 4 (`b1902421`, `1e7aef11`, `2e9b9fd5`, `d7e8b0b5` cherry-pick) |

Mini-batch 1: `1e59d2d4`, `98d5d94a` applied; `c8d61c07` reverted after review.  
Mini-batch 2: `7a85827e` applied; `cfbf3508`, `db57e52a` already present; `b1902421` conflict.  
Mini-batch 3: `1cd1ef72` adapted manually (two commits); `4b9efd82`, `3734adee` cherry-picked on retry.  
Mini-batch 4: `0c32a84e` cherry-picked cleanly; `1e7aef11` adapted after conflict; `7054bfc4` deferred (see below).  
Post batch 4: `2e9b9fd5` drawer guard adapted after cherry-pick conflict.  
Mini-batch 5: `d7e8b0b5` + `1cb6a11c` already implemented in fork `377ce394b`; verified parity, no code delta.

## Commit Log

| Upstream SHA | Applied SHA | Status | Reason | Files | Tests | Notes |
|--------------|-------------|--------|--------|-------|-------|-------|
| `1e59d2d43fab463a709d1dac2477f45cfacdfae6` | `623ac8590` | Applied cleanly | Shape test baseline update only | `Tests/Shapes/ListTests.json` | JSON parse OK | Adds `ExoTransportConfig` to ListTests shape. |
| `98d5d94a0d122d5fbc7380d5abe5cb02fba366fd` | `f3c917c1a` | Applied cleanly | Custom test alert-on-status UI; pairs with API `6aa66c74` | `src/pages/tools/custom-tests/add.jsx` | Static review | `AlertStatuses` multi-select gated on `AlertOnFailure`. |
| `c8d61c0757853359cde98f9a00e6e3ba6fe6e98e` | `aebf6ada5` → reverted `af5c9a905` | Already implemented before sync; reverted noisy formatting-only cherry-pick | JIT admin autocomplete creatable guard | `src/pages/identity/administration/jit-admin/add.jsx` | Static review post-revert | Fork already had `creatable={false}` on all five autocomplete fields. |
| `cfbf3508e1ede8b51ef6daff780356ea0379f083` | — | Already implemented | Duplicate `appliesToTest` merge | `src/data/standards.json` | JSON compare | Skipped cherry-pick. |
| `db57e52a207f3e9d77974832978d88963859bf83` | — | Already implemented | TemplateList optional + non-creatable | `src/data/standards.json` | JSON compare | Skipped cherry-pick. |
| `b19024214e96bd207640c5e63dcefb38d408e161` | — | Skipped (conflict) | Tab layout first-tab margin | `HeaderedTabbedLayout.jsx`, `TabbedLayout.jsx` | Not applied | Layout conflict; needs adapted apply. |
| `7a85827ef1072955a48cb1d48c3ce2aafe3ab88d` | `bb5150d99` | Applied cleanly | Bulk patch wizard contact/UPN fields | `src/pages/identity/administration/users/patch-wizard.jsx` | Static review | Cherry-pick `-x` succeeded. |
| `1cd1ef7223672170bdce1fffe88d8bb4ddb903d9` | `dc44bd9d1` + `1688fbca0` | Applied with adaptation (fully adapted) | TAP audit log template filter | `src/data/AuditLogTemplates.json` | JSON parse OK | Cherry-pick conflicted; manual adaptation: (1) `like` `"*"` → `"*PassId*"`; (2) duplicate `ne []` SecuredAccessPassData filter removed. |
| `4b9efd827d27a3498eca51b444934a99e78c634f` | `dce16f09c` | Applied cleanly | Licenses report `apiDataKey="Results"` | `src/pages/tenant/reports/list-licenses/index.js` | Static review | Cherry-pick `-x` succeeded on mini-batch 3 retry. |
| `3734adeeaec92e6d83974590c36a9e91bf024a98` | `7a6c71950` | Applied cleanly | User defaults license label casing | `src/pages/tenant/manage/user-defaults.js` | Static review | Cherry-pick `-x` succeeded; `AvailableUnits` → `availableUnits`. |
| `7054bfc42d67a7f3d86b23b036057ba98559d488` | `de565d5f9` → reverted `b0fcc3129` | **Deferred / reverted from frontend branch** | UserReportedPhishing alert definition | `src/data/alerts.json` | JSON parse OK | Cherry-picked in mini-batch 4, then removed: matching CIPP-API handler `Get-CIPPAlertUserReportedPhishing.ps1` and `ThreatSubmission.ReadWrite.All` SAM/CPV chain not imported yet. **Revisit only as paired frontend + CIPP-API feature import.** |
| `1e7aef11995feb42e9872ec4aefac39fc7ba67c5` | `ad8f64688` | Applied with adaptation | Quota alert run intervals `4h` → `1d` | `src/data/alerts.json` | JSON parse OK | Cherry-pick conflicted on fork `QuotaUsed` `multipleInput` schema; manually set SharePointQuota and OneDriveQuota to `1d`. QuotaUsed already `1d`. |
| `0c32a84eb21d3df3a719427b54d10821a94b40a4` | `52cf36559` | Applied cleanly | Hudu extension portal link toggles | `src/data/Extensions.json` | JSON parse OK | Data-only switches: Partner Center, Defender, Compliance (Purview). No navigation/branding changes. |
| `2e9b9fd508f2e9ae6fddffa9f03db7c8edb22881` | `ac59795fb` | Applied with adaptation | Hide open button when drawer is controlled | `CippTenantAllowBlockListTemplateDrawer.jsx` | Static review | Cherry-pick conflicted: fork lacks upstream `editData`/`isEditMode` controlled-drawer stack (`bc412396b`). Adapted: optional `drawerVisible: controlledDrawerVisible` prop + `controlledDrawerVisible === undefined` guard only. Uncontrolled page usage unchanged. |
| `d7e8b0b569c3f9243ff7e09a326ed74ccbd3a046` | `377ce394b` | **Already implemented** | Toggle button size/sx on alignment page | `standards/alignment/index.js` | Static review | Incorporated when fork ported by-standard view (`377ce394b`). Cherry-pick `-x` conflicted (formatting-only); verified identical `MuiToggleButton-root` sx on tenant filter and view-mode toggles. |
| `1cb6a11cf22c446b952976f5200f5a3f3df689f5` | `377ce394b` | **Already implemented** | Standard name retrieval priority | `standards/alignment/index.js` | Static review | `hasExactMatch` + label/`row.standardName`/`standardKey` fallback chain already present in `377ce394b`. No code delta on sync branch. |

## Mini-batch 5 Validation — Standards Alignment Pair (2026-06-17)

| Check | Result |
|-------|--------|
| Pre-check protected areas | Both commits touch only `src/pages/tenant/standards/alignment/index.js` — no protected overlap |
| `d7e8b0b5` cherry-pick | Conflict — fork already has toggle sx (`py: 0.25`, `px: 1`, `fontSize: 0.75rem`) on both ToggleButtonGroups |
| `1cb6a11c` cherry-pick | Not attempted separately — same file; logic already present |
| Toggle buttons | Still render; only size/style sx applied; no behavior change |
| Standard name retrieval | `hasExactMatch ? (label ?? row.standardName ?? key) : (row.standardName ?? label ?? key)` — safe fallbacks when fields missing |
| Data fetching / tenant / permissions | Unchanged |
| Full frontend build/lint | Not run — known pre-existing dependency blockers |

## Proposed Next Candidates (post-checkpoint)

| Priority | SHA | Title | Notes |
|----------|-----|-------|-------|
| 1 | `7054bfc4` + API pair | UserReportedPhishing alert | Paired with CIPP-API handler + SAM permission |
| 2 | `b1902421` | Tab layout first-tab margin | Adapted manual apply only |
| 3 | `bc412396b` / `20e2f554d` | Allow/block list edit mode | Full controlled-drawer stack |
| 4 | `4c0c058f` | Alerts schema change | Higher risk — review before apply |

**Exclude:** `16b4503f`, dependency/build/search/table commits unless explicitly approved.

## Next Steps

1. Final code-review-only pass on sync branch diff vs `main`.
2. Open CIPP frontend PR paired with CIPP-API PR #1 review.
3. Do not continue upstream picks without explicit approval per candidate.
