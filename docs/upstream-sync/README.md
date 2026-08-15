# Upstream Sync Tracking

Cycle-specific tracking documents for Manage365's selective intake from the [CyberDrain CIPP monorepo](https://github.com/CyberDrain/CIPP).

- **[PROCESS.md](./PROCESS.md)** — the sync process (monorepo edition). Start here.
- **`UPSTREAM_DELTA_YYYYMMDD.md`** — commit inventory for a cycle
- **`SYNC_CHECKPOINT_YYYYMMDD.md`** — cycle results and next sync base
- **`APPLIED_COMMITS_YYYYMMDD.md`** — per-commit outcomes

## Pre-monorepo history

Before August 2026, Manage365 tracked the split `KelvinTegelaar/CIPP` and `KelvinTegelaar/CIPP-API` repos and deployed to Azure Static Web Apps + Function App slots. Those cycle documents are preserved:

- [history-cipp/](./history-cipp/) — frontend (CIPP) cycles through v10.8.5 / Manage365 v5.33.0
- [history-cipp-api/](./history-cipp-api/) — backend (CIPP-API) cycles through v10.8.5

The migration of Manage365 customizations into this monorepo is documented in [MONOREPO_MIGRATION_20260815.md](./MONOREPO_MIGRATION_20260815.md).
