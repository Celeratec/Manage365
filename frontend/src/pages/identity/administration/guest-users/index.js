import { useState, useMemo } from "react";
import { EyeIcon } from "@heroicons/react/24/outline";
import { useCippReportDB } from "../../../../components/CippComponents/CippReportDBControls";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippHead } from "../../../../components/CippComponents/CippHead.jsx";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Grid,
  Skeleton,
  Stack,
  Typography,
} from "@mui/material";
import {
  GroupOutlined,
  PersonOff,
  HourglassEmpty,
  Warning,
  CheckCircle,
  Block,
  Send,
} from "@mui/icons-material";
import { useSettings } from "../../../../hooks/use-settings.js";
import { ApiGetCall, ApiPostCall } from "../../../../api/ApiCall.jsx";
import { CippDataTable } from "../../../../components/CippTable/CippDataTable.js";
import { getCippError } from "../../../../utils/get-cipp-error.js";

const STATUS_CONFIG = {
  Active: { color: "success", icon: CheckCircle },
  Stale: { color: "error", icon: Warning },
  Pending: { color: "warning", icon: HourglassEmpty },
  "Pending Acceptance": { color: "warning", icon: HourglassEmpty },
  Disabled: { color: "default", icon: Block },
  "Never Signed In": { color: "info", icon: PersonOff },
};

const SummaryCard = ({ title, count, icon: Icon, color, selected, onClick }) => (
  <Card
    variant={selected ? "elevation" : "outlined"}
    sx={{
      cursor: "pointer",
      borderColor: selected ? `${color}.main` : undefined,
      borderWidth: selected ? 2 : 1,
      transition: "all 0.2s",
      "&:hover": { borderColor: `${color}.main` },
    }}
    onClick={onClick}
  >
    <CardContent sx={{ py: 1.5, "&:last-child": { pb: 1.5 } }}>
      <Stack direction="row" alignItems="center" spacing={1.5}>
        {Icon && <Icon color={color} sx={{ fontSize: 28 }} />}
        <Box>
          <Typography variant="h5" sx={{ fontWeight: 700, lineHeight: 1 }}>
            {count ?? <Skeleton width={30} />}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {title}
          </Typography>
        </Box>
      </Stack>
    </CardContent>
  </Card>
);

