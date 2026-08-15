import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { useState, useEffect, useMemo } from "react";
import { useForm } from "react-hook-form";
import {
  Alert,
  Badge,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogContent,
  DialogTitle,
  IconButton,
  Paper,
  Skeleton,
  Stack,
  Tab,
  Tabs,
  Typography,
} from "@mui/material";
import {
  Block,
  CheckCircle,
  Close,
  ContentCopy,
  Done,
} from "@mui/icons-material";
import {
  Timeline,
  TimelineItem,
  TimelineSeparator,
  TimelineDot,
  TimelineConnector,
  TimelineContent,
  TimelineOppositeContent,
} from "@mui/lab";
import { DocumentTextIcon } from "@heroicons/react/24/outline";
import { CippDataTable } from "../../../../components/CippTable/CippDataTable";
import { CippMessageViewer } from "../../../../components/CippComponents/CippMessageViewer.jsx";
import { ApiPostCall, ApiGetCall } from "../../../../api/ApiCall";
import { useSettings } from "../../../../hooks/use-settings";
import { useDispatch } from "react-redux";
import { showToast } from "../../../../store/toasts";
import {
  buildQuarantineActions,
  buildQuarantineColumns,
  buildQuarantineSearchPayload,
  CippQuarantineBulkToolbar,
  CippQuarantineDetailPanel,
  CippQuarantineFilterPanel,
  handleBulkBlockSenders,
  QUARANTINE_DAYS_OPTIONS,
  useQuarantineFilters,
} from "../../../../components/CippComponents/quarantine";

const quickPresets = [
  { key: "quarantined24h", label: "Quarantined (24h)", days: 1, status: "Quarantined" },
  { key: "failed48h", label: "Failed Delivery (48h)", days: 2, status: "Failed" },
  { key: "recent7d", label: "All Recent (7d)", days: 7, status: null },
];

const traceDaysOptions = [
  { label: "Last 24 hours", value: 1 },
  { label: "Last 2 days", value: 2 },
  { label: "Last 7 days", value: 7 },
  { label: "Last 10 days", value: 10 },
];

const getEventColor = (event) => {
  const e = (event || "").toUpperCase();
  if (e.includes("DELIVER") || e.includes("RESOLVE")) return "success";
  if (e.includes("FAIL") || e.includes("DROP")) return "error";
  if (e.includes("QUARANTINE")) return "warning";
  return "grey";
};

const DeliveryTimeline = ({ events }) => {
  if (!events?.length) return <Typography>No delivery events found.</Typography>;

  return (
    <Timeline position="right">
      {events.map((evt, idx) => (
        <TimelineItem key={idx}>
          <TimelineOppositeContent sx={{ maxWidth: 140, flex: "none" }}>
            <Typography variant="caption" color="text.secondary">
              {evt.Date}
            </Typography>
          </TimelineOppositeContent>
          <TimelineSeparator>
            <TimelineDot color={getEventColor(evt.Event)} />
            {idx < events.length - 1 && <TimelineConnector />}
          </TimelineSeparator>
          <TimelineContent>
            <Paper
              elevation={0}
              sx={{ p: 1.5, mb: 1, bgcolor: "background.default", borderRadius: 1 }}
            >
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                {evt.Event}
              </Typography>
              {evt.Action && (
                <Typography variant="body2" color="text.secondary">
                  Action: {evt.Action}
                </Typography>
              )}
              {evt.Detail && (
                <Typography variant="body2" sx={{ mt: 0.5, wordBreak: "break-word" }}>
                  {evt.Detail}
                </Typography>
              )}
            </Paper>
          </TimelineContent>
        </TimelineItem>
      ))}
    </Timeline>
  );
};

const authResultColor = (result) => {
  const r = (result || "").toLowerCase();
  if (r === "pass" || r === "bestguesspass") return "success";
  if (r === "fail" || r === "permerror") return "error";
  if (r === "softfail" || r === "temperror") return "warning";
  return "default";
};

