import fs from 'node:fs'
import path from 'node:path'
import { getHelpLinks } from '../../src/utils/help-links'
import { nativeMenuItems } from '../../src/layouts/config'

const DOCS_ROOT = path.resolve(__dirname, '../../../docs/user-documentation')
const docsRootExists = fs.existsSync(DOCS_ROOT)

// Pages with no docs page yet - fix the nav entry (docsPath override) instead of growing
// this list. Confirm the real docs location is still missing before adding to it.
const NO_DOCS_YET = new Set([
  '/tenant/baselines',
  '/tenant/conditional/deploy-vacation',
  '/endpoint/reports/workfromanywhere',
  '/onboardingv2',
  '/identity/reports/group-usage',
  '/email/reports/mail-flow-statistics',
  '/security/ediscovery/cases',
  '/email/troubleshooting/email-troubleshooter',
  '/email/tools/mail-test',
  '/teams-share/onedrive/file-search',
  '/teams-share/onedrive/file-browser',
  '/teams-share/onedrive/file-transfer',
  '/teams-share/sharepoint/temp-file-cleanup',
  '/teams-share/sharepoint/dashboard',
  '/teams-share/sharepoint/sharing-settings',
  '/teams-share/sharepoint/recycle-bin',
  '/teams-share/sharepoint/image-optimizer',
  '/teams-share/external-access',
  '/teams-share/troubleshooting/sharing-troubleshooter',
  '/teams-share/teams/teams-settings',
  '/teams-share/teams/business-voice/call-queues',
  '/teams-share/teams/business-voice/auto-attendants',
  '/teams-share/teams/business-voice/dial-plans',
  '/endpoint/autopilot/list-profiles',
  '/dynamics/environments',
  '/dynamics/administration/users',
  '/dynamics/administration/security-roles',
  '/dynamics/administration/business-units',
  '/dynamics/administration/solutions',
  '/tenant/standards/bpa-report',
])

// Same resolution getHelpLinks uses: a nav item's docsPath overrides the pathname-derived
// docs location.
const resolveDocsTarget = (item) => item.docsPath ?? item.path.slice(1)

// readdir + exact name compare, so a case-insensitive disk cannot hide a mismatch
// that fails the Ubuntu docs checkout in CI.
const existsExact = (relativePath) => {
  let current = DOCS_ROOT
  for (const part of relativePath.split('/').filter(Boolean)) {
    let entries
    try {
      entries = fs.readdirSync(current)
    } catch {
      return false
    }
    if (!entries.includes(part)) return false
    current = path.join(current, part)
  }
  return true
}

const docsTargetExists = (target) =>
  existsExact(`${target}.md`) ||
  existsExact(path.join(target, 'README.md')) ||
  existsExact(target)

const walkNavPaths = (items = [], out = []) => {
  items.forEach((item) => {
    if (item?.path?.startsWith('/')) {
      out.push(item)
    }
    if (Array.isArray(item?.items)) {
      walkNavPaths(item.items, out)
    }
  })
  return out
}

describe.skipIf(!docsRootExists)(
  'nav entries resolve to real docs pages',
  () => {
    const navEntries = walkNavPaths(nativeMenuItems)

    it('found nav entries to check', () => {
      expect(navEntries.length).toBeGreaterThan(0)
    })

    navEntries
      .filter((item) => !NO_DOCS_YET.has(item.path))
      .forEach((item) => {
        it(`${item.path} -> ${resolveDocsTarget(item)}`, () => {
          expect(docsTargetExists(resolveDocsTarget(item))).toBe(true)
        })
      })
  }
)

describe('getHelpLinks documentation link', () => {
  it('uses the pathname-derived URL when the nav item has no docsPath', () => {
    const links = getHelpLinks('/identity/administration/users')
    const docs = links.find((link) => link.id === 'documentation')
    expect(docs.href).toBe(
      'https://docs.cipp.app/user-documentation/identity/administration/users'
    )
  })

  it('uses the docsPath override when the nav item has one', () => {
    const links = getHelpLinks('/tenant/tools/graph-explorer')
    const docs = links.find((link) => link.id === 'documentation')
    expect(docs.href).toBe(
      'https://docs.cipp.app/user-documentation/tools/tenant-tools/graph-explorer'
    )
  })
})
