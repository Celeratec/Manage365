# Soft-delete mailbox folder (Manage365)

**Date:** 2026-11-20
**Status:** Draft — awaiting review
**Ticket:** #3281353 (Miller Law) — build for M365 Engineer; live run only after Clint’s OK
**Approach:** Dedicated guarded endpoints (not `ExecGraphWrite` allowlist)

## Problem

Manage365 has no allowlisted way to move or soft-delete a single mailbox folder. Exchange Online has no cmdlet for it. Trigger case: a stale local calendar copy at `\Calendar\Cody Rogers` (3,556 items) that must leave the live tree without permanent delete.

## Goals

- Soft-delete only: Graph **move** the folder into the mailbox **Deleted Items**.
- Companion restore that moves it back to the original parent.
- Ticket + reason required; **preview/dryRun defaults to true** and makes **zero Graph write calls**.
- Refuse well-known/default folders, shared/linked/delegated calendars, folders already in Deleted Items, and search folders.
- Return before-state always; after a real run, re-read and fail loudly if verify fails.
- Audit every attempt; no secrets/tokens in logs or responses.
- Behind **`GuardedTenantWrites`**; after ship, **enable that flag on this Manage365 instance**.
- Document the soft-delete-only prohibition in README and guarded-writes docs.

## Non-goals

- Permanent delete (`DELETE` verb) or bypass of Recoverable Items.
- Emptying Deleted Items / Recoverable Items.
- UI for this flow in v1 (API for M365 Engineer).
- Running against client mailboxes during verification (test mailbox/tenant only).
- Upstream CyberDrain/CIPP changes (fork-only).

---

## API surface

### `POST /api/ExecSoftDeleteMailboxFolder`

| Field | Required | Default | Notes |
|-------|----------|---------|--------|
| `tenantFilter` | yes | — | Tenant scope |
| `userId` | yes | — | UPN or user GUID |
| `folderId` | exactly one of id/path | — | Graph folder id |
| `folderPath` | exactly one of id/path | — | Exact folder path (e.g. `\Calendar\Cody Rogers`); both or neither → 400 |
| `folderType` | yes | — | `mail` \| `calendar` |
| `TicketNumber` | yes | — | 6–8 digits via `Test-CIPPGuardedWriteRequest` |
| `Reason` | yes | — | Empty → 400 (enforced on these endpoints) |
| `preview` / `dryRun` | no | **true** | Read-only when true |

**Role:** `Exchange.Mailbox.ReadWrite`

**Response:**

- Always: before-state, planned destination (`deleteditems`), refuse-check outcome, `Status` (`DryRun` \| `Success` \| `Failed`), `AuditId`.
- Real success: `deletedFolderId` (id under Deleted Items), `originalParentId`, after-state confirmation (same item count under Deleted Items; absent from old parent).

### `POST /api/ExecRestoreMailboxFolder`

| Field | Required | Default | Notes |
|-------|----------|---------|--------|
| `tenantFilter` | yes | — | |
| `userId` | yes | — | |
| `deletedFolderId` | yes | — | Folder id currently under Deleted Items |
| `originalParentId` | yes | — | Parent returned by soft-delete |
| `folderType` | yes | — | `mail` \| `calendar` |
| `TicketNumber` | yes | — | 6–8 digits |
| `Reason` | yes | — | Empty → 400 |
| `preview` / `dryRun` | no | **true** | |

Same role, audit, and preview rules. Restore moves back to `originalParentId` only (no arbitrary relocate).

---

## Gating and ops

1. Add `ExecSoftDeleteMailboxFolder` and `ExecRestoreMailboxFolder` to `GuardedTenantWrites.Endpoints` in `backend/Config/FeatureFlags.json`.
2. Repo default for the flag stays **`Enabled: false`**.
3. After merge, image deploy, and Clint’s explicit OK: **enable `GuardedTenantWrites` on this Manage365 instance** (all endpoints on that flag become available, including Graph/EXO/mail-filter writes).
4. Flag off → **503** from `New-CippCoreRequest` (existing behavior).

---

## Guards (refuse → 400 + audit, no write)

Checked by Graph **well-known name/id**, not display name:

| Guard | Rule |
|-------|------|
| Well-known / default | Inbox, Calendar (root), Sent Items, Deleted Items, Drafts, Outbox, Junk, Archive, Conversation History, and other Graph well-known folder names |
| Shared / linked / delegated | Calendar (or folder) that points at another mailbox: `isShared`, owner mismatch, linked-calendar / canEdit signals as exposed on the Graph object |
| Already deleted | Folder whose parent is Deleted Items (or well-known `deleteditems`) |
| Search folders | Search folder type / class |

Missing or invalid `TicketNumber` / empty `Reason` → 400 before Graph writes.

---

## Before-state

Always returned (preview and real):

- Folder path, id
- Parent id and path
- Folder class (e.g. `IPF.Appointment`, `IPF.Note`)
- Item count, size
- Oldest and newest item dates (from item metadata; no message bodies/subjects in audit)

---

## Graph move

**Soft-delete:**

