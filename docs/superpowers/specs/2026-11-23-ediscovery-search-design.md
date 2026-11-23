# Design: Purview eDiscovery content search (stats-first)

**Date:** 2026-11-23
**Branch:** `clint/ediscovery-search-design`
**Originating client ticket:** Freshdesk #3276171 (attorney litigation-hold search; client work only)
**Build ticket:** Dedicated internal ticket to be opened (not #3276171); required for ticket-gated writes once known
**Status:** Design approved by Clint (2026-11-23). Approach 1 (AzureArm twin). Ship through PR2 with `EdiscoverySearch` enabled in production after merge/image cutover.

## Decisions (section 7)

| # | Question | Decision |
|---|----------|----------|
| — | Delivery | Design → implement through PR2 (stats-only) → prod image with flag **on** |
| — | Identity | **A** Dedicated per-tenant app + certificate (Graph app-only). Not CIPP SAM |
| 5 | Hold removal / case delete | **Out of Manage365 entirely** (always refuse; portal-only) |
| 4 | `approvalReference` (hold-add / export later) | Free-text must match `CLINT-APPROVED:<ticket>` (e.g. `CLINT-APPROVED:3276171`) |
| 8 | Build ticket | Open dedicated internal ticket for Manage365 build; keep #3276171 for client matter |
| 9 | Clients | Reusable for **all** managed tenants (product surface from day one) |
| — | Existing Cases UI | Manage365-only (not upstream CIPP). Same workstream: flag + dedicated identity; dangerous actions refuse |
| 7 | Delegated fallback | Runbook only (manual Purview). No delegated product path |
| 1 | Per-term hit counts | Spike: prefer in-memory keyword-report parse **if** counts-only and no item content; else one estimate per term. Document overlap if (b) |
| 2 | Archive | Default mailbox `userSource` only. Spike: confirm whether `mailbox` includes in-place archive |
| 3 | Premium / app-only | Spike: how premium case is enabled; E3 + pay-as-you-go requirements. Readiness reports remediation |
| 6 | KQL dates / terms | Build KQL in code from validated term array + date bounds. Spike confirms `sent` / `received` / `date`. No free-form query from caller |

## Context

- Manage365 already has Cases UI and `Invoke-*Ediscovery*` HTTP functions (ported Manage365 custom code; **absent from upstream CIPP**).
- `GraphEndpointBlocklist.json` blocks `ediscoveryCases` / `ediscovery` on the normal SAM Graph path (export URLs / content risk). That blocklist stays for SAM/`New-GraphGetRequest`.
- Classic ComplianceSearch cmdlets are legacy; Graph eDiscovery with application permissions is the supported automation path. GDAP Compliance Admin is not Purview eDiscovery Manager.
- Do **not** add `eDiscovery.*` to the CIPP SAM app. Dedicated per-tenant app only.

## Architecture

Mirror AzureArm as an isolated stack:

- **Feature flag:** `EdiscoverySearch` in `backend/Config/FeatureFlags.json`. Ships **Enabled: true** (Clint choice C). Endpoints still fail closed without per-tenant config + Purview SP/role.
- **Config table:** `EdiscoveryConfig` — `PartitionKey = tenantFilter`, `RowKey = config`. Stores **appId** + **Key Vault certificate name** only. Never PFX, private key, or secret value in table, logs, PRs, or responses.
- **Config APIs:** `ExecEdiscoveryConfig` (ticket + `dryRun` default true), `ListEdiscoveryConfig` (sanitized).
- **Token:** `Get-CIPPEdiscoveryAccessToken -TenantFilter` — client credentials into the customer tenant with that app/cert. **Refuse if appId equals CIPP SAM.** Graph scopes as needed (`eDiscovery.Read.All` / `eDiscovery.ReadWrite.All`).
- **Request layer:** `Invoke-CIPPEdiscoveryRequest` — host allowlist `graph.microsoft.com` only; paths from templates; bounded polling for estimate operations; never log tokens or report `downloadUrl`s.
- **Allowlist:** `backend/Config/GuardedWrites/EdiscoveryAllowlist.json` — exact Graph paths for case/search/custodian/source/estimate and required GETs. Purge, hold-remove, and case-delete are **absent** and hard-refused in code (400, no network call).
- **Guards:** Reuse `Test-CIPPGuardedWriteRequest`, `Add-CIPPGuardedWriteAudit`; extend `ConvertTo-CIPPGuardedWriteRedacted` for counts-only fields.
- **Existing Cases endpoints:** Behind `EdiscoverySearch`; use dedicated token + allowlist. Create/update/list/search allowed when configured. **Always refuse:** case delete, hold remove, purge, export content download. Hold-add and export writes deferred to later PRs with `approvalReference`.
- **SAM blocklist:** Unchanged for shared Graph helpers. Only `Invoke-CIPPEdiscoveryRequest` may call eDiscovery URLs.

### Permission blast radius (say plainly)

Graph `eDiscovery.*` cannot be limited to one mailbox or case. An SP in `eDiscoveryManager` can search any mailbox in that tenant. Mitigations: per-tenant app; grant on demand / remove after the matter; short-lived cert; workload-identity CA if the client has it; full audit on every write.

## Stats workflow (PR2)

**Endpoint:** `ExecEdiscoverySearch` (guarded write even though “stats only” — creates case/search in client Purview).

**Input (validated):**

- `tenantFilter`, `ticketNumber` (6–8 digits), `reason`
- `dryRun` **default true**
- `custodianUpn` (exactly one in v1)
- `terms[]` (max 25)
- optional `dateFrom` / `dateTo` (max span e.g. 5 years)
- optional `caseLabel` (short; never client name)
- mailbox only; OneDrive/`site` excluded unless a later explicit option

**Dry run:** Return plan only — proposed `displayName` (`<ticket> - <label>`), `externalId` = ticket, custodian, KQL, estimate options. Status `DryRun`. No Graph writes.

**Live (`dryRun: false`):**

1. Reuse a case this app created with matching `externalId`, else create (`displayName`, `description`, `externalId`).
2. Add custodian + mailbox `userSource`.
3. Create search with server-built KQL (validated terms + date bounds).
4. `POST .../estimateStatistics` with `statisticsOptions` = `includeQueryStats, includeUnindexedStats`; poll operation with timeout.
5. Response **counts only:** indexed/unindexed item counts and sizes, `mailboxCount`, per-term counts (spike method). Strip/reject subjects, senders, snippets, filenames, download URLs.
6. Audit: ticket, actor, case/search IDs, term **count**, KQL **hash** (raw terms only in Purview case + ticket — not in logs).

**Limits:** one custodian per request; one in-flight estimate per tenant; term/date caps; refuse purge / hold-remove / case-delete always.

**MCP:** List/get/status reads only (`.Read` roles). Stats create path is not an MCP write surface in v1.

## Readiness and runbook

**`ListEdiscoveryReadiness` (read-only):** Config present? Cert name resolvable? Token acquires? Harmless `GET /security/cases/ediscoveryCases` → 200 vs 403? Premium / pay-as-you-go remediation when detectable. Structured steps: admin consent, `New-ServicePrincipal`, add SP to `eDiscoveryManager` (least privileged; do not treat Administrator as interchangeable without spike confirmation).

**Runbook:** Human one-time setup per tenant; Clint confirms attorney written authorization is on the ticket before any live run; if config missing, run stats manually in Purview (no product delegated path).

**Setup banner (existing Cases UI):** Point at readiness + dedicated app — not “add CIPP SAM as eDiscovery Administrator.”

## Later actions (not first release)

| Action | Gate |
|--------|------|
| Hold add | Own action + `approvalReference` = `CLINT-APPROVED:<ticket>` |
| Export | Own action + same approval; design gate only in v1 (no content download in Manage365) |
| Hold remove | **Never** in Manage365 |
| Case delete | **Never** in Manage365 |
| Purge (`purgeData` / ComplianceSearch -Purge) | **Never**; test proves 400 and no network |

## PR phasing (draft PRs)

1. **PR0 (this):** Design doc + spike plan. Docs only.
2. **PR1:** `EdiscoveryConfig` + readiness + flag (`Enabled: true`) + migrate existing Cases endpoints onto dedicated token; refuse dangerous actions; docs/runbook.
3. **PR2:** `ExecEdiscoverySearch` stats-only (dryRun default true, counts-only, limits, Pester).
4. **PR3:** MCP-safe `ListEdiscovery*` reads (`.Read` only).
5. **Later:** Hold-add / export with approval gate (separate PRs).

Each feature PR: `docs/api-documentation/` page, runbook note, App Security review of identity model. Lint, type check, tests. Synthetic fixtures only (`contoso.onmicrosoft.com`, fake GUIDs, `custodian@contoso.example`, case `Example Matter 2026-001`, terms like `"project falcon"`). No client names, tenant IDs, mailboxes, or ticket body text in code/tests/docs/commits/PR text beyond the public ticket **numbers** above.

## Spike plan (throwaway / test tenant only — never a client tenant)

Record results in a follow-up note under `docs/` (still no client data):

1. Create throwaway app; grant `eDiscovery.ReadWrite.All`; admin consent.
2. `New-ServicePrincipal`; add to `eDiscoveryManager`; optionally reconcile `Add-eDiscoveryCaseAdmin` vs Manager-only guidance.
3. Create case; enable premium features as required for app-only; note whether this is tenant-level (E5 / pay-as-you-go) vs case body fields.
4. Add synthetic custodian with archive-only items; run estimate; record whether archive counts under `mailbox`.
5. Estimate with `includeQueryStats`; download keyword report **once** offline; record format; confirm whether any item content/subjects appear. If content present → reject parse option; use per-term estimates.
6. Confirm KQL property names for date bounds (`sent` / `received` / `date`).
7. Confirm E3 + pay-as-you-go app-only behavior if available on the test tenant.

## Acceptance checklist

- [ ] Design answers every section 7 row (spike items marked).
- [ ] Spike plan lists exact calls and what to record; no client data.
- [ ] Missing/bad `ticketNumber` or missing `reason` → refuse.
- [ ] `dryRun` defaults true; dry run performs no write network calls.
- [ ] Hold-remove, case-delete, purge always refused; hold-add/export need `CLINT-APPROVED:<ticket>` when built.
- [ ] Responses, audit, logs: counts only (content-like fixtures never leak).
- [ ] Flag gates every endpoint; MCP `.Read` only for list/get.
- [ ] No SAM reuse; no private key/PFX accepted; tests prove refusal.
- [ ] Limits enforced and tested.
- [ ] Lint, type check, tests pass; no client PII in diff.
- [ ] Prod enable: flag on after Clint OK (already decided); first live tenant still needs config + Purview role + ticket authorization.

## Out of scope (v1)

- Free-form KQL from callers
- Multi-custodian / bulk stats
- OneDrive/site sources by default
- Export package download into Manage365
- Hold remove, case delete, purge
- Adding `eDiscovery.*` to CIPP SAM
- Client or production tenant spike work
- Opening the internal build ticket (Clint / Ticket Ops)

## Rollback

- Disable `EdiscoverySearch` (or set Enabled false and redeploy) to gate endpoints.
- Remove per-tenant `EdiscoveryConfig` row and/or Purview role membership to revoke search ability for that tenant.
- Image rollback to previous Manage365 tag if a bad release ships.
