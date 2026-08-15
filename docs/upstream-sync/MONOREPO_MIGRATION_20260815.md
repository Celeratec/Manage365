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
| 0 — Foundation | in progress | upstream remote added; sync tooling/docs ported; local container smoke pending |
| 1 — Branding & identity | pending | |
| 2 — Feature verticals (all A–I selected) | pending | Order: E, F, H, B, G, D, C, A, I |
| 3 — Cross-cutting UI | pending | |
| 4 — Hooked logic | pending | |
| 5 — Cutover | pending | production migration is a separate operational step |

## Tranche log

(filled in as tranches land)
