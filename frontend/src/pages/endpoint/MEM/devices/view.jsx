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
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Grid, Stack } from "@mui/system";
import {
  ArrowBack,
  CheckCircle,
  Cancel,
  Warning,
  Help,
  Info as InfoIcon,
  CalendarToday,
  Computer,
  PhoneAndroid,
  PhoneIphone,
  Laptop,
  Dns,
  WifiOff,
  Wifi,
  Person,
  Sync,
  RestartAlt,
  Edit,
  Password,
  Key,
  Security,
  Recycling,
} from "@mui/icons-material";
import Link from "next/link";
import { stringToColor } from "../../../../utils/get-initials";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";

const getOSIcon = (os) => {
  const lower = String(os || "").toLowerCase();
  if (lower.includes("windows")) return <Computer />;
  if (lower.includes("ios") || lower.includes("iphone") || lower.includes("ipad")) return <PhoneIphone />;
  if (lower.includes("android")) return <PhoneAndroid />;
  if (lower.includes("macos") || lower.includes("mac")) return <Laptop />;
  return <Computer />;
};

const getComplianceInfo = (state, palette) => {
  switch (String(state || "").toLowerCase()) {
    case "compliant":
      return { label: "Compliant", color: palette.success.main, icon: <CheckCircle fontSize="small" /> };
    case "noncompliant":
      return { label: "Non-Compliant", color: palette.error.main, icon: <Cancel fontSize="small" /> };
    case "ingraceperiod":
      return { label: "In Grace Period", color: palette.warning.main, icon: <Warning fontSize="small" /> };
    default:
      return { label: "Unknown", color: palette.grey[500], icon: <Help fontSize="small" /> };
  }
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
  const theme = useTheme();

  const syncDialog = useDialog();
  const rebootDialog = useDialog();
  const renameDialog = useDialog();
  const lapsDialog = useDialog();
  const bitlockerDialog = useDialog();
  const deleteDialog = useDialog();
  const retireDialog = useDialog();

  const deviceData = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: "deviceManagement/managedDevices",
      $count: true,
      tenantFilter: tenant,
    },
    queryKey: `MEMDevice-${deviceId}-${tenant}`,
    waiting: !!(deviceId && tenant),
  });

  const device = useMemo(() => {
    if (!deviceData.data?.Results) return null;
    return deviceData.data.Results.find((d) => d.id === deviceId) || null;
  }, [deviceData.data, deviceId]);

  if (!deviceId || !tenant) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/endpoint/MEM/devices" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Devices
        </Button>
        <Alert severity="warning">No device selected. Please select a device from the list.</Alert>
      </Container>
    );
  }

  if (deviceData.isLoading) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/endpoint/MEM/devices" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
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
        <Button component={Link} href="/endpoint/MEM/devices" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Devices
        </Button>
        <Alert severity="error">Failed to load device details. Please try again.</Alert>
      </Container>
    );
  }

  const complianceInfo = getComplianceInfo(device.complianceState, theme.palette);
  const osIcon = getOSIcon(device.operatingSystem);
  const isWindows = device.operatingSystem === "Windows";

  return (
    <Container maxWidth={false} sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Button
          component={Link}
          href="/endpoint/MEM/devices"
          startIcon={<ArrowBack />}
          sx={{ alignSelf: "flex-start" }}
        >
          Back to Devices
        </Button>

        {/* Hero + Quick Actions */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, lg: 8 }}>
            <Paper
              elevation={0}
              sx={{
                p: 3,
                borderRadius: 2,
                background: `linear-gradient(135deg, ${alpha(complianceInfo.color, 0.15)} 0%, ${alpha(complianceInfo.color, 0.05)} 100%)`,
                borderLeft: `4px solid ${complianceInfo.color}`,
                height: "100%",
              }}
            >
              <Stack direction="row" spacing={2} alignItems="center">
                <Avatar
                  sx={{
                    bgcolor: stringToColor(device.deviceName || "D"),
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
                    {device.deviceName || "Unknown Device"}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" noWrap sx={{ mb: 1 }}>
                    {device.userPrincipalName || "No user assigned"}
                  </Typography>
                  <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                    <Chip
                      icon={complianceInfo.icon}
                      label={complianceInfo.label}
                      size="small"
                      sx={{
                        fontWeight: 600,
                        bgcolor: alpha(complianceInfo.color, 0.1),
                        color: complianceInfo.color,
                        borderColor: complianceInfo.color,
                      }}
                      variant="outlined"
                    />
                    {device.managedDeviceOwnerType && (
                      <Chip
                        label={device.managedDeviceOwnerType === "company" ? "Corporate" : "Personal"}
                        size="small"
                        color={device.managedDeviceOwnerType === "company" ? "primary" : "default"}
                        variant="outlined"
                      />
                    )}
                    {device.isEncrypted && (
                      <Chip icon={<Security fontSize="small" />} label="Encrypted" size="small" color="success" variant="outlined" />
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
                <Button variant="outlined" color="primary" startIcon={<Sync />} fullWidth onClick={() => syncDialog.handleOpen()}>
                  Sync Device
                </Button>
                <Button variant="outlined" color="warning" startIcon={<RestartAlt />} fullWidth onClick={() => rebootDialog.handleOpen()}>
                  Reboot Device
                </Button>
                <Button variant="outlined" color="info" startIcon={<Edit />} fullWidth onClick={() => renameDialog.handleOpen()}>
                  Rename Device
                </Button>
                {isWindows && (
                  <>
                    <Button variant="outlined" color="info" startIcon={<Password />} fullWidth onClick={() => lapsDialog.handleOpen()}>
                      Retrieve LAPS Password
                    </Button>
                    <Button variant="outlined" color="info" startIcon={<Key />} fullWidth onClick={() => bitlockerDialog.handleOpen()}>
                      Retrieve BitLocker Keys
                    </Button>
                  </>
                )}
                <Divider />
                <Button variant="outlined" color="error" startIcon={<Recycling />} fullWidth onClick={() => retireDialog.handleOpen()}>
                  Retire Device
                </Button>
                <Button variant="outlined" color="error" startIcon={<Recycling />} fullWidth onClick={() => deleteDialog.handleOpen()}>
                  Delete Device
                </Button>
              </Stack>
            </Paper>
          </Grid>
        </Grid>

        {/* Sources */}
        <Paper variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
          <Typography variant="overline" color="text.secondary" sx={{ fontWeight: 600, letterSpacing: 1, mb: 1, display: "block" }}>
            Sources
          </Typography>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            {device.azureADDeviceId && (
              <Tooltip title="Device registered in Microsoft Entra ID">
                <Chip label="Entra" size="small" variant="outlined"
                  sx={{ fontWeight: 600, borderColor: alpha(theme.palette.info.main, 0.6), bgcolor: alpha(theme.palette.info.main, 0.08) }}
                />
              </Tooltip>
            )}
            <Tooltip title="Device managed by Microsoft Intune">
              <Chip label="Intune" size="small" variant="outlined"
                sx={{ fontWeight: 600, borderColor: alpha(theme.palette.primary.main, 0.6), bgcolor: alpha(theme.palette.primary.main, 0.08) }}
              />
            </Tooltip>
            <Tooltip title={device.ninjaDeviceId ? "Device has NinjaOne agent" : "No NinjaOne agent"}>
              <Chip label="NinjaOne" size="small" variant="outlined"
                sx={{
                  fontWeight: 600,
                  ...(device.ninjaDeviceId
                    ? { borderColor: alpha(theme.palette.success.main, 0.6), bgcolor: alpha(theme.palette.success.main, 0.12) }
                    : { borderColor: alpha(theme.palette.text.secondary, 0.4), color: theme.palette.text.secondary, bgcolor: alpha(theme.palette.text.secondary, 0.06) }),
                }}
              />
            </Tooltip>
          </Stack>
        </Paper>

        {/* Device Info + NinjaOne / User & Timeline */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, md: 6 }}>
            <Stack spacing={2}>
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <InfoIcon fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Device Information</Typography>
                </Stack>
                <Stack spacing={0.5}>
                  <InfoRow label="Operating System" value={device.operatingSystem} />
                  <InfoRow label="OS Version" value={device.osVersion} />
                  <InfoRow label="Manufacturer" value={device.manufacturer} />
                  <InfoRow label="Model" value={device.model} />
                  <InfoRow label="Serial Number" value={device.serialNumber} mono />
                </Stack>
              </Paper>

              {/* User & Enrollment */}
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <Person fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>User & Enrollment</Typography>
                </Stack>
                <Stack spacing={0.5}>
                  <InfoRow label="Primary User" value={device.userPrincipalName} />
                  <InfoRow label="Enrollment Type" value={device.deviceEnrollmentType} />
                  <InfoRow label="Join Type" value={device.joinType} />
                  <InfoRow label="Ownership" value={device.managedDeviceOwnerType === "company" ? "Corporate" : device.managedDeviceOwnerType === "personal" ? "Personal" : device.managedDeviceOwnerType} />
                </Stack>
              </Paper>
            </Stack>
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
                  <InfoRow label="Enrolled" value={device.enrolledDateTime ? getCippFormatting(device.enrolledDateTime, "enrolledDateTime") : null} />
                  <InfoRow label="Last Sync" value={device.lastSyncDateTime ? getCippFormatting(device.lastSyncDateTime, "lastSyncDateTime") : null} />
                  <InfoRow label="Device ID" value={device.id} mono />
                </Stack>
              </Paper>
            </Stack>
          </Grid>
        </Grid>
      </Stack>

      {/* Dialogs */}
      <CippApiDialog
        title="Sync Device"
        createDialog={syncDialog}
        api={{
          url: "/api/ExecDeviceAction",
          type: "POST",
          data: { GUID: device?.id, Action: "syncDevice", tenantFilter: tenant },
          confirmText: "Are you sure you want to sync this device?",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`MEMDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Reboot Device"
        createDialog={rebootDialog}
        api={{
          url: "/api/ExecDeviceAction",
          type: "POST",
          data: { GUID: device?.id, Action: "rebootNow", tenantFilter: tenant },
          confirmText: "Are you sure you want to reboot this device?",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`MEMDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Rename Device"
        createDialog={renameDialog}
        api={{
          url: "/api/ExecDeviceAction",
          type: "POST",
          data: { GUID: device?.id, Action: "setDeviceName", tenantFilter: tenant },
          confirmText: "Enter the new name for the device.",
          multiPost: false,
        }}
        row={device || {}}
        fields={[{ type: "textField", name: "input", label: "New Device Name", required: true }]}
        relatedQueryKeys={[`MEMDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Retrieve LAPS Password"
        createDialog={lapsDialog}
        api={{
          url: "/api/ExecGetLocalAdminPassword",
          type: "POST",
          data: { GUID: device?.azureADDeviceId, tenantFilter: tenant },
          confirmText: "Are you sure you want to retrieve the local admin password?",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`MEMDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Retrieve BitLocker Keys"
        createDialog={bitlockerDialog}
        api={{
          url: "/api/ExecGetRecoveryKey",
          type: "POST",
          data: { GUID: device?.azureADDeviceId, RecoveryKeyType: "BitLocker", tenantFilter: tenant },
          confirmText: "Are you sure you want to retrieve the BitLocker keys?",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`MEMDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Retire Device"
        createDialog={retireDialog}
        api={{
          url: "/api/ExecDeviceAction",
          type: "POST",
          data: { GUID: device?.id, Action: "retire", tenantFilter: tenant },
          confirmText: "Are you sure you want to retire this device?",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`MEMDevice-${deviceId}-${tenant}`]}
      />
      <CippApiDialog
        title="Delete Device"
        createDialog={deleteDialog}
        api={{
          url: "/api/ExecDeviceAction",
          type: "POST",
          data: { GUID: device?.id, Action: "delete", tenantFilter: tenant },
          confirmText: "Are you sure you want to delete this device? This action cannot be undone.",
          multiPost: false,
        }}
        row={device || {}}
        relatedQueryKeys={[`MEMDevice-${deviceId}-${tenant}`]}
      />
    </Container>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
