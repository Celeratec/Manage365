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

## v10.10.3 triage

Merged onto the v10.9.1 result. Conflicts were files both sides changed after 10.9.1 (MUI 9 renames to `.jsx`, Graph message trace, JIT/PIM, GDAP templates).

| Area | Outcome | Notes |
|------|---------|-------|
| CyberDrain workflows, dashboard v1, add-subscription, Sherweb licence report and migration | **Skip** | Kept deleted |
| Quarantine page | **Adapt** | Manage365 EXO portal kept |
| Standards catalog and standards/drift pages | **Adapt** | Union. Baselines flag left off. Standards pages stay available |
| Navigation and version card | **Adapt** | Union of menus. Manage365 version card kept |
| Message trace, JIT/PIM, GDAP templates, report pagination | **Apply** | Upstream behavior, with Manage365 card views and action categories kept |
| Retired `.js` pages (`404`, roles, message trace, bulk add, GDAP roles, icon registry) | **Apply** | Removed where a `.jsx` page or redirect already covers the route |
| Cutover script | **Apply** | Upstream script is in-tree. Runbook updated: live run deletes file shares; storage account, tables, blobs, queues, and Key Vault stay. Script was not executed |

## Still open in this cycle

- v10.10.3 and v11.0.2 are not merged yet.
- 24 Aug identity/BEC hotfix (`47c750c25`, `40dcaed53`) is ported after the ladder if upstream did not supersede it.
- Baselines feature flag stays off so existing standards keep running.
