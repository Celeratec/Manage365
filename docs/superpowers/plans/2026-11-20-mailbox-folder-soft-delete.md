# Soft-delete mailbox folder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add guarded `ExecSoftDeleteMailboxFolder` and `ExecRestoreMailboxFolder` that soft-delete (Graph move to Deleted Items) / restore a single mailbox folder with ticket, reason, preview-default-true, refuse guards, before/after verify, and audit.

**Architecture:** HTTP entrypoints normalize `preview`/`dryRun` (default true), call `Test-CIPPGuardedWriteRequest`, then CIPPCore helpers for resolve → guards → before-state → optional Graph `mailFolders/{id}/move` → verify → `Add-CIPPGuardedWriteAudit`. Both Exec names are listed on `GuardedTenantWrites` (repo default off). After deploy, enable the flag on this Manage365 instance.

**Tech Stack:** Azure Functions PowerShell, Microsoft Graph (`New-GraphGetRequest` / `New-GraphPOSTRequest`), Pester, GuardedWriteAudit table, FeatureFlags.

**Spec:** `docs/superpowers/specs/2026-11-20-mailbox-folder-soft-delete-design.md`

## Global Constraints

- Fork only (Celeratec/Manage365); no upstream PRs; never push/merge to main without Clint.
- **No `DELETE` verb** and no permanent delete on this path; soft-delete = move to `deleteditems` only.
- Never bypass Recoverable Items.
- `TicketNumber` 6–8 digits; `Reason` required (empty → 400); `preview`/`dryRun` defaults **true**.
- Refuse well-known/default folders, shared/linked/delegated calendars, folders already in Deleted Items, search folders — by well-known id/name, not display name.
- Preview makes **zero** Graph write calls; Pester must fail if a write helper runs.
- No secrets/tokens in logs, audit, or responses; no message bodies/subjects in audit.
- Live Graph checks only on a **test** mailbox/tenant — never client mailboxes.
- Always run `aikido_full_scan` on generated/modified first-party code and fix findings before done.
- Nothing to production without Clint’s explicit OK; enabling `GuardedTenantWrites` on this instance is a post-deploy ops step.

## File map

| File | Responsibility |
|------|----------------|
| `backend/Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderWellKnownNames.ps1` | Canonical well-known name set |
| `backend/Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteGuards.ps1` | Refuse-list evaluation on a resolved folder object |
| `backend/Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteRequest.ps1` | Parse body: userId, folderId\|folderPath, folderType, Reason; normalize preview default true onto request |
| `backend/Modules/CIPPCore/Public/MailboxFolder/Resolve-CIPPMailboxFolder.ps1` | Resolve by id or exact path via Graph GET (read-only) |
| `backend/Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderBeforeState.ps1` | Path, ids, class, counts, size, oldest/newest dates |
| `backend/Modules/CIPPCore/Public/MailboxFolder/Invoke-CIPPMailboxFolderSoftDelete.ps1` | Preview or move + verify |
| `backend/Modules/CIPPCore/Public/MailboxFolder/Invoke-CIPPMailboxFolderRestore.ps1` | Preview or move back + verify |
| `backend/Modules/CIPPHTTP/.../Administration/Invoke-ExecSoftDeleteMailboxFolder.ps1` | HTTP facade |
| `backend/Modules/CIPPHTTP/.../Administration/Invoke-ExecRestoreMailboxFolder.ps1` | HTTP facade |
| `backend/Config/FeatureFlags.json` | Add both Exec names to `GuardedTenantWrites.Endpoints` |
| `backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1` | Guards, preview zero writes, verify, restore |
| `backend/Tests/GuardedWrite/GuardedWrite.Tests.ps1` | Extend flag endpoint list assertions |
| `docs/api-documentation/guarded-writes.md` | Soft-delete prohibition + endpoints |
| `README.md` | Release note + prohibition |
| `backend/Config/openapi.json` | Regen after entrypoints exist |

---

### Task 1: Well-known names + refuse guards (TDD)

