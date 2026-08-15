# Upstream Sync Inventory — CIPP (Frontend)

Generated: 2026-06-17 11:21

## Summary

| Field | Value |
|-------|-------|
| Our branch tip | `f2d87612ec80b9be24c303137c9604590992b144` |
| Upstream branch | `upstream/main` |
| Upstream tip | `0d8ca9d2f5f8511413b69a3064e055ac45024f33` |
| Merge base | `0710355e2adac37fffe4c7eef48d6f2c3a04993d` |
| Commits to review | **241** |

### Risk Distribution

- **Low**: 11
- **Medium**: 80
- **High**: 150

### Recommendation Distribution

- **Needs manual review**: 200
- **Cherry-pick with adaptation**: 30
- **Cherry-pick**: 11

### Review Buckets

- **Potentially breaking changes**: 157
- **Dependency/build changes**: 136
- **Other**: 44
- **Tenant management changes**: 20
- **Intune changes**: 9
- **UI improvements**: 7
- **Security fixes**: 6
- **Exchange/Email changes**: 6
- **Authentication/permissions changes**: 6
- **Tests-only**: 4
- **Bug fixes**: 2
- **API endpoint changes**: 1

---

## Commit Inventory

### 1. `7dffc4c6` — feat: add fuzzy match distance setting to Intune template based on Levenshtein distance

| Field | Value |
|-------|-------|
| SHA | `7dffc4c64a9de48e0d6f3f59abdcc57f1634c019` |
| Author | Bobby |
| Date | 2026-03-20 20:27:59 +0100 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** `src/data/standards.json`

---

### 2. `4fc1b57b` — feat: add warningMessage support  standards

| Field | Value |
|-------|-------|
| SHA | `4fc1b57b65a49f832db2ded4e15563a21ac1ebfa` |
| Author | Bobby |
| Date | 2026-03-20 20:41:42 +0100 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippStandards/CippStandardAccordion.jsx`, `src/data/standards.json`

---

### 3. `88bc10a5` — Added UI Elements for adding conditional access policies to package tags

| Field | Value |
|-------|-------|
| SHA | `88bc10a527efe58a986bf96c551c07c74c3f6ab5` |
| Author | James Tarran |
| Date | 2026-04-02 19:03:48 +0100 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/data/standards.json`, `src/pages/tenant/conditional/list-template/index.js`

---

### 4. `5ffd20e1` — Merge remote-tracking branch 'upstream/dev' into Feat-Conditional-accesss-policy-package-tags

| Field | Value |
|-------|-------|
| SHA | `5ffd20e13c0d00dee4af844cff6affc6883c298e` |
| Author | James Tarran |
| Date | 2026-04-03 07:50:17 +0100 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** (none)

---

### 5. `db57e52a` — Mark TemplateList as optional and non-creatable

| Field | Value |
|-------|-------|
| SHA | `db57e52a207f3e9d77974832978d88963859bf83` |
| Author | James Tarran |
| Date | 2026-04-03 08:14:19 +0100 |
| Files changed | 1 |
| Risk | **Low** |
| Area | UI |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: UI improvements |

**Files:** `src/data/standards.json`

---

### 6. `83d657b8` — Lookup CA template names via API

| Field | Value |
|-------|-------|
| SHA | `83d657b8390afb7853ddcf68e822efc7a92b1b28` |
| Author | James Tarran |
| Date | 2026-04-03 14:07:06 +0100 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/tenant/manage/drift.js`, `src/pages/tenant/manage/policies-deployed.js`

---

### 7. `b6438ee3` — Merge branch 'dev' into Feat-Conditional-accesss-policy-package-tags

| Field | Value |
|-------|-------|
| SHA | `b6438ee3c9874f2769542e4a9829fe88a87c799b` |
| Author | KelvinTegelaar |
| Date | 2026-04-04 02:14:49 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** (none)

---

### 8. `05b93261` — chore(deps): bump actions/setup-node from 6.3.0 to 6.4.0

| Field | Value |
|-------|-------|
| SHA | `05b93261635e0c6c2859581c4be1ce058806b066` |
| Author | dependabot[bot] |
| Date | 2026-04-22 23:44:43 +0000 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `.github/workflows/Node_Project_Check.yml`, `.github/workflows/cipp_dev_build.yml`, `.github/workflows/cipp_frontend_build.yml`

---

### 9. `9ae908d7` — chore(deps): bump recharts from 3.8.0 to 3.8.1

| Field | Value |
|-------|-------|
| SHA | `9ae908d73382e1f4da5ea85c968d9b1eb2a7455c` |
| Author | dependabot[bot] |
| Date | 2026-04-22 23:44:47 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 10. `93cfed20` — chore(deps): bump @tanstack/react-query-devtools from 5.91.3 to 5.96.2

| Field | Value |
|-------|-------|
| SHA | `93cfed20dca053f6077b1dd6783292847f503f17` |
| Author | dependabot[bot] |
| Date | 2026-04-22 23:45:03 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 11. `c22177f7` — chore(deps): bump mui-tiptap from 1.29.1 to 1.30.0

| Field | Value |
|-------|-------|
| SHA | `c22177f70624b2780c8079c60977f6aed7035c85` |
| Author | dependabot[bot] |
| Date | 2026-04-22 23:45:24 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 12. `c3c90afe` — chore(deps): bump @uiw/react-json-view

| Field | Value |
|-------|-------|
| SHA | `c3c90afeda02f0dd9d20e7583aef1d7f51cdb284` |
| Author | dependabot[bot] |
| Date | 2026-04-22 23:55:54 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 13. `a5f2b74b` — feat: add allTenants support for multiple intune pages

| Field | Value |
|-------|-------|
| SHA | `a5f2b74b69fa0e3847666c57dd19e072578b9466` |
| Author | Bobby |
| Date | 2026-04-25 01:32:34 +0200 |
| Files changed | 8 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/endpoint/MEM/assignment-filters/index.js`, `src/pages/endpoint/MEM/devices/index.js`, `src/pages/endpoint/MEM/list-appprotection-policies/index.js`, `src/pages/endpoint/MEM/list-compliance-policies/index.js`, `src/pages/endpoint/MEM/list-policies/index.js`, `src/pages/endpoint/MEM/list-scripts/index.jsx`, `src/pages/endpoint/MEM/reusable-settings/index.js`, `src/pages/endpoint/applications/list/index.js`

---

### 14. `f86925dc` — Merge branch 'dev' of https://github.com/kris6673/CIPP into alltenants-intune

| Field | Value |
|-------|-------|
| SHA | `f86925dc5ee5d3c8c875ff81577242cc206cf82c` |
| Author | Bobby |
| Date | 2026-04-25 20:57:51 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 15. `1707506b` — feat: integrate useCippReportDB for data handling

| Field | Value |
|-------|-------|
| SHA | `1707506b0a39fbf7c0154b9608b9d90a69c19331` |
| Author | Bobby |
| Date | 2026-04-25 21:22:00 +0200 |
| Files changed | 8 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippReportDBControls.jsx`, `src/pages/endpoint/MEM/assignment-filters/index.js`, `src/pages/endpoint/MEM/devices/index.js`, `src/pages/endpoint/MEM/list-appprotection-policies/index.js`, `src/pages/endpoint/MEM/list-compliance-policies/index.js`, `src/pages/endpoint/MEM/list-scripts/index.jsx`, `src/pages/endpoint/MEM/reusable-settings/index.js`, `src/pages/endpoint/applications/list/index.js`

---

### 16. `d7d36a31` — feat: Add allTenants support for all the Teams  SharePoint pages

| Field | Value |
|-------|-------|
| SHA | `d7d36a31eb86f6b6f011d483862024515f63757d` |
| Author | Bobby |
| Date | 2026-04-26 19:13:54 +0200 |
| Files changed | 5 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/teams-share/onedrive/index.js`, `src/pages/teams-share/sharepoint/index.js`, `src/pages/teams-share/teams/business-voice/index.js`, `src/pages/teams-share/teams/list-team/index.js`, `src/pages/teams-share/teams/teams-activity/index.js`

---

### 17. `b05e0923` — feat(standards): add by-standard alignment summary view

| Field | Value |
|-------|-------|
| SHA | `b05e0923d8afc286f7ca5591056bf847c8dbd755` |
| Author | Bobby |
| Date | 2026-05-08 22:36:34 +0200 |
| Files changed | 6 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippTranslations.jsx`, `src/components/CippTable/CippDataTable.js`, `src/components/CippTable/CippDataTableButton.jsx`, `src/pages/tenant/standards/alignment/index.js`, `src/utils/get-cipp-column-size.js`, `src/utils/get-cipp-formatting.js`

---

### 18. `45f1d72b` — purview adding

| Field | Value |
|-------|-------|
| SHA | `45f1d72bf7e1376fbc2e4f58ecc39d9a4c3e363b` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 01:25:58 +0200 |
| Files changed | 11 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippDeployCompliancePolicyDrawer.jsx`, `src/data/standards.json`, `src/layouts/config.js`, `src/pages/security/compliance/dlp-templates/index.js`, `src/pages/security/compliance/dlp/index.js`, `src/pages/security/compliance/labels-templates/index.js`, `src/pages/security/compliance/labels/index.js`, `src/pages/security/compliance/retention-templates/index.js`, `src/pages/security/compliance/retention/index.js`, `src/pages/security/compliance/sit-templates/index.js`, `src/pages/security/compliance/sit/index.js`

---

### 19. `b8abed94` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `b8abed94810020cd90175d56ea268215d990a37f` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 01:26:05 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 20. `e3ed1818` — fix alert mode

| Field | Value |
|-------|-------|
| SHA | `e3ed181822d69e25889251113ae8b3732b2d492d` |
| Author | KelvinTegelaar |
| Date | 2026-05-10 14:51:51 +0200 |
| Files changed | 2 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** `src/data/standards.json`, `src/pages/security/compliance/retention/index.js`

---

### 21. `98d5d94a` — Custom Test - Alert on X statuses

| Field | Value |
|-------|-------|
| SHA | `98d5d94a0d122d5fbc7380d5abe5cb02fba366fd` |
| Author | Zacgoose |
| Date | 2026-05-11 21:49:35 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `src/pages/tools/custom-tests/add.jsx`

---

### 22. `4b9efd82` — Update index.js

| Field | Value |
|-------|-------|
| SHA | `4b9efd827d27a3498eca51b444934a99e78c634f` |
| Author | Zacgoose |
| Date | 2026-05-11 23:14:49 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/tenant/reports/list-licenses/index.js`

---

### 23. `cfe8c705` — adds #5939

| Field | Value |
|-------|-------|
| SHA | `cfe8c705025c918e34646f68bba815af2a0d04b2` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 19:51:43 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/tenant/reports/list-licenses/index.js`

---

### 24. `0d42f679` — #5939

| Field | Value |
|-------|-------|
| SHA | `0d42f6798b69367401c33f692b541faa8f483651` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 19:51:47 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/tenant/reports/list-licenses/index.js`

---

### 25. `64e40807` — implemenets #5948

| Field | Value |
|-------|-------|
| SHA | `64e408072e2cea57f098f49acbd84dd3d96187b2` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 19:58:59 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippApplicationDeployDrawer.jsx`

