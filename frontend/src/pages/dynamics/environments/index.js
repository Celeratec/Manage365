import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { CippTablePage } from "../../../components/CippComponents/CippTablePage.jsx";
import {
  Chip,
  Typography,
  Stack,
  Paper,
  Avatar,
  Divider,
  useTheme,
  useMediaQuery,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box } from "@mui/system";
import {
  Cloud,
  Science,
  CheckCircle,
  Info,
  Language,
  CalendarToday,
  Storage,
  OpenInNew,
} from "@mui/icons-material";
import { useMemo, useCallback } from "react";
import { getCippFormatting } from "../../../utils/get-cipp-formatting";

const getEnvironmentTypeInfo = (type) => {
  const typeMap = {
    Production: { icon: <Cloud />, color: "success", label: "Production" },
    Sandbox: { icon: <Science />, color: "warning", label: "Sandbox" },
    Trial: { icon: <Science />, color: "info", label: "Trial" },
    Default: { icon: <Cloud />, color: "primary", label: "Default" },
    Developer: { icon: <Science />, color: "secondary", label: "Developer" },
  };
  return typeMap[type] || { icon: <Cloud />, color: "default", label: type || "Unknown" };
};

const Page = () => {
  const pageTitle = "Dynamics 365 Environments";
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  const actions = useMemo(
    () => [
      {
        label: "View Users",
        type: "link",
        icon: <Info />,
        link: "/dynamics/administration/users?dynamicsUrl=[apiUrl]&envName=[displayName]",
        category: "view",
        quickAction: true,
      },
      {
        label: "View Security Roles",
        type: "link",
        icon: <Info />,
        link: "/dynamics/administration/security-roles?dynamicsUrl=[apiUrl]&envName=[displayName]",
        category: "view",
      },
      {
        label: "View Business Units",
        type: "link",
        icon: <Info />,
        link: "/dynamics/administration/business-units?dynamicsUrl=[apiUrl]&envName=[displayName]",
        category: "view",
      },
      {
        label: "View Solutions",
        type: "link",
        icon: <Info />,
        link: "/dynamics/administration/solutions?dynamicsUrl=[apiUrl]&envName=[displayName]",
        category: "view",
      },
      {
        label: "Open Environment",
        type: "link",
        icon: <OpenInNew />,
        link: "[url]",
        external: true,
        category: "view",
        quickAction: true,
      },
    ],
    []
  );

  const filters = useMemo(
    () => [
      {
        filterName: "Production",
        value: [{ id: "environmentType", value: "Production" }],
        type: "column",
      },
      {
        filterName: "Sandbox",
        value: [{ id: "environmentType", value: "Sandbox" }],
        type: "column",
      },
      {
        filterName: "Trial",
        value: [{ id: "environmentType", value: "Trial" }],
        type: "column",
      },
    ],
    []
  );

  const cardConfig = useMemo(
    () => ({
      title: "displayName",
      avatar: {
        field: "environmentType",
        customRender: (value) => {
          const typeInfo = getEnvironmentTypeInfo(value);
          return (
            <Avatar
              sx={{
                bgcolor: (theme) =>
                  alpha(theme.palette[typeInfo.color]?.main || theme.palette.grey[500], 0.15),
                color: (theme) =>
                  theme.palette[typeInfo.color]?.main || theme.palette.grey[500],
              }}
            >
              {typeInfo.icon}
            </Avatar>
          );
        },
      },
      badges: [
        {
          field: "environmentType",
          conditions: {
            Production: { icon: "check", color: "success", label: "Production" },
            Sandbox: { icon: "science", color: "warning", label: "Sandbox" },
            Trial: { icon: "info", color: "info", label: "Trial" },
          },
        },
      ],
      extraFields: [
        { field: "region", icon: <Language />, label: "Region" },
        { field: "version", icon: <Storage />, label: "Version" },
      ],
      desktopFields: [
        { field: "createdTime", icon: <CalendarToday />, label: "Created" },
      ],
      cardGridProps: {
        md: 6,
        lg: 4,
      },
      mobileQuickActions: ["View Users", "Open Environment"],
    }),
    []
  );

  const offCanvasChildren = useCallback(
    (row) => {
      const typeInfo = getEnvironmentTypeInfo(row.environmentType);
      return (
        <Stack spacing={3}>
          <Paper
            elevation={0}
            sx={{
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(
                theme.palette[typeInfo.color]?.main || theme.palette.primary.main,
                0.15
              )} 0%, ${alpha(
                theme.palette[typeInfo.color]?.main || theme.palette.primary.main,
                0.05
              )} 100%)`,
              borderLeft: `4px solid ${
                theme.palette[typeInfo.color]?.main || theme.palette.primary.main
              }`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(
                    theme.palette[typeInfo.color]?.main || theme.palette.primary.main,
                    0.15
                  ),
                  color:
                    theme.palette[typeInfo.color]?.main || theme.palette.primary.main,
                  width: 56,
                  height: 56,
                }}
              >
                {typeInfo.icon}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.displayName || "Unknown Environment"}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center">
                  <Chip
                    label={typeInfo.label}
                    size="small"
                    color={typeInfo.color}
                    variant="outlined"
                  />
                  {row.isDefault && (
                    <Chip
                      icon={<CheckCircle fontSize="small" />}
                      label="Default"
                      size="small"
                      color="primary"
                      variant="outlined"
                    />
                  )}
                </Stack>
              </Box>
            </Stack>
          </Paper>

          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Environment Details
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Type
                </Typography>
                <Chip label={row.environmentType} size="small" color={typeInfo.color} />
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Region
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.region || "N/A"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Domain
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.domainName || "N/A"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Version
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.version || "N/A"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Created
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.createdTime
                    ? getCippFormatting(row.createdTime, "createdTime")
                    : "N/A"}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {row.url && (
            <Box>
              <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1 }}>
                Environment URL
              </Typography>
              <Typography
                component="a"
                href={row.url}
                target="_blank"
                rel="noopener noreferrer"
                variant="body2"
                sx={{
                  color: "primary.main",
                  textDecoration: "none",
                  "&:hover": { textDecoration: "underline" },
                  wordBreak: "break-all",
                }}
              >
                {row.url}
              </Typography>
            </Box>
          )}

          {row.apiUrl && (
            <Box>
              <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1 }}>
                API URL
              </Typography>
              <Typography variant="body2" sx={{ wordBreak: "break-all" }}>
                {row.apiUrl}
              </Typography>
            </Box>
          )}
        </Stack>
      );
    },
    [theme]
  );

  const offCanvas = useMemo(
    () => ({
      actions: actions,
      children: offCanvasChildren,
      size: "lg",
    }),
    [actions, offCanvasChildren]
  );

  const simpleColumns = useMemo(
    () =>
      isMobile
        ? ["displayName", "environmentType", "region"]
        : [
            "displayName",
            "environmentType",
            "state",
            "region",
            "domainName",
            "version",
            "url",
            "createdTime",
          ],
    [isMobile]
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListDynamicsEnvironments"
      apiDataKey="Results"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      filters={filters}
      cardConfig={cardConfig}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
