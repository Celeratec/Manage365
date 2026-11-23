# Task 7 Report: Counts-only converter + search action orchestrator

## Status

Completed on branch `clint/ediscovery-stats-search`.

## Changes

- Extended `ConvertTo-CIPPEdiscoveryCountsOnly` to strip additional content-like fields including sender, preview, fileName, content, recipient, and body.
- Added `Invoke-CIPPEdiscoverySearchAction` with guarded write evaluation, required reason handling, default dry run, per-tenant in-flight lock, dry-run plan output, live case reuse/create, custodian mailbox source creation, per-term search estimates, and counts-only audit payloads containing only `TermCount` and `KqlHash`.
- Added `EdiscoverySearchAction.Tests.ps1` covering dry run with no Graph writes, converter stripping, missing reason, term limit rejection, and live per-term orchestration.

## Verification

- `pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/Ediscovery/EdiscoverySearchAction.Tests.ps1 -Output Detailed"`: passed, 5/5.
- `pwsh -NoProfile -Command "Invoke-Pester -Path backend/Tests/Ediscovery -Output Detailed"`: passed, 63/63.
- `Invoke-ScriptAnalyzer` on modified production PowerShell files: no warnings or errors.
- Cursor `ReadLints` on modified files: no linter errors.
- Aikido scan on modified files: no issues.
- `git diff --check`: clean.

## Concerns

- Live per-term estimates intentionally run one estimate per term and return an overlap note; aggregate totals are summed from per-term estimates and may over-count when terms overlap.
