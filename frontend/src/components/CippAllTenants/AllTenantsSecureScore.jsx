import { useMemo } from 'react'
import { CippIcons } from '../../utils/icon-registry'
import {
  Box,
  Card,
  CardContent,
  CardHeader,
  Divider,
  LinearProgress,
  Skeleton,
  Stack,
  Typography,
} from '@mui/material'
import { Grid } from '@mui/system'
import Link from 'next/link'
import { ApiGetCall } from '../../api/ApiCall.jsx'
import { useMultiTenantScope } from '../../hooks/use-multi-tenant-scope'
import { getCippError } from '../../utils/get-cipp-error'
import { CippInfoBar } from '../CippCards/CippInfoBar'
import { CippDataTable } from '../CippTable/CippDataTable'
import { AllTenantsTrendChart, severityColor } from './AllTenantsPrimitives'
import { asArray, deriveSecureScoreSummary } from './useAllTenantsDashboard'
import { tenantScope } from '../../utils/tenant-selection'

/**
 * Estate-wide secure score, rendered by the secure score tabs when the tenant selector is on
 * AllTenants: the summary on Tenant Overview, the per-tenant table on Table Overview. Built from
 * the nightly-cache report rather than live Graph calls, and shares its query key with the All
 * Tenants dashboard card — both tabs and the dashboard resolve from one request.
 */
const useSecureScoreReport = () => {
  const scope = useMultiTenantScope()
  const reportApi = ApiGetCall({
    url: '/api/ListSecureScoreReport',
    data: { ...tenantScope(scope), includeHistory: 'true' },
    queryKey: `AllTenantsDashboard-SecureScore-${scope}`,
  })

  const rows = useMemo(() => asArray(reportApi.data), [reportApi.data])
  const summary = useMemo(() => deriveSecureScoreSummary(rows), [rows])

  return { reportApi, rows, summary }
}

// Bucket labels never contain one another, so the table's default `contains` preset filter
// can't match 'Complete' rows when asked for 'Partial' or the other way round.
export const scoreBucket = (percent) => {
  if (percent === null || percent === undefined || Number.isNaN(Number(percent))) return 'No data'
  const value = Number(percent)
  if (value >= 100) return 'Complete'
  if (value <= 0) return 'Not started'
  return 'Partial'
}

// Points moved across the retained history window, oldest to newest.
export const tenantChange = (history) => {
  const points = asArray(history)
  if (points.length < 2) return null
  const first = Number(points[0]?.PercentageScore)
  const last = Number(points[points.length - 1]?.PercentageScore)
  if (Number.isNaN(first) || Number.isNaN(last)) return null
  return Math.round((last - first) * 100) / 100
}

// customerId -> 'Group A, Group B' from the ListTenantGroups payload.
export const tenantGroupLookup = (groups) => {
  const lookup = new Map()
  asArray(groups).forEach((group) => {
    asArray(group?.Members).forEach((member) => {
      if (!member?.customerId || !group?.Name) return
      lookup.set(member.customerId, [...(lookup.get(member.customerId) ?? []), group.Name])
    })
  })
  return new Map([...lookup].map(([id, names]) => [id, names.sort().join(', ')]))
}

// customerIds in any of the selected tenant groups, or null for "all tenants". Membership is
// matched by id, never by the joined TenantGroups text, so 'Production' never picks up
// 'NonProduction' tenants.
export const groupMembers = (groups, groupIds) => {
  const selected = new Set(asArray(groupIds))
  if (selected.size === 0) return null
  return new Set(
    asArray(groups)
      .filter((group) => selected.has(group?.Id))
      .flatMap((group) => asArray(group?.Members).map((member) => member?.customerId))
      .filter(Boolean)
  )
}

