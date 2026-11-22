# Auth hardening — 2026-11-22

Selective CIPP intake on `clint/upstream-auth-blockalltenants`. Fork-only; never PR CyberDrain/CIPP.

| SHA | Change | Status |
|-----|--------|--------|
| `95cfca890` | `BlockAllTenants` custom role flag + access-scope helpers | Applied (`6edc516cf`) |
| `941953042` | Grant CIPP roles from trusted Entra app roles | Applied (`e18407e1b`); RestoreBackup RestrictedTables Adapt via allowedAppRoles+DevSecrets |
| `eb540a7fd` | Restricted multi-tenant SSO sign-in mode | Applied (`fc215ceb5`) |
| `8d2ca384e` | Refuse AllTenants bulk deploys for BlockAllTenants (403) | Applied with Adapt (`74c3d831e`) |
| `9fced15f0` | Keep endpoint blocks on AllTenants when BlockAllTenants is set | Applied (`78752de0f`) |

## Adapt notes (`8d2ca384e`)

- **New-CippCoreRequest**: map status via `Get-CippErrorStatusCode` while keeping Manage365 structured JSON error body (`Get-CippException` + details).
- **Resolve-CippBulkSelectedTenant**: helper landed with BlockAllTenants → `UnauthorizedAccessException`; unit tests under `backend/Tests/Private/Resolve-CippBulkSelectedTenant.Tests.ps1`.
- **Deferred**: wire bulk app/deploy endpoints to `Resolve-CippBulkSelectedTenant` (fork still uses inline `Test-CippAccess` / `selectedTenants` filters). Upstream `BulkEndpointTenantScope` + `OutOfMemory` dispatcher tests not restored (fork lacks OOM rewrite path and Resolve call sites).
- **ListTenants** already hides AllTenants selector when `Test-CippAllTenantsBlocked`.

## Verify

- OpenAPI regen: **879** endpoints; `AppRoleTenants` on ExecCustomRole; `allowedTenants` on ExecSSOSetup.
- Pester: ErrorStatusCode, Resolve-CippBulk, Test-CIPPAccess.Core, Get-CIPPRolePermissions, Set-CIPPSSOEasyAuth, Invoke-ExecCustomRole (stubbed `ConvertTo-CIPPODataFilterValue`).
- Aikido: clean on auth pack first-party files.
- Baseline stays **11.2.1**.

## Follow-ups

- Wire `Resolve-CippBulkSelectedTenant` into Add*App / bulk deploy handlers (or take upstream `70cde7cdd`/`5dd7a697d` Adapt pack).
- Optional: restore focused dispatcher 403 integration test without full OOM suite.
