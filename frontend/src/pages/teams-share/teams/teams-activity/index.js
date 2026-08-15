import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import {
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
  Tooltip,
  LinearProgress,
  useMediaQuery,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  Person,
  CalendarToday,
  Call,
  Videocam,
  Chat,
  TrendingUp,
  TrendingDown,
  MeetingRoom,
  CheckCircle,
  Warning,
} from "@mui/icons-material";
import { useSettings } from "../../../../hooks/use-settings";
import { useMemo, useCallback } from "react";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";

// Helper to determine activity level
const getActivityLevel = (totalActivity) => {
  if (!totalActivity || totalActivity === 0) return "none";
  if (totalActivity >= 100) return "heavy";
  if (totalActivity >= 30) return "active";
  if (totalActivity >= 5) return "light";
  return "minimal";
};

// Helper to get activity color
const getActivityColor = (level) => {
  switch (level) {
    case "heavy":
      return "success";
    case "active":
      return "info";
    case "light":
      return "warning";
    case "minimal":
      return "warning";
    case "none":
      return "error";
    default:
      return "default";
  }
};

// Helper to check if user is inactive (no activity in 30+ days)
const isUserInactive = (lastActive) => {
  if (!lastActive) return true;
  const lastDate = new Date(lastActive);
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  return lastDate < thirtyDaysAgo;
};

// Activity bar component
const ActivityBar = ({ value, max, color = "primary", label }) => {
  const percentage = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0;
  return (
    <Tooltip title={`${label}: ${value} (${percentage}% of max)`}>
      <Box sx={{ width: "100%", minWidth: 60 }}>
        <LinearProgress
          variant="determinate"
          value={percentage}
          color={color}
          sx={{
            height: 4,
            borderRadius: 2,
            bgcolor: (theme) => alpha(theme.palette.grey[500], 0.15),
          }}
        />
      </Box>
    </Tooltip>
  );
};

