import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { useRouter } from "next/router";
import { useSettings } from "../../../../hooks/use-settings";
import { ApiGetCall, ApiPostCall } from "../../../../api/ApiCall";
import { CippExchangeActions } from "../../../../components/CippComponents/CippExchangeActions";
import { useDialog } from "../../../../hooks/use-dialog";
import { CippApiDialog } from "../../../../components/CippComponents/CippApiDialog";
import {
  Alert,
  Avatar,
  Button,
  Chip,
  CircularProgress,
  Container,
  Divider,
  Paper,
  Tooltip,
  Typography,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Grid, Stack } from "@mui/system";
import {
  ArrowBack,
  Email,
  Person,
  Group,
  MeetingRoom,
  Devices,
  AlternateEmail,
  ContentCopy,
  CheckCircle,
  Cancel,
  Archive,
  Gavel,
  Visibility,
  VisibilityOff,
  Settings,
  Storage,
} from "@mui/icons-material";
import Link from "next/link";
import { getInitials, stringToColor } from "../../../../utils/get-initials";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { useMemo } from "react";

const getMailboxTypeInfo = (type) => {
  switch (type) {
    case "SharedMailbox":
      return { label: "Shared Mailbox", color: "#7c4dff", icon: <Group fontSize="small" /> };
    case "RoomMailbox":
      return { label: "Room Mailbox", color: "#ff9800", icon: <MeetingRoom fontSize="small" /> };
    case "EquipmentMailbox":
      return { label: "Equipment Mailbox", color: "#607d8b", icon: <Devices fontSize="small" /> };
    case "UserMailbox":
    default:
      return { label: "User Mailbox", color: "#1976d2", icon: <Person fontSize="small" /> };
  }
};

const StatBox = ({ label, value, color = "primary.main" }) => (
  <Box sx={{ textAlign: "center", px: 3 }}>
    <Typography variant="h5" sx={{ fontWeight: 700, color }}>{value}</Typography>
    <Typography variant="caption" color="text.secondary">{label}</Typography>
  </Box>
);

const InfoRow = ({ label, value, mono = false }) => {
  if (!value) return null;
  return (
    <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ py: 0.5 }}>
      <Typography variant="body2" color="text.secondary">{label}</Typography>
      <Typography
        variant="body2"
        sx={{
          fontWeight: 500,
          maxWidth: "60%",
          textAlign: "right",
          wordBreak: "break-all",
          ...(mono && {
            fontFamily: "monospace",
            fontSize: "0.8rem",
            bgcolor: (t) => alpha(t.palette.text.primary, 0.05),
            px: 1,
            py: 0.25,
            borderRadius: 0.5,
          }),
        }}
      >
        {value}
      </Typography>
    </Stack>
  );
};

