# EXO Read Test Cmdlets (#3281675 PR1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Accept two allowlisted `Test-*` EXO cmdlets on `ListExoRequest` as reads with strict validation and `Tenant.AppGovernance.Read`.

**Architecture:** New `ExoReadTestAllowlist.json` + `Get-CIPPExoReadTestCmdletPlan` (+ shared param-name helper). `Invoke-ListExoRequest` branches on verb `Test`, checks role, validates, forces `useSystemMailbox`, adds OrganizationScopedGrant meta, logs count only.

**Tech Stack:** PowerShell Azure Functions, Pester, CIPPCore GuardedWrites config layout, OpenAPI.

## Global Constraints

- Draft PR only; no merge/deploy without Clint OK.
- No secrets or client data in diffs, logs, or PR text.
- Explicit cmdlet names only; never verb wildcards for Test.
- Reads and writes stay separate; no audit row for this read path.

---

## File map

| File | Responsibility |
| --- | --- |
| `backend/Config/GuardedWrites/ExoReadTestAllowlist.json` | Two Test cmdlets + allowed param names |
| `backend/Modules/CIPPCore/Private/Test-CIPPExoParameterName.ps1` | Shared ASCII param-name rule |
| `backend/Modules/CIPPCore/Public/GuardedWrite/Get-CIPPExoReadTestCmdletPlan.ps1` | Load allowlist, validate names/values |
| `backend/Modules/CIPPCore/Public/GuardedWrite/Get-CIPPExoAllowlistedCmdletPlan.ps1` | Call shared param-name helper |
| `backend/Modules/CIPPHTTP/.../Invoke-ListExoRequest.ps1` | Test verb path + role + meta |
| `backend/Tests/GuardedWrite/ExoReadTestCmdlet.Tests.ps1` | PR1 Pester cases |
| `docs/api-documentation/exchange-rbac-for-applications.md` | Interpretation + read path |
| `docs/api-documentation/guarded-writes.md` | Cross-link |
| `backend/Config/openapi.json` | ListExoRequest description |

---

### Task 1: Allowlist + shared validation + plan helper

**Files:** create allowlist JSON; create `Test-CIPPExoParameterName.ps1`; create `Get-CIPPExoReadTestCmdletPlan.ps1`; refactor allowlisted plan to use helper.

- [ ] Write failing Pester for plan helper (accept good SPA/AAP; reject other Test, bad GUID, missing Resource, wildcards, arrays, bad param names).
- [ ] Implement allowlist + helpers until tests pass.
- [ ] Refactor `Get-CIPPExoAllowlistedCmdletPlan` to use `Test-CIPPExoParameterName` (existing allowlist tests still pass).

### Task 2: Extend `Invoke-ListExoRequest`

- [ ] Failing tests: Test path role gate, allowlist, useSystemMailbox forced, OrganizationScopedGrant, Get/Search unchanged, no audit.
- [ ] Implement entrypoint branch; mock `New-ExoRequest` / `Get-CippRequestAllowedPermissions`.
- [ ] Update DESCRIPTION comment for OpenAPI regen awareness.

### Task 3: Docs + OpenAPI + Aikido + draft PR

- [ ] Write `exchange-rbac-for-applications.md`; cross-link from guarded-writes.
- [ ] Update OpenAPI ListExoRequest description (and Meta if schema lists it).
- [ ] Run Pester for new + allowlist suites; Aikido scan modified files; commit; push; `gh pr create --draft`.
