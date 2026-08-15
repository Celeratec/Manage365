# MEM Devices + Small Component Fixes Intake — 2026-07-15

**Type:** Feature intake (batch)
**Upstream baseline:** 10.6.1 (commits from upstream/main, late June – early July 2026)
**Fork version:** 5.22.0 → 5.23.0
**Backup tag:** `backup/pre-memdevices-intake-20260715`
**Branch:** `manage365/memdevices-intake-20260715`

## Upstream commits covered

| Commit | Subject | Disposition |
| --- | --- | --- |
| `35a019f65` | Disable broken "Generate logs and ship to MEM" action | Taken (commented out, both pages) |
| `eb1935152` | refactor(devices): dedupe Intune device actions | Adapted — shared component built from the fork's richer action list |
| `b6d2de4d7` | chore: linting (device detail page) | Skipped — pure reformatting of a file we did not adopt wholesale |
| `9fd979ec9` | Defanged URL rendering fix | Taken |
| `690f7720a` | Bar chart tooltip/color fix | Taken |
| `0a3fe87d2` | Stable EMPTY_ARRAY default for `data` prop | Taken |
| `04d89c427` | Tenant correction on action click (#6268) | Taken (adapted to fork's categorized menu) |
| `0fc6459db` | Clear stale dialog results on reopen (#6265) | Taken (ApiDialog only; ApiResults diff was pure formatting) |
| `c4608b26c` | Search placeholder "Search input" → "Search..." | Skipped — fork already uses "Search items…" |

## Changes

### New shared component: `CippIntuneDeviceActions.jsx`

Upstream deduplicated the ~19 Intune device actions that were copy-pasted between
the MEM devices list page and the View Device detail page. We adopted the same
shape (`getIntuneDeviceActions({ tenantFilter })`) but built the array from the
**fork's** action list, which is a superset of upstream's:

- `category` (view/edit/manage/security/danger) driving the fork's grouped action menus
- `quickAction` flags for the table page's quick-action buttons
- The fork-only "View in Entra" link action
- Broken "Generate logs and ship to MEM" commented out per upstream `35a019f65`

Both pages now consume the shared list:

- `src/pages/endpoint/MEM/devices/index.js` — replaced the ~390-line inline array; unused icon imports removed.
- `src/pages/endpoint/MEM/devices/device/index.jsx` — replaced its ~370-line copy. This is a small
  behavior upgrade for the detail page: its copy had drifted (still listed the broken
  Generate-logs action, lacked quick-action flags). Link-type actions (`View Device`,
  `View in Intune`, `View in Entra`) are filtered out of the detail page's ActionsMenu by
  `components/actions-menu.js`, and the page header keeps its own View in Intune button,
  so the `[id]` placeholder links never render there.

### `src/utils/get-cipp-formatting.js`

Strings starting with `http` are now only rendered as links when they parse as a
real absolute http(s) URL. Defanged URLs (e.g. `https[:]//bad.com` from Check)
previously rendered as links relative to the CIPP instance; they now show as
plain text with a copy button.

### `src/components/CippCards/CippChartCard.jsx`

Bar charts now use a single named series with `xaxis.categories` +
`plotOptions.bar.distributed`, so tooltips show the category name instead of
"series-1" and per-bar colors are preserved. Legend dots use modulo color
cycling to match ApexCharts. Fork customizations (customColors, compact,
horizontal layout, header icon) untouched.

### `src/components/CippTable/CippDataTable.js`

- `data = EMPTY_ARRAY` module-level default so an undefined `data` prop doesn't
  create a fresh `[]` each render and loop the static-data sync effect.
- Row action clicks in AllTenants mode now only switch to the row's tenant for
  immediately-executing paths (noConfirm customFunction, customComponent). The
  standard dialog flow no longer eagerly switches, so cancelling a dialog no
  longer leaves the wrong tenant selected (upstream #6268). Adapted into the
  fork's categorized action menu.

### `src/components/CippComponents/CippApiDialog.jsx`

New effect on dialog open: clears streamed partial results, resets the POST
mutation, and clears the GET request state so a reopened dialog never shows
stale output from a previous action (upstream #6265). The fork already cleared
`partialResults` on close, but React Query retained the last mutation/query
result while the component stayed mounted.

## Fork customizations preserved

- MEM devices list page: card view, NinjaOne enrichment, compliance/ownership chips,
  quick actions config, custom offcanvas hero — all untouched (only the actions array moved).
- Device detail page: header buttons, compliance/apps/groups tabs, property lists — untouched.
- Chart card: all fork layout props preserved.
- DataTable: fork's categorized menus, card view, sorting helpers preserved; changes were surgical.
- Toolbar search placeholder kept as the fork's "Search items…".

## Verification

- ESLint on all touched files: 0 errors (pre-existing exhaustive-deps warnings only).
- `yarn build`: passed (67s).

## Still deferred (frontend)

- Scheduled user edit UI, Dashboard Alerts card
- config.js menu changes, top-nav tweaks, PrivateRoute/login tweaks
- Shadow AI report button removal, tenant metrics grid style, build optimisations
- Container management, dependency bumps

## Still deferred (API)

- Custom Test Alerting overhaul, MCP support, Purview DLP standard,
  Intune policy sync / device app collection, IP lookup + audit log improvements,
  and the remaining small items listed in USERACTIONS_NESTEDGROUPS_INTAKE_20260715.md.
