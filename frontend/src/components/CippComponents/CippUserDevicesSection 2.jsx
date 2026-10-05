import { memo, useMemo, useCallback } from "react";
import { ApiGetCall, ApiPostCall } from "../../api/ApiCall";
import {
  Computer,
  PhoneAndroid,
  PhoneIphone,
  Laptop,
  CheckCircle,
  Cancel,
  Warning,
  Sync,
  OpenInNew,
  Schedule,
  Devices,
  Dns,
  WifiOff,
  Wifi,
  Memory,
  Storage,
  RestartAlt,
  LocationOn,
  Lock,
  Recycling,
  Key,
  FindInPage,
} from "@mui/icons-material";
import { Box, Stack, Grid } from "@mui/system";
import {
  Typography,
  Card,
  CardContent,
  Chip,
  Avatar,
  Divider,
  IconButton,
  Tooltip,
  Skeleton,
} from "@mui/material";
import { alpha, useTheme } from "@mui/material/styles";
import { CippTimeAgo } from "./CippTimeAgo";

const INTUNE_QUICK_ACTIONS = [
  { action: "view", label: "View in Intune", icon: OpenInNew, type: "link", key: "view" },
  { action: "syncDevice", label: "Sync Device", icon: Sync, confirm: "Sync this device?", key: "sync" },
  { action: "rebootNow", label: "Reboot Device", icon: RestartAlt, confirm: "Reboot this device?", key: "reboot" },
  { action: "locateDevice", label: "Locate Device", icon: LocationOn, confirm: "Locate this device?", key: "locate" },
  { action: "remoteLock", label: "Remote Lock", icon: Lock, confirm: "Remotely lock this device?", key: "lock" },
  { action: "retire", label: "Retire Device", icon: Recycling, confirm: "Retire this device? Apps and data will be removed.", key: "retire" },
  { action: "RotateLocalAdminPassword", label: "Rotate LAPS", icon: Key, confirm: "Rotate the local admin password?", key: "laps", os: "Windows" },
  { action: "WindowsDefenderScan", label: "Defender Quick Scan", icon: FindInPage, confirm: "Run Windows Defender quick scan?", key: "scan", os: "Windows", quickScan: true },
];

