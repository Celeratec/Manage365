import { useState, useEffect, useCallback } from "react";
import {
  Box,
  Typography,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  IconButton,
  Tooltip,
  Chip,
  Stack,
  Button,
  Alert,
  CircularProgress,
  Collapse,
  alpha,
} from "@mui/material";
import { useTheme } from "@mui/material/styles";
import {
  ContentCopy,
  Check,
  Error as ErrorIcon,
  Refresh,
  Download,
  Visibility,
  VisibilityOff,
  CheckCircle,
  Cancel,
} from "@mui/icons-material";
import { ApiGetCall } from "../../api/ApiCall";

const CopyButton = ({ value, label }) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    if (!value) return;
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error("Failed to copy:", err);
    }
  };

  return (
    <Tooltip title={copied ? "Copied!" : `Copy ${label}`}>
      <IconButton size="small" onClick={handleCopy} disabled={!value}>
        {copied ? <Check color="success" fontSize="small" /> : <ContentCopy fontSize="small" />}
      </IconButton>
    </Tooltip>
  );
};

const SecretCell = ({ secret }) => {
  const [visible, setVisible] = useState(false);

  if (!secret) {
    return <Typography variant="body2" color="text.secondary">-</Typography>;
  }

  return (
    <Stack direction="row" alignItems="center" spacing={1}>
      <Typography
        variant="body2"
        sx={{
          fontFamily: "monospace",
          fontSize: "0.8rem",
          maxWidth: 200,
          overflow: "hidden",
          textOverflow: "ellipsis",
        }}
      >
        {visible ? secret : "••••••••••••••••"}
      </Typography>
      <Tooltip title={visible ? "Hide" : "Show"}>
        <IconButton size="small" onClick={() => setVisible(!visible)}>
          {visible ? <VisibilityOff fontSize="small" /> : <Visibility fontSize="small" />}
        </IconButton>
      </Tooltip>
      <CopyButton value={secret} label="secret" />
    </Stack>
  );
};

