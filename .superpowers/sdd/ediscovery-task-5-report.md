# Task 5 Report: Migrate Existing Cases Endpoints + Docs

Status: completed and pushed to draft PR.

Branch: `clint/ediscovery-config-readiness`

PR: https://github.com/Celeratec/Manage365/pull/96

Commits:
- `56ab7041c` `feat(ediscovery): migrate cases endpoints`

Implemented:
- Migrated existing Security eDiscovery Cases list endpoints from `New-GraphGetRequest` to `Get-CIPPEdiscoveryAccessToken` + `Invoke-CIPPEdiscoveryRequest`.
- Migrated existing case/search/hold write endpoints from `New-GraphPostRequest` to guarded writes, default dry run, reason requirement, dedicated token, and allowlisted actions.
- Hard-refused case delete, search delete, search purge, hold remove/delete, and export/content download before Graph transport.
- Removed frontend destructive/export affordances and updated setup/remediation copy to readiness + dedicated eDiscovery app, not CIPP SAM/CPV.
- Added `docs/api-documentation/ediscovery-search.md` runbook and identity model.
- Added Pester endpoint coverage proving refused actions return `400` with zero transport calls.

Verification:
- `pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/Ediscovery -Output Detailed"`: 36 passed.
- Aikido path scan on 18 changed/new first-party files: 0 issues.
- `git diff --check`: passed.
- Cursor lints on touched files: no IDE diagnostics.
- Frontend lint: initial `yarn lint` blocked by local Node 24.22.1 vs required `^22.23.4`; `YARN_IGNORE_ENGINES=1 yarn lint` ran and failed on existing repo-wide lint issues. Targeted lint on touched frontend files still reports pre-existing JSX-in-`.js` and React Compiler hook/polling issues unrelated to this task.

Concerns:
- Existing frontend lint debt remains in the eDiscovery route files and `CippApiResults.jsx`; this PR did not rename routes or rewrite unrelated polling/job-progress internals.
- Existing frontend callers for allowed writes must supply `ticketNumber`, `reason`, and `dryRun:false` for live execution because eDiscovery writes now fail closed and default to preview.

Rollback:
- Revert PR #96, or disable `EdiscoverySearch` / remove the tenant `EdiscoveryConfig` row to stop dedicated eDiscovery calls.

## Review Fixes: Redaction + Guarded Frontend Writes

Status: completed for Task 5 review findings.

Implemented:
- Added counts-only eDiscovery redaction for guarded-write audit request bodies, list searches, list holds, and operation result info.
- Removed `contentQuery` text and raw `userSources` / `siteSources` from list API responses, replacing them with presence/count fields.
- Added ticket number, reason, and dry-run controls to supported frontend eDiscovery writes: case create/close/reopen, search create/estimate, and hold create.
- Stripped trailing whitespace from `docs/superpowers` files without removing Freshdesk #3276171 references.

Verification:
- `pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/Ediscovery -Output Detailed"`: 40 passed.
- Aikido path scan on 12 changed code/test files: 0 issues, 0 skipped.
- `git diff --check`: passed.
- Cursor lints on touched code files: no IDE diagnostics.
- Targeted frontend lint with `YARN_IGNORE_ENGINES=1 yarn eslint ...`: still fails on existing eDiscovery route lint debt (`react/jsx-filename-extension`, case page `react-hooks/set-state-in-effect`, searches page `react-hooks/immutability` polling mutation).

Concerns:
- Frontend route lint debt remains pre-existing and was not broadened into this security fix.
- No frontend typecheck script exists in `frontend/package.json`; validation used Pester, Aikido, diff-check, IDE lints, and targeted eslint.
