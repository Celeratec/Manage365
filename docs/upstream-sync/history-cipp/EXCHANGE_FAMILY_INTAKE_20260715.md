# Exchange/Mailbox Family Intake — 2026-07-15

Feature intake of the deferred upstream Exchange/mailbox page family (8 frontend commits) plus
their API dependencies. Fork frontend version bumped **5.20.0 → 5.21.0**.

## Upstream commits taken

| Commit | Summary | How it landed |
|---|---|---|
| `ed025994c` | Encode UPN + surface report errors in Mailbox Access card | Merged into fork `exchange.jsx` (guest `#EXT#` fix) |
| `6433cd3a2` | Merge Entra ID and Exchange proxy addresses, show drift | Merged into fork `exchange.jsx` |
| `fc446f8d0` | Opt-in mail-enabled security groups in permission dialogs, grouped picker | Dialogs adopted wholesale; page logic merged |
| `553e4cfc2` | Lint churn | **Skipped** (formatting only) |
| `a3d25bfbb` | Bulk remove mailbox permissions on report page | Page adopted wholesale (upstream version) |
| `605990cdb` | Mailbox Access card on exchange page | Merged into fork `exchange.jsx` |
| `b1838ab84` | Show SMTP auth state on user tab | Adapted to fork's interactive protocols card |
| `afca350cb` | Navigation links on dashboard cards | Adapted to fork's rewritten cards |

## Frontend (CIPP)

- **`src/pages/identity/administration/users/user/exchange.jsx`** (heavily customized in fork — surgical merge):
  - New **Mailbox Access** banner card (inverse of Mailbox Permissions) fed from the cached
    permission report, with per-row bulk removal. UPN is URL-encoded so guest users work; an
    error state distinguishes "report failed to load" from "no access".
  - **Proxy Addresses** card now merges Entra ID `proxyAddresses` with Exchange
    `EmailAddresses` and shows a `Source` column ("Entra ID & Exchange" / "Entra ID only" /
    "Exchange only") so directory drift is visible. Make Primary / Remove restricted to
    `Type === "Alias"` rows. Alias actions also refresh the mailbox query.
  - Permission pickers now have an opt-in **"Include mail-enabled security groups"** switch
    (state resets when all dialogs close); options are grouped (System Users / Users /
    Mail-enabled Security Groups). Groups query only fires when toggled on.
  - **Preserved fork customizations**: `mail`-based recipient values with `.filter(user.mail)`
    in calendar/contact pickers, memoized subtitle, `getPermissionInfo` resolver, all fork-only
    cards (mailbox rules, junk email config) and layout sections.
- **Permission dialogs** (`CippMailboxPermissionsDialog`, `CippCalendarPermissionsDialog`,
  `CippContactPermissionsDialog`): adopted upstream wholesale (fork copies were stale upstream
  versions, no customizations). They render the include-groups switch and grouped autocomplete.
- **`src/pages/email/reports/mailbox-permissions/index.js`**: adopted upstream wholesale. Now
  uses the shared `useCippReportDB` hook and adds **Bulk Remove Mailbox Permissions** actions in
  both By User and By Mailbox views (grouped per tenant so AllTenants selections work). Fork's
  bespoke sync/queue-tracker UI is superseded by the hook's controls.
- **`src/components/CippComponents/CippReportDBControls.jsx`**: adopted upstream wholesale
  (per-tenant cache override + `Types: 'None'` on plain mailbox cache syncs). No fork-only
  commits existed on this file.
- **`src/components/CippCards/CippExchangeInfoCard.jsx`** (fork's interactive rewrite —
  adapted, not replaced): added **SMTP Auth** chip to the Legacy Protocols section.
  `SmtpClientAuthenticationDisabled` is inverted in EXO: `false` = basic auth enabled (red,
  clickable to disable), `true` = disabled (neutral), `null` = follows org default (neutral,
  not clickable). "Disable Both" button now keys off IMAP/POP only.
- **Dashboard cards** (`AuthMethodCard`, `MFACard`, `SecureScoreCard`, `LicenseCard`): card
  header titles are now clickable links to their report pages (mfa-report, securescore,
  list-licenses). Fork's `LicenseCard` bars deep-link to the licenses report filtered on that
  license. `CippSankey` renders `node.label ?? node.id` (upstream unique-id fix support).
- **`src/pages/tenant/reports/list-licenses/index.js`**: parses `?filters=` from the URL into
  `initialFilters` for deep links. Still uses fork's `/api/ListLicenses` (upstream's
  `ListLicensesReport` remains deferred).

## API (CIPP-API)

- **`Invoke-ExecModifyMBPerms.ps1`**: adopted upstream's refactor — permission-level → cmdlet
  mapping now delegates to `Set-CIPPMailboxPermission -AsCmdletObject` (single source of
  truth), and successful FullAccess/SendAs/SendOnBehalf ops call
  `Sync-CIPPMailboxPermissionCache` so the cached report stays current after bulk changes
  (required by the new bulk-remove UI). **Preserved fork's guest-UPN retry**: on
  `InvalidExternalUserIdException` the op retries with the Entra object ID, now via a shared
  `Invoke-ExoRequestWithGuestRetry` helper used in the bulk-result, fallback, and single-op
  paths.
- **`Invoke-ExecSetCASMailbox.ps1`**: legacy (fork card) caller path now accepts `SMTP`,
  mapping to `SmtpClientAuthenticationDisabled` with inverted boolean.
- `Sync-CIPPMailboxPermissionCache` and `Set-CIPPMailboxPermission -AsCmdletObject` already
  existed in the fork (identical / near-identical to upstream); `ListMailboxPermissions`
  already supported `ByUser`/`UseReportDB`. No SAM manifest changes needed.

## Verification

- All changed frontend files lint-clean; `yarn build` passes (67s).
- Both changed API files pass PowerShell parser validation.
- Backup tags: `backup/pre-exchange-intake-20260715` in both repos.

## Still deferred from this family's neighborhood

- `ListLicensesReport` API (`2f02befcd`) — fork keeps `/api/ListLicenses`.
- Upstream's Sankey-based `LicenseCard` — fork keeps its progress-bar rewrite.
- UserActions family, nested group memberships, MEM devices pages (separate intakes).
