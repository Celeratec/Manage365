# SSO / CIPP Users Family — Deferral Decision — July 15, 2026

Cycle type: **Feature intake (evaluated, declined)** per [PROCESS.md](PROCESS.md).

The SSO / CIPP-user family was the largest remaining deferred item after the Copilot & AI,
SAM certificate, and SharePoint suite intakes. This cycle inventoried it fully and concluded it
**cannot be safely intaken** under Manage365's current hosting architecture. One standalone fix
from the same commit window was taken.

## What the family is

Upstream commits inventoried (CIPP-API): `2a2851b57` (sso auth), `fc76e111b` (app repair +
migration failures), `d2e54ee85` (app password policy), `168a11032` (manual cred input),
`405c55d08` (redirect URI), `9520792f4` (stats timer migration status), `fa5f4de6f` (feature
flag removal), plus the `be25c7640` squash that introduced `Invoke-ExecSSOSetup`,
`Invoke-ListCIPPUsers` / `Invoke-ExecCIPPUsers`, and `Start-UserSyncTimer`.

Frontend counterparts: `src/pages/cipp/advanced/super-admin/sso.js`, `cipp-users.js`,
`CippSSOSettings.jsx`, `SsoMigrationDialog.jsx`, `ForcedSsoMigrationDialog.jsx`, and the
`unauthenticated.js` rewrite.

Purpose: migrate CIPP instances **off Azure Static Web Apps built-in auth** onto a dedicated
CIPP-SSO Entra app with **EasyAuth configured directly on the app host**, with CIPP user/role
management moving from SWA invitations to an `allowedUsers` table synced from partner-tenant
Entra groups.

## Why it was declined

1. **Hard dependency on upstream's "Craft" container runtime.** Core files call
   `[Craft.Services.AppLifecycleBridge]` / `[Craft.Services.AuthBridge]` — C# bridges that exist
   only inside upstream's new hosted container image. They are **not** part of `CIPPSharp`.
   Upstream's `Initialize-CIPPAuth.ps1` calls `AppLifecycleBridge::IsEasyAuthConfigured()`
   unguarded at the top of warmup; adopting it would throw on every cold start of our Function
   App. (The fork already carries a few `Craft.Services.*` call sites from earlier syncs, but all
   are gated behind `$env:CIPPNG -eq 'true'` or try/catch, so they are inert.)
2. **The CIPP Users page would be a no-op.** `ExecCIPPUsers`/`ListCIPPUsers` manage the
   `allowedUsers` table, but the only thing that *enforces* that table at auth time is
   `Craft.Services.AuthBridge` inside the container host. Under our SWA auth, roles come from SWA
   invitations plus Entra-group resolution in `Test-CIPPAccessUserRole` (which we already have,
   identical to upstream). Shipping the page would present a user-management UI that silently
   does nothing.
3. **Production lockout risk.** `Set-CIPPSSOEasyAuth` rewrites `authsettingsV2` on the live
   Function App (`$env:WEBSITE_SITE_NAME`) via ARM, and the `Migrate` action in
   `Invoke-ExecSSOSetup` is designed to move a SWA-authenticated instance onto EasyAuth. Running
   any part of that against Manage365's SWA + linked Function App deployment risks breaking the
   SWA→API auth handoff and locking us out.

## Revisit condition

Revisit **only** if/when Manage365 deliberately migrates hosting off SWA auth (e.g. upstream
fully deprecates the SWA model, or we adopt their container/self-host layout). At that point
this family is the migration path, not an optional feature — plan it as an infrastructure
change with rollback, not a code intake.

Also skipped from the same window:

- `Update-CIPPSAMRedirectUri` switch to `-AsApp $true` — depends on app-only
  `Application.ReadWrite` behavior we haven't validated against our SAM app; the fork's
  delegated version works today.
- `Start-CIPPStatsTimer` SSO-migration status fields — meaningless without the SSO stack.
- `Initialize-CIPPTimezone`, `Get-CIPPManagedIdentityResourceId`,
  `Remove-CIPPMigrationAppSetting`, `Repair-CippApiIdentifierUri`, `Request-CIPPRestart` —
  SSO/Craft support helpers with no consumer in the fork.

## Taken (standalone fix from the same window)

- **`Invoke-CIPPStandardDisableGuests` — PendingAcceptance handling** (upstream `2edc75928`):
  guests who never redeemed their invite (`externalUserState -eq 'PendingAcceptance'`) are now
  disabled once the invite is older than the threshold, alerts break counts into stale sign-ins
  vs unredeemed invites, and the report fields gained `GuestsStaleSignInCount` /
  `GuestsPendingAcceptanceCount` / `GuestsPendingAcceptanceDetails`. The `standards.json` entry
  was already identical between fork and upstream, so this is a pure `.ps1` update.

## Verification

- PowerShell parser on the changed file: 0 errors.
- No frontend changes this cycle; no build needed.

## Remaining deferred families (unchanged priority candidates)

With SSO ruled out, the largest still-compatible deferred items are the BEC UI family, the
Exchange/mailbox page family, Custom Test Alerting overhaul, Intune Policy sync / device app
collection, scheduled user edit UI, and nested group memberships.
