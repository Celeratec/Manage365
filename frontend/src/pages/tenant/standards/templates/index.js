import { Alert, Button, Chip, Tooltip, Typography } from "@mui/material";
import { Box, Stack } from "@mui/system";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { TabbedLayout } from "../../../../layouts/TabbedLayout";
import Link from "next/link";
import { CopyAll, Delete, PlayArrow, AddBox, Edit, GitHub, ContentCopy } from "@mui/icons-material";
import { ApiGetCall, ApiPostCall } from "../../../../api/ApiCall";
import { Grid } from "@mui/system";
import { CippApiResults } from "../../../../components/CippComponents/CippApiResults";
import { EyeIcon, DocumentTextIcon, ClockIcon, UserIcon, PlayCircleIcon, ListBulletIcon } from "@heroicons/react/24/outline";
import tabOptions from "../tabOptions.json";
import { useSettings } from "../../../../hooks/use-settings.js";
import { CippPolicyImportDrawer } from "../../../../components/CippComponents/CippPolicyImportDrawer.jsx";
import { PermissionButton } from "../../../../utils/permissions.js";
import { CippRemovableTenantChips } from "../../../../components/CippComponents/CippRemovableTenantChips";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage";

const Page = () => {
  const oldStandards = ApiGetCall({ url: "/api/ListStandards", queryKey: "ListStandards-legacy" });
  const integrations = ApiGetCall({
    url: "/api/ListExtensionsConfig",
    queryKey: "Integrations",
    refetchOnMount: false,
    refetchOnReconnect: false,
  });

  const currentTenant = useSettings().currentTenant;
  const pageTitle = "Templates";
  const cardButtonPermissions = ["Tenant.Standards.ReadWrite"];
  const actions = [
    {
      label: "View Tenant Report",
      link: "/tenant/manage/applied-standards/?templateId=[GUID]",
      icon: <EyeIcon />,
      color: "info",
      target: "_self",
      category: "view",
    },
    {
      label: "Edit Template",
      link: "/tenant/standards/templates/template?id=[GUID]&type=[type]",
      icon: <Edit />,
      color: "success",
      target: "_self",
      category: "edit",
    },
    {
      label: "Clone & Edit Template",
      link: "/tenant/standards/templates/template?id=[GUID]&clone=true&type=[type]",
      icon: <CopyAll />,
      color: "success",
      target: "_self",
      category: "edit",
    },
    {
      label: "Create Drift Clone",
      type: "POST",
      url: "/api/ExecDriftClone",
      icon: <ContentCopy />,
      color: "warning",
      data: {
        id: "GUID",
      },
      confirmText:
        "Are you sure you want to create a drift clone of [templateName]? This will create a new drift template based on this template.",
      multiPost: false,
      category: "manage",
    },
    {
      label: `Run Template Now (${currentTenant || "Currently Selected Tenant"})`,
      type: "GET",
      url: "/api/ExecStandardsRun",
      icon: <PlayArrow />,
      data: {
        TemplateId: "GUID",
      },
      confirmText: "Are you sure you want to force a run of this template?",
      multiPost: false,
      category: "manage",
    },
    {
      label: "Run Template Now (All Tenants in Template)",
      type: "GET",
      url: "/api/ExecStandardsRun",
      icon: <PlayArrow />,
      data: {
        TemplateId: "GUID",
        tenantFilter: "allTenants",
      },
      confirmText: "Are you sure you want to force a run of this template?",
      multiPost: false,
      category: "manage",
    },
    {
      label: "Save to GitHub",
      type: "POST",
      url: "/api/ExecCommunityRepo",
      icon: <GitHub />,
      data: {
        Action: "UploadTemplate",
        GUID: "GUID",
      },
      fields: [
        {
          label: "Repository",
          name: "FullName",
          type: "select",
          api: {
            url: "/api/ListCommunityRepos",
            data: {
              WriteAccess: true,
            },
            queryKey: "CommunityRepos-Write",
            dataKey: "Results",
            valueField: "FullName",
            labelField: "FullName",
          },
          multiple: false,
          creatable: false,
          required: true,
          validators: {
            required: { value: true, message: "This field is required" },
          },
        },
        {
          label: "Commit Message",
          placeholder: "Enter a commit message for adding this file to GitHub",
          name: "Message",
          type: "textField",
          multiline: true,
          required: true,
          rows: 4,
        },
      ],
      confirmText: "Are you sure you want to save this template to the selected repository?",
      condition: () => integrations.isSuccess && integrations?.data?.GitHub?.Enabled,
      category: "manage",
    },
    {
      label: "Delete Template",
      type: "POST",
      url: "/api/RemoveStandardTemplate",
      icon: <Delete />,
      data: {
        ID: "GUID",
      },
      confirmText: "Are you sure you want to delete [templateName]?",
      multiPost: false,
      category: "danger",
    },
  ];
  const conversionApi = ApiPostCall({ relatedQueryKeys: "listStandardTemplates" });
  const handleConversion = () => {
    conversionApi.mutate({
      url: "/api/execStandardConvert",
      data: {},
    });
  };
  const queryKey = "listStandardTemplates";

  // Helper to format standards into a readable summary
  const formatStandardsSummary = (standards) => {
    if (!standards) return { count: 0, list: [] };
    
    let standardsList = [];
    
    if (typeof standards === "object" && !Array.isArray(standards)) {
      // Standards is an object with keys
      standardsList = Object.keys(standards).filter(key => {
        const value = standards[key];
        // Include if it's truthy or has action/remediate enabled
        return value && (value === true || value.action || value.remediate);
      });
    } else if (Array.isArray(standards)) {
      standardsList = standards;
    }
    
    return {
      count: standardsList.length,
      list: standardsList.map(s => {
        // Clean up standard names for display
        return s
          .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
          .replace(/([a-z])([A-Z])/g, "$1 $2")
          .replace(/[_]/g, " ");
      }),
    };
  };

  // Custom columns with better formatting and truncation
  const columns = [
    {
      header: "Name",
      id: "templateName",
      accessorKey: "templateName",
      size: 200,
      Cell: ({ row }) => {
        const name = row?.original?.templateName || "Unknown";
        return (
          <Tooltip title={name} arrow>
            <Stack direction="row" spacing={1} alignItems="center">
              <DocumentTextIcon style={{ width: 16, height: 16, opacity: 0.6, flexShrink: 0 }} />
              <Typography
                variant="body2"
                fontWeight={500}
                sx={{
                  maxWidth: 170,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {name}
              </Typography>
            </Stack>
          </Tooltip>
        );
      },
    },
    {
      header: "Type",
      id: "type",
      accessorKey: "type",
      size: 100,
      Cell: ({ row }) => {
        const type = row?.original?.type;
        return (
          <Chip
            label={type || "Standard"}
            size="small"
            color={type === "drift" ? "warning" : "primary"}
            variant="outlined"
          />
        );
      },
    },
    {
      header: "Included",
      id: "tenantFilter",
      accessorKey: "tenantFilter",
      enableSorting: false,
      size: 180,
      Cell: ({ row }) => {
        if (!row?.original) return null;
        return (
          <CippRemovableTenantChips
            tenants={row.original.tenantFilter}
            templateId={row.original.GUID}
            templateName={row.original.templateName}
            templateData={row.original}
            fieldName="tenantFilter"
            queryKey={queryKey}
            maxDisplay={2}
            emptyMessage="No tenants"
          />
        );
      },
    },
    {
      header: "Excluded",
      id: "excludedTenants",
      accessorKey: "excludedTenants",
      enableSorting: false,
      size: 180,
      Cell: ({ row }) => {
        if (!row?.original) return null;
        return (
          <CippRemovableTenantChips
            tenants={row.original.excludedTenants}
            templateId={row.original.GUID}
            templateName={row.original.templateName}
            templateData={row.original}
            fieldName="excludedTenants"
            queryKey={queryKey}
            maxDisplay={2}
            emptyMessage="None"
          />
        );
      },
    },
    {
      header: "Standards",
      id: "standards",
      accessorKey: "standards",
      size: 120,
      Cell: ({ row }) => {
        const { count, list } = formatStandardsSummary(row?.original?.standards);
        return (
          <Tooltip
            title={
              list.length > 0 ? (
                <Box sx={{ maxHeight: 300, overflow: "auto" }}>
                  {list.slice(0, 20).map((s, i) => (
                    <div key={i}>• {s}</div>
                  ))}
                  {list.length > 20 && <div>... and {list.length - 20} more</div>}
                </Box>
              ) : (
                "No standards configured"
              )
            }
            arrow
          >
            <Chip
              icon={<ListBulletIcon style={{ width: 14, height: 14 }} />}
              label={`${count} standard${count !== 1 ? "s" : ""}`}
              size="small"
              color={count > 0 ? "success" : "default"}
              variant="outlined"
            />
          </Tooltip>
        );
      },
    },
    {
      header: "Updated",
      id: "updatedAt",
      accessorKey: "updatedAt",
      size: 140,
      Cell: ({ row }) => (
        <Stack direction="row" spacing={0.5} alignItems="center">
          <ClockIcon style={{ width: 14, height: 14, opacity: 0.6 }} />
          <Typography variant="body2" fontSize="0.8rem">
            {getCippFormatting(row?.original?.updatedAt, "updatedAt")}
          </Typography>
        </Stack>
      ),
    },
    {
      header: "By",
      id: "updatedBy",
      accessorKey: "updatedBy",
      size: 150,
      Cell: ({ row }) => {
        const updatedBy = row?.original?.updatedBy || "Unknown";
        return (
          <Tooltip title={updatedBy} arrow>
            <Stack direction="row" spacing={0.5} alignItems="center">
              <UserIcon style={{ width: 14, height: 14, opacity: 0.6 }} />
              <Typography
                variant="body2"
                fontSize="0.8rem"
                sx={{
                  maxWidth: 120,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {updatedBy}
              </Typography>
            </Stack>
          </Tooltip>
        );
      },
    },
    {
      header: "Manual",
      id: "runManually",
      accessorKey: "runManually",
      size: 90,
      Cell: ({ row }) => {
        const runManually = row?.original?.runManually;
        return (
          <Tooltip title={runManually ? "Run manually only" : "Scheduled"} arrow>
            <Chip
              icon={<PlayCircleIcon style={{ width: 14, height: 14 }} />}
              label={runManually ? "Yes" : "No"}
              size="small"
              color={runManually ? "warning" : "success"}
              variant="outlined"
            />
          </Tooltip>
        );
      },
    },
  ];

  const tableFilter = oldStandards.isSuccess && oldStandards.data.length !== 0 && (
    <Grid container spacing={2}>
      <Grid size={12}>
        <Alert severity="warning" sx={{ display: "flex", alignItems: "center" }}>
          <Stack
            direction={{ xs: "column", md: "row" }}
            spacing={2}
            alignItems="center"
            sx={{ width: "100%" }}
          >
            <span>
              You have legacy standards available. Press the button to convert these standards to
              the new format. This will create a new template for each standard you had, but will
              disable the schedule. After conversion, please check the new templates to ensure they
              are correct and re-enable the schedule.
            </span>
            <Button onClick={() => handleConversion()} variant="contained" sx={{ flexShrink: 0 }}>
              Convert Legacy Standards
            </Button>
          </Stack>
        </Alert>
      </Grid>
      {conversionApi.isSuccess && (
        <Grid size={12}>
          <CippApiResults apiObject={conversionApi} />
        </Grid>
      )}
    </Grid>
  );

  const cardButton = (
    <Stack direction="row" spacing={1}>
      <Button component={Link} href="/tenant/standards/templates/template" startIcon={<AddBox />}>
        Add Template
      </Button>
      <Button
        component={Link}
        href="/tenant/standards/templates/template?type=drift"
        startIcon={<AddBox />}
      >
        Create Drift Template
      </Button>
      <CippPolicyImportDrawer
        buttonText="Browse Catalog"
        requiredPermissions={cardButtonPermissions}
        PermissionButton={PermissionButton}
        mode="Standards"
      />
    </Stack>
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/listStandardTemplates"
      apiDataKey="Results"
      cardButton={cardButton}
      columns={columns}
      actions={actions}
      queryKey={queryKey}
      tableFilter={tableFilter}
      tenantInTitle={false}
      spacing={1}
    />
  );
};

Page.getLayout = (page) => (
  <DashboardLayout>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
);

export default Page;