const AuthSummaryCard = ({ summary }) => {
  if (!summary) return null;
  const items = [
    { label: "SPF", result: summary.SPF?.result, detail: summary.SPF?.detail },
    { label: "DKIM", result: summary.DKIM?.result, detail: summary.DKIM?.detail },
    { label: "DMARC", result: summary.DMARC?.result, detail: summary.DMARC?.detail },
    { label: "CompAuth", result: summary.CompAuth?.result },
  ];
  const allUnknown = items.every((i) => !i.result || i.result === "Unknown");
  if (allUnknown) return null;

  return (
    <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
      <Typography variant="subtitle2" sx={{ mb: 1, fontWeight: 600 }}>
        Authentication Results
      </Typography>
      <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
        {items.map((item) => (
          <Chip
            key={item.label}
            label={`${item.label}: ${item.result || "Unknown"}${item.detail ? ` (${item.detail})` : ""}`}
            color={authResultColor(item.result)}
            size="small"
            variant="outlined"
          />
        ))}
      </Stack>
    </Paper>
  );
};

const statusColorMap = {
  Delivered: "success",
  Quarantined: "warning",
  Failed: "error",
  FilteredAsSpam: "warning",
  Pending: "default",
  Expanded: "info",
};

const Page = () => {
  const dispatch = useDispatch();
  const tenantFilter = useSettings().currentTenant;
  const [activePreset, setActivePreset] = useState(null);
  const [searchCollapsed, setSearchCollapsed] = useState(false);
  const [activeTab, setActiveTab] = useState(0);
  const [traceResults, setTraceResults] = useState([]);
  const [quarantineResults, setQuarantineResults] = useState([]);
  const [summary, setSummary] = useState(null);
  const [traceError, setTraceError] = useState(null);
  const [quarantineError, setQuarantineError] = useState(null);
  const [highlightMessageId, setHighlightMessageId] = useState(null);

  const [detailDialogOpen, setDetailDialogOpen] = useState(false);
  const [traceDetailData, setTraceDetailData] = useState([]);
  const [authSummary, setAuthSummary] = useState(null);
  const [detailMessageId, setDetailMessageId] = useState(null);

  const [selectedQuarantineRows, setSelectedQuarantineRows] = useState([]);
  const [messageViewerOpen, setMessageViewerOpen] = useState(false);
  const [viewMessageId, setViewMessageId] = useState(null);
  const [messageContentsWaiting, setMessageContentsWaiting] = useState(false);

  const [detailRow, setDetailRow] = useState(null);

  const formControl = useForm({
    defaultValues: {
      dateFilter: "relative",
      days: { label: "Last 2 days", value: 2 },
      startDate: null,
      endDate: null,
      sender: [],
      recipient: [],
      messageId: "",
      subject: "",
      subjectExact: "",
      senderDomain: "",
      recipientDomain: "",
      policyName: "",
      status: [],
      fromIP: "",
      toIP: "",
      quarantineType: [],
      releaseStatus: [],
      policyTypes: [],
    },
    mode: "onChange",
  });

  const { syncFiltersToUrl } = useQuarantineFilters({ formControl, enabled: true });

  const searchApi = ApiPostCall({
    urlFromData: true,
    queryKey: "EmailTroubleshoot",
    onResult: (result) => {
      const data = result?.Results ?? result;
      setTraceResults(data?.MessageTrace ?? []);
      setQuarantineResults(data?.Quarantine ?? []);
      setSummary(data?.Summary ?? null);
      setTraceError(data?.TraceError ?? null);
      setQuarantineError(data?.QuarantineError ?? null);
      setHighlightMessageId(null);
      setSearchCollapsed(true);
    },
  });

  const traceDetailApi = ApiPostCall({
    urlFromData: true,
    queryKey: `TraceDetail-${detailMessageId}`,
    onResult: (result) => {
      const data = Array.isArray(result) ? result[0] : result;
      if (data?.Events) {
        setTraceDetailData(data.Events);
        setAuthSummary(data.AuthSummary ?? null);
      } else {
        setTraceDetailData(Array.isArray(result) ? result : []);
        setAuthSummary(null);
      }
    },
  });

  const getMessageContents = ApiGetCall({
    url: "/api/ListMailQuarantineMessage",
    data: { tenantFilter, Identity: viewMessageId },
    waiting: messageContentsWaiting,
    queryKey: `QuarantineMessage-${viewMessageId}`,
  });

  const bulkReleaseApi = ApiPostCall({
    urlFromData: true,
    queryKey: "BulkQuarantineRelease",
    onResult: () => {
      setSelectedQuarantineRows([]);
      onSubmit();
    },
  });

  const buildSearchData = (overrides = {}) => {
    const values = { ...formControl.getValues(), ...overrides };
    return buildQuarantineSearchPayload(values, tenantFilter, overrides);
  };

  const onSubmit = (overrides) => {
    const values = { ...formControl.getValues(), ...overrides };
    syncFiltersToUrl(values);
    searchApi.mutate({
      url: "/api/ExecEmailTroubleshoot",
      data: buildSearchData(overrides),
    });
  };

  const onClear = () => {
    formControl.reset();
    setActivePreset(null);
    setTraceResults([]);
    setQuarantineResults([]);
    setSummary(null);
    setTraceError(null);
    setQuarantineError(null);
    setHighlightMessageId(null);
  };

  const applyPreset = (preset) => {
    const daysOption = traceDaysOptions.find((o) => o.value === preset.days) || {
      label: `Last ${preset.days} days`,
      value: preset.days,
    };
    formControl.setValue("dateFilter", "relative");
    formControl.setValue("days", daysOption);
    if (preset.status) {
      formControl.setValue("status", [{ label: preset.status, value: preset.status }]);
    } else {
      formControl.setValue("status", []);
    }
    setActivePreset(preset.key);
    onSubmit({
      dateFilter: "relative",
      days: daysOption,
      status: preset.status ? [{ value: preset.status }] : [],
    });
  };

  const viewTraceDetail = (row) => {
    // Clear the previous trace so the dialog doesn't show stale rows while loading.
    setTraceDetailData([]);
    setAuthSummary(null);
    setDetailMessageId(row.MessageTraceId);
    traceDetailApi.mutate({
      url: "/api/ListMessageTrace",
      data: {
        tenantFilter,
        id: row.MessageTraceId,
        recipient: row.RecipientAddress,
        traceDetail: true,
      },
    });
    setDetailDialogOpen(true);
  };

  const viewQuarantineMessage = (row) => {
    setViewMessageId(row.Identity);
    if (!messageContentsWaiting) setMessageContentsWaiting(true);
    getMessageContents.refetch();
    setMessageViewerOpen(true);
  };

  const handleBulkRelease = (rows, type, extra = {}) => {
    const identities = rows.map((row) => row.Identity);
    bulkReleaseApi.mutate({
      url: "/api/ExecQuarantineManagement",
      data: { tenantFilter, Identity: identities, Type: type, ...extra },
    });
  };

  const traceActions = [
    {
      label: "View Delivery Details",
      noConfirm: true,
      customFunction: viewTraceDetail,
      icon: <DocumentTextIcon />,
      category: "view",
    },
    {
      label: "View in Explorer",
      noConfirm: true,
      link: `https://security.microsoft.com/realtimereportsv3?tid=${tenantFilter}&dltarget=Explorer&dlstorage=Url&viewid=allemail&query-NetworkMessageId=[MessageTraceId]`,
      icon: <DocumentTextIcon />,
      category: "view",
    },
    {
      label: "Allow Sender",
      type: "POST",
      url: "/api/AddTenantAllowBlockList",
      data: {
        tenantID: tenantFilter,
        entries: "SenderAddress",
        listType: "!Sender",
        listMethod: "!Allow",
        notes: "!Allowed via Email Troubleshooter",
        RemoveAfter: true,
      },
      confirmText: "Allow this sender for all users in the tenant?",
      icon: <CheckCircle />,
      category: "security",
    },
    {
      label: "Block Sender",
      type: "POST",
      url: "/api/AddTenantAllowBlockList",
      data: {
        tenantID: tenantFilter,
        entries: "SenderAddress",
        listType: "!Sender",
        listMethod: "!Block",
        notes: "!Blocked via Email Troubleshooter",
        NoExpiration: true,
      },
      confirmText: "Block this sender for all users in the tenant?",
      icon: <Block />,
      category: "security",
    },
    {
      label: "Release from Quarantine",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      multiPost: true,
      data: { Identity: "MessageId", Type: "!Release" },
      confirmText: "Release this message from quarantine?",
      icon: <Done />,
      condition: (row) => row.Status === "Quarantined",
      category: "security",
    },
    {
      label: "Copy Message ID",
      noConfirm: true,
      customFunction: (row) => navigator.clipboard.writeText(row.MessageId || row.MessageTraceId),
      icon: <ContentCopy />,
      category: "view",
    },
  ];

  const quarantineActions = useMemo(
    () =>
      buildQuarantineActions({
        tenantFilter,
        onPreview: viewQuarantineMessage,
        onViewTimeline: (row) => {
          setTraceDetailData([]);
          setAuthSummary(null);
          setDetailMessageId(row.MessageId);
          setDetailRow(row);
          traceDetailApi.mutate({
            url: "/api/ListMessageTrace",
            data: { tenantFilter, messageId: row.MessageId, traceDetail: true },
          });
          setDetailDialogOpen(true);
        },
        includeExplorerLink: true,
      }),
    [tenantFilter]
  );

  const quarantineColumns = useMemo(() => buildQuarantineColumns(), []);

  const traceColumns = [
    { header: "Received", accessorKey: "Received" },
    {
      header: "Status",
      accessorKey: "Status",
      Cell: ({ row }) => {
        const status = row.original.Status;
        const isQuarantined = status === "Quarantined";
        return (
          <Chip
            label={status}
            color={statusColorMap[status] || "default"}
            size="small"
            variant="outlined"
            onClick={
              isQuarantined
                ? () => {
                    setActiveTab(1);
                    setHighlightMessageId(row.original.MessageId);
                  }
                : undefined
            }
            sx={isQuarantined ? { cursor: "pointer" } : {}}
          />
        );
      },
    },
    { header: "Sender", accessorKey: "SenderAddress" },
    { header: "Recipient", accessorKey: "RecipientAddress" },
    { header: "Subject", accessorKey: "Subject" },
  ];

  const displayedQuarantineResults =
    highlightMessageId && activeTab === 1
      ? quarantineResults.filter((r) => r.MessageId === highlightMessageId)
      : quarantineResults;

  const noHighlightMatch =
    highlightMessageId &&
    activeTab === 1 &&
    displayedQuarantineResults.length === 0;

  return (
    <Stack spacing={2} sx={{ px: 3 }}>
      <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
        <Typography variant="body2" color="text.secondary" sx={{ mr: 1 }}>
          Trace quick search:
        </Typography>
        {quickPresets.map((preset) => (
          <Chip
            key={preset.key}
            label={preset.label}
            size="small"
            onClick={() => applyPreset(preset)}
            color={activePreset === preset.key ? "primary" : "default"}
            variant={activePreset === preset.key ? "filled" : "outlined"}
            sx={{ cursor: "pointer" }}
          />
        ))}
      </Stack>

      {!searchCollapsed ? (
        <CippQuarantineFilterPanel
          formControl={formControl}
          onSearch={() => onSubmit()}
          onClear={onClear}
          onPreset={(preset) => {
            const daysOption =
              QUARANTINE_DAYS_OPTIONS.find((option) => option.value === preset.days) ||
              QUARANTINE_DAYS_OPTIONS[1];
            formControl.setValue("dateFilter", "relative");
            formControl.setValue("days", daysOption);
            setActivePreset(preset.key);
            onSubmit({ dateFilter: "relative", days: daysOption });
          }}
          activePreset={activePreset}
          showTraceFilters
          title="Email Troubleshooting Search"
        />
      ) : (
        <Button size="small" onClick={() => setSearchCollapsed(false)}>
          Show Search Filters
        </Button>
      )}

      {/* Error Alerts */}
      {traceError && (
        <Alert severity="warning" onClose={() => setTraceError(null)}>
          {traceError}
        </Alert>
      )}
      {quarantineError && (
        <Alert severity="warning" onClose={() => setQuarantineError(null)}>
          {quarantineError}
        </Alert>
      )}

      {/* Results Tabs */}
      <Tabs value={activeTab} onChange={(e, v) => setActiveTab(v)}>
        <Tab
          label={
            <Badge badgeContent={summary?.traceCount ?? 0} color="primary" max={999}>
              <span style={{ paddingRight: 12 }}>Message Trace</span>
            </Badge>
          }
        />
        <Tab
          label={
            <Badge badgeContent={summary?.quarantineUnreleased ?? 0} color="warning" max={999}>
              <span style={{ paddingRight: 12 }}>Quarantine</span>
            </Badge>
          }
        />
      </Tabs>

      {/* Message Trace Tab */}
      {activeTab === 0 && (
        <CippDataTable
          title="Message Trace Results"
          columns={traceColumns}
          data={traceResults}
          isFetching={searchApi.isPending}
          refreshFunction={() => onSubmit()}
          actions={traceActions}
        />
      )}

      {/* Quarantine Tab */}
      {activeTab === 1 && (
        <>
          {highlightMessageId && (
            <Stack direction="row" spacing={1} alignItems="center">
              <Chip
                label={`Filtered by Message ID`}
                onDelete={() => setHighlightMessageId(null)}
                color="primary"
                size="small"
              />
            </Stack>
          )}
          {noHighlightMatch && (
            <Alert
              severity="info"
              action={
                <Button
                  color="inherit"
                  size="small"
                  onClick={() => setHighlightMessageId(null)}
                >
                  Show All
                </Button>
              }
            >
              This message was not found in the current quarantine results. It may have already
              been released or expired.
            </Alert>
          )}
          <CippQuarantineBulkToolbar
            selectedRows={selectedQuarantineRows}
            isProcessing={bulkReleaseApi.isPending}
            onRelease={(rows) => handleBulkRelease(rows, "Release")}
            onDeny={(rows) => handleBulkRelease(rows, "Deny")}
            onReleaseAllow={(rows) => handleBulkRelease(rows, "Release", { AddAllowEntry: true })}
            onDelete={(rows) => handleBulkRelease(rows, "Delete")}
            onSubmitToMicrosoft={(rows) =>
              handleBulkRelease(rows, "Release", { ReportFalsePositive: true })
            }
            onBlockSenders={(rows) =>
              handleBulkBlockSenders({
                rows,
                tenantFilter,
                mutate: bulkReleaseApi.mutate,
                dispatch,
                showToast,
                sourceLabel: "Email Troubleshooter",
                onComplete: () => setSelectedQuarantineRows([]),
              })
            }
          />
          <CippDataTable
            title="Quarantine Results"
            columns={quarantineColumns}
            data={displayedQuarantineResults}
            isFetching={searchApi.isPending}
            refreshFunction={() => onSubmit()}
            actions={quarantineActions}
            onChange={(rows) => setSelectedQuarantineRows(rows)}
          />
        </>
      )}

      {/* Delivery Detail Dialog */}
      <Dialog
        open={detailDialogOpen}
        onClose={() => setDetailDialogOpen(false)}
        maxWidth="lg"
        fullWidth
      >
        <DialogTitle sx={{ py: 2 }}>
          Delivery Details
          <IconButton
            onClick={() => setDetailDialogOpen(false)}
            sx={{ position: "absolute", right: 8, top: 8 }}
          >
            <Close />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers>
          {traceDetailApi.isPending && (
            <Stack direction="row" alignItems="center" spacing={1} sx={{ py: 4 }}>
              <CircularProgress size={20} />
              <Typography variant="body1">Loading delivery details...</Typography>
            </Stack>
          )}
          {traceDetailApi.isSuccess && (
            <>
              <AuthSummaryCard summary={authSummary} />
              <DeliveryTimeline events={traceDetailData ?? []} />
              {detailRow && activeTab === 1 && (
                <Stack spacing={2} sx={{ mt: 2 }}>
                  <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                    Quarantine Details
                  </Typography>
                  <CippQuarantineDetailPanel
                    row={detailRow}
                    tenantFilter={tenantFilter}
                    onPreview={viewQuarantineMessage}
                  />
                </Stack>
              )}
            </>
          )}
        </DialogContent>
      </Dialog>

      {/* Message Viewer Dialog */}
      <Dialog
        open={messageViewerOpen}
        onClose={() => setMessageViewerOpen(false)}
        maxWidth="lg"
        fullWidth
      >
        <DialogTitle sx={{ py: 2 }}>
          Quarantine Message
          <IconButton
            onClick={() => setMessageViewerOpen(false)}
            sx={{ position: "absolute", right: 8, top: 8 }}
          >
            <Close />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers>
          {getMessageContents.isSuccess && !getMessageContents.isFetching ? (
            <CippMessageViewer emailSource={getMessageContents?.data?.Message} />
          ) : (
            <Skeleton variant="rectangular" height={400} />
          )}
        </DialogContent>
      </Dialog>
    </Stack>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
