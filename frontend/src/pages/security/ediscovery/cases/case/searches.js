import { Layout as DashboardLayout } from "../../../../../layouts/index.jsx";
import { useRouter } from "next/router";
import { ApiGetCall, ApiPostCall } from "../../../../../api/ApiCall";
import CippFormSkeleton from "../../../../../components/CippFormPages/CippFormSkeleton";
import { HeaderedTabbedLayout } from "../../../../../layouts/HeaderedTabbedLayout";
import tabOptions from "./tabOptions.json";
import { Box, Stack } from "@mui/system";
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Typography,
} from "@mui/material";
import { CippDataTable } from "../../../../../components/CippTable/CippDataTable";
import { CippApiResults } from "../../../../../components/CippComponents/CippApiResults";
import CippFormComponent from "../../../../../components/CippComponents/CippFormComponent";
import {
  Add,
  PlayArrow,
  Search as SearchIcon,
} from "@mui/icons-material";
import { useState, useMemo } from "react";
import { useForm } from "react-hook-form";
import { useSettings } from "../../../../../hooks/use-settings";

const Page = () => {
  const router = useRouter();
  const { caseId } = router.query;
  const userSettings = useSettings();
  const [createOpen, setCreateOpen] = useState(false);
  const formHook = useForm({ defaultValues: { dryRun: true } });

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
  });

  const hasRunning = useMemo(() => {
    if (!searchesRequest.data?.Results) return false;
    return searchesRequest.data.Results.some((s) => s.status === "running");
  }, [searchesRequest.data]);

  if (hasRunning) {
    searchesRequest.refetchInterval = 5000;
  }

  const createSearchRequest = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [`ListEdiscoveryCaseSearches-${caseId}`],
  });

  const estimateRequest = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [`ListEdiscoveryCaseSearches-${caseId}`],
  });

  const handleCreateSearch = (data) => {
    createSearchRequest.mutate({
      url: "/api/ExecEdiscoveryCaseSearch",
      data: {
        tenantFilter: userSettings.currentTenant,
        caseId,
        action: "create",
        displayName: data.displayName,
        description: data.description,
        contentQuery: data.contentQuery,
        dataSourceScopes: data.dataSourceScopes || "allTenantSources",
        ticketNumber: data.ticketNumber,
        reason: data.reason,
        dryRun: data.dryRun !== false,
      },
    });
  };

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
          <Box sx={{ display: "flex", justifyContent: "flex-end" }}>
            <Button
              variant="contained"
              startIcon={<Add />}
              onClick={() => {
                formHook.reset({ dryRun: true });
                createSearchRequest.reset();
                setCreateOpen(true);
              }}
            >
              Create Search
            </Button>
          </Box>

          {hasRunning && (
            <Alert severity="info">
              One or more searches are running. Results will update automatically.
            </Alert>
          )}

          <Alert severity="info" variant="outlined">
            Manage365 v1 supports counts-only estimates. Search delete, purge, exports, and content
            downloads are refused.
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

      <Dialog open={createOpen} onClose={() => setCreateOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          <Stack direction="row" alignItems="center" spacing={1}>
            <SearchIcon />
            <span>Create eDiscovery Search</span>
          </Stack>
        </DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <CippFormComponent
              type="textField"
              name="displayName"
              label="Search Name"
              formControl={formHook}
              validators={{ required: "Search name is required" }}
            />
            <CippFormComponent
              type="textField"
              name="description"
              label="Description"
              formControl={formHook}
              multiline
              rows={2}
            />
            <CippFormComponent
              type="textField"
              name="contentQuery"
              label="KQL Search Query"
              formControl={formHook}
              validators={{ required: "Search query is required" }}
              multiline
              rows={3}
              placeholder='e.g. subject:"litigation" AND from:user@domain.com AND date:2024-01-01..2025-06-30'
            />
            <Typography variant="caption" color="text.secondary">
              Use KQL syntax for search queries. Common operators: AND, OR, NOT, subject:, from:,
              to:, date:, filetype:
            </Typography>
            {guardedWriteFields.map((field) => (
              <CippFormComponent
                key={field.name}
                {...field}
                formControl={formHook}
              />
            ))}
            <CippApiResults apiObject={createSearchRequest} />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCreateOpen(false)}>Cancel</Button>
          <Button
            variant="contained"
            onClick={formHook.handleSubmit(handleCreateSearch)}
            disabled={createSearchRequest.isPending}
          >
            Create Search
          </Button>
        </DialogActions>
      </Dialog>
    </HeaderedTabbedLayout>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