const DeviceCard = memo(({ device, tenant, theme, managedDeviceId, onDeviceAction }) => {
  const getOSIcon = (os) => {
    const osLower = String(os || "").toLowerCase();
    if (osLower.includes("windows")) return <Computer />;
    if (osLower.includes("ios") || osLower.includes("iphone") || osLower.includes("ipad")) return <PhoneIphone />;
    if (osLower.includes("android")) return <PhoneAndroid />;
    if (osLower.includes("macos") || osLower.includes("mac")) return <Laptop />;
    return <Computer />;
  };

  const getComplianceInfo = () => {
    if (device.isCompliant === true) {
      return { label: "Compliant", color: "success", icon: <CheckCircle fontSize="small" /> };
    }
    if (device.isCompliant === false) {
      return { label: "Non-Compliant", color: "error", icon: <Cancel fontSize="small" /> };
    }
    return { label: "Unknown", color: "default", icon: <Warning fontSize="small" /> };
  };

  const getBorderColor = () => {
    if (!device.accountEnabled) return theme.palette.error.main;
    if (device.isCompliant === true) return theme.palette.success.main;
    if (device.isCompliant === false) return theme.palette.warning.main;
    return theme.palette.primary.main;
  };

  const getOSColor = (os) => {
    const osLower = String(os || "").toLowerCase();
    if (osLower.includes("windows")) return theme.palette.info.main;
    if (osLower.includes("ios") || osLower.includes("iphone") || osLower.includes("ipad") || osLower.includes("macos") || osLower.includes("mac")) return theme.palette.grey[700];
    if (osLower.includes("android")) return theme.palette.success.main;
    return theme.palette.primary.main;
  };

  const complianceInfo = getComplianceInfo();
  const osIcon = getOSIcon(device.operatingSystem);
  const osColor = getOSColor(device.operatingSystem);
  const borderColor = getBorderColor();

  const entraUrl = `https://entra.microsoft.com/${tenant}/#view/Microsoft_AAD_Devices/DeviceDetailsMenuBlade/~/Properties/objectId/${device.id}`;
  const intuneUrl = managedDeviceId
    ? `https://intune.microsoft.com/${tenant}/#view/Microsoft_Intune_Devices/DeviceSettingsMenuBlade/~/overview/mdmDeviceId/${managedDeviceId}`
    : null;

  const osLower = String(device.operatingSystem || "").toLowerCase();
  const isWindows = osLower.includes("windows");
  const quickActions =
    managedDeviceId && onDeviceAction
      ? INTUNE_QUICK_ACTIONS.filter((a) => !a.os || (a.os === "Windows" && isWindows)).slice(0, 8)
      : [];

  return (
    <Card
      variant="outlined"
      sx={{
        height: "100%",
        borderLeft: `4px solid ${borderColor}`,
        transition: "all 0.2s ease-in-out",
        "&:hover": {
          borderColor: theme.palette.primary.main,
          boxShadow: `0 4px 12px ${alpha(theme.palette.primary.main, 0.15)}`,
        },
      }}
    >
      <CardContent sx={{ p: 2.5, "&:last-child": { pb: 2.5 } }}>
        <Stack direction="row" spacing={2} alignItems="flex-start" sx={{ mb: 1.5 }}>
          <Avatar sx={{ bgcolor: alpha(osColor, 0.1), color: osColor, width: 48, height: 48 }}>{osIcon}</Avatar>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Stack direction="row" alignItems="center" justifyContent="space-between">
              <Typography
                variant="subtitle1"
                sx={{ fontWeight: 600, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", flex: 1 }}
              >
                {device.displayName || "Unknown Device"}
              </Typography>
              <Stack direction="row" spacing={0}>
                <Tooltip title="View in Entra">
                  <IconButton size="small" href={entraUrl} target="_blank" rel="noopener noreferrer">
                    <OpenInNew fontSize="small" />
                  </IconButton>
                </Tooltip>
                {device.isManaged && intuneUrl && (
                  <Tooltip title="View in Intune">
                    <IconButton size="small" href={intuneUrl} target="_blank" rel="noopener noreferrer">
                      <Devices fontSize="small" />
                    </IconButton>
                  </Tooltip>
                )}
              </Stack>
            </Stack>
            <Typography variant="body2" color="text.secondary">
              {device.operatingSystem} {device.operatingSystemVersion}
            </Typography>
          </Box>
        </Stack>

        <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap sx={{ mb: 1 }}>
          <Chip label="Entra" size="small" variant="outlined" sx={{ fontWeight: 600, fontSize: "0.65rem", height: 22 }} />
          <Chip
            label="Intune"
            size="small"
            variant="outlined"
            sx={{
              fontWeight: 600,
              fontSize: "0.65rem",
              height: 22,
              ...(device.isManaged
                ? { borderColor: (t) => alpha(t.palette.primary.main, 0.6), bgcolor: (t) => alpha(t.palette.primary.main, 0.08) }
                : { borderColor: (t) => alpha(t.palette.text.secondary, 0.4), color: "text.secondary" }),
            }}
          />
          <Chip
            label="NinjaOne"
            size="small"
            variant="outlined"
            sx={{
              fontWeight: 600,
              fontSize: "0.65rem",
              height: 22,
              ...(device.ninjaDeviceId
                ? { borderColor: (t) => alpha(t.palette.success.main, 0.6), bgcolor: (t) => alpha(t.palette.success.main, 0.12) }
                : { borderColor: (t) => alpha(t.palette.text.secondary, 0.4), color: "text.secondary" }),
            }}
          />
        </Stack>

        <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap sx={{ mb: 1.5 }}>
          <Chip icon={complianceInfo.icon} label={complianceInfo.label} color={complianceInfo.color} size="small" sx={{ fontWeight: 500, height: 22 }} />
          {device.isManaged && (
            <Chip icon={<Sync fontSize="small" />} label="Managed" color="info" size="small" sx={{ fontWeight: 500, height: 22 }} />
          )}
          {!device.accountEnabled && <Chip label="Disabled" color="error" variant="outlined" size="small" sx={{ height: 22 }} />}
          {device.trustType && <Chip label={device.trustType} size="small" variant="outlined" sx={{ height: 22, fontSize: "0.7rem" }} />}
          {device.ninjaDeviceId && (
            <Chip
              icon={device.ninjaOffline ? <WifiOff sx={{ fontSize: 14 }} /> : <Wifi sx={{ fontSize: 14 }} />}
              label={device.ninjaOffline ? "Offline" : "Online"}
              color={device.ninjaOffline ? "default" : "success"}
              variant="outlined"
              size="small"
              sx={{ height: 22 }}
            />
          )}
        </Stack>

        {quickActions.length > 0 && (
          <>
            <Divider sx={{ my: 1 }} />
            <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap alignItems="center">
              <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, mr: 0.5 }}>
                Quick actions:
              </Typography>
              {quickActions.map((qa) => {
                const Icon = qa.icon;
                if (qa.type === "link") {
                  return (
                    <Tooltip key={qa.key} title={qa.label}>
                      <IconButton size="small" href={intuneUrl} target="_blank" rel="noopener noreferrer" sx={{ color: "primary.main" }}>
                        <Icon sx={{ fontSize: 18 }} />
                      </IconButton>
                    </Tooltip>
                  );
                }
                return (
                  <Tooltip key={qa.key} title={qa.label}>
                    <IconButton
                      size="small"
                      onClick={() => {
                        if (!qa.confirm || window.confirm(qa.confirm)) {
                          const body = {};
                          if (qa.quickScan !== undefined) body.quickScan = qa.quickScan;
                          onDeviceAction(qa.action, body);
                        }
                      }}
                      sx={{ color: "primary.main" }}
                    >
                      <Icon sx={{ fontSize: 18 }} />
                    </IconButton>
                  </Tooltip>
                );
              })}
            </Stack>
          </>
        )}

        <Divider sx={{ my: 1 }} />

        <Stack spacing={0.75} sx={{ mt: 1 }}>
          {(device.manufacturer || device.model) && (
            <Stack direction="row" justifyContent="space-between" alignItems="center">
              <Typography variant="caption" color="text.secondary">
                Device
              </Typography>
              <Typography variant="body2" sx={{ fontWeight: 500, textAlign: "right" }}>
                {[device.manufacturer, device.model].filter(Boolean).join(" ")}
              </Typography>
            </Stack>
          )}
          <Stack direction="row" justifyContent="space-between" alignItems="center">
            <Typography variant="caption" color="text.secondary">
              Relationship
            </Typography>
            <Chip
              label={device.relationship}
              size="small"
              color={device.relationship === "Registered & Owned" ? "primary" : "default"}
              variant="outlined"
              sx={{ height: 20, fontSize: "0.7rem" }}
            />
          </Stack>
          {device.approximateLastSignInDateTime && (
            <Stack direction="row" justifyContent="space-between" alignItems="center">
              <Typography variant="caption" color="text.secondary">
                Last Sign-In
              </Typography>
              <Stack direction="row" alignItems="center" spacing={0.5}>
                <Schedule fontSize="small" sx={{ color: "text.secondary", fontSize: 14 }} />
                <Typography variant="body2">
                  <CippTimeAgo data={device.approximateLastSignInDateTime} />
                </Typography>
              </Stack>
            </Stack>
          )}
        </Stack>

        {device.ninjaDeviceId && (
          <>
            <Divider sx={{ my: 1 }} />
            <Box
              sx={{
                p: 1,
                borderRadius: 1,
                bgcolor: alpha(theme.palette.info.main, 0.04),
                border: `1px solid ${alpha(theme.palette.info.main, 0.12)}`,
              }}
            >
              <Stack spacing={0.75}>
                <Stack direction="row" alignItems="center" spacing={0.5}>
                  <Dns sx={{ fontSize: 13, color: "text.secondary" }} />
                  <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600 }}>
                    NinjaOne Hardware
                  </Typography>
                </Stack>
                {device.ninjaCpuName && (
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="caption" color="text.secondary">
                      CPU
                    </Typography>
                    <Typography variant="caption" sx={{ fontWeight: 500, textAlign: "right", maxWidth: "60%" }} noWrap>
                      {device.ninjaCpuName}
                      {device.ninjaCpuCores ? ` (${device.ninjaCpuCores}c)` : ""}
                    </Typography>
                  </Stack>
                )}
                {device.ninjaTotalRamGB != null && (
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="caption" color="text.secondary">
                      RAM
                    </Typography>
                    <Typography variant="caption" sx={{ fontWeight: 500 }}>
                      {device.ninjaTotalRamGB} GB
                    </Typography>
                  </Stack>
                )}
                {device.ninjaOsName && (
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="caption" color="text.secondary">
                      OS
                    </Typography>
                    <Typography variant="caption" sx={{ fontWeight: 500, textAlign: "right", maxWidth: "65%" }} noWrap>
                      {device.ninjaOsName}
                      {device.ninjaOsBuild ? ` (${device.ninjaOsBuild})` : ""}
                    </Typography>
                  </Stack>
                )}
              </Stack>
            </Box>
          </>
        )}
      </CardContent>
    </Card>
  );
});

