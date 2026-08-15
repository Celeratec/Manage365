import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { CippTablePage } from "../../../components/CippComponents/CippTablePage.jsx";
import {
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
  LinearProgress,
  Tooltip,
  useMediaQuery,
  IconButton,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  PersonAdd,
  PersonRemove,
  OpenInNew,
  Storage,
  CalendarToday,
  Person,
  Warning,
  TrendingDown,
  Description,
  Lock,
  DataUsage,
  CloudQueue,
  FolderOpen,
  LinkOff,
  CloudDone,
  CheckCircle,
  QueryStats,
} from "@mui/icons-material";
import { CippDataTable } from "../../../components/CippTable/CippDataTable";
import { useSettings } from "../../../hooks/use-settings";
import { getCippFormatting } from "../../../utils/get-cipp-formatting";
import { useMemo, useCallback } from "react";

// Helper to calculate storage percentage
const getStoragePercentage = (used, allocated) => {
  if (!allocated || allocated === 0) return 0;
  return Math.min(100, Math.round((used / allocated) * 100));
};

// Helper to get storage status color
const getStorageStatusColor = (percentage) => {
  if (percentage >= 90) return "error";
  if (percentage >= 75) return "warning";
  return "success";
};

// Helper to check if OneDrive is inactive (no activity in 90 days)
const isInactive = (lastActivityDate) => {
  if (!lastActivityDate) return true;
  const lastActivity = new Date(lastActivityDate);
  const ninetyDaysAgo = new Date();
  ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);
  return lastActivity < ninetyDaysAgo;
};

// Helper to check if recently active (within 7 days)
const isRecentlyActive = (lastActivityDate) => {
  if (!lastActivityDate) return false;
  const lastActivity = new Date(lastActivityDate);
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  return lastActivity >= sevenDaysAgo;
};

// Storage progress bar component
const StorageProgressBar = ({ used, allocated, showLabel = true }) => {
  const percentage = getStoragePercentage(used, allocated);
  const color = getStorageStatusColor(percentage);

  return (
    <Tooltip title={`${used} GB used of ${allocated} GB allocated (${percentage}%)`}>
      <Box sx={{ width: "100%", minWidth: 100 }}>
        {showLabel && (
          <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 0.5 }}>
            <Typography variant="caption" color="text.secondary">
              {used} GB
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {percentage}%
            </Typography>
          </Stack>
        )}
        <LinearProgress
          variant="determinate"
          value={percentage}
          color={color}
          sx={{
            height: 6,
            borderRadius: 3,
            bgcolor: (theme) => alpha(theme.palette.grey[500], 0.15),
          }}
        />
      </Box>
    </Tooltip>
  );
};

