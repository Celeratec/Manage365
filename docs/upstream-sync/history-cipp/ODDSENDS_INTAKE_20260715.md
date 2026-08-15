# Odds & Ends Intake (menu/config, deps, build) — 2026-07-15

**Type:** Light intake (batch)
**Upstream baseline:** 10.6.1
**Fork version:** 5.24.0 → 5.25.0
**Backup tag:** `backup/pre-oddsends-intake-20260715`
**Branch:** `manage365/oddsends-intake-20260715`

## Upstream commits covered

| Commit | Subject | Disposition |
| --- | --- | --- |
| `2d50bf858` | Add missing permission for Device Management menu | Taken |
| `612ef72b8` | Broaden menu section permissions | Taken (all four sections) |
| `c38010f5e` | `scope: 'global'` on Application Templates | Skipped — fork's menu does not have that item/scope pattern in nativeMenuItems |
| `2d0b8f271` | Nav tooltips + keyboard shortcut hints | Taken (adapted to fork top-nav) |
| `907075a91` | Build optimisations | Partially taken — build-trace skip only (see below) |
| Dependency bumps | react-query family, apexcharts, mui-tiptap, reduxjs/toolkit, dompurify | Taken |
| Blob upload action bump | GitHub Actions | Skipped — fork's SWA workflow doesn't use that action |

## Changes

### Menu permission fixes (`src/layouts/config.js`)

Section-level menu permissions were narrower than their children, so users holding
only the child permission couldn't see the section at all:

- **Device Management**: added `Endpoint.Device.*` (children use it for Managed Devices)
- **Transport**: added `Exchange.Connector.*` (Connectors / Connector Templates)
- **Spam Filter**: added `Exchange.ConnectionFilter.*` (Connection Filter items)
- **Resource Management**: added `Exchange.Room.*` (Rooms / Room Lists)

### Top-nav polish (`src/layouts/top-nav.js`)

- Both search icon buttons now use proper MUI `Tooltip`s with `aria-label`s
  (previously plain `title` attributes).
- The "Manage365 Search" dialog title shows keyboard shortcut hints
  (Pages: Ctrl/Cmd+K · Users: Ctrl/Cmd+Shift+F).

### Build optimisation (`scripts/skip-export-build-traces.mjs` + `package.json`)

Adopted upstream's Next.js build-trace skip: for `output: 'export'` builds Next
still runs @vercel/nft "Collecting build traces" even though the result is never
used without a server runtime. The script idempotently patches the installed Next
build to skip it. **Measured: build went from ~67s to ~24s locally.**

Importantly, upstream's build script includes `rm -rf package.json yarn.lock`
(their SWA workaround that previously caused the fork's "deleted files" incident);
the fork's build script does **not** re-add that — only the trace-skip was taken:

```
"build": "node scripts/skip-export-build-traces.mjs && next build --webpack"
```

The script warns and proceeds unpatched if Next internals change, so CI can never
break from this.

The rest of `907075a91` (lazy rich-text field extraction from CippFormComponent,
prism highlighter split, license/standards data modules, intuneCollection move)
touches heavily customized fork files and is **deferred** for a dedicated pass.

### Dependency bumps (`package.json`)

Aligned with upstream 10.6.x versions:

- `@reduxjs/toolkit` ^2.11.2 → ^2.12.0
- `@tanstack/react-query` / `-devtools` / `-persist-client` → ^5.101.2 (kept in lockstep)
- `apexcharts` 5.10.4 → 5.16.0, `react-apexcharts` 2.1.0 → 2.1.1
- `mui-tiptap` ^1.30.0 → ^1.31.0
- `dompurify` added as a **direct** dependency (^3.4.11) — it was imported in
  several files but only resolved via the `resolutions` pin / transitive deps

`yarn install` regenerated the lockfile cleanly.

## Verification

- ESLint on config.js/top-nav.js: no new problems (2 errors + 2 warnings pre-exist
  on the clean tree — React Compiler memoization notes).
- `yarn build`: passed in 24s (trace skip confirmed active in output).

## Still deferred

- Remainder of `907075a91` (code-splitting refactors)
- Shadow AI report button changes (`6a1d7de99`), tenant metrics grid style (`495f38808`)
- PrivateRoute/login tweaks, container management
- API: Custom Test Alerting overhaul, MCP support, Purview DLP standard, Intune
  policy sync, IP lookup + audit log improvements, Sherweb