// Tenant group picker for the estate-wide tables (rendered as the table's cardButton) plus the
// membership set the caller filters its rows with before they reach the table.
const useTenantGroupFilter = () => {
  const [groupIds, setGroupIds] = useState([])
  const groupsApi = ApiGetCall({ url: '/api/ListTenantGroups', queryKey: 'TenantGroupSelector' })
  const groups = useMemo(() => asArray(groupsApi.data), [groupsApi.data])
  const members = useMemo(() => groupMembers(groups, groupIds), [groups, groupIds])

  const groupSelect =
    groups.length > 0 ? (
      <TextField
        select
        size="small"
        value={groupIds}
        onChange={(event) => setGroupIds(asArray(event.target.value))}
        // No floating label: in the card header slot it overlapped the outline. The empty
        // selection renders as "All tenant groups" instead, so the field always says what it filters.
        slotProps={{
          select: {
            multiple: true,
            displayEmpty: true,
            renderValue: (selected) =>
              selected.length === 0
                ? 'All tenant groups'
                : groups
                    .filter((group) => selected.includes(group.Id))
                    .map((group) => group.Name)
                    .join(', '),
          },
          htmlInput: { 'aria-label': 'Tenant groups' },
        }}
        sx={{ minWidth: 220, maxWidth: 360 }}
      >
        {groups.map((group) => (
          <MenuItem key={group.Id} value={group.Id}>
            <Checkbox size="small" checked={groupIds.includes(group.Id)} sx={{ p: 0, mr: 1 }} />
            {group.Name}
          </MenuItem>
        ))}
      </TextField>
    ) : null

  return { groups, members, groupSelect }
}

// One row per tenant x reported control, joining the shared catalog back onto the slim
// per-tenant control scores the report sends.
export const flattenControlRows = (tenants, catalog = {}, groups = new Map()) =>
  asArray(tenants).flatMap((tenant) =>
    asArray(tenant?.Controls).map((control) => {
      const meta = catalog?.[control.controlName] ?? {}
      const percent =
        control.scoreInPercentage === null || control.scoreInPercentage === undefined
          ? null
          : Number(control.scoreInPercentage)
      return {
        Tenant: tenant.Tenant,
        TenantId: tenant.TenantId,
        TenantName: tenant.TenantName,
        TenantGroups: groups.get(tenant.TenantId) ?? '',
        ControlName: control.controlName,
        Title: meta.title ?? control.controlName,
        ScorePercent: percent,
        Points: `${control.score ?? 0} / ${meta.maxScore ?? 0}`,
        ScoreBucket: scoreBucket(percent),
        Tier: meta.tier ?? '',
        State: control.state || 'Default',
        Category: meta.controlCategory ?? '',
        UserImpact: meta.userImpact ?? '',
        ImplementationCost: meta.implementationCost ?? '',
        Threats: asArray(meta.threats).join(', '),
        StateBy: control.stateBy ?? '',
        StateDate: control.stateDate ?? '',
        StateComment: control.stateComment ?? '',
      }
    })
  )

// Per-control spread across the filtered tenant rows. "No data" counts tenants in scope that
// don't report the control at all, plus reported rows without a percentage.
export const rollupControls = (rows, tenantCount) => {
  const byControl = new Map()
  asArray(rows).forEach((row) => {
    const entry = byControl.get(row.ControlName) ?? {
      ControlName: row.ControlName,
      Title: row.Title,
      Tier: row.Tier,
      Category: row.Category,
      Reporting: 0,
      Complete: 0,
      Partial: 0,
      NotStarted: 0,
      NoScore: 0,
      sum: 0,
      scored: 0,
    }
    entry.Reporting += 1
    if (row.ScoreBucket === 'Complete') entry.Complete += 1
    else if (row.ScoreBucket === 'Partial') entry.Partial += 1
    else if (row.ScoreBucket === 'Not started') entry.NotStarted += 1
    else entry.NoScore += 1
    if (row.ScorePercent !== null && !Number.isNaN(row.ScorePercent)) {
      entry.sum += row.ScorePercent
      entry.scored += 1
    }
    byControl.set(row.ControlName, entry)
  })

  return [...byControl.values()]
    .map(({ sum, scored, NoScore, ...entry }) => ({
      ...entry,
      NoData: Math.max(0, tenantCount - entry.Reporting) + NoScore,
      AveragePercent: scored ? Math.round((sum / scored) * 100) / 100 : null,
    }))
    .sort((a, b) => (a.AveragePercent ?? -1) - (b.AveragePercent ?? -1))
}

