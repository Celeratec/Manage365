# Design: ListExoRequest read-only Test-* cmdlets (#3281675 PR1)

**Date:** 2026-11-20  
**Branch:** `clint/exo-read-test-cmdlets`  
**Status:** Approved (Clint: “yes”)

## Goal

Run `Test-ServicePrincipalAuthorization` and `Test-ApplicationAccessPolicy` as **reads** through `ListExoRequest`, without using `ExecExoAllowlistedCmdlet` (ticket, write role, rate limit, dryRun-without-run).

## Approach

1. New allowlist `backend/Config/GuardedWrites/ExoReadTestAllowlist.json` with exact cmdlets/params (not a verb wildcard).
2. Extend `Invoke-ListExoRequest`: keep `Get`/`Search`; accept verb `Test` only when on that allowlist with validated params.
3. Shared ASCII parameter-name helper reused by `Get-CIPPExoAllowlistedCmdletPlan` and the new read-test plan.
4. Extra role: `Tenant.AppGovernance.Read` via `Get-CippRequestAllowedPermissions`.
5. Always `New-ExoRequest -useSystemMailbox $true` for these two.
6. Optional `Meta.OrganizationScopedGrant` tripwire on SPA results (`ScopeType = Organization`).
7. No audit row; log cmdlet name + row count only.

## Validation

| Cmdlet | Params | Rules |
| --- | --- | --- |
| `Test-ServicePrincipalAuthorization` | `Identity`, `Resource` | Identity = GUID; Resource required = UPN/SMTP/GUID (1–320, no `*`, `%` tokens, controls, arrays) |
| `Test-ApplicationAccessPolicy` | `Identity`, `AppId` | Identity = UPN/SMTP/GUID; AppId = GUID |

Any other `Test-*`, extra/misspelled params, or bad values → 400. Missing `Tenant.AppGovernance.Read` → 403.

## Out of scope

PR2–PR6, Azure ARM, enabling `GuardedTenantWrites`, client/tenant calls, flipping global dryRun default.

## Docs / OpenAPI

- New `docs/api-documentation/exchange-rbac-for-applications.md` (interpretation table).
- Note in `guarded-writes.md` / endpoints that the read path exists separately from the write allowlist.
- Update OpenAPI description for `ListExoRequest`.