const Page = () => {
  const router = useRouter();
  const { mailboxId } = router.query;
  const tenant = useSettings().currentTenant;

  const mailboxData = ApiGetCall({
    url: "/api/ListMailboxes",
    data: { tenantFilter: tenant, SkipCache: true },
    queryKey: `mailbox-${mailboxId}-${tenant}`,
    waiting: !!(mailboxId && tenant),
  });

  const mailbox = useMemo(() => {
    if (!mailboxData.data) return null;
    const data = Array.isArray(mailboxData.data) ? mailboxData.data : [mailboxData.data];
    return data.find(
      (m) => m.ExternalDirectoryObjectId === mailboxId || m.Guid === mailboxId || m.UPN === mailboxId
    ) || data[0] || null;
  }, [mailboxData.data, mailboxId]);

  const typeInfo = mailbox ? getMailboxTypeInfo(mailbox.recipientTypeDetails) : getMailboxTypeInfo("UserMailbox");
  const aliases = useMemo(() => {
    if (!mailbox?.AdditionalEmailAddresses) return [];
    return Array.isArray(mailbox.AdditionalEmailAddresses)
      ? mailbox.AdditionalEmailAddresses
      : [mailbox.AdditionalEmailAddresses];
  }, [mailbox]);

  if (!mailboxId || !tenant) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/email/administration/mailboxes" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Mailboxes
        </Button>
        <Alert severity="warning">No mailbox selected. Please select a mailbox from the list.</Alert>
      </Container>
    );
  }

  if (mailboxData.isLoading) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/email/administration/mailboxes" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Mailboxes
        </Button>
        <Box sx={{ display: "flex", justifyContent: "center", py: 8 }}>
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  if (mailboxData.isError || !mailbox) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/email/administration/mailboxes" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Mailboxes
        </Button>
        <Alert severity="error">Failed to load mailbox details. Please try again.</Alert>
      </Container>
    );
  }

  return (
    <Container maxWidth={false} sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Button
          component={Link}
          href="/email/administration/mailboxes"
          startIcon={<ArrowBack />}
          sx={{ alignSelf: "flex-start" }}
        >
          Back to Mailboxes
        </Button>

        {/* Hero + Stats Row */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, lg: 7 }}>
            <Paper
              elevation={0}
              sx={{
                p: 3,
                borderRadius: 2,
                background: `linear-gradient(135deg, ${alpha(typeInfo.color, 0.12)} 0%, ${alpha(typeInfo.color, 0.04)} 100%)`,
                borderLeft: `4px solid ${typeInfo.color}`,
                height: "100%",
              }}
            >
              <Stack direction="row" spacing={2} alignItems="center">
                <Avatar
                  sx={{
                    bgcolor: stringToColor(mailbox.displayName || "M"),
                    width: 56,
                    height: 56,
                    fontSize: "1.25rem",
                    fontWeight: 600,
                  }}
                >
                  {getInitials(mailbox.displayName || "Mailbox")}
                </Avatar>
                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5 }}>
                    {mailbox.displayName || "Unknown Mailbox"}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" noWrap sx={{ mb: 1 }}>
                    {mailbox.primarySmtpAddress}
                  </Typography>
                  <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                    <Chip
                      icon={typeInfo.icon}
                      label={typeInfo.label}
                      size="small"
                      sx={{
                        fontWeight: 600,
                        bgcolor: alpha(typeInfo.color, 0.1),
                        color: typeInfo.color,
                        borderColor: typeInfo.color,
                      }}
                      variant="outlined"
                    />
                    {mailbox.ArchiveGuid && mailbox.ArchiveGuid !== "00000000-0000-0000-0000-000000000000" && (
                      <Tooltip title="Online Archive is enabled">
                        <Chip icon={<Archive fontSize="small" />} label="Archive" size="small" color="info" variant="outlined" />
                      </Tooltip>
                    )}
                    {mailbox.LitigationHoldEnabled && (
                      <Tooltip title="Litigation Hold is active">
                        <Chip icon={<Gavel fontSize="small" />} label="Litigation Hold" size="small" color="warning" variant="outlined" />
                      </Tooltip>
                    )}
                    {mailbox.HiddenFromAddressListsEnabled && (
                      <Tooltip title="Hidden from Global Address List">
                        <Chip icon={<VisibilityOff fontSize="small" />} label="Hidden from GAL" size="small" color="default" variant="outlined" />
                      </Tooltip>
                    )}
                    {mailbox.ExternalDirectoryObjectId && (
                      <Tooltip title="View Exchange settings for this user">
                        <Chip
                          icon={<Settings fontSize="small" />}
                          label="Exchange Settings"
                          size="small"
                          color="primary"
                          variant="outlined"
                          onClick={() => router.push(`/identity/administration/users/user/exchange?userId=${mailbox.ExternalDirectoryObjectId}`)}
                          sx={{ cursor: "pointer" }}
                        />
                      </Tooltip>
                    )}
                  </Stack>
                </Box>
              </Stack>
            </Paper>
          </Grid>
          <Grid size={{ xs: 12, lg: 5 }}>
            <Paper
              variant="outlined"
              sx={{
                p: 2,
                borderRadius: 2,
                height: "100%",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Stack direction="row" divider={<Divider orientation="vertical" flexItem />} spacing={0}>
                <StatBox label="Aliases" value={aliases.length} />
                <StatBox
                  label="Recipient Type"
                  value={mailbox.recipientType || "—"}
                  color="text.primary"
                />
              </Stack>
            </Paper>
          </Grid>
        </Grid>

        {/* Email Information + Aliases */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, md: 6 }}>
            <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                <Email fontSize="small" color="action" />
                <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                  Email Information
                </Typography>
              </Stack>
              <Stack spacing={0.5}>
                <InfoRow label="Primary Address" value={mailbox.primarySmtpAddress} />
                {mailbox.UPN && mailbox.UPN !== mailbox.primarySmtpAddress && (
                  <InfoRow label="UPN" value={mailbox.UPN} />
                )}
                <InfoRow label="Recipient Type" value={mailbox.recipientType} />
                <InfoRow label="Recipient Type Details" value={mailbox.recipientTypeDetails} />
                <InfoRow label="Exchange GUID" value={mailbox.ExchangeGuid} mono />
                <InfoRow label="External Directory Object ID" value={mailbox.ExternalDirectoryObjectId} mono />
              </Stack>
            </Paper>
          </Grid>
          <Grid size={{ xs: 12, md: 6 }}>
            <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2, height: "100%" }}>
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                <AlternateEmail fontSize="small" color="action" />
                <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                  Email Aliases ({aliases.length})
                </Typography>
              </Stack>
              {aliases.length > 0 ? (
                <Paper
                  variant="outlined"
                  sx={{
                    p: 1.5,
                    borderRadius: 1.5,
                    bgcolor: (t) => alpha(t.palette.background.default, 0.5),
                    maxHeight: 200,
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
              ) : (
                <Typography variant="body2" color="text.secondary" sx={{ fontStyle: "italic" }}>
                  No additional email aliases configured.
                </Typography>
              )}
            </Paper>
          </Grid>
        </Grid>
      </Stack>
    </Container>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
