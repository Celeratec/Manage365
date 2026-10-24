# Archive-to-primary item move (Manage365)

**Date:** 2026-10-23  
**Status:** Draft — awaiting review  
**Scope:** User mailboxes and shared mailboxes (v1)

## Problem

Admins need to move mail from a mailbox’s Exchange Online **archive** into its **primary** mailbox so they can disable archiving or reclaim licenses without data loss. Operations must be ticketed, auditable, dry-run first, and verifiable. No purge/delete shortcuts.

## Goals

- Move items (not copy-and-leave) from archive → primary with post-move verification.
- Support **UserMailbox** and **SharedMailbox** recipients in v1.
- Default **DryRun=true**; require numeric **Freshdesk TicketNumber**.
- Large archives run as **resumable jobs** with status polling.
- Optional **ExecDisableArchive** only when archive is empty (or forced with ticket + reason).

## Non-goals

- Changing auth/SAM setup endpoints (`ExecSAMSetup`, `ExecUpdateRefreshToken`, `ExecTokenExchange`).
- DeleteArchiveCopies / bulk purge APIs.
- Upstream CyberDrain/CIPP changes (fork-only).

---

## API surface

### `POST /api/ExecMoveArchiveItems`

| Field | Required | Default | Notes |
|-------|----------|---------|--------|
| `TenantFilter` | yes | — | Tenant scope |
| `UserPrincipalName` | yes | — | Primary mailbox identity |
| `TicketNumber` | yes | — | Freshdesk ID; reject missing or non-numeric |
| `SourceFolder` | no | all archive folders | Optional folder id/path filter |
| `TargetFolder` | no | mirror name in primary, else `Restored from Archive` | Created if missing |
| `DryRun` | no | **true** | Preview only |
| `HoldAcknowledged` | no | false | Required true if holds detected |

**Role:** `Exchange.Mailbox.ReadWrite` (same family as `ExecEditCalendarPermissions`).

**Response (sync for DryRun / job enqueue):**

- DryRun: per-folder item counts, aggregate size, target folder map, primary quota headroom, shared 50 GB check, hold summary.
- Real run (small): job id + initial status, or inline result if under inline threshold (TBD in implementation, default queue).

### `GET /api/ListMoveArchiveItemsJobs`

Query: `tenantFilter`, optional `UserPrincipalName`, optional `jobId`.

Returns job rows: status, counts, ticket, timestamps, errors (no message bodies/subjects).

### `POST /api/ExecDisableArchive` (companion)

Refuses if archive item count &gt; 0 unless `Force=true` with `TicketNumber` + `Reason`. Backs up archive stats first; same audit pattern.

---

## Mailbox types (v1)

| Type | Archive access | Quota guard |
|------|----------------|-------------|
| **UserMailbox** | Graph beta archive folders or EWS `ArchiveMsgFolderRoot` | Primary `ProhibitSendReceiveQuota` / issue warning headroom |
| **SharedMailbox** | Same | Enforce **50 GB** primary limit (shared mailbox convention); fail DryRun if move would exceed |

Recipient type from `Get-Mailbox` / Graph user; reject room/equipment unless they have an archive (out of scope v1 unless archive GUID present).

---

## Implementation strategy

### 1. Discovery (DryRun)

1. Resolve mailbox + `ArchiveGuid` / archive enabled via EXO `Get-Mailbox` (select archive fields).
2. **Graph (preferred):** Try beta paths for archive mail folders (user’s archive mailbox or `msgfolderroot` child). List folders; for each (or `SourceFolder`), get `$count` and size aggregates via message list with `$select=internetMessageId,size` (paginated, capped for DryRun preview).
3. **EWS fallback:** If Graph cannot address archive in tenant, use OAuth app token (`full_access_as_app` / Exchange.ManageAsApp, app access policy scoped): `FindFolder` on archive root, `FindItem` with id-only + size properties.
4. Map target folders in primary (create missing folder tree under Inbox or configured root).
5. **Holds:** EXO `Get-Mailbox` litigation hold, retention hold, eDiscovery hold flags → block real run unless `HoldAcknowledged`.
6. **Quota:** Compare projected primary size after move vs limits (user quotas from mailbox; shared 50 GB cap).

