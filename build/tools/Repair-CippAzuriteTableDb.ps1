# Repair an Azurite table database whose LokiJS indexes no longer match its rows.
#
# Symptom: reads work, writes duplicate, and every delete comes back 404. Range queries scan
# the data array directly so they return rows, while point operations (single-entity get,
# merge, delete) resolve through binaryIndices - and when those hold stale positions the row
# is reported as not found. Because the indexes are marked dirty=False, LokiJS treats them as
# authoritative and never rebuilds them, so the state does not heal on restart.
#
# The same broken lookup defeats upsert de-duplication, so PartitionKey+RowKey pairs pile up
# as duplicates even though the service guarantees they are unique.
#
# This rewrites the database with one row per PartitionKey+RowKey (most recent write wins),
# renumbered $loki ids, and every binary index emptied and marked dirty so LokiJS rebuilds it.

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$VolumeName = 'cipp-ng_azurite-data',
    [string]$TableDbFile = '__azurite_db_table__.json',
    [string]$ContainerName = 'cipp-azurite',
    # Written inside the volume, so it costs volume space rather than host space.
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'

$volumes = @(docker volume ls --format '{{.Name}}')
if ($LASTEXITCODE -ne 0) { throw 'Could not list Docker volumes.' }
if ($volumes -notcontains $VolumeName) { throw "Azurite volume '$VolumeName' does not exist." }

$python = @'
#!/usr/bin/env python3
import json
import os
import shutil
import sys

PATH = "/workspace/" + os.environ["AZURITE_TABLE_DB"]
BACKUP = PATH + ".corrupt.bak"
SKIP_BACKUP = os.environ.get("SKIP_BACKUP") == "1"

def main():
    if not os.path.isfile(PATH):
        print("missing=1")
        return

    before = os.path.getsize(PATH)
    if not SKIP_BACKUP:
        shutil.copy2(PATH, BACKUP)
        print("backup=%s" % BACKUP)

    with open(PATH, "r", encoding="utf-8") as f:
        db = json.load(f)

    for coll in db.get("collections") or []:
        name = coll.get("name", "")
        data = coll.get("data") or []

        # Last write wins, matching the upsert that should have replaced the row.
        keyed = all(("PartitionKey" in row and "RowKey" in row) for row in data) if data else False
        removed = 0
        if keyed:
            seen = {}
            for row in data:
                seen[(row["PartitionKey"], row["RowKey"])] = row
            if len(seen) != len(data):
                removed = len(data) - len(seen)
                data = list(seen.values())

        # LokiJS addresses rows by $loki, and idIndex must line up with data order.
        for position, row in enumerate(data, start=1):
            row["$loki"] = position
        coll["data"] = data
        coll["idIndex"] = [row["$loki"] for row in data]
        coll["maxId"] = len(data)
        coll["dirtyIds"] = []

        # A binary index holds positions into data, ordered by the indexed value. It cannot be
        # left empty for LokiJS to regenerate: ensureIndex returns early for collections using
        # adaptiveBinaryIndices, so a dirty flag is never acted on and the index stays empty,
        # which is what makes findOne - and therefore every delete - miss rows that a scan
        # still returns. The values are rebuilt here instead.
        stale = 0
        dropped = []
        for prop, index in (coll.get("binaryIndices") or {}).items():
            stale = max(stale, len(index.get("values") or []))
            if all(isinstance(row.get(prop), str) for row in data):
                positions = list(range(len(data)))
                # LokiJS orders with JavaScript's <, which compares UTF-16 code units.
                positions.sort(key=lambda pos: data[pos][prop].encode("utf-16-be"))
                index["values"] = positions
                index["dirty"] = False
            else:
                # Non-string or absent values: drop the index so lookups fall back to a scan
                # rather than risk ordering it differently than LokiJS would.
                dropped.append(prop)
        for prop in dropped:
            del coll["binaryIndices"][prop]

        if removed or stale:
            print("repaired\t%s\trows=%d\tdeduped=%d\tstale_index_entries=%d"
                  % (name, len(data), removed, stale))

    tmp = PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(db, f, separators=(",", ":"), ensure_ascii=False)
    os.replace(tmp, PATH)

    print("before_bytes=%d" % before)
    print("after_bytes=%d" % os.path.getsize(PATH))

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("error: %s" % exc, file=sys.stderr)
        sys.exit(1)
'@

$scriptPath = Join-Path $env:TEMP 'cipp-repair-azurite-table.py'
Set-Content -Path $scriptPath -Value $python -Encoding utf8NoBOM

if (-not $PSCmdlet.ShouldProcess($VolumeName, 'Rewrite Azurite table database')) { return }

$wasRunning = @(docker ps -q --filter "name=^$ContainerName$")
if ($wasRunning) {
    Write-Host "Stopping $ContainerName so the table DB can be rewritten..." -ForegroundColor DarkGray
    docker stop $ContainerName | Out-Null
}

try {
    docker run --rm --memory=4g --network none `
        -e "AZURITE_TABLE_DB=$TableDbFile" `
        -e "SKIP_BACKUP=$(if ($SkipBackup) { '1' } else { '0' })" `
        -v "${VolumeName}:/workspace" `
        -v "${scriptPath}:/script.py:ro" `
        python:3-slim python /script.py
    if ($LASTEXITCODE -ne 0) { throw 'Repair failed; the database was left unchanged.' }
} finally {
    Remove-Item -LiteralPath $scriptPath -ErrorAction SilentlyContinue
    if ($wasRunning) {
        Write-Host "Starting $ContainerName..." -ForegroundColor DarkGray
        docker start $ContainerName | Out-Null
    }
}

Write-Host 'Azurite table database repaired.' -ForegroundColor Green
