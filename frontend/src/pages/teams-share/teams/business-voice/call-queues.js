import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import {
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
  useMediaQuery,
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  Groups,
  Shuffle,
  LinearScale,
  Timer,
  Warning,
  Language,
  CallSplit,
  Phone,
  Timelapse,
  CheckCircle,
  RadioButtonUnchecked,
} from "@mui/icons-material";
import { useMemo, useCallback } from "react";

const Page = () => {
  const pageTitle = "Call Queues";
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  const getRoutingLabel = (method) => {
    const labels = {
      Attendant: "Attendant",
      Serial: "Serial",
      RoundRobin: "Round Robin",
      LongestIdle: "Longest Idle",
    };
    return labels[method] || method || "Unknown";
  };

  const getRoutingIcon = (method) => {
    switch (method) {
      case "RoundRobin":
        return <Shuffle fontSize="small" />;
      case "Serial":
        return <LinearScale fontSize="small" />;
      case "LongestIdle":
        return <Timelapse fontSize="small" />;
      default:
        return <CallSplit fontSize="small" />;
    }
  };

  const getAgentCount = (item) => {
    if (Array.isArray(item?.Agents)) return item.Agents.length;
    if (item?.Agents?.length) return item.Agents.length;
    return 0;
  };

  const getOverflowAction = (item) => {
    if (!item) return "Unknown";
    if (item.OverflowAction === "DisconnectWithBusy" || item.OverflowAction === "Disconnect")
      return "Disconnect";
    if (item.OverflowAction === "Forward" && item.OverflowActionTarget)
      return `Forward to ${item.OverflowActionTarget.Id || "target"}`;
    if (item.OverflowAction === "Voicemail") return "Voicemail";
    if (item.OverflowAction === "SharedVoicemail") return "Shared Voicemail";
    return item.OverflowAction || "Not configured";
  };

  const getTimeoutAction = (item) => {
    if (!item) return "Unknown";
    if (item.TimeoutAction === "Disconnect") return "Disconnect";
    if (item.TimeoutAction === "Forward" && item.TimeoutActionTarget)
      return `Forward to ${item.TimeoutActionTarget.Id || "target"}`;
    if (item.TimeoutAction === "Voicemail") return "Voicemail";
    if (item.TimeoutAction === "SharedVoicemail") return "Shared Voicemail";
    return item.TimeoutAction || "Not configured";
  };

  const filters = useMemo(
    () => [
      {
        filterName: "Round Robin Routing",
        value: [{ id: "RoutingMethod", value: "RoundRobin" }],
        type: "column",
      },
      {
        filterName: "Serial Routing",
        value: [{ id: "RoutingMethod", value: "Serial" }],
        type: "column",
      },
      {
        filterName: "Longest Idle Routing",
        value: [{ id: "RoutingMethod", value: "LongestIdle" }],
        type: "column",
      },
    ],
    []
  );

  const cardConfig = useMemo(
    () => ({
      title: "Name",
      avatar: {
        field: "Name",
        icon: () => <Phone />,
      },
      badges: [
        {
          field: "RoutingMethod",
          conditions: {
            Attendant: {
              label: "Attendant",
              color: "info",
              icon: <CallSplit fontSize="small" />,
              tooltip: "All agents ring simultaneously",
            },
            Serial: {
              label: "Serial",
              color: "primary",
              icon: <LinearScale fontSize="small" />,
              tooltip: "Agents ring one at a time in order",
            },
            RoundRobin: {
              label: "Round Robin",
              color: "success",
              icon: <Shuffle fontSize="small" />,
              tooltip: "Calls distributed evenly among agents",
            },
            LongestIdle: {
              label: "Longest Idle",
              color: "warning",
              icon: <Timelapse fontSize="small" />,
              tooltip: "Agent idle longest gets next call",
            },
          },
        },
      ],
      extraFields: [
        {
          field: "Agents",
          icon: <Groups />,
          label: "Agents",
          formatter: (value) => {
            const count = Array.isArray(value) ? value.length : 0;
            return `${count} agent${count !== 1 ? "s" : ""}`;
          },
        },
        [
          {
            field: "OverflowThreshold",
            icon: <Warning />,
            label: "Overflow",
            formatter: (value) => (value ? `${value} calls` : "Not set"),
          },
          {
            field: "TimeoutThreshold",
            icon: <Timer />,
            label: "Timeout",
            formatter: (value) => (value ? `${value}s` : "Not set"),
            align: "right",
          },
        ],
      ],
      desktopFields: [
        {
          field: "LanguageId",
          icon: <Language />,
          label: "Language",
        },
      ],
      cardGridProps: {
        md: 6,
        lg: 4,
      },
    }),
    []
  );

  const offCanvasChildren = useCallback(
    (row) => {
      const agentCount = getAgentCount(row);
      const routingLabel = getRoutingLabel(row.RoutingMethod);

      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper
            elevation={0}
            sx={{
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(
                theme.palette.primary.main,
                0.15
              )} 0%, ${alpha(theme.palette.primary.main, 0.05)} 100%)`,
              borderLeft: `4px solid ${theme.palette.primary.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(theme.palette.primary.main, 0.15),
                  color: theme.palette.primary.main,
                  width: 56,
                  height: 56,
                }}
              >
                <Phone sx={{ fontSize: 28 }} />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.Name}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                  <Chip
                    icon={getRoutingIcon(row.RoutingMethod)}
                    label={routingLabel}
                    size="small"
                    color="primary"
                    variant="outlined"
                  />
                  <Chip
                    icon={<Groups fontSize="small" />}
                    label={`${agentCount} agent${agentCount !== 1 ? "s" : ""}`}
                    size="small"
                    variant="outlined"
                  />
                </Stack>
              </Box>
            </Stack>
          </Paper>

          {/* Queue Settings */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Queue Settings
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Routing Method
                </Typography>
                <Chip
                  icon={getRoutingIcon(row.RoutingMethod)}
                  label={routingLabel}
                  size="small"
                  color="primary"
                  variant="outlined"
                />
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Agent Alert Time
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.AgentAlertTime ? `${row.AgentAlertTime}s` : "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Language
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.LanguageId || "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Conference Mode
                </Typography>
                <Chip
                  label={row.ConferenceMode === "true" || row.ConferenceMode === true ? "Enabled" : "Disabled"}
                  size="small"
                  color={row.ConferenceMode === "true" || row.ConferenceMode === true ? "success" : "default"}
                  variant="outlined"
                />
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Presence-Based Routing
                </Typography>
                <Chip
                  label={
                    row.PresenceBasedRouting === true || row.PresenceBasedRouting === "true"
                      ? "Enabled"
                      : "Disabled"
                  }
                  size="small"
                  color={
                    row.PresenceBasedRouting === true || row.PresenceBasedRouting === "true"
                      ? "success"
                      : "default"
                  }
                  variant="outlined"
                />
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Overflow & Timeout */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Overflow & Timeout
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Overflow Threshold
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.OverflowThreshold ? `${row.OverflowThreshold} calls` : "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Overflow Action
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {getOverflowAction(row)}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Timeout Threshold
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.TimeoutThreshold ? `${row.TimeoutThreshold}s` : "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Timeout Action
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {getTimeoutAction(row)}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Music & Greetings */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Music & Greetings
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Welcome Music
                </Typography>
                <Chip
                  label={row.WelcomeMusicFileName ? "Configured" : "Default"}
                  size="small"
                  color={row.WelcomeMusicFileName ? "success" : "default"}
                  variant="outlined"
                />
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Music on Hold
                </Typography>
                <Chip
                  label={row.MusicOnHoldFileName ? "Custom" : "Default"}
                  size="small"
                  color={row.MusicOnHoldFileName ? "info" : "default"}
                  variant="outlined"
                />
              </Stack>
              {row.WelcomeTextToSpeechPrompt && (
                <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                  <Typography variant="body2" color="text.secondary">
                    Welcome TTS
                  </Typography>
                  <Typography
                    variant="body2"
                    sx={{ fontWeight: 500, maxWidth: 200, textAlign: "right" }}
                  >
                    {row.WelcomeTextToSpeechPrompt}
                  </Typography>
                </Stack>
              )}
            </Stack>
          </Box>

          {/* Agents List */}
          {Array.isArray(row.Agents) && row.Agents.length > 0 && (
            <>
              <Divider />
              <Box>
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
                  Agents ({row.Agents.length})
                </Typography>
                <Paper variant="outlined" sx={{ borderRadius: 1, overflow: "hidden" }}>
                  <Table size="small">
                    <TableHead>
                      <TableRow>
                        <TableCell sx={{ fontWeight: 600, fontSize: "0.75rem" }}>
                          Agent
                        </TableCell>
                        <TableCell sx={{ fontWeight: 600, fontSize: "0.75rem" }} align="center">
                          Opt-In
                        </TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {row.Agents.map((agent, index) => (
                        <TableRow key={index}>
                          <TableCell sx={{ fontSize: "0.8125rem" }}>
                            {agent.ObjectId || agent.Id || `Agent ${index + 1}`}
                          </TableCell>
                          <TableCell align="center">
                            {agent.OptIn === true || agent.OptIn === "true" ? (
                              <CheckCircle fontSize="small" color="success" />
                            ) : (
                              <RadioButtonUnchecked fontSize="small" color="disabled" />
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </Paper>
              </Box>
            </>
          )}
        </Stack>
      );
    },
    [theme]
  );

  const offCanvas = useMemo(
    () => ({
      children: offCanvasChildren,
      size: "lg",
    }),
    [offCanvasChildren]
  );

  const simpleColumns = useMemo(
    () =>
      isMobile
        ? ["Name", "RoutingMethod", "Agents"]
        : [
            "Name",
            "RoutingMethod",
            "Agents",
            "AgentAlertTime",
            "OverflowThreshold",
            "TimeoutThreshold",
            "LanguageId",
            "ConferenceMode",
            "PresenceBasedRouting",
          ],
    [isMobile]
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListTeamsCallQueues"
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      filters={filters}
      cardConfig={cardConfig}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