```http
POST /users/{id}/mailFolders/{folderId}/move
{ "destinationId": "deleteditems" }
```

**Restore:**

```http
POST /users/{id}/mailFolders/{deletedFolderId}/move
{ "destinationId": "{originalParentId}" }
```

- **No `DELETE` verb** anywhere on this code path.
- Never permanently delete; never bypass Recoverable Items.
- For `folderType: calendar`, use the same mailFolder move when the folder is an Outlook store folder (`IPF.Appointment`). If Graph rejects calendar-folder move that way on a **test** mailbox, document the working alternative in the PR and `docs/api-documentation/guarded-writes.md` — still no DELETE fallback.

**Permissions to document** (after test-mailbox confirmation): application vs delegated `Mail.ReadWrite` and, if required, `Calendars.ReadWrite`; whether the Manage365 SAM app registration already has them.

---

## Preview

When `preview`/`dryRun` is true (default if omitted):

1. Resolve folder (id or path).
2. Collect before-state.
3. Run all refuse guards.
4. Return planned move (`destinationId: deleteditems` or restore parent).
5. **Zero** calls to Graph write helpers (`New-GraphPOSTRequest`, POST/PATCH/DELETE, or any wrapper that mutates).

Pester must fail if a write helper is invoked in preview.

---

## After-state verification (real run only)

1. Re-GET folder at old location → must be gone.
2. Locate folder under Deleted Items (or restored parent) by returned move id.
3. Item count must match before-state count.
4. Mismatch → `Status: Failed`, audit the mismatch, return known ids for manual recovery when possible. Never report Success on verify failure.

---

## Audit

Use `Add-CIPPGuardedWriteAudit` → table `GuardedWriteAudit`:

- Endpoint, TicketNumber, Reason, Caller, tenant
- Before / After JSON (redacted; no tokens)
- WhatIf/preview flag, Result, TimestampUtc

Also `Write-LogMessage` for operational success/failure without secrets.

---

## Components

| Piece | Location |
|-------|----------|
| HTTP entrypoints | `backend/Modules/CIPPHTTP/.../Email-Exchange/Administration/Invoke-ExecSoftDeleteMailboxFolder.ps1`, `Invoke-ExecRestoreMailboxFolder.ps1` |
| Request gate | `Test-CIPPGuardedWriteRequest` + endpoint-local required `Reason` |
| Core | CIPPCore helpers: resolve folder, before-state, guards, soft-delete, restore, verify (names e.g. `Test-CIPPMailboxFolderSoftDeleteRequest`, `Get-CIPPMailboxFolderBeforeState`, `Invoke-CIPPMailboxFolderSoftDelete`, `Invoke-CIPPMailboxFolderRestore`) |
| Feature flag | `backend/Config/FeatureFlags.json` |
| Docs | `docs/api-documentation/guarded-writes.md`, README release note (soft-delete-only prohibition + refuse list) |
| OpenAPI | regenerate via `build/tools/build-openapi.ps1` |
| Tests | `backend/Tests/` (GuardedWrite and/or Endpoint); guards must fail if removed |

No UI in v1.

---

## Errors

| Condition | HTTP / Status |
|-----------|----------------|
| Flag off | 503 |
| Role missing | 403 |
| Missing/invalid ticket or reason | 400 |
| Refuse-list hit | 400 + audit |
| Graph/auth failure | Failed + audit |
| Post-move verify mismatch | Failed (loud) + audit |

---

## Tests

Must cover and must fail if a guard is removed:

- Well-known/default folders refused
- Shared/linked/delegated calendars refused
- Already in Deleted Items / search folders refused
- Missing ticket / missing reason → 400
- Preview invokes zero write helpers
- Before-state shape present
- After-state verify success and mismatch failure
- Restore moves back with same ticket/reason/preview rules

Live Graph calendar-folder move check: **test mailbox in a test tenant only**.

---

## Documentation (prohibition)

README and `docs/api-documentation/guarded-writes.md` must state:

- Mailbox folder removal in Manage365 is **soft-delete only** (move to Deleted Items).
- Permanent delete is **prohibited** on this path.
- Default/well-known, shared/linked/delegated, Deleted Items, and search folders are refused.
- Preview defaults on; real run requires ticket + reason and post-move verify.
- Endpoints sit on **Guarded tenant writes**; enabling the flag on an instance enables all endpoints on that flag.

---

## Ship sequence

1. Draft PR off `main` on `clint/mailbox-folder-soft-delete`.
2. App QA + App Security + CodeRabbit review.
3. Clint merge OK → image deploy.
4. Enable **`GuardedTenantWrites`** on this Manage365 instance.
5. Hand M365 Engineer: endpoint names + request body shape for #3281353 — preview first, then `preview: false` with backup and verification.
6. Nothing against production/client mailboxes without Clint’s explicit OK.

---

## Rollback

- Soft-delete response returns `deletedFolderId` + `originalParentId`.
- `ExecRestoreMailboxFolder` moves the folder back.
- Feature flag can be turned off again (503 for all flagged endpoints).
- Image rollback to previous tag if a bad deploy ships.