**Files:**
- Create: `backend/Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderWellKnownNames.ps1`
- Create: `backend/Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteGuards.ps1`
- Create: `backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1`

**Interfaces:**
- Produces: `Get-CIPPMailboxFolderWellKnownNames` → `[string[]]` lowercase Graph well-known names
- Produces: `Test-CIPPMailboxFolderSoftDeleteGuards -Folder <psobject> -DeletedItemsId <string>` → `[pscustomobject]@{ Ok = [bool]; Reason = [string] }`

- [ ] **Step 1: Write failing tests for well-known and refuse guards**

Create `backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1`:

```powershell
Describe 'Test-CIPPMailboxFolderSoftDeleteGuards' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderWellKnownNames.ps1')
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteGuards.ps1')
    }

    It 'refuses inbox by wellKnownName' {
        $Folder = [pscustomobject]@{ id = 'abc'; wellKnownName = 'inbox'; displayName = 'Not Inbox'; parentFolderId = 'parent' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'well-known|default'
    }

    It 'refuses calendar root by wellKnownName even if displayName differs' {
        $Folder = [pscustomobject]@{ id = 'cal'; wellKnownName = 'calendar'; displayName = 'My Calendar'; parentFolderId = 'msgroot' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
    }

    It 'refuses shared or linked calendars' {
        $Folder = [pscustomobject]@{
            id             = 'shared1'
            wellKnownName  = $null
            displayName    = 'Cody Rogers'
            parentFolderId = 'cal-root'
            isShared       = $true
            owner          = @{ address = 'other@contoso.com' }
        }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -MailboxUpn 'user@contoso.com'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'shared|linked|delegat'
    }

    It 'refuses a folder already under Deleted Items' {
        $Folder = [pscustomobject]@{ id = 'x'; wellKnownName = $null; parentFolderId = 'del-id'; displayName = 'Old' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'Deleted Items'
    }

    It 'refuses search folders' {
        $Folder = [pscustomobject]@{ id = 's'; wellKnownName = $null; parentFolderId = 'p'; isSearchFolder = $true; displayName = 'Search' }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id'
        $Result.Ok | Should -BeFalse
        $Result.Reason | Should -Match 'search'
    }

    It 'allows a normal child calendar folder' {
        $Folder = [pscustomobject]@{
            id              = 'ok'
            wellKnownName   = $null
            parentFolderId  = 'cal-root'
            displayName     = 'Cody Rogers'
            isShared        = $false
            isSearchFolder  = $false
        }
        $Result = Test-CIPPMailboxFolderSoftDeleteGuards -Folder $Folder -DeletedItemsId 'del-id' -MailboxUpn 'user@contoso.com'
        $Result.Ok | Should -BeTrue
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL (functions missing)**

```bash
pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1 -Output Detailed"
```

Expected: FAIL — command/file not found.

- [ ] **Step 3: Implement well-known list + guards**

`Get-CIPPMailboxFolderWellKnownNames.ps1`:

```powershell
function Get-CIPPMailboxFolderWellKnownNames {
    <#
    .SYNOPSIS
        Graph well-known mail folder names that must never be soft-deleted.
    #>
    [CmdletBinding()]
    param()
    @(
        'inbox', 'drafts', 'sentitems', 'deleteditems', 'junkemail', 'outbox',
        'archive', 'clutter', 'conflicts', 'conversationhistory', 'localfailures',
        'serverfailures', 'syncissues', 'msgfolderroot', 'root', 'calendar',
        'contacts', 'notes', 'tasks', 'recoverableitemsroot', 'recoverableitemsdeletions',
        'recoverableitemsversions', 'recoverableitemspurges'
    )
}
```

`Test-CIPPMailboxFolderSoftDeleteGuards.ps1`:

```powershell
function Test-CIPPMailboxFolderSoftDeleteGuards {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Folder,
        [Parameter(Mandatory)][string]$DeletedItemsId,
        [string]$MailboxUpn
    )
    $WellKnown = Get-CIPPMailboxFolderWellKnownNames
    $Wkn = [string]$Folder.wellKnownName
    if (-not [string]::IsNullOrWhiteSpace($Wkn) -and $WellKnown -contains $Wkn.ToLowerInvariant()) {
        return [pscustomobject]@{ Ok = $false; Reason = "Refusing well-known/default folder '$Wkn'." }
    }
    if ($Folder.isSearchFolder -eq $true) {
        return [pscustomobject]@{ Ok = $false; Reason = 'Refusing search folders.' }
    }
    if ([string]$Folder.parentFolderId -eq $DeletedItemsId -or $Wkn -eq 'deleteditems') {
        return [pscustomobject]@{ Ok = $false; Reason = 'Folder is already under Deleted Items.' }
    }
    $Shared = ($Folder.isShared -eq $true) -or ($Folder.isRemovable -eq $false -and $null -ne $Folder.owner)
    if ($Folder.PSObject.Properties.Name -contains 'canShare' -and $Folder.isDefaultCalendar -eq $true -and $Folder.isShared -eq $true) {
        $Shared = $true
    }
    if ($null -ne $Folder.owner) {
        $OwnerAddr = [string]($Folder.owner.address ?? $Folder.owner.emailAddress ?? $Folder.owner)
        if (-not [string]::IsNullOrWhiteSpace($MailboxUpn) -and -not [string]::IsNullOrWhiteSpace($OwnerAddr) -and $OwnerAddr -ne $MailboxUpn) {
            $Shared = $true
        }
    }
    if ($Shared) {
        return [pscustomobject]@{ Ok = $false; Reason = 'Refusing shared, linked, or delegated calendars that point at another mailbox.' }
    }
    return [pscustomobject]@{ Ok = $true; Reason = $null }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1 -Output Detailed"