export const CippDeploymentResults = ({ deploymentId, onComplete }) => {
  const theme = useTheme();
  const [pollInterval, setPollInterval] = useState(2000);

  const deploymentQuery = ApiGetCall({
    url: "/api/ListIntegrationDeployments",
    data: { deploymentId },
    queryKey: ["IntegrationDeployment", deploymentId],
    refetchInterval: (data) => {
      if (data?.status === "Complete") {
        return false;
      }
      return pollInterval;
    },
  });

  const isComplete = deploymentQuery.data?.status === "Complete";
  const results = deploymentQuery.data?.results || [];
  const successCount = deploymentQuery.data?.successCount || 0;
  const failedCount = deploymentQuery.data?.failedCount || 0;

  useEffect(() => {
    if (isComplete && onComplete) {
      onComplete(deploymentQuery.data);
    }
  }, [isComplete, onComplete, deploymentQuery.data]);

  const handleExportCSV = () => {
    const csvContent = [
      ["Tenant", "App Name", "Application ID", "Tenant ID", "Client Secret", "Secret Expiration", "Status"],
      ...results.map((r) => [
        r.displayName || r.tenantName,
        r.appName || "",
        r.appId || "",
        r.tenantId || "",
        r.clientSecret || "",
        r.secretExpiration || "",
        r.status,
      ]),
    ]
      .map((row) => row.map((cell) => `"${(cell || "").replace(/"/g, '""')}"`).join(","))
      .join("\n");

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `integration-deployment-${deploymentId}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const handleCopyAll = async () => {
    const text = results
      .filter((r) => r.status === "Success")
      .map(
        (r) =>
          `Tenant: ${r.displayName || r.tenantName}\nApplication ID: ${r.appId}\nTenant ID: ${r.tenantId}\nClient Secret: ${r.clientSecret}\n`
      )
      .join("\n---\n\n");

    try {
      await navigator.clipboard.writeText(text);
    } catch (err) {
      console.error("Failed to copy:", err);
    }
  };

  if (deploymentQuery.isLoading && !deploymentQuery.data) {
    return (
      <Box sx={{ textAlign: "center", py: 4 }}>
        <CircularProgress />
        <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
          Loading deployment status...
        </Typography>
      </Box>
    );
  }

  if (deploymentQuery.isError) {
    return (
      <Alert severity="error">
        Failed to load deployment status: {deploymentQuery.error?.message || "Unknown error"}
      </Alert>
    );
  }

  return (
    <Stack spacing={3}>
      <Box sx={{ textAlign: "center" }}>
        <Box
          sx={{
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            width: 72,
            height: 72,
            borderRadius: "50%",
            bgcolor: isComplete
              ? alpha(theme.palette.success.main, 0.1)
              : alpha(theme.palette.info.main, 0.1),
            color: isComplete ? "success.main" : "info.main",
            mb: 1.5,
            border: `2px solid ${
              isComplete
                ? alpha(theme.palette.success.main, 0.2)
                : alpha(theme.palette.info.main, 0.2)
            }`,
          }}
        >
          {isComplete ? (
            <CheckCircle sx={{ fontSize: 36 }} />
          ) : (
            <CircularProgress size={36} color="inherit" />
          )}
        </Box>
        <Typography variant="h5" fontWeight={600} gutterBottom>
          {isComplete ? "Deployment Complete" : "Deployment In Progress"}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {isComplete
            ? `${successCount} succeeded, ${failedCount} failed`
            : `Processing ${deploymentQuery.data?.completedCount || 0} of ${deploymentQuery.data?.totalCount || 0} tenants...`}
        </Typography>
      </Box>

      {isComplete && successCount > 0 && (
        <Alert severity="warning" sx={{ mx: "auto", maxWidth: 600 }}>
          <strong>Important:</strong> Client secrets are shown only once. Copy them now or export to
          CSV before leaving this page.
        </Alert>
      )}

      {results.length > 0 && (
        <>
          <Stack direction="row" spacing={2} justifyContent="flex-end">
            <Button
              variant="outlined"
              size="small"
              startIcon={<ContentCopy />}
              onClick={handleCopyAll}
              disabled={successCount === 0}
            >
              Copy All Credentials
            </Button>
            <Button
              variant="outlined"
              size="small"
              startIcon={<Download />}
              onClick={handleExportCSV}
            >
              Export CSV
            </Button>
          </Stack>

          <TableContainer component={Paper} variant="outlined">
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Tenant</TableCell>
                  <TableCell>App Name</TableCell>
                  <TableCell>Application (Client) ID</TableCell>
                  <TableCell>Directory (Tenant) ID</TableCell>
                  <TableCell>Client Secret</TableCell>
                  <TableCell>Status</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {results.map((result, index) => (
                  <TableRow key={index}>
                    <TableCell>
                      <Typography variant="body2" fontWeight={500}>
                        {result.displayName || result.tenantName}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2">{result.appName || "-"}</Typography>
                    </TableCell>
                    <TableCell>
                      {result.appId ? (
                        <Stack direction="row" alignItems="center" spacing={0.5}>
                          <Typography
                            variant="body2"
                            sx={{ fontFamily: "monospace", fontSize: "0.8rem" }}
                          >
                            {result.appId}
                          </Typography>
                          <CopyButton value={result.appId} label="App ID" />
                        </Stack>
                      ) : (
                        "-"
                      )}
                    </TableCell>
                    <TableCell>
                      {result.tenantId ? (
                        <Stack direction="row" alignItems="center" spacing={0.5}>
                          <Typography
                            variant="body2"
                            sx={{ fontFamily: "monospace", fontSize: "0.8rem" }}
                          >
                            {result.tenantId}
                          </Typography>
                          <CopyButton value={result.tenantId} label="Tenant ID" />
                        </Stack>
                      ) : (
                        "-"
                      )}
                    </TableCell>
                    <TableCell>
                      <SecretCell secret={result.clientSecret} />
                    </TableCell>
                    <TableCell>
                      <Chip
                        icon={
                          result.status === "Success" ? (
                            <CheckCircle fontSize="small" />
                          ) : (
                            <Cancel fontSize="small" />
                          )
                        }
                        label={result.status}
                        size="small"
                        color={result.status === "Success" ? "success" : "error"}
                        variant="outlined"
                      />
                      {result.status === "Failed" && result.message && (
                        <Typography
                          variant="caption"
                          color="error"
                          sx={{ display: "block", mt: 0.5 }}
                        >
                          {result.message}
                        </Typography>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </>
      )}
    </Stack>
  );
};

export default CippDeploymentResults;
