import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
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
  Assignment, 
  Done,
  Warning,
  Error as ErrorIcon,
  Info as InfoIcon,
  CheckCircle,
  Pending,
  Person,
  CalendarToday,
  Category as CategoryIcon,
} from "@mui/icons-material";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";

const Page = () => {
  const pageTitle = "Alerts List";
  const theme = useTheme();

  // Define actions for alerts
  const actions = [
    {
      label: "Set status to in progress",
      type: "POST",
      icon: <Assignment />,
      url: "/api/ExecSetSecurityAlert",
      data: {
        GUID: "Id",
        Status: "!inProgress",
        Vendor: "RawResult.vendorInformation.vendor",
        Provider: "RawResult.vendorInformation.provider",
      },
      confirmText: "Are you sure you want to set the status to in progress?",
      category: "edit",
    },
    {
      label: "Set status to resolved",
      type: "POST",
      icon: <Done />,
      url: "/api/ExecSetSecurityAlert",
      data: {
        GUID: "Id",
        Status: "!resolved",
        Vendor: "RawResult.vendorInformation.vendor",
        Provider: "RawResult.vendorInformation.provider",
      },
      confirmText: "Are you sure you want to set the status to resolved?",
      category: "edit",
    },
  ];

  // Helper functions
  const getSeverityInfo = (severity) => {
    switch (String(severity || "").toLowerCase()) {
      case "high":
        return { label: "High", color: theme.palette.error.main, icon: <ErrorIcon fontSize="small" /> };
      case "medium":
        return { label: "Medium", color: theme.palette.warning.main, icon: <Warning fontSize="small" /> };
      case "low":
        return { label: "Low", color: theme.palette.info.main, icon: <InfoIcon fontSize="small" /> };
      case "informational":
        return { label: "Informational", color: theme.palette.grey[500], icon: <InfoIcon fontSize="small" /> };
      default:
        return { label: severity || "Unknown", color: theme.palette.grey[500], icon: <InfoIcon fontSize="small" /> };
    }
  };

  const getStatusInfo = (status) => {
    switch (String(status || "").toLowerCase()) {
      case "resolved":
        return { label: "Resolved", color: theme.palette.success.main, icon: <CheckCircle fontSize="small" /> };
      case "inprogress":
        return { label: "In Progress", color: theme.palette.warning.main, icon: <Assignment fontSize="small" /> };
      case "new":
      case "newalert":
        return { label: "New", color: theme.palette.error.main, icon: <Pending fontSize="small" /> };
      default:
        return { label: status || "Unknown", color: theme.palette.grey[500], icon: <Pending fontSize="small" /> };
    }
  };

  // Define off-canvas details
  const offCanvas = {
    actions: actions,
    children: (row) => {
      const severityInfo = getSeverityInfo(row.Severity);
      const statusInfo = getStatusInfo(row.Status);
      const involvedUsers = row.InvolvedUsers ? (Array.isArray(row.InvolvedUsers) ? row.InvolvedUsers : [row.InvolvedUsers]) : [];
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(severityInfo.color, 0.15)} 0%, ${alpha(severityInfo.color, 0.05)} 100%)`,
              borderLeft: `4px solid ${severityInfo.color}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: severityInfo.color,
                  width: 56,
                  height: 56,
                }}
              >
                {severityInfo.icon}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.Title || "Unknown Alert"}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {row.Tenant}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Status & Severity */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Alert Status
            </Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                icon={statusInfo.icon}
                label={statusInfo.label}
                sx={{ 
                  fontWeight: 600, 
                  bgcolor: alpha(statusInfo.color, 0.1),
                  color: statusInfo.color,
                  borderColor: statusInfo.color,
                }}
                variant="outlined"
              />
              <Chip
                icon={severityInfo.icon}
                label={`Severity: ${severityInfo.label}`}
                color={severityInfo.label === "High" ? "error" : severityInfo.label === "Medium" ? "warning" : "info"}
                variant="filled"
                size="small"
              />
            </Stack>
          </Box>

          <Divider />

          {/* Alert Details */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <CategoryIcon fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Alert Details
              </Typography>
            </Stack>
            <Stack spacing={1}>
              {row.Category && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Category</Typography>
                  <Chip label={row.Category} size="small" variant="outlined" />
                </Stack>
              )}
              {row.EventDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Event Time</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.EventDateTime, "EventDateTime")}
                  </Typography>
                </Stack>
              )}
            </Stack>
          </Box>

          {/* Involved Users */}
          {involvedUsers.length > 0 && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                  <Person fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Involved Users ({involvedUsers.length})
                  </Typography>
                </Stack>
                <Paper 
                  variant="outlined" 
                  sx={{ 
                    p: 1.5, 
                    borderRadius: 1.5,
                    backgroundColor: alpha(theme.palette.background.default, 0.5),
                    maxHeight: 150,
                    overflow: "auto",
                  }}
                >
                  <Stack spacing={0.5}>
                    {involvedUsers.map((user, index) => (
                      <Typography key={index} variant="body2" color="text.secondary">
                        {typeof user === "object" ? user.userPrincipalName || user.displayName || JSON.stringify(user) : user}
                      </Typography>
                    ))}
                  </Stack>
                </Paper>
              </Box>
            </>
          )}
        </Stack>
      );
    },
  };

  // Simplified columns for the table
  const simpleColumns = [
    "EventDateTime", // Created Date (Local)
    "Status", // Status
    "Title", // Title
    "Severity", // Severity
    "Category", // Category
    "Tenant", // Tenant
  ];

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ExecAlertsList"
      apiDataKey="Results.MSResults"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