---

### 26. `445820dd` — Better intune policy support for alltenants list

| Field | Value |
|-------|-------|
| SHA | `445820dddc1438aa87d4b57d523784a9a5f2fb04` |
| Author | Zacgoose |
| Date | 2026-05-12 02:01:46 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippIntunePolicyDetails.jsx`, `src/components/CippFormPages/CippJSONView.jsx`

---

### 27. `8b79d999` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `8b79d999788597e35b9e3440db71a98a304aaeaa` |
| Author | Zacgoose |
| Date | 2026-05-12 02:01:48 +0800 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 28. `55dd9cc2` — HVE user page

| Field | Value |
|-------|-------|
| SHA | `55dd9cc22fab7e05f07214f55acc92743faf8829` |
| Author | Zacgoose |
| Date | 2026-05-12 02:04:38 +0800 |
| Files changed | 6 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippHVEUserDrawer.jsx`, `src/components/CippComponents/CippNotificationForm.jsx`, `src/data/CIPPDBCacheTypes.json`, `src/layouts/config.js`, `src/pages/email/administration/hve-accounts/index.js`, `src/pages/email/administration/mailboxes/index.js`

---

### 29. `9cee69d4` — eclusions everywhere

| Field | Value |
|-------|-------|
| SHA | `9cee69d460f246f83583316091ba86170f73f172` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:13:45 +0200 |
| Files changed | 6 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippAppTemplateDrawer.jsx`, `src/components/CippComponents/CippApplicationDeployDrawer.jsx`, `src/components/CippComponents/CippIntunePolicyActions.jsx`, `src/components/CippComponents/CippPolicyDeployDrawer.jsx`, `src/components/CippWizard/CippIntunePolicy.jsx`, `src/pages/endpoint/applications/templates/index.js`

---

### 30. `14461b4f` — eclusions everywhere

| Field | Value |
|-------|-------|
| SHA | `14461b4f68c5f6e3214512a575d585439d9cbbd7` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:13:49 +0200 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippIntunePolicyActions.jsx`, `src/components/CippWizard/CippIntunePolicy.jsx`, `src/pages/endpoint/applications/templates/index.js`

---

### 31. `1b77b784` — Update manifest for PWA chrome install option

| Field | Value |
|-------|-------|
| SHA | `1b77b7843ee3c86e746019d8ce0ecd2ded3ed6cf` |
| Author | Zacgoose |
| Date | 2026-05-12 02:28:27 +0800 |
| Files changed | 4 |
| Risk | **Medium** |
| Area | UI |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: UI improvements |

**Files:** `public/manifest.json`, `public/sw.js`, `src/pages/_app.js`, `src/pages/_document.js`

---

### 32. `08c793d7` — Update manifest.json

| Field | Value |
|-------|-------|
| SHA | `08c793d77ab6449bd8ec7bbdebd9535d892d00f6` |
| Author | Zacgoose |
| Date | 2026-05-12 02:28:43 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `public/manifest.json`

---

### 33. `da6dc7fa` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `da6dc7fad7915d6e82a1fd631047dd5047b22487` |
| Author | Zacgoose |
| Date | 2026-05-12 02:29:13 +0800 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 34. `20e2f554` — implements #5986

| Field | Value |
|-------|-------|
| SHA | `20e2f554df668843e44dc2e88671bb605aab7067` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:43:01 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippTenantAllowBlockListTemplateDrawer.jsx`, `src/pages/email/administration/tenant-allow-block-list-templates/index.js`

---

### 35. `bc412396` — implements #5986

| Field | Value |
|-------|-------|
| SHA | `bc412396b99046eb487a838aaf213007f1db568e` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:43:06 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippTenantAllowBlockListTemplateDrawer.jsx`, `src/pages/email/administration/tenant-allow-block-list-templates/index.js`

---

### 36. `8e99c018` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `8e99c01866d9f7f6bc78c6517e80db73ab1b0ca8` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:43:08 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 37. `2e9b9fd5` — fixed weird button

| Field | Value |
|-------|-------|
| SHA | `2e9b9fd508f2e9ae6fddffa9f03db7c8edb22881` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:47:36 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippTenantAllowBlockListTemplateDrawer.jsx`

---

### 38. `2a1b9128` — Merge pull request #5984 from kris6673/by-standards-view

| Field | Value |
|-------|-------|
| SHA | `2a1b9128bb8177ca79e75d6faa078e6fcd84c7a5` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 20:49:29 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 39. `35711f89` — Merge branch 'dev' of https://github.com/kris6673/CIPP into allTenants-SP

| Field | Value |
|-------|-------|
| SHA | `35711f89238acdd76b53fae5c9830346b5fa99db` |
| Author | Bobby |
| Date | 2026-05-11 20:59:51 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 40. `5ca3e9ad` — Merge branch 'dev' into alltenants-intune

| Field | Value |
|-------|-------|
| SHA | `5ca3e9ad310e88e92ec7e6b44e54bab52f0ae57c` |
| Author | Bobby |
| Date | 2026-05-11 21:06:50 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** (none)

---

### 41. `be88cc9c` — Merge branch 'dev' into levenshtein-distance

| Field | Value |
|-------|-------|
| SHA | `be88cc9c54dd47a989fd3c3af7b4b8ff2fec537e` |
| Author | Kristian Kjærgård |
| Date | 2026-05-11 21:07:15 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 42. `dd0ba6f1` — Merge pull request #5920 from kris6673/alltenants-intune

| Field | Value |
|-------|-------|
| SHA | `dd0ba6f1b07b33eb18dae67131341d2df35f6b30` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:13:11 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** (none)

---

### 43. `2f849474` — Merge branch 'dev' into levenshtein-distance

| Field | Value |
|-------|-------|
| SHA | `2f849474358af80c5da1a67048800baaf3d4bf4f` |
| Author | Kristian Kjærgård |
| Date | 2026-05-11 21:20:47 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 44. `fd23c0df` — Merge branch 'dev' into allTenants-SP

| Field | Value |
|-------|-------|
| SHA | `fd23c0df0fd3c63fc7d5f1fc006bb60c8b8b788d` |
| Author | Kristian Kjærgård |
| Date | 2026-05-11 21:21:18 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** (none)

---

### 45. `fe722173` — Merge pull request #5794 from TecharyJames/Feat-Conditional-accesss-policy-package-tags

| Field | Value |
|-------|-------|
| SHA | `fe722173a80cb3ab719f90cfe1a49899e710c41c` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:29:08 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** (none)

---

### 46. `ccf4e9cf` — Merge pull request #5685 from kris6673/levenshtein-distance

| Field | Value |
|-------|-------|
| SHA | `ccf4e9cf01a4158c5cb6cad3264e84b855a3e194` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:33:48 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 47. `0fc7b3c6` — Merge pull request #5921 from kris6673/allTenants-SP

| Field | Value |
|-------|-------|
| SHA | `0fc7b3c6123916874377ffad15fa6a7b3464a094` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:37:32 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** (none)

---

### 48. `4b0800b8` — Merge pull request #5903 from KelvinTegelaar/dependabot/github_actions/dev/actions/setup-node-6.4.0

| Field | Value |
|-------|-------|
| SHA | `4b0800b8371802b36fadf269fe0ab99afa4dbdc0` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:55:32 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 49. `7bcd507c` — Merge pull request #5906 from KelvinTegelaar/dependabot/npm_and_yarn/dev/mui-tiptap-1.30.0

| Field | Value |
|-------|-------|
| SHA | `7bcd507c81e29aab1b8d2b9d0ef93c8e91a5c7cf` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:56:26 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 50. `cef87445` — Merge pull request #5905 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tanstack/react-query-devtools-5.96.2

| Field | Value |
|-------|-------|
| SHA | `cef87445b19b8a64c6289f67073dc77fb7d13abc` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:56:35 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 51. `06e16457` — Merge pull request #5904 from KelvinTegelaar/dependabot/npm_and_yarn/dev/recharts-3.8.1

| Field | Value |
|-------|-------|
| SHA | `06e16457eb9b9c872f746706eb591acc4834c2fe` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:56:54 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 52. `7dcb867b` — Merge pull request #5908 from KelvinTegelaar/dependabot/npm_and_yarn/dev/uiw/react-json-view-2.0.0-alpha.42

| Field | Value |
|-------|-------|
| SHA | `7dcb867bb354653fcfaa9218e81f1bcb96a83ef9` |
| Author | KelvinTegelaar |
| Date | 2026-05-11 21:57:59 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 53. `a4915dff` — chore(deps): bump @tanstack/react-query-persist-client

| Field | Value |
|-------|-------|
| SHA | `a4915dff719e75be54e3b786b27028b54aadc26d` |
| Author | dependabot[bot] |
| Date | 2026-05-11 20:01:47 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 54. `fe4bd7f9` — fix: allow alltenants sync on onedrive/sharepoint

| Field | Value |
|-------|-------|
| SHA | `fe4bd7f9cdf6ff5188c8df9078d9b9a8d38ea979` |
| Author | John Duprey |
| Date | 2026-05-11 17:41:08 -0400 |
| Files changed | 2 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/teams-share/onedrive/index.js`, `src/pages/teams-share/sharepoint/index.js`

---

### 55. `d7e8b0b5` — fix: tweak toggle button size

| Field | Value |
|-------|-------|
| SHA | `d7e8b0b569c3f9243ff7e09a326ed74ccbd3a046` |
| Author | John Duprey |
| Date | 2026-05-11 19:03:48 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/tenant/standards/alignment/index.js`

---

### 56. `15939e2b` — feat: improve run standard now UX provide single action with autocomplete to select all tenants in template or individual tenant (expanded from alltenants/groups)

| Field | Value |
|-------|-------|
| SHA | `15939e2b9a9a9d229b3f0e33b0fbde1467222016` |
| Author | John Duprey |
| Date | 2026-05-11 22:48:47 -0400 |
| Files changed | 7 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippFormTemplateTenantSelector.jsx`, `src/pages/tenant/manage/applied-standards.js`, `src/pages/tenant/manage/drift.js`, `src/pages/tenant/manage/driftManagementActions.js`, `src/pages/tenant/manage/policies-deployed.js`, `src/pages/tenant/standards/templates/index.js`, `src/pages/tenant/standards/templates/template.jsx`

---

### 57. `1cb6a11c` — fix: enhance standard name retrieval logic for better matching

| Field | Value |
|-------|-------|
| SHA | `1cb6a11cf22c446b952976f5200f5a3f3df689f5` |
| Author | John Duprey |
| Date | 2026-05-11 22:54:17 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/tenant/standards/alignment/index.js`

---

### 58. `6cd8c632` — chore: linting

| Field | Value |
|-------|-------|
| SHA | `6cd8c632cc9273a5fd95b82dba4a99f81b442b59` |
| Author | John Duprey |
| Date | 2026-05-11 23:07:54 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/tenant/standards/alignment/index.js`

