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

`ExecEdiscoverySearch` runs the stats-first workflow: create or reuse a case by ticket number, add one custodian mailbox source, create one estimate search per term, and return counts only. Terms are OR-style keyword-list terms in the generated KQL; per-term estimates may overlap. Until the test-tenant spike proves richer keyword reports are safe, this endpoint does not return message subjects, snippets, bodies, filenames, download URLs, item content, or export material.

## Config synthetic example

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

## ExecEdiscoverySearch request

All values below are synthetic. `dryRun` defaults to `true`; send `false` only after readiness is `Ready` and the operator has approval on the ticket.

```json
{
  "tenantFilter": "contoso.onmicrosoft.com",
  "ticketNumber": "1234567",
  "reason": "Example Matter 2026-001 stats estimate",
  "dryRun": true,
  "caseLabel": "Example Matter 2026-001",
  "custodianUpn": "custodian@contoso.example",
  "terms": ["project falcon", "quarterly planning"],
  "dateFrom": "2026-01-01",
  "dateTo": "2026-03-31"
}
```

### Dry-run response

```json
{
  "Status": "DryRun",
  "AuditId": "audit-1234567",
  "Before": null,
  "After": {
    "DisplayName": "1234567 - Example Matter 2026-001",
    "ExternalId": "1234567",
    "CustodianUpn": "custodian@contoso.example",
    "TermCount": 2,
    "KqlHash": "1111111111111111111111111111111111111111111111111111111111111111",
    "Terms": ["project falcon", "quarterly planning"],
    "Limits": {
      "MaxTerms": 25,
      "MaxDateSpanDays": 1825,
      "MaxCustodians": 1,
      "MailboxOnly": true,
      "StatisticsOptions": "includeQueryStats,includeUnindexedStats"
    }
  },
  "Rollback": "No Graph changes were made.",
  "Results": {
    "Note": "DryRun only. Live execution creates/reuses a case, custodian mailbox source, and one estimate per term. Per-term counts may overlap."
  }
}
```

### Live counts-only response

```json
{
  "Status": "Success",
  "AuditId": "audit-1234567",
  "Before": null,
  "After": {
    "DisplayName": "1234567 - Example Matter 2026-001",
    "ExternalId": "1234567",
    "CustodianUpn": "custodian@contoso.example",
    "TermCount": 2,
    "KqlHash": "1111111111111111111111111111111111111111111111111111111111111111",
    "Terms": ["project falcon", "quarterly planning"]
  },
  "Rollback": "No destructive Graph action was performed. Remove the search/case manually in Purview if policy allows.",
  "Results": {
    "indexedItemCount": 42,
    "indexedItemsSize": 1048576,
    "mailboxCount": 1,
    "unindexedItemCount": 0,
    "perTerm": [
      {
        "term": "project falcon",
        "itemCount": 40,
        "size": 1000000
      },
      {
        "term": "quarterly planning",
        "itemCount": 2,
        "size": 48576
      }
    ],
    "Note": "Per-term counts are estimated independently and may overlap."
  }
}
```

### Bad request response

Validation failures return `400` with a counts-only failure envelope.

```json
{
  "Status": "Failed",
  "Results": "Failed to run eDiscovery stats search: terms must contain 1 to 25 items."
}
```
