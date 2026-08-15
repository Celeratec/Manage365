import { useCallback, useMemo } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { ApiGetCall } from "../../../../api/ApiCall.jsx";
import { CippApiDialog } from "../../../../components/CippComponents/CippApiDialog.jsx";
import { useSettings } from "../../../../hooks/use-settings";
import { useDialog } from "../../../../hooks/use-dialog.js";
import {
  Box,
  Button,
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  Tooltip,
  Stack,
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import {
  Sync,
  Security,
  Computer,
  PhoneAndroid,
  PhoneIphone,
  Laptop,
  CheckCircle,
  Cancel,
  Warning,
  Help,
  VerifiedUser,
  GppBad,
  Person,
  CalendarToday,
  Info as InfoIcon,
  Business,
  Dns,
  WifiOff,
  Wifi,
  Memory,
  Storage,
  Devices,
} from "@mui/icons-material";
import { useRouter } from "next/router";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";
import { getIntuneDeviceActions } from "../../../../components/CippComponents/CippIntuneDeviceActions.jsx";

const Page = () => {
  const pageTitle = "Devices";
  const router = useRouter();
  const tenantFilter = useSettings().currentTenant;
  const theme = useTheme();
  const depSyncDialog = useDialog();

  const handleCardClick = useCallback((device) => {
    router.push(`/endpoint/MEM/devices/view?deviceId=${encodeURIComponent(device.id || "")}`);
  }, [router]);

  // Fetch NinjaOne enrichment data (runs in parallel with the Intune fetch)
  const ninjaDevices = ApiGetCall({
    url: "/api/ListNinjaDeviceInfo",
    data: { TenantFilter: tenantFilter },
    queryKey: `NinjaDevices-${tenantFilter}`,
    waiting: !!tenantFilter,
  });

  // Build NinjaOne lookup: by azureADDeviceId and by serial (NinjaOne stores serial as primary identifier)
  const { ninjaLookup, ninjaBySerial } = useMemo(() => {
    const byId = {};
    const bySerial = {};
    const raw = ninjaDevices.data;
    const arr = Array.isArray(raw) ? raw : raw?.Results;
    if (arr) {
      arr.forEach((d) => {
        if (d.azureADDeviceId) byId[d.azureADDeviceId] = d;
      });
    }
    const serialIndex = raw?.BySerial || {};
    Object.keys(serialIndex).forEach((sn) => {
      if (sn && serialIndex[sn]) bySerial[String(sn).trim()] = serialIndex[sn];
    });
    return { ninjaLookup: byId, ninjaBySerial: bySerial };
  }, [ninjaDevices.data]);

  const hasNinjaData = Object.keys(ninjaLookup).length > 0 || Object.keys(ninjaBySerial).length > 0;

  // Merge NinjaOne fields into each Intune device row (match by azureADDeviceId or serial)
  const mergeNinjaData = useCallback(
    (devices) => {
      if (!hasNinjaData) return devices;
      return devices.map((device) => {
        const ninja = ninjaLookup[device.azureADDeviceId] || (device.serialNumber && ninjaBySerial[String(device.serialNumber).trim()]);
        return ninja ? { ...device, ...ninja } : device;
      });
    },
    [ninjaLookup, ninjaBySerial, hasNinjaData]
  );

  // Card view configuration (works for both mobile and desktop)
  const cardConfig = {
    title: "deviceName",
    subtitle: "userPrincipalName",
    avatar: {
      field: "deviceName",
      icon: (item) => {
        const os = (item.operatingSystem || "").toLowerCase();
        if (os.includes("android")) return <PhoneAndroid />;
        if (os.includes("ios") || os.includes("iphone") || os.includes("ipad")) return <PhoneIphone />;
        if (os.includes("mac")) return <Laptop />;
        if (os.includes("windows")) return <Computer />;
        return <Devices />;
      },
    },
    // Color-code left border by compliance state
    cardSx: (item) => {
      const state = String(item.complianceState || "").toLowerCase();
      if (state === "compliant") return { borderLeft: `4px solid ${theme.palette.success.main}` };
      if (state === "noncompliant") return { borderLeft: `4px solid ${theme.palette.error.main}` };
      if (state === "ingraceperiod") return { borderLeft: `4px solid ${theme.palette.warning.main}` };
      return { borderLeft: `4px solid ${theme.palette.grey[400]}` };
    },
    badges: [
      {
        field: "complianceState",
        iconOnly: true,
        conditions: {
          compliant: { icon: <VerifiedUser fontSize="small" />, color: "success", label: "Compliant" },
          noncompliant: { icon: <GppBad fontSize="small" />, color: "error", label: "Non-Compliant" },
          unknown: { label: "Unknown Compliance", color: "default", icon: <Help fontSize="small" /> },
          inGracePeriod: { label: "Grace Period", color: "warning", icon: <Warning fontSize="small" /> },
        },
      },
      {
        field: "managedDeviceOwnerType",
        conditions: {
          company: { label: "Corporate", color: "primary" },
          personal: { label: "Personal", color: "default" },
        },
      },
      // Source presence indicators — show which systems this device exists in
      {
        field: "azureADDeviceId",
        transform: (v) => (v ? "yes" : null),
        conditions: { yes: { label: "Entra", color: "info" } },
      },
      {
        field: "id",
        transform: (v) => (v ? "yes" : null),
        conditions: { yes: { label: "Intune", color: "primary" } },
      },
      {
        field: "ninjaDeviceId",
        transform: (v) => (v ? "yes" : null),
        conditions: { yes: { label: "NinjaOne", color: "success" } },
      },
    ],
    extraFields: [
      { field: "operatingSystem", icon: <Computer />, maxLines: 1 },
      [
        { field: "manufacturer", maxLines: 1 },
        { field: "model", maxLines: 1 },
      ],
    ],
    extraFieldsMax: 3,
    // NinjaOne hardware summary rendered as custom content
    customContent: (item) => {
      if (!item.ninjaDeviceId) return null;
      return (
        <Box
          sx={{
            mt: 1,
            mb: 0.5,
            p: 1,
            borderRadius: 1,
            bgcolor: alpha(theme.palette.info.main, 0.04),
            border: `1px solid ${alpha(theme.palette.info.main, 0.12)}`,
          }}
        >
          <Stack spacing={0.5}>
            <Stack direction="row" alignItems="center" spacing={0.5}>
              <Dns sx={{ fontSize: 12, color: "text.secondary" }} />
              <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600 }}>
                NinjaOne
              </Typography>
            </Stack>
            <Stack direction="row" spacing={2} flexWrap="wrap" useFlexGap>
              {item.ninjaCpuName && (
                <Stack direction="row" alignItems="center" spacing={0.5}>
                  <Memory sx={{ fontSize: 12, color: "text.secondary" }} />
                  <Typography variant="caption" noWrap sx={{ maxWidth: 140 }}>
                    {item.ninjaCpuName}
                  </Typography>
                </Stack>
              )}
              {item.ninjaTotalRamGB != null && (
                <Stack direction="row" alignItems="center" spacing={0.5}>
                  <Storage sx={{ fontSize: 12, color: "text.secondary" }} />
                  <Typography variant="caption">{item.ninjaTotalRamGB} GB</Typography>
                </Stack>
              )}
            </Stack>
          </Stack>
        </Box>
      );
    },
    // Additional fields shown only on desktop cards
    desktopFields: [
      { field: "osVersion", label: "OS Version" },
      { field: "serialNumber", label: "Serial Number" },
      { field: "lastSyncDateTime", label: "Last Sync" },
      { field: "enrolledDateTime", label: "Enrolled" },
    ],
    desktopFieldsMax: 4,
    desktopFieldsLayout: "column",
    // Grid sizing for consistent card widths
      cardGridProps: {
        md: 6,
        lg: 4,
      },
    mobileQuickActions: [
      "Sync Device",
      "Reboot Device",
      "Rename Device",
      "Retrieve LAPS password",
      "Retrieve BitLocker Keys",
    ],
    maxQuickActions: 8,
  };

  const actions = getIntuneDeviceActions({ tenantFilter });

  // Helper functions for device styling
  const getOSIcon = (os) => {
    const osLower = String(os || "").toLowerCase();
    if (osLower.includes("windows")) return <Computer fontSize="small" />;
    if (osLower.includes("ios") || osLower.includes("iphone") || osLower.includes("ipad")) return <PhoneIphone fontSize="small" />;
    if (osLower.includes("android")) return <PhoneAndroid fontSize="small" />;
    if (osLower.includes("macos") || osLower.includes("mac")) return <Laptop fontSize="small" />;
    return <Computer fontSize="small" />;
  };

  const getComplianceInfo = (state) => {
    switch (String(state || "").toLowerCase()) {
      case "compliant":
        return { label: "Compliant", color: theme.palette.success.main, icon: <CheckCircle fontSize="small" /> };
      case "noncompliant":
        return { label: "Non-Compliant", color: theme.palette.error.main, icon: <Cancel fontSize="small" /> };
      case "ingraceperiod":
        return { label: "In Grace Period", color: theme.palette.warning.main, icon: <Warning fontSize="small" /> };
      default:
        return { label: "Unknown", color: theme.palette.grey[500], icon: <Help fontSize="small" /> };
    }
  };

  const offCanvas = {
    actions: actions,
    children: (row) => {
      const complianceInfo = getComplianceInfo(row.complianceState);
      const osIcon = getOSIcon(row.operatingSystem);
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(complianceInfo.color, 0.15)} 0%, ${alpha(complianceInfo.color, 0.05)} 100%)`,
              borderLeft: `4px solid ${complianceInfo.color}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: stringToColor(row.deviceName || "D"),
                  width: 56,
                  height: 56,
                  fontSize: "1.25rem",
                  fontWeight: 600,
                }}
              >
                {osIcon}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.deviceName || "Unknown Device"}
                </Typography>
                <Typography variant="body2" color="text.secondary" noWrap>
                  {row.userPrincipalName || "No user assigned"}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Source Presence */}
          <Box>
            <Typography
              variant="overline"
              color="text.secondary"
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1, display: "block" }}
            >
              Sources
            </Typography>
            <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap>
              {row.azureADDeviceId && (
                <Tooltip title="Device registered in Microsoft Entra ID">
                  <Chip
                    label="Entra"
                    size="small"
                    variant="outlined"
                    sx={{
                      height: 22,
                      fontWeight: 600,
                      fontSize: "0.7rem",
                      borderColor: (t) => alpha(t.palette.info.main, 0.6),
                      color: "text.primary",
                      bgcolor: (t) => alpha(t.palette.info.main, 0.08),
                    }}
                  />
                </Tooltip>
              )}
              <Tooltip title="Device managed by Microsoft Intune">
                <Chip
                  label="Intune"
                  size="small"
                  variant="outlined"
                  sx={{
                    height: 22,
                    fontWeight: 600,
                    fontSize: "0.7rem",
                    borderColor: (t) => alpha(t.palette.primary.main, 0.6),
                    color: "text.primary",
                    bgcolor: (t) => alpha(t.palette.primary.main, 0.08),
                  }}
                />
              </Tooltip>
              <Tooltip title={row.ninjaDeviceId ? "Device has NinjaOne agent" : "No NinjaOne agent on this device"}>
                <Chip
                  label="NinjaOne"
                  size="small"
                  variant="outlined"
                  sx={{
                    height: 22,
                    fontWeight: 600,
                    fontSize: "0.7rem",
                    ...(row.ninjaDeviceId
                      ? {
                          borderColor: (t) => alpha(t.palette.success.main, 0.6),
                          color: "text.primary",
                          bgcolor: (t) => alpha(t.palette.success.main, 0.12),
                        }
                      : {
                          borderColor: (t) => alpha(t.palette.text.secondary, 0.4),
                          color: "text.secondary",
                          bgcolor: (t) => alpha(t.palette.text.secondary, 0.06),
                        }),
                  }}
                />
              </Tooltip>
            </Stack>
          </Box>

          {/* Status Badges */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Compliance Status
            </Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Tooltip title={complianceInfo.label === "Compliant" ? "Device meets compliance policies" : complianceInfo.label === "Non-Compliant" ? "Device does not meet compliance policies" : "Compliance status unknown"}>
                <Chip
                  icon={complianceInfo.icon}
                  label={complianceInfo.label}
                  sx={{ 
                    height: 22,
                    fontWeight: 600, 
                    bgcolor: alpha(complianceInfo.color, 0.1),
                    color: complianceInfo.color,
                    borderColor: complianceInfo.color,
                  }}
                  variant="outlined"
                />
              </Tooltip>
              {row.managedDeviceOwnerType && (
                <Tooltip title={`Device ownership: ${row.managedDeviceOwnerType === "company" ? "Corporate" : "Personal"}`}>
                  <Chip
                    label={row.managedDeviceOwnerType === "company" ? "Corporate" : "Personal"}
                    color={row.managedDeviceOwnerType === "company" ? "primary" : "default"}
                    variant="outlined"
                    size="small"
                    sx={{ height: 22 }}
                  />
                </Tooltip>
              )}
              {row.isEncrypted && (
                <Tooltip title="Device encryption is enabled">
                  <Chip
                    icon={<Security fontSize="small" />}
                    label="Encrypted"
                    color="success"
                    variant="outlined"
                    size="small"
                    sx={{ height: 22 }}
                  />
                </Tooltip>
              )}
            </Stack>
          </Box>

          <Divider />

          {/* Device Information */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <InfoIcon fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Device Information
              </Typography>
            </Stack>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Operating System</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.operatingSystem}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">OS Version</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.osVersion}
                </Typography>
              </Stack>
              {row.manufacturer && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Manufacturer</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.manufacturer}
                  </Typography>
                </Stack>
              )}
              {row.model && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Model</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.model}
                  </Typography>
                </Stack>
              )}
              {row.serialNumber && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Serial Number</Typography>
                  <Typography 
                    variant="caption" 
                    sx={{ 
                      fontFamily: "monospace",
                      bgcolor: alpha(theme.palette.text.primary, 0.05),
                      px: 1,
                      py: 0.25,
                      borderRadius: 0.5,
                    }}
                  >
                    {row.serialNumber}
                  </Typography>
                </Stack>
              )}
            </Stack>
          </Box>

          {/* NinjaOne Hardware — shown only when enrichment data is present */}
          {row.ninjaDeviceId && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                  <Dns fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    NinjaOne Hardware
                  </Typography>
                  <Chip
                    icon={row.ninjaOffline ? <WifiOff sx={{ fontSize: 14 }} /> : <Wifi sx={{ fontSize: 14 }} />}
                    label={row.ninjaOffline ? "Offline" : "Online"}
                    color={row.ninjaOffline ? "default" : "success"}
                    variant="outlined"
                    size="small"
                    sx={{ ml: "auto" }}
                  />
                </Stack>
                <Stack spacing={1}>
                  {row.ninjaCpuName && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">CPU</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.ninjaCpuName}{row.ninjaCpuCores ? ` (${row.ninjaCpuCores} cores)` : ""}
                      </Typography>
                    </Stack>
                  )}
                  {row.ninjaTotalRamGB != null && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Memory</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.ninjaTotalRamGB} GB
                      </Typography>
                    </Stack>
                  )}
                  {row.ninjaOsName && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">OS (NinjaOne)</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.ninjaOsName}{row.ninjaOsBuild ? ` (${row.ninjaOsBuild})` : ""}
                      </Typography>
                    </Stack>
                  )}
                  {row.ninjaOsArch && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Architecture</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.ninjaOsArch}
                      </Typography>
                    </Stack>
                  )}
                  {row.ninjaLastBootTime && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Last Boot</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {getCippFormatting(row.ninjaLastBootTime, "ninjaLastBootTime")}
                      </Typography>
                    </Stack>
                  )}
                  {row.ninjaDomain && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Domain</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.ninjaDomain}
                      </Typography>
                    </Stack>
                  )}
                  {row.ninjaLastContact && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Last NinjaOne Contact</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {getCippFormatting(row.ninjaLastContact, "ninjaLastContact")}
                      </Typography>
                    </Stack>
                  )}
                  {row.ninjaNodeClass && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Device Class</Typography>
                      <Chip label={row.ninjaNodeClass} size="small" variant="outlined" />
                    </Stack>
                  )}
                </Stack>
              </Box>
            </>
          )}

          {/* User & Enrollment */}
          <Divider />
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <Person fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                User & Enrollment
              </Typography>
            </Stack>
            <Stack spacing={1}>
              {row.userPrincipalName && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Primary User</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }} noWrap>
                    {row.userPrincipalName}
                  </Typography>
                </Stack>
              )}
              {row.deviceEnrollmentType && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Enrollment Type</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.deviceEnrollmentType}
                  </Typography>
                </Stack>
              )}
              {row.joinType && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Join Type</Typography>
                  <Chip label={row.joinType} size="small" variant="outlined" />
                </Stack>
              )}
            </Stack>
          </Box>

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
              {row.enrolledDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Enrolled</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.enrolledDateTime, "enrolledDateTime")}
                  </Typography>
                </Stack>
              )}
              {row.lastSyncDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Last Sync</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.lastSyncDateTime, "lastSyncDateTime")}
                  </Typography>
                </Stack>
              )}
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Device ID</Typography>
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
        </Stack>
      );
    },
  };

  // Build simpleColumns — always show Intune columns, conditionally add NinjaOne columns
  const simpleColumns = useMemo(() => {
    const base = [
      "deviceName",
      "userPrincipalName",
      "complianceState",
      "manufacturer",
      "model",
      "operatingSystem",
      "osVersion",
      "enrolledDateTime",
      "managedDeviceOwnerType",
      "deviceEnrollmentType",
      "joinType",
    ];

    if (!hasNinjaData) return base;

    return [
      ...base,
      "ninjaCpuName",
      "ninjaTotalRamGB",
      "ninjaOffline",
      "ninjaLastContact",
    ];
  }, [hasNinjaData]);

  return (
    <>
      <CippTablePage
        title={pageTitle}
        apiUrl="/api/ListGraphRequest"
        apiData={{
          Endpoint: "deviceManagement/managedDevices",
        }}
        apiDataKey="Results"
        apiDataFilter={mergeNinjaData}
        actions={actions}
        queryKey={`MEMDevices-${tenantFilter}`}
        offCanvas={offCanvas}
        simpleColumns={simpleColumns}
        cardConfig={cardConfig}
        onCardClick={handleCardClick}
        offCanvasOnRowClick={true}
        cardButton={
          <Box sx={{ display: "flex", gap: 1 }}>
            <Button onClick={depSyncDialog.handleOpen} startIcon={<Sync />}>
              Sync DEP
            </Button>
          </Box>
        }
      />
      <CippApiDialog
        title="Sync DEP Tokens"
        createDialog={depSyncDialog}
        api={{
          type: "POST",
          url: "/api/ExecSyncDEP",
          data: {},
          confirmText: `Are you sure you want to sync Apple Device Enrollment Program (DEP) tokens? This will sync all DEP tokens for ${tenantFilter}. This may take several minutes to complete in the background, and can only be done every 15 minutes.`,
        }}
      />
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