```

- [ ] **Step 5: Commit**

```bash
git add backend/Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderWellKnownNames.ps1 \
  backend/Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteGuards.ps1 \
  backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1
git commit -m "$(cat <<'EOF'
feat: add mailbox folder soft-delete refuse guards

EOF
)"
```

---

### Task 2: Request normalization (preview default true + required Reason)

**Files:**
- Create: `backend/Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteRequest.ps1`
- Modify: `backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1`

**Interfaces:**
- Produces: `Test-CIPPMailboxFolderSoftDeleteRequest -Request $Request` → `[pscustomobject]@{ Ok; StatusCode; Message; UserId; FolderId; FolderPath; FolderType; Preview; Reason }`  
  Mutates `$Request.Body` so `dryRun` is set when `preview`/`dryRun`/`WhatIf` all omitted (**default true**), and maps `preview` → `dryRun` when `preview` is present.

- [ ] **Step 1: Write failing tests**

Append to the Pester file:

```powershell
Describe 'Test-CIPPMailboxFolderSoftDeleteRequest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteRequest.ps1')
    }

    It 'defaults preview to true when dryRun and preview omitted' {
        $Body = [pscustomobject]@{
            tenantFilter = 'contoso.onmicrosoft.com'
            userId       = 'user@contoso.com'
            folderId     = 'folder-1'
            folderType   = 'calendar'
            TicketNumber = '3281353'
            Reason       = 'stale calendar copy'
        }
        $Req = @{ Body = $Body; Headers = @{} }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request $Req
        $Parsed.Ok | Should -BeTrue
        $Parsed.Preview | Should -BeTrue
        [string]$Req.Body.dryRun | Should -Be 'True'
    }

    It 'rejects missing Reason' {
        $Body = [pscustomobject]@{
            tenantFilter = 't'; userId = 'u@t.com'; folderId = 'f'; folderType = 'mail'
            TicketNumber = '3281353'
        }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.StatusCode | Should -Be 400
        $Parsed.Message | Should -Match 'Reason'
    }

    It 'rejects both folderId and folderPath missing' {
        $Body = [pscustomobject]@{
            tenantFilter = 't'; userId = 'u@t.com'; folderType = 'mail'
            TicketNumber = '3281353'; Reason = 'x'
        }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.Message | Should -Match 'folderId|folderPath'
    }

    It 'rejects both folderId and folderPath set' {
        $Body = [pscustomobject]@{
            tenantFilter = 't'; userId = 'u@t.com'; folderType = 'mail'
            folderId = 'a'; folderPath = '\Inbox\X'
            TicketNumber = '3281353'; Reason = 'x'
        }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
    }

    It 'rejects invalid folderType' {
        $Body = [pscustomobject]@{
            tenantFilter = 't'; userId = 'u@t.com'; folderId = 'a'; folderType = 'notes'
            TicketNumber = '3281353'; Reason = 'x'
        }
        $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request @{ Body = $Body; Headers = @{} }
        $Parsed.Ok | Should -BeFalse
        $Parsed.Message | Should -Match 'folderType'
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement `Test-CIPPMailboxFolderSoftDeleteRequest`**

Normalize preview onto body **before** callers invoke `Test-CIPPGuardedWriteRequest`:

```powershell
function Test-CIPPMailboxFolderSoftDeleteRequest {
    [CmdletBinding()]
    param($Request)

    $Body = $Request.Body
    $UserId = [string]($Body.userId ?? $Body.userid ?? $Body.UserPrincipalName)
    $FolderId = [string]$Body.folderId
    $FolderPath = [string]$Body.folderPath
    $FolderType = ([string]$Body.folderType).ToLowerInvariant()
    $Reason = [string]($Body.Reason ?? $Body.reason)

    $PreviewRaw = $Body.preview
    $DryRunRaw = $Body.dryRun
    if ($null -eq $DryRunRaw -or "$DryRunRaw" -eq '') { $DryRunRaw = $Body.WhatIf }
    $Preview = $true
    if (($null -ne $PreviewRaw -and "$PreviewRaw" -ne '') -or ($null -ne $DryRunRaw -and "$DryRunRaw" -ne '')) {
        $Raw = if ($null -ne $PreviewRaw -and "$PreviewRaw" -ne '') { $PreviewRaw } else { $DryRunRaw }
        if ("$Raw" -notin @('true', 'false', '1', '0', 'True', 'False')) {
            return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'preview/dryRun must be true or false.' }
        }
        $Preview = "$Raw" -in @('true', 'True', '1')
    }
    # Force dryRun on body so Test-CIPPGuardedWriteRequest does not default WhatIf to false
    if ($Body -is [hashtable] -or $Body -is [System.Collections.IDictionary]) {
        $Body['dryRun'] = $Preview
    } else {
        $Body | Add-Member -NotePropertyName dryRun -NotePropertyValue $Preview -Force
    }

    if ([string]::IsNullOrWhiteSpace($UserId)) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'userId is required.' }
    }
    if ([string]::IsNullOrWhiteSpace($Reason)) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'Reason is required.' }
    }
    $HasId = -not [string]::IsNullOrWhiteSpace($FolderId)
    $HasPath = -not [string]::IsNullOrWhiteSpace($FolderPath)
    if ($HasId -eq $HasPath) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'Provide exactly one of folderId or folderPath.' }
    }
    if ($FolderType -notin @('mail', 'calendar')) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = "folderType must be 'mail' or 'calendar'." }
    }

    return [pscustomobject]@{
        Ok         = $true
        StatusCode = 200
        UserId     = $UserId
        FolderId   = $(if ($HasId) { $FolderId } else { $null })
        FolderPath = $(if ($HasPath) { $FolderPath } else { $null })
        FolderType = $FolderType
        Preview    = $Preview
        Reason     = $Reason
    }
}
```

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit**

```bash
git add backend/Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderSoftDeleteRequest.ps1 \
  backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1
git commit -m "$(cat <<'EOF'
feat: validate mailbox folder soft-delete request envelope

EOF
)"
```

---

### Task 3: Resolve folder + before-state (read-only Graph)

**Files:**
- Create: `backend/Modules/CIPPCore/Public/MailboxFolder/Resolve-CIPPMailboxFolder.ps1`
- Create: `backend/Modules/CIPPCore/Public/MailboxFolder/Get-CIPPMailboxFolderBeforeState.ps1`
- Modify: `backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1`

**Interfaces:**
- Produces: `Resolve-CIPPMailboxFolder -TenantFilter -UserId -FolderId -FolderPath -FolderType` → folder object + `DeletedItemsId` + `Path`
- Produces: `Get-CIPPMailboxFolderBeforeState -TenantFilter -UserId -Folder` → before-state hashtable (path, id, parentId, parentPath, folderClass, itemCount, size, oldestItemDate, newestItemDate)
- Consumes: `New-GraphGetRequest` only (no POST)

Resolution strategy:
1. GET `https://graph.microsoft.com/v1.0/users/{userId}/mailFolders/deleteditems?$select=id,displayName,wellKnownName` → `DeletedItemsId`.
2. If `FolderId`: GET `.../mailFolders/{folderId}?$select=id,displayName,parentFolderId,wellKnownName,totalItemCount,unreadItemCount,childFolderCount,sizeInBytes,isHidden` (and calendar extras if `folderType=calendar`: also try calendar properties via GET calendar if needed for `isShared`/`owner`).
3. If `FolderPath`: walk from `msgfolderroot` (or `calendar` for calendar paths starting `\Calendar\...`) via `childFolders`, matching exact displayName segments; fail if zero or multiple matches at a segment.
4. Build path by walking parents until root (cap depth 32).

Before-state item dates: GET `.../mailFolders/{id}/messages?$select=receivedDateTime,createdDateTime&$orderby=receivedDateTime asc&$top=1` and `desc&$top=1` (for calendar folders use `.../calendar/events` or messages under that folder — prefer messages on the mailFolder id first; if empty and folderType calendar, document fallback). Do not store subjects/bodies.

- [ ] **Step 1: Write tests with mocked `New-GraphGetRequest`** that assert resolve-by-path and before-state shape; assert `New-GraphPOSTRequest` never defined/called.

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement resolve + before-state**

Use `-AsApp $true` consistently with other mailbox Graph helpers. URL-encode userId and folderId segments.

For calendar shared detection: after resolving mailFolder, if `folderType -eq 'calendar'`, optionally GET `v1.0/users/{id}/calendars?$select=id,name,isShared,owner,canEdit,isDefaultCalendar` and match by name; merge `isShared`/`owner` onto the folder object before guards.

- [ ] **Step 4: Run — PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: resolve mailbox folder and collect before-state via Graph

EOF
)"
```

---

### Task 4: Soft-delete core (preview zero writes + verify)

**Files:**
- Create: `backend/Modules/CIPPCore/Public/MailboxFolder/Invoke-CIPPMailboxFolderSoftDelete.ps1`
- Modify: `backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1`

**Interfaces:**
- Produces: `Invoke-CIPPMailboxFolderSoftDelete -TenantFilter -UserId -Parsed -Preview` → result object with `Status`, `Before`, `PlannedMove`, `After`, `deletedFolderId`, `originalParentId`, `Results`
- Consumes: Resolve, BeforeState, Guards, `New-GraphPOSTRequest` only when `-Preview:$false`

Move body (real run only):

```powershell
$Uri = "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserId))/mailFolders/$([uri]::EscapeDataString($Folder.id))/move"
$Moved = New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -type 'POST' -body (@{ destinationId = 'deleteditems' } | ConvertTo-Json -Compress)
```

Verify:
1. GET old folder id → must 404 / not found.
2. GET moved id under deleted items → `totalItemCount` equals before count.
3. Else throw / return `Status = 'Failed'`.

**Hard rule:** Search this function for `DELETE` / `type = 'DELETE'` — none allowed.

- [ ] **Step 1: Write failing tests**

```powershell
Describe 'Invoke-CIPPMailboxFolderSoftDelete preview' {
    It 'makes zero Graph write calls in preview' {
        $script:PostCalls = 0
        function New-GraphGetRequest { param($uri, $tenantid, $AsApp) 
            # return stub folder tree / deleteditems / target folder as needed
        }
        function New-GraphPOSTRequest { param($uri, $tenantid, $body, $type, $AsApp)
            $script:PostCalls++
            throw 'write should not run in preview'
        }
        # ... wire resolve stubs / or Mock ...
        $Result = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter 't' -UserId 'u@t.com' -FolderId 'child' -FolderType 'calendar' -Preview $true
        $Result.Status | Should -Be 'DryRun'
        $script:PostCalls | Should -Be 0
    }
}

