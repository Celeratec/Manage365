import { TabbedLayout } from "../../../../layouts/TabbedLayout";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import tabOptions from "../tabOptions";
import CippTablePage from "../../../../components/CippComponents/CippTablePage";
import CippGdapActions from "../../../../components/CippComponents/CippGdapActions";
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
  Handshake,
  CheckCircle,
  Pending,
  Cancel,
  Schedule,
  CalendarToday,
  Security,
} from "@mui/icons-material";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";

const pageTitle = "GDAP Relationships";

const actions = CippGdapActions();

const simpleColumns = [
  "customer.displayName",
  "displayName",
  "status",
  "createdDateTime",
  "activatedDateTime",
  "endDateTime",
  "autoExtendDuration",
  "accessDetails.unifiedRoles",
];

const filters = [
  {
    filterName: "Active",
    value: [{ id: "status", value: "active" }],
    type: "column",
  },
  {
    filterName: "Approval Pending",
    value: [{ id: "status", value: "approvalPending" }],
    type: "column",
  },
  {
    filterName: "Terminating",
    value: [{ id: "status", value: "terminating" }],
    type: "column",
  },
  {
    filterName: "Terminated",
    value: [{ id: "status", value: "terminated" }],
    type: "column",
  },
];

const apiUrl = "/api/ListGraphRequest";
const apiData = {
  Endpoint: "tenantRelationships/delegatedAdminRelationships",
  tenantFilter: "",
  $top: 300,
};

const Page = () => {
  const theme = useTheme();

  // Helper for status
  const getStatusInfo = (status) => {
    switch (String(status || "").toLowerCase()) {
      case "active":
        return { label: "Active", color: theme.palette.success.main, icon: <CheckCircle fontSize="small" /> };
      case "approvalpending":
        return { label: "Approval Pending", color: theme.palette.warning.main, icon: <Pending fontSize="small" /> };
      case "terminating":
        return { label: "Terminating", color: theme.palette.error.main, icon: <Schedule fontSize="small" /> };
      case "terminated":
        return { label: "Terminated", color: theme.palette.grey[500], icon: <Cancel fontSize="small" /> };
      default:
        return { label: status || "Unknown", color: theme.palette.grey[500], icon: <Pending fontSize="small" /> };
    }
  };

  const offCanvas = {
    actions: actions,
    children: (row) => {
      const statusInfo = getStatusInfo(row.status);
      const roles = row.accessDetails?.unifiedRoles || [];
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(statusInfo.color, 0.15)} 0%, ${alpha(statusInfo.color, 0.05)} 100%)`,
              borderLeft: `4px solid ${statusInfo.color}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: stringToColor(row.customer?.displayName || "G"),
                  width: 56,
                  height: 56,
                }}
              >
                <Handshake />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.customer?.displayName || "Unknown Customer"}
                </Typography>
                <Typography variant="body2" color="text.secondary" noWrap>
                  {row.displayName}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Status */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Relationship Status
            </Typography>
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
          </Box>

          <Divider />

          {/* Timeline */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <CalendarToday fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Timeline
              </Typography>
            </Stack>
            <Stack spacing={1}>
              {row.createdDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Created</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.createdDateTime, "createdDateTime")}
                  </Typography>
                </Stack>
              )}
              {row.activatedDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Activated</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.activatedDateTime, "activatedDateTime")}
                  </Typography>
                </Stack>
              )}
              {row.endDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">End Date</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.endDateTime, "endDateTime")}
                  </Typography>
                </Stack>
              )}
              {row.autoExtendDuration && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Auto Extend</Typography>
                  <Chip label={row.autoExtendDuration} size="small" variant="outlined" />
                </Stack>
              )}
            </Stack>
          </Box>

          {/* Roles */}
          {roles.length > 0 && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                  <Security fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Assigned Roles ({roles.length})
                  </Typography>
                </Stack>
                <Paper 
                  variant="outlined" 
                  sx={{ 
                    p: 1.5, 
                    borderRadius: 1.5,
                    backgroundColor: alpha(theme.palette.background.default, 0.5),
                    maxHeight: 200,
                    overflow: "auto",
                  }}
                >
                  <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
                    {roles.map((role, index) => (
                      <Chip 
                        key={index} 
                        label={role.roleDefinitionId || role} 
                        size="small" 
                        variant="outlined" 
                      />
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

  return (
    <CippTablePage
      title={pageTitle}
      tenantInTitle={false}
      apiUrl={apiUrl}
      apiData={apiData}
      apiDataKey="Results"
      queryKey="ListGDAPRelationships"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      maxHeightOffset="460px"
      filters={filters}
      defaultSorting={[{ id: "customer.displayName", desc: false }]}
    />
  );
};

Page.getLayout = (page) => (
  <DashboardLayout>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
);

export default Page;
