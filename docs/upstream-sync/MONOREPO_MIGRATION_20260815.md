# Monorepo Migration — 2026-08-15

Migration of Manage365 customizations (branding + features) from the two-repo forks
(`Celeratec/CIPP` @ v5.33.0 / upstream 10.8.5, `Celeratec/CIPP-API` @ upstream 10.8.5)
into this monorepo (base: CyberDrain CIPP monorepo v10.8.5, Craft container runtime).

- **Branch:** `manage365/monorepo-migration-20260815`
- **Base:** `main` @ `04e249350` (docs: document Manage365 5.33.0 / upstream 10.8.5 in README)
- **Upstream remote:** `upstream` → CyberDrain/CIPP (monorepo), fetched 2026-08-15
- **Source repos:** `~/Documents/GitHub/CIPP` (frontend fork), `~/Documents/GitHub/CIPP-API` (backend fork)

## Porting rules used

1. Net-new backend endpoints land in `backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/`
   with `.FUNCTIONALITY Entrypoint` + `.ROLE` help comments.
2. Net-new activity workers (`Push-*`) land in `backend/Modules/CIPPActivityTriggers/`.
3. Queue/orchestration wiring goes through the Craft bridges (`Add-CippQueueMessage`,
   `Start-CIPPOrchestrator`) — no `Push-OutputBinding`, no Durable client calls, no
   processor-slot offload.
4. Frontend pages/components port path-for-path into `frontend/src/`.
5. Auth-sensitive code must tolerate the EasyAuth `/.auth/me` array shape (upstream
   `PrivateRoute` already does; ported code must not regress it).
6. Where the fork was *behind* upstream (SSO, CIPP users, container management,
   branding-settings backend, `Initialize-CIPPAuth`), the upstream monorepo version wins.
7. Dropped as obsolete: `staticwebapp.config.json`, SWA deploy workflow, function-app slot
   workflows (`master_cippbefno*`), `Start-CIPPProcessorQueue` processor-slot model,
   `Set-CippApiAuth` EasyAuth/ARM hacks, `profile.ps1` / `host.json` mods, vendored
   `MicrosoftTeams/7.4.0` module (pending Teams V2 decision).

## Phase status

| Phase | Status | Notes |
|-------|--------|-------|
| 0 — Foundation | done | upstream remote added; sync tooling/docs ported; local container stack validated (Craft :5196, Azurite, dev auth, core pages 200) |
| 1 — Branding & identity | done | cerulean theme, logos/manifest/titles, dual versioning 6.0.0 / upstream 10.8.5 (`5d9f17d5`) |
| 2 — Feature verticals (all A–I) | done | all verticals landed in one pass — see tranche log (`0801ea60` backend, `08ff84fe` frontend) |
| 3 — Cross-cutting UI | done | fork had already rebased card views onto upstream's virtualized `CippDataTable` at the 10.8.5 sync, so the sweep carried them; organized nav merged with monorepo-only entries |
| 4 — Hooked logic | done | BEC/Ninja/quarantine match fork tip; `Test-CIPPAccess`, `Set-CIPPUser`, `Invoke-ExecMcp` kept as monorepo versions, which contain the fork semantics (fail-closed roles, scheduled edits, MCPAllowed) plus newer hardening |
| 5 — Cutover | runbook ready | see `CUTOVER_RUNBOOK_20260815.md`; staging deploy, production migration (`deployment/Invoke-CippMigration.ps1`), and fork-repo archiving are operational steps to run at cutover time — do **not** archive the forks while production still runs on them |

## Tranche log

- 2026-08-15 `1bad0c7b` — Phase 0: sync process/tooling/history ported to monorepo.
- 2026-08-15 `5d9f17d5` — Phase 1: Manage365 identity (logos, icons, theme, titles, dual versioning).
- 2026-08-15 `0801ea60` — Phase 2/4 backend: 691-file modified sweep + 128 fork-only endpoints/helpers/standards, Sherweb removal, config merges (standards 207 entries, SAMManifest +10 perms/+3 resource apps, IntegrationTemplates), Craft adaptations, Pester tests. All PowerShell parses clean.
- 2026-08-15 `08ff84fe` — Phase 2/3 frontend: 418-file modified sweep + 93 fork-only pages/components, 98 deletions (dead template sections, Sherweb pages), nav merge, standards.json synced with backend. Kept monorepo versions of auth flow, onboarding wizard, super-admin pages, and the refactored PDF/report suite (fork's report buttons predate upstream's `CippPdf` primitives). Build green: 406 static pages, no import warnings; new routes smoke-tested 200 on the local stack.
