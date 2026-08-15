import { useMemo, useCallback, useState } from "react";
import { useRouter } from "next/router";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { useSettings } from "../../../../hooks/use-settings";
import { ApiGetCall, ApiPostCall } from "../../../../api/ApiCall";
import { useDialog } from "../../../../hooks/use-dialog";
import { CippApiDialog } from "../../../../components/CippComponents/CippApiDialog";
import {
  Avatar,
  Button,
  Checkbox,
  Chip,
  CircularProgress,
  Collapse,
  Container,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControlLabel,
  IconButton,
  Paper,
  Tooltip,
  Typography,
  Alert,
  AlertTitle,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Grid, Stack } from "@mui/system";
import {
  ArrowBack,
  Phone,
  Phone as PhoneIcon,
  Person,
  PersonAdd,
  PersonRemove,
  LocationOn,
  CheckCircle,
  Warning,
  SyncAlt,
  Speed,
  Shield,
  ErrorOutline,
  Build,
  OpenInNew,
  Replay,
  ExpandMore,
  ExpandLess,
  Code,
} from "@mui/icons-material";
import Link from "next/link";
import CippFormComponent from "../../../../components/CippComponents/CippFormComponent";
import { useForm } from "react-hook-form";
import { useQueryClient } from "@tanstack/react-query";

const formatCapability = (cap) =>
  cap.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2");

const formatNumberType = (value) => {
  if (!value || typeof value !== "string") return value;
  return value.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2");
};

const parseCapabilities = (value) => {
  if (!value) return [];
  if (Array.isArray(value)) return value.map(formatCapability);
  if (typeof value !== "string") return [String(value)];
  if (value.includes(",")) return value.split(",").map((s) => formatCapability(s.trim())).filter(Boolean);
  const known = [
    "FirstPartyAppAssignment", "Geographic", "InboundCalling", "Office365",
    "OutboundCalling", "SharedCalling", "AzureConferenceAssignment",
    "InboundA2PSms", "OutboundA2PSms", "ThirdPartyAppAssignment",
    "UserAssignment", "ConferenceAssignment", "VoiceAppAssignment", "PrivateLineAssignment",
  ];
  const caps = [];
  let remaining = value;
  while (remaining.length > 0) {
    let matched = false;
    for (const cap of known) {
      if (remaining.startsWith(cap)) {
        caps.push(formatCapability(cap));
        remaining = remaining.slice(cap.length);
        matched = true;
        break;
      }
    }
    if (!matched) {
      const match = remaining.match(/^([A-Z][a-z]+(?:[A-Z][a-z]+)*)/);
      if (match) {
        caps.push(formatCapability(match[1]));
        remaining = remaining.slice(match[1].length);
      } else {
        caps.push(remaining);
        break;
      }
    }
  }
  return caps;
};

const getAssignedToDisplay = (value) => {
  if (!value) return "";
  if (typeof value === "string") return value;
  if (typeof value === "object") {
    return value.displayName || value.userPrincipalName || value.id || "";
  }
  return String(value);
};

const InfoRow = ({ label, value, mono = false }) => {
  if (!value) return null;
  return (
    <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ py: 0.5 }}>
      <Typography variant="body2" color="text.secondary">
        {label}
      </Typography>
      <Typography
        variant="body2"
        sx={{
          fontWeight: 500,
          fontFamily: mono ? "monospace" : "inherit",
          fontSize: mono ? "0.8rem" : "inherit",
          maxWidth: "60%",
          textAlign: "right",
          wordBreak: "break-all",
        }}
      >
        {value}
      </Typography>
    </Stack>
  );
};

const StatBox = ({ label, value, color = "primary" }) => (
  <Box sx={{ textAlign: "center", flex: 1, py: 1.5 }}>
    <Typography variant="h6" sx={{ fontWeight: 700, color: `${color}.main` }}>
      {value ?? "—"}
    </Typography>
    <Typography variant="caption" color="text.secondary">
      {label}
    </Typography>
  </Box>
);

const severityMap = {
  error: "error",
  warning: "warning",
  info: "info",
  success: "success",
};

const riskColorMap = {
  high: "error",
  medium: "warning",
  low: "info",
};

/**
 * Renders the diagnostics panel when the backend returns a Diagnostics array.
 * Shows structured root cause findings with risk-gated quick-fix buttons.
 * Includes a collapsible "Technical Details" section with the raw error.
 */
