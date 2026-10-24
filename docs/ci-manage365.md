# Manage365 CI notes (Celeratec fork)

## OpenAPI drift

When you add or change HTTP entrypoints under `backend/Modules/CIPPHTTP` or supporting core functions referenced by the generator:

```bash
pwsh build/tools/build-openapi.ps1
git add backend/Config/openapi.json frontend/public/openapi.json
```

CI job **OpenAPI Spec → Validate and check for drift** runs on pull requests and fails if the committed file is stale. Do not rely on a follow-up commit after merge.

Scheduled workflow **Manage365 Update OpenAPI Spec** (`.github/workflows/manage365-update-openapi-spec.yml`) can open a drift-fix PR against `main` on the fork.

Upstream CyberDrain uses a separate workflow (`update-openapi-spec.yml`) against `dev`; it does not run on this fork.

## Frontend Vitest / Storybook

Keep all `@storybook/*` packages on the **same version** as the `storybook` package (see `frontend/package.json`). A mismatch (for example `@storybook/react-vite` behind `storybook`) breaks Vitest startup with `reportToolsetTelemetry` import errors.

After the Storybook alignment fix, Vitest runs cleanly but **individual component tests may still fail** on `main` (same pattern as Manage365 6.1.24). Treat red Vitest shards as unrelated unless the PR touches those files. Sharded CI: `yarn test:unit --shard=N/4 --run`.

## Backend Pester

Full-suite failures on CI are not always caused by the PR under review. Common unrelated buckets:

- Baseline tests that dot-source moved modules under `Modules/CIPPBaselines/Public/` (Helpers, PrepareHooks, Executors)
- Extension / NinjaOne container setup
- Certificate token retry tests

For a focused change, run:

```bash
cd backend
pwsh -Command "Invoke-Pester -Path Tests/Private/Test-CIPPMoveArchiveItemsRequest.Tests.ps1 -Output Detailed"
```

Archive move tests live under `Tests/Private/*MoveArchive*`.
