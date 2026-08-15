# Upstream Delta Inventory — CIPP (Frontend)

Generated: 2026-06-17
Production branch: `main` @ `81a5dc53b`
Upstream: `KelvinTegelaar/CIPP` @ `0d8ca9d2f`

## Delta summary

| Metric | Count |
|--------|-------|
| Fork-only commits (ahead of upstream) | 602 |
| Upstream commits not in `main` (behind) | 241 |
| Upstream commits since sync base `f2d87612e` | 241 |

**Interpretation:** The branch is behind upstream by design. The first selective sync merged ~25 commits; the remaining delta is expected unpicked upstream work, not a failed merge.

### Recommendation distribution

- **Cherry-pick with review:** 113
- **Skip:** 41
- **Skip or Defer:** 40
- **Cherry-pick:** 28
- **Already applied (sync 2026-06-17):** 15
- **Defer:** 4

### Risk distribution

- **Medium:** 146
- **High:** 61
- **Low:** 34

## Carried-forward deferred items (from sync 2026-06-17)

| Item | Status |
|------|--------|
| `7054bfc4` UserReportedPhishing frontend alert | Defer until CIPP-API handler + SAM permission |
| `b1902421` tab layout first-tab margin | Defer — layout conflict |
| `bc412396b` / `20e2f554d` allow/block edit/controlled drawer | Defer — partial guard only applied |
| `4c0c058f` alerts schema change | Defer — higher risk |
| Frontend dependency/lint debt | Pre-existing — not sync blocker |

## Commit inventory

