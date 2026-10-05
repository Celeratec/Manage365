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
  RestoreFromTrash, 
  Warning,
  Delete,
  Person,
  Group,
  CalendarToday,
  Work,
  Phone,
  Email,
  LocationOn,
} from "@mui/icons-material";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";

const Page = () => {
  const pageTitle = "Deleted Items";
  const theme = useTheme();

  const actions = [
    {
      label: "Restore Object",
      type: "POST",
      icon: <RestoreFromTrash />,
      url: "/api/ExecRestoreDeleted",
      data: { ID: "id", userPrincipalName: "userPrincipalName", displayName: "displayName" },
      confirmText: "Are you sure you want to restore this object?",
      multiPost: false,
      category: "edit",
    },
    {
      label: "Permanently Delete Object",
      type: "POST",
      icon: <Warning />,
      url: "/api/RemoveDeletedObject",
      data: { ID: "id", userPrincipalName: "userPrincipalName", displayName: "displayName" },
      confirmText:
        "Are you sure you want to permanently delete this object? This action cannot be undone.",
      multiPost: false,
      category: "danger",
    },
  ];

  const offCanvas = {
    actions: actions,
    children: (row) => {
      const isUser = row.TargetType === "User";
      const isGroup = row.TargetType === "Group";
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(theme.palette.error.main, 0.15)} 0%, ${alpha(theme.palette.error.main, 0.05)} 100%)`,
              borderLeft: `4px solid ${theme.palette.error.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: stringToColor(row.displayName || "D"),
                  width: 56,
                  height: 56,
                  fontSize: "1.25rem",
                  fontWeight: 600,
                }}
              >
                {isUser ? getInitials(row.displayName || "User") : isGroup ? <Group /> : <Delete />}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.displayName || "Unknown Item"}
                </Typography>
                <Typography variant="body2" color="text.secondary" noWrap>
                  {row.userPrincipalName || row.mail}
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
              Item Status
            </Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                icon={<Delete fontSize="small" />}
                label="Deleted"
                color="error"
                variant="filled"
                sx={{ fontWeight: 600 }}
              />
              <Chip
                icon={isUser ? <Person fontSize="small" /> : <Group fontSize="small" />}
                label={row.TargetType || "Unknown"}
                variant="outlined"
              />
              {row.onPremisesSyncEnabled && (
                <Chip
                  label="AD Synced"
                  color="info"
                  variant="outlined"
                  size="small"
                />
              )}
            </Stack>
          </Box>

          <Divider />

          {/* User Details (if user) */}
          {isUser && (
            <Box>
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                <Person fontSize="small" color="action" />
                <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                  User Details
                </Typography>
              </Stack>
              <Stack spacing={1}>
                {(row.givenName || row.surname) && (
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="body2" color="text.secondary">Full Name</Typography>
                    <Typography variant="body2" sx={{ fontWeight: 500 }}>
                      {[row.givenName, row.surname].filter(Boolean).join(" ")}
                    </Typography>
                  </Stack>
                )}
                {row.jobTitle && (
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="body2" color="text.secondary">Job Title</Typography>
                    <Typography variant="body2" sx={{ fontWeight: 500 }}>
                      {row.jobTitle}
                    </Typography>
                  </Stack>
                )}
                {row.department && (
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="body2" color="text.secondary">Department</Typography>
                    <Typography variant="body2" sx={{ fontWeight: 500 }}>
                      {row.department}
                    </Typography>
                  </Stack>
                )}
              </Stack>
            </Box>
          )}

          {/* Contact Info */}
          {(row.mail || row.businessPhones?.length > 0 || row.mobilePhone) && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                  <Email fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Contact Information
                  </Typography>
                </Stack>
                <Stack spacing={1}>
                  {row.mail && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Email</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }} noWrap>
                        {row.mail}
                      </Typography>
                    </Stack>
                  )}
                  {row.businessPhones?.[0] && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Business Phone</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.businessPhones[0]}
                      </Typography>
                    </Stack>
                  )}
                  {row.mobilePhone && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Mobile Phone</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.mobilePhone}
                      </Typography>
                    </Stack>
                  )}
                  {row.city && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">City</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.city}
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
              {row.createdDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Created</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.createdDateTime, "createdDateTime")}
                  </Typography>
                </Stack>
              )}
              {row.deletedDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Deleted</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500, color: "error.main" }}>
                    {getCippFormatting(row.deletedDateTime, "deletedDateTime")}
                  </Typography>
                </Stack>
              )}
              {row.onPremisesLastSyncDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Last AD Sync</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.onPremisesLastSyncDateTime, "onPremisesLastSyncDateTime")}
                  </Typography>
                </Stack>
              )}
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">ID</Typography>
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
                  {row.id}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          {/* Licenses */}
          {row.LicJoined && (
            <>
              <Divider />
              <Box>
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1 }}>
                  Licenses
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {row.LicJoined}
                </Typography>
              </Box>
            </>
          )}
        </Stack>
      );
    },
  };

  const columns = [
    "displayName", // Display Name
    "TargetType", // Type
    "userPrincipalName", // User Principal Name
    "deletedDateTime", // Deleted on
    "onPremisesSyncEnabled", // AD Synced
  ];

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListDeletedItems"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={columns}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