Describe 'Invoke-CIPPMailboxFolderSoftDelete real run' {
    It 'fails loudly when after-state item count mismatches' {
        # Mock move success, then GET under deleteditems with wrong totalItemCount
        # Expect Status Failed and no Success
    }

    It 'returns deletedFolderId and originalParentId on success' {
        # Mock move + verify match
    }
}
```

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement soft-delete**

Flow:
1. Resolve folder + DeletedItemsId
2. Before-state
3. Guards — if not Ok, return Failed/400 reason (caller maps to HTTP)
4. If Preview: return DryRun with Before + PlannedMove `{ destinationId = 'deleteditems' }` — **return before any POST**
5. Else POST move; capture new id; verify; return Success or Failed

- [ ] **Step 4: Run — PASS** (especially preview PostCalls = 0)

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: soft-delete mailbox folder via Graph move with preview and verify

EOF
)"
```

---

### Task 5: Restore core

**Files:**
- Create: `backend/Modules/CIPPCore/Public/MailboxFolder/Invoke-CIPPMailboxFolderRestore.ps1`
- Create: `backend/Modules/CIPPCore/Public/MailboxFolder/Test-CIPPMailboxFolderRestoreRequest.ps1`
- Modify: `backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1`

**Interfaces:**
- Produces: `Test-CIPPMailboxFolderRestoreRequest` — requires `deletedFolderId`, `originalParentId`, `userId`, `folderType`, `Reason`; same preview default true
- Produces: `Invoke-CIPPMailboxFolderRestore` — guards: folder must currently be under Deleted Items; destination must not be a refused well-known target for “restore into defaults” beyond original parent id; preview zero writes; real run `destinationId = originalParentId`; verify folder present under parent with same count