DeviceCard.displayName = "DeviceCard";

export const CippUserDevicesSection = ({ userId, tenant }) => {
  const theme = useTheme();

  const registeredDevices = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: `users/${userId}/registeredDevices`,
      tenantFilter: tenant,
      $select:
        "id,displayName,deviceId,operatingSystem,operatingSystemVersion,trustType,approximateLastSignInDateTime,accountEnabled,manufacturer,model,isCompliant,isManaged",
    },
    queryKey: `UserRegisteredDevices-${userId}`,
    waiting: !!userId && !!tenant,
  });

  const ownedDevices = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: `users/${userId}/ownedDevices`,
      tenantFilter: tenant,
      $select:
        "id,displayName,deviceId,operatingSystem,operatingSystemVersion,trustType,approximateLastSignInDateTime,accountEnabled,manufacturer,model,isCompliant,isManaged",
    },
    queryKey: `UserOwnedDevices-${userId}`,
    waiting: !!userId && !!tenant,
  });

  const managedDevicesRequest = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: "deviceManagement/managedDevices",
      $select: "id,azureADDeviceId,serialNumber",
      $top: 999,
      tenantFilter: tenant,
    },
    queryKey: `ManagedDevicesMap-${tenant}`,
    waiting: !!tenant && tenant !== "AllTenants",
  });

  const ninjaDevices = ApiGetCall({
    url: "/api/ListNinjaDeviceInfo",
    data: { TenantFilter: tenant },
    queryKey: `NinjaDevices-${tenant}`,
    waiting: !!tenant,
  });

  const managedDeviceMap = useMemo(() => {
    const map = {};
    const raw = managedDevicesRequest.data;
    const arr = Array.isArray(raw) ? raw : raw?.Results || raw?.value || [];
    arr.forEach((md) => {
      const key = md.azureADDeviceId?.toLowerCase?.() || md.azureADDeviceId;
      if (key && md.id) {
        map[key] = { id: md.id, serialNumber: md.serialNumber };
      }
    });
    return map;
  }, [managedDevicesRequest.data]);

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

  const allDevices = useMemo(() => {
    const registeredDevicesList = registeredDevices.data?.Results || [];
    const ownedDevicesList = ownedDevices.data?.Results || [];
    const deviceMap = new Map();
    registeredDevicesList.forEach((device) => {
      deviceMap.set(device.id, { ...device, relationship: "Registered" });
    });
    ownedDevicesList.forEach((device) => {
      if (deviceMap.has(device.id)) {
        deviceMap.set(device.id, { ...deviceMap.get(device.id), relationship: "Registered & Owned" });
      } else {
        deviceMap.set(device.id, { ...device, relationship: "Owned" });
      }
    });

    return Array.from(deviceMap.values()).map((device) => {
      const idKey = device.id?.toLowerCase?.() || device.id;
      const managed =
        managedDeviceMap[idKey] || managedDeviceMap[device.deviceId?.toLowerCase?.()] || managedDeviceMap[device.deviceId];
      const serialNumber = managed?.serialNumber ?? device.serialNumber;
      const ninja =
        ninjaLookup[device.id] ||
        ninjaLookup[device.deviceId] ||
        ninjaLookup[idKey] ||
        (serialNumber && ninjaBySerial[String(serialNumber).trim()]);
      return {
        ...device,
        ...(ninja || {}),
        serialNumber,
        managedDeviceId: managed?.id ?? null,
      };
    });
  }, [registeredDevices.data?.Results, ownedDevices.data?.Results, ninjaLookup, ninjaBySerial, managedDeviceMap]);

  const isLoading = registeredDevices.isLoading || ownedDevices.isLoading;

  const deviceActionMutation = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [`UserRegisteredDevices-${userId}`, `UserOwnedDevices-${userId}`],
  });

  const handleDeviceAction = useCallback(
    (action, body = {}) => {
      const payload = { ...(body || {}), Action: action, tenantFilter: tenant };
      if (payload.managedDeviceId) {
        payload.GUID = payload.managedDeviceId;
        delete payload.managedDeviceId;
      }
      deviceActionMutation.mutate(
        { url: "/api/ExecDeviceAction", data: payload },
        {
          onSuccess: () => {
            registeredDevices.refetch();
            ownedDevices.refetch();
            managedDevicesRequest.refetch();
          },
        },
      );
    },
    [deviceActionMutation, tenant, registeredDevices, ownedDevices, managedDevicesRequest],
  );

  const createDeviceActionHandler = useCallback(
    (managedDeviceId) => (action, body = {}) => {
      handleDeviceAction(action, { ...body, managedDeviceId });
    },
    [handleDeviceAction],
  );

  const { totalDevices, compliantDevices, nonCompliantDevices, managedCount } = useMemo(
    () => ({
      totalDevices: allDevices.length,
      compliantDevices: allDevices.filter((d) => d.isCompliant === true).length,
      nonCompliantDevices: allDevices.filter((d) => d.isCompliant === false).length,
      managedCount: allDevices.filter((d) => d.isManaged === true).length,
    }),
    [allDevices],
  );

  if (isLoading) {
    return (
      <Stack spacing={2}>
        <Skeleton variant="rounded" height={72} />
        <Grid container spacing={2}>
          {[1, 2].map((i) => (
            <Grid key={i} size={{ xs: 12, sm: 6 }}>
              <Skeleton variant="rounded" height={220} />
            </Grid>
          ))}
        </Grid>
      </Stack>
    );
  }

  return (
    <Stack spacing={2}>
      <Card variant="outlined">
        <CardContent sx={{ py: 2, "&:last-child": { pb: 2 } }}>
          <Stack
            direction={{ xs: "column", sm: "row" }}
            spacing={{ xs: 2, sm: 4 }}
            divider={<Divider orientation="vertical" flexItem />}
            justifyContent="center"
            alignItems="center"
          >
            {[
              { value: totalDevices, label: "Entra Devices", color: "primary", icon: Devices },
              { value: compliantDevices, label: "Compliant", color: "success", icon: CheckCircle },
              { value: nonCompliantDevices, label: "Non-Compliant", color: "error", icon: Cancel },
              { value: managedCount, label: "Managed", color: "info", icon: Sync },
            ].map(({ value, label, color, icon: Icon }) => (
              <Stack key={label} direction="row" alignItems="center" spacing={1.5}>
                <Avatar sx={{ bgcolor: alpha(theme.palette[color].main, 0.1), width: 36, height: 36 }}>
                  <Icon sx={{ color: theme.palette[color].main, fontSize: 20 }} />
                </Avatar>
                <Box>
                  <Typography variant="h5" sx={{ fontWeight: 600, lineHeight: 1 }}>
                    {value}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {label}
                  </Typography>
                </Box>
              </Stack>
            ))}
          </Stack>
        </CardContent>
      </Card>

      {allDevices.length === 0 ? (
        <Card variant="outlined">
          <CardContent sx={{ textAlign: "center", py: 4 }}>
            <Devices sx={{ fontSize: 40, color: "text.disabled", mb: 1 }} />
            <Typography variant="body1" color="text.secondary">
              No registered or owned Entra devices for this user.
            </Typography>
          </CardContent>
        </Card>
      ) : (
        <Grid container spacing={2}>
          {allDevices.map((device) => (
            <Grid key={device.id} size={{ xs: 12, md: 6 }}>
              <DeviceCard
                device={device}
                tenant={tenant}
                theme={theme}
                managedDeviceId={device.managedDeviceId}
                onDeviceAction={device.managedDeviceId ? createDeviceActionHandler(device.managedDeviceId) : null}
              />
            </Grid>
          ))}
        </Grid>
      )}
    </Stack>
  );
};
