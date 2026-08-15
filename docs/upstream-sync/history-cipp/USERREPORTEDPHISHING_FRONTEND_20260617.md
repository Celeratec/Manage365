# UserReportedPhishing — Frontend Enablement

Generated: 2026-06-17  
Branch: `manage365/userreportedphishing-frontend-20260617`  
Backup tag: `backup/pre-userreportedphishing-frontend-20260617`  
Base: `main`

## Prerequisites (completed before this PR)

| Gate | Status |
|------|--------|
| CIPP-API PR #2 merged | Yes — https://github.com/Celeratec/CIPP-API/pull/2 |
| Backend handler | `Get-CIPPAlertUserReportedPhishing` on CIPP-API `master` |
| SAM manifest | `ThreatSubmission.ReadWrite.All` in Config + lib/data SAM manifests |
| SAM/CPV/consent validation | Completed |
| Backend smoke test | Clean |

## Upstream Commit

| Field | Value |
|-------|--------|
| SHA | `7054bfc42` (short: `7054bfc4`) |
| Title | Add AlertUserReportPhising |
| Author | KelvinTegelaar |
| Date | 2026-05-12 |

## Pre-Apply Verification

`git show --stat 7054bfc4` — 1 file, 15 insertions:

- `src/data/alerts.json` only

No auth, tenant switching, quarantine, Email Troubleshooter, navigation, package/build, or API helper files touched.

## Apply Result

| Status | Detail |
|--------|--------|
| **Applied cleanly** | Cherry-pick `-x` succeeded with no conflicts |

Previously deferred in Cycle 1 sync (`de565d5f9` → reverted `b0fcc3129`); now unblocked after API rollout validation.

## Files Changed

| File | Change |
|------|--------|
| `src/data/alerts.json` | Added `UserReportedPhishing` alert definition (+15 lines) |
| `docs/upstream-sync/USERREPORTEDPHISHING_FRONTEND_20260617.md` | This tracking doc |

## Alert Definition Validation

| Check | Result |
|-------|--------|
| JSON parses | Pass |
| Alert name/key | `UserReportedPhishing` |
| Backend handler resolution | `Get-CIPPAlertUserReportedPhishing` (via `Push-SchedulerAlert` naming) |
| `HoursBack` input | Present (`inputType: number`, `inputName: HoursBack`) |
| `recommendedRunInterval` | `4h` |
| Typo / handler mismatch | None |
| Other alerts modified | **No** — append-only entry at end of array |

## Rollout Note

This PR **exposes** the alert in the frontend catalog only. After merge:

- Enable `UserReportedPhishing` in **SchedulerConfig / tenant alert settings in a controlled manner** (one test tenant first, then broader rollout).
- Do not bulk-enable globally without operator review.
- Requires `ThreatSubmission.ReadWrite.All` granted on CIPP service principal in each tenant where enabled.

## Related Docs

- CIPP-API: `USERREPORTEDPHISHING_API_20260617.md`, `USERREPORTEDPHISHING_POST_MERGE_20260617.md`, `USERREPORTEDPHISHING_ROLLOUT_RUNBOOK_20260617.md`
- Prior deferral: `APPLIED_COMMITS_CIPP_20260617.md` (row for `7054bfc4`)
