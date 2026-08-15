import {
  Stack,
  Typography,
  Button,
  Box,
  Card,
  CardContent,
  Checkbox,
  FormControlLabel,
  Alert,
  Divider,
  CircularProgress,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  Chip,
} from "@mui/material";
import { DeleteForever, CheckCircle, Error as ErrorIcon, Warning } from "@mui/icons-material";
import { useState } from "react";
import { ApiPostCall } from "../../../api/ApiCall";
import { getCippError } from "../../../utils/get-cipp-error";

const formatFileSize = (bytes) => {
  if (bytes === 0 || bytes === null || bytes === undefined) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const k = 1024;
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  const size = bytes / Math.pow(k, i);
  return `${size.toFixed(i > 0 ? 2 : 0)} ${units[i]}`;
};

export const StepConfirmDelete = ({ data, onBack }) => {
  const [confirmed, setConfirmed] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [results, setResults] = useState(null);
  const [error, setError] = useState(null);

  // Defend against null entries (an empty array can serialize to JSON null on the Functions
  // runtime and surface here as [null]).
  const selectedFiles = (data.selectedFiles || []).filter(Boolean);

  const deleteMutation = ApiPostCall({ urlFromData: true });

  const handleDelete = () => {
    setIsDeleting(true);
    setError(null);

    const fileCount = selectedFiles.length;
    const deleteTimeoutMs = Math.min(300000, Math.max(120000, fileCount * 2000));

    deleteMutation.mutate(
      {
        url: "/api/ExecTempFileCleanup",
        timeout: deleteTimeoutMs,
        data: {
          tenantFilter: data.tenant?.value,
          files: selectedFiles.map((f) => ({
            id: f.id,
            driveId: f.driveId,
            name: f.name,
          })),
        },
      },
      {
        onSuccess: (response) => {
          setIsDeleting(false);
          setResults(response?.data);
        },
        onError: (err) => {
          setIsDeleting(false);
          setError(getCippError(err) || "Deletion failed. Please try again.");
        },
      }
    );
  };

  const selectedSize = selectedFiles.reduce((sum, f) => sum + (f?.size || 0), 0);
  const affectedSites = [...new Set(selectedFiles.map((f) => f.SiteName).filter(Boolean))];

  if (results) {
    const summary = results.Summary;
    const deleteResults = (results.Results || []).filter(Boolean);
    const failedFiles = deleteResults.filter((r) => r.status === "failed");

    return (
      <Stack spacing={3}>
        <Typography variant="h6">Cleanup Complete</Typography>

        {summary && (
          <Alert
            severity={summary.Failed > 0 ? "warning" : "success"}
            icon={summary.Failed > 0 ? <Warning /> : <CheckCircle />}
          >
            <Typography variant="body1" fontWeight="medium">
              Successfully deleted {summary.Success} of {summary.Total} files.
            </Typography>
            {summary.Failed > 0 && (
              <Typography variant="body2" sx={{ mt: 0.5 }}>
                {summary.Failed} file{summary.Failed !== 1 ? "s" : ""} could not be deleted.
              </Typography>
            )}
          </Alert>
        )}

        {error && (
          <Alert severity="error" icon={<ErrorIcon />}>
            {typeof error === "string" ? error : JSON.stringify(error)}
          </Alert>
        )}

        {failedFiles.length > 0 && (
          <Card variant="outlined">
            <CardContent>
              <Typography variant="subtitle2" color="error" gutterBottom>
                Failed Deletions
              </Typography>
              <List dense disablePadding>
                {failedFiles.slice(0, 10).map((file, idx) => (
                  <ListItem key={file.id || idx} disablePadding sx={{ py: 0.5 }}>
                    <ListItemIcon sx={{ minWidth: 32 }}>
                      <ErrorIcon fontSize="small" color="error" />
                    </ListItemIcon>
                    <ListItemText
                      primary={file.name}
                      secondary={file.message}
                      primaryTypographyProps={{ variant: "body2" }}
                      secondaryTypographyProps={{ variant: "caption" }}
                    />
                  </ListItem>
                ))}
                {failedFiles.length > 10 && (
                  <Typography variant="caption" color="text.secondary" sx={{ pl: 4 }}>
                    ... and {failedFiles.length - 10} more
                  </Typography>
                )}
              </List>
            </CardContent>
          </Card>
        )}

        <Alert severity="info">
          Deleted files can be recovered from the SharePoint/OneDrive recycle bin for 93 days.
        </Alert>
      </Stack>
    );
  }

  return (
    <Stack spacing={3}>
      <Typography variant="h6">
        Review and confirm the files to be deleted.
      </Typography>

      <Card variant="outlined">
        <CardContent>
          <Stack spacing={2}>
            <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Typography color="text.secondary">Files to delete:</Typography>
              <Chip
                label={selectedFiles.length}
                color="error"
                size="small"
                variant="outlined"
              />
            </Box>
            <Divider />
            <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Typography color="text.secondary">Total size:</Typography>
              <Typography fontWeight="medium">{formatFileSize(selectedSize)}</Typography>
            </Box>
            <Divider />
            <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Typography color="text.secondary">Affected locations:</Typography>
              <Typography fontWeight="medium">{affectedSites.length}</Typography>
            </Box>
            {affectedSites.length > 0 && affectedSites.length <= 5 && (
              <Box sx={{ pl: 2 }}>
                {affectedSites.map((site) => (
                  <Typography key={site} variant="caption" color="text.secondary" display="block">
                    {site}
                  </Typography>
                ))}
              </Box>
            )}
          </Stack>
        </CardContent>
      </Card>

      <Alert severity="warning" icon={<Warning />}>
        This action will move the selected files to the recycle bin. This cannot be undone from
        Manage365, but files can be restored manually from SharePoint/OneDrive for 93 days.
      </Alert>

      <FormControlLabel
        control={
          <Checkbox
            checked={confirmed}
            onChange={(e) => setConfirmed(e.target.checked)}
            color="error"
            disabled={isDeleting}
          />
        }
        label={
          <Typography variant="body2">
            I understand these {selectedFiles.length} files will be moved to the recycle bin
          </Typography>
        }
      />

      {error && (
        <Alert severity="error" icon={<ErrorIcon />}>
          {typeof error === "string" ? error : JSON.stringify(error)}
        </Alert>
      )}

      <Box sx={{ display: "flex", justifyContent: "space-between", mt: 2 }}>
        <Button onClick={onBack} disabled={isDeleting}>
          Back
        </Button>
        <Button
          variant="contained"
          color="error"
          onClick={handleDelete}
          disabled={!confirmed || isDeleting}
          startIcon={isDeleting ? <CircularProgress size={16} color="inherit" /> : <DeleteForever />}
        >
          {isDeleting ? "Deleting..." : "Delete Selected Files"}
        </Button>
      </Box>
    </Stack>
  );
};

export default StepConfirmDelete;
