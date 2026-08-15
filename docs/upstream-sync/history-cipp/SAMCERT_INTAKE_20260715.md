# SAM Certificate Authentication Intake — 2026-07-15

Dedicated feature intake: ports the upstream **SAM certificate authentication**
family (8 commits from 2026-07-09 plus follow-up fixes) into Manage365. This is
the foundational auth change that unblocks the deferred SharePoint site
management suite and parts of the SSO family.

- API branch: `manage365/samcert-intake-20260715` (backup tag `backup/pre-samcert-intake-20260715`)
- Frontend: **no changes required** — upstream has no SAM-cert UI; the
  certificate is managed by the API (setup wizard, weekly timer, and
  `Invoke-ExecSAMCertificate` via ExecCippFunction).

## What this adds

Certificate-based app authentication alongside the existing client secret:

- **Provisioning:** `Get-CIPPAuthentication` now preloads the SAM certificate
  PFX from Key Vault (secret name `SAMCertificate`) and provisions one on first
  run (guarded to at most once per process to prevent recursion loops).
  `Invoke-ExecCreateSAMApp` also creates the certificate during initial setup.
- **Rotation:** `Start-UpdateTokensTimer` renews the certificate when close to
  expiry, alongside the existing secret rotation.
- **Usage:** `Get-GraphToken`, `New-GraphGetRequest`, `New-GraphPOSTRequest`,
  and `New-ExoRequest` accept an opt-in `-UseCertificate` switch. App-only uses
  `Get-GraphTokenFromCert`; delegated keeps the refresh token but authenticates
  the app with a signed JWT assertion (`New-CIPPCertificateAssertion`) instead
  of the client secret.
- **App management policy:** `Update-AppManagementPolicy` now also exempts the
  CIPP app from `asymmetricKeyLifetime` / `trustedCertificateAuthority`
  restrictions so the 1-year self-signed certificate can be attached.

**No existing call sites pass `-UseCertificate`** — the only upstream consumers
are the deferred SharePoint suite endpoints, so current auth behavior is
unchanged. The visible behavior change is one-time certificate provisioning on
authentication load (non-fatal on failure; retried weekly).

## Files ported (upstream tip, wholesale)

New:
- `Get-CIPPSAMCertificate`, `New-CIPPSAMCertificate`, `Set-CIPPSAMCertificate`,
  `Update-CIPPSAMCertificate`, `Update-CIPPSAMCertificateEnvCache`
- `GraphHelper/New-CIPPCertificateAssertion`
- `Get-CippKeyVaultName`, `Get-CippOffloadSuffix` (single source of truth for
  vault name; fixes the dashed-instance-name truncation bug)
- HTTP endpoint `Invoke-ExecSAMCertificate` (ROLE: `CIPP.AppSettings.ReadWrite`)

Updated:
- `Get-GraphToken`, `Get-GraphTokenFromCert` (now shared-token-cache aware —
  upstream's version is a superset of the fork's; verified the fork had no
  unique lines beyond superseded keyvault-name derivation)
- `New-GraphGetRequest` (also brings `-Stream` / `-SkipValueExtraction`
  pagination options), `New-GraphPOSTRequest`, `New-ExoRequest`
- `Get-CIPPAuthentication` (cert preload/provision + provision-loop fix
  `5ae417185`), `Get/Set/Remove-CippKeyVaultSecret` (use `Get-CippKeyVaultName`,
  skip KV 404 retries)
- `Start-UpdateTokensTimer`, `Update-AppManagementPolicy`,
  `Invoke-ExecCreateSAMApp`, `Invoke-ExecCippFunction`,
  `Get-CIPPSchedulerBlockedCommands` (cert functions blocked from scheduler)

Removed:
- Stale duplicate `Modules/CIPPCore/Private/Get-CIPPSchedulerBlockedCommands.ps1`
  (upstream keeps only the `Public/Tools` copy; fork copy had no unique entries)

## Not taken (same upstream commit range)

- `Set-CIPPDBCacheSharePointSharingLinks` streaming/OOM commits (`e7ed3a226`,
  `6c86428cc`, `82ac60ee9`) — that cache setter is part of the deferred
  SharePoint suite and does not exist in the fork.

## Deployment notes

- No SAM manifest / CPV changes required — the certificate is a credential on
  the existing app registration, not a new permission.
- The Function App's managed identity must retain Key Vault set/get rights
  (already required for secret rotation).
- On first run after deploy, expect an Info log "No SAM certificate found,
  provisioning one now" and a new `SAMCertificate` secret in Key Vault.

## Verification

- PowerShell parse check on all 23 changed/added files: clean.
- Dependency scan: all helpers referenced by the new functions
  (`Get-CIPPAzIdentityToken`, `Get-CippOffloadSuffix`, KV helpers, Graph
  helpers) present in fork; `Get-CIPPAzIdentityToken` verified byte-identical
  to upstream.
- `CIPPCore` exports via wildcard + recursive dot-sourcing, so new files are
  picked up automatically.