---

### 59. `4f2d4993` — feat: enhance intune template details display

| Field | Value |
|-------|-------|
| SHA | `4f2d4993fb2efb983bea8a38de5d527e5d87c369` |
| Author | John Duprey |
| Date | 2026-05-11 23:57:17 -0400 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippTranslations.jsx`, `src/pages/endpoint/MEM/list-templates/index.js`, `src/utils/get-cipp-formatting.js`

---

### 60. `0a70010e` — fix: update translation keys and adjust template usage references

| Field | Value |
|-------|-------|
| SHA | `0a70010e2185488a67f91f8e508f67f14f0708df` |
| Author | John Duprey |
| Date | 2026-05-12 00:07:31 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippTranslations.jsx`, `src/pages/endpoint/MEM/list-templates/index.js`

---

### 61. `63c85df0` — OneDrive Sharing disable

| Field | Value |
|-------|-------|
| SHA | `63c85df03c93f0172b357ccd3be0536f075210da` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 16:03:50 +0200 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippCards/CippRemediationCard.jsx`, `src/components/CippComponents/CippOffboardingDefaultSettings.jsx`, `src/components/CippComponents/CippUserActions.jsx`, `src/components/CippWizard/CippWizardOffboarding.jsx`

---

### 62. `6c55bc42` — OneDrive Sharing disable

| Field | Value |
|-------|-------|
| SHA | `6c55bc422c0e8d89c66dbd4de14b595babfd188f` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 16:03:54 +0200 |
| Files changed | 4 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippCards/CippRemediationCard.jsx`, `src/components/CippComponents/CippOffboardingDefaultSettings.jsx`, `src/components/CippComponents/CippUserActions.jsx`, `src/components/CippWizard/CippWizardOffboarding.jsx`

---

### 63. `7054bfc4` — Add AlertUserReportPhising

| Field | Value |
|-------|-------|
| SHA | `7054bfc42d67a7f3d86b23b036057ba98559d488` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 16:32:20 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/alerts.json`

---

### 64. `d00ebb77` — chore: bump version to 10.4.5

| Field | Value |
|-------|-------|
| SHA | `d00ebb77ca928c0fe06f5f728a78a459b76dd911` |
| Author | John Duprey |
| Date | 2026-05-12 11:32:16 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `public/version.json`

---

### 65. `335e40ad` — Merge pull request #5907 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tanstack/react-query-persist-client-5.96.2

| Field | Value |
|-------|-------|
| SHA | `335e40ad0dbdf05dd9453eef6df89901932a2782` |
| Author | KelvinTegelaar |
| Date | 2026-05-12 20:25:37 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 66. `19c48eab` — auth options

| Field | Value |
|-------|-------|
| SHA | `19c48eabf7ff5779f683b6edf33ca24d9c76dae0` |
| Author | Zacgoose |
| Date | 2026-05-13 04:19:28 +0800 |
| Files changed | 12 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/ForcedSsoMigrationDialog.jsx`, `src/components/CippComponents/SsoMigrationDialog.jsx`, `src/components/CippIntegrations/CippApiClientManagement.jsx`, `src/components/CippSettings/CippContainerManagement.jsx`, `src/components/CippSettings/CippSSOSettings.jsx`, `src/components/CippSettings/CippUserManagement.jsx`, `src/layouts/TabbedLayout.jsx`, `src/layouts/index.js`, `src/pages/cipp/advanced/super-admin/cipp-users.js`, `src/pages/cipp/advanced/super-admin/container.js`, `src/pages/cipp/advanced/super-admin/sso.js`, `src/pages/cipp/advanced/super-admin/tabOptions.json`

---

### 67. `36071e54` — Module updates and import changes

| Field | Value |
|-------|-------|
| SHA | `36071e5403afe1bf5bc8426e49db987ce23a0bb8` |
| Author | Zacgoose |
| Date | 2026-05-13 14:20:34 +0800 |
| Files changed | 13 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `next.config.js`, `package.json`, `src/components/CippCards/CippStandardsDialog.jsx`, `src/components/CippComponents/CippAppPermissionBuilder.jsx`, `src/components/CippSettings/CippContainerManagement.jsx`, `src/components/CippStandards/CippStandardAccordion.jsx`, `src/components/CippStandards/CippStandardsSideBar.jsx`, `src/components/CippTable/CippDataTable.js`, `src/pages/cipp/advanced/super-admin/container.js`, `src/pages/cipp/settings/features.js`, `src/pages/tenant/standards/bpa-report/view.js`, `src/pages/tenant/standards/templates/template.jsx`, `yarn.lock`

---

### 68. `c0946109` — Fix bulk mailbox rule changes

| Field | Value |
|-------|-------|
| SHA | `c0946109c91b31ee9699ba7dbf377a8f299b1a55` |
| Author | Zacgoose |
| Date | 2026-05-13 16:47:42 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** `src/pages/identity/administration/users/user/exchange.jsx`

---

### 69. `72d8658d` — Add Apps and SP to universal search

| Field | Value |
|-------|-------|
| SHA | `72d8658d5ded1c0f47fddeacb3a384c5cbf0e38d` |
| Author | Zacgoose |
| Date | 2026-05-13 17:06:41 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippCards/CippUniversalSearchV2.jsx`, `src/components/bulk-actions-menu.js`

---

### 70. `ba196dde` — expand side nav slightly for ux

| Field | Value |
|-------|-------|
| SHA | `ba196dde059e16c53ee182a7d49eff8292073e27` |
| Author | KelvinTegelaar |
| Date | 2026-05-13 12:07:00 +0200 |
| Files changed | 2 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `.claude/worktrees/blissful-golick-d405ab`, `src/layouts/side-nav.js`

---

### 71. `8551ef5f` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `8551ef5fd6d78da756930a5c41d783512063ec13` |
| Author | KelvinTegelaar |
| Date | 2026-05-13 12:07:14 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 72. `52a47639` — Nice CA policy editor and template creator/editor

| Field | Value |
|-------|-------|
| SHA | `52a4763907144faafc70dfeb439c705679e24dc0` |
| Author | Zacgoose |
| Date | 2026-05-13 18:52:11 +0800 |
| Files changed | 8 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippCAPolicyBuilder.jsx`, `src/components/CippComponents/CippTemplateFieldRenderer.jsx`, `src/data/conditionalAccessSchema.json`, `src/pages/tenant/conditional/list-policies/edit.jsx`, `src/pages/tenant/conditional/list-policies/index.js`, `src/pages/tenant/conditional/list-template/create.jsx`, `src/pages/tenant/conditional/list-template/edit.jsx`, `src/pages/tenant/conditional/list-template/index.js`

---

### 73. `41efc5b7` — Update CippCAPolicyBuilder.jsx

| Field | Value |
|-------|-------|
| SHA | `41efc5b726d55036beeef036f6d2e2ac7a7e4e80` |
| Author | Zacgoose |
| Date | 2026-05-13 18:54:03 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippCAPolicyBuilder.jsx`

---

### 74. `60a50738` — fixes tenantfilter property

| Field | Value |
|-------|-------|
| SHA | `60a50738fc68fd8b17ea615343f785828c713209` |
| Author | KelvinTegelaar |
| Date | 2026-05-13 21:08:55 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/email/administration/mailbox-rules/index.js`

---

### 75. `c9584010` — chore(deps): bump dompurify from 3.4.2 to 3.4.3

| Field | Value |
|-------|-------|
| SHA | `c958401045bf32a2326446cb24b4550e63b15f75` |
| Author | dependabot[bot] |
| Date | 2026-05-13 23:43:59 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 76. `a783d28a` — chore(deps): bump @tiptap/extension-table from 3.20.4 to 3.20.5

| Field | Value |
|-------|-------|
| SHA | `a783d28ab623dc69767ffd758e5cd140f171f2d5` |
| Author | dependabot[bot] |
| Date | 2026-05-13 23:44:16 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 77. `2285d39c` — chore(deps): bump @tiptap/core from 3.20.5 to 3.22.3

| Field | Value |
|-------|-------|
| SHA | `2285d39cfdfdbbdffe377fbcc357200763f27e84` |
| Author | dependabot[bot] |
| Date | 2026-05-13 23:44:34 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 78. `d392d1cf` — chore(deps): bump @tanstack/react-query from 5.96.2 to 5.100.10

| Field | Value |
|-------|-------|
| SHA | `d392d1cfebf3dd1fc82e50e0cc0fda449814d693` |
| Author | dependabot[bot] |
| Date | 2026-05-13 23:45:13 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 79. `fd6a9e36` — Logs

| Field | Value |
|-------|-------|
| SHA | `fd6a9e36007839cbb51f850ac75b5585726724a0` |
| Author | Zacgoose |
| Date | 2026-05-14 15:38:27 +1000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/layouts/config.js`, `src/pages/cipp/advanced/container-logs.js`

---

### 80. `b5d48bcd` — logging

| Field | Value |
|-------|-------|
| SHA | `b5d48bcddaed40af6839e15ba7a9907c4b22ad33` |
| Author | Zacgoose |
| Date | 2026-05-14 18:09:04 +1000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/data/ContainerLogPresets.json`, `src/pages/cipp/advanced/container-logs.js`

---

### 81. `12a07270` — comingsoon

| Field | Value |
|-------|-------|
| SHA | `12a07270752ea03f3c94eb33f419fdd7336f5985` |
| Author | KelvinTegelaar |
| Date | 2026-05-14 14:34:30 +0200 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `public/assets/integrations/autotask.png`, `public/assets/integrations/connectwise.png`, `public/assets/integrations/kaseya.svg`, `src/data/Extensions.json`, `src/pages/cipp/integrations/index.js`

---

### 82. `db20afa2` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `db20afa205ae565262837d9c43c2fb5ccb3b268a` |
| Author | KelvinTegelaar |
| Date | 2026-05-14 14:34:41 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 83. `c9bfe909` — feat(endpoint): add MEM enrollment profiles page (Apple ADE, Android, Autopilot)

