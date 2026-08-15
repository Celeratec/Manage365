import { useRouter } from "next/router";
import { Layout as DashboardLayout } from "../../../../../layouts/index.js";
import { TabbedLayout } from "../../../../../layouts/TabbedLayout";
import tabOptions from "../tabOptions";
import CippPageCard from "../../../../../components/CippCards/CippPageCard";
import { ApiPostCall } from "../../../../../api/ApiCall";
import { useForm, useFieldArray, Controller } from "react-hook-form";
import {
  Box,
  Button,
  Card,
  CardContent,
  TextField,
  Typography,
  Stack,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  IconButton,
  Alert,
  FormHelperText,
  Autocomplete,
  Switch,
  FormControlLabel,
} from "@mui/material";
import { Add, Delete, Save } from "@mui/icons-material";
import { useState } from "react";

const COMMON_GRAPH_PERMISSIONS = [
  { id: "df021288-bdef-4463-88db-98f22de89214", name: "User.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "5b567255-7703-4780-807c-7be8301ae99b", name: "Group.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "98830695-27a2-44f7-bda0-e1eae16e3bb0", name: "GroupMember.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", name: "Directory.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "19dbc75e-c2e2-444c-a770-ec69d8559fc7", name: "Directory.ReadWrite.All", type: "Role", resource: "Microsoft Graph" },
  { id: "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30", name: "Application.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "06b708a9-e830-4db3-a914-8e69da51d44f", name: "AppRoleAssignment.ReadWrite.All", type: "Role", resource: "Microsoft Graph" },
  { id: "246dd0d5-5bd0-4def-940b-0421030a5b68", name: "Policy.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "01c0a623-fc9b-48e9-b794-0756f8e8f067", name: "Policy.ReadWrite.ConditionalAccess", type: "Role", resource: "Microsoft Graph" },
  { id: "5df07f86-2634-4e2c-9b7b-d9e76d8c1d36", name: "Mail.Read", type: "Role", resource: "Microsoft Graph" },
  { id: "e2a3a72e-5f79-4c64-b1b1-878b674786c9", name: "Mail.ReadWrite", type: "Role", resource: "Microsoft Graph" },
  { id: "089fe4d0-434a-44c5-8827-41ba8a0b17f5", name: "Calendars.Read", type: "Role", resource: "Microsoft Graph" },
  { id: "ef54d2bf-783f-4e0f-bca1-3210c0444d99", name: "Calendars.ReadWrite", type: "Role", resource: "Microsoft Graph" },
  { id: "75359482-378d-4052-8f01-80520e7db3cd", name: "Files.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "01d4889c-1287-42c6-ac1f-5d1e02578ef6", name: "Files.ReadWrite.All", type: "Role", resource: "Microsoft Graph" },
  { id: "332a536c-c7ef-4017-ab91-336970924f0d", name: "Sites.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "9492366f-7969-46a4-8d15-ed1a20078fff", name: "Sites.ReadWrite.All", type: "Role", resource: "Microsoft Graph" },
  { id: "bf394140-e372-4bf9-a898-299cfc7564e5", name: "SecurityEvents.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "d903a879-88e0-4c09-b0c9-82f6a1333f84", name: "SecurityEvents.ReadWrite.All", type: "Role", resource: "Microsoft Graph" },
  { id: "230c1aed-a721-4c5d-9cb4-a90514e508ef", name: "Reports.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "483bed4a-2ad3-4361-a73b-c83ccdbdc53c", name: "RoleManagement.Read.All", type: "Role", resource: "Microsoft Graph" },
  { id: "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8", name: "RoleManagement.ReadWrite.Directory", type: "Role", resource: "Microsoft Graph" },
];

const GRAPH_RESOURCE_APP_ID = "00000003-0000-0000-c000-000000000000";

const Page = () => {
  const router = useRouter();
  const [isSaving, setIsSaving] = useState(false);

  const {
    control,
    handleSubmit,
    formState: { errors },
    watch,
  } = useForm({
    mode: "onBlur",
    defaultValues: {
      name: "",
      description: "",
      appNamePattern: "",
      permissions: [],
      generateSecret: true,
      secretExpirationDays: 730,
      documentationUrl: "",
    },
  });

  const { fields: permissionFields, append, remove } = useFieldArray({
    control,
    name: "permissions",
  });

  const saveMutation = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: ["ListIntegrationTemplates"],
  });

  const onSubmit = (data) => {
    setIsSaving(true);

    const groupedPermissions = {};
    data.permissions.forEach((perm) => {
      const resourceAppId = GRAPH_RESOURCE_APP_ID;
      if (!groupedPermissions[resourceAppId]) {
        groupedPermissions[resourceAppId] = {
          resource: perm.resource,
          resourceAppId,
          permissions: [],
        };
      }
      groupedPermissions[resourceAppId].permissions.push({
        id: perm.id,
        name: perm.name,
        type: perm.type,
      });
    });

    const appNamePattern = data.appNamePattern || `${data.name} - {TenantName}`;

    saveMutation.mutate(
      {
        url: "/api/ExecIntegrationTemplate",
        data: {
          action: "save",
          name: data.name,
          description: data.description,
          appNamePattern,
          permissions: Object.values(groupedPermissions),
          generateSecret: data.generateSecret,
          secretExpirationDays: data.secretExpirationDays,
          documentationUrl: data.documentationUrl,
        },
      },
      {
        onSuccess: (response) => {
          setIsSaving(false);
          router.push("/tenant/administration/applications/integration-templates");
        },
        onError: () => {
          setIsSaving(false);
        },
      }
    );
  };

  const selectedPermissions = watch("permissions") || [];
  const availablePermissions = COMMON_GRAPH_PERMISSIONS.filter(
    (p) => !selectedPermissions.some((sp) => sp.id === p.id)
  );

  return (
    <CippPageCard title="Add Integration Template" hideBackButton={false}>
      <Box sx={{ p: 3 }}>
        <form onSubmit={handleSubmit(onSubmit)}>
          <Stack spacing={3}>
            <Card variant="outlined">
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Template Details
                </Typography>
                <Stack spacing={2}>
                  <Controller
                    name="name"
                    control={control}
                    rules={{ required: "Name is required" }}
                    render={({ field }) => (
                      <TextField
                        {...field}
                        label="Template Name"
                        fullWidth
                        error={!!errors.name}
                        helperText={errors.name?.message}
                      />
                    )}
                  />

                  <Controller
                    name="description"
                    control={control}
                    render={({ field }) => (
                      <TextField
                        {...field}
                        label="Description"
                        fullWidth
                        multiline
                        rows={2}
                        helperText="Brief description of what this template is used for"
                      />
                    )}
                  />

                  <Controller
                    name="appNamePattern"
                    control={control}
                    render={({ field }) => (
                      <TextField
                        {...field}
                        label="App Name Pattern"
                        fullWidth
                        placeholder="{TemplateName} - {TenantName}"
                        helperText="Use {TenantName} as a placeholder. Leave empty for default pattern."
                      />
                    )}
                  />

                  <Controller
                    name="documentationUrl"
                    control={control}
                    render={({ field }) => (
                      <TextField
                        {...field}
                        label="Documentation URL"
                        fullWidth
                        placeholder="https://..."
                        helperText="Link to setup instructions for this integration"
                      />
                    )}
                  />
                </Stack>
              </CardContent>
            </Card>

            <Card variant="outlined">
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  API Permissions
                </Typography>
                <Stack spacing={2}>
                  <Autocomplete
                    options={availablePermissions}
                    getOptionLabel={(option) => `${option.name} (${option.type})`}
                    groupBy={(option) => option.resource}
                    onChange={(_, value) => {
                      if (value) {
                        append(value);
                      }
                    }}
                    renderInput={(params) => (
                      <TextField
                        {...params}
                        label="Add Permission"
                        placeholder="Search permissions..."
                      />
                    )}
                    value={null}
                  />

                  {permissionFields.length === 0 ? (
                    <Alert severity="info">
                      No permissions added. Select permissions from the dropdown above.
                    </Alert>
                  ) : (
                    <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                      {permissionFields.map((field, index) => (
                        <Chip
                          key={field.id}
                          label={field.name}
                          onDelete={() => remove(index)}
                          color="primary"
                          variant="outlined"
                        />
                      ))}
                    </Stack>
                  )}

                  {errors.permissions && (
                    <FormHelperText error>{errors.permissions.message}</FormHelperText>
                  )}
                </Stack>
              </CardContent>
            </Card>

            <Card variant="outlined">
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Secret Settings
                </Typography>
                <Stack spacing={2}>
                  <Controller
                    name="generateSecret"
                    control={control}
                    render={({ field }) => (
                      <FormControlLabel
                        control={<Switch {...field} checked={field.value} />}
                        label="Auto-generate client secret"
                      />
                    )}
                  />

                  <Controller
                    name="secretExpirationDays"
                    control={control}
                    render={({ field }) => (
                      <FormControl fullWidth>
                        <InputLabel>Secret Expiration</InputLabel>
                        <Select {...field} label="Secret Expiration">
                          <MenuItem value={90}>90 days</MenuItem>
                          <MenuItem value={180}>180 days</MenuItem>
                          <MenuItem value={365}>1 year</MenuItem>
                          <MenuItem value={730}>2 years (maximum)</MenuItem>
                        </Select>
                      </FormControl>
                    )}
                  />
                </Stack>
              </CardContent>
            </Card>

            <Stack direction="row" spacing={2} justifyContent="flex-end">
              <Button
                variant="outlined"
                onClick={() => router.push("/tenant/administration/applications/integration-templates")}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                variant="contained"
                startIcon={<Save />}
                disabled={isSaving || permissionFields.length === 0}
              >
                {isSaving ? "Saving..." : "Save Template"}
              </Button>
            </Stack>
          </Stack>
        </form>
      </Box>
    </CippPageCard>
  );
};

Page.getLayout = (page) => (
  <DashboardLayout>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
);

export default Page;
