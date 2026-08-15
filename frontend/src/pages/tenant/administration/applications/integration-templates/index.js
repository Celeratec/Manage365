import { Layout as DashboardLayout } from "../../../../../layouts/index.js";
import { TabbedLayout } from "../../../../../layouts/TabbedLayout";
import tabOptions from "../tabOptions";
import { ApiGetCall } from "../../../../../api/ApiCall";
import { 
  Box, 
  Button, 
  Card, 
  CardContent, 
  CardActions, 
  Typography, 
  Chip, 
  Stack,
  Skeleton,
  Alert,
  Tooltip,
  IconButton,
} from "@mui/material";
import { Grid } from "@mui/system";
import { Add, RocketLaunch, Edit, ContentCopy, Delete, Lock, OpenInNew } from "@mui/icons-material";
import Link from "next/link";
import CippPageCard from "../../../../../components/CippCards/CippPageCard";
import { useSettings } from "../../../../../hooks/use-settings.js";
import { getCippFormatting } from "../../../../../utils/get-cipp-formatting.js";
import { CippApiDialog } from "../../../../../components/CippComponents/CippApiDialog.jsx";
import { useState } from "react";

const IntegrationTemplateCard = ({ template, onDelete, onDuplicate }) => {
  const permissionCount = template.permissions?.reduce(
    (acc, resource) => acc + (resource.permissions?.length || 0),
    0
  ) || 0;

  return (
    <Card 
      sx={{ 
        height: "100%", 
        display: "flex", 
        flexDirection: "column",
        position: "relative",
      }}
    >
      {template.isBuiltIn && (
        <Tooltip title="Built-in template (cannot be modified)">
          <Lock 
            sx={{ 
              position: "absolute", 
              top: 12, 
              right: 12, 
              fontSize: 18,
              color: "text.secondary",
            }} 
          />
        </Tooltip>
      )}
      <CardContent sx={{ flexGrow: 1 }}>
        <Typography variant="h6" gutterBottom>
          {template.name}
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2, minHeight: 40 }}>
          {template.description || "No description provided"}
        </Typography>
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
          <Chip 
            label={`${permissionCount} permission${permissionCount !== 1 ? "s" : ""}`} 
            size="small" 
            color="primary" 
            variant="outlined"
          />
          {template.generateSecret && (
            <Chip label="Auto-generates secret" size="small" variant="outlined" />
          )}
          {template.isBuiltIn && (
            <Chip label="Built-in" size="small" color="info" variant="filled" />
          )}
        </Stack>
      </CardContent>
      <CardActions sx={{ justifyContent: "space-between", px: 2, pb: 2 }}>
        <Stack direction="row" spacing={1}>
          <Button
            component={Link}
            href={`/tenant/administration/applications/integration-templates/deploy?template=${template.id}`}
            variant="contained"
            size="small"
            startIcon={<RocketLaunch />}
          >
            Deploy
          </Button>
          {template.documentationUrl && (
            <Tooltip title="View documentation">
              <IconButton
                component="a"
                href={template.documentationUrl}
                target="_blank"
                rel="noopener noreferrer"
                size="small"
              >
                <OpenInNew fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
        </Stack>
        <Stack direction="row" spacing={0.5}>
          {!template.isBuiltIn && (
            <>
              <Tooltip title="Edit">
                <IconButton
                  component={Link}
                  href={`/tenant/administration/applications/integration-templates/edit?id=${template.id}`}
                  size="small"
                >
                  <Edit fontSize="small" />
                </IconButton>
              </Tooltip>
              <Tooltip title="Delete">
                <IconButton
                  size="small"
                  color="error"
                  onClick={() => onDelete(template)}
                >
                  <Delete fontSize="small" />
                </IconButton>
              </Tooltip>
            </>
          )}
          <Tooltip title="Duplicate">
            <IconButton
              size="small"
              onClick={() => onDuplicate(template)}
            >
              <ContentCopy fontSize="small" />
            </IconButton>
          </Tooltip>
        </Stack>
      </CardActions>
    </Card>
  );
};

const Page = () => {
  const settings = useSettings();
  const [deleteDialog, setDeleteDialog] = useState({ open: false, template: null });
  const [duplicateDialog, setDuplicateDialog] = useState({ open: false, template: null });

  const templatesQuery = ApiGetCall({
    url: "/api/ListIntegrationTemplates",
    queryKey: "ListIntegrationTemplates",
  });

  const handleDeleteClick = (template) => {
    setDeleteDialog({ open: true, template });
  };

  const handleDuplicateClick = (template) => {
    setDuplicateDialog({ open: true, template });
  };

  const cardButton = (
    <Button
      component={Link}
      href="/tenant/administration/applications/integration-templates/add"
      startIcon={<Add />}
    >
      Add Template
    </Button>
  );

  return (
    <>
      <CippPageCard
        title="Integration Templates"
        cardButton={cardButton}
      >
        <Box sx={{ p: 3 }}>
          {templatesQuery.isLoading ? (
            <Grid container spacing={3}>
              {[1, 2, 3].map((i) => (
                <Grid key={i} size={{ xs: 12, sm: 6, md: 4 }}>
                  <Skeleton variant="rectangular" height={200} sx={{ borderRadius: 1 }} />
                </Grid>
              ))}
            </Grid>
          ) : templatesQuery.isError ? (
            <Alert severity="error">
              Failed to load templates: {templatesQuery.error?.message || "Unknown error"}
            </Alert>
          ) : templatesQuery.data?.length === 0 ? (
            <Alert severity="info">
              No integration templates found. Click "Add Template" to create one.
            </Alert>
          ) : (
            <Grid container spacing={3}>
              {templatesQuery.data?.map((template) => (
                <Grid key={template.id} size={{ xs: 12, sm: 6, md: 4 }}>
                  <IntegrationTemplateCard
                    template={template}
                    onDelete={handleDeleteClick}
                    onDuplicate={handleDuplicateClick}
                  />
                </Grid>
              ))}
            </Grid>
          )}
        </Box>
      </CippPageCard>

      <CippApiDialog
        createDialog={deleteDialog.open}
        title="Delete Template"
        fields={[]}
        api={{
          url: "/api/ExecIntegrationTemplate",
          type: "POST",
          data: {
            action: "delete",
            id: deleteDialog.template?.id,
          },
          confirmText: `Are you sure you want to delete "${deleteDialog.template?.name}"?`,
        }}
        row={deleteDialog.template}
        relatedQueryKeys={["ListIntegrationTemplates"]}
        onClose={() => setDeleteDialog({ open: false, template: null })}
      />

      <CippApiDialog
        createDialog={duplicateDialog.open}
        title="Duplicate Template"
        fields={[
          {
            name: "name",
            label: "New Template Name",
            type: "textField",
            required: true,
            defaultValue: duplicateDialog.template ? `${duplicateDialog.template.name} (Copy)` : "",
          },
        ]}
        api={{
          url: "/api/ExecIntegrationTemplate",
          type: "POST",
          data: {
            action: "duplicate",
            id: duplicateDialog.template?.id,
          },
        }}
        row={duplicateDialog.template}
        relatedQueryKeys={["ListIntegrationTemplates"]}
        onClose={() => setDuplicateDialog({ open: false, template: null })}
      />
    </>
  );
};

Page.getLayout = (page) => (
  <DashboardLayout>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
);

export default Page;