| Field | Value |
|-------|-------|
| SHA | `c9bfe909582d9cc9d308903d7e74b44c6d926087` |
| Author | Bobby |
| Date | 2026-05-14 10:44:12 +0200 |
| Files changed | 8 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippCards/CippUniversalSearchV2.jsx`, `src/components/CippComponents/CippBreadcrumbNav.jsx`, `src/layouts/config.js`, `src/pages/endpoint/MEM/enrollment-profiles/EnrollmentProfileTabs.jsx`, `src/pages/endpoint/MEM/enrollment-profiles/android-enterprise.js`, `src/pages/endpoint/MEM/enrollment-profiles/index.js`, `src/pages/endpoint/MEM/enrollment-profiles/tabOptions.json`, `src/pages/endpoint/MEM/enrollment-profiles/windows-autopilot.js`

---

### 84. `b1902421` — feat: Bit more margin to make tabbed layout of first item less cramped

| Field | Value |
|-------|-------|
| SHA | `b19024214e96bd207640c5e63dcefb38d408e161` |
| Author | Bobby |
| Date | 2026-05-14 16:51:32 +0200 |
| Files changed | 2 |
| Risk | **Low** |
| Area | UI |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: UI improvements |

**Files:** `src/layouts/HeaderedTabbedLayout.jsx`, `src/layouts/TabbedLayout.jsx`

---

### 85. `6dab9339` — feat(tabs): support icons in tabbed layouts

| Field | Value |
|-------|-------|
| SHA | `6dab9339978f195dc8e6db35633071da8f16eb8a` |
| Author | Bobby |
| Date | 2026-05-14 17:50:36 +0200 |
| Files changed | 4 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** `src/layouts/HeaderedTabbedLayout.jsx`, `src/layouts/TabbedLayout.jsx`, `src/pages/endpoint/MEM/enrollment-profiles/tabOptions.json`, `src/utils/icon-registry.js`

---

### 86. `9b616499` — feat: Migrate to use shared icon registry for string to icon conversion

| Field | Value |
|-------|-------|
| SHA | `9b6164999145da5dab8cb726cc2b4d6a25cba44b` |
| Author | Bobby |
| Date | 2026-05-14 18:46:23 +0200 |
| Files changed | 8 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippCards/CippPropertyListCard.jsx`, `src/components/CippCards/CippUniversalSearchV2.jsx`, `src/components/CippComponents/CippTenantSelector.jsx`, `src/components/bulk-actions-menu.js`, `src/data/portals.json`, `src/layouts/HeaderedTabbedLayout.jsx`, `src/layouts/TabbedLayout.jsx`, `src/utils/icon-registry.js`

---

### 87. `983b48a1` — fix: Remove accidentally committed .claude/worktrees directory

| Field | Value |
|-------|-------|
| SHA | `983b48a1b1c35c329c9ad8405635c26e6859b0b9` |
| Author | Clint Thomon |
| Date | 2026-05-14 13:59:43 -0500 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `.claude/worktrees/blissful-golick-d405ab`, `.gitignore`

---

### 88. `0c32a84e` — Add additional portal links to Invoke-HuduExtensionSync

| Field | Value |
|-------|-------|
| SHA | `0c32a84eb21d3df3a719427b54d10821a94b40a4` |
| Author | jwebster@protectedtrust.com |
| Date | 2026-05-14 16:26:44 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | API |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: API endpoint changes |

**Files:** `src/data/Extensions.json`

---

### 89. `186a2c6e` — audit log template tweak

| Field | Value |
|-------|-------|
| SHA | `186a2c6ea22589ca28f655eba01526ceb74ec2d9` |
| Author | Zacgoose |
| Date | 2026-05-15 02:29:31 -0500 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/data/AuditLogTemplates.json`, `src/layouts/config.js`, `src/pages/cipp/advanced/worker-health.js`

---

### 90. `7a85827e` — feat(users): add bulk update contact and UPN fields

| Field | Value |
|-------|-------|
| SHA | `7a85827ef1072955a48cb1d48c3ce2aafe3ab88d` |
| Author | Bobby |
| Date | 2026-05-15 16:34:51 +0200 |
| Files changed | 1 |
| Risk | **Low** |
| Area | UI |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: UI improvements |

**Files:** `src/pages/identity/administration/users/patch-wizard.jsx`

---

### 91. `8232e5c1` — feat(standards): add intuneRestrictUserDeviceJoin entry

| Field | Value |
|-------|-------|
| SHA | `8232e5c11b26c897151d6daaaaa74f8288f52110` |
| Author | Bobby |
| Date | 2026-05-15 20:30:01 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** `src/data/standards.json`

---

### 92. `f768330c` — fix(standards): move CIS 5.1.4.1 and SMB1001 (2.8) tags to join standard

| Field | Value |
|-------|-------|
| SHA | `f768330cd45a2b2e1f6a7cae857b7a5e2ec7d999` |
| Author | Bobby |
| Date | 2026-05-15 20:30:31 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/data/standards.json`

---

### 93. `9d5ce402` — Org auto expanding archive property usage

| Field | Value |
|-------|-------|
| SHA | `9d5ce40275098a4a442d247fe42541958d08ba88` |
| Author | Zacgoose |
| Date | 2026-05-18 07:27:51 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippCards/CippExchangeInfoCard.jsx`

---

### 94. `6db7e776` — Delete .claude directory

| Field | Value |
|-------|-------|
| SHA | `6db7e7760fc02807df809897fcda40b48a8b365b` |
| Author | Zacgoose |
| Date | 2026-05-18 14:37:01 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `.claude/worktrees/blissful-golick-d405ab`

---

### 95. `1e7aef11` — Update alerts.json

| Field | Value |
|-------|-------|
| SHA | `1e7aef11995feb42e9872ec4aefac39fc7ba67c5` |
| Author | Zacgoose |
| Date | 2026-05-19 08:19:29 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/alerts.json`

---

### 96. `fc246a54` — update default value for standard

| Field | Value |
|-------|-------|
| SHA | `fc246a54ee6c1720f9d442f4cf22568b53add85d` |
| Author | Zacgoose |
| Date | 2026-05-19 10:02:02 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 97. `766a3c52` — feat: add in missing options for Windows Hello standard

| Field | Value |
|-------|-------|
| SHA | `766a3c52814dcc09d9170c780b4caa5e59d7a343` |
| Author | Bobby |
| Date | 2026-05-20 22:10:11 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 98. `5b5302ca` — feat(standards): add DLP via DCS OWA standard

| Field | Value |
|-------|-------|
| SHA | `5b5302ca907b971e86c5ed5fd8c1f56491f796c8` |
| Author | Bobby |
| Date | 2026-05-20 23:18:38 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 99. `131927b9` — Stats

| Field | Value |
|-------|-------|
| SHA | `131927b943aebebd6844ba986fbcf30fb21ac8bc` |
| Author | Zacgoose |
| Date | 2026-05-22 12:51:00 -0400 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/PrivateRoute.js`, `src/layouts/index.js`, `src/pages/cipp/advanced/worker-health.js`

---

### 100. `a6ae2610` — Add Group-Based Licensing support

| Field | Value |
|-------|-------|
| SHA | `a6ae2610d2bf4977dc4ff0a63979d32f263cf440` |
| Author | Luis Mengel |
| Date | 2026-05-23 15:21:33 +0200 |
| Files changed | 6 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows, Standards/Alignment Custom; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippFormLicenseSelector.jsx`, `src/components/CippFormPages/CippAddGroupForm.jsx`, `src/components/CippFormPages/CippAddGroupTemplateForm.jsx`, `src/components/CippWizard/CippWizardGroupTemplates.jsx`, `src/pages/identity/administration/group-templates/edit.jsx`, `src/pages/identity/administration/groups/edit.jsx`

---

### 101. `c74966b3` — Merge pull request #6018 from kris6673/bulk-edit

| Field | Value |
|-------|-------|
| SHA | `c74966b3aeb084e181626cc9e7c3b91d05af5350` |
| Author | KelvinTegelaar |
| Date | 2026-05-23 16:39:33 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 102. `5574b477` — Merge pull request #6038 from kris6673/winhello

| Field | Value |
|-------|-------|
| SHA | `5574b4779a5ca2600070ce3fc37e939d5a54a466` |
| Author | KelvinTegelaar |
| Date | 2026-05-23 16:41:22 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 103. `fad1cacf` — Merge pull request #6019 from kris6673/split-intune-join-registration

| Field | Value |
|-------|-------|
| SHA | `fad1cacfe9936eef973d5dc6b41447e3220376bd` |
| Author | KelvinTegelaar |
| Date | 2026-05-23 16:42:33 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** (none)

---

### 104. `96686d7e` — Merge pull request #6012 from jonwbstr/magicdash-addoptions

| Field | Value |
|-------|-------|
| SHA | `96686d7e90cc1dbd88ac6b30bebc74888dac4841` |
| Author | KelvinTegelaar |
| Date | 2026-05-23 16:46:30 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 105. `bde8ad3c` — Merge pull request #6010 from Celeratec/fix/remove-claude-worktrees

| Field | Value |
|-------|-------|
| SHA | `bde8ad3cfea1197e04b2dff8ac0b93e944566f7f` |
| Author | KelvinTegelaar |
| Date | 2026-05-23 16:49:24 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** (none)

---

### 106. `a3279044` — CIPP Hosted Notices

| Field | Value |
|-------|-------|
| SHA | `a32790443fc1297fab6900acc498df9cff107aa0` |
| Author | Zacgoose |
| Date | 2026-05-24 09:13:35 +1000 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/FailedPaymentDialog.jsx`, `src/components/CippComponents/SubscriptionEndedDialog.jsx`, `src/layouts/index.js`

---

### 107. `04c63849` — implement standards template deployment for intune apps

| Field | Value |
|-------|-------|
| SHA | `04c63849f689bbd2686fb473cbaef1462a1d1b99` |
| Author | KelvinTegelaar |
| Date | 2026-05-24 22:41:10 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** `src/data/standards.json`

---

### 108. `28cafc93` — added third party notice

| Field | Value |
|-------|-------|
| SHA | `28cafc931d46c705b3481a1e5bd185b39ca8879d` |
| Author | KelvinTegelaar |
| Date | 2026-05-24 23:06:16 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/integrations/index.js`

---

### 109. `30455f27` — third party

| Field | Value |
|-------|-------|
| SHA | `30455f273d7cfcba5add1012bc260bb789f7c405` |
| Author | KelvinTegelaar |
| Date | 2026-05-24 23:06:35 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/integrations/index.js`

---

### 110. `d4f458a1` — Third party text

| Field | Value |
|-------|-------|
| SHA | `d4f458a15b67d7c8cdd8b8095d3a638a040a9dd4` |
| Author | KelvinTegelaar |
| Date | 2026-05-24 23:07:33 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/integrations/index.js`

---

### 111. `ee0ab2ab` — add extendedValues

| Field | Value |
|-------|-------|
| SHA | `ee0ab2abe3341bd2f0270391f36e781f6f4ef8d2` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 00:13:35 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippFormPages/CippAddEditUser.jsx`, `src/pages/tenant/manage/user-defaults.js`

---

### 112. `17bf1f8d` — fixes #5995

| Field | Value |
|-------|-------|
| SHA | `17bf1f8dbbd6fe16a63fa268c60dfa8fe8a0c053` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 00:14:08 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Tenant management changes, Potentially breaking changes |

**Files:** `src/pages/tenant/manage/user-defaults.js`

---

### 113. `8097e6ed` — FIDO2 profile standards

| Field | Value |
|-------|-------|
| SHA | `8097e6ede3991b61e65b03bd21496dc55c96bc33` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 01:34:03 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 114. `389babe3` — add global var showing

| Field | Value |
|-------|-------|
| SHA | `389babe3e5641be1363afed31b78eddd1a0e3949` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 01:58:14 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippCustomVariables.jsx`

---

### 115. `3bdb9d5b` — add global var showing

