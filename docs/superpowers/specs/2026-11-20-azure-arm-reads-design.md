# Design: Azure ARM read support (#3272074 PR1)

**Date:** 2026-11-20
**Branch:** `clint/azure-arm-reads`
**Status:** Proceeding with Clint “proceed smartly” defaults

## Decisions (open item #4)

1. **Config store:** Azure Table `AzureArmConfig` (PartitionKey = tenantFilter, RowKey = `config`).
2. **Credentials:** Key Vault secret/cert *names* only on the config row; resolve via `Get-CippKeyVaultSecret` / certificate helpers. Never store secret values in the table.
3. **Feature flag:** new `AzureArm` (default off), listing all `ListAz*` (+ config endpoints).
4. **Defer** `ListAzWebAppSettingNames` to PR2 (needs `change` profile).

## Architecture

- `Get-CIPPAzArmTenantConfig` / `Set-CIPPAzArmTenantConfig` — table CRUD; Set is ticketed via `ExecAzArmConfig`.
- `Get-CIPPAzArmAccessToken -TenantFilter -Profile` — Lighthouse (managing-tenant client credentials) or ServicePrincipal (client-tenant); profiles `reader`|`change`|`rbac`; fail closed; refuse SAM app id.
- `Invoke-CIPPAzArmRequest` — host allowlist `management.azure.com` only; path from templates + pinned subscription/RG; deny list; classified-read POSTs; page cap; 429/5xx backoff; no token in logs.
- `AzureArmReadAllowlist.json` — action → method/path/api-version/profile/role.
- Thin `Invoke-ListAz*` entrypoints call shared `Invoke-CIPPAzArmListAction`.

## Out of scope

PR2 writes, PR3 role assignments, `ListAzWebAppSettingNames`, client/tenant calls, enabling the flag in prod.
