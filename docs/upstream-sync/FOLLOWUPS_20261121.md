# Upstream feature follow-ups — 2026-11-21

Queued after Batch 1 security/reliability intake on `clint/upstream-intake-20261121`.  
Each item should become its own `clint/upstream-*` branch and **draft** PR into `main`. Do not wholesale-merge `upstream/main` or `upstream/dev`. Never PR CyberDrain/CIPP.

| Pack | Suggested branch | Scope (from CIPP 11.3–11.4) | Notes |
|------|------------------|-----------------------------|-------|
| Intune clarity | `clint/upstream-intune-clarity` | Policy Failures, non-compliant devices, deployment/sync drawers, Autopilot unassign, enrollment restrictions | Pair FE/BE; Adapt card views |
| NHI / BEC | `clint/upstream-nhi-bec` | NHI compromise cases, BEC release / containment | High ops value |
| CA ops | `clint/upstream-ca-ops` | Duplicate CA, vacation end-now, named locations All Tenants, Compare Policies | |
| SPO guest / storage | `clint/upstream-spo-guest-storage` | Per-site guest expiry; storage report PDF | **Adapt** around recycle-bin suite |
| Exchange utils | `clint/upstream-exchange-utils` | Bulk shared/room/equipment, calendar bulk remove, timezone migrate, Exchange app roles + `0e8a6e145` | Includes deferred Batch 1 SHA |
| Auth hardening | `clint/upstream-auth-blockalltenants` | `BlockAllTenants`, restricted multi-tenant SSO, grant CIPP roles from Entra app roles | |
| Tenant group selector | `clint/upstream-tenant-group-selector` | Tenant Groups in Tenant Selector flag | Design vs existing tenant groups; flag default off |
| Container trust | `clint/upstream-container-attestation` | Sigstore attestation, digest pinning, trust labels | Ops review |
| ZTA 3.1.0 identity tests | `clint/upstream-zta-identity` | `ec5de65d8` ZTNA identity sync + matching Invoke-CippTestZTNA* updates; restore `ZTNAIdentityUpstreamSync.Tests.ps1` | Dropped from Batch 1 guest-coverage Adapt |

## Explicitly skipped (do not queue unless product asks)

- Hudu People/Devices/Magic Dash redesign; NinjaOne ticketing as primary PSA
- Multi-partner beta wholesale
- Baselines product expansion while Baselines flag is off
- Unreleased `upstream/dev` (pwsh 7.6, SecOps mailbox baseline, …)

## Baseline claim

**Done (6.1.37):** Intune + NHI + CA (and the rest of #81–#89) landed; `upstreamBaseline` bumped to **11.4.0** via `Tools/Update-Version.ps1` on `clint/upstream-baseline-11.4.0`.
