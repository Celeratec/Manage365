import { useCallback } from "react";
import { useRouter } from "next/router";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import CippExchangeActions from "../../../../components/CippComponents/CippExchangeActions";
import { CippHVEUserDrawer } from "../../../../components/CippComponents/CippHVEUserDrawer.jsx";
import { CippSharedMailboxDrawer } from "../../../../components/CippComponents/CippSharedMailboxDrawer.jsx";
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
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import { 
  Group, 
  Email,
  MeetingRoom,
  Devices,
  Person,
  Inbox,
  AlternateEmail,
  Sync,
  Info,
} from "@mui/icons-material";
import { getInitials, stringToColor } from "../../../../utils/get-initials";
import { useSettings } from "../../../../hooks/use-settings";
import { useDialog } from "../../../../hooks/use-dialog";
import { CippApiDialog } from "../../../../components/CippComponents/CippApiDialog";
import { useState } from "react";
import { CippQueueTracker } from "../../../../components/CippTable/CippQueueTracker";

const Page = () => {
  const pageTitle = "Mailboxes";
  const theme = useTheme();
  const router = useRouter();
  const currentTenant = useSettings().currentTenant;
  const syncDialog = useDialog();
  const [syncQueueId, setSyncQueueId] = useState(null);

  const isAllTenants = currentTenant === "AllTenants";

  const apiData = {
    UseReportDB: true,
  };

  const handleCardClick = useCallback((mailbox) => {
    router.push(`/email/administration/mailboxes/view?mailboxId=${encodeURIComponent(mailbox.ExternalDirectoryObjectId || mailbox.Guid || mailbox.UPN || "")}`);
  }, [router]);

  const cardConfig = {
    title: "displayName",
    subtitle: "primarySmtpAddress",
    avatar: {
      field: "displayName",
    },
    badges: [
      {
        field: "recipientTypeDetails",
        conditions: {
          UserMailbox: { label: "User", color: "primary", icon: <Person fontSize="small" /> },
          SharedMailbox: { label: "Shared", color: "info", icon: <Group fontSize="small" />, tooltip: "Multiple users can access this mailbox" },
          RoomMailbox: { label: "Room", color: "warning", icon: <MeetingRoom fontSize="small" />, tooltip: "Bookable meeting room" },
          EquipmentMailbox: { label: "Equipment", color: "default", icon: <Devices fontSize="small" />, tooltip: "Bookable equipment" },
        },
      },
    ],
    extraFields: [
      { field: "UPN", icon: <Person />, maxLines: 1 },
    ],
    desktopFields: [
      { field: "recipientType", label: "Type", icon: <Inbox /> },
      { field: "AdditionalEmailAddresses", label: "Aliases", icon: <AlternateEmail /> },
    ],
    cardGridProps: {
      md: 6,
      lg: 4,
    },
    mobileQuickActions: [
      "Edit permissions",
      "Convert Mailbox",
      "Set Global Address List visibility",
      "Enable Online Archive",
      "Delete Mailbox",
    ],
    maxQuickActions: 8,
  };

  const getMailboxTypeInfo = (type) => {
    switch (type) {
      case "SharedMailbox":
        return { label: "Shared Mailbox", color: theme.palette.secondary.main, icon: <Group fontSize="small" /> };
      case "RoomMailbox":
        return { label: "Room Mailbox", color: theme.palette.info.main, icon: <MeetingRoom fontSize="small" /> };
      case "EquipmentMailbox":
        return { label: "Equipment Mailbox", color: theme.palette.warning.main, icon: <Devices fontSize="small" /> };
      case "UserMailbox":
      default:
        return { label: "User Mailbox", color: theme.palette.primary.main, icon: <Person fontSize="small" /> };
    }
  };

  // Define off-canvas details
  const offCanvas = {
    actions: CippExchangeActions(),
    children: (row) => {
      const typeInfo = getMailboxTypeInfo(row.recipientTypeDetails);
      const aliases = row.AdditionalEmailAddresses 
        ? (Array.isArray(row.AdditionalEmailAddresses) ? row.AdditionalEmailAddresses : [row.AdditionalEmailAddresses])
        : [];
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(typeInfo.color, 0.15)} 0%, ${alpha(typeInfo.color, 0.05)} 100%)`,
              borderLeft: `4px solid ${typeInfo.color}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: stringToColor(row.displayName || "M"),
                  width: 56,
                  height: 56,
                  fontSize: "1.25rem",
                  fontWeight: 600,
                }}
              >
                {getInitials(row.displayName || "Mailbox")}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.displayName || "Unknown Mailbox"}
                </Typography>
                <Typography variant="body2" color="text.secondary" noWrap>
                  {row.primarySmtpAddress}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Mailbox Type */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Mailbox Type
            </Typography>
            <Chip
              icon={typeInfo.icon}
              label={typeInfo.label}
              sx={{ 
                fontWeight: 600, 
                bgcolor: alpha(typeInfo.color, 0.1),
                color: typeInfo.color,
                borderColor: typeInfo.color,
              }}
              variant="outlined"
            />
          </Box>

          <Divider />

          {/* Email Information */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <Email fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Email Information
              </Typography>
            </Stack>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Primary Address</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }} noWrap>
                  {row.primarySmtpAddress}
                </Typography>
              </Stack>
              {row.UPN && row.UPN !== row.primarySmtpAddress && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">UPN</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }} noWrap>
                    {row.UPN}
                  </Typography>
                </Stack>
              )}
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Recipient Type</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.recipientType}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          {/* Email Aliases */}
          {aliases.length > 0 && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                  <AlternateEmail fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Email Aliases ({aliases.length})
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
                    {aliases.map((alias, index) => (
                      <Typography key={index} variant="body2" color="text.secondary">
                        {alias}
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

  const filterList = [
    {
      filterName: "View User Mailboxes",
      value: [{ id: "recipientTypeDetails", value: "UserMailbox" }],
      type: "column",
    },
    {
      filterName: "View Shared Mailboxes",
      value: [{ id: "recipientTypeDetails", value: "SharedMailbox" }],
      type: "column",
    },
    {
      filterName: "View Room Mailboxes",
      value: [{ id: "recipientTypeDetails", value: "RoomMailbox" }],
      type: "column",
    },
    {
      filterName: "View Equipment Mailboxes",
      value: [{ id: "recipientTypeDetails", value: "EquipmentMailbox" }],
      type: "column",
    },
  ];

  // Simplified columns for the table
  const simpleColumns = isAllTenants
    ? [
        "Tenant", // Tenant
        "displayName", // Display Name
        "recipientTypeDetails", // Recipient Type Details
        "UPN", // User Principal Name
        "primarySmtpAddress", // Primary Email Address
        "AdditionalEmailAddresses", // Additional Email Addresses
        "CacheTimestamp", // Cache Timestamp
      ]
    : [
        "displayName", // Display Name
        "recipientTypeDetails", // Recipient Type Details
        "UPN", // User Principal Name
        "primarySmtpAddress", // Primary Email Address
        "AdditionalEmailAddresses", // Additional Email Addresses
        "CacheTimestamp", // Cache Timestamp
      ];

  return (
    <>
      <CippTablePage
        title={pageTitle}
        apiUrl="/api/ListMailboxes"
        apiData={apiData}
        queryKey={`ListMailboxes-${currentTenant}`}
        actions={CippExchangeActions()}
        offCanvas={offCanvas}
        simpleColumns={simpleColumns}
        filters={filterList}
        cardButton={
          <Stack direction="row" spacing={1} alignItems="center">
            <CippSharedMailboxDrawer />
            <CippHVEUserDrawer />
            <CippQueueTracker
              queueId={syncQueueId}
              queryKey={`ListMailboxes-${currentTenant}`}
              title="Mailboxes Sync"
            />
            <Tooltip title="This report displays cached data from the Manage365 reporting database. Click the Sync button to update the cache for the current tenant.">
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
            >
              Sync
            </Button>
          </Stack>
        }
        cardConfig={cardConfig}
        onCardClick={handleCardClick}
        offCanvasOnRowClick={true}
      />
      <CippApiDialog
        createDialog={syncDialog}
        title="Sync Mailboxes"
        fields={[]}
        api={{
          type: "GET",
          url: "/api/ExecCIPPDBCache",
          confirmText: `Run mailboxes cache sync for ${currentTenant}? This will update mailbox data immediately.`,
          relatedQueryKeys: [`ListMailboxes-${currentTenant}`],
          data: {
            Name: "Mailboxes",
            Types: "None",
          },
          onSuccess: (response) => {
            if (response?.Metadata?.QueueId) {
              setSyncQueueId(response.Metadata.QueueId);
            }
          },
        }}
      />
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout allTenantsSupport={true}>{page}</DashboardLayout>;

export default Page;
