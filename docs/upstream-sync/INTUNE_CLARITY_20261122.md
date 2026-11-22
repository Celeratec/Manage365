# Intune clarity intake — 2026-11-22

Branch: `clint/upstream-intune-clarity`  
Base: Manage365 `main` @ `6ff2d9946` (post Batch 1)  
Upstream range: CIPP `8971c3fc6` (v11.2.1) → `12880df92` (v11.4.0)  
`upstreamBaseline` stays **11.2.1**

## Scope (from FOLLOWUPS)

Policy Failures, non-compliant devices, deployment/sync drawers, Autopilot unassign / remove primary user, enrollment restrictions. Pair FE/BE; Adapt card views / menu.

## Planned Apply order

| Upstream SHA | Intent |
|--------------|--------|
| `5f08dd9e8` | Intune report export retry / nightly miss |
| `8c1e02048` | Device policy status report endpoint |
| `a797ae70d` | Enrollment configuration on device policy status |
| `1611d89ad` | Non-compliant devices page |
| `004ed5c6b` | Policy Failures page |
| `7e6abff93` | Per-device / per-user deployment status drawers |
| `90fa5fdf1` | Autopilot unassign + Intune primary user remove (**Adapt** if Batch 1 already added `removePrimaryUser`) |
| `9111f8ecf` | Sync status drawer |
| `355ce8022` | Multi-admin approval pending on remove |
| `a4955e39b` → `349f6d652` → `c4d3e6141` → `c20b93fe1` | Enrollment restrictions + templates + Windows examples |

## Skip this PR

- Hudu Intune/device redesign commits
- Endpoint security template editor (`02530eb18`)
- Broad Intune cache perf-only unless required by features above
- Baselines Intune drift commits unless blocking

## Notes

- Regenerate `openapi.json` once after HTTP entrypoints land.
- Keep Manage365 card-view / menu Adapt where layouts conflict.
