import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { CippHead } from "../../../components/CippComponents/CippHead";
import {
  Alert,
  AlertTitle,
  Box,
  Button,
  Card,
  CardContent,
  CardHeader,
  Container,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  Divider,
  Grid,
  LinearProgress,
  Stack,
  Typography,
} from "@mui/material";
import { useEffect, useMemo, useState } from "react";
import { useForm, useWatch } from "react-hook-form";
import {
  Search as SearchIcon,
  Compress as CompressIcon,
  Download as DownloadIcon,
  Info as InfoIcon,
  WarningAmber as WarningIcon,
} from "@mui/icons-material";
import { useSettings } from "../../../hooks/use-settings";
import { useDialog } from "../../../hooks/use-dialog";
import { ApiGetCall, ApiPostCall } from "../../../api/ApiCall";
import { CippFormComponent } from "../../../components/CippComponents/CippFormComponent";
import { CippDataTable } from "../../../components/CippTable/CippDataTable";
import { getCippError } from "../../../utils/get-cipp-error";

const OPTIMIZE_URL = "/api/ExecSharePointImageOptimize";
const QUEUE_URL = "/api/ListCippQueue";
const RESULTS_URL = "/api/ListImageOptimizerResults";
const START_TIMEOUT_MS = 30000; // Queueing the job is fast; the work runs in the background.
const POLL_INTERVAL_MS = 3000;

const MODE_OPTIONS = [
  { label: "Audit only", value: "Audit" },
  { label: "Compress only", value: "Compress" },
  { label: "Compress and delete old versions", value: "CompressAndCleanup" },
];

const CLEANUP_OPTIONS = [
  { label: "Do not delete versions", value: "none" },
  { label: "Recycle old versions (recoverable)", value: "recycle" },
  { label: "Permanently delete old versions", value: "permanent" },
];

const RESULT_COLUMNS = [
  "FileName",
  "ServerRelativePath",
  "Site",
  "Library",
  "OriginalBytes",
  "CompressedBytes",
  "SavingsBytes",
  "SavingsPercent",
  "VersionCountBefore",
  "VersionsDeleted",
  "Status",
  "Error",
];

const getValue = (v) => (v && typeof v === "object" ? v.value : v);

