# Archive-to-primary move Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task.

**Goal:** Ticketed, auditable archive→primary moves for user and shared mailboxes with DryRun-first preview and queued real runs.

**Architecture:** HTTP entrypoints delegate to `Invoke-CIPPMoveArchiveItems` core; DryRun uses EXO mailbox/archive statistics plus quota/hold checks; real runs persist `MoveArchiveItemsJobs` rows and queue `Invoke-CIPPMoveArchiveItemsWorker` (Graph then EWS). Audit via `Write-LogMessage` + `MoveArchiveItemsAudit` table.

**Tech Stack:** Azure Functions PowerShell, EXO admin API, Graph beta mail (worker), optional EWS, React/MUI frontend.

## Global Constraints

- Fork only (Celeratec/Manage365); no upstream PRs.
- Do not modify `ExecSAMSetup`, `ExecUpdateRefreshToken`, `ExecTokenExchange`.
- No purge/delete APIs; move-only with verify-before-remove-source in worker.
- `TicketNumber` required numeric Freshdesk ID; `DryRun` defaults **true**.
- User + shared mailboxes v1; shared primary cap **50 GB** after move.
- No message bodies/subjects in logs.

---

## Phase 1 — Scaffold + DryRun (this PR)

- [x] `Test-CIPPMoveArchiveItemsRequest.ps1` + Pester
- [x] `Get-CIPPMoveArchiveItemsPreview.ps1` (EXO stats, holds, quota)
- [x] `Invoke-CIPPMoveArchiveItems.ps1` + audit helper
- [x] `Invoke-ExecMoveArchiveItems.ps1`, `Invoke-ListMoveArchiveItemsJobs.ps1`
- [x] `Start-CIPPMoveArchiveItemsJob.ps1` + worker stub for real runs
- [x] OpenAPI regen (`backend/Config/openapi.json`)
- [x] Mailbox detail UI (`CippMoveArchiveItemsDialog` + `view.jsx`)
- [ ] `Invoke-ExecDisableArchive.ps1` (guard + delegate `Set-CIPPMailboxArchive`)
- [ ] Regenerate OpenAPI
- [ ] Mailbox view UI (ticket + dry run preview)

## Phase 2 — Move worker

- [x] Graph archive folder discovery + batch move + verify (import/export APIs)
- [x] EWS fallback (ArchiveMsgFolderRoot shallow FindItem + CopyItem + delete source)
- [x] Resume/throttle on job row (CheckpointJson, Partial status, scheduled requeue)

## Phase 3 — Docs + integration test notes

- [ ] README permissions + user doc + API examples
