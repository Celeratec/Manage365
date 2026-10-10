# Trim Azurite table caches when the LokiJS DB is large enough to crash Azurite.
#
# Azurite stores every table in one JSON file and loads it as a single Node string.
# V8 refuses strings longer than 0x1fffffe8 (~512 MiB), so a full CippReportingDB
# cache will crash Table startup with:
#   Cannot create a string longer than 0x1fffffe8 characters
#
# This keeps Tenants/Config/Settings and only empties recreatable cache tables.
# Called from Start-Cipp-Dev-Windows-docker.ps1 before compose up. Missing volume
# or table DB is a skip, not a failure — startup must still continue.

[CmdletBinding()]
param(
    [string]$VolumeName = 'cipp-ng_azurite-data',
    [string]$TableDbFile = '__azurite_db_table__.json',
    # Headroom under the ~512 MiB V8 string cap so a session of cache writes cannot immediately re-crash Azurite.
    [long]$TrimThresholdBytes = 400MB
)

# Best-effort: a missing table DB or a failed size probe must never abort compose up.
$ErrorActionPreference = 'Stop'

function Write-AzuriteTrimSkip {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor DarkGray
}

function Get-AzuriteTableDbSize {
    param([string]$Volume, [string]$FileName)

    $probe = @"
if [ -f /workspace/$FileName ]; then stat -c%s /workspace/$FileName; else echo 0; fi
"@
    $output = docker run --rm --network none -v "${Volume}:/workspace" alpine sh -c $probe 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    $sizeLine = @($output) | Where-Object { $_ -match '^\d+$' } | Select-Object -Last 1
    if (-not $sizeLine) {
        return $null
    }
    return [long]$sizeLine
}

try {
$volumes = @(docker volume ls --format '{{.Name}}')
if ($LASTEXITCODE -ne 0) {
    Write-AzuriteTrimSkip 'Could not list Docker volumes; skip cache trim.'
    return
}
if ($volumes -notcontains $VolumeName) {
    Write-AzuriteTrimSkip "Azurite volume '$VolumeName' does not exist yet; skip cache trim."
    return
}

Write-Host 'Checking Azurite table DB size...' -ForegroundColor DarkGray
$size = Get-AzuriteTableDbSize -Volume $VolumeName -FileName $TableDbFile
if ($null -eq $size) {
    Write-AzuriteTrimSkip "Could not find or inspect $TableDbFile; skip cache trim."
    return
}
if ($size -le 0) {
    Write-AzuriteTrimSkip 'No table DB yet; skip cache trim.'
    return
}

$sizeMb = [math]::Round($size / 1MB, 1)
if ($size -lt $TrimThresholdBytes) {
    Write-Host ("  {0} is {1} MB (trim at {2} MB)." -f $TableDbFile, $sizeMb, [math]::Round($TrimThresholdBytes / 1MB)) -ForegroundColor DarkGray
    return
}

Write-Host ("  {0} is {1} MB — emptying cache tables so Azurite can start." -f $TableDbFile, $sizeMb) -ForegroundColor Yellow

$existing = docker ps -aq --filter "name=^cipp-azurite$"
if ($existing) {
    Write-Host '  Stopping cipp-azurite so the table DB can be rewritten...' -ForegroundColor DarkGray
    docker stop cipp-azurite | Out-Null
}

$python = @'
#!/usr/bin/env python3
import json
import os
import sys

PATH = "/workspace/" + os.environ["AZURITE_TABLE_DB"]
EXPLICIT = {"cippreportingdb", "calendarfoldercache", "reruncache"}

def table_from_collection(coll_name):
    if not coll_name or coll_name.startswith("$"):
        return None
    if "$" in coll_name:
        return coll_name.split("$", 1)[1]
    return coll_name

def should_empty(table):
    t = (table or "").lower()
    return t in EXPLICIT or t.startswith("cache")

def main():
    if not os.path.isfile(PATH):
        print("missing=1")
        return
    before = os.path.getsize(PATH)
    with open(PATH, "r", encoding="utf-8") as f:
        db = json.load(f)

    emptied = []
    for coll in db.get("collections") or []:
        table = table_from_collection(coll.get("name", ""))
        if not table or not should_empty(table):
            continue
        n = len(coll.get("data") or [])
        coll["data"] = []
        if "idIndex" in coll:
            coll["idIndex"] = []
        coll["dirtyIds"] = []
        coll["maxId"] = 0
        # Binary indices hold positions into data, so emptying the rows without emptying the
        # indices leaves LokiJS resolving point lookups - the single-entity get, merge and
        # delete paths - to rows that are not there, which the Table service reports as a 404
        # while range queries, which scan data directly, still succeed. An empty index is the
        # correct index for an emptied collection, so it is marked clean: LokiJS never rebuilds
        # a dirty index on a collection using adaptiveBinaryIndices anyway.
        for index in (coll.get("binaryIndices") or {}).values():
            index["values"] = []
            index["dirty"] = False
        emptied.append((coll.get("name", table), n))

    tmp = PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(db, f, separators=(",", ":"), ensure_ascii=False)
    os.replace(tmp, PATH)
    after = os.path.getsize(PATH)

    print(f"before_bytes={before}")
    print(f"after_bytes={after}")
    for name, n in sorted(emptied, key=lambda x: -x[1]):
        print(f"emptied\t{n}\t{name}")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
'@

$scriptPath = Join-Path $env:TEMP 'cipp-clear-azurite-cache.py'
Set-Content -Path $scriptPath -Value $python -Encoding utf8NoBOM

$trimOutput = docker run --rm --memory=4g --network none `
    -e "AZURITE_TABLE_DB=$TableDbFile" `
    -v "${VolumeName}:/workspace" `
    -v "${scriptPath}:/script.py:ro" `
    python:3-slim python /script.py
$trimExit = $LASTEXITCODE
Remove-Item -LiteralPath $scriptPath -ErrorAction SilentlyContinue

if ($trimExit -ne 0) {
    Write-Warning "Azurite cache trim failed; continuing startup.`n$trimOutput"
    return
}

$missing = $false
foreach ($line in @($trimOutput)) {
    if ($line -match '^missing=1$') {
        $missing = $true
    } elseif ($line -match '^emptied\t(\d+)\t(.+)$') {
        Write-Host ("    {0}: {1} rows" -f $Matches[2], $Matches[1]) -ForegroundColor DarkGray
    } elseif ($line -match '^after_bytes=(\d+)$') {
        $afterMb = [math]::Round([long]$Matches[1] / 1MB, 1)
        Write-Host ("  Table DB is now {0} MB. Tenant/config tables were left in place." -f $afterMb) -ForegroundColor Green
    }
}
if ($missing) {
    Write-AzuriteTrimSkip "Could not find $TableDbFile; skip cache trim."
    return
}

$afterSize = Get-AzuriteTableDbSize -Volume $VolumeName -FileName $TableDbFile
# 0x1fffffe8 UTF-16 units; ASCII JSON bytes ~= character count.
$nodeStringLimit = 536870888
if ($null -eq $afterSize) {
    Write-AzuriteTrimSkip "Could not re-inspect $TableDbFile after trim; continuing startup."
    return
}
if ($afterSize -ge $nodeStringLimit) {
    Write-Warning ("Azurite table DB is still {0} MB after emptying caches (above the Node string limit). Continuing startup; if Table crashes, factory-reset with: docker volume rm {1}" -f ([math]::Round($afterSize / 1MB, 1)), $VolumeName)
}
} catch {
    Write-Warning "Azurite cache trim skipped; continuing startup. $($_.Exception.Message)"
}
