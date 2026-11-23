# Task 3 Report: Access Token + Graph Request + Path Plan

Status: DONE

Implemented:
- Added `Get-CIPPEdiscoveryAccessToken` using per-tenant config, Key Vault certificate refs, `Get-GraphTokenFromCert`, Graph `.default` scope, tenant resolution via `Get-Tenants`, token caching, and SAM app-id refusal.
- Added `Get-CIPPEdiscoveryGraphPlan` to resolve allowlisted eDiscovery actions into method/path/classification with GUID-like segment validation and traversal/scheme rejection.
- Added `Invoke-CIPPEdiscoveryRequest` with graph.microsoft.com-only enforcement, injectable `-Transport`, forbidden-action path checks, encoded traversal rejection, paging, write operation polling, bearer redaction, and counts-only `downloadUrl` blocking.
- Added `backend/Tests/Ediscovery/EdiscoveryTokenAndRequest.Tests.ps1`.

Verification:
- Red check: new Task 3 tests initially failed because the functions did not exist.
- Red check: encoded traversal test failed before decoded-path validation, then passed after implementation.
- Pester: `pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/Ediscovery -Output Detailed"` passed 17/17.
- Lints: no linter errors reported for edited files.
- Aikido: `aikido_full_scan` and final `aikido_scan_paths` reported zero issues; final path scan covered 4 files with no skipped paths.

Concerns:
- Full repository Pester was not run; verification was scoped to `backend/Tests/Ediscovery`.
- Certificate loading prefers `EphemeralKeySet` and falls back when the local platform does not support it, matching local macOS test constraints.

## Task 3 review fixes (empty Graph `value` + allowlist hashtables)

Fixes:
- `Invoke-CIPPEdiscoveryRequest` treats OData list payloads via explicit `value` key/property detection (`IDictionary.Contains` / `PSObject.Properties`) so `@{ value = @() }` yields `Results.Count = 0` instead of one wrapper row.
- `Get-CIPPEdiscoveryGraphPlan -Allowlist` resolves actions from injected hashtables or JSON-deserialized objects.

Tests:
- Added Pester cases: empty `value` → zero rows; injected hashtable allowlist.
- `pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/Ediscovery/EdiscoveryTokenAndRequest.Tests.ps1 -Output Detailed"` → **Passed 11, Failed 0** (732ms).

Aikido: rescanned 3 modified files — zero issues.