| SHA | Title | Author | Date | Risk | Area | Protected overlap | Recommendation | Files |
|-----|-------|--------|------|------|------|-------------------|----------------|-------|
| `0d8ca9d2` | Merge pull request #6153 from KelvinTegelaar/dev | John Duprey | 2026-06-10 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `e0b0bdb8` | chore: bump version to 10.5.2 | John Duprey | 2026-06-10 | High | Data/config JSON, Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, public/version.json |
| `a4c56b26` | manual pagination support for Invoke-ListMailQuarantine | Zacgoose | 2026-06-10 | High | Protected feature | Quarantine Portal | Skip or Defer — protected-area overlap | src/pages/email/administration/quarantine/index.js |
| `f4448a56` | Merge pull request #6140 from KelvinTegelaar/dev | John Duprey | 2026-06-09 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `6a2e7b31` | chore: bump version to 10.5.1 | John Duprey | 2026-06-09 | High | Data/config JSON, Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, public/version.json |
| `0e10e08e` | Update index.js | Zacgoose | 2026-06-09 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/teams-share/sharepoint/index.js |
| `ae695a9f` | Update CippAddEditUser.jsx | Zacgoose | 2026-06-09 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippFormPages/CippAddEditUser.jsx |
| `91bb02b4` | Merge pull request #6071 from KelvinTegelaar/dependabot/npm_and_yarn/dev/react-virtuoso-4.18.7 | KelvinTegelaar | 2026-06-09 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `e53ab04d` | Merge pull request #6074 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tiptap/extension-heading-3.22.3 | KelvinTegelaar | 2026-06-09 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `87d543d4` | Merge pull request #6075 from KelvinTegelaar/dependabot/npm_and_yarn/dev/react-hook-form-7.76.1 | KelvinTegelaar | 2026-06-09 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `f1475e8e` | Merge pull request #6073 from KelvinTegelaar/dependabot/npm_and_yarn/dev/axios-1.16.1 | KelvinTegelaar | 2026-06-09 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `7ea75e76` | Merge pull request #6072 from KelvinTegelaar/dependabot/npm_and_yarn/dev/react-pdf/renderer-4.5.1 | KelvinTegelaar | 2026-06-09 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json |
| `8cfb8ca0` | Merge pull request #6138 from JNRavnIT/patch-1 | KelvinTegelaar | 2026-06-09 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `cfbf3508` | Removed dublicate appliesToTest key | JNRavnIT | 2026-06-09 | Low | Data/config JSON | None | Already applied (sync 2026-06-17) | src/data/standards.json |
| `0de0910a` | Merge pull request #6132 from kris6673/tables-search | KelvinTegelaar | 2026-06-09 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `1ea0324e` | fix: ensure search happens when data is done loading | Bobby | 2026-06-08 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippTable/CippDataTable.js |
| `580b66f9` | repair and fix failed SSO app creations and password addition failures | Zacgoose | 2026-06-09 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/ForcedSsoMigrationDialog.jsx, src/components/CippComponents/SsoMigrationDialog.jsx, src/components/CippSettings/CippSSOSettings.jsx |
| `4521af9d` | Merge pull request #6129 from KelvinTegelaar/dev | KelvinTegelaar | 2026-06-08 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `03048445` | Merge branch 'main' into dev | KelvinTegelaar | 2026-06-08 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `9c82a214` | 10.5.0 version up | KelvinTegelaar | 2026-06-08 | High | Data/config JSON, Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, public/version.json |
| `4df01a60` | Update unauthenticated.js | Zacgoose | 2026-06-08 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/unauthenticated.js |
| `4c0c058f` | Update alerts.json | Zacgoose | 2026-06-08 | Low | Data/config JSON | None | Defer — alerts schema change (higher risk) | src/data/alerts.json |
| `55e8eef2` | Update worker-health.js | Zacgoose | 2026-06-07 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/advanced/worker-health.js |
| `4c2843c7` | more secure pipeline configuration | Zacgoose | 2026-06-07 | Medium | General | None | Cherry-pick with review | .npmrc, .yarnrc |
| `e90b0ff9` | renumber for cis7 | KelvinTegelaar | 2026-06-06 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `6c968c4b` | fix: bad math | John Duprey | 2026-06-05 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/manage/applied-standards.js |
| `c15d1d0d` | fix: sherweb integration conditional fields | John Duprey | 2026-06-05 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/Extensions.json |
| `8ae6ad1f` | typo | Zacgoose | 2026-06-05 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/ForcedSsoMigrationDialog.jsx, src/components/CippComponents/SsoMigrationDialog.jsx |
| `7b0c8699` | Update SsoMigrationDialog.jsx | Zacgoose | 2026-06-05 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/SsoMigrationDialog.jsx |
| `a4aac4a1` | CA expansion for tags | KelvinTegelaar | 2026-06-05 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/manage/applied-standards.js |
| `98a96fcb` | CA expansion for tags | KelvinTegelaar | 2026-06-05 | Medium | General | None | Cherry-pick with review | src/pages/tenant/manage/applied-standards.js, src/pages/tenant/manage/policies-deployed.js |
| `c8d61c07` | fix: JIT admin, remove creatable on autocomplete | John Duprey | 2026-06-04 | Medium | General | None | Already applied (sync 2026-06-17) | src/pages/identity/administration/jit-admin/add.jsx |
| `0a8252e3` | fix: version encoding | John Duprey | 2026-06-04 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippSettings/CippVersionProperties.jsx |
| `4ed6ba02` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | KelvinTegelaar | 2026-06-04 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CIPPM365OAuthButton.jsx |
| `ffefbbb3` | Use broadcast channel | KelvinTegelaar | 2026-06-04 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CIPPM365OAuthButton.jsx, src/pages/authredirect.js |
| `5b09ef32` | fix: add popup grace period | John Duprey | 2026-06-04 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CIPPM365OAuthButton.jsx |
| `eb16c27a` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | KelvinTegelaar | 2026-06-04 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `67039061` | Auth changes to use sedndmessage | KelvinTegelaar | 2026-06-04 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/authredirect.js |
| `b7c051fa` | Auth changes to use sedndmessage | KelvinTegelaar | 2026-06-04 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CIPPM365OAuthButton.jsx, src/pages/authredirect.js |
| `0b4c3314` | Make breadcrumb text and > selectable/copyable | Zacgoose | 2026-06-04 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippBreadcrumbNav.jsx |
| `c0f8e990` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | Zacgoose | 2026-06-04 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `3daf8b33` | Add named location editing to CA template editor | Zacgoose | 2026-06-04 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippCAPolicyBuilder.jsx, src/pages/tenant/conditional/list-template/create.jsx, src/pages/tenant/conditional/list-template/edit.jsx |
| `02db7307` | Merge pull request #6106 from kris6673/EmailAsAlternateLoginId | KelvinTegelaar | 2026-06-04 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `a9ed024d` | Merge pull request #6110 from kris6673/CAS-stuffs | KelvinTegelaar | 2026-06-04 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `11ecd334` | remove unneeded results key | KelvinTegelaar | 2026-06-04 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippFormLicenseSelector.jsx |
| `cf30b4b1` | add excluded from alerts to licenses | KelvinTegelaar | 2026-06-04 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/settings/licenses.js |
| `a04ed1a6` | Merge pull request #6049 from luimen6/feat/group-license-management | KelvinTegelaar | 2026-06-04 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `72623261` | add excludeFromAlert to licenses. | KelvinTegelaar | 2026-06-04 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/settings/licenses.js |
| `a8048476` | Exclude partner tenant | Zacgoose | 2026-06-04 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippAddEditTenantGroups.jsx, src/pages/tenant/administration/tenants/groups/edit.js |
| `692c67d6` | fix: quarantine deny action | John Duprey | 2026-06-03 | High | Protected feature | Quarantine Portal | Skip or Defer — protected-area overlap | src/pages/email/administration/quarantine/index.js |
| `b2f8f803` | feat: add actions for managing mailbox client access protocols | Bobby | 2026-06-03 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/email/reports/mailbox-cas-settings/index.js |
| `38ac0c4a` | MCP warning | KelvinTegelaar | 2026-06-03 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippFormComponent.jsx, src/components/CippIntegrations/CippApiClientManagement.jsx |
| `e4009f28` | feat: add Email as alternate login ID standard | Bobby | 2026-06-03 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `51d2828b` | add mcp allowed | KelvinTegelaar | 2026-06-03 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippIntegrations/CippApiClientManagement.jsx |
| `4d88e456` | Update CippAutocomplete.jsx | Zacgoose | 2026-06-03 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippAutocomplete.jsx |
| `cbd6faef` | Correct report builder permissions | Zacgoose | 2026-06-03 | Medium | General | None | Cherry-pick with review | src/pages/tools/report-builder/builder/index.js, src/pages/tools/report-builder/view/index.js |
| `d4570de5` | Update CippReportToolbar.jsx | Zacgoose | 2026-06-03 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippReportToolbar.jsx |
| `069d6d6b` | Merge pull request #6101 from kris6673/stale | KelvinTegelaar | 2026-06-02 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `89abbf50` | fix: improve stale issue and close messages for clarity | Bobby | 2026-06-02 | Medium | General | None | Cherry-pick with review | .github/workflows/Close_Stale_Issues.yml |
| `f1703f04` | Update CippTenantModeDeploy.jsx | Zacgoose | 2026-06-02 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippWizard/CippTenantModeDeploy.jsx |
| `49cda6e0` | Update index.js | Zacgoose | 2026-06-02 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/reports/list-licenses/index.js |
| `d26084fb` | Merge pull request #6080 from kris6673/icons | KelvinTegelaar | 2026-06-02 | Medium | General | None | Cherry-pick with review — isolated UI | src/utils/icon-registry.js |
| `ee6f501e` | Merge pull request #6079 from kris6673/move-ADE | KelvinTegelaar | 2026-06-02 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `3734adee` | Fix template trigger | KelvinTegelaar | 2026-06-01 | Medium | General | None | Already applied (sync 2026-06-17) | src/pages/tenant/manage/user-defaults.js |
| `e2c39b26` | Update M365Licenses.json | Zacgoose | 2026-06-02 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/M365Licenses.json |
| `6737dcb7` | Licence Universal Search | Zacgoose | 2026-06-02 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/components/CippCards/CippUniversalSearchV2.jsx, src/components/CippComponents/CippLicenseDetailsDrawer.jsx, src/data/M365Licenses.json, src/layouts/top-nav.js (+2) |
| `9e44f394` | Update worker-health.js | Zacgoose | 2026-05-30 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/advanced/worker-health.js |
| `c0bfd7df` | Update standards.json | Zacgoose | 2026-05-29 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `97d77727` | Expose missing standards and allow removal | Zacgoose | 2026-05-29 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippStandards/CippStandardAccordion.jsx |
| `707873e3` | fix: Fix tab title showing as undefined | Bobby | 2026-05-28 | Medium | General | None | Cherry-pick with review | src/pages/email/administration/exchange-retention/policies/index.js, src/pages/email/administration/exchange-retention/tags/index.js |
| `d0405ff4` | feat: Add icons to the tabs and remove dead tab | Bobby | 2026-05-28 | Medium | Data/config JSON, General | None | Cherry-pick with review | src/pages/cipp/advanced/super-admin/tabOptions.json, src/pages/cipp/custom-data/tabOptions.json, src/pages/cipp/settings/tabOptions.json, src/pages/dashboardv2/tabOptions.json (+18) |
| `063550f4` | chore: update tab paths and imports | Bobby | 2026-05-28 | Medium | Data/config JSON, General | None | Cherry-pick with review | src/pages/endpoint/autopilot/enrollment-profiles/android-enterprise.js, src/pages/endpoint/autopilot/enrollment-profiles/apple-ade.js, src/pages/endpoint/autopilot/enrollment-profiles/index.js, src/pages/endpoint/autopilot/enrollment-profiles/tabOptions.json (+1) |
| `605ecd82` | fix: move ADE pages | Bobby | 2026-05-28 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/layouts/config.js, src/pages/endpoint/autopilot/enrollment-profiles/android-enterprise.js, src/pages/endpoint/autopilot/enrollment-profiles/apple-ade.js, src/pages/endpoint/autopilot/enrollment-profiles/index.js (+2) |
| `04f8575c` | Merge pull request #6070 from kris6673/6061 | KelvinTegelaar | 2026-05-28 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `8306a660` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | KelvinTegelaar | 2026-05-28 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `7e44aff8` | new auth methods single standard | KelvinTegelaar | 2026-05-28 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `ca43bc9e` | Update worker-health.js | Zacgoose | 2026-05-28 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/advanced/worker-health.js |
| `ab8de98d` | Update worker-health.js | Zacgoose | 2026-05-28 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/advanced/worker-health.js |
| `b8ece5c4` | Update worker-health.js | Zacgoose | 2026-05-28 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/advanced/worker-health.js |
| `0995677d` | chore(deps): bump react-hook-form from 7.72.0 to 7.76.1 | dependabot[bot] | 2026-05-28 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `c04cd7c9` | chore(deps): bump @tiptap/extension-heading from 3.20.5 to 3.22.3 | dependabot[bot] | 2026-05-28 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `49192881` | chore(deps): bump axios from 1.15.0 to 1.16.1 | dependabot[bot] | 2026-05-28 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `8316c600` | chore(deps): bump @react-pdf/renderer from 4.3.2 to 4.5.1 | dependabot[bot] | 2026-05-28 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `f256c253` | chore(deps): bump react-virtuoso from 4.18.5 to 4.18.7 | dependabot[bot] | 2026-05-28 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `072416dd` | new autopatch standard | KelvinTegelaar | 2026-05-28 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `d0f58cbe` | feat(mailboxes): show mailbox and archive size columns | Bobby | 2026-05-27 | Medium | General | None | Cherry-pick with review | src/pages/email/administration/mailboxes/index.js, src/utils/get-cipp-formatting.js |
| `de035243` | fixes #6065 | KelvinTegelaar | 2026-05-27 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/manage/user-defaults.js |
| `7a408542` | fix query keys | KelvinTegelaar | 2026-05-27 | Medium | General | None | Cherry-pick with review | src/pages/security/compliance/dlp/index.js, src/pages/security/compliance/labels/index.js, src/pages/security/compliance/retention/index.js, src/pages/security/compliance/sit/index.js |
| `635548af` | Add version cleanup | KelvinTegelaar | 2026-05-27 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/teams-share/sharepoint/index.js |
| `0abf5523` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | KelvinTegelaar | 2026-05-27 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `bf6056ba` | Add version cleanup | KelvinTegelaar | 2026-05-27 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/teams-share/sharepoint/index.js |
| `4102a13e` | Merge pull request #6064 from kris6673/TAP-typos | KelvinTegelaar | 2026-05-27 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `5709f856` | fix: update terminology from "Temporary Access Password" to "Temporary Access Pass" | Bobby | 2026-05-27 | Medium | Data/config JSON, General | None | Cherry-pick — data-only JSON | src/components/CippComponents/CippUserActions.jsx, src/data/standards.json |
| `0e527e50` | Sharepoint management functionality. | KelvinTegelaar | 2026-05-27 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `de70889f` | smart lockout standard | KelvinTegelaar | 2026-05-27 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `1b7797af` | Update standards.json | Zacgoose | 2026-05-27 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `fe4765e8` | Merge pull request #6059 from kris6673/permaDismiss | KelvinTegelaar | 2026-05-27 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `25f4caed` | feat: add permanent dismissal option for release notes | Bobby | 2026-05-27 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/ReleaseNotesDialog.js |
| `2f62bae9` | Update CippAuditLogSearchDrawer.jsx | Zacgoose | 2026-05-27 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippAuditLogSearchDrawer.jsx |
| `d28e8ebf` | user sync | Zacgoose | 2026-05-26 | Medium | General | None | Cherry-pick with review | src/components/CippSettings/CippRoleAddEdit.jsx, src/components/CippSettings/CippUserManagement.jsx, src/pages/cipp/advanced/super-admin/cipp-users.js |
| `f3c8a79e` | Update yarn.lock | Zacgoose | 2026-05-26 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | yarn.lock |
| `ca150a28` | Better display standards that are missing licenses to be able to work | Zacgoose | 2026-05-26 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/manage/applied-standards.js |
| `1cd1ef72` | Update AuditLogTemplates.json | Zacgoose | 2026-05-26 | Low | Data/config JSON | None | Already applied (sync 2026-06-17) | src/data/AuditLogTemplates.json |
| `1e59d2d4` | Update ListTests.json | Zacgoose | 2026-05-26 | Low | Data/config JSON | None | Already applied (sync 2026-06-17) | Tests/Shapes/ListTests.json |
| `8145f585` | Merge pull request #6056 from KelvinTegelaar/copilot/move-enrollment-profile-tabs | Zacgoose | 2026-05-25 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `02c7a434` | Move EnrollmentProfileTabs to CippComponents folder and update imports | copilot-swe-agent[bot] | 2026-05-25 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/EnrollmentProfileTabs.jsx, src/pages/endpoint/MEM/enrollment-profiles/android-enterprise.js, src/pages/endpoint/MEM/enrollment-profiles/apple-ade.js, src/pages/endpoint/MEM/enrollment-profiles/index.js (+1) |
| `7d1c2096` | Move EnrollmentProfileTabs from pages to components and update imports | copilot-swe-agent[bot] | 2026-05-25 | Medium | General | None | Cherry-pick with review | src/components/EnrollmentProfileTabs.jsx, src/pages/endpoint/MEM/enrollment-profiles/android-enterprise.js, src/pages/endpoint/MEM/enrollment-profiles/apple-ade.js, src/pages/endpoint/MEM/enrollment-profiles/index.js (+1) |
| `a2d8f191` | react-dom | KelvinTegelaar | 2026-05-25 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json |
| `37778e28` | Merge pull request #6002 from KelvinTegelaar/dependabot/npm_and_yarn/dev/react-19.2.6 | KelvinTegelaar | 2026-05-25 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `6a51abf3` | demo data | KelvinTegelaar | 2026-05-25 | Medium | General | None | Cherry-pick with review | src/contexts/tutorial-context.js, src/data/dashboardv2-demo-data.js |
| `eac59c8a` | add tutorials to easy deployment of steps for Ashe. | KelvinTegelaar | 2026-05-25 | High | General, Navigation/layout | None | Cherry-pick with review | src/components/CippComponents/CippBreadcrumbNav.jsx, src/components/CippComponents/CippSpeedDial.jsx, src/components/CippComponents/CippTutorialDialog.jsx, src/contexts/tutorial-context.js (+3) |
| `ff9af7e0` | add tutorials to easy deployment of steps for Ashe. | KelvinTegelaar | 2026-05-25 | High | Data/config JSON, Dependencies/build, General | Build/dependencies | Skip or Defer — protected-area overlap | package.json, src/components/CippComponents/CippBreadcrumbNav.jsx, src/components/CippComponents/CippSpeedDial.jsx, src/components/CippComponents/CippTutorialDialog.jsx (+10) |
| `8a179d28` | moved autopilot ade etc | KelvinTegelaar | 2026-05-25 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/layouts/config.js, src/pages/endpoint/MEM/enrollment-profiles/apple-ade.js, src/pages/endpoint/MEM/enrollment-profiles/index.js, src/pages/endpoint/MEM/enrollment-profiles/tabOptions.json |
| `83994360` | chore(deps): bump react from 19.2.5 to 19.2.6 | dependabot[bot] | 2026-05-25 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `0001b6c8` | Merge pull request #5999 from KelvinTegelaar/dependabot/npm_and_yarn/dev/dompurify-3.4.3 | KelvinTegelaar | 2026-05-25 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `4ffb7638` | Merge pull request #6000 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tiptap/extension-table-3.20.5 | KelvinTegelaar | 2026-05-25 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `2e1e3007` | Merge pull request #6001 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tiptap/core-3.22.3 | KelvinTegelaar | 2026-05-25 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `ac1190da` | Merge pull request #6003 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tanstack/react-query-5.100.10 | KelvinTegelaar | 2026-05-25 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `28ec38c1` | Merge pull request #6009 from kris6673/ade | KelvinTegelaar | 2026-05-25 | High | Navigation/layout | None | Cherry-pick with review — isolated UI | src/layouts/config.js |
| `d8c4988d` | Merge pull request #6039 from kris6673/DlpViaDcsEnabled | KelvinTegelaar | 2026-05-25 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `304e0e5a` | Merge pull request #6052 from kris6673/remove-adminroles | KelvinTegelaar | 2026-05-25 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `38e72f99` | Add APv2 profile | KelvinTegelaar | 2026-05-25 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `c1c5693c` | feat: add admin role member removal functionality | Bobby | 2026-05-25 | Medium | General | None | Cherry-pick with review | src/pages/identity/administration/roles/index.js, src/pages/identity/administration/users/user/index.jsx |
| `16b4503f` | login/out testing | Zacgoose | 2026-05-25 | High | Data/config JSON, Navigation/layout | None | Skip — auth/permissions overlap | src/layouts/account-popover.js, staticwebapp.config.json |
| `f591d479` | logout | Zacgoose | 2026-05-25 | High | General, Navigation/layout | None | Cherry-pick with review | src/components/CippComponents/SsoMigrationDialog.jsx, src/layouts/account-popover.js, src/layouts/index.js |
| `c43f6d9a` | Update unauthenticated.js | Zacgoose | 2026-05-25 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/unauthenticated.js |
| `3bdb9d5b` | add global var showing | KelvinTegelaar | 2026-05-25 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippCustomVariables.jsx |
| `389babe3` | add global var showing | KelvinTegelaar | 2026-05-25 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippCustomVariables.jsx |
| `8097e6ed` | FIDO2 profile standards | KelvinTegelaar | 2026-05-25 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `17bf1f8d` | fixes #5995 | KelvinTegelaar | 2026-05-25 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/manage/user-defaults.js |
| `ee0ab2ab` | add extendedValues | KelvinTegelaar | 2026-05-25 | Medium | General | None | Cherry-pick with review | src/components/CippFormPages/CippAddEditUser.jsx, src/pages/tenant/manage/user-defaults.js |
| `d4f458a1` | Third party text | KelvinTegelaar | 2026-05-24 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/integrations/index.js |
| `30455f27` | third party | KelvinTegelaar | 2026-05-24 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/integrations/index.js |
| `28cafc93` | added third party notice | KelvinTegelaar | 2026-05-24 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/cipp/integrations/index.js |
| `04c63849` | implement standards template deployment for intune apps | KelvinTegelaar | 2026-05-24 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `a3279044` | CIPP Hosted Notices | Zacgoose | 2026-05-24 | High | General, Navigation/layout | None | Cherry-pick with review | src/components/CippComponents/FailedPaymentDialog.jsx, src/components/CippComponents/SubscriptionEndedDialog.jsx, src/layouts/index.js |
| `bde8ad3c` | Merge pull request #6010 from Celeratec/fix/remove-claude-worktrees | KelvinTegelaar | 2026-05-23 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `96686d7e` | Merge pull request #6012 from jonwbstr/magicdash-addoptions | KelvinTegelaar | 2026-05-23 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `fad1cacf` | Merge pull request #6019 from kris6673/split-intune-join-registration | KelvinTegelaar | 2026-05-23 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `5574b477` | Merge pull request #6038 from kris6673/winhello | KelvinTegelaar | 2026-05-23 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `c74966b3` | Merge pull request #6018 from kris6673/bulk-edit | KelvinTegelaar | 2026-05-23 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `a6ae2610` | Add Group-Based Licensing support | Luis Mengel | 2026-05-23 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippFormLicenseSelector.jsx, src/components/CippFormPages/CippAddGroupForm.jsx, src/components/CippFormPages/CippAddGroupTemplateForm.jsx, src/components/CippWizard/CippWizardGroupTemplates.jsx (+2) |
| `131927b9` | Stats | Zacgoose | 2026-05-22 | High | General, Navigation/layout | None | Cherry-pick with review | src/components/PrivateRoute.js, src/layouts/index.js, src/pages/cipp/advanced/worker-health.js |
| `5b5302ca` | feat(standards): add DLP via DCS OWA standard | Bobby | 2026-05-20 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `766a3c52` | feat: add in missing options for Windows Hello standard | Bobby | 2026-05-20 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `fc246a54` | update default value for standard | Zacgoose | 2026-05-19 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `1e7aef11` | Update alerts.json | Zacgoose | 2026-05-19 | Low | Data/config JSON | None | Already applied (sync 2026-06-17) | src/data/alerts.json |
| `6db7e776` | Delete .claude directory | Zacgoose | 2026-05-18 | Medium | General | None | Cherry-pick with review | .claude/worktrees/blissful-golick-d405ab |
| `9d5ce402` | Org auto expanding archive property usage | Zacgoose | 2026-05-18 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippCards/CippExchangeInfoCard.jsx |
| `f768330c` | fix(standards): move CIS 5.1.4.1 and SMB1001 (2.8) tags to join standard | Bobby | 2026-05-15 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `8232e5c1` | feat(standards): add intuneRestrictUserDeviceJoin entry | Bobby | 2026-05-15 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `7a85827e` | feat(users): add bulk update contact and UPN fields | Bobby | 2026-05-15 | Medium | General | None | Already applied (sync 2026-06-17) | src/pages/identity/administration/users/patch-wizard.jsx |
| `186a2c6e` | audit log template tweak | Zacgoose | 2026-05-15 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/data/AuditLogTemplates.json, src/layouts/config.js, src/pages/cipp/advanced/worker-health.js |
| `0c32a84e` | Add additional portal links to Invoke-HuduExtensionSync | jwebster@protectedtrust.com | 2026-05-14 | Low | Data/config JSON | None | Already applied (sync 2026-06-17) | src/data/Extensions.json |
| `983b48a1` | fix: Remove accidentally committed .claude/worktrees directory | Clint Thomon | 2026-05-14 | Medium | General | None | Cherry-pick with review | .claude/worktrees/blissful-golick-d405ab, .gitignore |
| `9b616499` | feat: Migrate to use shared icon registry for string to icon conversion | Bobby | 2026-05-14 | High | Data/config JSON, General, Navigation/layout | Navigation/tenant switching | Skip or Defer — protected-area overlap | src/components/CippCards/CippPropertyListCard.jsx, src/components/CippCards/CippUniversalSearchV2.jsx, src/components/CippComponents/CippTenantSelector.jsx, src/components/bulk-actions-menu.js (+4) |
| `6dab9339` | feat(tabs): support icons in tabbed layouts | Bobby | 2026-05-14 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/layouts/HeaderedTabbedLayout.jsx, src/layouts/TabbedLayout.jsx, src/pages/endpoint/MEM/enrollment-profiles/tabOptions.json, src/utils/icon-registry.js |
| `b1902421` | feat: Bit more margin to make tabbed layout of first item less cramped | Bobby | 2026-05-14 | High | Navigation/layout | None | Defer — layout conflict (b1902421) | src/layouts/HeaderedTabbedLayout.jsx, src/layouts/TabbedLayout.jsx |
| `c9bfe909` | feat(endpoint): add MEM enrollment profiles page (Apple ADE, Android, Autopilot) | Bobby | 2026-05-14 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/components/CippCards/CippUniversalSearchV2.jsx, src/components/CippComponents/CippBreadcrumbNav.jsx, src/layouts/config.js, src/pages/endpoint/MEM/enrollment-profiles/EnrollmentProfileTabs.jsx (+4) |
| `db20afa2` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | KelvinTegelaar | 2026-05-14 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `12a07270` | comingsoon | KelvinTegelaar | 2026-05-14 | Medium | Data/config JSON, General | None | Cherry-pick with review | public/assets/integrations/autotask.png, public/assets/integrations/connectwise.png, public/assets/integrations/kaseya.svg, src/data/Extensions.json (+1) |
| `b5d48bcd` | logging | Zacgoose | 2026-05-14 | Medium | Data/config JSON, General | None | Cherry-pick with review | src/data/ContainerLogPresets.json, src/pages/cipp/advanced/container-logs.js |
| `fd6a9e36` | Logs | Zacgoose | 2026-05-14 | High | General, Navigation/layout | None | Cherry-pick with review | src/layouts/config.js, src/pages/cipp/advanced/container-logs.js |
| `d392d1cf` | chore(deps): bump @tanstack/react-query from 5.96.2 to 5.100.10 | dependabot[bot] | 2026-05-13 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `2285d39c` | chore(deps): bump @tiptap/core from 3.20.5 to 3.22.3 | dependabot[bot] | 2026-05-13 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `a783d28a` | chore(deps): bump @tiptap/extension-table from 3.20.4 to 3.20.5 | dependabot[bot] | 2026-05-13 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `c9584010` | chore(deps): bump dompurify from 3.4.2 to 3.4.3 | dependabot[bot] | 2026-05-13 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `60a50738` | fixes tenantfilter property | KelvinTegelaar | 2026-05-13 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/email/administration/mailbox-rules/index.js |
| `41efc5b7` | Update CippCAPolicyBuilder.jsx | Zacgoose | 2026-05-13 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippCAPolicyBuilder.jsx |
| `52a47639` | Nice CA policy editor and template creator/editor | Zacgoose | 2026-05-13 | Medium | Data/config JSON, General | None | Cherry-pick with review | src/components/CippComponents/CippCAPolicyBuilder.jsx, src/components/CippComponents/CippTemplateFieldRenderer.jsx, src/data/conditionalAccessSchema.json, src/pages/tenant/conditional/list-policies/edit.jsx (+4) |
| `8551ef5f` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | KelvinTegelaar | 2026-05-13 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `ba196dde` | expand side nav slightly for ux | KelvinTegelaar | 2026-05-13 | High | General, Navigation/layout | None | Cherry-pick with review | .claude/worktrees/blissful-golick-d405ab, src/layouts/side-nav.js |
| `72d8658d` | Add Apps and SP to universal search | Zacgoose | 2026-05-13 | Medium | General | None | Cherry-pick with review | src/components/CippCards/CippUniversalSearchV2.jsx, src/components/bulk-actions-menu.js |
| `c0946109` | Fix bulk mailbox rule changes | Zacgoose | 2026-05-13 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/identity/administration/users/user/exchange.jsx |
| `36071e54` | Module updates and import changes | Zacgoose | 2026-05-13 | High | Dependencies/build, General, Navigation/layout | Build/dependencies; Navigation/tenant switching | Skip or Defer — protected-area overlap | next.config.js, package.json, src/components/CippCards/CippStandardsDialog.jsx, src/components/CippComponents/CippAppPermissionBuilder.jsx (+9) |
| `19c48eab` | auth options | Zacgoose | 2026-05-13 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/components/CippComponents/ForcedSsoMigrationDialog.jsx, src/components/CippComponents/SsoMigrationDialog.jsx, src/components/CippIntegrations/CippApiClientManagement.jsx, src/components/CippSettings/CippContainerManagement.jsx (+8) |
| `335e40ad` | Merge pull request #5907 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tanstack/react-query-persist-client-5.96.2 | KelvinTegelaar | 2026-05-12 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json |
| `d00ebb77` | chore: bump version to 10.4.5 | John Duprey | 2026-05-12 | High | Data/config JSON, Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, public/version.json |
| `7054bfc4` | Add AlertUserReportPhising | KelvinTegelaar | 2026-05-12 | Low | Data/config JSON | None | Already applied (sync 2026-06-17) | src/data/alerts.json |
| `6c55bc42` | OneDrive Sharing disable | KelvinTegelaar | 2026-05-12 | Medium | General | None | Cherry-pick with review | src/components/CippCards/CippRemediationCard.jsx, src/components/CippComponents/CippOffboardingDefaultSettings.jsx, src/components/CippComponents/CippUserActions.jsx, src/components/CippWizard/CippWizardOffboarding.jsx |
| `63c85df0` | OneDrive Sharing disable | KelvinTegelaar | 2026-05-12 | Medium | General | None | Cherry-pick with review | src/components/CippCards/CippRemediationCard.jsx, src/components/CippComponents/CippOffboardingDefaultSettings.jsx, src/components/CippComponents/CippUserActions.jsx, src/components/CippWizard/CippWizardOffboarding.jsx |
| `0a70010e` | fix: update translation keys and adjust template usage references | John Duprey | 2026-05-12 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippTranslations.jsx, src/pages/endpoint/MEM/list-templates/index.js |
| `4f2d4993` | feat: enhance intune template details display | John Duprey | 2026-05-11 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippTranslations.jsx, src/pages/endpoint/MEM/list-templates/index.js, src/utils/get-cipp-formatting.js |
| `6cd8c632` | chore: linting | John Duprey | 2026-05-11 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/standards/alignment/index.js |
| `1cb6a11c` | fix: enhance standard name retrieval logic for better matching | John Duprey | 2026-05-11 | Medium | General | None | Already applied (sync 2026-06-17) | src/pages/tenant/standards/alignment/index.js |
| `15939e2b` | feat: improve run standard now UX provide single action with autocomplete to select all tenants in template or individual tenant (expanded from alltenants/groups) | John Duprey | 2026-05-11 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippFormTemplateTenantSelector.jsx, src/pages/tenant/manage/applied-standards.js, src/pages/tenant/manage/drift.js, src/pages/tenant/manage/driftManagementActions.js (+3) |
| `d7e8b0b5` | fix: tweak toggle button size | John Duprey | 2026-05-11 | Medium | General | None | Already applied (sync 2026-06-17) | src/pages/tenant/standards/alignment/index.js |
| `fe4bd7f9` | fix: allow alltenants sync on onedrive/sharepoint | John Duprey | 2026-05-11 | Medium | General | None | Cherry-pick with review | src/pages/teams-share/onedrive/index.js, src/pages/teams-share/sharepoint/index.js |
| `a4915dff` | chore(deps): bump @tanstack/react-query-persist-client | dependabot[bot] | 2026-05-11 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `7dcb867b` | Merge pull request #5908 from KelvinTegelaar/dependabot/npm_and_yarn/dev/uiw/react-json-view-2.0.0-alpha.42 | KelvinTegelaar | 2026-05-11 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `06e16457` | Merge pull request #5904 from KelvinTegelaar/dependabot/npm_and_yarn/dev/recharts-3.8.1 | KelvinTegelaar | 2026-05-11 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `cef87445` | Merge pull request #5905 from KelvinTegelaar/dependabot/npm_and_yarn/dev/tanstack/react-query-devtools-5.96.2 | KelvinTegelaar | 2026-05-11 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `7bcd507c` | Merge pull request #5906 from KelvinTegelaar/dependabot/npm_and_yarn/dev/mui-tiptap-1.30.0 | KelvinTegelaar | 2026-05-11 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json |
| `4b0800b8` | Merge pull request #5903 from KelvinTegelaar/dependabot/github_actions/dev/actions/setup-node-6.4.0 | KelvinTegelaar | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead | .github/workflows/cipp_frontend_build.yml |
| `0fc7b3c6` | Merge pull request #5921 from kris6673/allTenants-SP | KelvinTegelaar | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `ccf4e9cf` | Merge pull request #5685 from kris6673/levenshtein-distance | KelvinTegelaar | 2026-05-11 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `fe722173` | Merge pull request #5794 from TecharyJames/Feat-Conditional-accesss-policy-package-tags | KelvinTegelaar | 2026-05-11 | Medium | Data/config JSON, General | None | Skip — merge commit; cherry-pick substantive commits instead | src/data/standards.json, src/pages/tenant/manage/drift.js |
| `fd23c0df` | Merge branch 'dev' into allTenants-SP | Kristian Kjærgård | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `2f849474` | Merge branch 'dev' into levenshtein-distance | Kristian Kjærgård | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `dd0ba6f1` | Merge pull request #5920 from kris6673/alltenants-intune | KelvinTegelaar | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `be88cc9c` | Merge branch 'dev' into levenshtein-distance | Kristian Kjærgård | 2026-05-11 | Medium | Data/config JSON, General | None | Cherry-pick — data-only JSON | src/components/CippStandards/CippStandardAccordion.jsx, src/data/standards.json |
| `5ca3e9ad` | Merge branch 'dev' into alltenants-intune | Bobby | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead | src/components/CippComponents/CippReportDBControls.jsx, src/pages/endpoint/MEM/list-policies/index.js |
| `35711f89` | Merge branch 'dev' of https://github.com/kris6673/CIPP into allTenants-SP | Bobby | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead | src/pages/teams-share/onedrive/index.js, src/pages/teams-share/sharepoint/index.js |
| `2a1b9128` | Merge pull request #5984 from kris6673/by-standards-view | KelvinTegelaar | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `2e9b9fd5` | fixed weird button | KelvinTegelaar | 2026-05-11 | High | Dependencies/build | None | Already applied (sync 2026-06-17) | src/components/CippComponents/CippTenantAllowBlockListTemplateDrawer.jsx |
| `8e99c018` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | KelvinTegelaar | 2026-05-11 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `bc412396` | implements #5986 | KelvinTegelaar | 2026-05-11 | High | Dependencies/build | None | Defer — allow/block controlled drawer stack | src/components/CippComponents/CippTenantAllowBlockListTemplateDrawer.jsx, src/pages/email/administration/tenant-allow-block-list-templates/index.js |
| `20e2f554` | implements #5986 | KelvinTegelaar | 2026-05-11 | High | Dependencies/build | None | Defer — allow/block controlled drawer stack | src/components/CippComponents/CippTenantAllowBlockListTemplateDrawer.jsx, src/pages/email/administration/tenant-allow-block-list-templates/index.js |
| `da6dc7fa` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | Zacgoose | 2026-05-12 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `08c793d7` | Update manifest.json | Zacgoose | 2026-05-12 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | public/manifest.json |
| `1b77b784` | Update manifest for PWA chrome install option | Zacgoose | 2026-05-12 | Medium | Data/config JSON, General | None | Cherry-pick with review | public/manifest.json, public/sw.js, src/pages/_app.js, src/pages/_document.js |
| `14461b4f` | eclusions everywhere | KelvinTegelaar | 2026-05-11 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippIntunePolicyActions.jsx, src/components/CippWizard/CippIntunePolicy.jsx, src/pages/endpoint/applications/templates/index.js |
| `9cee69d4` | eclusions everywhere | KelvinTegelaar | 2026-05-11 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippAppTemplateDrawer.jsx, src/components/CippComponents/CippApplicationDeployDrawer.jsx, src/components/CippComponents/CippIntunePolicyActions.jsx, src/components/CippComponents/CippPolicyDeployDrawer.jsx (+2) |
| `55dd9cc2` | HVE user page | Zacgoose | 2026-05-12 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/components/CippComponents/CippHVEUserDrawer.jsx, src/components/CippComponents/CippNotificationForm.jsx, src/data/CIPPDBCacheTypes.json, src/layouts/config.js (+2) |
| `8b79d999` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | Zacgoose | 2026-05-12 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `445820dd` | Better intune policy support for alltenants list | Zacgoose | 2026-05-12 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippIntunePolicyDetails.jsx, src/components/CippFormPages/CippJSONView.jsx |
| `64e40807` | implemenets #5948 | KelvinTegelaar | 2026-05-11 | Medium | General | None | Cherry-pick with review — isolated UI | src/components/CippComponents/CippApplicationDeployDrawer.jsx |
| `0d42f679` | #5939 | KelvinTegelaar | 2026-05-11 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/reports/list-licenses/index.js |
| `cfe8c705` | adds #5939 | KelvinTegelaar | 2026-05-11 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/tenant/reports/list-licenses/index.js |
| `4b9efd82` | Update index.js | Zacgoose | 2026-05-11 | Medium | General | None | Already applied (sync 2026-06-17) | src/pages/tenant/reports/list-licenses/index.js |
| `98d5d94a` | Custom Test - Alert on X statuses | Zacgoose | 2026-05-11 | Low | Tests | None | Already applied (sync 2026-06-17) | src/pages/tools/custom-tests/add.jsx |
| `e3ed1818` | fix alert mode | KelvinTegelaar | 2026-05-10 | Medium | Data/config JSON, General | None | Cherry-pick with review | src/data/standards.json, src/pages/security/compliance/retention/index.js |
| `b8abed94` | Merge branch 'dev' of https://github.com/KelvinTegelaar/CIPP into dev | KelvinTegelaar | 2026-05-10 | Medium | General | None | Skip — merge commit; cherry-pick substantive commits instead |  |
| `45f1d72b` | purview adding | KelvinTegelaar | 2026-05-10 | High | Data/config JSON, General, Navigation/layout | None | Cherry-pick with review | src/components/CippComponents/CippDeployCompliancePolicyDrawer.jsx, src/data/standards.json, src/layouts/config.js, src/pages/security/compliance/dlp-templates/index.js (+7) |
| `b05e0923` | feat(standards): add by-standard alignment summary view | Bobby | 2026-05-08 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippTranslations.jsx, src/components/CippTable/CippDataTable.js, src/components/CippTable/CippDataTableButton.jsx, src/pages/tenant/standards/alignment/index.js (+2) |
| `d7d36a31` | feat: Add allTenants support for all the Teams  SharePoint pages | Bobby | 2026-04-26 | Medium | General | None | Cherry-pick with review | src/pages/teams-share/onedrive/index.js, src/pages/teams-share/sharepoint/index.js, src/pages/teams-share/teams/business-voice/index.js, src/pages/teams-share/teams/list-team/index.js (+1) |
| `1707506b` | feat: integrate useCippReportDB for data handling | Bobby | 2026-04-25 | Medium | General | None | Cherry-pick with review | src/components/CippComponents/CippReportDBControls.jsx, src/pages/endpoint/MEM/assignment-filters/index.js, src/pages/endpoint/MEM/devices/index.js, src/pages/endpoint/MEM/list-appprotection-policies/index.js (+4) |
| `f86925dc` | Merge branch 'dev' of https://github.com/kris6673/CIPP into alltenants-intune | Bobby | 2026-04-25 | Medium | General | None | Cherry-pick with review — isolated UI | src/pages/endpoint/MEM/list-policies/index.js |
| `a5f2b74b` | feat: add allTenants support for multiple intune pages | Bobby | 2026-04-25 | Medium | General | None | Cherry-pick with review | src/pages/endpoint/MEM/assignment-filters/index.js, src/pages/endpoint/MEM/devices/index.js, src/pages/endpoint/MEM/list-appprotection-policies/index.js, src/pages/endpoint/MEM/list-compliance-policies/index.js (+4) |
| `c3c90afe` | chore(deps): bump @uiw/react-json-view | dependabot[bot] | 2026-04-22 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `c22177f7` | chore(deps): bump mui-tiptap from 1.29.1 to 1.30.0 | dependabot[bot] | 2026-04-22 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `93cfed20` | chore(deps): bump @tanstack/react-query-devtools from 5.91.3 to 5.96.2 | dependabot[bot] | 2026-04-22 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `9ae908d7` | chore(deps): bump recharts from 3.8.0 to 3.8.1 | dependabot[bot] | 2026-04-22 | High | Dependencies/build | Build/dependencies | Skip or Defer — protected-area overlap | package.json, yarn.lock |
| `05b93261` | chore(deps): bump actions/setup-node from 6.3.0 to 6.4.0 | dependabot[bot] | 2026-04-22 | Medium | General | None | Cherry-pick with review | .github/workflows/Node_Project_Check.yml, .github/workflows/cipp_dev_build.yml, .github/workflows/cipp_frontend_build.yml |
| `b6438ee3` | Merge branch 'dev' into Feat-Conditional-accesss-policy-package-tags | KelvinTegelaar | 2026-04-04 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `83d657b8` | Lookup CA template names via API | James Tarran | 2026-04-03 | Medium | General | None | Cherry-pick with review | src/pages/tenant/manage/drift.js, src/pages/tenant/manage/policies-deployed.js |
| `db57e52a` | Mark TemplateList as optional and non-creatable | James Tarran | 2026-04-03 | Low | Data/config JSON | None | Already applied (sync 2026-06-17) | src/data/standards.json |
| `5ffd20e1` | Merge remote-tracking branch 'upstream/dev' into Feat-Conditional-accesss-policy-package-tags | James Tarran | 2026-04-03 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
| `88bc10a5` | Added UI Elements for adding conditional access policies to package tags | James Tarran | 2026-04-02 | Medium | Data/config JSON, General | None | Cherry-pick with review | src/data/standards.json, src/pages/tenant/conditional/list-template/index.js |
| `4fc1b57b` | feat: add warningMessage support  standards | Bobby | 2026-03-20 | Medium | Data/config JSON, General | None | Cherry-pick — data-only JSON | src/components/CippStandards/CippStandardAccordion.jsx, src/data/standards.json |
| `7dffc4c6` | feat: add fuzzy match distance setting to Intune template based on Levenshtein distance | Bobby | 2026-03-20 | Low | Data/config JSON | None | Cherry-pick — data-only JSON | src/data/standards.json |