### 2. Move (real run)

- Queue job in Azure Table `MoveArchiveItemsJobs` (partition: tenant, row: job GUID).
- Worker (scheduled task / activity trigger): process folders in batches.
- **Per item:** copy to primary target → verify `InternetMessageId` + size on primary → delete archive copy only after verify (same request transaction logically; failed verify marks job **Failed**, leaves archive intact).
- Throttling: honor Graph 429 / `Retry-After`; EWS backoff; checkpoint folder + page token on job row for resume.

### 3. Verification

After run: re-query counts with cache bypass where applicable.

- Primary count += moved count; archive count -= moved count.
- Spot-check or full ID set match for moved batch (configurable; full match for small jobs).
- Persist before/after summary on job + audit row.

### 4. Audit

- `Write-LogMessage`: tenant, mailbox, ticket, dry run flag, counts, duration, result (no subjects/bodies).
- Table `MoveArchiveItemsAudit`: caller identity (EasyAuth / API client), same fields, job id link.

---

## Frontend

**Location:** `frontend/src/pages/email/administration/mailboxes/view.jsx` (and link from user exchange tab if useful).

**Flow:**

1. Action: “Move archive items to mailbox”.
2. Required Freshdesk ticket field.
3. Dry run → preview table (folders, counts, sizes, targets, quota/hold warnings).
4. Confirm → start job → poll `ListMoveArchiveItemsJobs` → before/after summary.

Reuse `CippApiDialog` / `ApiPostCall` patterns from `CippExchangeActions`.

---

## Permissions (document in README)

Document exact SAM app additions (no changes to setup endpoints):

| Permission | Use |
|------------|-----|
| Microsoft Graph `Mail.ReadWrite` (app) | Archive/primary folder listing and move when Graph supports archive |
| `Exchange.ManageAsApp` + EWS `full_access_as_app` | EWS fallback |
| Existing EXO read | Mailbox quota, holds, archive stats |

Note: Application Access Policy must include target mailboxes. Admin consent per tenant as today.

---

## Testing

**Unit (Pester):**

- Missing / non-numeric `TicketNumber` rejected.
- `DryRun` defaults true when omitted.
- Shared mailbox over 50 GB projection fails DryRun.
- Hold present blocks without `HoldAcknowledged`.

**Integration (manual test tenant doc):**

- User mailbox: 3 items in archive → DryRun shows 3 → run moves 3 → verify → archive 0.
- Shared mailbox: same with 50 GB guard.
- Hold case requires acknowledgement.
- Simulated throttling (429) retries.

---

## Rollback

- Revert PR or remove role mapping for new endpoints in CustomRoles.
- In-flight jobs: mark cancelled in table; no automatic undo (operator restores from backup if needed).

---

## Open decisions (defaults chosen)

| Topic | Decision |
|-------|----------|
| User vs shared v1 | **Both** (user confirmed) |
| Inline vs queued threshold | Queue if &gt; 100 items or &gt; 50 MB (tunable constants) |
| Exchange restore request fallback | Not v1; document as future shortcut if Graph/EWS blocked |

---

## Files (planned)

**Backend**

- `Invoke-ExecMoveArchiveItems.ps1`, `Invoke-ListMoveArchiveItemsJobs.ps1`, `Invoke-ExecDisableArchive.ps1`
- `Start-MoveArchiveItemsJob.ps1` / `Push-MoveArchiveItemsBatch.ps1` (core logic)
- `Get-CIPPArchiveMovePreview.ps1`, `Invoke-CIPPArchiveItemMove.ps1`
- Tests under `backend/Tests/Private/` or `Email-Exchange/`
- Regenerate `backend/Config/openapi.json`

**Frontend**

- Mailbox view action + dialog/wizard component
- Optional permission string in frontend if new role slice needed (likely reuse `Exchange.Mailbox.ReadWrite`)

**Docs**

- `docs/user-documentation/email/...` + API reference examples