const Page = () => {
  const pageTitle = "OneDrive";
  const tenantFilter = useSettings().currentTenant;
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  const actions = useMemo(
    () => [
      {
        label: "Open OneDrive",
        type: "link",
        icon: <OpenInNew />,
        link: "[webUrl]",
        external: true,
        category: "view",
      },
      {
        label: "Browse Files",
        type: "link",
        icon: <FolderOpen />,
        link: "/teams-share/onedrive/file-browser?siteId=[siteId]&name=[displayName]",
        category: "view",
      },
      {
        label: "Add Permissions",
        type: "POST",
        icon: <PersonAdd />,
        url: "/api/ExecSharePointPerms",
        data: {
          UPN: "ownerPrincipalName",
          URL: "webUrl",
          RemovePermission: false,
        },
        confirmText:
          "Select the user to grant admin access to [displayName]'s OneDrive.",
        fields: [
          {
            type: "autoComplete",
            name: "onedriveAccessUser",
            label: "Select User",
            multiple: false,
            creatable: false,
            api: {
              url: "/api/ListGraphRequest",
              data: {
                Endpoint: "users",
                $select: "id,displayName,userPrincipalName",
                $top: 999,
                $count: true,
              },
              queryKey: "ListUsersAutoComplete",
              dataKey: "Results",
              labelField: (user) => `${user.displayName} (${user.userPrincipalName})`,
              valueField: "userPrincipalName",
              addedField: { id: "id" },
              showRefresh: true,
            },
          },
        ],
        multiPost: false,
        category: "edit",
      },
      {
        label: "Remove Permissions",
        type: "POST",
        icon: <PersonRemove />,
        url: "/api/ExecSharePointPerms",
        data: {
          UPN: "ownerPrincipalName",
          URL: "webUrl",
          RemovePermission: true,
        },
        confirmText:
          "Select the user to remove admin access from [displayName]'s OneDrive.",
        fields: [
          {
            type: "autoComplete",
            name: "onedriveAccessUser",
            label: "Select User",
            multiple: false,
            creatable: false,
            api: {
              url: "/api/ListGraphRequest",
              data: {
                Endpoint: "users",
                $select: "id,displayName,userPrincipalName",
                $top: 999,
                $count: true,
              },
              queryKey: "ListUsersAutoComplete",
              dataKey: "Results",
              labelField: (user) => `${user.displayName} (${user.userPrincipalName})`,
              valueField: "userPrincipalName",
              addedField: { id: "id" },
              showRefresh: true,
            },
          },
        ],
        multiPost: false,
        category: "edit",
      },
      {
        label: "Set Storage Quota",
        type: "POST",
        icon: <DataUsage />,
        url: "/api/ExecSetSiteProperty",
        data: {
          SiteId: "siteId",
          DisplayName: "displayName",
        },
        confirmText:
          "Set the storage quota for [displayName]'s OneDrive. Values are in GB. The warning level triggers a notification when storage is getting full.",
        fields: [
          {
            type: "textField",
            name: "StorageMaximumLevelGB",
            label: "Maximum Storage (GB)",
            required: true,
          },
          {
            type: "textField",
            name: "StorageWarningLevelGB",
            label: "Warning Level (GB, optional — defaults to 90% of max)",
          },
        ],
        multiPost: false,
        category: "edit",
      },
      {
        label: "Get Live Storage",
        type: "POST",
        icon: <QueryStats />,
        url: "/api/ListSiteLiveStorage",
        data: {
          SiteId: "siteId",
          DisplayName: "displayName",
        },
        confirmText:
          "Fetch real-time storage data for [displayName]'s OneDrive directly from the SharePoint Admin API. This bypasses the usage reports cache and returns current values.",
        multiPost: false,
        category: "view",
      },
      {
        label: "Lock / Unlock",
        type: "POST",
        icon: <Lock />,
        url: "/api/ExecSetSiteProperty",
        data: {
          SiteId: "siteId",
          DisplayName: "displayName",
        },
        confirmText:
          "Set the lock state for [displayName]'s OneDrive. 'Read Only' prevents edits, 'No Access' blocks all users, and 'Unlock' restores normal access.",
        fields: [
          {
            type: "autoComplete",
            name: "LockState",
            label: "Lock State",
            multiple: false,
            creatable: false,
            options: [
              { label: "Unlock (normal access)", value: "Unlock" },
              { label: "Read Only", value: "ReadOnly" },
              { label: "No Access", value: "NoAccess" },
            ],
            required: true,
          },
        ],
        multiPost: false,
        category: "security",
      },
      {
        label: "Provision OneDrive",
        type: "POST",
        icon: <CloudDone />,
        url: "/api/ExecOneDriveProvision",
        data: {
          UserPrincipalName: "ownerPrincipalName",
        },
        confirmText:
          "Provision a OneDrive personal site for [displayName] ([ownerPrincipalName]). Use this if the user's OneDrive has not been created yet.",
        multiPost: false,
        category: "edit",
      },
      {
        label: "Revoke All Sharing Links",
        type: "POST",
        icon: <LinkOff />,
        url: "/api/ExecRevokeOneDriveLink",
        data: {
          SiteId: "siteId",
          DisplayName: "displayName",
          RevokeAll: true,
        },
        confirmText:
          "Are you sure you want to revoke all external sharing links on [displayName]'s OneDrive? This will remove anonymous and external sharing links from the root. Internal permissions will not be affected.",
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
        filterName: "High Storage (>75%)",
        value: [{ id: "storageStatus", value: "high" }],
        type: "column",
      },
      {
        filterName: "Critical Storage (>90%)",
        value: [{ id: "storageStatus", value: "critical" }],
        type: "column",
      },
      {
        filterName: "Inactive (90+ days)",
        value: [{ id: "activityStatus", value: "inactive" }],
        type: "column",
      },
      {
        filterName: "Large OneDrives (>10 GB)",
        value: [{ id: "sizeCategory", value: "large" }],
        type: "column",
      },
      {
        filterName: "Recently Active (<7 days)",
        value: [{ id: "activityStatus", value: "recent" }],
        type: "column",
      },
      {
        filterName: "No Files",
        value: [{ id: "fileCount", value: 0 }],
        type: "column",
      },
    ],
    []
  );

  const cardConfig = useMemo(
    () => ({
      title: "displayName",
      avatar: {
        field: "storageUsedInGigabytes",
        customRender: (value, item) => {
          const pct = getStoragePercentage(
            item?.storageUsedInGigabytes,
            item?.storageAllocatedInGigabytes
          );
          const color = getStorageStatusColor(pct);
          return (
            <Avatar
              sx={{
                bgcolor: (t) => alpha(t.palette[color]?.main || t.palette.grey[500], 0.15),
                color: (t) => t.palette[color]?.main || t.palette.grey[500],
              }}
            >
              <CloudQueue />
            </Avatar>
          );
        },
      },
      badges: [
        {
          field: "storageStatus",
          conditions: {
            critical: { icon: <Storage fontSize="small" />, color: "error", label: "Storage Critical (>90%)" },
            high: { icon: <Storage fontSize="small" />, color: "warning", label: "Storage High (>75%)" },
            normal: { icon: <Storage fontSize="small" />, color: "success", label: "Storage OK" },
          },
          transform: (value, item) => {
            const pct = getStoragePercentage(
              item.storageUsedInGigabytes,
              item.storageAllocatedInGigabytes
            );
            if (pct >= 90) return "critical";
            if (pct >= 75) return "high";
            return "normal";
          },
          iconOnly: true,
        },
        {
          field: "activityStatus",
          conditions: {
            inactive: {
              icon: <TrendingDown fontSize="small" />,
              color: "warning",
              label: "Inactive (90+ days)",
            },
            recent: {
              icon: <CheckCircle fontSize="small" />,
              color: "success",
              label: "Recently Active",
            },
          },
          transform: (value, item) => {
            if (isRecentlyActive(item.lastActivityDate)) return "recent";
            if (isInactive(item.lastActivityDate)) return "inactive";
            return null;
          },
          iconOnly: true,
        },
      ],
      extraFields: [
        { field: "ownerPrincipalName", icon: <Person />, label: "Owner" },
        {
          field: "storageUsedInGigabytes",
          icon: <Storage />,
          label: "Storage",
          customRender: (value, item) => (
            <StorageProgressBar
              used={item.storageUsedInGigabytes || 0}
              allocated={item.storageAllocatedInGigabytes || 1}
              showLabel={false}
            />
          ),
        },
      ],
      desktopFields: [
        {
          field: "fileCount",
          icon: <Description />,
          label: "Files",
          formatter: (value) => (value ? value.toLocaleString() : "0"),
        },
        { field: "lastActivityDate", icon: <CalendarToday />, label: "Last Active" },
      ],
      cardGridProps: { md: 6, lg: 4 },
      mobileQuickActions: ["Open OneDrive", "Browse Files", "Add Permissions"],
    }),
    []
  );

  const offCanvasChildren = useCallback(
    (row) => {
      const storagePercentage = getStoragePercentage(
        row.storageUsedInGigabytes,
        row.storageAllocatedInGigabytes
      );
      const storageColor = getStorageStatusColor(storagePercentage);
      const inactive = isInactive(row.lastActivityDate);
      const recent = isRecentlyActive(row.lastActivityDate);

      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper
            elevation={0}
            sx={{
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(
                theme.palette.info.main,
                0.15
              )} 0%, ${alpha(theme.palette.info.main, 0.05)} 100%)`,
              borderLeft: `4px solid ${theme.palette.info.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(theme.palette.info.main, 0.15),
                  color: theme.palette.info.main,
                  width: 56,
                  height: 56,
                }}
              >
                <CloudQueue sx={{ fontSize: 28 }} />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.displayName || "Unknown OneDrive"}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                  <Chip label="OneDrive" size="small" color="info" variant="outlined" />
                  {inactive && (
                    <Chip
                      icon={<TrendingDown fontSize="small" />}
                      label="Inactive"
                      size="small"
                      color="warning"
                      variant="outlined"
                    />
                  )}
                  {recent && (
                    <Chip
                      icon={<CheckCircle fontSize="small" />}
                      label="Active"
                      size="small"
                      color="success"
                      variant="outlined"
                    />
                  )}
                </Stack>
              </Box>
            </Stack>
          </Paper>

          {/* Quick Stats */}
          <Paper variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
            <Stack direction="row" spacing={2} justifyContent="space-around">
              <Box sx={{ textAlign: "center" }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: "primary.main" }}>
                  {row.fileCount?.toLocaleString() || 0}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Files
                </Typography>
              </Box>
              <Divider orientation="vertical" flexItem />
              <Box sx={{ textAlign: "center" }}>
                <Typography
                  variant="h5"
                  sx={{ fontWeight: 700, color: `${storageColor}.main` }}
                >
                  {storagePercentage}%
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Storage Used
                </Typography>
              </Box>
              <Divider orientation="vertical" flexItem />
              <Box sx={{ textAlign: "center" }}>
                <Typography variant="h5" sx={{ fontWeight: 700 }}>
                  {row.storageUsedInGigabytes || 0}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  GB Used
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Storage Details */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <Storage fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Storage Details
              </Typography>
            </Stack>
            <Box sx={{ mb: 2 }}>
              <StorageProgressBar
                used={row.storageUsedInGigabytes || 0}
                allocated={row.storageAllocatedInGigabytes || 1}
              />
            </Box>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Storage Allocated
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.storageAllocatedInGigabytes} GB
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Storage Available
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {((row.storageAllocatedInGigabytes || 0) - (row.storageUsedInGigabytes || 0)).toFixed(
                    2
                  )}{" "}
                  GB
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Owner & Activity */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <Person fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Owner & Activity
              </Typography>
            </Stack>
            <Stack spacing={1}>
              {row.ownerPrincipalName && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">
                    Owner
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }} noWrap>
                    {row.ownerDisplayName || row.ownerPrincipalName}
                  </Typography>
                </Stack>
              )}
              {row.createdDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">
                    Created
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.createdDateTime, "createdDateTime")}
                  </Typography>
                </Stack>
              )}
              {row.lastActivityDate && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">
                    Last Activity
                  </Typography>
                  <Stack direction="row" alignItems="center" spacing={0.5}>
                    {inactive && (
                      <Tooltip title="No activity in over 90 days">
                        <Warning fontSize="small" color="warning" />
                      </Tooltip>
                    )}
                    <Typography variant="body2" sx={{ fontWeight: 500 }}>
                      {getCippFormatting(row.lastActivityDate, "lastActivityDate")}
                    </Typography>
                  </Stack>
                </Stack>
              )}
            </Stack>
          </Box>

          {/* OneDrive URL */}
          {row.webUrl && (
            <>
              <Divider />
              <Box>
                <Stack
                  direction="row"
                  alignItems="center"
                  justifyContent="space-between"
                  sx={{ mb: 1 }}
                >
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    OneDrive URL
                  </Typography>
                  <Tooltip title="Open OneDrive in new tab">
                    <IconButton
                      size="small"
                      component="a"
                      href={row.webUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      <OpenInNew fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </Stack>
                <Typography
                  component="a"
                  href={row.webUrl}
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
                  {row.webUrl}
                </Typography>
              </Box>
            </>
          )}

          <Divider />

          {/* Shared Items Table */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 2 }}>
              Shared Items
            </Typography>
            <CippDataTable
              title="Shared Items"
              queryKey={`onedrive-sharing-${row.siteId}`}
              api={{
                url: "/api/ListOneDriveSharing",
                data: {
                  SiteId: row.siteId,
                  tenantFilter: tenantFilter,
                },
              }}
              simpleColumns={["name", "type", "sharedWith", "sharedDateTime"]}
            />
          </Box>
        </Stack>
      );
    },
    [theme, tenantFilter]
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
        ? ["displayName", "storageUsedInGigabytes", "lastActivityDate"]
        : [
            "displayName",
            "ownerPrincipalName",
            "lastActivityDate",
            "fileCount",
            "storageUsedInGigabytes",
            "storageAllocatedInGigabytes",
            "webUrl",
          ],
    [isMobile]
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListSites?type=OneDriveUsageAccount"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      filters={filters}
      cardConfig={cardConfig}
      dataFreshnessField="reportRefreshDate"
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
