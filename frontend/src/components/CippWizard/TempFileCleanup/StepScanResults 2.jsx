import {
  Stack,
  Typography,
  Button,
  Box,
  LinearProgress,
  Alert,
  Card,
  CardContent,
} from "@mui/material";
import { useEffect, useState, useRef, useCallback } from "react";
import { ApiGetCall, ApiPostCall } from "../../../api/ApiCall";
import { getCippError } from "../../../utils/get-cipp-error";

const SCAN_TIMEOUT_MS = 30000;
const QUEUE_POLL_INTERVAL_MS = 3000;

const formatFileSize = (bytes) => {
  if (bytes === 0 || bytes === null || bytes === undefined) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const k = 1024;
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  const size = bytes / Math.pow(k, i);
  return `${size.toFixed(i > 0 ? 2 : 0)} ${units[i]}`;
};

export const StepScanResults = ({ data, onUpdate, onNext, onBack }) => {
  const [isScanning, setIsScanning] = useState(false);
  const [error, setError] = useState(null);
  const [queueId, setQueueId] = useState(null);
  const [fetchResults, setFetchResults] = useState(false);
  const scanStartedRef = useRef(false);

  const scanMutation = ApiPostCall({});

  const applyScanResults = useCallback(
    (results) => {
      setIsScanning(false);
      // Defend against null entries (an empty array can serialize to JSON null on the
      // Functions runtime, surfacing as [null] here).
      const clean = Array.isArray(results) ? results.filter(Boolean) : [];
      onUpdate({
        scanResults: clean,
        selectedFiles: clean,
      });
    },
    [onUpdate]
  );

  const queuePoll = ApiGetCall({
    url: "/api/ListCippQueue",
    data: { QueueId: queueId },
    queryKey: `TempFileScanQueue-${queueId}`,
    waiting: !!queueId && isScanning && !fetchResults,
    refetchInterval: (pollData) => {
      const status = pollData?.[0]?.Status;
      if (
        status === "Completed" ||
        status === "Failed" ||
        status === "Completed (with errors)"
      ) {
        return false;
      }
      return QUEUE_POLL_INTERVAL_MS;
    },
    refetchOnMount: true,
    refetchOnWindowFocus: false,
  });

  const resultsPoll = ApiGetCall({
    url: "/api/ListTempFileScanResults",
    data: { queueId, tenantFilter: data.tenant?.value },
    queryKey: `TempFileScanResults-${queueId}`,
    waiting: fetchResults && !!queueId,
    refetchInterval: (pollData) => {
      if (pollData?.Status === "Completed" || pollData?.Results) {
        return false;
      }
      return QUEUE_POLL_INTERVAL_MS;
    },
    refetchOnMount: true,
    refetchOnWindowFocus: false,
  });

  const startScan = () => {
    setIsScanning(true);
    setError(null);
    setQueueId(null);
    setFetchResults(false);

    scanMutation.mutate(
      {
        url: "/api/ExecTempFileScan",
        timeout: SCAN_TIMEOUT_MS,
        data: {
          tenantFilter: data.tenant?.value,
          scope: data.scope,
          siteId: data.siteId?.value,
          userId: data.userId?.value,
          filters: data.filters,
        },
      },
      {
        onSuccess: (response) => {
          const body = response?.data;
          if (body?.Queued && body?.QueueId) {
            setQueueId(body.QueueId);
            return;
          }

          const results = body?.Results || [];
          applyScanResults(results);
        },
        onError: (err) => {
          setIsScanning(false);
          const errorMsg = getCippError(err);
          const status = err?.response?.status;
          const statusText = err?.response?.statusText;
          const isTimeout =
            err?.code === "ECONNABORTED" ||
            /timeout/i.test(err?.message || "") ||
            status === 504;

          if (isTimeout) {
            setError(
              "The scan could not be started in time. Please try again."
            );
          } else if (status) {
            setError(
              `${errorMsg || "Scan failed"} (HTTP ${status}${statusText ? `: ${statusText}` : ""})`
            );
          } else {
            setError(
              errorMsg || err?.message || "Scan failed - please check your connection"
            );
          }
        },
      }
    );
  };

  useEffect(() => {
    if (!scanStartedRef.current) {
      scanStartedRef.current = true;
      startScan();
    }
  }, []);

  useEffect(() => {
    const queueStatus = queuePoll.data?.[0]?.Status;
    if (!queueStatus || !isScanning || fetchResults) return;

    if (queueStatus === "Completed") {
      setFetchResults(true);
      return;
    }

    if (queueStatus === "Failed" || queueStatus === "Completed (with errors)") {
      setIsScanning(false);
      setError("Temp file scan failed. Please try again or choose a smaller scope.");
    }
  }, [queuePoll.data, isScanning, fetchResults]);

  useEffect(() => {
    if (!fetchResults || !resultsPoll.data) return;

    const payload = resultsPoll.data;
    if (payload?.Status === "Running") return;

    if (payload?.Status === "Completed" || Array.isArray(payload?.Results)) {
      applyScanResults(payload.Results || []);
      return;
    }

    const errorMsg = getCippError({ response: { data: payload } });
    if (errorMsg) {
      setIsScanning(false);
      setError(
        typeof errorMsg === "string"
          ? errorMsg
          : "Temp file scan failed. Please try again."
      );
    }
  }, [resultsPoll.data, fetchResults, applyScanResults]);

  const totalSize =
    data.scanResults?.reduce((sum, file) => sum + (file?.size || 0), 0) || 0;
  const fileCount = data.scanResults?.length || 0;
  const queueStatus = queuePoll.data?.[0]?.Status;
  const queueProgress = queuePoll.data?.[0]?.PercentComplete;

  return (
    <Stack spacing={3}>
      <Typography variant="h6">
        {isScanning
          ? "Scanning... Large sites may take several minutes."
          : error
            ? "Scan Failed"
            : "Scan Complete"}
      </Typography>

      {isScanning && (
        <Box>
          <LinearProgress
            variant={queueProgress ? "determinate" : "indeterminate"}
            value={queueProgress || 0}
          />
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            {queueId
              ? queueStatus === "Running" || queueStatus === "Queued"
                ? "Scan running in the background..."
                : fetchResults
                  ? "Loading scan results..."
                  : "Searching for temp files..."
              : "Starting scan..."}
          </Typography>
        </Box>
      )}

      {error && (
        <Alert severity="error">
          {error}
          <Box sx={{ mt: 1 }}>
            <Button size="small" onClick={startScan}>
              Retry Scan
            </Button>
          </Box>
        </Alert>
      )}

      {!isScanning && !error && scanStartedRef.current && fileCount > 0 && (
        <Card variant="outlined">
          <CardContent>
            <Typography variant="h5">
              Found {fileCount} file{fileCount !== 1 ? "s" : ""} (
              {formatFileSize(totalSize)})
            </Typography>
            <Typography variant="body2" color="text.secondary">
              matching your criteria
            </Typography>
          </CardContent>
        </Card>
      )}

      {!isScanning && fileCount === 0 && !error && scanStartedRef.current && (
        <Alert severity="success">
          No temp files found! Your storage is clean.
        </Alert>
      )}

      <Box sx={{ display: "flex", justifyContent: "space-between", mt: 2 }}>
        <Button onClick={onBack} disabled={isScanning}>
          Back
        </Button>
        <Button
          variant="contained"
          onClick={onNext}
          disabled={isScanning || fileCount === 0}
        >
          Review Files
        </Button>
      </Box>
    </Stack>
  );
};

export default StepScanResults;
