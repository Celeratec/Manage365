import { Layout as DashboardLayout } from "../../../../../layouts/index.jsx";
import { useRouter } from "next/router";
import { ApiGetCall } from "../../../../../api/ApiCall";
import CippFormSkeleton from "../../../../../components/CippFormPages/CippFormSkeleton";
import { HeaderedTabbedLayout } from "../../../../../layouts/HeaderedTabbedLayout";
import tabOptions from "./tabOptions.json";
import { Box, Stack } from "@mui/system";
import { Alert, AlertTitle, Link } from "@mui/material";
import { CippDataTable } from "../../../../../components/CippTable/CippDataTable";
import { PlayArrow } from "@mui/icons-material";
import { useMemo } from "react";

const Page = () => {
  const router = useRouter();
  const { caseId } = router.query;

  const guardedWriteFields = [
    {
      name: "ticketNumber",
      label: "Ticket Number",
      type: "textField",
      validators: { required: "Ticket number is required" },
    },
    {
      name: "reason",
      label: "Reason",
      type: "textField",
      validators: { required: "Reason is required" },
    },
    {
      name: "dryRun",
      label: "Preview only (dry run)",
      type: "switch",
      defaultValue: true,
    },
  ];

  const searchesRequest = ApiGetCall({
    url: `/api/ListEdiscoveryCaseSearches`,
    queryKey: `ListEdiscoveryCaseSearches-${caseId}`,
    data: { caseId },
    waiting: !!caseId,
    refetchInterval: (query) =>
      query?.state?.data?.Results?.some((search) => search.status === "running") ? 5000 : false,
  });

  const hasRunning = useMemo(() => {
    if (!searchesRequest.data?.Results) return false;
    return searchesRequest.data.Results.some((s) => s.status === "running");
  }, [searchesRequest.data]);

  const actions = [
    {
      label: "Run Estimate",
      type: "POST",
      icon: <PlayArrow />,
      url: "/api/ExecEdiscoveryCaseSearch",
      data: {
        caseId: `!${caseId}`,
        searchId: "id",
        action: "!estimateStatistics",
      },
      customDataformatter: (row, _action, formData) => ({
        caseId,
        searchId: row.id,
        action: "estimateStatistics",
        ticketNumber: formData.ticketNumber,
        reason: formData.reason,
        dryRun: formData.dryRun,
      }),
      fields: guardedWriteFields,
      confirmText: "Run a search estimate? This may take several minutes.",
      relatedQueryKeys: [`ListEdiscoveryCaseSearches-${caseId}`],
      category: "manage",
    },
  ];

  const columns = [
    "displayName",
    "status",
    "contentQueryPresent",
    "estimatedItemCount",
    "estimatedSize",
    "createdBy",
    "createdDate",
  ];

  const title = "Searches";

  return (
    <HeaderedTabbedLayout
      tabOptions={tabOptions}
      title={title}
      isFetching={searchesRequest.isLoading}
      backUrl="/security/ediscovery/cases"
    >
      <Box sx={{ flexGrow: 1, pt: 2 }}>
        <Stack spacing={2}>
          {hasRunning && (
            <Alert severity="info">
              One or more searches are running. Results will update automatically.
            </Alert>
          )}

          <Alert severity="info">
            <AlertTitle>New mailbox stats searches</AlertTitle>
            Manage365 v1 does not accept free-form KQL or data-source scopes from this page. Use the{" "}
            <strong>ExecEdiscoverySearch</strong> API for validated, mailbox-only stats estimates
            (ticket number, custodian, and term list). See{" "}
            <Link
              href="https://github.com/Celeratec/Manage365/blob/main/docs/api-documentation/ediscovery-search.md"
              target="_blank"
              rel="noopener noreferrer"
            >
              eDiscovery Search API docs
            </Link>
            .
          </Alert>

          <Alert severity="info" variant="outlined">
            This view is read-only for listings, plus estimate-only actions on existing searches.
            Search delete, purge, exports, and content downloads are refused.
          </Alert>

          {searchesRequest.isLoading && <CippFormSkeleton layout={[1, 1]} />}
          {searchesRequest.isSuccess && (
            <CippDataTable
              title="Searches"
              data={searchesRequest.data?.Results ?? []}
              simpleColumns={columns}
              actions={actions}
            />
          )}
          {searchesRequest.isError && (
            <Alert severity="error">
              Failed to load searches. Check that eDiscovery permissions are configured.
            </Alert>
          )}
        </Stack>
      </Box>
    </HeaderedTabbedLayout>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;