- [ ] **Step 1: Failing tests** (missing reason, preview zero posts, success returns restored id)

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement**

```powershell
$Uri = "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserId))/mailFolders/$([uri]::EscapeDataString($DeletedFolderId))/move"
$Moved = New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -type 'POST' -body (@{ destinationId = $OriginalParentId } | ConvertTo-Json -Compress)
```

- [ ] **Step 4: Run — PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: restore soft-deleted mailbox folder to original parent

EOF
)"
```

---

### Task 6: HTTP entrypoints + FeatureFlags + GuardedWrite tests

**Files:**
- Create: `backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecSoftDeleteMailboxFolder.ps1`
- Create: `backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecRestoreMailboxFolder.ps1`
- Modify: `backend/Config/FeatureFlags.json` — append `"ExecSoftDeleteMailboxFolder"`, `"ExecRestoreMailboxFolder"` to `GuardedTenantWrites.Endpoints` (leave `Enabled: false`)
- Modify: `backend/Tests/GuardedWrite/GuardedWrite.Tests.ps1` — assert those two names are in Endpoints; `Enabled` still false

**Entrypoint pattern:**

```powershell
function Invoke-ExecSoftDeleteMailboxFolder {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    .DESCRIPTION
        Soft-deletes one mailbox folder by moving it to Deleted Items (never permanent delete).
        Requires tenantFilter, userId, folderId or folderPath, folderType (mail|calendar),
        ticketNumber (6-8 digits), and Reason. preview/dryRun defaults to true (read-only).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request $Request
    if (-not $Parsed.Ok) {
        return [HttpResponseContext]@{ StatusCode = $Parsed.StatusCode; Body = @{ Results = $Parsed.Message; Status = 'Failed' } }
    }
    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite:(-not $Parsed.Preview)
    if (-not $Gate.Ok) {
        $Headers = @{}
        if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
    }
    try {
        $Outcome = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter $Gate.Tenant -UserId $Parsed.UserId `
            -FolderId $Parsed.FolderId -FolderPath $Parsed.FolderPath -FolderType $Parsed.FolderType -Preview $Parsed.Preview
        $AuditResult = if ($Outcome.Status -eq 'DryRun') { 'DryRun' } elseif ($Outcome.Status -eq 'Success') { 'Success' } else { [string]$Outcome.Results }
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller `
            -Request $Request.Body -Before $Outcome.Before -After $Outcome.After -DryRun $Parsed.Preview -Result $AuditResult
        $StatusCode = if ($Outcome.Status -eq 'Failed') { [HttpStatusCode]::BadRequest } else { [HttpStatusCode]::OK }
        return [HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{
                Results            = $Outcome.Results
                Status             = $Outcome.Status
                AuditId            = $AuditId
                Before             = $Outcome.Before
                After              = $Outcome.After
                PlannedMove        = $Outcome.PlannedMove
                deletedFolderId    = $Outcome.deletedFolderId
                originalParentId   = $Outcome.originalParentId
                ticketNumber       = $Gate.Ticket
                reason             = $Parsed.Reason
                preview            = $Parsed.Preview
                dryRun             = $Parsed.Preview
            }
        }
    } catch {
        $Msg = (Get-CippException -Exception $_).NormalizedError
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Parsed.Preview -Result $Msg
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = $Msg; Status = 'Failed'; AuditId = $AuditId } }
    }
}
```

Mirror for restore with `Test-CIPPMailboxFolderRestoreRequest` + `Invoke-CIPPMailboxFolderRestore`.

- [ ] **Step 1: Update GuardedWrite.Tests.ps1 flag list to require the two new endpoint names (test fails until FeatureFlags updated)**

- [ ] **Step 2: Run that It — FAIL**

- [ ] **Step 3: Update FeatureFlags.json + add both Invoke-Exec*.ps1 files**

- [ ] **Step 4: Run GuardedWrite + MailboxFolder tests — PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: add ExecSoftDeleteMailboxFolder and ExecRestoreMailboxFolder endpoints

EOF
)"
```

