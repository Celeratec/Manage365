import { useState, useEffect } from "react";
import { useRouter } from "next/router";
import { Layout as DashboardLayout } from "../../../../../layouts/index.js";
import { TabbedLayout } from "../../../../../layouts/TabbedLayout";
import tabOptions from "../tabOptions";
import CippPageCard from "../../../../../components/CippCards/CippPageCard";
import { ApiGetCall, ApiPostCall } from "../../../../../api/ApiCall";
import {
  Box,
  Button,
  Typography,
  Stack,
  Stepper,
  Step,
  StepLabel,
  Card,
  CardContent,
  Alert,
  Chip,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  CircularProgress,
  alpha,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  IconButton,
  Tooltip,
  Collapse,
} from "@mui/material";
import { useTheme } from "@mui/material/styles";
import {
  ArrowBack,
  ArrowForward,
  RocketLaunch,
  Settings,
  Business,
  Warning,
  Delete,
  CheckCircle,
  Cancel,
  ExpandMore,
  ExpandLess,
  Refresh,
} from "@mui/icons-material";
import Link from "next/link";
import { CippFormTenantSelector } from "../../../../../components/CippComponents/CippFormTenantSelector";
import { useForm, useWatch } from "react-hook-form";
import CippDeploymentResults from "../../../../../components/CippComponents/CippDeploymentResults";

const steps = ["Review Template", "Select Tenants", "Pre-Check", "Deploy"];

