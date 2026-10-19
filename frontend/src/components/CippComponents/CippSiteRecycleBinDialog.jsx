import { useEffect, useState } from 'react'
import { Alert, Button, Dialog, DialogActions, DialogContent, DialogTitle, LinearProgress, Stack, Typography } from '@mui/material'
import { CippIcons } from '../../utils/icon-registry'
import { CippDataTable } from '../CippTable/CippDataTable'
import { CippApiDialog } from './CippApiDialog'
import CippFormComponent from './CippFormComponent'
import { ApiGetCall } from '../../api/ApiCall'
import { useDialog } from '../../hooks/use-dialog'
import { usePermissions } from '../../hooks/use-permissions'
import { formatCleanupBytes } from '../../utils/storage-cleanup-opportunities'

const optionValue = (value) =>
  value && typeof value === 'object' && 'value' in value ? value.value : value

// Custom-component action dialog: lists a site's recycle bin (first + second stage) and
// restores selected items via ExecRestoreRecycleBinItems.
export const CippSiteRecycleBinDialog = ({
  row,
  tenantFilter,
  drawerVisible,
  setDrawerVisible,
}) => {
  const siteRow = Array.isArray(row) ? row[0] : row
  const siteUrl = siteRow?.webUrl
  const tenant = siteRow?.Tenant ?? tenantFilter
  const { checkPermissions } = usePermissions()
  const canRestore = checkPermissions(['Sharepoint.SiteRecycleBin.ReadWrite'])
  const emptyDialog = useDialog()
  const [jobId, setJobId] = useState(null)
  const [jobActive, setJobActive] = useState(false)
  const [lastResult, setLastResult] = useState(null)

  const summaryApi = ApiGetCall({
    url: '/api/ListSiteRecycleBinSummary',
    data: { tenantFilter: tenant, SiteUrl: siteUrl },
    queryKey: `SiteRecycleBinSummary-${siteUrl}`,
    waiting: !!drawerVisible && !!siteUrl && !!tenant,
  })
  const summary = summaryApi.data?.Results
  const summaryReady = summary && typeof summary === 'object' && summary.itemCount !== undefined

  const statusApi = ApiGetCall({
    url: '/api/ListEmptySiteRecycleBinStatus',
    data: { tenantFilter: tenant, queueId: jobId, SiteUrl: siteUrl },
    queryKey: `SiteRecycleBinEmpty-${jobId}`,
    waiting: !!drawerVisible && !!jobId,
    refetchInterval: jobActive ? 4000 : false,
  })

  useEffect(() => {
    const status = statusApi.data?.Status
    if (!status) return
    if (status === 'Running' || status === 'Queued') {
      setJobActive(true)
      return
    }
    setJobActive(false)
    setLastResult(statusApi.data)
    summaryApi.refetch?.()
  }, [statusApi.data])

  const progress = jobActive ? statusApi.data : lastResult
  const actions = [
    {
      label: 'Restore Item',
      category: "manage",
      type: 'POST',
      icon: <CippIcons.RestoreFromTrash />,
      url: '/api/ExecRestoreRecycleBinItems',
      data: {
        Ids: 'Id',
        ItemNames: 'LeafName',
        // Literal values: these keys do not exist on the recycle bin rows, so the
        // action data mapper passes them through as-is.
        SiteUrl: siteUrl,
        tenantFilter: tenant,
      },
      confirmText: 'Restore [LeafName] from the recycle bin?',
      condition: () => canRestore,
      multiPost: false,
    },
  ]

  return (
    <Dialog fullWidth maxWidth="lg" open={!!drawerVisible} onClose={() => setDrawerVisible(false)}>
      <DialogTitle>
        Recycle Bin{siteRow?.displayName ? ` — ${siteRow.displayName}` : ''}
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={1.5}>
          {summaryApi.isFetching && !summaryReady ? <LinearProgress /> : null}
          {summaryReady ? (
            <Alert severity={summary.capped ? 'warning' : 'info'}>
              {summary.itemCount?.toLocaleString?.() ?? summary.itemCount} items · {formatCleanupBytes(summary.totalBytes)}
              {summary.capped ? ' (count is incomplete)' : ''}. First stage {summary.firstStageCount?.toLocaleString?.() ?? summary.firstStageCount} · {formatCleanupBytes(summary.firstStageBytes)}. Second stage {summary.secondStageCount?.toLocaleString?.() ?? summary.secondStageCount} · {formatCleanupBytes(summary.secondStageBytes)}.
            </Alert>
          ) : null}
          {progress?.Results ? (
            <Alert severity={progress.emptied ? 'success' : jobActive ? 'info' : 'warning'}>
              <Typography variant="body2">{progress.Results}</Typography>
              {progress.deletedCount != null ? (
                <Typography variant="caption" display="block">
                  Deleted {Number(progress.deletedCount).toLocaleString()} items
                  {progress.deletedBytes != null ? ` · ${formatCleanupBytes(progress.deletedBytes)}` : ''}
                  {progress.remainingFirst != null ? ` · remaining first ${Number(progress.remainingFirst).toLocaleString()}` : ''}
                  {progress.remainingSecond != null ? `, second ${Number(progress.remainingSecond).toLocaleString()}` : ''}
                </Typography>
              ) : null}
              {jobActive ? <LinearProgress sx={{ mt: 1 }} /> : null}
            </Alert>
          ) : null}
          {canRestore ? (
            <Button variant="contained" color="warning" onClick={emptyDialog.handleOpen} disabled={jobActive}>
              Empty recycle bin
            </Button>
          ) : null}
          <CippDataTable
            noCard={true}
            title="Deleted Items"
            queryKey={`SiteRecycleBin-${siteUrl}`}
            api={{
              url: '/api/ListSiteRecycleBin',
              data: {
                SiteUrl: siteUrl,
                tenantFilter: tenant,
              },
              dataKey: 'Results',
            }}
            actions={actions}
            simpleColumns={[
              'LeafName',
              'DirName',
              'ItemType',
              'ItemState',
              'Size',
              'DeletedByName',
              'DeletedDate',
            ]}
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button color="inherit" onClick={() => setDrawerVisible(false)}>
          Close
        </Button>
      </DialogActions>
      <CippApiDialog
        createDialog={emptyDialog}
        title="Empty Recycle Bin"
        relatedQueryKeys={[`SiteRecycleBin-${siteUrl}`, `SiteRecycleBinSummary-${siteUrl}`]}
        allowResubmit
        defaultvalues={{ Stage: 'Both' }}
        api={{
          type: 'POST',
          url: '/api/ExecEmptySiteRecycleBin',
          confirmText: `Permanently empty the recycle bin for ${siteRow?.displayName || siteUrl}? This cannot be undone. A large bin runs in the background.`,
          customDataformatter: (_row, _action, formData) => ({
            tenantFilter: tenant,
            SiteUrl: siteUrl,
            Stage: optionValue(formData.Stage) || 'Both',
          }),
          multiPost: false,
          onSuccess: (result) => {
            setLastResult(result)
            if (result?.Queued && result?.QueueId) {
              setJobId(result.QueueId)
              setJobActive(true)
              return
            }
            summaryApi.refetch?.()
          },
        }}
        row={siteRow ?? {}}
      >
        {({ formHook }) => (
          <CippFormComponent
            type="radio"
            name="Stage"
            label="Stage"
            formControl={formHook}
            options={[
              { label: 'Both stages', value: 'Both' },
              { label: 'First stage only', value: 'First' },
              { label: 'Second stage only', value: 'Second' },
            ]}
          />
        )}
      </CippApiDialog>
    </Dialog>
  )
}
