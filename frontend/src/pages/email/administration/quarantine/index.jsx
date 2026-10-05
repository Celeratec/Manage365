import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { useEffect, useMemo, useState } from "react";
import { useForm, useWatch } from "react-hook-form";
import { useDispatch } from "react-redux";
import {
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  IconButton,
  Skeleton,
  Typography,
  CircularProgress,
  Button,
  Stack,
} from "@mui/material";
import { Close } from "@mui/icons-material";
import { CippMessageViewer } from "../../../../components/CippComponents/CippMessageViewer.jsx";
import { ApiGetCall, ApiPostCall } from "../../../../api/ApiCall";
import { useSettings } from "../../../../hooks/use-settings";
import { CippDataTable } from "../../../../components/CippTable/CippDataTable";
import { showToast } from "../../../../store/toasts";
import {
  buildQuarantineActions,
  buildQuarantineColumns,
  buildQuarantineExportFilename,
  buildQuarantineListQuery,
  buildQuarantineSearchPayload,
  CippQuarantineBulkToolbar,
  CippQuarantineDetailPanel,
  CippQuarantineFilterPanel,
  handleBulkBlockSenders,
  hasQuarantinePostFilters,
  QUARANTINE_DAYS_OPTIONS,
  triggerQuarantineFileDownload,
  useQuarantineFilters,
} from "../../../../components/CippComponents/quarantine";

const detailColumns = ["Received", "Status", "SenderAddress", "RecipientAddress"];
const pageTitle = "Quarantine Management";