const Page = () => {
  const pageTitle = "Teams Activity";
  const tenantFilter = useSettings().currentTenant;
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  const filters = useMemo(
    () => [
      {
        filterName: "High Meeting Activity (20+)",
        value: [{ id: "meetingActivity", value: "high" }],
        type: "column",
      },
      {
        filterName: "High Call Activity (20+)",
        value: [{ id: "callActivity", value: "high" }],
        type: "column",
      },
      {
        filterName: "Active Chatters (50+)",
        value: [{ id: "chatActivity", value: "high" }],
        type: "column",
      },
      {
        filterName: "Inactive Users (30+ days)",
        value: [{ id: "activityStatus", value: "inactive" }],
        type: "column",
      },
      {
        filterName: "No Activity",
        value: [{ id: "activityLevel", value: "none" }],
        type: "column",
      },
    ],
    []
  );

  const cardConfig = useMemo(
    () => ({
      title: "displayName",
      subtitle: "UPN",
      avatar: {
        field: "displayName",
      },
      badges: [
        {
          field: "activityStatus",
          conditions: {
            active: {
              label: "Active",
              color: "success",
              icon: <CheckCircle fontSize="small" />,
            },
            inactive: {
              label: "Inactive (30+ days)",
              color: "warning",
              icon: <Warning fontSize="small" />,
            },
          },
          transform: (value, item) =>
            isUserInactive(item.LastActive) ? "inactive" : "active",
          iconOnly: true,
        },
        {
          field: "activityLevel",
          conditions: {
            heavy: {
              label: "Heavy usage (100+ activities)",
              color: "success",
              icon: <TrendingUp fontSize="small" />,
            },
            none: {
              label: "No activity",
              color: "error",
              icon: <TrendingDown fontSize="small" />,
            },
          },
          transform: (value, item) => {
            const level = getActivityLevel(item.totalActivity);
            return level === "heavy" || level === "none" ? level : null;
          },
          iconOnly: true,
        },
      ],
      extraFields: [
        {
          field: "LastActive",
          icon: <CalendarToday />,
          label: "Last Active",
          formatter: (value) =>
            value ? new Date(value).toLocaleDateString() : "Never",
        },
      ],
      desktopFields: [
        {
          field: "MeetingCount",
          icon: <MeetingRoom />,
          label: "Meetings",
          formatter: (value) => `${value || 0} meetings`,
        },
        {
          field: "CallCount",
          icon: <Call />,
          label: "Calls",
          formatter: (value) => `${value || 0} calls`,
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
      const totalActivity = row.totalActivity || 0;
      const level = getActivityLevel(totalActivity);
      const color = getActivityColor(level);
      const inactive = isUserInactive(row.LastActive);
      const maxActivity = Math.max(
        row.TeamsChat || 0,
        row.PrivateChat || 0,
        row.CallCount || 0,
        row.MeetingCount || 0,
        1
      );

      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper
            elevation={0}
            sx={{
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(
                theme.palette[color]?.main || theme.palette.primary.main,
                0.15
              )} 0%, ${alpha(
                theme.palette[color]?.main || theme.palette.primary.main,
                0.05
              )} 100%)`,
              borderLeft: `4px solid ${theme.palette[color]?.main || theme.palette.primary.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(
                    theme.palette[color]?.main || theme.palette.primary.main,
                    0.15
                  ),
                  color: theme.palette[color]?.main || theme.palette.primary.main,
                  width: 56,
                  height: 56,
                }}
              >
                <Person sx={{ fontSize: 28 }} />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.displayName || row.UPN || "Unknown User"}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                  <Chip
                    label={inactive ? "Inactive" : "Active"}
                    size="small"
                    color={inactive ? "warning" : "success"}
                    variant="outlined"
                  />
                  <Chip
                    label={`${totalActivity} total activities`}
                    size="small"
                    variant="outlined"
                  />
                </Stack>
              </Box>
            </Stack>
          </Paper>

          {/* Activity Summary */}
          <Paper variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
            <Stack direction="row" spacing={2} justifyContent="space-around" flexWrap="wrap" useFlexGap>
              <Box sx={{ textAlign: "center", minWidth: 60 }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: "info.main" }}>
                  {row.MeetingCount || 0}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Meetings
                </Typography>
              </Box>
              <Divider orientation="vertical" flexItem />
              <Box sx={{ textAlign: "center", minWidth: 60 }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: "success.main" }}>
                  {row.CallCount || 0}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Calls
                </Typography>
              </Box>
              <Divider orientation="vertical" flexItem />
              <Box sx={{ textAlign: "center", minWidth: 60 }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: "primary.main" }}>
                  {row.TeamsChat || 0}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Team Chats
                </Typography>
              </Box>
              <Divider orientation="vertical" flexItem />
              <Box sx={{ textAlign: "center", minWidth: 60 }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: "warning.main" }}>
                  {row.PrivateChat || 0}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Private Chats
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Activity Breakdown */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Activity Breakdown (30-day period)
            </Typography>
            <Stack spacing={1.5}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Stack direction="row" spacing={1} alignItems="center" sx={{ minWidth: 120 }}>
                  <MeetingRoom fontSize="small" color="info" />
                  <Typography variant="body2">Meetings</Typography>
                </Stack>
                <Typography variant="body2" sx={{ fontWeight: 600, minWidth: 40, textAlign: "right" }}>
                  {row.MeetingCount || 0}
                </Typography>
                <Box sx={{ flex: 1, ml: 2 }}>
                  <ActivityBar value={row.MeetingCount || 0} max={maxActivity} color="info" label="Meetings" />
                </Box>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Stack direction="row" spacing={1} alignItems="center" sx={{ minWidth: 120 }}>
                  <Call fontSize="small" color="success" />
                  <Typography variant="body2">Calls</Typography>
                </Stack>
                <Typography variant="body2" sx={{ fontWeight: 600, minWidth: 40, textAlign: "right" }}>
                  {row.CallCount || 0}
                </Typography>
                <Box sx={{ flex: 1, ml: 2 }}>
                  <ActivityBar value={row.CallCount || 0} max={maxActivity} color="success" label="Calls" />
                </Box>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Stack direction="row" spacing={1} alignItems="center" sx={{ minWidth: 120 }}>
                  <Chat fontSize="small" color="primary" />
                  <Typography variant="body2">Team Chats</Typography>
                </Stack>
                <Typography variant="body2" sx={{ fontWeight: 600, minWidth: 40, textAlign: "right" }}>
                  {row.TeamsChat || 0}
                </Typography>
                <Box sx={{ flex: 1, ml: 2 }}>
                  <ActivityBar value={row.TeamsChat || 0} max={maxActivity} color="primary" label="Team Chats" />
                </Box>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Stack direction="row" spacing={1} alignItems="center" sx={{ minWidth: 120 }}>
                  <Chat fontSize="small" color="warning" />
                  <Typography variant="body2">Private Chats</Typography>
                </Stack>
                <Typography variant="body2" sx={{ fontWeight: 600, minWidth: 40, textAlign: "right" }}>
                  {row.PrivateChat || 0}
                </Typography>
                <Box sx={{ flex: 1, ml: 2 }}>
                  <ActivityBar value={row.PrivateChat || 0} max={maxActivity} color="warning" label="Private Chats" />
                </Box>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Meeting Details */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Meeting Details
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Meetings Organized
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.MeetingsOrganized || 0}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Meetings Attended
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.MeetingsAttended || 0}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Ad-Hoc Organized
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.AdHocMeetingsOrganized || 0}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Scheduled Organized
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.ScheduledMeetingsOrganized || 0}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Media Duration */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Media Duration
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Audio
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.AudioDuration || "0:00:00"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Video
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.VideoDuration || "0:00:00"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Screen Share
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.ScreenShareDuration || "0:00:00"}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* User Info */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              User Info
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  UPN
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }} noWrap>
                  {row.UPN}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Last Active
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.LastActive || "Never"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Report Period
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.reportPeriod || "30"} days
                </Typography>
              </Stack>
            </Stack>
          </Box>
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
        ? ["displayName", "LastActive", "totalActivity"]
        : [
            "displayName",
            "UPN",
            "LastActive",
            "TeamsChat",
            "PrivateChat",
            "CallCount",
            "MeetingCount",
            "totalActivity",
          ],
    [isMobile]
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListTeamsActivity?type=TeamsUserActivityUser"
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      filters={filters}
      cardConfig={cardConfig}
      dataFreshnessField="reportRefreshDate"
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