const DiagnosticsPanel = ({
  diagnostics,
  rawError,
  onQuickFix,
  quickFixStatus,
  quickFixMessage,
  tenantInfo,
}) => {
  const [riskAcknowledged, setRiskAcknowledged] = useState({});
  const [showTechnical, setShowTechnical] = useState(false);

  if (!diagnostics || diagnostics.length === 0) return null;

  const buildDelegatedUrl = (baseUrl) => {
    if (!baseUrl || typeof baseUrl !== "string") return baseUrl;
    if (!baseUrl.startsWith("http")) return baseUrl;
    const initialDomain = tenantInfo?.addedFields?.initialDomainName;
    if (!initialDomain) return baseUrl;
    const separator = baseUrl.includes("?") ? "&" : "?";
    return `${baseUrl}${separator}delegatedOrg=${initialDomain}`;
  };

  return (
    <Stack spacing={1.5} sx={{ mt: 1 }}>
      <Stack direction="row" spacing={1} alignItems="center">
        <Build sx={{ fontSize: 18, color: "text.secondary" }} />
        <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
          Root Cause Analysis
        </Typography>
      </Stack>

      {diagnostics.map((diag, idx) => (
        <Paper
          key={idx}
          variant="outlined"
          sx={{
            p: 2,
            borderRadius: 1.5,
            borderLeft: (theme) =>
              `3px solid ${theme.palette[severityMap[diag.severity] || "info"].main}`,
          }}
        >
          <Stack spacing={1.5}>
            <Stack direction="row" spacing={1} alignItems="center">
              <Chip
                label={diag.source}
                size="small"
                color={severityMap[diag.severity] || "info"}
                variant="outlined"
                sx={{ fontWeight: 600, fontSize: "0.7rem" }}
              />
            </Stack>

            <Typography variant="body2" sx={{ fontWeight: 600 }}>
              {diag.issue}
            </Typography>

            <Typography variant="body2" color="text.secondary">
              {diag.detail}
            </Typography>

            {/* Structured capability display */}
            {(diag.acquiredCapabilities?.length > 0 || diag.availableCapabilities?.length > 0) && (
              <Paper
                variant="outlined"
                sx={{
                  p: 1.5,
                  borderRadius: 1,
                  bgcolor: (theme) => alpha(theme.palette.background.default, 0.5),
                }}
              >
                <Stack spacing={1.5}>
                  {diag.numberType && (
                    <Stack direction="row" spacing={1} alignItems="center">
                      <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, minWidth: 80 }}>
                        Number Type
                      </Typography>
                      <Chip label={formatNumberType(diag.numberType)} size="small" variant="outlined" />
                    </Stack>
                  )}
                  {diag.acquiredCapabilities?.length > 0 && (
                    <Box>
                      <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, display: "block", mb: 0.5 }}>
                        Acquired Capabilities
                      </Typography>
                      <Stack direction="row" flexWrap="wrap" useFlexGap spacing={0.5}>
                        {diag.acquiredCapabilities.map((cap, ci) => (
                          <Chip
                            key={ci}
                            label={formatCapability(cap)}
                            size="small"
                            color="success"
                            variant="outlined"
                            sx={{ fontSize: "0.7rem" }}
                          />
                        ))}
                      </Stack>
                    </Box>
                  )}
                  {diag.acquiredCapabilities?.length === 0 && (
                    <Box>
                      <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, display: "block", mb: 0.5 }}>
                        Acquired Capabilities
                      </Typography>
                      <Typography variant="caption" color="text.disabled">None</Typography>
                    </Box>
                  )}
                  {diag.availableCapabilities?.length > 0 && (
                    <Box>
                      <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, display: "block", mb: 0.5 }}>
                        Available Capabilities
                      </Typography>
                      <Stack direction="row" flexWrap="wrap" useFlexGap spacing={0.5}>
                        {diag.availableCapabilities.map((cap, ci) => (
                          <Chip
                            key={ci}
                            label={formatCapability(cap)}
                            size="small"
                            color={cap === "UserAssignment" ? "warning" : "default"}
                            variant="outlined"
                            sx={{
                              fontSize: "0.7rem",
                              ...(cap === "UserAssignment" && { fontWeight: 600, borderStyle: "dashed" }),
                            }}
                          />
                        ))}
                      </Stack>
                    </Box>
                  )}
                </Stack>
              </Paper>
            )}

            <Alert
              severity="info"
              variant="outlined"
              icon={false}
              sx={{ py: 0.5, "& .MuiAlert-message": { py: 0.5, width: "100%" } }}
            >
              <Typography variant="body2" sx={{ fontWeight: 500, mb: 0.5 }}>
                Recommended fix:
              </Typography>
              {/^\d\)/.test(diag.fix) ? (
                <Box
                  component="ol"
                  sx={{
                    m: 0,
                    pl: 2.5,
                    "& li": { fontSize: "0.875rem", mb: 0.25 },
                  }}
                >
                  {diag.fix
                    .split(/\d\)\s*/)
                    .filter(Boolean)
                    .map((step, si) => (
                      <li key={si}>{step.trim().replace(/\.$/, "")}</li>
                    ))}
                </Box>
              ) : (
                <Typography variant="body2">{diag.fix}</Typography>
              )}
            </Alert>

            {/* Risk warning + quick-fix button */}
            {diag.canQuickFix && (
              <Box>
                {diag.riskLevel === "high" && (
                  <Collapse in={true}>
                    <Alert severity="error" variant="outlined" sx={{ mb: 1.5 }}>
                      <AlertTitle>High Risk Action</AlertTitle>
                      <Typography variant="body2">{diag.riskWarning}</Typography>
                      <FormControlLabel
                        control={
                          <Checkbox
                            size="small"
                            checked={!!riskAcknowledged[idx]}
                            onChange={(e) =>
                              setRiskAcknowledged((prev) => ({
                                ...prev,
                                [idx]: e.target.checked,
                              }))
                            }
                          />
                        }
                        label={
                          <Typography variant="body2" sx={{ fontWeight: 500 }}>
                            I understand the consequences
                          </Typography>
                        }
                        sx={{ mt: 1 }}
                      />
                    </Alert>
                  </Collapse>
                )}

                {diag.riskLevel === "medium" && (
                  <Alert severity="warning" variant="outlined" sx={{ mb: 1.5 }}>
                    <Typography variant="body2">{diag.riskWarning}</Typography>
                  </Alert>
                )}

                {diag.riskLevel === "low" && (
                  <Alert severity="info" variant="outlined" sx={{ mb: 1.5 }}>
                    <Typography variant="body2">{diag.riskWarning}</Typography>
                  </Alert>
                )}

                <Button
                  size="small"
                  variant="contained"
                  color={riskColorMap[diag.riskLevel] || "primary"}
                  disabled={
                    quickFixStatus === "loading" ||
                    quickFixStatus === "success" ||
                    (diag.riskLevel === "high" && !riskAcknowledged[idx])
                  }
                  startIcon={
                    quickFixStatus === "loading" ? (
                      <CircularProgress size={14} />
                    ) : (
                      <Replay sx={{ fontSize: 14 }} />
                    )
                  }
                  onClick={() => onQuickFix(diag)}
                  sx={{ textTransform: "none", fontSize: "0.75rem" }}
                >
                  {quickFixStatus === "loading"
                    ? "Fixing..."
                    : diag.riskLevel === "low"
                    ? "Auto-fix & Retry"
                    : "Fix & Retry"}
                </Button>
              </Box>
            )}

            {/* Settings page link */}
            {diag.settingsPage && (
              <Box>
                {diag.settingsPage.startsWith("http") ? (
                  <Button
                    component="a"
                    href={buildDelegatedUrl(diag.settingsPage)}
                    target="_blank"
                    rel="noopener noreferrer"
                    size="small"
                    variant="outlined"
                    startIcon={<OpenInNew sx={{ fontSize: 14 }} />}
                    sx={{ textTransform: "none", fontSize: "0.75rem" }}
                  >
                    Open Teams Admin Center
                  </Button>
                ) : (
                  <Button
                    component={Link}
                    href={diag.settingsPage}
                    size="small"
                    variant="outlined"
                    startIcon={<OpenInNew sx={{ fontSize: 14 }} />}
                    sx={{ textTransform: "none", fontSize: "0.75rem" }}
                  >
                    Go to Settings
                  </Button>
                )}
              </Box>
            )}
          </Stack>
        </Paper>
      ))}

      {/* Quick-fix result */}
      {quickFixStatus === "success" && quickFixMessage && (
        <Alert severity="success" icon={<CheckCircle />}>
          <Typography variant="body2">{quickFixMessage}</Typography>
        </Alert>
      )}
      {quickFixStatus === "error" && quickFixMessage && (
        <Alert severity="error" icon={<ErrorOutline />}>
          <Typography variant="body2">{quickFixMessage}</Typography>
        </Alert>
      )}

      {/* Collapsible Technical Details */}
      {rawError && (
        <Box>
          <Button
            size="small"
            variant="text"
            color="inherit"
            startIcon={<Code sx={{ fontSize: 14 }} />}
            endIcon={showTechnical ? <ExpandLess sx={{ fontSize: 14 }} /> : <ExpandMore sx={{ fontSize: 14 }} />}
            onClick={() => setShowTechnical((prev) => !prev)}
            sx={{
              textTransform: "none",
              fontSize: "0.75rem",
              color: "text.secondary",
              px: 1,
            }}
          >
            Technical Details
          </Button>
          <Collapse in={showTechnical} unmountOnExit>
            <Paper
              variant="outlined"
              sx={{
                mt: 0.5,
                p: 1.5,
                borderRadius: 1,
                bgcolor: (theme) => alpha(theme.palette.text.primary, 0.03),
              }}
            >
              <Typography
                variant="body2"
                sx={{
                  fontFamily: "monospace",
                  fontSize: "0.75rem",
                  whiteSpace: "pre-wrap",
                  wordBreak: "break-all",
                  color: "text.secondary",
                }}
              >
                {rawError}
              </Typography>
            </Paper>
          </Collapse>
        </Box>
      )}
    </Stack>
  );
};

