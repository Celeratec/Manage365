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

Sharded CI: `yarn test:unit --shard=N/4 --run`. Nav routes that redirect to a different URL need a matching `docsPath` in `config.jsx` so `help-links.test.js` resolves real files under `docs/user-documentation/`.

## Backend Pester

Full suite: `./backend/Tests/Invoke-CippTests.ps1 -CI` (GitHub Actions: **Backend Pester** on `backend/**` PR paths). Expect **~6k+ tests**; a red job is not automatically caused by the PR under review.

### Run subsets

```bash
cd backend
pwsh ./Tests/Invoke-CippTests.ps1 -Path Tests/Private/Test-CIPPMoveArchiveItemsRequest.Tests.ps1
pwsh ./Tests/Invoke-CippTests.ps1 -Path Tests/Baselines
pwsh ./Tests/Invoke-CippTests.ps1 -Path Tests/Extensions
pwsh ./Tests/Invoke-CippTests.ps1 -Path Tests/GraphHelper/Get-GraphToken.CertificateAuth.Tests.ps1
pwsh ./Tests/Invoke-CippTests.ps1 -Path Tests/Static/OffboardingOptionsSync.Tests.ps1
```

Archive move tests: `Tests/Private/*MoveArchive*`.

### Baselines (`Tests/Baselines/`)

After the **CIPPBaselines** module split, batch tests must dot-source under `Modules/CIPPBaselines/Public/` (Helpers, PrepareHooks, Executors) and load `Get-CIPPBaselineCommand.ps1` when prepare hooks call `Get-CIPPBaselineCacheRows`.

**Module boundary** (`Tests/Static/BaselinesModuleBoundary.Tests.ps1`): scans CIPPCore/CIPPHTTP for references to CIPPBaselines function names, excluding legacy shim copies under `Modules/CIPPCore/Public/Baselines/` (they still call baseline helper names until rewired). Long-term fix is removing those shims so HTTP workers never autoload CIPPBaselines.

### Extensions (`Tests/Extensions/`)

Integration tests stub Az table cmdlets the extension code calls directly (`Get-AzDataTableEntity` / `Add-AzDataTableEntity`), not only `Get-CIPPAzDataTableEntity`. Example: `Invoke-NinjaOneOrgMapping.Tests.ps1` (NinjaOne org mapping).

`Invoke-NinjaOneOrgMapping.Tests.ps1` asserts inline **name** matches plus orchestrator **batch** enqueue for device correlation (no `-NameOnly` switch on the function anymore).

Other extension files (Hudu sync, Halo PSA, schedulers) are similarly sensitive to table/mock shape—run `Tests/Extensions` when touching `Modules/CippExtensions/`.

### Certificate / Graph token (`Tests/GraphHelper/`, `Tests/Private/*SAMCertificate*`)

- **PFX load flags**: Linux uses `EphemeralKeySet`; macOS uses `Exportable` (Ephemeral is unsupported on macOS .NET); Windows uses `MachineKeySet` (`Get-CIPPSAMCertificate.ps1`, `Get-CIPPSAMCertificateVersions.ps1`).
- **`Get-GraphToken.CertificateAuth.Tests.ps1`**: pins certificate-exclusive auth and stale-cert self-heal; duplicate `Describe` blocks were removed—do not re-add.

### Wizard / static sync (`Tests/Static/`)

**Offboarding** (`OffboardingOptionsSync.Tests.ps1`): every action in `Test-CIPPOffboardingRequest.ps1` must appear in `Invoke-CIPPOffboardingJob.ps1`, the offboarding wizard (`CippWizardOffboarding.jsx`), and default editors. Adding a backend action requires the wizard field and `setValue(..., false)` when Delete User is selected.

### Interpreting PR CI

| If your PR touches… | Run locally before push |
| --- | --- |
| HTTP / OpenAPI | `build-openapi.ps1 -Check` |
| Frontend unit tests | `yarn test:unit --shard=1/4 --run` (or full four shards) |
| CIPPBaselines / baseline tests | `Invoke-CippTests.ps1 -Path Tests/Baselines` |
| Extensions | `Invoke-CippTests.ps1 -Path Tests/Extensions` |
| Offboarding | `OffboardingOptionsSync.Tests.ps1` + wizard JSX |
| Archive move | `Tests/Private/*MoveArchive*` |

Remaining red files on full-suite `main` (endpoint one-offs, PIM invariants, HTTP catch-block lint, reports, scheduler overlap, etc.) are tracked upstream; fix when you touch that area, not as drive-by on unrelated PRs.