---

### Task 7: Docs, OpenAPI, permissions note

**Files:**
- Modify: `docs/api-documentation/guarded-writes.md`
- Modify: `README.md` (new release section under current banner — do not bump version numbers unless releasing; add a “Unreleased / next” or next patch section describing soft-delete prohibition)
- Regenerate: `backend/Config/openapi.json` via `pwsh -File build/tools/build-openapi.ps1` (or repo’s documented command)
- Optional: short note in guarded-writes.md: expected Graph app permissions `Mail.ReadWrite` (and `Calendars.ReadWrite` if calendar folder move requires it); “confirm against SAM app after test-mailbox verification”

README prohibition text (required):

> Mailbox folder removal is soft-delete only: Manage365 moves the folder to Deleted Items via Graph. Permanent delete is prohibited. Well-known/default folders, shared/linked/delegated calendars, folders already in Deleted Items, and search folders are refused. `ExecSoftDeleteMailboxFolder` and `ExecRestoreMailboxFolder` sit on **Guarded tenant writes** (preview/dryRun defaults true; ticket + reason required). Enabling that flag on an instance enables all endpoints on the flag.

- [ ] **Step 1: Edit guarded-writes.md table + prohibition paragraph**

- [ ] **Step 2: Edit README**

- [ ] **Step 3: Regen OpenAPI; assert paths `/api/ExecSoftDeleteMailboxFolder` and `/api/ExecRestoreMailboxFolder` exist**

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
docs: document mailbox folder soft-delete prohibition and endpoints

