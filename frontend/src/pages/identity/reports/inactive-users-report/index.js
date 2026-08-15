import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { EyeIcon, TrashIcon } from "@heroicons/react/24/outline";
import {
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
  Button,
  SvgIcon,
  IconButton,
  Tooltip,
  Alert,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import { 
  Edit, 
  Block,
  Person,
  CalendarToday,
  Badge,
  Warning,
  Sync,
  Info,
} from "@mui/icons-material";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";
import { useSettings } from "../../../../hooks/use-settings";
import { useDialog } from "../../../../hooks/use-dialog";
import { CippApiDialog } from "../../../../components/CippComponents/CippApiDialog";

const Page = () => {
  const pageTitle = "Inactive users (6 months)";
  const apiUrl = "/api/ListInactiveAccounts";
  const theme = useTheme();
  const currentTenant = useSettings().currentTenant;
  const syncDialog = useDialog();
  const isAllTenants = currentTenant === "AllTenants";

  const actions = [
    {
      label: "View User",
      link: "/identity/administration/users/user?userId=[azureAdUserId]",
      multiPost: false,
      icon: <EyeIcon />,
      color: "success",
      category: "view",
    },
    {
      label: "Edit User",
      link: "/identity/administration/users/user/edit?userId=[azureAdUserId]",
      icon: <Edit />,
      color: "success",
      target: "_self",
      category: "edit",
    },
    {
      label: "Block Sign In",
      type: "POST",
      icon: <Block />,
      url: "/api/ExecDisableUser",
      data: { ID: "azureAdUserId" },
      confirmText: "Are you sure you want to block the sign-in for this user?",
      multiPost: false,
      category: "security",
    },
    {
      label: "Delete User",
      type: "POST",
      icon: <TrashIcon />,
      url: "/api/RemoveUser",
      data: { ID: "azureAdUserId" },
      confirmText: "Are you sure you want to delete this user?",
      multiPost: false,
      category: "danger",
    },
  ];

  const offCanvas = {
    extendedInfoFields: [
      "tenantDisplayName",
      "displayName",
      "userPrincipalName",
      "userType",
      "createdDateTime",
      "lastSignInDateTime",
      "lastNonInteractiveSignInDateTime",
      "numberOfAssignedLicenses",
      "daysSinceLastSignIn",
      "lastRefreshedDateTime",
    ],
    actions: actions,
    children: (row) => (
      <Stack spacing={3}>
        {/* Hero Section */}
        <Paper 
          elevation={0}
          sx={{ 
            p: 2.5,
            borderRadius: 2,
            background: `linear-gradient(135deg, ${alpha(theme.palette.warning.main, 0.15)} 0%, ${alpha(theme.palette.warning.main, 0.05)} 100%)`,
            borderLeft: `4px solid ${theme.palette.warning.main}`,
          }}
        >
          <Stack direction="row" spacing={2} alignItems="center">
            <Avatar
              sx={{
                bgcolor: stringToColor(row.displayName || "U"),
                width: 56,
                height: 56,
                fontSize: "1.25rem",
                fontWeight: 600,
              }}
            >
              {getInitials(row.displayName || "User")}
            </Avatar>
            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                {row.displayName || "Unknown User"}
              </Typography>
              <Typography variant="body2" color="text.secondary" noWrap>
                {row.userPrincipalName}
              </Typography>
            </Box>
          </Stack>
        </Paper>

        {/* Inactive Status */}
        <Box>
          <Typography 
            variant="overline" 
            color="text.secondary" 
            sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
          >
            Account Status
          </Typography>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Chip
              icon={<Warning fontSize="small" />}
              label="Inactive"
              color="warning"
              variant="filled"
              sx={{ fontWeight: 600 }}
            />
            {row.userType && (
              <Chip
                label={row.userType}
                variant="outlined"
                size="small"
              />
            )}
            {row.numberOfAssignedLicenses > 0 && (
              <Chip
                label={`${row.numberOfAssignedLicenses} License${row.numberOfAssignedLicenses !== 1 ? "s" : ""}`}
                color="info"
                variant="outlined"
                size="small"
              />
            )}
          </Stack>
        </Box>

        <Divider />

        {/* User Details */}
        <Box>
          <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
            <Person fontSize="small" color="action" />
            <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
              User Details
            </Typography>
          </Stack>
          <Stack spacing={1}>
            <Stack direction="row" justifyContent="space-between" alignItems="center">
              <Typography variant="body2" color="text.secondary">Tenant</Typography>
              <Typography variant="body2" sx={{ fontWeight: 500 }}>
                {row.tenantDisplayName}
              </Typography>
            </Stack>
            {row.userType && (
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">User Type</Typography>
                <Chip label={row.userType} size="small" variant="outlined" />
              </Stack>
            )}
            <Stack direction="row" justifyContent="space-between" alignItems="center">
              <Typography variant="body2" color="text.secondary">Assigned Licenses</Typography>
              <Typography variant="body2" sx={{ fontWeight: 500 }}>
                {row.numberOfAssignedLicenses || 0}
              </Typography>
            </Stack>
          </Stack>
        </Box>

        {/* Activity Timeline */}
        <Divider />
        <Box>
          <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
            <CalendarToday fontSize="small" color="action" />
            <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
              Activity Timeline
            </Typography>
          </Stack>
          <Stack spacing={1}>
            {row.createdDateTime && (
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Account Created</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {getCippFormatting(row.createdDateTime, "createdDateTime")}
                </Typography>
              </Stack>
            )}
            {row.lastSignInDateTime && (
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Last Interactive Sign-in</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500, color: "warning.main" }}>
                  {getCippFormatting(row.lastSignInDateTime, "lastSignInDateTime")}
                </Typography>
              </Stack>
            )}
            {row.lastNonInteractiveSignInDateTime && (
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Last Non-Interactive Sign-in</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {getCippFormatting(row.lastNonInteractiveSignInDateTime, "lastNonInteractiveSignInDateTime")}
                </Typography>
              </Stack>
            )}
            {row.lastRefreshedDateTime && (
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Data Last Refreshed</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {getCippFormatting(row.lastRefreshedDateTime, "lastRefreshedDateTime")}
                </Typography>
              </Stack>
            )}
          </Stack>
        </Box>
      </Stack>
    ),
  };

  const simpleColumns = [
    "tenantDisplayName",
    "userPrincipalName",
    "displayName",
    "lastSignInDateTime",
    "lastNonInteractiveSignInDateTime",
    "numberOfAssignedLicenses",
    "daysSinceLastSignIn",
    "lastRefreshedDateTime",
  ];

  const pageActions = [
    <Stack direction="row" spacing={2} alignItems="center" key="actions-stack">
      <Tooltip title="This report displays cached data from the Manage365 reporting database. Cache timestamps are shown in the table. Click the Sync button to update the user cache for the current tenant.">
        <IconButton size="small">
          <Info fontSize="small" />
        </IconButton>
      </Tooltip>
      <Button
        startIcon={
          <SvgIcon fontSize="small">
            <Sync />
          </SvgIcon>
        }
        size="xs"
        onClick={syncDialog.handleOpen}
        disabled={isAllTenants}
      >
        Sync
      </Button>
    </Stack>,
  ];

  return (
    <>
      {currentTenant && currentTenant !== "" ? (
        <CippTablePage
          title={pageTitle}
          apiUrl={apiUrl}
          queryKey={["inactive-users", currentTenant]}
          actions={actions}
          offCanvas={offCanvas}
          simpleColumns={simpleColumns}
          cardButton={pageActions}
        />
      ) : (
        <Alert severity="warning">Please select a tenant to view inactive users.</Alert>
      )}
      <CippApiDialog
        createDialog={syncDialog}
        title="Sync User Cache"
        fields={[]}
        api={{
          type: "GET",
          url: "/api/ExecCIPPDBCache",
          confirmText: `Run user cache sync for ${currentTenant}? This will update user data including sign-in activity immediately.`,
          relatedQueryKeys: ["inactive-users"],
          data: {
            Name: "Users",
          },
        }}
      />
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
