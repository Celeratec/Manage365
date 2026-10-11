import { Alert, Card, CardContent, CardHeader, Divider, Typography, Chip, Box } from "@mui/material";
import { Grid, Stack } from "@mui/system";
import CippPageCard from "../../../components/CippCards/CippPageCard";
import { CippDataTable } from "../../../components/CippTable/CippDataTable";
import { Layout as DashboardLayout } from '../../../layouts/index'
import { ApiGetCall } from '../../../api/ApiCall'
import { CippInfoBar } from '../../../components/CippCards/CippInfoBar'
import {
  ArrowPathIcon,
  CheckCircleIcon,
  ClockIcon,
  ExclamationTriangleIcon,
  BuildingOfficeIcon,
} from '@heroicons/react/24/outline'
import { getCippFormatting } from '../../../utils/get-cipp-formatting'

const resultText = (results) => {
  if (typeof results === "string") return results;
  if (results == null || results === "") return "";
  try {
    return JSON.stringify(results);
  } catch {
    return "";
  }
};

const syncRowsFrom = (payload) => {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.Results)) return payload.Results;
  if (payload && typeof payload === "object" && (payload.Tenant || payload.SyncType || payload.RowKey)) {
    return [payload];
  }
  return [];
};

const Page = () => {
  // Separate from the table's infinite query. Sharing "ListExtensionSync" makes this
  // observer read { pages, pageParams }, and .filter then throws.
  const syncData = ApiGetCall({
    url: "/api/ListExtensionSync",
    queryKey: "ListExtensionSyncSummary",
  });
  const syncRows = syncRowsFrom(syncData.data);

  const stats = {
    total: syncRows.length,
    completed: syncRows.filter((item) => {
      const text = resultText(item?.Results);
      return text && !text.includes("Error");
    }).length,
    pending: syncRows.filter((item) => !resultText(item?.Results)).length,
    errors: syncRows.filter((item) => resultText(item?.Results).includes("Error")).length,
  };

  const infoBarData = [
    {
      name: "Total Jobs",
      data: stats.total,
      icon: <ArrowPathIcon />,
      color: "primary",
    },
    {
      name: "Completed",
      data: stats.completed,
      icon: <CheckCircleIcon />,
      color: "success",
    },
    {
      name: "Pending",
      data: stats.pending,
      icon: <ClockIcon />,
      color: "info",
    },
    {
      name: "Errors",
      data: stats.errors,
      icon: <ExclamationTriangleIcon />,
      color: stats.errors > 0 ? "error" : "success",
    },
  ];

  // Custom columns with better formatting
  const columns = [
    {
      header: "Tenant",
      id: "Tenant",
      accessorKey: "Tenant",
      Cell: ({ row }) => (
        <Stack direction="row" spacing={1} alignItems="center">
          <BuildingOfficeIcon style={{ width: 16, height: 16, opacity: 0.6 }} />
          <Typography variant="body2" fontWeight={500}>
            {row.original.Tenant}
          </Typography>
        </Stack>
      ),
    },
    {
      header: "Sync Type",
      id: "SyncType",
      accessorKey: "SyncType",
      Cell: ({ row }) => (
        <Chip
          label={row.original.SyncType}
          size="small"
          color="primary"
          variant="outlined"
        />
      ),
    },
    {
      header: "Task",
      id: "Task",
      accessorKey: "Task",
      Cell: ({ row }) => (
        <Typography variant="body2">{row.original.Task}</Typography>
      ),
    },
    {
      header: "Scheduled Time",
      id: "ScheduledTime",
      accessorKey: "ScheduledTime",
      Cell: ({ row }) => getCippFormatting(row.original.ScheduledTime, "ScheduledTime"),
    },
    {
      header: "Executed Time",
      id: "ExecutedTime",
      accessorKey: "ExecutedTime",
      Cell: ({ row }) => getCippFormatting(row.original.ExecutedTime, "ExecutedTime"),
    },
    {
      header: "Last Run",
      id: "LastRun",
      accessorKey: "LastRun",
      Cell: ({ row }) => getCippFormatting(row.original.LastRun, "LastRun"),
    },
    {
      header: "Repeats Every",
      id: "RepeatsEvery",
      accessorKey: "RepeatsEvery",
      Cell: ({ row }) => (
        <Chip
          label={row.original.RepeatsEvery || "One-time"}
          size="small"
          variant="outlined"
          color={row.original.RepeatsEvery ? "info" : "default"}
        />
      ),
    },
    {
      header: "Results",
      id: "Results",
      accessorKey: "Results",
      Cell: ({ row }) => {
        const results = resultText(row.original.Results);
        if (!results) {
          return (
            <Chip
              label="Pending"
              size="small"
              color="info"
              variant="outlined"
              icon={<ClockIcon style={{ width: 14, height: 14 }} />}
            />
          );
        }
        const isError = results.includes("Error") || results.includes("Failed");
        return (
          <Chip
            label={isError ? "Error" : "Success"}
            size="small"
            color={isError ? "error" : "success"}
            variant={isError ? "filled" : "outlined"}
            icon={
              isError ? (
                <ExclamationTriangleIcon style={{ width: 14, height: 14 }} />
              ) : (
                <CheckCircleIcon style={{ width: 14, height: 14 }} />
              )
            }
          />
        );
      },
    },
  ];

  return (
    <CippPageCard backButtonTitle="Integrations" title="Integration Sync Jobs" noTenantInHead={true}>
      <Stack spacing={2} sx={{ p: 2 }}>
        {/* Status Summary */}
        <CippInfoBar data={infoBarData} isFetching={syncData.isFetching} />

        {/* Info Alert */}
        <Alert severity="info">
          <Typography variant="body2">
            Integration sync jobs run automatically based on their configured schedule. Use the Force
            Sync button on individual integration pages to trigger an immediate sync.
          </Typography>
        </Alert>

        {/* Sync Jobs Table */}
        <CippDataTable
          title="Sync Jobs"
          noCard={true}
          columns={columns}
          api={{
            url: "/api/ListExtensionSync",
          }}
          queryKey="ListExtensionSync"
        />
      </Stack>
    </CippPageCard>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;
export default Page;
