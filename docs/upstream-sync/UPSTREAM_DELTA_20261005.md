# Upstream Delta — Manage365 — 2026-10-05

Cycle: **Major** — CyberDrain CIPP **10.8.5 → 11.0.2**, applied on the monorepo only. Production `Celeratec/CIPP` and `Celeratec/CIPP-API` are unchanged.

| | SHA / version |
|--|--|
| Sync base | `e8bfee212` (Manage365 `main`, upstream baseline **10.8.5**) |
| Backup tag | `backup/pre-upstream-sync-manage365-20261005` |
| Sync branch | `manage365/upstream-sync-20261005` |
| Step 1 | `v10.9.1` (`8bf90d4a6`) |
| Step 2 | `v10.10.3` |
| Step 3 | `v11.0.2` (`220099ead`) |

## v10.9.1 triage

315 commits. 114 conflicts. Outcomes:

| Area | Outcome | Notes |
|------|---------|-------|
| CyberDrain-only workflows (`CodeQL_Analyser`, issue comment/label) | **Skip** | Kept deleted by the fork CI commit |
| Hosted add-subscription page | **Skip** | Still deleted |
| Sherweb licence-report nav item | **Skip** | Page was removed in the August port; the path does not exist. Gated Sherweb fields on Add User stay, because they only render when the integration is enabled |
| Quarantine list, management, all-tenant sync, quarantine page | **Adapt** | Kept the Manage365 EXO portal (filters, export, bulk actions, deterministic row keys) |
| Version card, release notes, product title | **Adapt** | Manage365 version source and title kept. Took upstream release-note picker and mobile footer |
| `standards.json` (backend and frontend) | **Adapt** | Union of names. Kept Manage365 TAP help text. Took "Microsoft managed" and the device-preparation label |
| Navigation (`config.js`, top nav, side nav) | **Adapt** | Union of both menus. Baselines stay feature-flag gated and off |
| Group add | **Adapt** | Upstream directory-id resolver, plus already-a-member counted as success |
| Guest users | **Adapt** | Upstream list contract, plus `lastSignIn`, `isStale`, `neverSignedIn` and summary cards |
| Domain analyser cache, text replacement, Intune policy, custom roles, Halo, community repo | **Apply** | Upstream side of the conflict was the fix |
| Report list pages | **Adapt** | Shared report-database sync. Manage365 card views, drawers, and custom actions kept |
| CippDataTable, toolbar, user actions, offboarding wizard | **Adapt** | Both card/action behavior and upstream mobile, filter, and new actions |

## Still open in this cycle

- v10.10.3 and v11.0.2 are not merged yet.
- 24 Aug identity/BEC hotfix (`47c750c25`, `40dcaed53`) is ported after the ladder if upstream did not supersede it.
- Baselines feature flag stays off so existing standards keep running.