| Field | Value |
|-------|-------|
| SHA | `3bdb9d5b4de432f5a319d2c0e90b43462d4e82f1` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 01:58:18 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippCustomVariables.jsx`

---

### 116. `c43f6d9a` — Update unauthenticated.js

| Field | Value |
|-------|-------|
| SHA | `c43f6d9ab5f013d386dcb52237e61754efe3ee0d` |
| Author | Zacgoose |
| Date | 2026-05-25 08:02:23 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** `src/pages/unauthenticated.js`

---

### 117. `f591d479` — logout

| Field | Value |
|-------|-------|
| SHA | `f591d4790012f7fd747433f6eb65f1e30f7f6dd6` |
| Author | Zacgoose |
| Date | 2026-05-25 11:10:02 +0800 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/SsoMigrationDialog.jsx`, `src/layouts/account-popover.js`, `src/layouts/index.js`

---

### 118. `16b4503f` — login/out testing

| Field | Value |
|-------|-------|
| SHA | `16b4503f014b4d5b99ff0e49485dcc97544e3cee` |
| Author | Zacgoose |
| Date | 2026-05-25 11:29:56 +0800 |
| Files changed | 2 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `src/layouts/account-popover.js`, `staticwebapp.config.json`

---

### 119. `c1c5693c` — feat: add admin role member removal functionality

| Field | Value |
|-------|-------|
| SHA | `c1c5693c09ef99c196b80d17b4b8aeb61f1d9852` |
| Author | Bobby |
| Date | 2026-05-25 11:49:27 +0200 |
| Files changed | 2 |
| Risk | **Medium** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** `src/pages/identity/administration/roles/index.js`, `src/pages/identity/administration/users/user/index.jsx`

---

### 120. `38e72f99` — Add APv2 profile

| Field | Value |
|-------|-------|
| SHA | `38e72f99f64ab21449ad7588becbd2c35fb80646` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:29:31 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 121. `304e0e5a` — Merge pull request #6052 from kris6673/remove-adminroles

| Field | Value |
|-------|-------|
| SHA | `304e0e5a21017ffd1a384906891cdee6f2bcb472` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:31:34 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** (none)

---

### 122. `d8c4988d` — Merge pull request #6039 from kris6673/DlpViaDcsEnabled

| Field | Value |
|-------|-------|
| SHA | `d8c4988d120bfe295699b783912d1987b5faf84c` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:32:40 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 123. `28ec38c1` — Merge pull request #6009 from kris6673/ade

| Field | Value |
|-------|-------|
| SHA | `28ec38c1c67606d204e23cf26bec9acc11201292` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:35:36 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 124. `ac1190da` — Merge pull request #6003 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tanstack/react-query-5.100.10

| Field | Value |
|-------|-------|
| SHA | `ac1190da4417434b740ce99cee3de5f4ad9edc44` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:37:12 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 125. `2e1e3007` — Merge pull request #6001 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tiptap/core-3.22.3

| Field | Value |
|-------|-------|
| SHA | `2e1e30074fdc2db898f4449bcd93d69351e05344` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:37:31 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 126. `4ffb7638` — Merge pull request #6000 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tiptap/extension-table-3.20.5

| Field | Value |
|-------|-------|
| SHA | `4ffb7638952ef2ad242a073493fa7fb8c49a448d` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:37:42 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 127. `0001b6c8` — Merge pull request #5999 from KelvinTegelaar/dependabot/npm_and_yarn/dev/dompurify-3.4.3

| Field | Value |
|-------|-------|
| SHA | `0001b6c82cb49b7200904f89240c5028da5ef136` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 14:37:58 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 128. `83994360` — chore(deps): bump react from 19.2.5 to 19.2.6

| Field | Value |
|-------|-------|
| SHA | `839943607b846de806fb5f0694dd9dc479fcf7df` |
| Author | dependabot[bot] |
| Date | 2026-05-25 12:40:46 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 129. `8a179d28` — moved autopilot ade etc

| Field | Value |
|-------|-------|
| SHA | `8a179d2886027c1cd9e17eb7277bbe1c6d08ea2a` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 15:05:27 +0200 |
| Files changed | 4 |
| Risk | **High** |
| Area | Intune |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Intune changes, Potentially breaking changes |

**Files:** `src/layouts/config.js`, `src/pages/endpoint/MEM/enrollment-profiles/apple-ade.js`, `src/pages/endpoint/MEM/enrollment-profiles/index.js`, `src/pages/endpoint/MEM/enrollment-profiles/tabOptions.json`

---

### 130. `ff9af7e0` — add tutorials to easy deployment of steps for Ashe.

| Field | Value |
|-------|-------|
| SHA | `ff9af7e0d8de76f1902de17cd9b4cf7614b3c39d` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 18:30:53 +0200 |
| Files changed | 14 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `src/components/CippComponents/CippBreadcrumbNav.jsx`, `src/components/CippComponents/CippSpeedDial.jsx`, `src/components/CippComponents/CippTutorialDialog.jsx`, `src/contexts/tutorial-context.js`, `src/data/tutorials/dashboard-overview.json`, `src/data/tutorials/getting-started.json`, `src/data/tutorials/tenant-management.json`, `src/layouts/side-nav.js`, `src/layouts/top-nav.js`, `src/pages/_app.js`, `src/pages/dashboardv2/index.js`, `src/styles/tutorial-overrides.css`, `yarn.lock`

---

### 131. `eac59c8a` — add tutorials to easy deployment of steps for Ashe.

| Field | Value |
|-------|-------|
| SHA | `eac59c8ac8d55c4a2a4f81e3016f64747d85d4fc` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 18:31:00 +0200 |
| Files changed | 7 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippBreadcrumbNav.jsx`, `src/components/CippComponents/CippSpeedDial.jsx`, `src/components/CippComponents/CippTutorialDialog.jsx`, `src/contexts/tutorial-context.js`, `src/layouts/top-nav.js`, `src/pages/dashboardv2/index.js`, `src/styles/tutorial-overrides.css`

---

### 132. `6a51abf3` — demo data

| Field | Value |
|-------|-------|
| SHA | `6a51abf309207078b9429ed62eaa03eceb8280b3` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 20:37:52 +0200 |
| Files changed | 2 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/contexts/tutorial-context.js`, `src/data/dashboardv2-demo-data.js`

---

### 133. `37778e28` — Merge pull request #6002 from KelvinTegelaar/dependabot/npm_and_yarn/dev/react-19.2.6

| Field | Value |
|-------|-------|
| SHA | `37778e2872d9b994494603f626c1a4acba3e4c7d` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 21:30:54 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 134. `a2d8f191` — react-dom

| Field | Value |
|-------|-------|
| SHA | `a2d8f1918f67ed864a57e50e55f8fd3f949774a9` |
| Author | KelvinTegelaar |
| Date | 2026-05-25 21:32:56 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`

---

### 135. `7d1c2096` — Move EnrollmentProfileTabs from pages to components and update imports

| Field | Value |
|-------|-------|
| SHA | `7d1c2096f820f505684167d28bf38487534bd5ff` |
| Author | copilot-swe-agent[bot] |
| Date | 2026-05-25 23:09:50 +0000 |
| Files changed | 5 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** `src/components/EnrollmentProfileTabs.jsx`, `src/pages/endpoint/MEM/enrollment-profiles/android-enterprise.js`, `src/pages/endpoint/MEM/enrollment-profiles/apple-ade.js`, `src/pages/endpoint/MEM/enrollment-profiles/index.js`, `src/pages/endpoint/MEM/enrollment-profiles/windows-autopilot.js`

---

### 136. `02c7a434` — Move EnrollmentProfileTabs to CippComponents folder and update imports

| Field | Value |
|-------|-------|
| SHA | `02c7a4341ca6d9ceb016ed45d10f0e188bce6a26` |
| Author | copilot-swe-agent[bot] |
| Date | 2026-05-25 23:13:28 +0000 |
| Files changed | 5 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/EnrollmentProfileTabs.jsx`, `src/pages/endpoint/MEM/enrollment-profiles/android-enterprise.js`, `src/pages/endpoint/MEM/enrollment-profiles/apple-ade.js`, `src/pages/endpoint/MEM/enrollment-profiles/index.js`, `src/pages/endpoint/MEM/enrollment-profiles/windows-autopilot.js`

---

### 137. `8145f585` — Merge pull request #6056 from KelvinTegelaar/copilot/move-enrollment-profile-tabs

| Field | Value |
|-------|-------|
| SHA | `8145f585d73328645f2354a284bf769405a69092` |
| Author | Zacgoose |
| Date | 2026-05-25 19:14:54 -0400 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 138. `1e59d2d4` — Update ListTests.json

| Field | Value |
|-------|-------|
| SHA | `1e59d2d43fab463a709d1dac2477f45cfacdfae6` |
| Author | Zacgoose |
| Date | 2026-05-26 11:54:57 +0800 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `Tests/Shapes/ListTests.json`

---

### 139. `1cd1ef72` — Update AuditLogTemplates.json

| Field | Value |
|-------|-------|
| SHA | `1cd1ef7223672170bdce1fffe88d8bb4ddb903d9` |
| Author | Zacgoose |
| Date | 2026-05-26 12:30:37 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/AuditLogTemplates.json`

---

### 140. `ca150a28` — Better display standards that are missing licenses to be able to work

| Field | Value |
|-------|-------|
| SHA | `ca150a28cfcb3922d6de42cb4db54f2afcdf6e0e` |
| Author | Zacgoose |
| Date | 2026-05-26 15:08:56 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Tenant management changes, Potentially breaking changes |

**Files:** `src/pages/tenant/manage/applied-standards.js`

---

### 141. `f3c8a79e` — Update yarn.lock

| Field | Value |
|-------|-------|
| SHA | `f3c8a79e42e97ad5b0cad9889ce15e4863f6bef8` |
| Author | Zacgoose |
| Date | 2026-05-26 15:09:04 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `yarn.lock`

---

### 142. `d28e8ebf` — user sync

| Field | Value |
|-------|-------|
| SHA | `d28e8ebfaa9517e5f2134bb1c339d294096dca91` |
| Author | Zacgoose |
| Date | 2026-05-26 23:33:43 +0800 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippSettings/CippRoleAddEdit.jsx`, `src/components/CippSettings/CippUserManagement.jsx`, `src/pages/cipp/advanced/super-admin/cipp-users.js`

---

### 143. `2f62bae9` — Update CippAuditLogSearchDrawer.jsx