EOF
)"
```

---

### Task 8: Aikido scan + draft PR

- [ ] **Step 1: Run `aikido_full_scan` on every new/modified first-party file (full file contents). Fix any findings; rescan until clean.** If Aikido MCP unavailable, stop and point to https://help.aikido.dev/ide-plugins/aikido-mcp

- [ ] **Step 2: Run lint/typecheck/tests relevant to backend Pester suites touched**

```bash
pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/MailboxFolder/MailboxFolderSoftDelete.Tests.ps1,backend/Tests/GuardedWrite/GuardedWrite.Tests.ps1 -Output Detailed"
```

- [ ] **Step 3: Push branch and open draft PR**

```bash
git push -u origin clint/mailbox-folder-soft-delete
gh pr create --draft --title "feat: guarded soft-delete mailbox folder (#3281353)" --body "$(cat <<'EOF'
## Summary
- Adds `ExecSoftDeleteMailboxFolder` and `ExecRestoreMailboxFolder` (Graph move to/from Deleted Items only; no DELETE).
- Guards: well-known/default, shared/linked/delegated, already deleted, search folders; ticket + reason; preview defaults true with zero write calls.
- Behind `GuardedTenantWrites` (repo default off). After deploy, enable the flag on this Manage365 instance (enables all listed guarded writes).
- README / guarded-writes.md document the soft-delete-only prohibition.

