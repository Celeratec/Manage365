# Applied commits — Manage365 upstream intake 2026-11-21

Branch: `clint/upstream-intake-20261121`  
Base: Manage365 `main` `b88ca6637` (6.1.36) / CIPP sync base `8971c3fc6` (v11.2.1)

| Upstream SHA | Outcome | Fork note |
|--------------|---------|-----------|
| `b54540ace` | **Adapt** | Graph path validation; restored device-action allowlist + GDAP UPN escape; kept partner-tenant fallback |
| `9e10e5b68` | **Apply** | OData Type/Partition sanitize |
| `a0103d230` | **Apply** | Webhook SSRF guard |
| `5525e964e` | **Apply** | SPO REST tenant-host restrict |
| `9c0a5640e` | **Apply** | Assert-CIPPSharePointHost |
| `8134fcddb` | **Apply** | Scripted alerts silent-failure fix (restored deleted test) |
| `b3e79565f` | **Apply** | Alert snooze file naming |
| `9652a6935` | **Apply** | Notification day-rollover |
| `221460991` | **Apply** | Day-rollover tidy |
| `0eb1acc3f` | **Apply** | CA policies failed read → error |
| `1e40f25cd` | **Apply** | CA phishing-resistant + guest MFA analysis |
| `a2f4231ca` | **Adapt** | Guest/external CA coverage; took upstream Get-CIPPMFAState rewrite; Hudu/Ninja guest membership helpers included |
| `5e935359d` | **Apply** | Standards false-compliant |
| `8ec39af08` | **Adapt** | MDE attach toggle (standards + small baselineStandards lines) |
| `dc38b8686` | **Apply** | Dynamic tenant group evaluation |
| `d93f6e475` | **Apply** | Security sim GSA named location |
| `43c41faa1` | **Adapt** | Variables table ErrorAction Stop + tenant scoping; kept fork tenantId/GlobalVariables guards |
| `15962a13c` | **Adapt** | Reports unknown-not-negative; kept Manage365 MFACard colors + Unknown node |
| `a7a5954ae` | **Apply** | Edit user last license → remove all |
| `65fd4ab93` | **Apply** | Graph bulk single-row FE |
| `d740467d8` | **Adapt** | Direct-tenant auth UTC + include excluded/direct tenants in CIPP backup; also added `allowedUsers` (drop `_` bookkeeping keys) so instance user rows restore |
| `0e8a6e145` | **Defer** | Hide default Exchange delegating roles — AppPermissions / app-mailbox-access pages not in fork yet (Exchange feature pack) |

## Not applied this PR (queued)

See [FOLLOWUPS_20261121.md](./FOLLOWUPS_20261121.md).
