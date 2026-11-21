# Sync checkpoint — 2026-11-21

| | Value |
|--|--|
| Work branch | `clint/upstream-intake-20261121` |
| Sync branch (script) | `manage365/upstream-sync-20261121` |
| Backup tag | `backup/pre-upstream-sync-manage365-20261121` |
| Base SHA | `b88ca6637` (Manage365 6.1.36) |
| Sync inventory base | `8971c3fc6` (CIPP v11.2.1) |
| Upstream tip reviewed | `12880df92` (CIPP v11.4.0) |
| `upstreamBaseline` after this PR | **11.2.1** (unchanged until feature packs land) |

## Mini-batches

1. Security foundations (Graph path, OData, webhook SSRF, SPO host)
2. Alerts + notifications (silent failures, snooze casing, day-rollover)
3. CA / standards / identity coverage
4. Reliability (variables, reports unknown, licenses, graph bulk FE, backup UTC)

## Recommendation

**Ready for draft PR** as a security/reliability intake. Do not claim CIPP baseline 11.4.0 yet.

## Follow-ups

Documented in [FOLLOWUPS_20261121.md](./FOLLOWUPS_20261121.md).
