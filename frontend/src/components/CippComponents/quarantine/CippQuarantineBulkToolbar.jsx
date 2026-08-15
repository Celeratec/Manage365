import { Alert, Button, Stack, Typography } from "@mui/material";
import { Block, Delete, Done, DoneAll, FileDownload, Report } from "@mui/icons-material";
import { QUARANTINE_ACTION_WARNINGS } from "./quarantineConstants";

const confirmBulkAction = (count, actionLabel) => {
  if (count > 50) {
    return window.confirm(
      `WARNING: You are about to ${actionLabel} ${count} messages. This may take a while and could have significant impact. Continue?`
    );
  }
  if (count > 10) {
    return window.confirm(`You are about to ${actionLabel} ${count} messages. Are you sure?`);
  }
  return window.confirm(`${actionLabel} ${count} selected message(s)?`);
};

const CippQuarantineBulkToolbar = ({
  selectedRows = [],
  onRelease,
  onDeny,
  onReleaseAllow,
  onDelete,
  onSubmitToMicrosoft,
  onBlockSenders,
  onExportSelected,
  isProcessing = false,
}) => {
  if (!selectedRows.length) return null;

  const count = selectedRows.length;

  const handle = (callback, label, warning) => {
    if (!confirmBulkAction(count, label)) return;
    if (warning && !window.confirm(warning)) return;
    callback?.(selectedRows);
  };

  return (
    <Stack spacing={1} sx={{ py: 1 }}>
      <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
        <Typography variant="body2" color="text.secondary">
          {count} selected:
        </Typography>
        <Button
          size="small"
          variant="contained"
          startIcon={<Done />}
          disabled={isProcessing}
          onClick={() => handle(onRelease, "release", QUARANTINE_ACTION_WARNINGS.release)}
        >
          Bulk Release
        </Button>
        <Button
          size="small"
          variant="outlined"
          startIcon={<Block />}
          disabled={isProcessing}
          onClick={() => handle(onDeny, "deny")}
        >
          Bulk Deny
        </Button>
        <Button
          size="small"
          variant="outlined"
          startIcon={<DoneAll />}
          disabled={isProcessing}
          onClick={() =>
            handle(onReleaseAllow, "release and allow", QUARANTINE_ACTION_WARNINGS.allowSender)
          }
        >
          Release & Allow
        </Button>
        <Button
          size="small"
          variant="outlined"
          color="error"
          startIcon={<Delete />}
          disabled={isProcessing}
          onClick={() => handle(onDelete, "delete", QUARANTINE_ACTION_WARNINGS.delete)}
        >
          Bulk Delete
        </Button>
        <Button
          size="small"
          variant="outlined"
          startIcon={<Report />}
          disabled={isProcessing}
          onClick={() =>
            handle(
              onSubmitToMicrosoft,
              "submit to Microsoft",
              QUARANTINE_ACTION_WARNINGS.submitToMicrosoft
            )
          }
        >
          Submit to Microsoft
        </Button>
        <Button
          size="small"
          variant="outlined"
          startIcon={<Block />}
          disabled={isProcessing}
          onClick={() => onBlockSenders?.(selectedRows)}
        >
          Block Senders
        </Button>
        <Button
          size="small"
          variant="outlined"
          startIcon={<FileDownload />}
          disabled={isProcessing}
          onClick={() => onExportSelected?.(selectedRows)}
        >
          Export Selected
        </Button>
      </Stack>
      <Alert severity="warning" sx={{ py: 0.5 }}>
        Bulk actions affect {count} quarantined message(s). Review selections carefully before
        proceeding.
      </Alert>
    </Stack>
  );
};

export default CippQuarantineBulkToolbar;