const formatBytes = (bytes) => {
  const n = Number(bytes) || 0;
  if (n === 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const k = 1024;
  const i = Math.min(Math.floor(Math.log(n) / Math.log(k)), units.length - 1);
  return `${(n / Math.pow(k, i)).toFixed(i > 0 ? 2 : 0)} ${units[i]}`;
};

const sanitizeForFile = (value) => (value || "tenant").replace(/[^a-zA-Z0-9.-]+/g, "_");

const triggerDownload = (content, mimeType, filename) => {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
};

const csvEscape = (value) => {
  if (value === null || value === undefined) return "";
  const str = String(value).replace(/"/g, '""');
  return `"${str}"`;
};

const SummaryCard = ({ label, value, color }) => (
  <Card variant="outlined" sx={{ height: "100%" }}>
    <CardContent>
      <Typography variant="overline" color="text.secondary">
        {label}
      </Typography>
      <Typography variant="h5" color={color || "text.primary"}>
        {value}
      </Typography>
    </CardContent>
  </Card>
);

const ImageOptimizerPage = () => {
  const settings = useSettings();
  const tenantFilter = settings.currentTenant;
  const tenantSelected = tenantFilter && tenantFilter !== "AllTenants";

  const formControl = useForm({
    mode: "onChange",
    defaultValues: {
      site: null,
      library: null,
      folder: null,
      includeSubfolders: true,
      minimumFileSizeMB: 5,
      jpegQuality: 82,
      mode: MODE_OPTIONS[0],
      versionCleanupMode: CLEANUP_OPTIONS[0],
      whatIf: true,
      minimumSavingsPercent: 15,
      stripMetadata: true,
      maxFiles: "",
    },
  });

  const site = useWatch({ control: formControl.control, name: "site" });
  const library = useWatch({ control: formControl.control, name: "library" });
  const mode = getValue(useWatch({ control: formControl.control, name: "mode" }));
  const whatIf = useWatch({ control: formControl.control, name: "whatIf" });

  const [result, setResult] = useState(null);
  const [hasAudited, setHasAudited] = useState(false);
  const [runError, setRunError] = useState(null);
  const [lastRunMode, setLastRunMode] = useState(null);
  const [queueId, setQueueId] = useState(null);
  const [isRunning, setIsRunning] = useState(false);
  const [fetchResults, setFetchResults] = useState(false);
  const confirmDialog = useDialog();

  const siteId = getValue(site);
  const driveId = getValue(library);

  // Reset audit gate + selections when the target changes.
  useEffect(() => {
    setHasAudited(false);
    setResult(null);
    setQueueId(null);
    setIsRunning(false);
    setFetchResults(false);
    formControl.setValue("library", null);
    formControl.setValue("folder", null);
  }, [siteId, tenantFilter]); // eslint-disable-line react-hooks/exhaustive-deps

  // Changing the library invalidates the chosen folder and any prior audit.
  useEffect(() => {
    setHasAudited(false);
    formControl.setValue("folder", null);
  }, [driveId]); // eslint-disable-line react-hooks/exhaustive-deps

  // Any change to the folder or the settings that determine which files are eligible
  // invalidates a prior audit, so a destructive live run can never execute against a
  // different scope/settings than the audit the user actually reviewed.
  const auditScope = useWatch({
    control: formControl.control,
    name: [
      "folder",
      "includeSubfolders",
      "minimumFileSizeMB",
      "jpegQuality",
      "minimumSavingsPercent",
      "stripMetadata",
      "maxFiles",
    ],
  });
  useEffect(() => {
    setHasAudited(false);
  }, auditScope); // eslint-disable-line react-hooks/exhaustive-deps

  const startApi = ApiPostCall({});

  const queuePoll = ApiGetCall({
    url: QUEUE_URL,
    data: { QueueId: queueId },
    queryKey: `ImageOptQueue-${queueId}`,
    waiting: !!queueId && isRunning && !fetchResults,
    refetchInterval: (pollData) => {
      const status = pollData?.[0]?.Status;
      if (status === "Completed" || status === "Failed" || status === "Completed (with errors)") {
        return false;
      }
      return POLL_INTERVAL_MS;
    },
    refetchOnMount: true,
    refetchOnWindowFocus: false,
  });

  const resultsPoll = ApiGetCall({
    url: RESULTS_URL,
    data: { queueId, tenantFilter },
    queryKey: `ImageOptResults-${queueId}`,
    waiting: fetchResults && !!queueId,
    refetchInterval: (pollData) => {
      if (pollData?.Status === "Completed" || pollData?.Results) {
        return false;
      }
      return POLL_INTERVAL_MS;
    },
    refetchOnMount: true,
    refetchOnWindowFocus: false,
  });

  // Queue status drives the transition from "scanning" to "loading results".
  useEffect(() => {
    const status = queuePoll.data?.[0]?.Status;
    if (!status || !isRunning || fetchResults) return;
    if (status === "Completed" || status === "Completed (with errors)") {
      setFetchResults(true);
      return;
    }
    if (status === "Failed") {
      setIsRunning(false);
      setRunError("The image optimizer job failed. Check the CIPP logs for details and try again.");
    }
  }, [queuePoll.data, isRunning, fetchResults]);

  // Results payload completes the run.
  useEffect(() => {
    if (!fetchResults) return;
    if (resultsPoll.isError) {
      setIsRunning(false);
      setFetchResults(false);
      setRunError(getCippError(resultsPoll.error) || "Failed to load optimizer results.");
      return;
    }
    const payload = resultsPoll.data;
    if (!payload || payload.Status === "Running") return;
    if (payload.Status === "Completed" || Array.isArray(payload.Results)) {
      setResult(payload);
      setIsRunning(false);
      setFetchResults(false);
      if (lastRunMode === "Audit") setHasAudited(true);
    }
  }, [resultsPoll.data, resultsPoll.isError, resultsPoll.error, fetchResults, lastRunMode]);

  const numOrDefault = (raw, fallback) => {
    if (raw === "" || raw === null || raw === undefined) return fallback;
    const n = Number(raw);
    return Number.isFinite(n) ? n : fallback;
  };

  const buildPayload = (runMode) => {
    const values = formControl.getValues();
    const maxFiles = Number(values.maxFiles);
    const folder = values.folder;
    return {
      tenantFilter,
      SiteId: getValue(values.site),
      SiteUrl: values.site?.addedFields?.webUrl,
      DriveId: getValue(values.library),
      LibraryName: values.library?.label,
      FolderId: getValue(folder) || "",
      FolderPath: folder?.addedFields?.path || folder?.label || "",
      Mode: runMode,
      MinimumFileSizeMB: numOrDefault(values.minimumFileSizeMB, 5),
      JpegQuality: numOrDefault(values.jpegQuality, 82),
      MinimumSavingsPercent: numOrDefault(values.minimumSavingsPercent, 15),
      StripMetadata: !!values.stripMetadata,
      WhatIf: !!values.whatIf,
      VersionCleanupMode:
        runMode === "CompressAndCleanup" ? getValue(values.versionCleanupMode) : "none",
      MaxFiles: Number.isFinite(maxFiles) && maxFiles > 0 ? maxFiles : 0,
      IncludeSubfolders: !!values.includeSubfolders,
    };
  };

  // Not memoized on purpose: buildPayload closes over the currently selected tenant and
  // form values, so executeRun must be recreated each render to avoid POSTing a stale
  // tenantFilter after the user switches tenants in the header.
  const executeRun = (runMode) => {
    setRunError(null);
    setResult(null);
    setQueueId(null);
    setFetchResults(false);
    setLastRunMode(runMode);
    setIsRunning(true);
    startApi.mutate(
      { url: OPTIMIZE_URL, data: buildPayload(runMode), timeout: START_TIMEOUT_MS },
      {
        onSuccess: (response) => {
          const body = response?.data;
          if (body?.Queued && body?.QueueId) {
            setQueueId(body.QueueId);
            return;
          }
          // Backwards-compatible: a synchronous body would already contain results.
          if (body?.Results || body?.Summary) {
            setResult(body);
            setIsRunning(false);
            if (runMode === "Audit") setHasAudited(true);
            return;
          }
          setIsRunning(false);
          setRunError("The job did not start correctly. Please try again.");
        },
        onError: (err) => {
          setIsRunning(false);
          const message = getCippError(err);
          setRunError(
            (typeof message === "string" && message) ||
              err?.message ||
              "The run failed. Please try again."
          );
        },
      }
    );
  };

  const handleRunAudit = () => executeRun("Audit");

  const handleRunCompression = () => {
    if (!whatIf) {
      confirmDialog.handleOpen();
      return;
    }
    executeRun(mode === "CompressAndCleanup" ? "CompressAndCleanup" : "Compress");
  };

  const confirmDestructiveRun = () => {
    confirmDialog.handleClose();
    executeRun(mode === "CompressAndCleanup" ? "CompressAndCleanup" : "Compress");
  };

  const compressionDisabled =
    !tenantSelected || !siteId || isRunning || mode === "Audit" || (!whatIf && !hasAudited);

  const summary = result?.Summary;
  const rows = useMemo(() => (result?.Results || []).filter(Boolean), [result]);
  const warnings = (result?.Warnings || []).filter(Boolean);
  const permissionIssue = rows.some(
    (r) => r.Status === "Compressed, version cleanup failed" || /permission/i.test(r.Error || "")
  );

  const exportResults = (format) => {
    if (!rows.length) return;
    const ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
    const base = `sharepoint-image-optimizer-${sanitizeForFile(tenantFilter)}-${ts}`;
    if (format === "json") {
      triggerDownload(JSON.stringify(result, null, 2), "application/json", `${base}.json`);
      return;
    }
    const header = RESULT_COLUMNS.join(",");
    const lines = rows.map((row) => RESULT_COLUMNS.map((c) => csvEscape(row[c])).join(","));
    triggerDownload([header, ...lines].join("\n"), "text/csv", `${base}.csv`);
  };

  const runningLabel = !queueId
    ? "Starting job..."
    : fetchResults
      ? "Loading results..."
      : "Scanning in the background — large folders may take a few minutes...";

  return (
    <Box sx={{ flexGrow: 1, py: 4 }}>
      <CippHead title="SharePoint Image Optimizer" />
      <Container maxWidth="xl">
        <Stack spacing={3}>
          <Box>
            <Typography variant="h4" sx={{ mb: 1 }}>
              SharePoint Image Optimizer
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Identify large JPG/JPEG files in a SharePoint document library or a specific folder,
              compress them server-side, and optionally remove old file versions to reclaim storage.
            </Typography>
          </Box>

          <Alert severity="info" icon={<InfoIcon />}>
            Runs in the background so large libraries don&apos;t time out. Replacing a JPG may not
            reclaim SharePoint storage until old file versions are deleted or retention expires — use
            the version cleanup options to actually free space.
          </Alert>

          {!tenantSelected && (
            <Alert severity="warning">
              Select a specific tenant from the tenant selector above. This tool cannot run against
              &quot;All Tenants&quot;.
            </Alert>
          )}

          {permissionIssue && (
            <Alert severity="warning" icon={<WarningIcon />}>
              Compression may succeed while version cleanup fails if the app/account lacks permission
              to delete file versions. Review the per-file errors below.
            </Alert>
          )}

          <Card>
            <CardHeader title="Target" subheader="Choose where to look for large images." />
            <Divider />
            <CardContent>
              <Grid container spacing={3}>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="site"
                    label="SharePoint Site"
                    type="autoComplete"
                    multiple={false}
                    formControl={formControl}
                    required
                    disabled={!tenantSelected}
                    api={{
                      url: "/api/ListSites",
                      tenantFilter,
                      data: { Type: "SharePointSiteUsage" },
                      queryKey: `ListSites-${tenantFilter}`,
                      labelField: (s) => s.displayName || s.webUrl || s.siteId,
                      valueField: "siteId",
                      addedField: { webUrl: "webUrl", displayName: "displayName" },
                    }}
                  />
                </Grid>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    key={`library-${siteId}`}
                    name="library"
                    label="Document Library"
                    type="autoComplete"
                    multiple={false}
                    formControl={formControl}
                    disabled={!siteId}
                    helperText="Leave empty to use the site's default document library."
                    api={{
                      url: "/api/ListSharePointDocumentLibraries",
                      tenantFilter,
                      data: { SiteId: siteId },
                      queryKey: `SPDocLibs-${siteId}`,
                      labelField: "name",
                      valueField: "id",
                    }}
                  />
                </Grid>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    key={`folder-${siteId}-${driveId}`}
                    name="folder"
                    label="Folder (optional)"
                    type="autoComplete"
                    multiple={false}
                    formControl={formControl}
                    disabled={!siteId}
                    helperText="Limit the run to one folder. Leave empty to scan the whole library."
                    api={{
                      url: "/api/ListSharePointFolders",
                      tenantFilter,
                      data: { SiteId: siteId, DriveId: driveId },
                      queryKey: `SPFolders-${siteId}-${driveId}`,
                      labelField: "path",
                      valueField: "id",
                      addedField: { path: "path" },
                    }}
                  />
                </Grid>

                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="includeSubfolders"
                    label="Include subfolders"
                    type="switch"
                    formControl={formControl}
                  />
                </Grid>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="minimumFileSizeMB"
                    label="File size threshold (MB)"
                    type="number"
                    formControl={formControl}
                    validators={{ min: { value: 0, message: "Must be 0 or more" } }}
                  />
                </Grid>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="maxFiles"
                    label="Max files (optional)"
                    type="number"
                    formControl={formControl}
                    helperText="Limit how many files are processed per run."
                  />
                </Grid>
              </Grid>
            </CardContent>
          </Card>

          <Card>
            <CardHeader title="Compression settings" />
            <Divider />
            <CardContent>
              <Grid container spacing={3}>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="jpegQuality"
                    label="JPEG quality (60-95)"
                    type="number"
                    formControl={formControl}
                    validators={{
                      min: { value: 60, message: "Minimum quality is 60" },
                      max: { value: 95, message: "Maximum quality is 95" },
                    }}
                  />
                </Grid>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="minimumSavingsPercent"
                    label="Minimum savings to keep (%)"
                    type="number"
                    formControl={formControl}
                    helperText="Skip files that do not shrink by at least this percent."
                    validators={{
                      min: { value: 0, message: "Must be 0 or more" },
                      max: { value: 99, message: "Must be 99 or less" },
                    }}
                  />
                </Grid>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="stripMetadata"
                    label="Strip EXIF metadata"
                    type="switch"
                    formControl={formControl}
                  />
                </Grid>

                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="mode"
                    label="Mode"
                    type="autoComplete"
                    multiple={false}
                    disableClearable
                    formControl={formControl}
                    options={MODE_OPTIONS}
                  />
                </Grid>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="versionCleanupMode"
                    label="Version cleanup"
                    type="autoComplete"
                    multiple={false}
                    disableClearable
                    formControl={formControl}
                    options={CLEANUP_OPTIONS}
                    disabled={mode !== "CompressAndCleanup"}
                    helperText={
                      mode === "CompressAndCleanup"
                        ? "Recycle is recoverable; permanent reclaims storage immediately."
                        : "Only used with the Compress and delete old versions mode."
                    }
                  />
                </Grid>
                <Grid item xs={12} md={4}>
                  <CippFormComponent
                    name="whatIf"
                    label="Dry run (WhatIf) - no files changed"
                    type="switch"
                    formControl={formControl}
                  />
                </Grid>
              </Grid>

              {mode === "CompressAndCleanup" && (
                <Alert severity="warning" sx={{ mt: 3 }}>
                  Deleting old file versions is destructive and may affect retention/recovery
                  expectations. Versions are removed only after a successful compression, and never
                  the current version.
                </Alert>
              )}

              {runError && (
                <Alert severity="error" sx={{ mt: 3 }}>
                  {String(runError)}
                </Alert>
              )}

              {isRunning && (
                <Box sx={{ mt: 3 }}>
                  <LinearProgress />
                  <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                    {runningLabel}
                  </Typography>
                </Box>
              )}

              <Stack direction="row" spacing={2} sx={{ mt: 3 }} flexWrap="wrap">
                <Button
                  variant="outlined"
                  startIcon={<SearchIcon />}
                  onClick={handleRunAudit}
                  disabled={!tenantSelected || !siteId || isRunning}
                >
                  Run Audit
                </Button>
                <Button
                  variant="contained"
                  color={!whatIf ? "error" : "primary"}
                  startIcon={<CompressIcon />}
                  onClick={handleRunCompression}
                  disabled={compressionDisabled}
                >
                  {mode === "CompressAndCleanup"
                    ? "Run Compression + Version Cleanup"
                    : "Run Compression"}
                </Button>
              </Stack>
              {mode !== "Audit" && !whatIf && !hasAudited && (
                <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: "block" }}>
                  Run an audit first before executing a live compression.
                </Typography>
              )}
            </CardContent>
          </Card>

          {summary && (
            <Grid container spacing={2}>
              <Grid item xs={6} md={2}>
                <SummaryCard label="Files scanned" value={summary.FilesScanned ?? 0} />
              </Grid>
              <Grid item xs={6} md={2}>
                <SummaryCard label="Eligible JPGs" value={summary.EligibleFiles ?? 0} />
              </Grid>
              <Grid item xs={6} md={2}>
                <SummaryCard
                  label="Estimated savings"
                  value={formatBytes(summary.EstimatedSavingsBytes)}
                  color="info.main"
                />
              </Grid>
              <Grid item xs={6} md={2}>
                <SummaryCard
                  label="Actual savings"
                  value={
                    result?.Mode === "Audit"
                      ? "—"
                      : result?.WhatIf
                        ? "Dry run"
                        : formatBytes(summary.ActualSavingsBytes ?? 0)
                  }
                  color={
                    result?.Mode === "Audit" || result?.WhatIf ? "text.secondary" : "success.main"
                  }
                />
              </Grid>
              <Grid item xs={6} md={2}>
                <SummaryCard label="Versions deleted" value={summary.VersionsDeleted ?? 0} />
              </Grid>
              <Grid item xs={6} md={2}>
                <SummaryCard
                  label="Errors"
                  value={summary.Errors ?? 0}
                  color={summary.Errors > 0 ? "error.main" : "text.primary"}
                />
              </Grid>
            </Grid>
          )}

          {warnings.length > 0 && (
            <Alert severity="info">
              <AlertTitle>Warnings</AlertTitle>
              <Stack spacing={0.5}>
                {warnings.map((w, i) => (
                  <Typography key={i} variant="body2">
                    {w}
                  </Typography>
                ))}
              </Stack>
            </Alert>
          )}

          {rows.length > 0 && (
            <Card>
              <CardHeader
                title="Results"
                action={
                  <Stack direction="row" spacing={1}>
                    <Button
                      size="small"
                      startIcon={<DownloadIcon />}
                      onClick={() => exportResults("csv")}
                    >
                      Export CSV
                    </Button>
                    <Button
                      size="small"
                      startIcon={<DownloadIcon />}
                      onClick={() => exportResults("json")}
                    >
                      Export JSON
                    </Button>
                  </Stack>
                }
              />
              <Divider />
              <CardContent>
                <CippDataTable
                  noCard
                  title="Image Optimizer Results"
                  data={rows}
                  actions={[]}
                  simpleColumns={RESULT_COLUMNS}
                />
              </CardContent>
            </Card>
          )}

          {result && rows.length === 0 && (
            <Alert severity="success">
              No eligible JPG/JPEG files were found for the current settings in this target.
            </Alert>
          )}
        </Stack>
      </Container>

      <Dialog open={confirmDialog.open} onClose={confirmDialog.handleClose} maxWidth="sm" fullWidth>
        <DialogTitle>Confirm live run</DialogTitle>
        <DialogContent>
          <DialogContentText component="div">
            {mode === "CompressAndCleanup" ? (
              <>
                This will overwrite eligible JPGs in <strong>{site?.label}</strong> with compressed
                copies <strong>and delete old file versions</strong>. Depending on the cleanup mode,
                old versions may not be recoverable. The current version is never deleted.
              </>
            ) : (
              <>
                This will overwrite eligible JPGs in <strong>{site?.label}</strong> with compressed
                copies. This modifies client data.
              </>
            )}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={confirmDialog.handleClose}>Cancel</Button>
          <Button color="error" variant="contained" onClick={confirmDestructiveRun}>
            Yes, run now
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

const Page = () => <ImageOptimizerPage />;

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