const Page = () => {
  const dispatch = useDispatch();
  const tenantFilter = useSettings().currentTenant;
  const [dialogOpen, setDialogOpen] = useState(false);
  const [dialogContent, setDialogContent] = useState(null);
  const [messageId, setMessageId] = useState(null);
  const [traceDialogOpen, setTraceDialogOpen] = useState(false);
  const [traceDetails, setTraceDetails] = useState([]);
  const [traceMessageId, setTraceMessageId] = useState(null);
  const [messageSubject, setMessageSubject] = useState(null);
  const [messageContentsWaiting, setMessageContentsWaiting] = useState(false);
  const [selectedRows, setSelectedRows] = useState([]);
  const [activePreset, setActivePreset] = useState("7d");
  const [apiFilters, setApiFilters] = useState(null);
  const [tableKey, setTableKey] = useState(0);

  const formControl = useForm({
    defaultValues: {
      dateFilter: "relative",
      days: QUARANTINE_DAYS_OPTIONS[1],
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
      quarantineType: [],
      releaseStatus: [],
      policyTypes: [],
    },
    mode: "onChange",
  });

  const { syncFiltersToUrl } = useQuarantineFilters({ formControl, enabled: true });
  // Subscribe only to the post-filter fields; watching the whole form re-renders
  // the page (filter panel, toolbar, table wrapper) on every keystroke.
  const [watchedSubject, watchedSenderDomain, watchedRecipientDomain] = useWatch({
    control: formControl.control,
    name: ["subject", "senderDomain", "recipientDomain"],
  });
  const showPostFilterWarning = hasQuarantinePostFilters({
    subject: watchedSubject,
    senderDomain: watchedSenderDomain,
    recipientDomain: watchedRecipientDomain,
  });
  const quarantineColumns = useMemo(() => buildQuarantineColumns(), []);

  const getMessageContents = ApiGetCall({
    url: "/api/ListMailQuarantineMessage",
    data: {
      tenantFilter: tenantFilter,
      Identity: messageId,
    },
    waiting: messageContentsWaiting,
    queryKey: `ListMailQuarantineMessage-${messageId}`,
  });

  const getMessageTraceDetails = ApiPostCall({
    urlFromData: true,
    queryKey: `MessageTraceDetail-${traceMessageId}`,
    onResult: (result) => {
      setTraceDetails(result);
    },
  });

  const bulkApi = ApiPostCall({
    urlFromData: true,
    queryKey: "BulkQuarantineManagement",
    onResult: () => {
      setSelectedRows([]);
      setTableKey((value) => value + 1);
    },
  });

  const exportApi = ApiPostCall({
    urlFromData: true,
    queryKey: "ExportMailQuarantine",
  });

  const viewMessage = (row) => {
    const id = row.Identity;
    setMessageId(id);
    if (!messageContentsWaiting) {
      setMessageContentsWaiting(true);
    }
    getMessageContents.refetch();
    setDialogOpen(true);
  };

  const viewMessageTrace = (row) => {
    // Clear the previous trace so a second dialog doesn't show stale rows
    // under the new message's subject while the request is in flight.
    setTraceDetails(null);
    setTraceMessageId(row.MessageId);
    getMessageTraceDetails.mutate({
      url: "/api/ListMessageTrace",
      data: {
        tenantFilter: tenantFilter,
        messageId: row.MessageId,
      },
    });
    setMessageSubject(row.Subject);
    setTraceDialogOpen(true);
  };

  useEffect(() => {
    // Show the skeleton while (re)fetching so the previous message's content
    // never flashes when opening a different message.
    if (!getMessageContents.isFetching && getMessageContents.isSuccess) {
      setDialogContent(<CippMessageViewer emailSource={getMessageContents?.data?.Message} />);
    } else {
      setDialogContent(<Skeleton variant="rectangular" height={400} />);
    }
  }, [getMessageContents.isFetching, getMessageContents.isSuccess, getMessageContents.data]);

  const actions = useMemo(
    () =>
      buildQuarantineActions({
        tenantFilter,
        onPreview: viewMessage,
        onViewTrace: viewMessageTrace,
        includeExplorerLink: true,
      }),
    [tenantFilter]
  );

  const runSearch = (overrides = {}) => {
    const values = { ...formControl.getValues(), ...overrides };
    syncFiltersToUrl(values);
    setApiFilters(buildQuarantineListQuery(values, tenantFilter));
    setTableKey((value) => value + 1);
  };

  useEffect(() => {
    if (tenantFilter) {
      runSearch({ days: QUARANTINE_DAYS_OPTIONS[1] });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tenantFilter]);

  const onClear = () => {
    formControl.reset();
    setActivePreset(null);
    runSearch({ days: QUARANTINE_DAYS_OPTIONS[1] });
  };

  const onPreset = (preset) => {
    const daysOption = QUARANTINE_DAYS_OPTIONS.find((option) => option.value === preset.days) || {
      label: preset.label,
      value: preset.days,
    };
    formControl.setValue("dateFilter", "relative");
    formControl.setValue("days", daysOption);
    setActivePreset(preset.key);
    runSearch({ dateFilter: "relative", days: daysOption });
  };

  const runBulk = (rows, type, extra = {}) => {
    bulkApi.mutate({
      url: "/api/ExecQuarantineManagement",
      data: {
        tenantFilter,
        Identity: rows.map((row) => row.Identity),
        Type: type,
        ...extra,
      },
    });
  };

  const handleExportResult = (responseData, format) => {
    const metadata = responseData?.Metadata ?? {};
    const filename = buildQuarantineExportFilename(tenantFilter, format);

    if (format === "json") {
      const exportPayload = {
        Results: responseData?.Results ?? [],
        Metadata: metadata,
      };
      triggerQuarantineFileDownload(
        JSON.stringify(exportPayload, null, 2),
        "application/json",
        filename
      );
    } else {
      const csvContent = typeof responseData?.Results === "string" ? responseData.Results : "";
      triggerQuarantineFileDownload(csvContent, "text/csv", filename);
    }

    dispatch(
      showToast({
        message: `Export started (${metadata.FilteredRowsReturned ?? metadata.count ?? 0} rows).`,
        title: "Quarantine Export",
      })
    );

    if (metadata.truncated || metadata.PostFilterPaginationLimited) {
      dispatch(
        showToast({
          message:
            "Export was capped at 5,000 raw Exchange rows before post-filtering. Narrow your filters or date range for complete results.",
          title: "Export Truncated",
        })
      );
    }
  };

  const handleExport = (format = "csv") => {
    const values = formControl.getValues();
    exportApi.mutate(
      {
        url: "/api/ExportMailQuarantine",
        data: { ...buildQuarantineSearchPayload(values, tenantFilter), format },
      },
      {
        onSuccess: (response) => handleExportResult(response?.data, format),
        onError: (error) => {
          dispatch(
            showToast({
              message:
                error?.response?.data?.Results ||
                error?.message ||
                "Failed to export quarantine results.",
              title: "Export Failed",
              toastError: error,
            })
          );
        },
      }
    );
  };

  const handleExportSelected = (rows) => {
    const header =
      "ReceivedTime,Subject,SenderAddress,RecipientAddress,Type,ReleaseStatus,PolicyName,MessageId,Identity";
    const lines = rows.map((row) =>
      [
        row.ReceivedTime,
        `"${(row.Subject || "").replace(/"/g, '""')}"`,
        row.SenderAddress,
        row.RecipientAddress,
        row.Type,
        row.ReleaseStatus,
        row.PolicyName,
        row.MessageId,
        row.Identity,
      ].join(",")
    );
    triggerQuarantineFileDownload(
      [header, ...lines].join("\n"),
      "text/csv",
      buildQuarantineExportFilename(tenantFilter, "csv", "selected")
    );
    dispatch(
      showToast({
        message: `Exported ${rows.length} selected row(s).`,
        title: "Quarantine Export",
      })
    );
  };

  const filterList = [
    {
      filterName: "Not Released",
      value: [{ id: "ReleaseStatus", value: "NOTRELEASED" }],
      type: "column",
      filterType: "equal",
    },
    {
      filterName: "Released",
      value: [{ id: "ReleaseStatus", value: "RELEASED" }],
      type: "column",
      filterType: "equal",
    },
    {
      filterName: "Requested",
      value: [{ id: "ReleaseStatus", value: "REQUESTED" }],
      type: "column",
      filterType: "equal",
    },
  ];

  const offCanvas = {
    actions: actions,
    children: (row) => (
      <CippQuarantineDetailPanel
        row={row}
        tenantFilter={tenantFilter}
        onPreview={viewMessage}
        onRunTrace={viewMessageTrace}
      />
    ),
  };

  return (
    <>
      <Stack spacing={2} sx={{ px: 3, pb: 2 }}>
        <CippQuarantineFilterPanel
          formControl={formControl}
          onSearch={() => runSearch()}
          onClear={onClear}
          onPreset={onPreset}
          activePreset={activePreset}
        />
        {showPostFilterWarning && (
          <Alert severity="info">
            Subject and sender/recipient domain filters are applied after Exchange returns results.
            Pagination may require multiple pages, and export is the most reliable way to review
            complete filtered results.
          </Alert>
        )}
        <Stack direction="row" spacing={1}>
          <Button
            size="small"
            variant="outlined"
            disabled={exportApi.isPending}
            onClick={() => handleExport("csv")}
          >
            Export Results (CSV)
          </Button>
          <Button
            size="small"
            variant="outlined"
            disabled={exportApi.isPending}
            onClick={() => handleExport("json")}
          >
            Export Results (JSON)
          </Button>
        </Stack>
        <CippQuarantineBulkToolbar
          selectedRows={selectedRows}
          isProcessing={bulkApi.isPending}
          onRelease={(rows) => runBulk(rows, "Release")}
          onDeny={(rows) => runBulk(rows, "Deny")}
          onReleaseAllow={(rows) => runBulk(rows, "Release", { AddAllowEntry: true })}
          onDelete={(rows) => runBulk(rows, "Delete")}
          onSubmitToMicrosoft={(rows) => runBulk(rows, "Release", { ReportFalsePositive: true })}
          onBlockSenders={(rows) =>
            handleBulkBlockSenders({
              rows,
              tenantFilter,
              mutate: bulkApi.mutate,
              dispatch,
              showToast,
              sourceLabel: "Quarantine Management",
              onComplete: () => {
                setSelectedRows([]);
                setTableKey((value) => value + 1);
              },
            })
          }
          onExportSelected={handleExportSelected}
        />
      </Stack>
      <CippTablePage
        key={tableKey}
        title={pageTitle}
        apiUrl="/api/ListMailQuarantine"
        apiData={apiFilters || { tenantFilter, manualPagination: true, days: 7, pageSize: 100 }}
        apiDataKey="Results"
        actions={actions}
        offCanvas={offCanvas}
        columns={quarantineColumns}
        filters={filterList}
        onChange={(rows) => setSelectedRows(rows)}
        queryKey={`QuarantineManagement-${tableKey}`}
        tenantInTitle
      />
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="lg" fullWidth>
        <DialogTitle sx={{ py: 2 }}>
          Quarantine Message
          <IconButton
            aria-label="close"
            onClick={() => setDialogOpen(false)}
            sx={{ position: "absolute", right: 8, top: 8 }}
          >
            <Close />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers>{dialogContent}</DialogContent>
      </Dialog>
      <Dialog
        open={traceDialogOpen}
        onClose={() => setTraceDialogOpen(false)}
        maxWidth="lg"
        fullWidth
      >
        <DialogTitle sx={{ py: 2 }}>
          Message Trace - {messageSubject}
          <IconButton
            aria-label="close"
            onClick={() => setTraceDialogOpen(false)}
            sx={{ position: "absolute", right: 8, top: 8 }}
          >
            <Close />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers>
          {getMessageTraceDetails.isPending && (
            <Typography variant="body1" sx={{ py: 4 }}>
              <CircularProgress size={20} color="inherit" sx={{ mr: 1 }} /> Loading message trace
              details...
            </Typography>
          )}
          {getMessageTraceDetails.isSuccess && (
            <CippDataTable
              noCard={true}
              title="Message Trace Details"
              simpleColumns={detailColumns}
              data={traceDetails ?? []}
              refreshFunction={() =>
                getMessageTraceDetails.mutate({
                  url: "/api/ListMessageTrace",
                  data: {
                    tenantFilter: tenantFilter,
                    messageId: traceMessageId,
                  },
                })
              }
              isFetching={getMessageTraceDetails.isPending}
            />
          )}
        </DialogContent>
      </Dialog>
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