## Risk
Medium — mailbox mutation. Soft-delete only; restore companion included. Flag gates production use.

## Test plan
- [ ] Pester MailboxFolderSoftDelete + GuardedWrite flag list
- [ ] Preview path: confirm no Graph POST in tests
- [ ] Test-tenant mailbox only: calendar folder (`IPF.Appointment`) move works; document if alternate API needed
- [ ] Confirm SAM Graph permissions (`Mail.ReadWrite` / `Calendars.ReadWrite`)
- [ ] App QA + App Security + CodeRabbit
- [ ] Clint OK before merge/deploy/flag enable
- [ ] M365 Engineer: preview then real run for #3281353 with backup/verify

## Rollback
- Turn off `GuardedTenantWrites` on the instance, and/or `ExecRestoreMailboxFolder` with returned ids, and/or image rollback.

EOF
)"
```

- [ ] **Step 4: Report branch + PR URL. Do not enable the flag or run against Miller Law until Clint says OK.**

---

## Post-merge ops (not in PR code)

1. Deploy image containing this PR.
2. Enable **Guarded tenant writes** on this Manage365 instance.
3. Give M365 Engineer:

**Soft-delete (preview first):**
```json
POST /api/ExecSoftDeleteMailboxFolder
{
  "tenantFilter": "<tenant>",
  "userId": "<upn>",
  "folderPath": "\\Calendar\\Cody Rogers",
  "folderType": "calendar",
  "TicketNumber": "3281353",
  "Reason": "Remove stale local calendar copy",
  "preview": true
}
```

Then same body with `"preview": false`. Use returned `deletedFolderId` + `originalParentId` for restore if needed.

---

## Plan self-review

| Spec requirement | Task |
|------------------|------|
| Dedicated soft-delete + restore endpoints | 6 |
| Soft-delete = move to deleteditems; no DELETE | 4, 5 |
| Refuse well-known / shared / deleted / search | 1, 4 |
| Before-state fields | 3 |
| After verify + fail loud | 4, 5 |
| Rollback ids + restore action | 4, 5, 6 |
| Preview default true, zero writes + test | 2, 4 |
| Audit ticket/reason/actor/before/after | 6 |
| GuardedTenantWrites + enable on instance | 6 + post-merge |
| README prohibition | 7 |
| Graph permissions doc + test mailbox | 7 + post-merge |
| Unit tests fail if guard removed | 1 |
| Draft PR, no prod without Clint | 8 |

No TBD placeholders; preview default explicitly forced onto `Request.Body.dryRun` so `Test-CIPPGuardedWriteRequest` cannot flip it to false.
