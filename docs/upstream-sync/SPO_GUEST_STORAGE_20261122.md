# SPO guest / storage — 2026-11-22

Selective CIPP intake on `clint/upstream-spo-guest-storage`. Fork-only; never PR CyberDrain/CIPP.  
**Adapt** around the recycle-bin suite (`sharepoint2`, `ListSiteRecycleBin`) — do not replace it.

| SHA | Change |
|-----|--------|
| `c778d0e82` | Per-site guest expiration, extend and remove from site (`ExecSPOGuestAccess`, external-users UI) |
| `e8e22f6fb` | Storage report PDF, Libraries tab, per-library version policies |
| `0b3287ef5` | Storage report figures / wording / version-history estimate fix |
| `ba4cc07dd` (partial) | Recycle-bin `$skip` paging in storage cleanup scan only (summary endpoint left to recycle suite) |

## Adapt

- `external-users.jsx`: keep Manage365 `category: 'danger'` on remove-all; take upstream clearer All Sites + Entra label.
- Storage report stays at `frontend/src/pages/teams-share/storage-report/` (fork path); do not move under `reports/` (`4dd9c80a9` deferred).
- Import depth `../../../` for that page; `StorageReportButton` wired into existing recycle/cleanup UI.
- Report trees land under `backend/Modules/CIPPCore/Public/Tools/Reporting/` (fork layout).
- Preview branding: add `storage` sample type; skip upstream `domain` report type (not on fork).
- Restored PDF branding-preset / cleanup-scan batch tests that upstream still ships.

## Skip this PR

- `4dd9c80a9` move storage report under Teams & SharePoint reports nav (path churn vs recycle Adapt)
- Broader SPO REST / Assert-CIPPSharePointHost Batch 1 leftovers unless needed
- Exchange app mailbox-access UI (`8a2cd9041`) — Exchange utils pack

## Notes

- Regenerate `openapi.json` after HTTP entrypoints land.
- Baseline stays **11.2.1** until Intune + NHI + CA packs merge (or Clint bumps earlier).

## Status

Cherry-picks + Adapt done. OpenAPI regenerated (881 endpoints). Focused Pester + Storage branding vitest green. Aikido clean on entrypoints/FE.
