# Exchange RBAC for applications (read checks)

Use this page when verifying application access that is limited by Exchange RBAC for Applications (management scopes and role assignments), not only Entra app roles.

## Read path: `ListExoRequest`

`ListExoRequest` (`CIPP.Core.Read`) still accepts `Get-*` and `Search-*`. It also accepts these two cmdlets when the caller also has **`Tenant.AppGovernance.Read`**:

| Cmdlet | Required `cmdParams` |
| --- | --- |
| `Test-ServicePrincipalAuthorization` | `Identity` (service principal / app **GUID** only), `Resource` (mailbox UPN, SMTP, or GUID) |
| `Test-ApplicationAccessPolicy` | `Identity` (target **recipient** UPN/SMTP/GUID), `AppId` (app GUID) |

Allowlist file: `backend/Config/GuardedWrites/ExoReadTestAllowlist.json`. Any other `Test-*` is rejected. These reads always use the system mailbox. There is **no** guarded-write audit row and no ticket requirement.

The same two cmdlets remain on the **write** allowlist (`ExecExoAllowlistedCmdlet`, `Exchange.Security.ReadWrite`, ticket + dryRun). Prefer `ListExoRequest` for a real check so you do not burn the write rate limit or get a dry-run “Would run” stub.

## Interpreting `Test-ServicePrincipalAuthorization`

Columns of interest: `RoleName`, `GrantedPermissions`, `AllowedResourceScope`, `ScopeType`, `InScope`.

| `InScope` | Meaning |
| --- | --- |
| `True` | The RBAC grant covers this `Resource` mailbox (for this simulation). |
| `False` | The grant exists but this mailbox is outside the scope. |
| `Not Run` | Returned when `Resource` is omitted; this API requires `Resource` so you should not see this on success. |

`ScopeType = Organization` means an **unscoped** grant: `InScope` is `True` for every mailbox. Treat that as a tripwire. `ListExoRequest` sets `Meta.OrganizationScopedGrant` to `true` when any result row has `ScopeType` equal to `Organization`.

This cmdlet simulates **Exchange RBAC grants only** (not Entra grants) and **bypasses the propagation cache**.

## Interpreting `Test-ApplicationAccessPolicy`

Here `Identity` is the **recipient**, not the application. `AppId` is the application id.

## Propagation

Permission changes (new service principal, management scope, or role assignment) often take **30 minutes to 2 hours** to show up in Graph or mailbox access tests. Prefer `Test-ServicePrincipalAuthorization` through this read path when you need a cache-bypassing RBAC check soon after a change.

## Related

- Guarded write allowlist and ticketed EXO cmdlets: [Guarded tenant writes](guarded-writes.md)
