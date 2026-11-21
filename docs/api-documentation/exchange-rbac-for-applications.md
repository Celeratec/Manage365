# Exchange RBAC for applications

Use this page when verifying application access limited by Exchange RBAC for Applications (management scopes and role assignments), not only Entra app roles.

## Facts that matter

- Exchange RBAC for Applications and Application Access Policies are **unioned**: either path can grant access.
- An Entra app role or OAuth grant can widen access even when Exchange scopes look tight — keep Entra permissions empty for mailbox-scoped apps.
- Permission changes often take **30 minutes to 2 hours** to show up in Graph mailbox calls. `Test-ServicePrincipalAuthorization` (Exchange) bypasses the propagation cache; Graph app-only probes do not.

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

## Runbook (create → assign → verify)

1. Create the app with **public certificate only** (`ExecAppRegistration` certificate path when available). No Entra `requiredResourceAccess`, no admin consent, no client secret.
2. Store the private key **outside** Manage365 (operator box / HSM). Manage365 must never receive the private key.
3. In Exchange (ticketed allowlist): `New-ServicePrincipal` (use the **service principal object id**), `New-ManagementScope`, `New-ManagementRoleAssignment` for `Application Mail.Read` only (never `Mail.ReadWrite` / `Mail.Send` / unscoped).
4. Wait for propagation (30 min–2 h) before Graph probes.
5. Exchange-side check: `Test-ServicePrincipalAuthorization` — in-scope mailbox `InScope = True`; out-of-scope `InScope = False`; no `ScopeType = Organization`.
6. App-only Graph check: run `scripts/security/Test-AppOnlyMailboxAccess.ps1` (below).
7. Rollback order: role assignment → scope → Exchange service principal → credential → app registration.

### Entra-side checks via `ListGraphRequest` (GET only)

Confirm for the application object:

- `requiredResourceAccess` is empty
- `keyCredentials` has exactly one entry whose end date matches the certificate
- `passwordCredentials` is empty

Confirm for the service principal:

- `appRoleAssignments` empty
- `oauth2PermissionGrants` empty

## App-only mailbox probe (PR6, option A)

**Decision:** open question 1 = **A** (out-of-runtime script). Options B (Key Vault signing endpoint) and C (federated credential so Manage365 can mint tokens as the app) are rejected — Manage365 must not hold a standing path to firm mail.

```powershell
pwsh scripts/security/Test-AppOnlyMailboxAccess.ps1 `
  -TenantId '<tenant-guid>' `
  -ClientId '<app-id>' `
  -CertificatePath '/secure/path/app.pfx' `
  -InScopeMailbox 'scoped@contoso.test' `
  -OutOfScopeMailbox 'other@contoso.test','third@contoso.test' `
  -WaitForPropagation
```

- Passphrase: `SecureString` prompt or `-CertificatePassword (Read-Host -AsSecureString)` — never a plaintext CLI value, never committed.
- Or `-CertificateThumbprint` for a cert already in the local store.
- Expected: HTTP **200** (in-scope), **403** (out-of-scope). Exit code non-zero on mismatch.
- Output: status codes and item counts only — never tokens, assertions, keys, message ids, subjects, or bodies.
- Hosts pinned to `login.microsoftonline.com` and `graph.microsoft.com`; GET-only Graph path template.

## What Manage365 deliberately does not do

- Create or store private keys / PFX material
- Expose an HTTP endpoint that signs as the mailbox app
- Yopass or similar secret relays for app keys
- Unscoped `Application Mail.Read` assignments without an explicit ticketed scope

## Related

- [Guarded tenant writes](guarded-writes.md)
