# UserActions + Nested Group Memberships Intake — 2026-07-15

Feature intake batching two related upstream families that touch the identity-administration
surface. Fork frontend version bumped **5.21.0 → 5.22.0**.

## Upstream commits taken

| Commit | Summary | How it landed |
|---|---|---|
| `01cff98d1` | TAP generation: policy-aware form, error when TAP disabled | Merged into fork `CippUserActions.jsx` |
| `af1fe13ff` | Sign-in state: pre-select current, block no-op submit | Merged (radio validator row passthrough + action) |
| `22f153f48` | Source of authority: pre-select current state | Merged into user SOA action |
| `f66e74a07` | SOA refinements: hide when meaningless (users/groups/contacts) | Merged across 4 files |
| `456662835` | Add/remove nested groups in group memberships | Adapted to fork's redesigned edit page |
| `1e60e5f2b` | Missing dependency fix + label | Superseded by adaptation (labels included) |

## Frontend (CIPP)

- **`CippFormComponent.jsx`**: radio fields now pass the data `row` as the third argument to
  custom `validate` functions (same contract autoComplete fields already had).
- **`CippUserActions.jsx`** (fork-customized hook — surgical merge):
  - **Create Temporary Access Pass** now renders a `TemporaryAccessPassForm` child that queries
    the tenant's TAP authentication-method policy: shows an error alert (with re-check button
    and link to Authentication Methods) when TAP is disabled, validates lifetime against the
    policy's min/max, and forces + locks the one-time-use switch when the policy enforces it.
    Fork's `canWriteUser` condition, category, and quickAction flags preserved.
  - **Set Sign In State** pre-selects the current state (blank when the selection has mixed
    states) and rejects submitting an unchanged state.
  - **Set Source of Authority** pre-selects the current state, rejects no-op submissions, and
    is now hidden for cloud-native users (shown only when on-prem synced now or previously).
- **`groups/index.js`, `groups/group/index.jsx`, `contacts/index.js`**: same SOA
  pre-select/no-op-guard treatment. Groups hide the action unless
  `onPremisesSyncEnabled`/`onPremisesSamAccountName`; contacts require a `graphId` (cloud-native
  mail contacts have no Graph counterpart).
- **`CippApiDialog.jsx`**: fork's "Add Another" button now evaluates function-form
  `defaultvalues(row)` on reset (fork-only fix; the main reset paths already did).
- **`CippFormUserAndGroupSelector.jsx`**: adopted upstream wholesale (group-type labels
  instead of a Users/Groups groupBy; no fork customizations existed).
- **`groups/edit.jsx`** (fork's redesigned page — adapted, not replaced): upstream changed its
  AddMember autocomplete; the fork uses an Add Member dialog + members table instead, so the
  equivalent was applied to that design:
  - New `memberPickerField` backed by `/api/ListUsersAndGroups` with upstream's group-type
    labels — the Add Member dialog can now add **nested groups** as members. The Add Owner
    dialog keeps the users-only picker.
  - Members table's Email column shows the group type for nested-group rows (no UPN).
  - `EditGroup` API already binds members via `directoryObjects/{id}`, which accepts groups —
    no API change needed for add/remove.

## API (CIPP-API)

- **`Invoke-ListUsersAndGroups.ps1`** (both `CIPPHTTP` and `CIPPCore` copies, kept in sync):
  adopted upstream — groups now return `mailEnabled`/`securityEnabled`/`groupTypes`, exclude
  Unified (M365) groups, and normalize `userPrincipalName`/`@odata.type` so pickers can
  distinguish users from groups.

## Verification

- All changed files lint-clean; `yarn build` passes (63s).
- `Invoke-ListUsersAndGroups.ps1` passes PowerShell parser validation; both copies identical.
- Backup tags: `backup/pre-useractions-intake-20260715` in both repos.

## Notes

- `ExecCreateTAP`, `ExecDisableUser`, `ExecSetCloudManaged` endpoints already existed in the
  fork and needed no changes; the TAP policy query goes through `ListGraphRequest`.
