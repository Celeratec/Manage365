# Tenant group selector — 2026-11-22

Selective CIPP intake on `clint/upstream-tenant-group-selector`. Fork-only; never PR CyberDrain/CIPP.

**Base:** `clint/upstream-auth-blockalltenants` (#86) — `444c477ba` depends on BlockAllTenants / `Test-CippAllTenantsBlocked`.

| SHA | Change | Status |
|-----|--------|--------|
| `444c477ba` | View data for a tenant group from the tenant selector (`TenantGroupSelector` flag, **off by default**) | Applied (`8a8eefe4c`) with Adapt |
| `931b3612c` | Open pages that don't use a tenant while a tenant group is selected (`usesTenant={false}`) | Applied (`7164303bb`); DU paths kept deleted |

## Adapt notes

- Keep Manage365 FeatureFlags (`GuardedTenantWrites`, `AzureArm`) and append `TenantGroupSelector` (Enabled: false).
- `New-CippCoreRequest`: clear `CippAllowedTenantsStorage` / groups when unrestricted (prevents scope bleed across requests).
- `Test-CIPPAccess` TenantList short-circuit for unrestricted callers.
- ListNamedLocations AllTenants cache path + ListIPWhitelist `Select-CippAllowedTenantData`.
- FE: keep Manage365 page Adapt; wire `tenantGroupSupport` / `tenantScope` / `usesTenant={false}`; do not restore deleted drawers/pages from Intune/NHI/Exo packs not on this base.

## Verify

- OpenAPI regen **879**.
- Pester: TenantGroup CoreRequest, Test-CIPPAccess.Core, Get-TenantGroups.Scope, ListTenantGroups.TenantSelector, TenantGroupEndpointScope.
- Baseline stays **11.2.1**.

## PR notes

Draft includes #86 auth commits until #86 merges; then rebase this branch onto main. Overlaps openapi with #81–#87.