| Field | Value |
|-------|-------|
| SHA | `2f62bae921c333f7a0b72f78ce02aab8b0980d55` |
| Author | Zacgoose |
| Date | 2026-05-27 00:13:18 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippAuditLogSearchDrawer.jsx`

---

### 144. `25f4caed` — feat: add permanent dismissal option for release notes

| Field | Value |
|-------|-------|
| SHA | `25f4caed93e9c722f359ea7d0f6ea3af75843716` |
| Author | Bobby |
| Date | 2026-05-27 00:37:35 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | UI |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Manage365 Branding/Versioning; Buckets: UI improvements, Potentially breaking changes |

**Files:** `src/components/ReleaseNotesDialog.js`

---

### 145. `fe4765e8` — Merge pull request #6059 from kris6673/permaDismiss

| Field | Value |
|-------|-------|
| SHA | `fe4765e892bdd13c890781d8c9311116da355bf5` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 01:09:02 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 146. `1b7797af` — Update standards.json

| Field | Value |
|-------|-------|
| SHA | `1b7797afd4f4c55e6a44157a87914daf8110068f` |
| Author | Zacgoose |
| Date | 2026-05-27 16:29:15 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 147. `de70889f` — smart lockout standard

| Field | Value |
|-------|-------|
| SHA | `de70889fe1c4e157ac25eb1ef43751add88056fa` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 14:39:44 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 148. `0e527e50` — Sharepoint management functionality.

| Field | Value |
|-------|-------|
| SHA | `0e527e50d858628dbe0943c33c0b67b18949d612` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 17:03:29 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Teams |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 149. `5709f856` — fix: update terminology from "Temporary Access Password" to "Temporary Access Pass"

| Field | Value |
|-------|-------|
| SHA | `5709f85661a047dad29216739acccf6326c9231b` |
| Author | Bobby |
| Date | 2026-05-27 17:11:46 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippUserActions.jsx`, `src/data/standards.json`

---

### 150. `4102a13e` — Merge pull request #6064 from kris6673/TAP-typos

| Field | Value |
|-------|-------|
| SHA | `4102a13e6b58656cf4e29a9f36d3930df7a92fa1` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 18:56:03 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 151. `bf6056ba` — Add version cleanup

| Field | Value |
|-------|-------|
| SHA | `bf6056baf362471dba4ecbb599e0b1c85091b8d0` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 20:24:47 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Teams |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/pages/teams-share/sharepoint/index.js`

---

### 152. `0abf5523` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `0abf5523a012a07f73982ed92a41a7b5e063e005` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 20:24:57 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 153. `635548af` — Add version cleanup

| Field | Value |
|-------|-------|
| SHA | `635548afd1d988518d8c392413828aec7e39eda5` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 20:25:01 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Teams |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/pages/teams-share/sharepoint/index.js`

---

### 154. `7a408542` — fix query keys

| Field | Value |
|-------|-------|
| SHA | `7a40854272a60617d57a28570406953a9cca913c` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 20:37:02 +0200 |
| Files changed | 4 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** `src/pages/security/compliance/dlp/index.js`, `src/pages/security/compliance/labels/index.js`, `src/pages/security/compliance/retention/index.js`, `src/pages/security/compliance/sit/index.js`

---

### 155. `de035243` — fixes #6065

| Field | Value |
|-------|-------|
| SHA | `de035243aa1090ac818cc2d02e651007a90723e1` |
| Author | KelvinTegelaar |
| Date | 2026-05-27 20:59:42 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Tenant management changes, Potentially breaking changes |

**Files:** `src/pages/tenant/manage/user-defaults.js`

---

### 156. `d0f58cbe` — feat(mailboxes): show mailbox and archive size columns

| Field | Value |
|-------|-------|
| SHA | `d0f58cbebd48dbdeaddfcf3af0f68d7b4320bec8` |
| Author | Bobby |
| Date | 2026-05-27 22:43:01 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/email/administration/mailboxes/index.js`, `src/utils/get-cipp-formatting.js`

---

### 157. `072416dd` — new autopatch standard

| Field | Value |
|-------|-------|
| SHA | `072416dd95fb955625d466022ebb4a05847e76e3` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 00:54:29 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 158. `f256c253` — chore(deps): bump react-virtuoso from 4.18.5 to 4.18.7

| Field | Value |
|-------|-------|
| SHA | `f256c253bff5710aab52bbcb21d64d2775df27b7` |
| Author | dependabot[bot] |
| Date | 2026-05-28 00:38:36 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 159. `8316c600` — chore(deps): bump @react-pdf/renderer from 4.3.2 to 4.5.1

| Field | Value |
|-------|-------|
| SHA | `8316c600205322891849d6b211f01c7237971c62` |
| Author | dependabot[bot] |
| Date | 2026-05-28 00:38:54 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 160. `49192881` — chore(deps): bump axios from 1.15.0 to 1.16.1

| Field | Value |
|-------|-------|
| SHA | `49192881a81a4599d990755b85393a767c16acf8` |
| Author | dependabot[bot] |
| Date | 2026-05-28 00:39:08 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 161. `c04cd7c9` — chore(deps): bump @tiptap/extension-heading from 3.20.5 to 3.22.3

| Field | Value |
|-------|-------|
| SHA | `c04cd7c9f6d2c487440aa334d6d4f3a8c3773f67` |
| Author | dependabot[bot] |
| Date | 2026-05-28 00:39:27 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 162. `0995677d` — chore(deps): bump react-hook-form from 7.72.0 to 7.76.1

| Field | Value |
|-------|-------|
| SHA | `0995677d8e4f32b35699ffe220c3b8726f015356` |
| Author | dependabot[bot] |
| Date | 2026-05-28 00:39:39 +0000 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `yarn.lock`

---

### 163. `b8ece5c4` — Update worker-health.js

| Field | Value |
|-------|-------|
| SHA | `b8ece5c448ee814f5400dacaaee9a3590c911cde` |
| Author | Zacgoose |
| Date | 2026-05-28 13:56:39 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/advanced/worker-health.js`

---

### 164. `ab8de98d` — Update worker-health.js

| Field | Value |
|-------|-------|
| SHA | `ab8de98d1c4c1ce1c8cd200962f13ebeae1416e6` |
| Author | Zacgoose |
| Date | 2026-05-28 15:21:20 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/advanced/worker-health.js`

---

### 165. `ca43bc9e` — Update worker-health.js

| Field | Value |
|-------|-------|
| SHA | `ca43bc9e04e0bc662de24be73466f1b9a18044eb` |
| Author | Zacgoose |
| Date | 2026-05-28 20:51:17 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/advanced/worker-health.js`

---

### 166. `7e44aff8` — new auth methods single standard

| Field | Value |
|-------|-------|
| SHA | `7e44aff88a1ff1fbb29e8d3a9fb9aa5c70c1b504` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 15:21:13 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** `src/data/standards.json`

---

### 167. `8306a660` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `8306a660288391bfd031b6f51bc45e7de8aa6dc9` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 15:21:21 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 168. `04f8575c` — Merge pull request #6070 from kris6673/6061

| Field | Value |
|-------|-------|
| SHA | `04f8575caa54883b3256e920aa840e45d29cba1f` |
| Author | KelvinTegelaar |
| Date | 2026-05-28 16:21:22 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 169. `605ecd82` — fix: move ADE pages

| Field | Value |
|-------|-------|
| SHA | `605ecd8272e8e6c5d6eaba7692fa0d3ddb22c745` |
| Author | Bobby |
| Date | 2026-05-28 21:13:05 +0200 |
| Files changed | 6 |
| Risk | **High** |
| Area | Intune |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Intune changes, Potentially breaking changes |

**Files:** `src/layouts/config.js`, `src/pages/endpoint/autopilot/enrollment-profiles/android-enterprise.js`, `src/pages/endpoint/autopilot/enrollment-profiles/apple-ade.js`, `src/pages/endpoint/autopilot/enrollment-profiles/index.js`, `src/pages/endpoint/autopilot/enrollment-profiles/tabOptions.json`, `src/pages/endpoint/autopilot/enrollment-profiles/windows-autopilot.js`

---

### 170. `063550f4` — chore: update tab paths and imports

| Field | Value |
|-------|-------|
| SHA | `063550f430ee43d716ae24a1e7834d10e2aa3014` |
| Author | Bobby |
| Date | 2026-05-28 21:20:53 +0200 |
| Files changed | 5 |
| Risk | **Medium** |
| Area | Intune |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Intune changes |

**Files:** `src/pages/endpoint/autopilot/enrollment-profiles/android-enterprise.js`, `src/pages/endpoint/autopilot/enrollment-profiles/apple-ade.js`, `src/pages/endpoint/autopilot/enrollment-profiles/index.js`, `src/pages/endpoint/autopilot/enrollment-profiles/tabOptions.json`, `src/pages/endpoint/autopilot/enrollment-profiles/windows-autopilot.js`

---

### 171. `d0405ff4` — feat: Add icons to the tabs and remove dead tab

| Field | Value |
|-------|-------|
| SHA | `d0405ff45e5ad572438e007734a93f2b5a3b69f0` |
| Author | Bobby |
| Date | 2026-05-28 22:45:31 +0200 |
| Files changed | 22 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/advanced/super-admin/tabOptions.json`, `src/pages/cipp/custom-data/tabOptions.json`, `src/pages/cipp/settings/tabOptions.json`, `src/pages/dashboardv2/tabOptions.json`, `src/pages/email/administration/exchange-retention/tabOptions.json`, `src/pages/endpoint/MEM/devices/device/tabOptions.json`, `src/pages/identity/administration/groups/group/tabOptions.json`, `src/pages/identity/administration/users/user/devices.jsx`, `src/pages/identity/administration/users/user/tabOptions.json`, `src/pages/tenant/administration/alert-configuration/tabOptions.json`, `src/pages/tenant/administration/applications/app-registration/tabOptions.json`, `src/pages/tenant/administration/applications/enterprise-app/tabOptions.json`, `src/pages/tenant/administration/applications/tabOptions.json`, `src/pages/tenant/administration/audit-logs/tabOptions.json`, `src/pages/tenant/administration/securescore/tabOptions.json` … (+7 more)

---

### 172. `707873e3` — fix: Fix tab title showing as undefined

| Field | Value |
|-------|-------|
| SHA | `707873e31e3b9fae7504dea81643f7bf673a1bef` |
| Author | Bobby |
| Date | 2026-05-28 23:24:30 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/email/administration/exchange-retention/policies/index.js`, `src/pages/email/administration/exchange-retention/tags/index.js`

---

### 173. `97d77727` — Expose missing standards and allow removal

| Field | Value |
|-------|-------|
| SHA | `97d77727f602177fbb52643ff24697fe4c394717` |
| Author | Zacgoose |
| Date | 2026-05-29 16:31:56 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippStandards/CippStandardAccordion.jsx`

---

### 174. `c0bfd7df` — Update standards.json

| Field | Value |
|-------|-------|
| SHA | `c0bfd7df29808523b2ab94847fff8b7736681c43` |
| Author | Zacgoose |
| Date | 2026-05-29 17:43:25 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/standards.json`

---

### 175. `9e44f394` — Update worker-health.js

| Field | Value |
|-------|-------|
| SHA | `9e44f394d5d975b69dcc1a096a101ab27720bcf9` |
| Author | Zacgoose |
| Date | 2026-05-30 22:49:02 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/advanced/worker-health.js`

---

### 176. `6737dcb7` — Licence Universal Search

| Field | Value |
|-------|-------|
| SHA | `6737dcb7df0ad4e21a4edf4979dfc2f30e49510f` |
| Author | Zacgoose |
| Date | 2026-06-02 00:08:49 +0800 |
| Files changed | 6 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippCards/CippUniversalSearchV2.jsx`, `src/components/CippComponents/CippLicenseDetailsDrawer.jsx`, `src/data/M365Licenses.json`, `src/layouts/top-nav.js`, `src/utils/get-cipp-license-catalog.js`, `src/utils/icon-registry.js`

