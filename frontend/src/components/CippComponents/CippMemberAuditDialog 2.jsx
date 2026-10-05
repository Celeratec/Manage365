import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  LinearProgress,
  Stack,
  Typography,
} from "@mui/material";
import {
  CheckCircle,
  WarningAmber,
  Info,
  Build,
  Refresh,
  AutoFixHigh,
} from "@mui/icons-material";
import { useState, useEffect, useCallback, useRef } from "react";
import axios from "axios";
import { useQueryClient } from "@tanstack/react-query";
import { buildVersionedHeaders } from "../../utils/cippVersion";

const ISSUE_META = {
  NOT_SYNCED: {
    label: "Not Synced",
    color: "warning",
    fixLabel: "Sync to SharePoint",
  },
  ORPHANED: {
    label: "Not in Group",
    color: "info",
    fixLabel: "Add to Group",
  },
  DRIVE_ONLY: {
    label: "Drive-Only Access",
    color: "warning",
    fixLabel: "Promote to Member",
  },
  NO_ROLE: {
    label: "No Permissions",
    color: "info",
    fixLabel: "Assign Role",
  },
};

export default function CippMemberAuditDialog({
  open,
  onClose,
  tenantFilter,
  siteId,
  siteUrl,
  groupId,
  sharePointType,
  relatedQueryKeys = [],
}) {
  const queryClient = useQueryClient();
  const [loading, setLoading] = useState(false);
  const [auditResult, setAuditResult] = useState(null);
  const [repairingIndex, setRepairingIndex] = useState(null);
  const [repairingAll, setRepairingAll] = useState(false);
  const [repairMessages, setRepairMessages] = useState({});
  const [error, setError] = useState(null);
  const pendingTimerRef = useRef(null);

  const invalidateRelated = useCallback(() => {
    relatedQueryKeys.forEach((key) => {
      queryClient.invalidateQueries({ queryKey: [key] });
    });
  }, [queryClient, relatedQueryKeys]);

  const runAudit = useCallback(async () => {
    if (!tenantFilter || !siteId) return;
    setLoading(true);
    setAuditResult(null);
    setError(null);
    setRepairMessages({});
    setRepairingIndex(null);
    setRepairingAll(false);

    try {
      const headers = await buildVersionedHeaders();
      const resp = await axios.post(
        "/api/ExecSharePointMemberAudit",
        {
          tenantFilter,
          siteId,
          siteUrl,
          groupId,
          sharePointType,
          action: "audit",
        },
        { headers, timeout: 60000 }
      );
      const data = resp.data?.Results;
      if (data?.error) {
        setError(data.error);
      } else {
        setAuditResult(data);
      }
    } catch (err) {
      setError(
        err.response?.data?.Results?.error ||
          err.message ||
          "Audit request failed."
      );
    } finally {
      setLoading(false);
    }
  }, [tenantFilter, siteId, siteUrl, groupId, sharePointType]);

  useEffect(() => {
    if (open) {
      runAudit();
    } else {
      if (pendingTimerRef.current) {
        clearTimeout(pendingTimerRef.current);
        pendingTimerRef.current = null;
      }
      setAuditResult(null);
      setError(null);
      setRepairMessages({});
      setRepairingAll(false);
    }
  }, [open, runAudit]);

  const repairSingle = async (issue, index) => {
    setRepairingIndex(index);
    setRepairMessages((prev) => ({ ...prev, [index]: null }));

    try {
      const headers = await buildVersionedHeaders();
      const resp = await axios.post(
        "/api/ExecSharePointMemberAudit",
        {
          tenantFilter,
          siteId,
          siteUrl,
          groupId,
          sharePointType,
          action: "repair",
          repairType: issue.repairAction,
          userEmail: issue.userEmail,
          userId: issue.userId,
          drivePermissionId: issue.drivePermissionId,
        },
        { headers, timeout: 60000 }
      );
      const results = resp.data?.Results?.results || [];
      setRepairMessages((prev) => ({
        ...prev,
        [index]: { success: true, text: results.join(" ") || "Fixed." },
      }));
      invalidateRelated();
    } catch (err) {
      const msg =
        err.response?.data?.Results?.error || err.message || "Repair failed.";
      setRepairMessages((prev) => ({
        ...prev,
        [index]: { success: false, text: msg },
      }));
    } finally {
      setRepairingIndex(null);
    }
  };

  const repairAll = async () => {
    if (!auditResult?.issues?.length) return;
    setRepairingAll(true);
    setRepairMessages({});

    try {
      const headers = await buildVersionedHeaders();
      const resp = await axios.post(
        "/api/ExecSharePointMemberAudit",
        {
          tenantFilter,
          siteId,
          siteUrl,
          groupId,
          sharePointType,
          action: "repair",
          repairType: "repair_all",
          userEmail: "_all",
          issues: auditResult.issues,
        },
        { headers, timeout: 120000 }
      );
      const results = resp.data?.Results?.results || [];
      setRepairMessages({
        all: {
          success: true,
          text: results.join(" ") || "All issues repaired.",
        },
      });
      invalidateRelated();
      pendingTimerRef.current = setTimeout(() => {
        pendingTimerRef.current = null;
        runAudit();
      }, 1500);
    } catch (err) {
      const msg =
        err.response?.data?.Results?.error ||
        err.message ||
        "Repair all failed.";
      setRepairMessages({ all: { success: false, text: msg } });
      setRepairingAll(false);
    }
  };

  const issues = auditResult?.issues || [];
  const hasIssues = issues.length > 0;

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle sx={{ pb: 1 }}>
        <Stack direction="row" alignItems="center" spacing={1}>
          <Build sx={{ fontSize: 20 }} />
          <Typography variant="h6">Member Audit</Typography>
        </Stack>
        <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
          Checks for members with incorrect or incomplete permissions and offers
          repairs.
        </Typography>
      </DialogTitle>

      <DialogContent dividers>
        {loading && (
          <Box sx={{ py: 3, textAlign: "center" }}>
            <LinearProgress sx={{ mb: 2 }} />
            <Typography variant="body2" color="text.secondary">
              Auditing site membership...
            </Typography>
          </Box>
        )}

        {error && !loading && (
          <Alert severity="error" sx={{ mb: 1 }}>
            {error}
          </Alert>
        )}

        {auditResult && !loading && (
          <>
            {!hasIssues && (
              <Alert
                severity="success"
                icon={<CheckCircle />}
                sx={{ mb: 1 }}
              >
                All members have correct permissions. No issues detected.
              </Alert>
            )}

            {hasIssues && (
              <Stack spacing={1.5}>
                <Stack
                  direction="row"
                  alignItems="center"
                  justifyContent="space-between"
                >
                  <Typography variant="body2" color="text.secondary">
                    Found{" "}
                    <strong>
                      {issues.length} issue{issues.length !== 1 ? "s" : ""}
                    </strong>{" "}
                    ({auditResult.siteType} site)
                  </Typography>
                  {issues.length > 1 && (
                    <Button
                      size="small"
                      variant="contained"
                      startIcon={
                        repairingAll ? (
                          <CircularProgress size={14} color="inherit" />
                        ) : (
                          <AutoFixHigh />
                        )
                      }
                      onClick={repairAll}
                      disabled={repairingAll || repairingIndex !== null}
                    >
                      Fix All
                    </Button>
                  )}
                </Stack>

                {repairMessages.all && (
                  <Alert
                    severity={
                      repairMessages.all.success ? "success" : "error"
                    }
                    variant="outlined"
                    sx={{ py: 0.5 }}
                  >
                    <Typography variant="body2">
                      {repairMessages.all.text}
                    </Typography>
                  </Alert>
                )}

                <Divider />

                {issues.map((issue, idx) => {
                  const meta = ISSUE_META[issue.type] || {
                    label: issue.type,
                    color: "default",
                    fixLabel: "Fix",
                  };
                  const msg = repairMessages[idx];

                  return (
                    <Box key={idx}>
                      <Stack
                        direction="row"
                        alignItems="flex-start"
                        justifyContent="space-between"
                        spacing={1}
                      >
                        <Box sx={{ flex: 1, minWidth: 0 }}>
                          <Stack
                            direction="row"
                            alignItems="center"
                            spacing={1}
                            sx={{ mb: 0.5 }}
                          >
                            {issue.severity === "warning" ? (
                              <WarningAmber
                                sx={{ fontSize: 16 }}
                                color="warning"
                              />
                            ) : (
                              <Info sx={{ fontSize: 16 }} color="info" />
                            )}
                            <Typography
                              variant="body2"
                              sx={{ fontWeight: 600 }}
                              noWrap
                            >
                              {issue.userName || issue.userEmail}
                            </Typography>
                            <Chip
                              label={meta.label}
                              size="small"
                              color={meta.color}
                              variant="outlined"
                              sx={{
                                height: 20,
                                fontSize: "0.7rem",
                                "& .MuiChip-label": { px: 0.5 },
                              }}
                            />
                          </Stack>
                          <Typography
                            variant="caption"
                            color="text.secondary"
                            sx={{ display: "block", mb: 0.25 }}
                          >
                            {issue.userEmail}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {issue.description}
                          </Typography>
                        </Box>

                        <Button
                          size="small"
                          variant="outlined"
                          onClick={() => repairSingle(issue, idx)}
                          disabled={
                            repairingAll ||
                            repairingIndex !== null ||
                            msg?.success === true
                          }
                          startIcon={
                            repairingIndex === idx ? (
                              <CircularProgress size={14} />
                            ) : msg?.success ? (
                              <CheckCircle />
                            ) : undefined
                          }
                          color={msg?.success ? "success" : "primary"}
                          sx={{
                            minWidth: "auto",
                            whiteSpace: "nowrap",
                            mt: 0.5,
                          }}
                        >
                          {msg?.success ? "Done" : meta.fixLabel}
                        </Button>
                      </Stack>

                      {msg && !msg.success && (
                        <Alert
                          severity="error"
                          variant="outlined"
                          sx={{ mt: 0.5, py: 0 }}
                        >
                          <Typography variant="caption">{msg.text}</Typography>
                        </Alert>
                      )}

                      {idx < issues.length - 1 && <Divider sx={{ mt: 1 }} />}
                    </Box>
                  );
                })}
              </Stack>
            )}
          </>
        )}
      </DialogContent>

      <DialogActions sx={{ px: 2, py: 1.5 }}>
        <Button
          size="small"
          startIcon={<Refresh />}
          onClick={runAudit}
          disabled={loading}
        >
          Re-Audit
        </Button>
        <Box sx={{ flex: 1 }} />
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
}
