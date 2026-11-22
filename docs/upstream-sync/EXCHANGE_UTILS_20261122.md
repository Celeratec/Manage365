# Exchange utils — 2026-11-22

Selective CIPP intake on `clint/upstream-exchange-utils`. Fork-only; never PR CyberDrain/CIPP.

| SHA | Change | Plan |
|-----|--------|------|
| `e8a1eecf3` | Bulk add drawers: shared / room / equipment (+ `CippBulkDrawer`) | **Applied** — Adapt: keep HVE drawer; wire `CippBulkContactDrawer` on contacts page |
| `445e695f3` | Migrate mailbox calendars to a new time zone | **Applied** |
| `460245742` | Bulk remove on Calendar Permissions Report | **Defer** — heavy conflict with fork calendar permission / AclUserName Adapt; revisit after #82 or dedicated Adapt PR |
| `8a2cd9041` | Exchange app mailbox-access UI (roles/policies/scopes) | **Defer** until NHI/BEC #82 merges (needs Exo exposure/cache from `bdeeef2e0`) |
| `0e8a6e145` | Hide default Exchange delegating app roles | **Defer** with `8a2cd9041` (touches exposure already in #82) |

## Skip this PR

- App mailbox-access UI shell follow-ups (`74041437f`, `ce60c8526`) — with roles UI
- Hudu / unrelated merges

## Notes

- Regenerate `openapi.json` after HTTP entrypoints land.
- Baseline stays **11.2.1**.
- Overlap: do not re-cherry-pick `bdeeef2e0` here; it already lives on #82.

## Status

Bulk drawers + timezone migration landed. OpenAPI regenerated (880 endpoints). Calendar bulk-remove and app-mailbox UI deferred.