---

### 177. `e2c39b26` — Update M365Licenses.json

| Field | Value |
|-------|-------|
| SHA | `e2c39b26d95394b3095a28f03e9dccb7a8085afa` |
| Author | Zacgoose |
| Date | 2026-06-02 00:09:49 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/M365Licenses.json`

---

### 178. `3734adee` — Fix template trigger

| Field | Value |
|-------|-------|
| SHA | `3734adeeaec92e6d83974590c36a9e91bf024a98` |
| Author | KelvinTegelaar |
| Date | 2026-06-01 23:44:55 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Tenant management changes, Potentially breaking changes |

**Files:** `src/pages/tenant/manage/user-defaults.js`

---

### 179. `ee6f501e` — Merge pull request #6079 from kris6673/move-ADE

| Field | Value |
|-------|-------|
| SHA | `ee6f501eadb0069a8260f61ba175767584cb353b` |
| Author | KelvinTegelaar |
| Date | 2026-06-02 00:23:58 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 180. `d26084fb` — Merge pull request #6080 from kris6673/icons

| Field | Value |
|-------|-------|
| SHA | `d26084fb3923e10f615506e3585ae1c7027c4a7d` |
| Author | KelvinTegelaar |
| Date | 2026-06-02 00:24:29 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 181. `49cda6e0` — Update index.js

| Field | Value |
|-------|-------|
| SHA | `49cda6e0b465ad7bb9a0a259a9ee31a2584e0835` |
| Author | Zacgoose |
| Date | 2026-06-02 07:28:27 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Tenant management changes |

**Files:** `src/pages/tenant/reports/list-licenses/index.js`

---

### 182. `f1703f04` — Update CippTenantModeDeploy.jsx

| Field | Value |
|-------|-------|
| SHA | `f1703f041f517d7d07ca35074a89743f1991141f` |
| Author | Zacgoose |
| Date | 2026-06-02 15:15:54 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippWizard/CippTenantModeDeploy.jsx`

---

### 183. `89abbf50` — fix: improve stale issue and close messages for clarity

| Field | Value |
|-------|-------|
| SHA | `89abbf507b2f96ea9a9238536bd95fe99a1b3b37` |
| Author | Bobby |
| Date | 2026-06-02 19:03:13 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `.github/workflows/Close_Stale_Issues.yml`

---

### 184. `069d6d6b` — Merge pull request #6101 from kris6673/stale

| Field | Value |
|-------|-------|
| SHA | `069d6d6bb070af166c583fb59c224e21f16e6263` |
| Author | KelvinTegelaar |
| Date | 2026-06-02 23:40:55 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 185. `d4570de5` — Update CippReportToolbar.jsx

| Field | Value |
|-------|-------|
| SHA | `d4570de5058eba87c7f9e122a39d41bdedbc401c` |
| Author | Zacgoose |
| Date | 2026-06-03 07:10:49 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippReportToolbar.jsx`

---

### 186. `cbd6faef` — Correct report builder permissions

| Field | Value |
|-------|-------|
| SHA | `cbd6faefb184a7ee611063726862d2663bb56d4b` |
| Author | Zacgoose |
| Date | 2026-06-03 13:15:25 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/tools/report-builder/builder/index.js`, `src/pages/tools/report-builder/view/index.js`

---

### 187. `4d88e456` — Update CippAutocomplete.jsx

| Field | Value |
|-------|-------|
| SHA | `4d88e456cf5e581dbbd30cc6e348059e410d7f9c` |
| Author | Zacgoose |
| Date | 2026-06-03 14:49:31 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippAutocomplete.jsx`

---

### 188. `51d2828b` — add mcp allowed

| Field | Value |
|-------|-------|
| SHA | `51d2828b77990f8a3d017d69206c7b0a3df0f832` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 13:37:01 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippIntegrations/CippApiClientManagement.jsx`

---

### 189. `e4009f28` — feat: add Email as alternate login ID standard

| Field | Value |
|-------|-------|
| SHA | `e4009f28e0aeb0f338cfeeed606b24fec26b05b7` |
| Author | Bobby |
| Date | 2026-06-03 16:54:12 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** `src/data/standards.json`

---

### 190. `38ac0c4a` — MCP warning

| Field | Value |
|-------|-------|
| SHA | `38ac0c4a46f6c1e5f405bd429bae7accd43a1917` |
| Author | KelvinTegelaar |
| Date | 2026-06-03 19:25:42 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippFormComponent.jsx`, `src/components/CippIntegrations/CippApiClientManagement.jsx`

---

### 191. `b2f8f803` — feat: add actions for managing mailbox client access protocols

| Field | Value |
|-------|-------|
| SHA | `b2f8f80372d5c6a28ef57ea373708cd3287f3a8a` |
| Author | Bobby |
| Date | 2026-06-03 19:24:53 +0200 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** `src/pages/email/reports/mailbox-cas-settings/index.js`

---

### 192. `692c67d6` — fix: quarantine deny action

| Field | Value |
|-------|-------|
| SHA | `692c67d6451811f01fdcd7fd021a9b9273efd233` |
| Author | John Duprey |
| Date | 2026-06-03 21:33:18 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal; Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** `src/pages/email/administration/quarantine/index.js`

---

### 193. `a8048476` — Exclude partner tenant

| Field | Value |
|-------|-------|
| SHA | `a80484765aea42b43c1e663d0a9a9295f3795ad9` |
| Author | Zacgoose |
| Date | 2026-06-04 16:03:41 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippAddEditTenantGroups.jsx`, `src/pages/tenant/administration/tenants/groups/edit.js`

---

### 194. `72623261` — add excludeFromAlert to licenses.

| Field | Value |
|-------|-------|
| SHA | `726232611922cf2c302a7e77254ba881e074f4d8` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:21:35 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/settings/licenses.js`

---

### 195. `a04ed1a6` — Merge pull request #6049 from luimen6/feat/group-license-management

| Field | Value |
|-------|-------|
| SHA | `a04ed1a6e283f55ccaedcd6214a65ad51633077f` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:24:44 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | UI |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: UI improvements |

**Files:** (none)

---

### 196. `cf30b4b1` — add excluded from alerts to licenses

| Field | Value |
|-------|-------|
| SHA | `cf30b4b19c0feee4b4429777e51b1c06720d51c0` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:25:03 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/settings/licenses.js`

---

### 197. `11ecd334` — remove unneeded results key

| Field | Value |
|-------|-------|
| SHA | `11ecd3342338bf46f214a62137d6ad4482410ab3` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:25:26 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Standards/Alignment Custom; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippFormLicenseSelector.jsx`

---

### 198. `a9ed024d` — Merge pull request #6110 from kris6673/CAS-stuffs

| Field | Value |
|-------|-------|
| SHA | `a9ed024df2737538eedb25ba3d727be386727c10` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:36:45 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 199. `02db7307` — Merge pull request #6106 from kris6673/EmailAsAlternateLoginId

| Field | Value |
|-------|-------|
| SHA | `02db7307dde8a9ed0e01e0d2a7b8badc7b31c0ed` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 12:37:08 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** (none)

---

### 200. `3daf8b33` — Add named location editing to CA template editor

| Field | Value |
|-------|-------|
| SHA | `3daf8b33cad3a4c9df81c87703758cab2d3150aa` |
| Author | Zacgoose |
| Date | 2026-06-04 20:49:15 +0800 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippCAPolicyBuilder.jsx`, `src/pages/tenant/conditional/list-template/create.jsx`, `src/pages/tenant/conditional/list-template/edit.jsx`

---

### 201. `c0f8e990` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `c0f8e990e3680d80aa121bfbe0ceaff829dcdcec` |
| Author | Zacgoose |
| Date | 2026-06-04 20:49:18 +0800 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 202. `0b4c3314` — Make breadcrumb text and > selectable/copyable

| Field | Value |
|-------|-------|
| SHA | `0b4c331444ef004e841ac1c1ba66d5974d1aab5e` |
| Author | Zacgoose |
| Date | 2026-06-04 23:28:04 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Navigation/Menu; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CippBreadcrumbNav.jsx`

---

### 203. `b7c051fa` — Auth changes to use sedndmessage

| Field | Value |
|-------|-------|
| SHA | `b7c051fa865a06eaf3747be60635740f4837c4ac` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 21:52:25 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Manage365 Branding/Versioning, Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CIPPM365OAuthButton.jsx`, `src/pages/authredirect.js`

---

### 204. `67039061` — Auth changes to use sedndmessage

| Field | Value |
|-------|-------|
| SHA | `67039061cb901709c0cd35b2baa1fca1026cdc1e` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 21:52:28 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** `src/pages/authredirect.js`

---

### 205. `eb16c27a` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `eb16c27aa32198ea5e6e9287860c7f3f84946969` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 21:52:30 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 206. `5b09ef32` — fix: add popup grace period

| Field | Value |
|-------|-------|
| SHA | `5b09ef3264fef015af58826d1977c75e1960190f` |
| Author | John Duprey |
| Date | 2026-06-04 16:55:52 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Manage365 Branding/Versioning, Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CIPPM365OAuthButton.jsx`

---

### 207. `ffefbbb3` — Use broadcast channel

| Field | Value |
|-------|-------|
| SHA | `ffefbbb337754727297ecec9be79e1e7b16a4b32` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 23:24:15 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Manage365 Branding/Versioning, Permissions/Roles/Auth; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/CIPPM365OAuthButton.jsx`, `src/pages/authredirect.js`

---

### 208. `4ed6ba02` — Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev

| Field | Value |
|-------|-------|
| SHA | `4ed6ba02a3ff4f510313e1b9926f3b5012e11393` |
| Author | KelvinTegelaar |
| Date | 2026-06-04 23:25:34 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 209. `0a8252e3` — fix: version encoding

| Field | Value |
|-------|-------|
| SHA | `0a8252e3a2a954a734f58637179e7eed91dcb16c` |
| Author | John Duprey |
| Date | 2026-06-04 20:15:21 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Manage365 Branding/Versioning; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippSettings/CippVersionProperties.jsx`

---

### 210. `c8d61c07` — fix: JIT admin, remove creatable on autocomplete

| Field | Value |
|-------|-------|
| SHA | `c8d61c0757853359cde98f9a00e6e3ba6fe6e98e` |
| Author | John Duprey |
| Date | 2026-06-04 23:13:18 -0400 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Bugfix |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Bug fixes |

**Files:** `src/pages/identity/administration/jit-admin/add.jsx`

---

### 211. `98a96fcb` — CA expansion for tags

| Field | Value |
|-------|-------|
| SHA | `98a96fcbcf72717d266c53eeaca45ab4a074b28a` |
| Author | KelvinTegelaar |
| Date | 2026-06-05 13:17:15 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Cherry-pick with adaptation** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/tenant/manage/applied-standards.js`, `src/pages/tenant/manage/policies-deployed.js`