// Tenant x control data for the Table Overview and Controls tabs. One request shared by both
// (react-query key), separate from the dashboard's lighter call that never carries controls.
const useSecureScoreControls = () => {
  const scope = useMultiTenantScope()
  const reportApi = ApiGetCall({
    url: '/api/ListSecureScoreReport',
    data: { ...tenantScope(scope), includeControls: 'true' },
    queryKey: `AllTenantsSecureScore-Controls-${scope}`,
  })
  const { groups, members, groupSelect } = useTenantGroupFilter()

  const tenants = useMemo(
    () => asArray(reportApi.data).filter((tenant) => !members || members.has(tenant.TenantId)),
    [reportApi.data, members]
  )
  const rows = useMemo(
    () => flattenControlRows(tenants, reportApi.data?.Catalog, tenantGroupLookup(groups)),
    [tenants, reportApi.data, groups]
  )

  // Empty means nothing cached at all, not "the selected group has no rows" — the table and its
  // group picker must stay up for that.
  const hasControls = useMemo(
    () => asArray(reportApi.data).some((tenant) => asArray(tenant?.Controls).length > 0),
    [reportApi.data]
  )

  return { reportApi, tenants, rows, groupSelect, hasControls }
}

const scoreSeverity = (value) => (value >= 75 ? 'ok' : value >= 50 ? 'warning' : 'critical')

/**
 * Ranked tenant rows with a score bar; each row links to that tenant's own secure score view via
 * the tenantFilter query param, which the tenant selector picks up.
 */
const LeaderboardCard = ({ title, subheader, rows, isFetching }) => (
  <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
    <CardHeader
      title={title}
      subheader={subheader}
      slotProps={{
        title: { variant: 'h6' },
        subheader: { variant: 'caption' }
      }} />
    <Divider />
    <CardContent sx={{ flex: 1 }}>
      {isFetching ? (
        <Stack spacing={1.5}>
          {[0, 1, 2, 3, 4].map((key) => (
            <Skeleton key={key} variant="rounded" height={40} />
          ))}
        </Stack>
      ) : rows.length === 0 ? (
        <Typography
          variant="body2"
          sx={{
            color: "text.secondary",
            py: 2,
            textAlign: 'center'
          }}>
          No scored tenants yet
        </Typography>
      ) : (
        <Stack spacing={0.5}>
          {rows.map((row) => (
            <Stack
              key={row.tenant}
              component={Link}
              href={`/tenant/administration/securescore?tenantFilter=${row.tenant}`}
              direction="row"
              spacing={1.5}
              sx={{
                alignItems: "center",
                px: 1,
                py: 0.75,
                borderRadius: 1,
                textDecoration: 'none',
                color: 'inherit',
                '&:hover': { backgroundColor: 'action.hover' }
              }}>
              <Typography
                variant="caption"
                sx={{
                  color: "text.disabled",
                  width: 24,
                  flexShrink: 0,
                  fontVariantNumeric: 'tabular-nums'
                }}>
                #{row.rank}
              </Typography>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="body2" noWrap title={row.name}>
                  {row.name}
                </Typography>
                <LinearProgress
                  variant="determinate"
                  value={Math.min(100, Math.max(0, row.percent))}
                  sx={{
                    mt: 0.5,
                    height: 4,
                    borderRadius: 5,
                    backgroundColor: 'action.hover',
                    '& .MuiLinearProgress-bar': {
                      borderRadius: 5,
                      backgroundColor: severityColor(scoreSeverity(row.percent)),
                    },
                  }}
                />
              </Box>
              <Typography
                variant="subtitle2"
                sx={{
                  flexShrink: 0,
                  fontVariantNumeric: 'tabular-nums',
                  color: severityColor(scoreSeverity(row.percent)),
                }}
              >
                {row.percent}%
              </Typography>
            </Stack>
          ))}
        </Stack>
      )}
    </CardContent>
  </Card>
)

const ReportError = ({ error }) => (
  <Card>
    <CardContent>
      <Typography variant="body2" color="error" sx={{ py: 2, textAlign: 'center' }}>
        {getCippError(error)}
      </Typography>
    </CardContent>
  </Card>
)

