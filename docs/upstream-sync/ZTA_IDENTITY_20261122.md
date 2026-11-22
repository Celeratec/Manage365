# ZTA 3.1.0 identity tests — 2026-11-22

Selective CIPP intake on `clint/upstream-zta-identity`. Fork-only; never PR CyberDrain/CIPP.

| SHA | Change | Status |
|-----|--------|--------|
| `ec5de65d8` | Align existing ZTNA tests with Zero Trust Assessment 3.1.0 | Applied with Adapt (`a1e4d8968`) |

## Adapt notes

- **ZTNA21824**: keep Batch1 `GuestsOrExternalUsers` includeUsers token + enabled-only Pass filter (do not count report-only).
- **ZTNA21803 / 21816 / 21818 / 21819 / 21835**: take upstream 3.1.0 grading, PIM notify, licence gates, emergency-access rewrite.
- **ZTNA21816.Tests**: stub `Test-CIPPStandardLicense` after new PIM licence gate.
- Restored suites: `ZTNAIdentityUpstreamSync.Tests.ps1`, `ZTNAIdentityPrivilegedSync.Tests.ps1`, `ZTNADeviceSync.Tests.ps1`, `ZTNA21818.Tests.ps1`.

## Deferred (related upstream, not this pack)

- `b6c172254` new ZTNA 3.1.0 assessments
- `02fb46317` remediation docs sync
- `bc7608a67` Global Admin group count (may already be partially present)

## Verify

- Pester: ZTNA21818, DeviceSync, IdentityPrivilegedSync, IdentityUpstreamSync, ZTNA21816 — green.
- Aikido: clean on scanned pack files.
- OpenAPI: unchanged (test-only).
- Baseline stays **11.2.1**.
