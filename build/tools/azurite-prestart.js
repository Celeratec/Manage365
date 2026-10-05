#!/usr/bin/env node
/*
 * Azurite pre-start guard for the local dev stack.
 *
 * Azurite's table service loads the entire LokiJS JSON file into memory on
 * start; once cache tables grow it past a few hundred MB the container can
 * OOM before the table service ever listens, and then crash-loops. This runs
 * before azurite starts and, when the file is over a size threshold, empties
 * the known regenerable cache/log collections in the file itself so azurite
 * boots against a small store. Durable dev state (DevSecrets, Tenants,
 * templates, standards, config) is never touched.
 *
 * Usage: node azurite-prestart.js <workspace-dir>
 * Env:   AZURITE_PRESTART_MAX_MB   file size that triggers a prune (default 300)
 */
const fs = require('fs')
const path = require('path')

const workspace = process.argv[2] || '/workspace'
const dbPath = path.join(workspace, '__azurite_db_table__.json')
const maxBytes = (parseInt(process.env.AZURITE_PRESTART_MAX_MB, 10) || 300) * 1024 * 1024

// Regenerable data only: logs, per-run results and graph caches. Everything
// else is presumed durable and left alone. CippReportingDB is deliberately
// preserved (needed for report-DB testing) except its DLP catalog rows below.
const PRUNABLE = [
  /^devstoreaccount1\$CippLogs$/,
  /^devstoreaccount1\$AuditLogs$/,
  /^devstoreaccount1\$CippTestResults$/,
  /^devstoreaccount1\$AlertLastRun$/,
  /^devstoreaccount1\$FailedAuditLogDownloads$/,
  /^devstoreaccount1\$AuditLogCoverage$/,
  /^devstoreaccount1\$CalendarFolderCache$/,
  /^devstoreaccount1\$sitenameprocHistory$/,
  /^devstoreaccount1\$cache/i,
]

function log(msg) {
  console.log(`[azurite-prestart] ${msg}`)
}

try {
  if (!fs.existsSync(dbPath)) {
    log('no table db yet; nothing to do')
    process.exit(0)
  }
  const size = fs.statSync(dbPath).size
  log(`table db is ${(size / 1e6).toFixed(0)}MB (threshold ${(maxBytes / 1e6).toFixed(0)}MB)`)
  if (size <= maxBytes) {
    process.exit(0)
  }

  log('over threshold - pruning regenerable collections')
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'))
  let freedRows = 0
  for (const col of db.collections || []) {
    const isReportDB = col.name === 'devstoreaccount1$CippReportingDB'
    if (!isReportDB && !PRUNABLE.some((re) => re.test(col.name))) continue
    const before = (col.data || []).length
    if (before === 0) continue
    if (isReportDB) {
      // The per-tenant copies of Microsoft's built-in DLP sensitive-info-type
      // catalog (~425KB per row) dwarf the rest of the reporting DB; drop only
      // those and keep every other cached report row.
      col.data = col.data.filter((row) => !String(row.RowKey || '').startsWith('ExoDlpSensitiveInfoTypes'))
    } else {
      col.data = []
    }
    const removed = before - col.data.length
    if (removed === 0) continue
    log(`  ${col.name}: removed ${removed} of ${before} rows`)
    freedRows += removed
    // Reset derived state so Loki rebuilds it instead of walking stale refs.
    if (Array.isArray(col.idIndex)) col.idIndex = col.data.map((row) => row.$loki)
    if (Array.isArray(col.dirtyIds)) col.dirtyIds = []
    if (col.binaryIndices) {
      for (const key of Object.keys(col.binaryIndices)) {
        col.binaryIndices[key] = { name: key, dirty: true, values: [] }
      }
    }
  }

  if (freedRows === 0) {
    log('nothing prunable found above threshold - leaving file as is')
    process.exit(0)
  }

  const tmpPath = `${dbPath}.tmp`
  fs.writeFileSync(tmpPath, JSON.stringify(db))
  fs.renameSync(tmpPath, dbPath)
  log(`pruned ${freedRows} rows; table db now ${(fs.statSync(dbPath).size / 1e6).toFixed(0)}MB`)
} catch (err) {
  // Never block azurite on a prune failure - worst case it boots the old file.
  log(`prune failed (starting azurite anyway): ${err.message}`)
}
process.exit(0)
