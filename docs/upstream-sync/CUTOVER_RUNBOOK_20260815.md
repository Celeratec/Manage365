# Manage365 Monorepo Cutover Runbook

Migrating production from the two-repo deployment (Azure Static Web App + Function App
slots) to the single Manage365 container. Companion to
[MONOREPO_MIGRATION_20260815.md](./MONOREPO_MIGRATION_20260815.md).

## Prerequisites

- [ ] This repo's migration branch merged to `main`; frontend builds (`yarn build`) and
      backend Pester tests pass.
- [ ] A Manage365 container image published to a registry you control (GHCR under
      Celeratec or an ACR). Build from repo root:

  ```bash
  docker build -f build/Dockerfile \
    --build-arg APP_VERSION=10.8.5 \
    --build-arg COMMIT_SHA=$(git rev-parse --short HEAD) \
    --build-arg IMAGE_TAG=v6.0.0 \
    --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    -t ghcr.io/celeratec/manage365:v6.0.0 .
  docker push ghcr.io/celeratec/manage365:v6.0.0
  ```

  `APP_VERSION` must be the upstream baseline (drives out-of-date checks);
  the Manage365 release is read from `manage365-version.json` inside the image.

## Stage 1 — Staging validation

1. Deploy a FRESH staging instance (new resource group, new storage account) with
   `deployment/cipp-deploy.json` (or the Bicep), overriding the container image with the
   Manage365 image. **Never point the container at production storage while the function
   apps are live — both would consume queues and timers.**
2. Run SAM setup against a test tenant set; verify the setup gate completes.
3. Smoke checklist (per feature vertical):
   - [ ] Dashboard v2, top-nav search, tenant switcher
   - [ ] Identity: users list (card view on mobile), user detail cards, guest users
   - [ ] SharePoint dashboard, file browser/search/transfer, recycle bin, image optimizer
   - [ ] OneDrive sharing report, temp-file cleanup wizard
   - [ ] Quarantine portal (filters, bulk release), email troubleshooter
   - [ ] Teams settings/detail, Business Voice pages (needs Teams module decision — see
         migration doc)
   - [ ] Cross-tenant access: partners, policy, templates, health; external collaboration
   - [ ] Dynamics 365 environments/users/roles; eDiscovery cases/holds/searches/exports
   - [ ] Integration templates list/deploy (NinjaOne enrichment if configured)
   - [ ] Applied standards + drift + license-aware scoring
   - [ ] Alerts/audit logs; scheduler tasks run (watch `CIPPTimers` + queue processing)
   - [ ] Application Settings shows Manage365 v6.0.0 + upstream 10.8.5, no false
         out-of-date toasts
4. Soak for several days; watch container memory/CPU and the Craft worker stats page.

## Stage 2 — Production migration

1. Freeze fork deploys; announce downtime window.
2. Dry run: `deployment/Invoke-CippMigration.ps1 -ResourceGroupName <prod RG> -TestOnly`.
3. Execute:

   ```powershell
   ./deployment/Invoke-CippMigration.ps1 `
     -ResourceGroupName <prod RG> `
     -CippUrl manage365.<domain> `
     -ContainerImage 'DOCKER|ghcr.io/celeratec/manage365:v6.0.0'
   ```

   The script preserves SAM credentials + API client auth, migrates SWA role assignments
   into the `allowedUsers` table, deletes the SWA, and removes ALL function apps/plans/App
   Insights in the RG (main, processor, standards, audit, user-tasks slots included).
4. Point DNS per the script's summary; verify EasyAuth sign-in and role mapping for each
   admin user.
5. Re-run the Stage 1 smoke checklist against production data (read-only checks first).

## Stage 3 — Close out

- [ ] Archive `Celeratec/CIPP` and `Celeratec/CIPP-API` (read-only; history preserved).
- [ ] Update DNS/docs/bookmarks; decommission the SWA GitHub deploy workflows.
- [ ] Record the migration in the memory palace diary.
- [ ] First monorepo-era upstream sync cycle: `./Tools/Start-UpstreamSyncCycle.ps1`.

## Rollback

Until Stage 2 step 3 completes, rollback = do nothing (production untouched). After the
migration script has run, rollback requires redeploying the SWA + function apps from the
archived fork repos against the same storage account (the script does not delete storage)
— stop the container app first so queues/timers are not double-consumed.
