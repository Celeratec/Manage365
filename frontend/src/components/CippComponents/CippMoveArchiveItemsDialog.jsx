import { useMemo, useState } from "react";
import {
  Alert,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import { ApiGetCall, ApiPostCall } from "../../api/ApiCall";

const formatBytes = (bytes) => {
  if (bytes == null || Number.isNaN(Number(bytes))) return "—";
  const n = Number(bytes);
  if (n < 1024) return `${n} B`;
  if (n < 1024 ** 2) return `${(n / 1024).toFixed(1)} KB`;
  if (n < 1024 ** 3) return `${(n / 1024 ** 2).toFixed(1)} MB`;
  return `${(n / 1024 ** 3).toFixed(2)} GB`;
};

export const CippMoveArchiveItemsDialog = ({ open, onClose, tenantFilter, userPrincipalName }) => {
  const [ticketNumber, setTicketNumber] = useState("");
  const [holdAcknowledged, setHoldAcknowledged] = useState(false);
  const [preview, setPreview] = useState(null);
  const [jobId, setJobId] = useState(null);
  const [error, setError] = useState(null);
  const [step, setStep] = useState("form");

  const dryRunCall = ApiPostCall({});
  const runCall = ApiPostCall({});

  const tracking = step === "tracking" && !!jobId;
  const jobStatusQuery = ApiGetCall({
    url: "/api/ListMoveArchiveItemsJobs",
    queryKey: `move-archive-job-${tenantFilter}-${jobId}`,
    data: { tenantFilter, JobId: jobId },
    waiting: open && tracking,
    refetchInterval: (query) => {
      const rows = query.state.data?.data ?? query.state.data;
      const row = Array.isArray(rows) ? rows[0] : rows;
      const status = row?.Status ?? row?.status;
      if (!status || status === "Succeeded" || status === "Failed") return false;
      return 5000;
    },
  });

  const jobRow = useMemo(() => {
    const raw = jobStatusQuery.data?.data ?? jobStatusQuery.data;
    if (!raw) return null;
    return Array.isArray(raw) ? raw[0] : raw;
  }, [jobStatusQuery.data]);

  const reset = () => {
    setPreview(null);
    setJobId(null);
    setError(null);
    setStep("form");
    setHoldAcknowledged(false);
  };

  const handleClose = () => {
    reset();
    onClose();
  };

  const buildBody = (dryRun) => ({
    tenantFilter,
    UserPrincipalName: userPrincipalName,
    TicketNumber: ticketNumber.trim(),
    DryRun: dryRun,
    HoldAcknowledged: holdAcknowledged,
  });

  const handleDryRun = async () => {
    setError(null);
    try {
      const result = await dryRunCall.mutateAsync({
        url: "/api/ExecMoveArchiveItems",
        data: buildBody(true),
      });
      const payload = result?.data?.Results?.[0] ?? result?.data;
      setPreview(payload?.Preview ?? payload?.preview ?? payload);
      setStep("preview");
    } catch (e) {
      setError(e?.message ?? "Dry run failed");
    }
  };

  const handleConfirmMove = async () => {
    setError(null);
    try {
      const result = await runCall.mutateAsync({
        url: "/api/ExecMoveArchiveItems",
        data: buildBody(false),
      });
      const payload = result?.data?.Results?.[0] ?? result?.data;
      setJobId(payload?.JobId ?? payload?.jobId);
      setStep("tracking");
    } catch (e) {
      setError(e?.message ?? "Failed to queue move job");
    }
  };

  const p = preview;
  const holds = p?.Holds ?? p?.holds ?? [];

  return (
    <Dialog open={open} onClose={handleClose} maxWidth="md" fullWidth>
      <DialogTitle>Move archive items to mailbox</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <Typography variant="body2" color="text.secondary">
            Mailbox: {userPrincipalName}
          </Typography>
          <TextField
            label="Freshdesk ticket number"
            required
            fullWidth
            value={ticketNumber}
            onChange={(e) => setTicketNumber(e.target.value.replace(/\D/g, ""))}
            inputMode="numeric"
            helperText="Required for audit (numeric Freshdesk ID)"
          />
          {error && <Alert severity="error">{error}</Alert>}
          {step === "preview" && p && (
            <Alert severity="info">
              <Typography variant="subtitle2">Dry run preview</Typography>
              <Typography variant="body2">
                Archive items: {p.ArchiveItemCount ?? p.archiveItemCount ?? "—"} (
                {formatBytes(p.ArchiveTotalBytes ?? p.archiveTotalBytes)})
              </Typography>
              <Typography variant="body2">
                Primary today: {p.PrimaryItemCount ?? p.primaryItemCount ?? "—"} (
                {formatBytes(p.PrimaryTotalBytes ?? p.primaryTotalBytes)})
              </Typography>
              <Typography variant="body2">
                Projected primary size:{" "}
                {formatBytes(p.ProjectedPrimaryTotalBytes ?? p.projectedPrimaryTotalBytes)}
              </Typography>
              {(p.QuotaIssues?.length ?? p.quotaIssues?.length ?? 0) > 0 && (
                <Typography variant="body2" color="error.main">
                  {(p.QuotaIssues ?? p.quotaIssues).join(" ")}
                </Typography>
              )}
            </Alert>
          )}
          {step === "preview" && holds.length > 0 && (
            <Alert severity="warning">
              Holds detected: {holds.join(", ")}. Acknowledge before queuing the move.
              <label style={{ display: "block", marginTop: 8 }}>
                <input
                  type="checkbox"
                  checked={holdAcknowledged}
                  onChange={(e) => setHoldAcknowledged(e.target.checked)}
                />{" "}
                I acknowledge holds and want to queue the move job
              </label>
            </Alert>
          )}
          {step === "tracking" && (
            <Alert
              severity={
                jobRow?.Status === "Failed" || jobRow?.status === "Failed"
                  ? "error"
                  : jobRow?.Status === "Succeeded" || jobRow?.status === "Succeeded"
                    ? "success"
                    : "info"
              }
            >
              <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
                <Typography variant="subtitle2">Job status</Typography>
                {jobStatusQuery.isFetching && !jobRow && <CircularProgress size={16} />}
              </Stack>
              <Typography variant="body2">Job ID: {jobId ?? "—"}</Typography>
              <Typography variant="body2">
                Status: {jobRow?.Status ?? jobRow?.status ?? "Queued (waiting for worker…)"}
              </Typography>
              {(jobRow?.MovedCount != null || jobRow?.movedCount != null) && (
                <Typography variant="body2">
                  Items moved: {jobRow.MovedCount ?? jobRow.movedCount}
                </Typography>
              )}
              {(jobRow?.ArchiveItemsBefore != null || jobRow?.ArchiveItemsAfter != null) && (
                <Typography variant="body2">
                  Archive count: {jobRow.ArchiveItemsBefore ?? "—"} →{" "}
                  {jobRow.ArchiveItemsAfter ?? "—"}
                </Typography>
              )}
              {(jobRow?.PrimaryItemsBefore != null || jobRow?.PrimaryItemsAfter != null) && (
                <Typography variant="body2">
                  Primary count: {jobRow.PrimaryItemsBefore ?? "—"} →{" "}
                  {jobRow.PrimaryItemsAfter ?? "—"}
                </Typography>
              )}
              {(jobRow?.Transport ?? jobRow?.transport) && (
                <Typography variant="body2">
                  Transport: {jobRow.Transport ?? jobRow.transport}
                </Typography>
              )}
              {(jobRow?.ErrorSummary ?? jobRow?.errorSummary) && (
                <Typography variant="body2" color="error.main">
                  {jobRow.ErrorSummary ?? jobRow.errorSummary}
                </Typography>
              )}
            </Alert>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={handleClose}>Close</Button>
        {step === "form" && (
          <Button
            variant="contained"
            disabled={!ticketNumber || dryRunCall.isPending}
            onClick={handleDryRun}
          >
            Dry run
          </Button>
        )}
        {step === "preview" && (
          <Button
            variant="contained"
            color="warning"
            disabled={
              runCall.isPending ||
              (p?.QuotaIssues?.length ?? p?.quotaIssues?.length ?? 0) > 0 ||
              (holds.length > 0 && !holdAcknowledged)
            }
            onClick={handleConfirmMove}
          >
            Queue move job
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
};
