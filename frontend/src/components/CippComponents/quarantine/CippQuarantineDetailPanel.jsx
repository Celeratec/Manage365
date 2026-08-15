import { useEffect, useState } from "react";
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Divider,
  Paper,
  Stack,
  Typography,
} from "@mui/material";
import { ContentCopy, Email, Security } from "@mui/icons-material";
import { ApiGetCall } from "../../../api/ApiCall";
import { getCippFormatting } from "../../../utils/get-cipp-formatting";
import {
  getQuarantineReasonLabel,
  getReleaseStatusLabel,
  getSenderDisplay,
  QUARANTINE_ACTION_WARNINGS,
  RELEASE_STATUS_COLOR_MAP,
} from "./quarantineConstants";

const DetailRow = ({ label, value }) => {
  if (!value) return null;
  return (
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={2}>
      <Typography variant="body2" color="text.secondary" sx={{ minWidth: 140 }}>
        {label}
      </Typography>
      <Typography variant="body2" sx={{ fontWeight: 500, textAlign: "right", wordBreak: "break-word" }}>
        {value}
      </Typography>
    </Stack>
  );
};

const AuthSummaryChips = ({ summary }) => {
  if (!summary) return null;
  const items = [
    { label: "SPF", result: summary.SPF?.result },
    { label: "DKIM", result: summary.DKIM?.result },
    { label: "DMARC", result: summary.DMARC?.result },
    { label: "CompAuth", result: summary.CompAuth?.result },
  ].filter((item) => item.result && item.result !== "Unknown");
  if (!items.length) return null;

  return (
    <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
      {items.map((item) => (
        <Chip key={item.label} label={`${item.label}: ${item.result}`} size="small" variant="outlined" />
      ))}
    </Stack>
  );
};

const CippQuarantineDetailPanel = ({ row, tenantFilter, onPreview, onRunTrace }) => {
  const [detail, setDetail] = useState(row);
  const identity = row?.Identity;

  const detailApi = ApiGetCall({
    url: "/api/GetMailQuarantineMessage",
    data: { tenantFilter, Identity: identity },
    waiting: !!identity && !!tenantFilter,
    queryKey: `GetMailQuarantineMessage-${identity}`,
  });

  useEffect(() => {
    if (!detailApi.isSuccess) {
      setDetail(row);
      return;
    }

    const results = detailApi.data?.Results;
    if (results && typeof results === "object" && !Array.isArray(results)) {
      setDetail({ ...row, ...results });
    } else if (typeof results === "string" && results.trim()) {
      setDetail(row);
    } else {
      setDetail(row);
    }
  }, [detailApi.isSuccess, detailApi.data, row]);

  if (!row) {
    return (
      <Typography variant="body2" color="text.secondary">
        Select a quarantined message to view details.
      </Typography>
    );
  }

  const status = detail?.ReleaseStatus;
  const statusColor = RELEASE_STATUS_COLOR_MAP[status] || "default";

  return (
    <Stack spacing={2}>
      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
          <Email fontSize="small" color="action" />
          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
            {detail?.Subject || "No Subject"}
          </Typography>
        </Stack>
        <Chip
          label={getReleaseStatusLabel(status)}
          color={statusColor}
          size="small"
          sx={{ mb: 1 }}
        />
        <Typography variant="body2" color="text.secondary">
          {getSenderDisplay(detail)} → {detail?.RecipientAddress}
        </Typography>
      </Paper>

      {detailApi.isFetching && (
        <Stack direction="row" spacing={1} alignItems="center">
          <CircularProgress size={18} />
          <Typography variant="body2">Loading message metadata...</Typography>
        </Stack>
      )}

      {detailApi.isError && (
        <Alert severity="warning">
          Could not load extended metadata. Showing list data only.
        </Alert>
      )}

      {detailApi.isSuccess &&
        typeof detailApi.data?.Results === "string" &&
        detailApi.data.Results.trim() && (
          <Alert severity="warning">{detailApi.data.Results}</Alert>
        )}

      <Box>
        <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1 }}>
          Message Details
        </Typography>
        <Stack spacing={1}>
          <DetailRow label="Sender" value={getSenderDisplay(detail)} />
          <DetailRow label="Sender Address" value={detail?.SenderAddress} />
          <DetailRow label="Recipient" value={detail?.RecipientAddress} />
          <DetailRow
            label="Time Received"
            value={getCippFormatting(detail?.ReceivedTime, "ReceivedTime")}
          />
          <DetailRow label="Quarantine Reason" value={getQuarantineReasonLabel(detail)} />
          <DetailRow label="Policy Type" value={detail?.PolicyType} />
          <DetailRow label="Policy Name" value={detail?.PolicyName} />
          <DetailRow label="Release Status" value={getReleaseStatusLabel(status)} />
          <DetailRow label="Expiration" value={getCippFormatting(detail?.Expires, "Expires")} />
          <DetailRow label="Released By" value={detail?.ReleasedBy} />
          <DetailRow
            label="Released Time"
            value={getCippFormatting(detail?.ReleasedTime, "ReleasedTime")}
          />
          <DetailRow label="Message ID" value={detail?.MessageId} />
          <DetailRow label="Identity" value={detail?.Identity} />
        </Stack>
      </Box>

      {detailApi.data?.AuthSummary && (
        <>
          <Divider />
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1 }}>
              Authentication Results
            </Typography>
            <AuthSummaryChips summary={detailApi.data.AuthSummary} />
          </Box>
        </>
      )}

      <Alert severity="info" icon={<Security fontSize="small" />}>
        Sending IP, URL reputation, and attachment sandbox details are available via message trace
        and EML preview when exposed by Exchange Online. They are not returned in the quarantine
        list API.
      </Alert>

      <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
        {onPreview && (
          <Button size="small" variant="contained" onClick={() => onPreview(detail)}>
            Preview Message
          </Button>
        )}
        {onRunTrace && detail?.MessageId && (
          <Button size="small" variant="outlined" onClick={() => onRunTrace(detail)}>
            View Message Trace
          </Button>
        )}
        <Button
          size="small"
          variant="outlined"
          startIcon={<ContentCopy />}
          onClick={() => navigator.clipboard.writeText(detail?.MessageId || detail?.Identity || "")}
        >
          Copy Metadata
        </Button>
      </Stack>

      <Typography variant="caption" color="text.secondary">
        {QUARANTINE_ACTION_WARNINGS.release}
      </Typography>
    </Stack>
  );
};

export default CippQuarantineDetailPanel;
