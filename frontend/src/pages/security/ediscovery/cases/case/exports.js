import { Layout as DashboardLayout } from "../../../../../layouts/index.jsx";
import { useRouter } from "next/router";
import { ApiGetCall } from "../../../../../api/ApiCall";
import CippFormSkeleton from "../../../../../components/CippFormPages/CippFormSkeleton";
import { HeaderedTabbedLayout } from "../../../../../layouts/HeaderedTabbedLayout";
import tabOptions from "./tabOptions.json";
import { Box, Stack } from "@mui/system";
import { Alert, Chip, Typography } from "@mui/material";
import { CippDataTable } from "../../../../../components/CippTable/CippDataTable";
import { HourglassTop } from "@mui/icons-material";
import { useMemo } from "react";

const Page = () => {
  const router = useRouter();
  const { caseId } = router.query;

  const operationsRequest = ApiGetCall({
    url: `/api/ListEdiscoveryCaseOperations`,
    queryKey: `ListEdiscoveryCaseOperations-${caseId}`,
    data: { caseId },
    waiting: !!caseId,
  });

  const hasRunning = useMemo(() => {
    if (!operationsRequest.data?.Results) return false;
    return operationsRequest.data.Results.some(
      (op) => op.status === "running" || op.status === "notStarted"
    );
  }, [operationsRequest.data]);

  if (hasRunning) {
    operationsRequest.refetchInterval = 5000;
  }

  const columns = [
    "displayName",
    "action",
    "status",
    "percentProgress",
    "createdBy",
    "createdDate",
    "completedDate",
  ];

  const title = "Exports";

  const offCanvas = {
    children: (row) => (
      <Stack spacing={2}>
        <Typography variant="subtitle2">Export Details</Typography>
        <Stack spacing={1}>
          <Stack direction="row" justifyContent="space-between">
            <Typography variant="body2" color="text.secondary">
              Type
            </Typography>
            <Typography variant="body2">{row.displayName}</Typography>
          </Stack>
          <Stack direction="row" justifyContent="space-between">
            <Typography variant="body2" color="text.secondary">
              Status
            </Typography>
            <Chip
              label={row.status}
              size="small"
              color={
                row.status === "succeeded"
                  ? "success"
                  : row.status === "failed"
                    ? "error"
                    : "warning"
              }
            />
          </Stack>
          {row.percentProgress != null && (
            <Stack direction="row" justifyContent="space-between">
              <Typography variant="body2" color="text.secondary">
                Progress
              </Typography>
              <Typography variant="body2">{row.percentProgress}%</Typography>
            </Stack>
          )}
          {row.exportGuidance && (
            <Stack direction="row" justifyContent="space-between">
              <Typography variant="body2" color="text.secondary">
                Export
              </Typography>
              <Typography variant="body2">{row.exportGuidance}</Typography>
            </Stack>
          )}
          {row.resultInfo && (
            <Stack direction="row" justifyContent="space-between">
              <Typography variant="body2" color="text.secondary">
                Result
              </Typography>
              <Typography variant="body2">{JSON.stringify(row.resultInfo)}</Typography>
            </Stack>
          )}
        </Stack>
      </Stack>
    ),
  };

  return (
    <HeaderedTabbedLayout
      tabOptions={tabOptions}
      title={title}
      isFetching={operationsRequest.isLoading}
      backUrl="/security/ediscovery/cases"
    >
      <Box sx={{ flexGrow: 1, pt: 2 }}>
        <Stack spacing={2}>
          {hasRunning && (
            <Alert severity="info" icon={<HourglassTop />}>
              One or more exports are in progress. Status will update automatically.
            </Alert>
          )}

          <Alert severity="info" variant="outlined">
            Export creation and content downloads are disabled in Manage365 v1. Use search estimates
            for counts-only review data.
          </Alert>

          {operationsRequest.isLoading && <CippFormSkeleton layout={[1, 1]} />}
          {operationsRequest.isSuccess && (
            <CippDataTable
              title="Export Operations"
              data={operationsRequest.data?.Results ?? []}
              simpleColumns={columns}
              offCanvas={offCanvas}
            />
          )}
          {operationsRequest.isError && (
            <Alert severity="error">
              Failed to load export operations. Check that eDiscovery permissions are configured.
            </Alert>
          )}
        </Stack>
      </Box>
    </HeaderedTabbedLayout>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
