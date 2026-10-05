import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import {
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  Warning,
  Error as ErrorIcon,
  Info as InfoIcon,
  CheckCircle,
  Cancel,
  LocationOn,
  Computer,
  CalendarToday,
  Person,
} from "@mui/icons-material";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";

const Page = () => {
  const pageTitle = "Risk Detection Report";
  const apiUrl = "/api/ListGraphRequest";
  const theme = useTheme();

  const actions = [
    {
      label: "Research Compromised Account",
      type: "GET",
      icon: <MagnifyingGlassIcon />,
      link: "/identity/administration/users/user/bec?userId=[userId]",
      confirmText: "Are you sure you want to research this compromised account?",
      multiPost: false,
      category: "view",
    },
  ];

  // Helper functions
  const getRiskLevelInfo = (level) => {
    switch (String(level || "").toLowerCase()) {
      case "high":
        return { label: "High", color: theme.palette.error.main, icon: <ErrorIcon fontSize="small" /> };
      case "medium":
        return { label: "Medium", color: theme.palette.warning.main, icon: <Warning fontSize="small" /> };
      case "low":
        return { label: "Low", color: theme.palette.info.main, icon: <InfoIcon fontSize="small" /> };
      default:
        return { label: level || "Unknown", color: theme.palette.grey[500], icon: <InfoIcon fontSize="small" /> };
    }
  };

  const getRiskStateInfo = (state) => {
    switch (String(state || "").toLowerCase()) {
      case "atrisk":
        return { label: "At Risk", color: theme.palette.error.main, icon: <ErrorIcon fontSize="small" /> };
      case "confirmedcompromised":
        return { label: "Compromised", color: theme.palette.error.dark, icon: <ErrorIcon fontSize="small" /> };
      case "confirmedsafe":
        return { label: "Confirmed Safe", color: theme.palette.success.main, icon: <CheckCircle fontSize="small" /> };
      case "remediated":
        return { label: "Remediated", color: theme.palette.success.main, icon: <CheckCircle fontSize="small" /> };
      case "dismissed":
        return { label: "Dismissed", color: theme.palette.grey[500], icon: <Cancel fontSize="small" /> };
      default:
        return { label: state || "Unknown", color: theme.palette.grey[500], icon: <InfoIcon fontSize="small" /> };
    }
  };

  const offCanvas = {
    actions: actions,
    children: (row) => {
      const levelInfo = getRiskLevelInfo(row.riskLevel);
      const stateInfo = getRiskStateInfo(row.riskState);
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(levelInfo.color, 0.15)} 0%, ${alpha(levelInfo.color, 0.05)} 100%)`,
              borderLeft: `4px solid ${levelInfo.color}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: stringToColor(row.userDisplayName || "U"),
                  width: 56,
                  height: 56,
                  fontSize: "1.25rem",
                  fontWeight: 600,
                }}
              >
                {getInitials(row.userDisplayName || "User")}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.userDisplayName || "Unknown User"}
                </Typography>
                <Typography variant="body2" color="text.secondary" noWrap>
                  {row.userPrincipalName}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Risk Status */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Risk Assessment
            </Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                icon={stateInfo.icon}
                label={stateInfo.label}
                sx={{ 
                  fontWeight: 600, 
                  bgcolor: alpha(stateInfo.color, 0.1),
                  color: stateInfo.color,
                  borderColor: stateInfo.color,
                }}
                variant="outlined"
              />
              <Chip
                icon={levelInfo.icon}
                label={`Level: ${levelInfo.label}`}
                color={levelInfo.label === "High" ? "error" : levelInfo.label === "Medium" ? "warning" : "info"}
                variant="filled"
                size="small"
              />
            </Stack>
          </Box>

          <Divider />

          {/* Detection Details */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <InfoIcon fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Detection Details
              </Typography>
            </Stack>
            <Stack spacing={1}>
              {row.riskEventType && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Event Type</Typography>
                  <Chip label={row.riskEventType} size="small" variant="outlined" />
                </Stack>
              )}
              {row.riskDetail && (
                <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                  <Typography variant="body2" color="text.secondary">Detail</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500, textAlign: "right", maxWidth: "60%" }}>
                    {row.riskDetail}
                  </Typography>
                </Stack>
              )}
              {row.detectionTimingType && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Detection Timing</Typography>
                  <Chip label={row.detectionTimingType} size="small" variant="outlined" />
                </Stack>
              )}
              {row.activity && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Activity</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.activity}
                  </Typography>
                </Stack>
              )}
            </Stack>
          </Box>

          {/* Location & IP */}
          {(row.location || row.ipAddress) && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                  <LocationOn fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Location Information
                  </Typography>
                </Stack>
                <Stack spacing={1}>
                  {row.ipAddress && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">IP Address</Typography>
                      <Typography 
                        variant="caption" 
                        sx={{ 
                          fontFamily: "monospace",
                          bgcolor: alpha(theme.palette.text.primary, 0.05),
                          px: 1,
                          py: 0.25,
                          borderRadius: 0.5,
                        }}
                      >
                        {row.ipAddress}
                      </Typography>
                    </Stack>
                  )}
                  {row.location && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Location</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {typeof row.location === "object" 
                          ? [row.location.city, row.location.state, row.location.countryOrRegion].filter(Boolean).join(", ")
                          : row.location}
                      </Typography>
                    </Stack>
                  )}
                </Stack>
              </Box>
            </>
          )}

          {/* Timeline */}
          <Divider />
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <CalendarToday fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Timeline
              </Typography>
            </Stack>
            <Stack spacing={1}>
              {row.detectedDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Detected</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.detectedDateTime, "detectedDateTime")}
                  </Typography>
                </Stack>
              )}
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">User ID</Typography>
                <Typography 
                  variant="caption" 
                  sx={{ 
                    fontFamily: "monospace",
                    bgcolor: alpha(theme.palette.text.primary, 0.05),
                    px: 1,
                    py: 0.25,
                    borderRadius: 0.5,
                    maxWidth: 180,
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                  }}
                >
                  {row.userId}
                </Typography>
              </Stack>
            </Stack>
          </Box>
        </Stack>
      );
    },
  };

  const simpleColumns = [
    "detectedDateTime",
    "userPrincipalName",
    "location",
    "ipAddress",
    "riskState",
    "riskDetail",
    "riskLevel",
    "riskType",
    "riskEventType",
    "detectionTimingType",
    "activity",
  ];

  const filterList = [
    {
      filterName: "Users at Risk",
      value: [{ id: "riskState", value: "at Risk" }],
      type: "column",
    },
    {
      filterName: "Confirmed Compromised",
      value: [{ id: "riskState", value: "confirmedCompromised" }],
      type: "column",
    },
    {
      filterName: "Confirmed Safe",
      value: [{ id: "riskState", value: "confirmedSafe" }],
      type: "column",
    },
    {
      filterName: "Remediated",
      value: [{ id: "riskState", value: "remediated" }],
      type: "column",
    },
  ];

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl={apiUrl}
      apiData={{
        Endpoint: "identityProtection/riskDetections",
        manualPagination: true,
        $count: true,
        $orderby: "detectedDateTime desc",
        $top: 500,
      }}
      apiDataKey="Results"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      filters={filterList}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
