# Azure Resource Manager (ARM)

Manage365 can call Azure Resource Manager for a pinned customer subscription using a **dedicated** credential — never the CIPP SAM app. Access is off until the **Azure ARM** feature flag is enabled.

## Access model

| Mode | Token tenant | Typical use |
| --- | --- | --- |
| `lighthouse` | Managing (Cortalis) tenant | One MSP principal, many delegated subscriptions |
| `servicePrincipal` | Customer tenant | Per-client app + Azure RBAC |

Three optional profiles (fail closed if missing):

| Profile | Intended Azure roles | Used by |
| --- | --- | --- |
| `reader` | Reader (+ Cost Management Reader for costs) | All `ListAz*` in PR1 |
| `change` | Contributor on one RG | `ExecAz*` writes and `ListAzWebAppSettingNames` |
| `rbac` | Constrained RBAC admin on one RG | Future `ExecAzRoleAssignment` (PR3) |

Config lives in table `AzureArmConfig` (credential **references** only: Key Vault secret/cert names). Upsert via `ExecAzArmConfig` (`Azure.Resources.ReadWrite`, ticket + `dryRun`). Read sanitized config via `ListAzArmConfig`.

## Lighthouse vs service principal (tradeoff summary)

- **Lighthouse:** best multi-tenant scale; no per-client secret; client revokes delegation; cannot delegate Owner / RBAC Administrator / data-plane roles.
- **Service principal:** faster full capability per client; N credentials to rotate; customer CA can apply; can use RBAC Administrator + ABAC for role assignment work (PR3).

Default long-term preference: Lighthouse for reader/change; evaluate SP for RBAC assignment if Lighthouse UAA is insufficient.

## Read endpoints (`Azure.Resources.Read` / `Azure.Cost.Read`)

`ListAzSubscriptions`, `ListAzAccessStatus`, `ListAzResourceGroups`, `ListAzLocks`, `ListAzResources`, `ListAzRoleAssignments`, `ListAzProviders`, `ListAzPolicyAssignments`, `ListAzWebApps`, `ListAzIdentities`, `ListAzSqlServers`, `ListAzStorageAccounts`, `ListAzKeyVaults`, `ListAzAppInsights`, `ListAzBudgets`, `ListAzCosts` (`Azure.Cost.Read`), `ListAzActivityLog` (≤30 days), `ListAzCheckName`, `ListAzFlexLocations`, `ListAzArmConfig`.

`ListAzWebAppSettingNames` uses the **change** profile (`Azure.Resources.ReadWrite`, ticket required). It returns setting **names** and Key Vault reference strings only — never secret values.

## Write endpoints (`Azure.Resources.ReadWrite`, change profile)

`ExecAzResourceProvider`, `ExecAzIdentity`, `ExecAzStorageAccount`, `ExecAzKeyVault`, `ExecAzFunctionApp` (`create` | `setAppSettings` | `setKeyVaultReferenceIdentity`), `ExecAzTags`, `ExecAzDelete`.

Every write requires `tenantFilter`, `ticketNumber`, `reason`, and `resourceGroupName` in `allowedResourceGroups`. **`dryRun` defaults to true** (explicit `dryRun:false` to apply). Preview returns `Before`, `WhatIfPlan`, and `Rollback` with **zero** ARM writes. Create-only by default (`allowUpdate:true` to update). Secure defaults are enforced in code (TLS 1.2, no public blob, no shared key, KV RBAC + purge protection with `confirmPurgeProtection`, Flex Consumption only, no connection-string storage settings). `ExecAzDelete` is rollback-only: `managedBy=manage365` + matching `ticket` tags, allowlisted types, never resource groups or purge.

Allowlists live in `backend/Config/GuardedWrites/AzureArmAllowlist.json`.

Hard rules: only `management.azure.com`; no caller-supplied URLs; subscription pinned; RG must be in `allowedResourceGroups` for writes; never `listKeys` / secrets / data-plane hosts; tokens never logged.

## `ListAzAccessStatus`

Confirms the token, lists visible subscriptions, reads effective permissions, and sets `OverPrivilegeTripwire` when a service-principal identity looks Owner-like or subscription-wide write capable with empty `allowedResourceGroups`.

## Onboarding (high level)

1. Choose mode; create/delegate identities for the profiles you need (cert preferred).
2. Store cert/secret in Key Vault; note the secret names.
3. Enable feature flag **Azure ARM**.
4. `ExecAzArmConfig` with `dryRun:true`, then `dryRun:false`.
5. `ListAzAccessStatus` — fix tripwire warnings before any write.
6. Configure a `change` profile credential; run writes with `dryRun:true` first.

## Unsupported (by design)

SQL/T-SQL; Key Vault/Storage **data plane**; locks/diagnostics writes; budget create/change; Entra (use Graph); subscription create/transfer; management-group scope.

## Related

- [Guarded tenant writes](guarded-writes.md) (ticket envelope used by `ExecAzArmConfig`)