export const AllTenantsSecureScoreSummary = () => {
  const { reportApi, summary } = useSecureScoreReport()

  if (reportApi.isError) return <ReportError error={reportApi.error} />

  const deltaLabel =
    summary.delta === null ? '—' : `${summary.delta > 0 ? '+' : ''}${summary.delta} pts`

  const infoBarItems = [
    {
      name: 'Portfolio average',
      data: `${summary.average}%`,
      icon: <CippIcons.ShieldCheckIcon />,
      toolTip: `Average of each tenant's latest cached score, across ${summary.scored} tenants`,
    },
    {
      name: summary.trend.length > 1 ? `Change over ${summary.trend.length} days` : 'Change',
      data: deltaLabel,
      icon: summary.delta < 0 ? <CippIcons.ArrowTrendingDownIcon /> : <CippIcons.ArrowTrendingUpIcon />,
      color: summary.delta < 0 ? 'error' : summary.delta > 0 ? 'success' : 'primary',
      toolTip: 'Movement of the portfolio average across the retained history window',
    },
    {
      name: 'Highest',
      data: summary.best ? `${summary.best.percent}%` : '—',
      icon: <CippIcons.TrophyIcon />,
      color: 'success',
      toolTip: summary.best
        ? `${summary.best.name} — ${summary.best.current} of ${summary.best.max} points`
        : 'No scored tenants yet',
    },
    {
      name: 'Lowest',
      data: summary.worst ? `${summary.worst.percent}%` : '—',
      icon: <CippIcons.ExclamationTriangleIcon />,
      color: 'error',
      toolTip: summary.worst
        ? `${summary.worst.name} — ${summary.worst.current} of ${summary.worst.max} points`
        : 'No scored tenants yet',
    },
  ]

  // Ranks are estate-wide (1 = best). The boards never overlap: bottom takes the worst five,
  // top takes whatever best tenants remain on estates smaller than ten.
  const bottomRows = summary.ranked.slice(0, 5).map((row, index) => ({
    ...row,
    rank: summary.ranked.length - index,
  }))
  const topRows = summary.ranked
    .slice(Math.max(5, summary.ranked.length - 5))
    .reverse()
    .map((row, index) => ({ ...row, rank: index + 1 }))

  return (
    <Stack spacing={2}>
      <CippInfoBar isFetching={reportApi.isLoading} data={infoBarItems} />

      <Grid container spacing={2}>
        <Grid size={{ xs: 12, lg: 6 }}>
          <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
            <CardHeader
              title="Portfolio trend"
              subheader="Daily average of every tenant's cached score"
              slotProps={{
                title: { variant: 'h6' },
                subheader: { variant: 'caption' }
              }} />
            <Divider />
            <CardContent sx={{ flex: 1 }}>
              <AllTenantsTrendChart
                points={summary.trend}
                isFetching={reportApi.isLoading}
                height={280}
                severity={summary.delta < 0 ? 'critical' : summary.delta > 0 ? 'ok' : 'info'}
              />
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 12, sm: 6, lg: 3 }}>
          <LeaderboardCard
            title="Top 5"
            subheader="Highest scoring tenants"
            rows={topRows}
            isFetching={reportApi.isLoading}
          />
        </Grid>
        <Grid size={{ xs: 12, sm: 6, lg: 3 }}>
          <LeaderboardCard
            title="Bottom 5"
            subheader="Lowest scoring tenants"
            rows={bottomRows}
            isFetching={reportApi.isLoading}
          />
        </Grid>
      </Grid>
    </Stack>
  );
}

export const AllTenantsSecureScoreTable = () => {
  const { reportApi, rows } = useSecureScoreReport()

  if (reportApi.isError) return <ReportError error={reportApi.error} />

  if (!reportApi.isLoading && rows.length === 0) {
    return (
      <Card>
        <CardContent>
          <Typography
            variant="body2"
            sx={{
              color: "text.secondary",
              py: 2,
              textAlign: 'center'
            }}>
            No cached secure scores yet. Scores appear after the nightly cache job has run.
          </Typography>
        </CardContent>
      </Card>
    );
  }

  return (
    <CippDataTable
      title="Secure score by tenant"
      data={rows}
      isFetching={reportApi.isLoading}
      refreshFunction={() => reportApi.refetch()}
      simpleColumns={[
        'TenantName',
        'Tenant',
        'PercentageScore',
        'CurrentScore',
        'MaxScore',
        'CapturedAt',
      ]}
      defaultSorting={[{ id: 'PercentageScore', desc: false }]}
      actions={[
        {
          label: 'View tenant secure score',
          link: '/tenant/administration/securescore?tenantFilter=[Tenant]',
          icon: <CippIcons.EyeIcon />,
        },
      ]}
    />
  )
}