const Page = () => {
  const settings = useSettings();
  const currentTenant = settings.currentTenant;
  const [statusFilter, setStatusFilter] = useState(null);

  const reportDB = useCippReportDB({
    apiUrl: "/api/ListGuestUsers",
    queryKey: "ListGuestUsers",
    cacheName: "Guests",
    syncTitle: "Sync Guest Users",
    allowToggle: true,
    defaultCached: true,
    allowAllTenantSync: true,
    cacheColumns: ["CacheTimestamp"],
  });

  const guestQuery = ApiGetCall({
    url: reportDB.resolvedApiUrl,
    data: { tenantFilter: currentTenant },
    queryKey: reportDB.resolvedQueryKey,
    waiting: !currentTenant,
  });

  const payload = guestQuery.data?.Results ?? guestQuery.data;
  const guests = Array.isArray(payload) ? payload : payload?.guests || [];
  const summary = payload?.summary || {
    totalGuests: guests.length,
    activeGuests: guests.filter((guest) => guest.status === "Active").length,
    staleGuests: guests.filter((guest) => guest.status === "Stale").length,
    pendingGuests: guests.filter(
      (guest) => guest.status === "Pending" || guest.status === "Pending Acceptance",
    ).length,
    disabledGuests: guests.filter((guest) => guest.status === "Disabled").length,
    neverSignedIn: guests.filter((guest) => guest.status === "Never Signed In").length,
  };

  const filteredGuests = useMemo(() => {
    if (!statusFilter) return guests;
    return guests.filter((g) => g.status === statusFilter);
  }, [guests, statusFilter]);

  const reinviteApi = ApiPostCall({
    relatedQueryKeys: [`GuestUsers-${currentTenant}`],
  });

  const handleReinvite = (guest) => {
    reinviteApi.mutate({
      url: "/api/AddGuest",
      data: {
        tenantFilter: currentTenant,
        displayName: guest.displayName,
        mail: guest.mail,
        sendInvite: true,
      },
    });
  };

  const columns = [
    {
      id: "displayName",
      header: "Name",
      accessorKey: "displayName",
      cell: ({ row }) => (
        <Typography variant="body2" sx={{ fontWeight: 500 }}>
          {row.original.displayName}
        </Typography>
      ),
    },
    {
      id: "mail",
      header: "Email",
      accessorKey: "mail",
    },
    {
      id: "sourceDomain",
      header: "Source Domain",
      accessorKey: "sourceDomain",
      cell: ({ row }) => (
        <Chip label={row.original.sourceDomain} size="small" variant="outlined" />
      ),
    },
    {
      id: "status",
      header: "Status",
      accessorKey: "status",
      cell: ({ row }) => {
        const config = STATUS_CONFIG[row.original.status] || STATUS_CONFIG.Active;
        return <Chip label={row.original.status} size="small" color={config.color} />;
      },
    },
    {
      id: "accountEnabled",
      header: "Enabled",
      accessorKey: "accountEnabled",
      cell: ({ row }) => (
        <Chip
          label={row.original.accountEnabled ? "Yes" : "No"}
          size="small"
          color={row.original.accountEnabled ? "success" : "default"}
          variant="outlined"
        />
      ),
    },
    {
      id: "lastSignIn",
      header: "Last Sign-In",
      accessorKey: "lastSignIn",
      cell: ({ row }) => {
        const d = row.original.lastSignIn;
        if (!d) return <Typography variant="caption" color="text.secondary">Never</Typography>;
        return <Typography variant="body2">{new Date(d).toLocaleDateString()}</Typography>;
      },
    },
    {
      id: "createdDateTime",
      header: "Created",
      accessorKey: "createdDateTime",
      cell: ({ row }) => {
        const d = row.original.createdDateTime;
        if (!d) return "-";
        return <Typography variant="body2">{new Date(d).toLocaleDateString()}</Typography>;
      },
    },
    {
      id: "daysSinceSignIn",
      header: "Days Inactive",
      accessorKey: "daysSinceSignIn",
      cell: ({ row }) => {
        const days = row.original.daysSinceSignIn;
        if (days == null) return "-";
        return (
          <Typography variant="body2" color={days > 90 ? "error.main" : "text.primary"}>
            {days} days
          </Typography>
        );
      },
    },
  ];

  const rowActions = [
    {
      label: "View User",
      link: "/identity/administration/users/user?userId=[id]",
      icon: <EyeIcon />,
      color: "success",
      category: "view",
    },
    {
      label: "Re-invite Guest",
      icon: <Send />,
      color: "info",
      condition: (row) => row?.mail,
      onClick: (row) => handleReinvite(row),
      category: "edit",
    },
  ];

  return (
    <>
      <CippHead title="Guest Users" />
      <Box sx={{ p: 3 }}>
        <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
          <Typography variant="h4">Guest Lifecycle Dashboard</Typography>
          {reportDB.controls}
        </Stack>

        {!currentTenant && (
          <Alert severity="info" sx={{ mb: 2 }}>
            Select a tenant to view guest users.
          </Alert>
        )}

        {currentTenant && (
          <>
            <Grid container spacing={2} sx={{ mb: 3 }}>
              <Grid item xs={6} sm={4} md={2}>
                <SummaryCard
                  title="Total"
                  count={summary.totalGuests}
                  icon={GroupOutlined}
                  color="primary"
                  selected={!statusFilter}
                  onClick={() => setStatusFilter(null)}
                />
              </Grid>
              {Object.entries(STATUS_CONFIG).map(([status, config]) => (
                <Grid item xs={6} sm={4} md={2} key={status}>
                  <SummaryCard
                    title={status}
                    count={summary[
                      status === "Active" ? "activeGuests" :
                      status === "Stale" ? "staleGuests" :
                      status === "Pending" || status === "Pending Acceptance" ? "pendingGuests" :
                      status === "Disabled" ? "disabledGuests" :
                      "neverSignedIn"
                    ]}
                    icon={config.icon}
                    color={config.color}
                    selected={statusFilter === status}
                    onClick={() => setStatusFilter(statusFilter === status ? null : status)}
                  />
                </Grid>
              ))}
            </Grid>

            <CippDataTable
              title="Guest Users"
              data={filteredGuests}
              columns={columns}
              isFetching={guestQuery.isFetching}
              actions={rowActions}
            />
          </>
        )}
      </Box>
      {reportDB.syncDialog}
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
