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
  Chip,
} from "@mui/material";
import { CippDataTable } from "../../../../../components/CippTable/CippDataTable";
import { CippApiResults } from "../../../../../components/CippComponents/CippApiResults";
import CippFormComponent from "../../../../../components/CippComponents/CippFormComponent";
import { Add, Delete, Gavel } from "@mui/icons-material";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { useSettings } from "../../../../../hooks/use-settings";

const Page = () => {
  const router = useRouter();
  const { caseId } = router.query;
  const userSettings = useSettings();
  const [createOpen, setCreateOpen] = useState(false);
  const formHook = useForm({ defaultValues: {} });

  const holdsRequest = ApiGetCall({
    url: `/api/ListEdiscoveryCaseHolds`,
    queryKey: `ListEdiscoveryCaseHolds-${caseId}`,
    data: { caseId },
    waiting: !!caseId,
  });

  const createHoldRequest = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [`ListEdiscoveryCaseHolds-${caseId}`],
  });

  const handleCreateHold = (data) => {
    const userSources = data.userEmails
      ? data.userEmails
          .split(",")
          .map((e) => e.trim())
          .filter(Boolean)
          .map((email) => ({ email, includedSources: "mailbox,site" }))
      : [];

    const siteSources = data.siteUrls
      ? data.siteUrls
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean)
          .map((siteWebUrl) => ({ siteWebUrl }))
      : [];

    createHoldRequest.mutate({
      url: "/api/ExecEdiscoveryCaseHold",
      data: {
        tenantFilter: userSettings.currentTenant,
        caseId,
        action: "create",
        displayName: data.displayName,
        description: data.description,
        contentQuery: data.contentQuery,
        userSources,
        siteSources,
      },
    });
  };

  const actions = [
    {
      label: "Remove Hold",
      type: "POST",
      icon: <Delete />,
      url: "/api/ExecEdiscoveryCaseHold",
      data: {
        caseId: `!${caseId}`,
        holdId: "id",
        action: "!remove",
      },
      confirmText:
        "Are you sure you want to remove this legal hold? Content will no longer be preserved.",
      relatedQueryKeys: [`ListEdiscoveryCaseHolds-${caseId}`],
      category: "danger",
    },
  ];

  const columns = [
    "displayName",
    "status",
    "contentSourcesCount",
    "contentQuery",
    "createdBy",
    "createdDate",
  ];

  const title = "Legal Holds";

  return (
    <HeaderedTabbedLayout
      tabOptions={tabOptions}
      title={title}
      isFetching={holdsRequest.isLoading}
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
                createHoldRequest.reset();
                setCreateOpen(true);
              }}
            >
              Create Hold
            </Button>
          </Box>

          {holdsRequest.isLoading && <CippFormSkeleton layout={[1, 1]} />}
          {holdsRequest.isSuccess && (
            <CippDataTable
              title="Legal Holds"
              data={holdsRequest.data?.Results ?? []}
              simpleColumns={columns}
              actions={actions}
            />
          )}
          {holdsRequest.isError && (
            <Alert severity="error">
              Failed to load legal holds. Check that eDiscovery permissions are configured.
            </Alert>
          )}
        </Stack>
      </Box>

      <Dialog open={createOpen} onClose={() => setCreateOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Gavel />
            <span>Create Legal Hold</span>
          </Stack>
        </DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <CippFormComponent
              type="textField"
              name="displayName"
              label="Hold Name"
              formControl={formHook}
              validators={{ required: "Hold name is required" }}
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
              name="userEmails"
              label="User Mailboxes (comma-separated email addresses)"
              formControl={formHook}
              multiline
              rows={2}
            />
            <CippFormComponent
              type="textField"
              name="siteUrls"
              label="SharePoint Site URLs (comma-separated)"
              formControl={formHook}
              multiline
              rows={2}
            />
            <CippFormComponent
              type="textField"
              name="contentQuery"
              label="KQL Content Query (optional)"
              formControl={formHook}
              placeholder='e.g. subject:"Project Alpha" AND date:2024-01-01..2025-01-01'
            />
            <CippApiResults apiObject={createHoldRequest} />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCreateOpen(false)}>Cancel</Button>
          <Button
            variant="contained"
            onClick={formHook.handleSubmit(handleCreateHold)}
            disabled={createHoldRequest.isPending}
          >
            Create Hold
          </Button>
        </DialogActions>
      </Dialog>
    </HeaderedTabbedLayout>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