/**
 * Custom dialog for assign/unassign that integrates diagnostics panel.
 * Follows the pattern from CippGuestInviteDialog.
 */
const VoiceActionDialog = ({
  open,
  onClose,
  title,
  confirmText,
  fields,
  apiUrl,
  apiData,
  phoneNumber,
  tenant,
  queryKey,
  isDanger = false,
}) => {
  const formHook = useForm();
  const queryClient = useQueryClient();
  const [status, setStatus] = useState("idle");
  const [resultMessages, setResultMessages] = useState([]);
  const [diagnostics, setDiagnostics] = useState(null);
  const [rawError, setRawError] = useState(null);
  const [quickFixStatus, setQuickFixStatus] = useState("idle");

  const tenantInfo = useMemo(() => {
    const cached = queryClient.getQueryData(["TenantSelector"]);
    if (!cached || !tenant) return null;
    const match = (Array.isArray(cached) ? cached : []).find(
      (t) => t.defaultDomainName === tenant
    );
    if (!match) return null;
    return {
      addedFields: {
        initialDomainName: match.initialDomainName,
        customerId: match.customerId,
      },
    };
  }, [queryClient, tenant]);
  const [quickFixMessage, setQuickFixMessage] = useState("");

  const actionPost = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [queryKey],
  });

  const quickFixPost = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [queryKey],
  });

  const resetState = useCallback(() => {
    setStatus("idle");
    setResultMessages([]);
    setDiagnostics(null);
    setRawError(null);
    setQuickFixStatus("idle");
    setQuickFixMessage("");
    formHook.reset();
  }, [formHook]);

  const handleClose = useCallback(() => {
    onClose();
    setTimeout(resetState, 300);
  }, [onClose, resetState]);

  const handleSubmitAction = useCallback(
    (formData, overrideData = {}) => {
      setStatus("loading");
      setDiagnostics(null);
      setRawError(null);
      setQuickFixStatus("idle");
      setQuickFixMessage("");

      const payload = {
        tenantFilter: tenant,
        ...apiData,
        ...formData,
        ...overrideData,
      };

      actionPost.mutate(
        { url: apiUrl, data: payload },
        {
          onSuccess: (response) => {
            const data = response?.data;
            const resultText = data?.Results || data?.results || "Operation completed.";
            setResultMessages([
              {
                text: typeof resultText === "string" ? resultText : JSON.stringify(resultText),
                severity: "success",
              },
            ]);
            setStatus("success");
            queryClient.invalidateQueries({ queryKey: [queryKey] });
          },
          onError: (error) => {
            const responseData = error?.response?.data;
            const resultText =
              responseData?.Results ||
              responseData?.results ||
              error?.message ||
              "Operation failed.";
            setResultMessages([
              {
                text: typeof resultText === "string" ? resultText : JSON.stringify(resultText),
                severity: "error",
              },
            ]);
            setStatus("error");

            if (responseData?.Diagnostics?.length > 0) {
              setDiagnostics(responseData.Diagnostics);
            }
            if (responseData?.RawError) {
              setRawError(responseData.RawError);
            }
          },
        }
      );
    },
    [apiUrl, apiData, tenant, queryKey, actionPost, queryClient]
  );

  const handleQuickFix = useCallback(
    (diag) => {
      setQuickFixStatus("loading");
      setQuickFixMessage("");

      const action = diag.quickFixAction;
      const data = diag.quickFixData || {};
      const formData = formHook.getValues();

      const executeRetry = (overrideData = {}) => {
        setQuickFixMessage("Fix applied. Retrying original action...");
        handleSubmitAction(formData, overrideData);
      };

      if (action === "unassignAndRetry") {
        quickFixPost.mutate(
          {
            url: "/api/ExecRemoveTeamsVoicePhoneNumberAssignment",
            data: {
              tenantFilter: tenant,
              PhoneNumber: data.phoneNumber,
              AssignedTo: data.currentAssignee,
              PhoneNumberType: data.phoneNumberType,
            },
          },
          {
            onSuccess: () => {
              setQuickFixStatus("success");
              setQuickFixMessage(
                `Unassigned from ${data.currentAssigneeDisplay}. Retrying assignment...`
              );
              setTimeout(() => executeRetry(), 2000);
            },
            onError: (err) => {
              setQuickFixStatus("error");
              setQuickFixMessage(
                `Failed to unassign from ${data.currentAssigneeDisplay}: ${
                  err?.response?.data?.Results || err?.message || "Unknown error"
                }`
              );
            },
          }
        );
      } else if (action === "removeUserNumberAndRetry") {
        quickFixPost.mutate(
          {
            url: "/api/ExecRemoveTeamsVoicePhoneNumberAssignment",
            data: {
              tenantFilter: tenant,
              PhoneNumber: data.currentNumber,
              AssignedTo: data.userIdentity,
              PhoneNumberType: data.currentNumberType,
            },
          },
          {
            onSuccess: () => {
              setQuickFixStatus("success");
              setQuickFixMessage(
                `Removed ${data.currentNumber} from ${data.userDisplay}. Retrying assignment...`
              );
              setTimeout(() => executeRetry(), 2000);
            },
            onError: (err) => {
              setQuickFixStatus("error");
              setQuickFixMessage(
                `Failed to remove number from ${data.userDisplay}: ${
                  err?.response?.data?.Results || err?.message || "Unknown error"
                }`
              );
            },
          }
        );
      } else if (action === "retryWithCorrectType") {
        setQuickFixStatus("success");
        setQuickFixMessage(`Retrying with correct type: ${data.correctType}...`);
        setTimeout(() => executeRetry({ PhoneNumberType: data.correctType }), 500);
      } else if (action === "unassignFromCorrectUser") {
        quickFixPost.mutate(
          {
            url: "/api/ExecRemoveTeamsVoicePhoneNumberAssignment",
            data: {
              tenantFilter: tenant,
              PhoneNumber: data.phoneNumber,
              AssignedTo: data.actualAssignee,
              PhoneNumberType: data.phoneNumberType,
            },
          },
          {
            onSuccess: () => {
              setQuickFixStatus("success");
              setQuickFixMessage(
                `Unassigned from ${data.actualAssigneeDisplay}. The number is now available.`
              );
              queryClient.invalidateQueries({ queryKey: [queryKey] });
            },
            onError: (err) => {
              setQuickFixStatus("error");
              setQuickFixMessage(
                `Failed to unassign from ${data.actualAssigneeDisplay}: ${
                  err?.response?.data?.Results || err?.message || "Unknown error"
                }`
              );
            },
          }
        );
      } else {
        setQuickFixStatus("error");
        setQuickFixMessage("Unknown quick-fix action.");
      }
    },
    [tenant, queryKey, formHook, handleSubmitAction, quickFixPost, queryClient]
  );

  const onSubmit = (formData) => handleSubmitAction(formData);

  return (
    <Dialog fullWidth maxWidth="sm" open={open} onClose={handleClose} disableRestoreFocus>
      <form onSubmit={formHook.handleSubmit(onSubmit)}>
        <DialogTitle>{title}</DialogTitle>
        <DialogContent>
          <Stack spacing={2}>
            <Typography variant="body2">{confirmText}</Typography>
          </Stack>
        </DialogContent>
        {fields && fields.length > 0 && (
          <DialogContent>
            <Stack spacing={2}>
              {fields.map((fieldProps, i) => (
                <Box key={i} sx={{ width: "100%" }}>
                  <CippFormComponent formControl={formHook} {...fieldProps} />
                </Box>
              ))}
            </Stack>
          </DialogContent>
        )}

        {/* Results section */}
        <Collapse in={resultMessages.length > 0 || status === "loading"}>
          <DialogContent>
            <Stack spacing={1.5}>
              {status === "loading" && (
                <Alert severity="info" variant="outlined">
                  <Stack direction="row" spacing={1} alignItems="center">
                    <CircularProgress size={16} />
                    <Typography variant="body2">Processing...</Typography>
                  </Stack>
                </Alert>
              )}
              {resultMessages.map((msg, i) => (
                <Alert key={i} severity={msg.severity} variant="filled">
                  <Typography variant="body2" sx={{ wordBreak: "break-word" }}>
                    {msg.text}
                  </Typography>
                </Alert>
              ))}

              {/* Diagnostics panel */}
              <DiagnosticsPanel
                diagnostics={diagnostics}
                rawError={rawError}
                onQuickFix={handleQuickFix}
                quickFixStatus={quickFixStatus}
                quickFixMessage={quickFixMessage}
                tenantInfo={tenantInfo}
              />
            </Stack>
          </DialogContent>
        </Collapse>

        <DialogActions>
          <Button color="inherit" onClick={handleClose}>
            Close
          </Button>
          <Button
            variant="contained"
            color={isDanger ? "error" : "primary"}
            type="submit"
            disabled={status === "loading" || status === "success"}
          >
            Confirm
          </Button>
        </DialogActions>
      </form>
    </Dialog>
  );
};