const Page = () => {
  const router = useRouter();
  const theme = useTheme();
  const { template: templateId } = router.query;
  const [activeStep, setActiveStep] = useState(0);
  const [deploymentId, setDeploymentId] = useState(null);
  const [isDeploying, setIsDeploying] = useState(false);
  const [isChecking, setIsChecking] = useState(false);
  const [preCheckResults, setPreCheckResults] = useState(null);
  const [expandedTenants, setExpandedTenants] = useState({});
  const [deletingApps, setDeletingApps] = useState({});

  const formControl = useForm({
    mode: "onChange",
    defaultValues: {
      tenantFilter: [],
      secretExpirationDays: 730,
    },
  });

  const selectedTenants = useWatch({
    control: formControl.control,
    name: "tenantFilter",
  });

  const templateQuery = ApiGetCall({
    url: "/api/ListIntegrationTemplates",
    data: { id: templateId },
    queryKey: ["IntegrationTemplate", templateId],
    enabled: !!templateId,
  });

  const template = templateQuery.data?.[0];

  const deployMutation = ApiPostCall({
    relatedQueryKeys: ["ListIntegrationTemplates"],
  });

  const preCheckMutation = ApiPostCall({});
  const deleteMutation = ApiPostCall({});

  // Watch for successful deployment and advance to results step
  useEffect(() => {
    if (deployMutation.isSuccess && deployMutation.data?.data?.DeploymentId) {
      setDeploymentId(deployMutation.data.data.DeploymentId);
      setActiveStep(3);
      setIsDeploying(false);
    } else if (deployMutation.isError) {
      console.error("Deploy error:", deployMutation.error);
      setIsDeploying(false);
    }
  }, [deployMutation.isSuccess, deployMutation.isError, deployMutation.data, deployMutation.error]);

  // Watch for pre-check results
  useEffect(() => {
    if (preCheckMutation.isSuccess && preCheckMutation.data?.data?.Results) {
      setPreCheckResults(preCheckMutation.data.data.Results);
      setIsChecking(false);
    } else if (preCheckMutation.isError) {
      console.error("Pre-check error:", preCheckMutation.error);
      setIsChecking(false);
    }
  }, [preCheckMutation.isSuccess, preCheckMutation.isError, preCheckMutation.data]);

  // Watch for delete results
  useEffect(() => {
    if (deleteMutation.isSuccess) {
      // Refresh the pre-check after deletion
      runPreCheck();
    }
  }, [deleteMutation.isSuccess]);

  const runPreCheck = () => {
    const tenants = Array.isArray(selectedTenants) ? selectedTenants : [selectedTenants];
    if (tenants.length === 0) return;

    setIsChecking(true);
    setPreCheckResults(null);
    preCheckMutation.mutate({
      url: "/api/ListIntegrationAppStatus",
      data: {
        templateId: template.id,
        tenants: tenants.map((t) => ({
          value: t.value,
          label: t.label,
        })),
      },
    });
  };

  const handleNext = () => {
    if (activeStep === 1) {
      // Moving from tenant selection to pre-check
      setActiveStep(2);
      runPreCheck();
    } else if (activeStep === 2) {
      handleDeploy();
    } else {
      setActiveStep((prev) => prev + 1);
    }
  };

  const handleBack = () => {
    if (activeStep === 2) {
      setPreCheckResults(null);
    }
    setActiveStep((prev) => prev - 1);
  };

  const handleDeploy = () => {
    const tenants = Array.isArray(selectedTenants) ? selectedTenants : [selectedTenants];
    if (tenants.length === 0) return;

    setIsDeploying(true);
    deployMutation.mutate({
      url: "/api/ExecDeployIntegrationApp",
      data: {
        templateId: template.id,
        tenants: tenants.map((t) => ({
          value: t.value,
          label: t.label,
        })),
        customizations: {
          secretExpirationDays: formControl.getValues("secretExpirationDays"),
        },
      },
    });
  };

  const handleDeleteApp = (tenant, app) => {
    const key = `${tenant}-${app.id}`;
    setDeletingApps((prev) => ({ ...prev, [key]: true }));

    deleteMutation.mutate(
      {
        url: "/api/ExecDeleteIntegrationApp",
        data: {
          tenantFilter: tenant,
          appObjectId: app.id,
          appId: app.appId,
        },
      },
      {
        onSettled: () => {
          setDeletingApps((prev) => ({ ...prev, [key]: false }));
        },
      }
    );
  };

  const toggleTenantExpanded = (tenant) => {
    setExpandedTenants((prev) => ({
      ...prev,
      [tenant]: !prev[tenant],
    }));
  };

  const permissionCount =
    template?.permissions?.reduce(
      (acc, resource) => acc + (resource.permissions?.length || 0),
      0
    ) || 0;

  const tenantsWithExistingApps = preCheckResults?.filter((r) => r.hasExistingApps) || [];
  const hasExistingApps = tenantsWithExistingApps.length > 0;

  const canProceed = () => {
    if (activeStep === 0) return !!template;
    if (activeStep === 1) {
      const tenants = Array.isArray(selectedTenants) ? selectedTenants : [selectedTenants];
      return tenants.length > 0 && tenants[0]?.value;
    }
    if (activeStep === 2) {
      return preCheckResults !== null && !isChecking;
    }
    return false;
  };

  if (!templateId) {
    return (
      <CippPageCard title="Deploy Integration App">
        <Box sx={{ p: 3 }}>
          <Alert severity="warning">
            No template selected. Please select a template from the{" "}
            <Link href="/tenant/administration/applications/integration-templates">
              Integration Templates
            </Link>{" "}
            page.
          </Alert>
        </Box>
      </CippPageCard>
    );
  }

  return (
    <CippPageCard title={`Deploy: ${template?.name || "Loading..."}`}>
      <Box sx={{ p: 3 }}>
        <Stepper activeStep={activeStep} sx={{ mb: 4 }}>
          {steps.map((label) => (
            <Step key={label}>
              <StepLabel>{label}</StepLabel>
            </Step>
          ))}
        </Stepper>

        {templateQuery.isLoading ? (
          <Box sx={{ textAlign: "center", py: 4 }}>
            <CircularProgress />
          </Box>
        ) : templateQuery.isError ? (
          <Alert severity="error">
            Failed to load template: {templateQuery.error?.message || "Unknown error"}
          </Alert>
        ) : (
          <>
            {activeStep === 0 && (
              <Stack spacing={3}>
                <Box sx={{ textAlign: "center" }}>
                  <Box
                    sx={{
                      display: "inline-flex",
                      alignItems: "center",
                      justifyContent: "center",
                      width: 72,
                      height: 72,
                      borderRadius: "50%",
                      bgcolor: alpha(theme.palette.primary.main, 0.1),
                      color: "primary.main",
                      mb: 1.5,
                      border: `2px solid ${alpha(theme.palette.primary.main, 0.2)}`,
                    }}
                  >
                    <Settings sx={{ fontSize: 36 }} />
                  </Box>
                  <Typography variant="h5" fontWeight={600} gutterBottom>
                    Review Template
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Confirm the template settings before selecting tenants
                  </Typography>
                </Box>

                <Card variant="outlined">
                  <CardContent>
                    <Stack spacing={2}>
                      <Box>
                        <Typography variant="subtitle2" color="text.secondary">
                          Template Name
                        </Typography>
                        <Typography variant="body1" fontWeight={500}>
                          {template?.name}
                        </Typography>
                      </Box>

                      <Box>
                        <Typography variant="subtitle2" color="text.secondary">
                          Description
                        </Typography>
                        <Typography variant="body1">
                          {template?.description || "No description provided"}
                        </Typography>
                      </Box>

                      <Box>
                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                          Permissions ({permissionCount})
                        </Typography>
                        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                          {template?.permissions?.map((resource) =>
                            resource.permissions?.map((perm) => (
                              <Chip
                                key={perm.id}
                                label={perm.name}
                                size="small"
                                variant="outlined"
                                color="primary"
                              />
                            ))
                          )}
                        </Stack>
                      </Box>

                      <Box>
                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                          App Name Pattern
                        </Typography>
                        <Typography variant="body2" sx={{ fontFamily: "monospace" }}>
                          {template?.appNamePattern}
                        </Typography>
                      </Box>
                    </Stack>
                  </CardContent>
                </Card>

                <Card variant="outlined">
                  <CardContent>
                    <Typography variant="subtitle2" gutterBottom>
                      Customizations
                    </Typography>
                    <FormControl fullWidth size="small">
                      <InputLabel>Secret Expiration</InputLabel>
                      <Select
                        value={formControl.watch("secretExpirationDays")}
                        onChange={(e) =>
                          formControl.setValue("secretExpirationDays", e.target.value)
                        }
                        label="Secret Expiration"
                      >
                        <MenuItem value={90}>90 days</MenuItem>
                        <MenuItem value={180}>180 days</MenuItem>
                        <MenuItem value={365}>1 year</MenuItem>
                        <MenuItem value={730}>2 years (maximum)</MenuItem>
                      </Select>
                    </FormControl>
                  </CardContent>
                </Card>
              </Stack>
            )}

            {activeStep === 1 && (
              <Stack spacing={3}>
                <Box sx={{ textAlign: "center" }}>
                  <Box
                    sx={{
                      display: "inline-flex",
                      alignItems: "center",
                      justifyContent: "center",
                      width: 72,
                      height: 72,
                      borderRadius: "50%",
                      bgcolor: alpha(theme.palette.primary.main, 0.1),
                      color: "primary.main",
                      mb: 1.5,
                      border: `2px solid ${alpha(theme.palette.primary.main, 0.2)}`,
                    }}
                  >
                    <Business sx={{ fontSize: 36 }} />
                  </Box>
                  <Typography variant="h5" fontWeight={600} gutterBottom>
                    Select Tenants
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Choose the tenants where you want to create the app registration
                  </Typography>
                </Box>

                <CippFormTenantSelector
                  formControl={formControl}
                  allTenants={false}
                  type="multiple"
                  valueField="defaultDomainName"
                />

                {selectedTenants && selectedTenants.length > 0 && (
                  <Paper
                    variant="outlined"
                    sx={{
                      p: 2,
                      bgcolor: alpha(theme.palette.info.main, 0.02),
                      borderColor: alpha(theme.palette.info.main, 0.2),
                    }}
                  >
                    <Typography variant="body2">
                      <strong>{selectedTenants.length}</strong> tenant
                      {selectedTenants.length !== 1 ? "s" : ""} selected
                    </Typography>
                  </Paper>
                )}
              </Stack>
            )}

            {activeStep === 2 && (
              <Stack spacing={3}>
                <Box sx={{ textAlign: "center" }}>
                  <Box
                    sx={{
                      display: "inline-flex",
                      alignItems: "center",
                      justifyContent: "center",
                      width: 72,
                      height: 72,
                      borderRadius: "50%",
                      bgcolor: hasExistingApps
                        ? alpha(theme.palette.warning.main, 0.1)
                        : alpha(theme.palette.success.main, 0.1),
                      color: hasExistingApps ? "warning.main" : "success.main",
                      mb: 1.5,
                      border: `2px solid ${
                        hasExistingApps
                          ? alpha(theme.palette.warning.main, 0.2)
                          : alpha(theme.palette.success.main, 0.2)
                      }`,
                    }}
                  >
                    {isChecking ? (
                      <CircularProgress size={36} color="inherit" />
                    ) : hasExistingApps ? (
                      <Warning sx={{ fontSize: 36 }} />
                    ) : (
                      <CheckCircle sx={{ fontSize: 36 }} />
                    )}
                  </Box>
                  <Typography variant="h5" fontWeight={600} gutterBottom>
                    {isChecking
                      ? "Checking for Existing Apps..."
                      : hasExistingApps
                      ? "Existing Apps Found"
                      : "Ready to Deploy"}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    {isChecking
                      ? "Scanning selected tenants for existing app registrations"
                      : hasExistingApps
                      ? `Found existing apps in ${tenantsWithExistingApps.length} tenant(s). You can delete them before deploying or proceed to update them.`
                      : "No existing apps found. Click Deploy to create new app registrations."}
                  </Typography>
                </Box>

                {!isChecking && preCheckResults && (
                  <>
                    <Stack direction="row" justifyContent="flex-end">
                      <Button
                        size="small"
                        startIcon={<Refresh />}
                        onClick={runPreCheck}
                        disabled={isChecking}
                      >
                        Refresh
                      </Button>
                    </Stack>

                    {hasExistingApps && (
                      <Alert severity="warning">
                        The following tenants already have app registrations matching this template.
                        If you proceed, the existing apps will be updated with new permissions and a
                        new client secret will be generated. To start fresh, delete the existing
                        apps first.
                      </Alert>
                    )}

                    <TableContainer component={Paper} variant="outlined">
                      <Table size="small">
                        <TableHead>
                          <TableRow>
                            <TableCell width={40} />
                            <TableCell>Tenant</TableCell>
                            <TableCell>Expected App Name</TableCell>
                            <TableCell>Status</TableCell>
                            <TableCell align="right">Actions</TableCell>
                          </TableRow>
                        </TableHead>
                        <TableBody>
                          {preCheckResults.map((result) => (
                            <>
                              <TableRow key={result.tenant}>
                                <TableCell>
                                  {result.hasExistingApps && (
                                    <IconButton
                                      size="small"
                                      onClick={() => toggleTenantExpanded(result.tenant)}
                                    >
                                      {expandedTenants[result.tenant] ? (
                                        <ExpandLess />
                                      ) : (
                                        <ExpandMore />
                                      )}
                                    </IconButton>
                                  )}
                                </TableCell>
                                <TableCell>
                                  <Typography variant="body2" fontWeight={500}>
                                    {result.displayName || result.tenantName}
                                  </Typography>
                                  <Typography variant="caption" color="text.secondary">
                                    {result.tenant}
                                  </Typography>
                                </TableCell>
                                <TableCell>
                                  <Typography variant="body2" sx={{ fontFamily: "monospace" }}>
                                    {result.expectedAppName}
                                  </Typography>
                                </TableCell>
                                <TableCell>
                                  {result.error ? (
                                    <Chip
                                      icon={<Cancel fontSize="small" />}
                                      label="Error"
                                      size="small"
                                      color="error"
                                      variant="outlined"
                                    />
                                  ) : result.hasExistingApps ? (
                                    <Chip
                                      icon={<Warning fontSize="small" />}
                                      label={`${result.existingAppCount} existing`}
                                      size="small"
                                      color="warning"
                                      variant="outlined"
                                    />
                                  ) : (
                                    <Chip
                                      icon={<CheckCircle fontSize="small" />}
                                      label="Ready"
                                      size="small"
                                      color="success"
                                      variant="outlined"
                                    />
                                  )}
                                </TableCell>
                                <TableCell align="right">
                                  {result.hasExistingApps && result.existingApps?.length === 1 && (
                                    <Tooltip title="Delete existing app">
                                      <IconButton
                                        size="small"
                                        color="error"
                                        onClick={() =>
                                          handleDeleteApp(result.tenant, result.existingApps[0])
                                        }
                                        disabled={
                                          deletingApps[
                                            `${result.tenant}-${result.existingApps[0].id}`
                                          ]
                                        }
                                      >
                                        {deletingApps[
                                          `${result.tenant}-${result.existingApps[0].id}`
                                        ] ? (
                                          <CircularProgress size={18} />
                                        ) : (
                                          <Delete fontSize="small" />
                                        )}
                                      </IconButton>
                                    </Tooltip>
                                  )}
                                </TableCell>
                              </TableRow>
                              {result.hasExistingApps && result.existingApps?.length > 1 && (
                                <TableRow>
                                  <TableCell colSpan={5} sx={{ p: 0 }}>
                                    <Collapse in={expandedTenants[result.tenant]}>
                                      <Box sx={{ p: 2, bgcolor: "action.hover" }}>
                                        <Typography variant="subtitle2" gutterBottom>
                                          Existing Apps ({result.existingApps.length})
                                        </Typography>
                                        <Table size="small">
                                          <TableHead>
                                            <TableRow>
                                              <TableCell>App Name</TableCell>
                                              <TableCell>App ID</TableCell>
                                              <TableCell>Created</TableCell>
                                              <TableCell>Secrets</TableCell>
                                              <TableCell align="right">Action</TableCell>
                                            </TableRow>
                                          </TableHead>
                                          <TableBody>
                                            {result.existingApps.map((app) => (
                                              <TableRow key={app.id}>
                                                <TableCell>{app.displayName}</TableCell>
                                                <TableCell>
                                                  <Typography
                                                    variant="body2"
                                                    sx={{ fontFamily: "monospace", fontSize: "0.75rem" }}
                                                  >
                                                    {app.appId}
                                                  </Typography>
                                                </TableCell>
                                                <TableCell>
                                                  {app.createdDateTime
                                                    ? new Date(app.createdDateTime).toLocaleDateString()
                                                    : "-"}
                                                </TableCell>
                                                <TableCell>{app.secretCount || 0}</TableCell>
                                                <TableCell align="right">
                                                  <Tooltip title="Delete this app">
                                                    <IconButton
                                                      size="small"
                                                      color="error"
                                                      onClick={() =>
                                                        handleDeleteApp(result.tenant, app)
                                                      }
                                                      disabled={
                                                        deletingApps[`${result.tenant}-${app.id}`]
                                                      }
                                                    >
                                                      {deletingApps[`${result.tenant}-${app.id}`] ? (
                                                        <CircularProgress size={18} />
                                                      ) : (
                                                        <Delete fontSize="small" />
                                                      )}
                                                    </IconButton>
                                                  </Tooltip>
                                                </TableCell>
                                              </TableRow>
                                            ))}
                                          </TableBody>
                                        </Table>
                                      </Box>
                                    </Collapse>
                                  </TableCell>
                                </TableRow>
                              )}
                            </>
                          ))}
                        </TableBody>
                      </Table>
                    </TableContainer>
                  </>
                )}
              </Stack>
            )}

            {activeStep === 3 && deploymentId && (
              <CippDeploymentResults deploymentId={deploymentId} />
            )}

            {activeStep < 3 && (
              <Stack direction="row" spacing={2} justifyContent="space-between" sx={{ mt: 4 }}>
                <Button
                  variant="outlined"
                  onClick={handleBack}
                  disabled={activeStep === 0}
                  startIcon={<ArrowBack />}
                >
                  Back
                </Button>
                <Button
                  variant="contained"
                  onClick={handleNext}
                  disabled={!canProceed() || isDeploying || isChecking}
                  endIcon={
                    isDeploying || isChecking ? (
                      <CircularProgress size={20} color="inherit" />
                    ) : activeStep === 2 ? (
                      <RocketLaunch />
                    ) : (
                      <ArrowForward />
                    )
                  }
                >
                  {activeStep === 2 ? (hasExistingApps ? "Update & Deploy" : "Deploy") : "Next"}
                </Button>
              </Stack>
            )}

            {activeStep === 3 && (
              <Stack direction="row" spacing={2} justifyContent="center" sx={{ mt: 4 }}>
                <Button
                  variant="outlined"
                  component={Link}
                  href="/tenant/administration/applications/integration-templates"
                  startIcon={<ArrowBack />}
                >
                  Back to Templates
                </Button>
              </Stack>
            )}
          </>
        )}
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
