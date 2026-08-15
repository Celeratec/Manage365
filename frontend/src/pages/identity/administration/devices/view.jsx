import { useMemo } from "react";
import { useRouter } from "next/router";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { useSettings } from "../../../../hooks/use-settings";
import { ApiGetCall } from "../../../../api/ApiCall";
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
  CheckCircle,
  Cancel,
  VerifiedUser,
  Info as InfoIcon,
  CalendarToday,
  Computer,
  PhoneAndroid,
  PhoneIphone,
  Laptop,
  Dns,
  WifiOff,
  Wifi,
  CheckCircleOutline,
  Block,
  VpnKey,
  DeleteForever,
} from "@mui/icons-material";
import Link from "next/link";
import { stringToColor } from "../../../../utils/get-initials";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";

const getOSIcon = (os) => {
  if (!os) return <Computer />;
  const lower = os.toLowerCase();
  if (lower.includes("android")) return <PhoneAndroid />;
  if (lower.includes("iphone") || lower.includes("ios") || lower.includes("ipad")) return <PhoneIphone />;
  if (lower.includes("mac")) return <Laptop />;
  return <Computer />;
};

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
  const { deviceId } = router.query;
  const tenant = useSettings().currentTenant;

  const enableDialog = useDialog();
  const disableDialog = useDialog();
  const bitlockerDialog = useDialog();
  const deleteDialog = useDialog();

  const deviceData = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: "devices",
      $format: "application/json",
      $count: true,
      tenantFilter: tenant,
    },
    queryKey: `EntraDevice-${deviceId}-${tenant}`,
    waiting: !!(deviceId && tenant),
  });

  const device = useMemo(() => {
    if (!deviceData.data?.Results) return null;
    return deviceData.data.Results.find((d) => d.id === deviceId) || null;
  }, [deviceData.data, deviceId]);

  if (!deviceId || !tenant) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/identity/administration/devices" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Devices
        </Button>
        <Alert severity="warning">No device selected. Please select a device from the list.</Alert>
      </Container>
    );
  }

  if (deviceData.isLoading) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/identity/administration/devices" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Devices
        </Button>
        <Box sx={{ display: "flex", justifyContent: "center", py: 8 }}>
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  if (deviceData.isError || !device) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/identity/administration/devices" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Devices
        </Button>
        <Alert severity="error">Failed to load device details. Please try again.</Alert>
      </Container>
    );
  }

  const isEnabled = device.accountEnabled === true;
  const statusColor = isEnabled ? "success" : "error";
  const osIcon = getOSIcon(device.operatingSystem);

  return (
    <Container maxWidth={false} sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Button
          component={Link}
          href="/identity/administration/devices"
          startIcon={<ArrowBack />}
          sx={{ alignSelf: "flex-start" }}
        >
          Back to Devices
        </Button>

        {/* Hero + Actions */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, lg: 8 }}>
            <Paper
              elevation={0}
              sx={(t) => ({
                p: 3,
                borderRadius: 2,
                background: `linear-gradient(135deg, ${alpha(t.palette[statusColor].main, 0.15)} 0%, ${alpha(t.palette[statusColor].main, 0.05)} 100%)`,
                borderLeft: `4px solid ${t.palette[statusColor].main}`,
                height: "100%",
              })}
            >
              <Stack direction="row" spacing={2} alignItems="center">
                <Avatar
                  sx={{
                    bgcolor: stringToColor(device.displayName || "D"),
                    width: 56,
                    height: 56,
                    fontSize: "1.25rem",
                    fontWeight: 600,
                  }}
                >
                  {osIcon}
                </Avatar>
                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5 }}>
                    {device.displayName || "Unknown Device"}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" noWrap sx={{ mb: 1 }}>
                    {device.operatingSystem} {device.operatingSystemVersion}
                  </Typography>
                  <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                    <Chip
                      icon={isEnabled ? <CheckCircle fontSize="small" /> : <Cancel fontSize="small" />}
                      label={isEnabled ? "Enabled" : "Disabled"}
                      size="small"
                      color={statusColor}
                      variant="outlined"
                    />
                    {device.trustType && (
                      <Chip
                        icon={<VerifiedUser fontSize="small" />}
                        label={device.trustType === "AzureAd" ? "Azure AD Joined" : device.trustType === "ServerAd" ? "Domain Joined" : "Workplace Joined"}
                        size="small"
                        color="primary"
                        variant="outlined"
                      />
                    )}
                    {device.isCompliant === true && (
                      <Chip icon={<CheckCircle fontSize="small" />} label="Compliant" size="small" color="success" variant="outlined" />
                    )}
                    {device.isCompliant === false && (
                      <Chip icon={<Cancel fontSize="small" />} label="Non-Compliant" size="small" color="error" variant="outlined" />
                    )}
                    {device.isManaged && (
                      <Chip label="Managed" size="small" color="info" variant="outlined" />
                    )}
                  </Stack>
                </Box>
              </Stack>
            </Paper>
          </Grid>
          <Grid size={{ xs: 12, lg: 4 }}>
            <Paper variant="outlined" sx={{ p: 2, borderRadius: 2, height: "100%" }}>
              <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
                Quick Actions
              </Typography>
              <Stack spacing={1}>
                {!isEnabled && (
                  <Button
                    variant="outlined"
                    color="success"
                    startIcon={<CheckCircleOutline />}
                    fullWidth
                    onClick={() => enableDialog.handleOpen()}
                  >
                    Enable Device
                  </Button>
                )}
                {isEnabled && (
                  <Button
                    variant="outlined"
                    color="warning"
                    startIcon={<Block />}
                    fullWidth
                    onClick={() => disableDialog.handleOpen()}
                  >
                    Disable Device
                  </Button>
                )}
                <Button
                  variant="outlined"
                  color="info"
                  startIcon={<VpnKey />}
                  fullWidth
                  onClick={() => bitlockerDialog.handleOpen()}
                >
                  Retrieve BitLocker Keys
                </Button>
                <Button
                  variant="outlined"
                  color="error"
                  startIcon={<DeleteForever />}
                  fullWidth
                  onClick={() => deleteDialog.handleOpen()}
                >
                  Delete Device
                </Button>
              </Stack>
            </Paper>
          </Grid>
        </Grid>

        {/* Source Presence */}
        <Paper variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
          <Typography variant="overline" color="text.secondary" sx={{ fontWeight: 600, letterSpacing: 1, mb: 1, display: "block" }}>
            Sources
          </Typography>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Tooltip title="Device registered in Microsoft Entra ID">
              <Chip
                label="Entra"
                size="small"
                variant="outlined"
                sx={(t) => ({
                  fontWeight: 600,
                  borderColor: alpha(t.palette.info.main, 0.6),
                  bgcolor: alpha(t.palette.info.main, 0.08),
                })}
              />
            </Tooltip>
            <Tooltip title={device.isManaged ? "Device managed by Microsoft Intune" : "Not managed by Intune"}>
              <Chip
                label="Intune"
                size="small"
                variant="outlined"
                sx={(t) => ({
                  fontWeight: 600,
                  ...(device.isManaged
                    ? {
                        borderColor: alpha(t.palette.primary.main, 0.6),
                        bgcolor: alpha(t.palette.primary.main, 0.08),
                      }
                    : {
                        borderColor: alpha(t.palette.text.secondary, 0.4),
                        color: t.palette.text.secondary,
                        bgcolor: alpha(t.palette.text.secondary, 0.06),
                      }),
                })}
              />
            </Tooltip>
            <Tooltip title={device.ninjaDeviceId ? "Device has NinjaOne agent" : "No NinjaOne agent"}>
              <Chip
                label="NinjaOne"
                size="small"
                variant="outlined"
                sx={(t) => ({
                  fontWeight: 600,
                  ...(device.ninjaDeviceId
                    ? {
                        borderColor: alpha(t.palette.success.main, 0.6),
                        bgcolor: alpha(t.palette.success.main, 0.12),
                      }
                    : {
                        borderColor: alpha(t.palette.text.secondary, 0.4),
                        color: t.palette.text.secondary,
                        bgcolor: alpha(t.palette.text.secondary, 0.06),
                      }),
                })}
              />
            </Tooltip>
          </Stack>
        </Paper>

        {/* Device Info + NinjaOne / Timeline */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, md: 6 }}>
            <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                <InfoIcon fontSize="small" color="action" />
                <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Device Information</Typography>
              </Stack>
              <Stack spacing={0.5}>
                <InfoRow label="Manufacturer" value={device.manufacturer} />
                <InfoRow label="Model" value={device.model} />
                <InfoRow label="Operating System" value={device.operatingSystem} />
                <InfoRow label="OS Version" value={device.operatingSystemVersion} />
                <InfoRow label="Enrollment Type" value={device.enrollmentType} />
                <InfoRow label="Profile Type" value={device.profileType} />
                <InfoRow label="Device ID" value={device.id} mono />
              </Stack>
            </Paper>
          </Grid>
          <Grid size={{ xs: 12, md: 6 }}>
            <Stack spacing={2}>
              {/* NinjaOne Hardware */}
              {device.ninjaDeviceId && (
                <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                  <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                    <Dns fontSize="small" color="action" />
                    <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>NinjaOne Hardware</Typography>
                    <Chip
                      icon={device.ninjaOffline ? <WifiOff sx={{ fontSize: 14 }} /> : <Wifi sx={{ fontSize: 14 }} />}
                      label={device.ninjaOffline ? "Offline" : "Online"}
                      color={device.ninjaOffline ? "default" : "success"}
                      variant="outlined"
                      size="small"
                      sx={{ ml: "auto" }}
                    />
                  </Stack>
                  <Stack spacing={0.5}>
                    <InfoRow label="CPU" value={device.ninjaCpuName ? `${device.ninjaCpuName}${device.ninjaCpuCores ? ` (${device.ninjaCpuCores} cores)` : ""}` : null} />
                    <InfoRow label="Memory" value={device.ninjaTotalRamGB != null ? `${device.ninjaTotalRamGB} GB` : null} />
                    <InfoRow label="OS (NinjaOne)" value={device.ninjaOsName ? `${device.ninjaOsName}${device.ninjaOsBuild ? ` (${device.ninjaOsBuild})` : ""}` : null} />
                    <InfoRow label="Architecture" value={device.ninjaOsArch} />
                    <InfoRow label="Domain" value={device.ninjaDomain} />
                    <InfoRow label="Last Boot" value={device.ninjaLastBootTime ? getCippFormatting(device.ninjaLastBootTime, "ninjaLastBootTime") : null} />
                    <InfoRow label="Last NinjaOne Contact" value={device.ninjaLastContact ? getCippFormatting(device.ninjaLastContact, "ninjaLastContact") : null} />
                  </Stack>
                </Paper>
              )}

              {/* Timeline */}
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <CalendarToday fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Timeline</Typography>
                </Stack>
                <Stack spacing={0.5}>
                  <InfoRow label="Last Sign-In" value={device.approximateLastSignInDateTime ? getCippFormatting(device.approximateLastSignInDateTime, "approximateLastSignInDateTime") : null} />
                  <InfoRow label="Registered" value={device.registrationDateTime ? getCippFormatting(device.registrationDateTime, "registrationDateTime") : null} />
                  <InfoRow label="Device ID" value={device.id} mono />
                </Stack>
              </Paper>
            </Stack>
          </Grid>
        </Grid>
      </Stack>

      {/* Dialogs */}
      <CippApiDialog
        title="Enable Device"
        createDialog={enableDialog}
        api={{
          url: "/api/ExecDeviceDelete",
          type: "POST",
          data: { ID: device?.id, action: "!Enable", tenantFilter: tenant },
          confirmText: "Are you sure you want to enable this device?",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`EntraDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Disable Device"
        createDialog={disableDialog}
        api={{
          url: "/api/ExecDeviceDelete",
          type: "POST",
          data: { ID: device?.id, action: "!Disable", tenantFilter: tenant },
          confirmText: "Are you sure you want to disable this device?",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`EntraDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Retrieve BitLocker Keys"
        createDialog={bitlockerDialog}
        api={{
          url: "/api/ExecGetRecoveryKey",
          type: "POST",
          data: { GUID: device?.deviceId, tenantFilter: tenant },
          confirmText: "Are you sure you want to retrieve the BitLocker keys for this device?",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`EntraDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Delete Device"
        createDialog={deleteDialog}
        api={{
          url: "/api/ExecDeviceDelete",
          type: "POST",
          data: { ID: device?.id, action: "!Delete", tenantFilter: tenant },
          confirmText: "Are you sure you want to delete this device? This action cannot be undone.",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`EntraDevice-${deviceId}-${tenant}`]}
      />
    </Container>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
