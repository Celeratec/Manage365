import { Layout as DashboardLayout } from "../../../../../layouts/index.js";
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
  Delete,
  PlayArrow,
  Download,
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
  const formHook = useForm({ defaultValues: {} });

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

  const exportRequest = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [`ListEdiscoveryCaseOperations-${caseId}`],
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
      confirmText: "Run a search estimate? This may take several minutes.",
      relatedQueryKeys: [`ListEdiscoveryCaseSearches-${caseId}`],
      category: "manage",
    },
    {
      label: "Export Results",
      type: "POST",
      icon: <Download />,
      url: "/api/ExecEdiscoveryCaseExport",
      data: {
        caseId: `!${caseId}`,
        searchId: "id",
      },
      confirmText: "Start exporting search results? Check the Exports tab for progress.",
      relatedQueryKeys: [`ListEdiscoveryCaseOperations-${caseId}`],
      category: "manage",
    },
    {
      label: "Delete Search",
      type: "POST",
      icon: <Delete />,
      url: "/api/ExecEdiscoveryCaseSearch",
      data: {
        caseId: `!${caseId}`,
        searchId: "id",
        action: "!delete",
      },
      confirmText: "Are you sure you want to delete this search?",
      relatedQueryKeys: [`ListEdiscoveryCaseSearches-${caseId}`],
      category: "danger",
    },
  ];

  const columns = [
    "displayName",
    "status",
    "contentQuery",
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
                formHook.reset({});
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
