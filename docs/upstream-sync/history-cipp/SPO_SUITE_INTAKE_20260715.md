# SharePoint Site Management Suite Intake — 2026-07-15

Dedicated feature intake: ports the upstream **SharePoint site management
suite** (7 API commits from 2026-07-09/10 plus the sharing-links streaming
fixes) into Manage365. This was the largest deferred family and depends on the
SAM certificate authentication intake completed earlier the same day —
certificate app-only tokens are what let SharePoint REST `_api/web/*` calls run
without a delegated token.

- API branch: `manage365/spo-intake-20260715` (backup tag `backup/pre-spo-intake-20260715`)
- Frontend branch: `manage365/spo-intake-20260715` (backup tag `backup/pre-spo-intake-20260715`)
- Fork frontend version bumped to **5.19.0** (upstream baseline unchanged at 10.6.1 / API 10.6.2)

## What this adds

### API — net-new endpoints (upstream tip, wholesale)

- **Sharing report:** `Invoke-ListSharePointSharing`,
  `Invoke-ExecRemoveSharingLink`, `Invoke-ExecBulkRemoveSharingLinks`
- **Sharing links cache:** `Set-CIPPDBCacheSharePointSharingLinks` (includes
  upstream's streaming/OOM fixes `e7ed3a226`/`6c86428cc`/`82ac60ee9`) plus its
  activity workers `Push-DBCacheSharePointSiteSharingLinks` and
  `Push-StoreSharePointSharingLinks`
- **External users:** `Get-CIPPSPOExternalUsers` (CSOM GetExternalUsers —
  includes legacy spo:guest identities with no Entra object),
  `Invoke-ListSharePointExternalUsers`, `Invoke-ExecRemoveSPOExternalUser`
- **Full site user removal:** `Remove-CIPPSPOSiteUser`,
  `Invoke-ExecRemoveSiteUser` (removes a user from every site group and direct
  permission grant at once)
- **Item-level recycle bin:** `Invoke-ListSiteRecycleBin`,
  `Invoke-ExecRestoreRecycleBinItems` (new CIPP permission family
  `Sharepoint.SiteRecycleBin.Read` / `.ReadWrite`)
- **Libraries:** `Invoke-ListSiteLibraries`, `Invoke-ExecSetLibraryPermission`
- **Version cleanup:** `Invoke-ExecSPOVersionCleanup` (fork already had
  `Invoke-ListSPOVersionCleanup`)

### API — merged with fork customizations

- **`Invoke-ExecSetSharePointMember`** — adopted upstream's role-group model
  (Owners/Members/Visitors via `associated*group` REST with `-UseCertificate
  -AsApp $true`; group-connected sites keep managing Owners/Members through the
  M365 group) while preserving the fork's protections:
  - guest-UPN safety: prefers the picker's Entra object ID and encodes `#` as
    `%23` in filter lookups (upstream used `/users/$UPN` paths that break on
    `#EXT#`)
  - single-quote escaping in the group OData lookup
  - ensureuser force-add to the User Information List after group add (so new
    members appear immediately in the members table)
  - classified error messages (CPV token / cert-missing / access-denied
    guidance for `CippApiResults`)
- **`Invoke-ListSiteMembers`** — adopted upstream's rewrite: real role-group
  membership via cert REST, M365-group claim expansion through Graph, site
  admins flagged, guest detection, with automatic fallback to the fork's old
  User Information List approach when the cert/REST path is unavailable.
- **`Invoke-ExecSetSiteProperties`** — adopted upstream's version (superset of
  fork's): filters group-connected sites to the supported property subset and
  reports skipped properties.
- **`Push-ExecDeleteSharepointSite`** (fork's queued delete worker, both module
  copies) — kept the fork's background-queue architecture, template protection,
  and hub-site unregister, and applied upstream's auth findings:
  - fixed a latent bug where `-extraHeaders` was passed to
    `New-GraphPOSTRequest`, which has no such parameter (the POST calls would
    fail at parameter binding)
  - `SPO.Tenant` GET keeps `odata-version: 4.0` and now uses cert app-only
  - manager POST endpoints no longer receive `odata-version` (SPO rejects it
    with an "Elevated context" pipeline error)
  - `SPSiteManager/delete` now uses `-UseCertificate -AsApp $true` (denies
    delegated tokens with E_ACCESSDENIED)
- **`Push-CIPPDBCacheData`** (both module copies) — added the SharePoint
  license gate + `SharePointSharingLinks` as its own activity (heavy: scans
  every drive, spawns a child orchestrator). The CIPPCore copy previously had
  no SharePoint group task at all; it now dispatches the grouped SharePoint
  collection too.
- **`Config/CIPPDBCacheTypes.json`** — added the `SharePointSharingLinks`
  entry; removed a pre-existing duplicate `SharePointSiteUsage` entry.
- `$MemberType` in ExecSetSharePointMember additionally reads
  `$Request.Body.MemberType` so flat table-action mappings (site-details page)
  can pass the member type without an addedFields object.

### Frontend

- **SharePoint Sites page (fork's customized page, actions added/updated):**
  - Add Member: site role picker (Members/Owners/Visitors)
  - Remove Member: now driven by `ListSiteMembers` (real role membership,
    shows the member's role and dedupes)
  - New: Remove User From Site, Revoke Sharing Links (Anonymous/External/All
    scopes), Edit Site (consolidated property editor with prefill), Set
    Library Permission, Start Version Cleanup Job, Check Cleanup Job Status,
    item-level Recycle Bin dialog
  - Off-canvas members table switched from the User Information List to
    `ListSiteMembers` (role/type/guest/admin columns)
  - Fork's existing quick actions (Lock/Unlock, Set Sharing Policy, Set
    Storage Quota, Live Storage, Create Team from Site) untouched
- **Site Details page:** members table switched to `ListSiteMembers`; Remove
  Member action now passes the member's role group and type
- **New pages:** `/teams-share/sharing-report` (charts + revoke links) and
  `/teams-share/external-users` (tenant-wide external user inventory with
  remove/purge actions), both wholesale from upstream
- **New components:** `CippEditSitePropertiesForm`, `CippSiteRecycleBinDialog`
- **Menu:** Sharing Report + External Users added to the SharePoint section

### Kept fork implementations (upstream equivalents skipped)

- **Deleted sites family** — fork's `Invoke-ListDeletedSites`,
  `Invoke-ExecRestoreDeletedSite`, `Invoke-ExecRemoveDeletedSite` and the
  `/teams-share/sharepoint/recycle-bin` page stay. Upstream's
  `Get-CIPPSPODeletedSites` / `Restore-CIPPSPODeletedSite` /
  `deleted-sites.js` were not taken (fork's version has feature parity plus
  permanent-delete, which upstream lacks).
- Fork's per-property `ExecSetSiteProperty` quick actions remain alongside the
  new consolidated Edit Site dialog.

## Permissions

- SharePoint `Sites.FullControl.All` application permission
  (`678536fe-1083-478a-9c59-b99265e6b0d3` on `00000003-0000-0ff1-ce00-000000000000`)
  was already present in both fork SAM manifests — no manifest change needed.
  A CPV refresh is still recommended so client tenants pick up the SharePoint
  app-only consent for the certificate token path.
- New CIPP RBAC roles surface automatically from the endpoint `.ROLE`
  docstrings: `Sharepoint.SiteRecycleBin.Read` / `.ReadWrite`.

## Deferred (unchanged)

- `Invoke-ExecSetOneDriveSharing` (separate "OneDrive Sharing disable" commit)
- OneDrive root permissions cache (from the 10.6.2 hotfix range)
- License capability presets commit `29685d69b` (touches 140+ files; the
  sharing-links task addition was adapted to the fork's existing license-check
  style instead)

## Verification

- PowerShell parse check on all 25 changed/added API files: clean.
- Dependency scan of new functions: all referenced helpers
  (`Get-SharePointAdminLink`, `Start-CIPPOrchestrator`, `New-GraphBulkRequest`,
  KV/Graph helpers, `Get-CIPPIdentityLabel`/`Test-CIPPExternalIdentity`
  defined in the sharing workers) resolve in the fork.
- `Config/CIPPDBCacheTypes.json` validates as JSON.
- Frontend production build (`yarn build`, Node 22): clean; new routes
  `sharing-report.html` and `external-users.html` emitted.
- No linter errors on the seven touched frontend files.