const Page = () => {
  const router = useRouter();
  const { number } = router.query;
  const tenant = useSettings().currentTenant;

  const [assignOpen, setAssignOpen] = useState(false);
  const [unassignOpen, setUnassignOpen] = useState(false);
  const locationDialog = useDialog();

  const phoneData = ApiGetCall({
    url: "/api/ListTeamsVoice",
    data: { tenantFilter: tenant },
    queryKey: `TeamsVoice-${tenant}`,
    waiting: !!(tenant),
  });

  const phoneNumber = useMemo(() => {
    if (!phoneData.data || !number) return null;
    const data = Array.isArray(phoneData.data) ? phoneData.data : [];
    return data.find((p) => p.TelephoneNumber === number) || null;
  }, [phoneData.data, number]);

  if (!number || phoneData.isLoading) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Stack spacing={2}>
          <Button
            component={Link}
            href="/teams-share/teams/business-voice"
            startIcon={<ArrowBack />}
            sx={{ alignSelf: "flex-start" }}
          >
            Back to Phone Numbers
          </Button>
          <Box sx={{ display: "flex", justifyContent: "center", py: 8 }}>
            <CircularProgress />
          </Box>
        </Stack>
      </Container>
    );
  }

  if (phoneData.isError || !phoneNumber) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Stack spacing={2}>
          <Button
            component={Link}
            href="/teams-share/teams/business-voice"
            startIcon={<ArrowBack />}
            sx={{ alignSelf: "flex-start" }}
          >
            Back to Phone Numbers
          </Button>
          <Alert severity="error">
            {phoneData.isError
              ? "Failed to load phone number data."
              : `Phone number "${number}" not found.`}
          </Alert>
        </Stack>
      </Container>
    );
  }

  const isAssigned = phoneNumber.AssignmentStatus === "Assigned";
  const isOperatorConnect =
    phoneNumber.IsOperatorConnect === true ||
    phoneNumber.IsOperatorConnect === "True" ||
    phoneNumber.IsOperatorConnect === "true";
  const assignedUser = getAssignedToDisplay(phoneNumber.AssignedTo);
  const accentColor = isAssigned ? "success" : "warning";

  return (
    <>
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Stack spacing={2}>
          <Button
            component={Link}
            href="/teams-share/teams/business-voice"
            startIcon={<ArrowBack />}
            sx={{ alignSelf: "flex-start" }}
          >
            Back to Phone Numbers
          </Button>

          {/* Hero + Stats Row */}
          <Grid container spacing={2}>
            <Grid size={{ xs: 12, lg: 7 }}>
              <Paper
                elevation={0}
                sx={{
                  p: 3,
                  borderRadius: 2,
                  height: "100%",
                  background: (theme) =>
                    `linear-gradient(135deg, ${alpha(
                      theme.palette[accentColor].main,
                      0.12
                    )} 0%, ${alpha(theme.palette[accentColor].main, 0.04)} 100%)`,
                  borderLeft: (theme) =>
                    `4px solid ${theme.palette[accentColor].main}`,
                }}
              >
                <Stack direction="row" spacing={2} alignItems="center">
                  <Avatar
                    sx={{
                      bgcolor: (theme) =>
                        alpha(theme.palette[accentColor].main, 0.15),
                      color: (theme) => theme.palette[accentColor].main,
                      width: 64,
                      height: 64,
                    }}
                  >
                    <PhoneIcon sx={{ fontSize: 32 }} />
                  </Avatar>
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Typography variant="h5" sx={{ fontWeight: 700, mb: 0.25 }}>
                      {phoneNumber.TelephoneNumber}
                    </Typography>
                    {isAssigned && assignedUser && (
                      <Stack
                        direction="row"
                        spacing={0.75}
                        alignItems="center"
                        sx={{ mb: 0.75 }}
                      >
                        <Person sx={{ fontSize: 18, color: "text.secondary" }} />
                        <Typography variant="body1" sx={{ fontWeight: 600 }}>
                          {assignedUser}
                        </Typography>
                      </Stack>
                    )}
                    <Stack
                      direction="row"
                      spacing={1}
                      flexWrap="wrap"
                      useFlexGap
                    >
                      <Chip
                        icon={
                          isAssigned ? (
                            <CheckCircle fontSize="small" />
                          ) : (
                            <Warning fontSize="small" />
                          )
                        }
                        label={isAssigned ? "Assigned" : "Unassigned"}
                        size="small"
                        color={accentColor}
                        variant="outlined"
                      />
                      {phoneNumber.NumberType && (
                        <Chip
                          icon={<Phone fontSize="small" />}
                          label={formatNumberType(phoneNumber.NumberType)}
                          size="small"
                          variant="outlined"
                        />
                      )}
                      {isOperatorConnect && (
                        <Tooltip title="Provisioned via Operator Connect">
                          <Chip
                            icon={<SyncAlt fontSize="small" />}
                            label="Operator Connect"
                            size="small"
                            color="info"
                            variant="outlined"
                          />
                        </Tooltip>
                      )}
                      {phoneNumber.ActivationState && (
                        <Chip
                          label={phoneNumber.ActivationState}
                          size="small"
                          color={
                            phoneNumber.ActivationState === "Activated"
                              ? "success"
                              : phoneNumber.ActivationState === "AssignmentPending"
                              ? "info"
                              : "default"
                          }
                          variant="outlined"
                        />
                      )}
                    </Stack>
                  </Box>
                </Stack>
              </Paper>
            </Grid>
            <Grid size={{ xs: 12, lg: 5 }}>
              <Paper
                variant="outlined"
                sx={{
                  borderRadius: 2,
                  height: "100%",
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "center",
                }}
              >
                <Stack
                  direction="row"
                  divider={<Divider orientation="vertical" flexItem />}
                  spacing={0}
                >
                  <StatBox
                    label="Status"
                    value={isAssigned ? "Assigned" : "Unassigned"}
                    color={accentColor}
                  />
                  <StatBox
                    label="Country"
                    value={phoneNumber.IsoCountryCode || "—"}
                    color="primary"
                  />
                  <StatBox
                    label="Type"
                    value={formatNumberType(phoneNumber.NumberType) || "—"}
                    color="info"
                  />
                </Stack>
              </Paper>
            </Grid>
          </Grid>

          {/* Quick Actions */}
          <Paper variant="outlined" sx={{ borderRadius: 2, p: 2 }}>
            <Stack
              direction="row"
              spacing={1.5}
              flexWrap="wrap"
              useFlexGap
            >
              <Button
                variant="outlined"
                size="small"
                startIcon={<PersonAdd />}
                onClick={() => setAssignOpen(true)}
              >
                Assign User
              </Button>
              {isAssigned && (
                <Button
                  variant="outlined"
                  size="small"
                  color="warning"
                  startIcon={<PersonRemove />}
                  onClick={() => setUnassignOpen(true)}
                >
                  Unassign User
                </Button>
              )}
              <Button
                variant="outlined"
                size="small"
                startIcon={<LocationOn />}
                onClick={() => locationDialog.handleOpen()}
              >
                Set Emergency Location
              </Button>
            </Stack>
          </Paper>

          {/* Assignment + Location Info */}
          <Grid container spacing={2}>
            <Grid size={{ xs: 12, md: 6 }}>
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2, height: "100%" }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <Person fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Assignment
                  </Typography>
                </Stack>
                <Stack spacing={0.5}>
                  <InfoRow
                    label="Assignment Status"
                    value={phoneNumber.AssignmentStatus}
                  />
                  <InfoRow
                    label="Assigned To"
                    value={assignedUser || "Unassigned"}
                  />
                  <InfoRow label="Number Type" value={formatNumberType(phoneNumber.NumberType)} />
                  <InfoRow
                    label="Activation State"
                    value={phoneNumber.ActivationState}
                  />
                </Stack>
              </Paper>
            </Grid>
            <Grid size={{ xs: 12, md: 6 }}>
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2, height: "100%" }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <LocationOn fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Location
                  </Typography>
                </Stack>
                <Stack spacing={0.5}>
                  <InfoRow
                    label="Country Code"
                    value={phoneNumber.IsoCountryCode}
                  />
                  <InfoRow
                    label="Emergency Location"
                    value={phoneNumber.PlaceName}
                  />
                  <InfoRow label="City" value={phoneNumber.CityCode} />
                </Stack>
              </Paper>
            </Grid>
          </Grid>

          {/* Capabilities + Details */}
          <Grid container spacing={2}>
            <Grid size={{ xs: 12, md: 6 }}>
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2, height: "100%" }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <Speed fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Capabilities
                  </Typography>
                </Stack>
                <Stack spacing={2}>
                  <Box>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                      Acquired Capabilities
                    </Typography>
                    <Stack direction="row" flexWrap="wrap" useFlexGap spacing={0.75}>
                      {parseCapabilities(phoneNumber.AcquiredCapabilities).length > 0 ? (
                        parseCapabilities(phoneNumber.AcquiredCapabilities).map((cap, i) => (
                          <Chip key={i} label={cap} size="small" color="success" variant="outlined" />
                        ))
                      ) : (
                        <Typography variant="body2" color="text.disabled">None</Typography>
                      )}
                    </Stack>
                  </Box>
                  <Box>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                      Available Capabilities
                    </Typography>
                    <Stack direction="row" flexWrap="wrap" useFlexGap spacing={0.75}>
                      {parseCapabilities(phoneNumber.AvailableCapabilities).length > 0 ? (
                        parseCapabilities(phoneNumber.AvailableCapabilities).map((cap, i) => (
                          <Chip key={i} label={cap} size="small" variant="outlined" />
                        ))
                      ) : (
                        <Typography variant="body2" color="text.disabled">None</Typography>
                      )}
                    </Stack>
                  </Box>
                </Stack>
              </Paper>
            </Grid>
            <Grid size={{ xs: 12, md: 6 }}>
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2, height: "100%" }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <Shield fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Additional Details
                  </Typography>
                </Stack>
                <Stack spacing={0.5}>
                  <InfoRow
                    label="Operator Connect"
                    value={isOperatorConnect ? "Yes" : "No"}
                  />
                  {phoneNumber.AcquisitionDate && (
                    <InfoRow
                      label="Acquisition Date"
                      value={new Date(
                        phoneNumber.AcquisitionDate
                      ).toLocaleDateString()}
                    />
                  )}
                  <InfoRow
                    label="Telephone Number ID"
                    value={phoneNumber.Id}
                    mono
                  />
                </Stack>
              </Paper>
            </Grid>
          </Grid>
        </Stack>
      </Container>

      {/* Assign User Dialog with Diagnostics */}
      <VoiceActionDialog
        open={assignOpen}
        onClose={() => setAssignOpen(false)}
        title="Assign User"
        confirmText={`Select the User to assign the phone number '${phoneNumber.TelephoneNumber}' to.`}
        apiUrl="/api/ExecTeamsVoicePhoneNumberAssignment"
        apiData={{
          PhoneNumber: phoneNumber.TelephoneNumber,
          PhoneNumberType: phoneNumber.NumberType,
          locationOnly: false,
        }}
        fields={[
          {
            type: "autoComplete",
            name: "input",
            label: "Select User",
            multiple: false,
            creatable: false,
            api: {
              url: "/api/listUsers",
              labelField: (input) =>
                `${input.displayName} (${input.userPrincipalName})`,
              valueField: "userPrincipalName",
            },
          },
        ]}
        phoneNumber={phoneNumber}
        tenant={tenant}
        queryKey={`TeamsVoice-${tenant}`}
      />

      {/* Unassign User Dialog with Diagnostics */}
      <VoiceActionDialog
        open={unassignOpen}
        onClose={() => setUnassignOpen(false)}
        title="Unassign User"
        confirmText={`Are you sure you want to remove the assignment for '${phoneNumber.TelephoneNumber}' from '${assignedUser}'?`}
        apiUrl="/api/ExecRemoveTeamsVoicePhoneNumberAssignment"
        apiData={{
          PhoneNumber: phoneNumber.TelephoneNumber,
          AssignedTo: phoneNumber.AssignedTo,
          PhoneNumberType: phoneNumber.NumberType,
        }}
        fields={[]}
        phoneNumber={phoneNumber}
        tenant={tenant}
        queryKey={`TeamsVoice-${tenant}`}
        isDanger
      />

      {/* Set Emergency Location Dialog -- uses standard CippApiDialog (no diagnostics needed) */}
      <CippApiDialog
        title="Set Emergency Location"
        createDialog={locationDialog}
        api={{
          url: "/api/ExecTeamsVoicePhoneNumberAssignment",
          type: "POST",
          data: {
            PhoneNumber: phoneNumber.TelephoneNumber,
            locationOnly: true,
          },
          confirmText: `Select the Emergency Location for '${phoneNumber.TelephoneNumber}'.`,
          multiPost: false,
        }}
        fields={[
          {
            type: "autoComplete",
            name: "input",
            label: "Emergency Location",
            api: {
              url: "/api/ListTeamsLisLocation",
              labelField: "Description",
              valueField: "LocationId",
            },
          },
        ]}
        row={phoneNumber}
        relatedQueryKeys={[`TeamsVoice-${tenant}`]}
      />
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
