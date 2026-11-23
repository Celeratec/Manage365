# Purview eDiscovery Search

Manage365 eDiscovery uses a dedicated per-tenant Microsoft Graph app for Purview eDiscovery. It must not use the CIPP SAM app identity.

## Identity model

Each tenant stores eDiscovery config in `EdiscoveryConfig`: app ID, certificate Key Vault secret name, optional certificate password secret name, enabled flag, and notes. Only Key Vault names are accepted. PFX, private keys, client secrets, and certificate material are refused in API bodies.

The dedicated app should be consented only for the Graph eDiscovery permissions needed by Purview, then added in Purview to the `eDiscovery Manager` role group. Use the least-privileged dedicated app for each tenant; do not reuse the CIPP SAM app or CPV refresh path for eDiscovery.

## Setup runbook

1. Create a tenant-dedicated app registration and certificate.
2. Store the certificate as a Key Vault secret and record the secret name only.
3. Consent the Graph eDiscovery permissions required for Purview eDiscovery.
4. Add the app service principal to Purview `eDiscovery Manager`.
5. Run `ExecEdiscoveryConfig` with `dryRun:true`, then `dryRun:false` after review.
6. Run `ListEdiscoveryReadiness` and fix remediation until `Status` is `Ready`.
7. Use Cases endpoints only after readiness is green.

## Feature flag and endpoints

The `EdiscoverySearch` feature flag ships enabled and covers config, readiness, Cases, and stats-only search endpoints:

- `ListEdiscoveryConfig`, `ExecEdiscoveryConfig`, `ListEdiscoveryReadiness`
- `ListEdiscoveryCases`, `ExecEdiscoveryCase`
- `ListEdiscoveryCaseSearches`, `ExecEdiscoveryCaseSearch`
- `ListEdiscoveryCaseHolds`, `ExecEdiscoveryCaseHold`
- `ListEdiscoveryCaseOperations`, `ExecEdiscoveryCaseExport`
- `ExecEdiscoverySearch`

Writes use the guarded write envelope from [Guarded tenant writes](guarded-writes.md): `tenantFilter`, `ticketNumber`, `reason`, and `dryRun`. For eDiscovery writes, `dryRun` defaults to true and `reason` is required.

## Hard refusals

Manage365 v1 always refuses these actions with `400` before any Graph transport call:

- Case delete
- Search delete
- Search purge or `purgeData`
- Hold remove or delete
- eDiscovery export creation
- Export content downloads or download URLs

The Operations list does not return export download URLs. Export content is intentionally unavailable in Manage365 v1.

## Counts-only guidance

PR1 migrates existing Cases endpoints to the dedicated token, allowlist, guarded writes, and hard refusals. PR2 adds the stats-first `ExecEdiscoverySearch` workflow. Until then, use Cases search estimates only for counts/status. Do not log or return subjects, snippets, message bodies, filenames, download URLs, or item content.

## Synthetic example

```json
{
  "tenantFilter": "contoso.onmicrosoft.com",
  "ticketNumber": "1234567",
  "reason": "Example Matter 2026-001 readiness setup",
  "dryRun": true,
  "appId": "11111111-1111-1111-1111-111111111111",
  "certificateSecretName": "ediscovery-contoso-cert"
}
```
