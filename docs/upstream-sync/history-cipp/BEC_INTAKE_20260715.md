# BEC (Compromise Remediation) Intake — July 15, 2026

Cycle type: **Feature intake** per [PROCESS.md](PROCESS.md).

Upstream commits taken — frontend: `8359da60e` (sent messages check), `488541e0a` (recent inbox
rule changes), `a445e3981` (trusted/blocked senders checks), `cb81f1a07` (collapsible compact
check cards), `c1fb0f92a` (senders/sent-emails as tables). API: `15dc7816e` / `f95046cbe`
(inbox rule changes in `Push-BECRun`), plus retained `42087aefc` (message trace) which the fork
partially had.

Fork version bumped **5.19.0 → 5.20.0** (upstream baseline unchanged at 10.6.1).

## Taken

### CIPP-API — `Push-BECRun.ps1` (both `CIPPActivityTriggers` and `CIPPCore` copies)

- **Copies resynced.** The `CIPPCore` copy — the one the fork's `profile.ps1` actually loads —
  was stale and missing the entire `SentMessages` (message trace) block, so the Sent Messages
  data was never produced in production. Both copies are now identical.
- **Inbox rule changes** (upstream): a separate user-scoped `Search-UnifiedAuditLog` for
  `New-InboxRule` / `Set-InboxRule` / `Remove-InboxRule` / `UpdateInboxRules`, surfaced as
  `InboxRuleChanges`. Existing rules gain a `RecentlyChanged` flag when their name matches a
  7-day audit event.
- **Better failure logging** (upstream): rules/trace failures log through `Write-LogMessage`
  with normalized errors; the error entity now carries `ExtractedAt`.
- **Fork customization preserved:** the extra `MailboxLogin` / `UserLoggedIn` operations in the
  7-day tenant-wide audit search.
- **Manage365 addition — safelist backend.** Upstream's UI ships a "Trusted & Blocked Senders"
  check (Check 8) but **no upstream branch produces the fields** (`TrustedSenders`,
  `BlockedSenders`, `SafelistChanges`) — upstream's check renders empty today. We implemented
  the producer: `Get-MailboxJunkEmailConfiguration` for the current trusted/blocked lists and a
  user-scoped audit search for `Set-MailboxJunkEmailConfiguration` events (7 days) shaped as
  `{ Operation, UserKey, Date, Trusted, Blocked }` to match what the UI and PDF report render.
  Watch for upstream shipping their own producer later; theirs should supersede ours if shapes
  match.

### CIPP — Compromise Remediation UI

- **`bec.jsx`** — merged upstream's compact accordion layout into the fork's page: every check
  is now a collapsed accordion with a count chip (amber when findings exist), lists cap at 300px
  with scrolling, sent messages and trusted/blocked senders render as `CippDataTable` tables.
  New content: inbox rule changes sub-section in Check 1 with `RecentlyChanged` sorting/labels,
  Sent Messages (Check 5), Trusted & Blocked Senders (Check 8) with safelist change history.
  Checks renumbered to match upstream (MFA 6, Passwords 7).
  **Fork customizations preserved:** no-user-selected / user-not-found / loading-skeleton page
  states, header `userActions`, `CippTimeAgo` subtitle, responsive grid (`xs`/`md` sizes),
  theme-aware loading banner, memoized check card.
- **`BECRemediationReportButton.js`** — adopted upstream wholesale (fork's copy was an older
  upstream version with no customizations). The PDF report now covers inbox rule changes and
  trusted/blocked senders, and both feed the threat score.
- **`CippButtonCard.jsx`** — accordion header now stretches (`flexGrow: 1`) so check titles can
  right-align their chips, and the stray divider between a collapsed accordion summary and its
  details was removed (upstream change). Fork's hover-shadow interaction kept.

## Verification

- `yarn build` (Node 22): pass, no lint errors on the three touched frontend files.
- PowerShell parser on both `Push-BECRun.ps1` copies: 0 errors.
- `package.json` / `yarn.lock` intact after build (rm-removal holding).

## Deferred

- `c1fb0f92a`'s removal of per-item icons in favor of chips was taken; no part of the BEC family
  remains deferred.