---

### 212. `a4aac4a1` — CA expansion for tags

| Field | Value |
|-------|-------|
| SHA | `a4aac4a128a847a5af059c4edc73f66af7014a60` |
| Author | KelvinTegelaar |
| Date | 2026-06-05 13:17:18 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Tenant management changes, Potentially breaking changes |

**Files:** `src/pages/tenant/manage/applied-standards.js`

---

### 213. `7b0c8699` — Update SsoMigrationDialog.jsx

| Field | Value |
|-------|-------|
| SHA | `7b0c86990e1e5765992c31ad0650d1c63fcf7917` |
| Author | Zacgoose |
| Date | 2026-06-05 22:11:18 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/SsoMigrationDialog.jsx`

---

### 214. `8ae6ad1f` — typo

| Field | Value |
|-------|-------|
| SHA | `8ae6ad1fae73702c180047ba374b491542dc0b4d` |
| Author | Zacgoose |
| Date | 2026-06-05 22:19:13 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/ForcedSsoMigrationDialog.jsx`, `src/components/CippComponents/SsoMigrationDialog.jsx`

---

### 215. `c15d1d0d` — fix: sherweb integration conditional fields

| Field | Value |
|-------|-------|
| SHA | `c15d1d0df12c5aef9bd1d301a255ef5224c05f7d` |
| Author | John Duprey |
| Date | 2026-06-05 10:41:56 -0400 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Security |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Security fixes |

**Files:** `src/data/Extensions.json`

---

### 216. `6c968c4b` — fix: bad math

| Field | Value |
|-------|-------|
| SHA | `6c968c4bd3eb95439caf2c669e63bc7f1dd2fdd7` |
| Author | John Duprey |
| Date | 2026-06-05 14:36:10 -0400 |
| Files changed | 1 |
| Risk | **High** |
| Area | Tenant |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Tenant Workflows; Buckets: Tenant management changes, Potentially breaking changes |

**Files:** `src/pages/tenant/manage/applied-standards.js`

---

### 217. `e90b0ff9` — renumber for cis7

| Field | Value |
|-------|-------|
| SHA | `e90b0ff971de99d70d5ee1e10a98c183dc1f97e7` |
| Author | KelvinTegelaar |
| Date | 2026-06-06 00:46:30 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/data/standards.json`

---

### 218. `4c2843c7` — more secure pipeline configuration

| Field | Value |
|-------|-------|
| SHA | `4c2843c74331a4af685b700ab82f20b4cdbe33b7` |
| Author | Zacgoose |
| Date | 2026-06-07 13:24:08 +0800 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `.npmrc`, `.yarnrc`

---

### 219. `55e8eef2` — Update worker-health.js

| Field | Value |
|-------|-------|
| SHA | `55e8eef2399713f966791554ee214f928cb72f81` |
| Author | Zacgoose |
| Date | 2026-06-07 15:06:59 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/pages/cipp/advanced/worker-health.js`

---

### 220. `4c0c058f` — Update alerts.json

| Field | Value |
|-------|-------|
| SHA | `4c0c058f42dcd7cdb23fb83d64df0884a38493c4` |
| Author | Zacgoose |
| Date | 2026-06-08 13:28:09 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/data/alerts.json`

---

### 221. `4df01a60` — Update unauthenticated.js

| Field | Value |
|-------|-------|
| SHA | `4df01a60857ef84b8cf7085ddc1684aabc135767` |
| Author | Zacgoose |
| Date | 2026-06-08 14:16:54 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Auth |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Permissions/Roles/Auth; Buckets: Authentication/permissions changes, Potentially breaking changes |

**Files:** `src/pages/unauthenticated.js`

---

### 222. `9c82a214` — 10.5.0 version up

| Field | Value |
|-------|-------|
| SHA | `9c82a214263d290a46901fb7f4e804b4bfb573b5` |
| Author | KelvinTegelaar |
| Date | 2026-06-08 11:32:48 +0200 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `public/version.json`

---

### 223. `03048445` — Merge branch 'main' into dev

| Field | Value |
|-------|-------|
| SHA | `03048445fc6037f0436363b7cec15ca3baacb7c9` |
| Author | KelvinTegelaar |
| Date | 2026-06-08 12:01:22 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 224. `4521af9d` — Merge pull request #6129 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `4521af9d115e4552f1eafabb94d604bb87415843` |
| Author | KelvinTegelaar |
| Date | 2026-06-08 14:25:04 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 225. `580b66f9` — repair and fix failed SSO app creations and password addition failures

| Field | Value |
|-------|-------|
| SHA | `580b66f91e2d658e81516e6a7f298fd9688e544c` |
| Author | Zacgoose |
| Date | 2026-06-09 01:03:26 +0800 |
| Files changed | 3 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippComponents/ForcedSsoMigrationDialog.jsx`, `src/components/CippComponents/SsoMigrationDialog.jsx`, `src/components/CippSettings/CippSSOSettings.jsx`

---

### 226. `1ea0324e` — fix: ensure search happens when data is done loading

| Field | Value |
|-------|-------|
| SHA | `1ea0324e5fe184ba493501e49657910bc21999de` |
| Author | Bobby |
| Date | 2026-06-08 22:56:55 +0200 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippTable/CippDataTable.js`

---

### 227. `0de0910a` — Merge pull request #6132 from kris6673/tables-search

| Field | Value |
|-------|-------|
| SHA | `0de0910aa769c348e33ac520c72d84e3587f48f9` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 00:12:03 +0200 |
| Files changed | 0 |
| Risk | **Low** |
| Area | UI |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: UI improvements |

**Files:** (none)

---

### 228. `cfbf3508` — Removed dublicate appliesToTest key

| Field | Value |
|-------|-------|
| SHA | `cfbf3508e1ede8b51ef6daff780356ea0379f083` |
| Author | JNRavnIT |
| Date | 2026-06-09 10:19:54 +0200 |
| Files changed | 1 |
| Risk | **Low** |
| Area | Tests |
| Recommendation | **Cherry-pick** |
| Conflict likelihood | Low |
| Notes | Buckets: Tests-only |

**Files:** `src/data/standards.json`

---

### 229. `8cfb8ca0` — Merge pull request #6138 from JNRavnIT/patch-1

| Field | Value |
|-------|-------|
| SHA | `8cfb8ca077a920d42556858d1aabe692c1d39748` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 10:24:55 +0200 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 230. `7ea75e76` — Merge pull request #6072 from KelvinTegelaar/dependabot/npm_and_yarn/dev/react-pdf/renderer-4.5.1

| Field | Value |
|-------|-------|
| SHA | `7ea75e76a5f2efa8332d22ecbad4507613992930` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 14:20:20 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 231. `f1475e8e` — Merge pull request #6073 from KelvinTegelaar/dependabot/npm_and_yarn/dev/axios-1.16.1

| Field | Value |
|-------|-------|
| SHA | `f1475e8e43f1880a34ffb9e4f6bd80838aa9c0ad` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 14:20:38 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 232. `87d543d4` — Merge pull request #6075 from KelvinTegelaar/dependabot/npm_and_yarn/dev/react-hook-form-7.76.1

| Field | Value |
|-------|-------|
| SHA | `87d543d43a3881aac46dd99bf4cfb4b4e5acabe2` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 14:21:07 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 233. `e53ab04d` — Merge pull request #6074 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tiptap/extension-heading-3.22.3

| Field | Value |
|-------|-------|
| SHA | `e53ab04dd4d8a93d8fa0983d223c4fb5346207cd` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 14:21:27 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 234. `91bb02b4` — Merge pull request #6071 from KelvinTegelaar/dependabot/npm_and_yarn/dev/react-virtuoso-4.18.7

| Field | Value |
|-------|-------|
| SHA | `91bb02b41faf27a0d586b92a0a7b1abc53540934` |
| Author | KelvinTegelaar |
| Date | 2026-06-09 14:21:35 +0200 |
| Files changed | 0 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** (none)

---

### 235. `ae695a9f` — Update CippAddEditUser.jsx

| Field | Value |
|-------|-------|
| SHA | `ae695a9f3a1bec6b275b4dbcf4d1cc77abc1a8eb` |
| Author | Zacgoose |
| Date | 2026-06-09 21:48:31 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Build |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `src/components/CippFormPages/CippAddEditUser.jsx`

---

### 236. `0e10e08e` — Update index.js

| Field | Value |
|-------|-------|
| SHA | `0e10e08eb1826be1912569a3dd6e5e979c3da273` |
| Author | Zacgoose |
| Date | 2026-06-09 21:53:36 +0800 |
| Files changed | 1 |
| Risk | **Medium** |
| Area | Teams |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** `src/pages/teams-share/sharepoint/index.js`

---

### 237. `6a2e7b31` — chore: bump version to 10.5.1

| Field | Value |
|-------|-------|
| SHA | `6a2e7b31d1312e0f51f99f2f65b9ae32a5629304` |
| Author | John Duprey |
| Date | 2026-06-09 10:35:24 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `public/version.json`

---

### 238. `f4448a56` — Merge pull request #6140 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `f4448a56afe9cbbe295450db33698864655359eb` |
| Author | John Duprey |
| Date | 2026-06-09 10:42:04 -0400 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---

### 239. `a4c56b26` — manual pagination support for Invoke-ListMailQuarantine

| Field | Value |
|-------|-------|
| SHA | `a4c56b26accd9374cc739dcc46934624fb5d1089` |
| Author | Zacgoose |
| Date | 2026-06-10 22:49:57 +0800 |
| Files changed | 1 |
| Risk | **High** |
| Area | Email |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Custom overlap: Quarantine Portal; Buckets: Exchange/Email changes, Potentially breaking changes |

**Files:** `src/pages/email/administration/quarantine/index.js`

---

### 240. `e0b0bdb8` — chore: bump version to 10.5.2

| Field | Value |
|-------|-------|
| SHA | `e0b0bdb85c9161edce9fa50263682b7a42ed1b44` |
| Author | John Duprey |
| Date | 2026-06-10 17:02:44 -0400 |
| Files changed | 2 |
| Risk | **High** |
| Area | Dependencies |
| Recommendation | **Needs manual review** |
| Conflict likelihood | High |
| Notes | Buckets: Dependency/build changes, Potentially breaking changes |

**Files:** `package.json`, `public/version.json`

---

### 241. `0d8ca9d2` — Merge pull request #6153 from KelvinTegelaar/dev

| Field | Value |
|-------|-------|
| SHA | `0d8ca9d2f5f8511413b69a3064e055ac45024f33` |
| Author | John Duprey |
| Date | 2026-06-10 17:32:21 -0400 |
| Files changed | 0 |
| Risk | **Medium** |
| Area | Other |
| Recommendation | **Needs manual review** |
| Conflict likelihood | Medium |
| Notes | Buckets: Other |

**Files:** (none)

---
