# UserReportedPhishing — Frontend Post-Merge Status

Generated: 2026-06-17  
Repo: Celeratec/CIPP  
Main tip: `7050757b2`

## Merge Summary

| Field | Value |
|-------|--------|
| **PR** | https://github.com/Celeratec/CIPP/pull/9 |
| **Merge commit** | `7050757b2` |
| **Feature commit** | `5b3ef362c` |
| **Title** | Expose user reported phishing alert |
| **Backup tag (retained)** | `backup/pre-userreportedphishing-frontend-20260617` → pre-PR `main` |

## Files Changed (PR #9)

| File | Change |
|------|--------|
| `src/data/alerts.json` | Added `UserReportedPhishing` alert definition (+15 lines) |
| `docs/upstream-sync/USERREPORTEDPHISHING_FRONTEND_20260617.md` | Import/enablement tracking doc |

## Validation Summary

| Check | Result |
|-------|--------|
| PR scope | 2 files only — `alerts.json` + tracking doc |
| `alerts.json` valid JSON | Pass |
| Alert name | `UserReportedPhishing` (maps to `Get-CIPPAlertUserReportedPhishing`) |
| `HoursBack` input | Present |
| `recommendedRunInterval` | `4h` |
| Other alerts modified | **No** — append-only |
| Upstream commit | `7054bfc4` cherry-picked cleanly |

## Backend Dependency

Satisfied by **CIPP-API PR #2** (merged):

- https://github.com/Celeratec/CIPP-API/pull/2
- Handler: `Get-CIPPAlertUserReportedPhishing`
- Permission: `ThreatSubmission.ReadWrite.All` (`d72bdbf4-a59b-405c-8b04-5995895819ac`)
- SAM/CPV/consent validated and backend smoke test clean **before** frontend PR #9 merged

## Deployment Requirement

Deploy **CIPP `main`** (includes PR #9) alongside **CIPP-API `master`** (includes PR #2). Frontend alert catalog entries have no effect until both are deployed to the target environment.

## Operational Gate (remaining)

**First-tenant production enablement not performed yet.**

Before broader rollout:

1. Deploy paired CIPP + CIPP-API to target environment (if not already).
2. Enable `UserReportedPhishing` in SchedulerConfig / tenant alert settings for **one test tenant first**.
3. Use **`HoursBack: 24`** for initial run.
4. Validate scheduler invokes `Get-CIPPAlertUserReportedPhishing` and produces expected trace (or clean no-op when no submissions).
5. **Do not bulk-enable globally** until one clean scheduler run is documented.

## Related Docs

- Import: `docs/upstream-sync/USERREPORTEDPHISHING_FRONTEND_20260617.md`
- CIPP-API: `USERREPORTEDPHISHING_API_20260617.md`, `USERREPORTEDPHISHING_POST_MERGE_20260617.md`, `USERREPORTEDPHISHING_ROLLOUT_RUNBOOK_20260617.md`, `USERREPORTEDPHISHING_FINAL_STATUS_20260617.md`
