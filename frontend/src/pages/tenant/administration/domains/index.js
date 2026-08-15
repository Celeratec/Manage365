import { useState } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import {
  CheckCircle,
  Star,
  Delete,
  Language,
  VerifiedUser,
  AdminPanelSettings,
  Cancel,
  SwapHoriz,
} from "@mui/icons-material";
import { CippAddDomainDrawer } from "../../../../components/CippComponents/CippAddDomainDrawer.jsx";
import { CippDomainVerificationRecords } from "../../../../components/CippComponents/CippDomainVerificationRecords.jsx";
import { CippDomainServiceConfigurationRecords } from "../../../../components/CippComponents/CippDomainServiceConfigurationRecords.jsx";
import { CippDomainMigrationDialog } from "../../../../components/CippComponents/CippDomainMigrationDialog.jsx";
import { Box, Typography, Divider, Paper, Avatar, Chip, useTheme } from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Stack } from "@mui/system";
import { CippPropertyList } from "../../../../components/CippComponents/CippPropertyList";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { stringToColor } from "../../../../utils/get-initials";

const Page = () => {
  const pageTitle = "Domains";
  const apiUrl = "/api/ListGraphRequest";
  const theme = useTheme();
  const [migrationTarget, setMigrationTarget] = useState(null);

  // API Data configuration for the request
  const apiData = {
    Endpoint: "domains",
  };

  const simpleColumns = [
    "id",
    "authenticationType",
    "isAdminManaged",
    "isDefault",
    "isInitial",
    "isVerified",
  ];

  const offCanvas = {
    size: "lg",
    children: (row) => {
      const isVerified = row.isVerified;
      const isDefault = row.isDefault;
      const statusColor = isVerified ? theme.palette.success.main : theme.palette.warning.main;
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(statusColor, 0.15)} 0%, ${alpha(statusColor, 0.05)} 100%)`,
              borderLeft: `4px solid ${statusColor}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: stringToColor(row.id || "D"),
                  width: 56,
                  height: 56,
                }}
              >
                <Language />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.id}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {row.authenticationType || "Managed"} Authentication
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Status Badges */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Domain Status
            </Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                icon={isVerified ? <VerifiedUser fontSize="small" /> : <Cancel fontSize="small" />}
                label={isVerified ? "Verified" : "Not Verified"}
                color={isVerified ? "success" : "warning"}
                variant="filled"
                sx={{ fontWeight: 600 }}
              />
              {isDefault && (
                <Chip
                  icon={<Star fontSize="small" />}
                  label="Default"
                  color="primary"
                  variant="outlined"
                />
              )}
              {row.isInitial && (
                <Chip
                  label="Initial"
                  variant="outlined"
                  size="small"
                />
              )}
              {row.isAdminManaged && (
                <Chip
                  icon={<AdminPanelSettings fontSize="small" />}
                  label="Admin Managed"
                  variant="outlined"
                  size="small"
                />
              )}
            </Stack>
          </Box>

          {/* Supported Services */}
          {row.supportedServices?.length > 0 && (
            <>
              <Divider />
              <Box>
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1 }}>
                  Supported Services
                </Typography>
                <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
                  {row.supportedServices.map((service, index) => (
                    <Chip key={index} label={service} size="small" variant="outlined" />
                  ))}
                </Stack>
              </Box>
            </>
          )}

          <Divider />

          {/* Verification Records */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 2 }}>
              Verification Records
            </Typography>
            <CippDomainVerificationRecords row={row} />
          </Box>

          <Divider />

          {/* Service Configuration Records */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 2 }}>
              Service Configuration Records
            </Typography>
            <CippDomainServiceConfigurationRecords row={row} />
          </Box>
        </Stack>
      );
    },
  };

  return (
    <>
    <CippTablePage
      title={pageTitle}
      apiUrl={apiUrl}
      apiDataKey="Results"
      simpleColumns={simpleColumns}
      apiData={apiData}
      offCanvas={offCanvas}
      cardButton={
        <CippAddDomainDrawer
          buttonText="Add Domain"
          requiredPermissions={["Tenant.Administration.ReadWrite"]}
        />
      }
      actions={[
        {
          label: "Verify Domain",
          condition: (row) => !row.isVerified,
          type: "POST",
          icon: <CheckCircle />,
          url: "/api/ExecDomainAction",
          data: { domain: "id", Action: "verify" },
          confirmText:
            "Are you sure you want to verify this domain? Use one of the records below to complete verification.",
          children: ({ row }) => <CippDomainVerificationRecords row={row} />,
          size: "lg",
          category: "manage",
        },
        {
          label: "Set as Default",
          condition: (row) => !row.isDefault && row.isVerified,
          type: "POST",
          icon: <Star />,
          url: "/api/ExecDomainAction",
          data: { domain: "id", Action: "setDefault" },
          confirmText: "Are you sure you want to set [id] as the default domain?",
          multiPost: false,
          hideBulk: true,
          category: "edit",
        },
        {
          label: "Migrate Users to This Domain",
          condition: (row) => row.isVerified && !row.isInitial,
          icon: <SwapHoriz />,
          noConfirm: true,
          customFunction: (row) => {
            setMigrationTarget(row.id);
          },
          category: "manage",
        },
        {
          label: "Delete Domain",
          condition: (row) => !row.isDefault && !row.isInitial,
          type: "POST",
          icon: <Delete />,
          url: "/api/ExecDomainAction",
          data: { domain: "id", Action: "delete" },
          confirmText: "Are you sure you want to delete [id]? This action cannot be undone.",
          color: "error",
          multiPost: false,
          category: "danger",
        },
      ]}
    />
    {migrationTarget && (
      <CippDomainMigrationDialog
        open={!!migrationTarget}
        onClose={() => setMigrationTarget(null)}
        targetDomain={migrationTarget}
      />
    )}
    </>
  );
};

// Adding the layout for the dashboard
Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
