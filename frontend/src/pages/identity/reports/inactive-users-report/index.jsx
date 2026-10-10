import { Layout as DashboardLayout } from "../../../../layouts/index";
import { CippIcons } from "../../../../utils/icon-registry"
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { EyeIcon, TrashIcon } from "@heroicons/react/24/outline";
import { Paper, Avatar, Typography, Chip, Divider, useTheme } from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import { Edit, Block, Person, CalendarToday, Badge, Warning } from "@mui/icons-material";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";
import { useCippReportDB } from "../../../../components/CippComponents/CippReportDBControls";

const Page = () => {
  const pageTitle = "Inactive users (6 months)";
  const theme = useTheme();

  const reportDB = useCippReportDB({
    apiUrl: "/api/ListInactiveAccounts",
    queryKey: "inactive-users",
    cacheName: "Users",
    syncTitle: "Sync User Cache",
    allowToggle: false,
    defaultCached: true,
    cacheColumns: ["lastRefreshedDateTime"],
  });

  const actions = [
    {
      label: "View User",
      link: "/identity/administration/users/user?userId=[azureAdUserId]&tenantFilter=[tenantId]",
      pinned: true,
      multiPost: false,
      icon: <CippIcons.EyeIcon />,
      color: "success",
      category: "view",
    },
    {
      label: "Edit User",
      link: "/identity/administration/users/user/edit?userId=[azureAdUserId]&tenantFilter=[tenantId]",
      pinned: true,
      icon: <CippIcons.Edit />,
      color: "success",
      target: "_self",
      category: "edit",
    },
    {
      label: "Block Sign In",
      type: "POST",
      icon: <CippIcons.Block />,
      url: "/api/ExecDisableUser",
      data: { ID: "azureAdUserId" },
      confirmText: "Are you sure you want to block the sign-in for this user?",
      multiPost: false,
      category: "security",
      condition: (row) => row.accountEnabled !== false,
    },
    {
      label: "Delete User",
      type: "POST",
      icon: <CippIcons.Delete />,
      url: "/api/RemoveUser",
      data: { ID: "azureAdUserId" },
      confirmText: "Are you sure you want to delete this user?",
      multiPost: false,
      category: "danger",
    },
  ];

  const filters = [
    {
      filterName: "Sign-in allowed",
      value: [{ id: "accountEnabled", value: "Yes" }],
      type: "column",
    },
    {
      filterName: "Sign-in blocked",
      value: [{ id: "accountEnabled", value: "No" }],
      type: "column",
    },
  ];

  const offCanvas = {
    extendedInfoFields: [
      "tenantDisplayName",
      "displayName",
      "userPrincipalName",
      "accountEnabled",
      "userType",
      "createdDateTime",
      "lastSignInDateTime",
      "lastNonInteractiveSignInDateTime",
      "lastSuccessfulSignInDateTime",
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
    ...reportDB.cacheColumns.filter((c) => c === "Tenant"),
    "tenantDisplayName",
    "userPrincipalName",
    "displayName",
    "accountEnabled",
    "lastSignInDateTime",
    "lastNonInteractiveSignInDateTime",
    "lastSuccessfulSignInDateTime",
    "numberOfAssignedLicenses",
    "daysSinceLastSignIn",
    ...reportDB.cacheColumns.filter((c) => c !== "Tenant"),
  ];

  return (
    <>
      <CippTablePage
        title={pageTitle}
        apiUrl={reportDB.resolvedApiUrl}
        queryKey={reportDB.resolvedQueryKey}
        actions={actions}
        offCanvas={offCanvas}
        rowOpen={{
          link: '/identity/administration/users/user?userId=[azureAdUserId]&tenantFilter=[tenantId]',
          condition: (row) => Boolean(row?.azureAdUserId),
        }}
        simpleColumns={simpleColumns}
        filters={filters}
        dataSourceControls={reportDB.controls}
      />
      {reportDB.syncDialog}
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
