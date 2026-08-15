import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { CippTablePage } from "../../../components/CippComponents/CippTablePage.jsx";
import {
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
  useMediaQuery,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  DeleteForever,
  RestoreFromTrash,
  Language,
  CalendarToday,
  Timer,
  Warning,
} from "@mui/icons-material";
import { getCippFormatting } from "../../../utils/get-cipp-formatting";
import { useMemo, useCallback } from "react";

// Days-remaining color helper
const getDaysColor = (days) => {
  if (typeof days !== "number") return "default";
  if (days <= 7) return "error";
  if (days <= 30) return "warning";
  return "success";
};

const getDaysLabel = (days) => {
  if (typeof days !== "number") return "Unknown";
  if (days === 0) return "Expiring today";
  if (days === 1) return "1 day left";
  return `${days} days left`;
};

const Page = () => {
  const pageTitle = "SharePoint Recycle Bin";
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  const actions = useMemo(
    () => [
      {
        label: "Restore Site",
        type: "POST",
        icon: <RestoreFromTrash />,
        url: "/api/ExecRestoreDeletedSite",
        data: {
          SiteUrl: "webUrl",
          DisplayName: "displayName",
        },
        confirmText:
          "Are you sure you want to restore the site '[displayName]'? The site will be restored to its original URL and will be accessible again.",
        color: "warning",
        multiPost: false,
        category: "edit",
      },
      {
        label: "Permanently Delete",
        type: "POST",
        icon: <DeleteForever />,
        url: "/api/ExecRemoveDeletedSite",
        data: {
          SiteUrl: "webUrl",
          DisplayName: "displayName",
        },
        confirmText:
          "Are you sure you want to PERMANENTLY delete '[displayName]'? This action is irreversible. The site, all its content, and all associated data will be destroyed and cannot be recovered by any means.",
        color: "error",
        multiPost: false,
        category: "danger",
      },
    ],
    []
  );

  const filters = useMemo(
    () => [
      {
        filterName: "Expiring Soon (< 7 days)",
        value: [{ id: "retentionStatus", value: "critical" }],
        type: "column",
      },
      {
        filterName: "Expiring (< 30 days)",
        value: [{ id: "retentionStatus", value: "warning" }],
        type: "column",
      },
    ],
    []
  );

  const cardConfig = useMemo(
    () => ({
      title: "displayName",
      avatar: {
        field: "daysRemaining",
        customRender: (value) => {
          const color = getDaysColor(value);
          return (
            <Avatar
              sx={{
                bgcolor: (t) =>
                  alpha(t.palette[color]?.main || t.palette.grey[500], 0.15),
                color: (t) => t.palette[color]?.main || t.palette.grey[500],
              }}
            >
              <RestoreFromTrash />
            </Avatar>
          );
        },
      },
      badges: [
        {
          field: "retentionStatus",
          conditions: {
            critical: {
              icon: <Warning fontSize="small" />,
              color: "error",
              label: "Expiring < 7 days",
            },
            warning: {
              icon: <Timer fontSize="small" />,
              color: "warning",
              label: "Expiring < 30 days",
            },
          },
          transform: (value, item) => {
            if (typeof item.daysRemaining !== "number") return null;
            if (item.daysRemaining <= 7) return "critical";
            if (item.daysRemaining <= 30) return "warning";
            return null;
          },
          iconOnly: true,
        },
      ],
      extraFields: [
        { field: "webUrl", icon: <Language />, label: "URL" },
        { field: "deletedDateTime", icon: <CalendarToday />, label: "Deleted" },
      ],
      desktopFields: [
        {
          field: "daysRemaining",
          icon: <Timer />,
          label: "Retention",
          formatter: (value) => getDaysLabel(value),
        },
      ],
      cardGridProps: { md: 6, lg: 4 },
      mobileQuickActions: ["Restore Site"],
    }),
    []
  );

  const offCanvasChildren = useCallback(
    (row) => {
      const daysColor = getDaysColor(row.daysRemaining);

      return (
        <Stack spacing={3}>
          {/* Header */}
          <Box
            sx={{
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(
                theme.palette[daysColor]?.main || theme.palette.grey[500],
                0.15
              )} 0%, ${alpha(
                theme.palette[daysColor]?.main || theme.palette.grey[500],
                0.05
              )} 100%)`,
              borderLeft: `4px solid ${
                theme.palette[daysColor]?.main || theme.palette.grey[500]
              }`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(
                    theme.palette[daysColor]?.main || theme.palette.grey[500],
                    0.15
                  ),
                  color:
                    theme.palette[daysColor]?.main || theme.palette.grey[500],
                  width: 56,
                  height: 56,
                }}
              >
                <RestoreFromTrash sx={{ fontSize: 28 }} />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.displayName || "Unknown Site"}
                </Typography>
                <Chip
                  label={getDaysLabel(row.daysRemaining)}
                  size="small"
                  color={daysColor}
                  variant="outlined"
                />
              </Box>
            </Stack>
          </Box>

          {/* Deletion Details */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Deletion Details
            </Typography>
            <Stack spacing={1}>
              <Stack
                direction="row"
                justifyContent="space-between"
                alignItems="center"
              >
                <Typography variant="body2" color="text.secondary">
                  Deleted On
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.deletedDateTime
                    ? getCippFormatting(row.deletedDateTime, "deletedDateTime")
                    : "Unknown"}
                </Typography>
              </Stack>
              <Stack
                direction="row"
                justifyContent="space-between"
                alignItems="center"
              >
                <Typography variant="body2" color="text.secondary">
                  Days Remaining
                </Typography>
                <Chip
                  label={getDaysLabel(row.daysRemaining)}
                  size="small"
                  color={daysColor}
                />
              </Stack>
              <Stack
                direction="row"
                justifyContent="space-between"
                alignItems="center"
              >
                <Typography variant="body2" color="text.secondary">
                  Auto-Purge Date
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {(() => {
                    const deleted = new Date(row.deletedDateTime);
                    if (!row.deletedDateTime || isNaN(deleted.getTime())) return "Unknown";
                    return getCippFormatting(
                      new Date(deleted.getTime() + 93 * 24 * 60 * 60 * 1000).toISOString(),
                      "purgeDate"
                    );
                  })()}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Site URL */}
          {row.webUrl && (
            <Box>
              <Typography
                variant="subtitle2"
                sx={{ fontWeight: 600, mb: 1 }}
              >
                Original Site URL
              </Typography>
              <Typography
                variant="body2"
                sx={{
                  color: "text.secondary",
                  wordBreak: "break-all",
                }}
              >
                {row.webUrl}
              </Typography>
            </Box>
          )}

          <Divider />

          {/* Retention Warning */}
          {typeof row.daysRemaining === "number" && row.daysRemaining <= 30 && (
            <Box
              sx={{
                p: 2,
                borderRadius: 1,
                bgcolor: alpha(theme.palette.warning.main, 0.08),
                border: `1px solid ${alpha(theme.palette.warning.main, 0.3)}`,
              }}
            >
              <Stack direction="row" spacing={1} alignItems="flex-start">
                <Warning
                  fontSize="small"
                  sx={{ color: "warning.main", mt: 0.25 }}
                />
                <Typography variant="body2" color="text.secondary">
                  {row.daysRemaining <= 7
                    ? "This site will be permanently deleted very soon. Restore it now if you need any of its content."
                    : "This site will be automatically purged after the retention period. Restore it if you need to preserve its content."}
                </Typography>
              </Stack>
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
        ? ["displayName", "daysRemaining", "deletedDateTime"]
        : ["displayName", "webUrl", "deletedDateTime", "daysRemaining"],
    [isMobile]
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListDeletedSites"
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
