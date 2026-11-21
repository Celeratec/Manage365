# Upstream Delta — Manage365 — 2026-11-21

Cycle: **Major** — CyberDrain CIPP **11.2.1 → 11.4.0** selective intake. Released `upstream/main` only; `upstream/dev` watched, not merged.

| | SHA / version |
|--|--|
| Sync base | `8971c3fc6` (tag **v11.2.1**) |
| Manage365 `main` at cycle start | `b88ca6637` — release **6.1.36**, baseline **11.2.1** |
| Backup tag | `backup/pre-upstream-sync-manage365-20261121` |
| Sync branch (script) | `manage365/upstream-sync-20261121` |
| Work branch | `clint/upstream-intake-20261121` |
| Upstream tip | `12880df92` — tag **v11.4.0** |
| Commits to review | **810** (`8971c3fc6..upstream/main`) |
| Ahead / behind vs upstream/main | **211** / **810** |

Releases in range: [v11.3.0](https://github.com/CyberDrain/CIPP/releases/tag/v11.3.0), [v11.4.0](https://github.com/CyberDrain/CIPP/releases/tag/v11.4.0) (“French '75”).

## Batch 1 — Apply (security / reliability)

| Upstream | Outcome | Notes |
|----------|---------|-------|
| `b54540ace` Graph path validation | **Apply** | New-GraphBulkRequest / device action / GDAP trace |
| `9e10e5b68` OData Type/Partition sanitize | **Apply** | Get-CIPPDbItem + Teams activity |
| `a0103d230` Webhook SSRF guard | **Apply** | Assert-CIPPWebhookDestination |
| `5525e964e` SPO REST tenant-host restrict | **Apply** | Builds on fork Resolve-CIPPSharePointRestContext |
| `9c0a5640e` Assert-CIPPSharePointHost | **Apply** | Centralize host checks |
| `8134fcddb` Scripted alerts no longer silent | **Apply** | Seven alert functions + tests |
| `b3e79565f` Alert snooze cmdlet casing | **Apply** | File names match functions |
| `9652a6935` Notification day-rollover | **Apply** | Push-SchedulerCIPPNotifications |
| `221460991` Day-rollover tidy | **Apply** | Follow-up refactor |
| `0eb1acc3f` CA policies failed read → error | **Apply** | ListConditionalAccessPolicies |
| `1e40f25cd` CA phishing-resistant + guest MFA | **Apply** | Security simulation CA analysis |
| `a2f4231ca` Guest/external CA coverage | **Adapt** | Keep fork Hudu/Ninja sync if conflict; take coverage helpers |
| `5e935359d` Standards false-compliant | **Apply** | Seven standards comparison fixes |
| `8ec39af08` MDE attach toggle | **Adapt** | Take standard/Defender attach logic; do not wholesale baselineStandards.json |
| `dc38b8686` Dynamic group rule evaluation | **Apply** | Tenant groups |
| `d93f6e475` Security sim GSA named location | **Apply** | CA What If / compliant network |
| `43c41faa1` Variables endpoint read errors | **Apply** | ExecCippReplacemap |
| `15962a13c` Reports unknown not negative | **Apply** | Sign-in / MFA missing data |
| `a7a5954ae` Edit user last license → remove all | **Apply** | CippAddEditUser |
| `65fd4ab93` Graph bulk single-row FE | **Apply** | getListGraphBulkRequestRows |
| `d740467d8` Backup direct-tenant auth UTC | **Adapt** | Include excluded/direct tenants + UTC auth date |
| `0e8a6e145` Hide default Exchange delegating roles | **Defer** | Feature files not in fork; Exchange utils pack |

## CONSIDER — defer to feature mini-PRs

| Theme | Outcome | Notes |
|-------|---------|-------|
| Intune Policy Failures / non-compliant / deployment / sync / MAA | **Defer** | Feature pack |
| NHI compromise + BEC release / containment | **Defer** | Feature pack |
| CA duplicate / vacation / named locations All Tenants / Compare Policies | **Defer** | Feature pack |
| SPO per-site guest + storage PDF | **Defer** | Adapt around recycle-bin suite |
| Exchange bulk drawers / timezone / app roles pages | **Defer** | Feature pack |
| BlockAllTenants + restricted multi-tenant SSO | **Defer** | Auth hardening pack |
| Tenant Groups in Tenant Selector (flag) | **Defer** | Design vs existing tenant groups |
| All Tenants cache coverage UX | **Defer** | Large table / card-view Adapt |
| Container sigstore / digest pinning | **Defer** | Ops review |
| Multi-partner beta | **Skip** until product sign-off | Cross-cutting tokens/GDAP/CPV |
| GSA web filtering templates | **Defer** | Tied to baselines/GSA |

## SKIP

| Area | Reason |
|------|--------|
| Hudu People/Devices/Magic Dash redesign | Fork keeps custom Hudu sync |
| NinjaOne ticketing as primary PSA | Integration posture; not required |
| Halo / CIPPPwPush / Premium / worker rewrite / Craft live queue | Historical deferrals |
| Baselines overrides / OR graduation / bulk stage UI | Baselines flag stays off |
| Wholesale `baselineStandards.json` | Thousands of lines; Adapt standards-only |
| Blind recycle-bin endpoint replacement | Fork POST/paging/empty-queue |
| Blind DataTable / card-view page merges | Adapt into Manage365 cards |
| CyberDrain-only CI / hosted subscription pages | Fork CI |
| Unreleased `upstream/dev` (~215 commits) | Watch / hotfix only |

## Dev watch (not this cycle)

Tip `47d0707d5` — SecOps mailbox baseline (#1353), BEC disabled-rules, pwsh 7.6 (#944), OneDrive copy-to-user, alert webhook 5xx retry, ongoing baselineStandards JSON churn.
