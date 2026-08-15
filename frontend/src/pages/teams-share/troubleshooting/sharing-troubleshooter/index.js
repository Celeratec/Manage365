import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { useState, useEffect } from "react";
import { useForm } from "react-hook-form";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CardHeader,
  Chip,
  CircularProgress,
  Grid,
  Stack,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from "@mui/material";
import {
  CheckCircle,
  Cancel,
  Warning,
  Info,
  Search,
  Refresh,
  OpenInNew,
  Language,
  Groups,
  AutoFixHigh,
} from "@mui/icons-material";
import {
  Timeline,
  TimelineItem,
  TimelineSeparator,
  TimelineDot,
  TimelineConnector,
  TimelineContent,
} from "@mui/lab";
import Link from "next/link";
import CippFormComponent from "../../../../components/CippComponents/CippFormComponent";

import { ApiPostCall } from "../../../../api/ApiCall";
import { useSettings } from "../../../../hooks/use-settings";
import { CippHead } from "../../../../components/CippComponents/CippHead.jsx";

const QUICK_PRESETS = [
  {
    key: "yahoo-gmail-sharepoint",
    label: "Personal email can't access SharePoint",
    description: "Yahoo, Gmail, or Outlook.com user can't access a SharePoint site",
    resourceType: "sharepoint",
  },
  {
    key: "shared-channel",
    label: "External user can't join shared channel",
    description: "Work/school account can't be added to a Teams shared channel",
    resourceType: "teams",
  },
  {
    key: "guest-signin",
    label: "Guest invited but can't sign in",
    description: "Guest was invited but gets an error when trying to access resources",
    resourceType: "auto",
  },
];

const getCheckIcon = (status) => {
  switch (status) {
    case "pass":
      return <CheckCircle color="success" />;
    case "fail":
      return <Cancel color="error" />;
    case "warning":
      return <Warning color="warning" />;
    case "info":
      return <Info color="info" />;
    default:
      return <Info color="disabled" />;
  }
};

const getCheckColor = (status) => {
  switch (status) {
    case "pass":
      return "success";
    case "fail":
      return "error";
    case "warning":
      return "warning";
    default:
      return "info";
  }
};

const getOverallLabel = (status) => {
  switch (status) {
    case "pass":
      return { label: "All Checks Passed", color: "success" };
    case "fail":
      return { label: "Issues Found", color: "error" };
    case "warning":
      return { label: "Warnings Found", color: "warning" };
    default:
      return { label: "Complete", color: "info" };
  }
};

const Page = () => {
  const settings = useSettings();
  const currentTenant = settings.currentTenant;
  const [results, setResults] = useState(null);
  const [selectedPreset, setSelectedPreset] = useState(null);

  const formHook = useForm({
    defaultValues: {
      userEmail: "",
      resourceUrl: "",
      resourceType: "auto",
    },
    mode: "onChange",
  });

  const troubleshootApi = ApiPostCall({});

  const watchedResourceType = formHook.watch("resourceType");

  useEffect(() => {
    formHook.setValue("resourceUrl", null);
  }, [watchedResourceType]);

  const onSubmit = (data) => {
    setResults(null);
    troubleshootApi.mutate(
      {
        url: "/api/ExecSharingTroubleshoot",
        data: {
          tenantFilter: currentTenant,
          ...data,
          resourceUrl: data.resourceUrl?.value || data.resourceUrl || "",
        },
      },
      {
        onSuccess: (response) => {
          setResults(response?.data?.Results);
        },
        onError: (error) => {
          setResults({
            overallStatus: "fail",
            checks: [
              {
                step: "Troubleshooter Error",
                status: "fail",
                detail: error?.response?.data?.Results || error?.message || "An error occurred",
                category: "System",
              },
            ],
            summary: { totalChecks: 1, passed: 0, failed: 1, warnings: 0 },
          });
        },
      }
    );
  };

  const handlePreset = (preset) => {
    setSelectedPreset(preset.key);
    formHook.setValue("resourceType", preset.resourceType);
  };

  const handleReset = () => {
    setResults(null);
    setSelectedPreset(null);
    formHook.reset();
  };

  const isLoading = troubleshootApi.isPending;
  const checks = results?.checks || [];
  const summary = results?.summary;
  const overallInfo = results ? getOverallLabel(results.overallStatus) : null;

  return (
    <>
      <CippHead title="Sharing Troubleshooter" />
      <Box sx={{ p: 3 }}>
        <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
          <Box>
            <Typography variant="h4">Sharing & Guest Troubleshooter</Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
              Diagnose why an external user can&apos;t access SharePoint or Teams resources. Checks domain policies, guest status, sharing settings, and cross-tenant configuration.
            </Typography>
          </Box>
          {results && (
            <Button variant="outlined" startIcon={<Refresh />} onClick={handleReset}>
              New Check
            </Button>
          )}
        </Stack>

        {!currentTenant && (
          <Alert severity="info">Select a tenant to use the troubleshooter.</Alert>
        )}

        {currentTenant && !results && (
          <>
            <Typography variant="subtitle2" sx={{ mb: 1.5 }}>
              Quick Presets
            </Typography>
            <Grid container spacing={2} sx={{ mb: 3 }}>
              {QUICK_PRESETS.map((preset) => (
                <Grid item xs={12} sm={4} key={preset.key}>
                  <Card
                    variant={selectedPreset === preset.key ? "elevation" : "outlined"}
                    sx={{
                      cursor: "pointer",
                      borderColor: selectedPreset === preset.key ? "primary.main" : undefined,
                      borderWidth: selectedPreset === preset.key ? 2 : 1,
                      transition: "all 0.2s",
                      "&:hover": { borderColor: "primary.main" },
                    }}
                    onClick={() => handlePreset(preset)}
                  >
                    <CardContent sx={{ py: 1.5, "&:last-child": { pb: 1.5 } }}>
                      <Typography variant="subtitle2">{preset.label}</Typography>
                      <Typography variant="caption" color="text.secondary">
                        {preset.description}
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>

            <Card>
              <CardContent>
                <form onSubmit={formHook.handleSubmit(onSubmit)}>
                  <Stack spacing={3}>
                    <Box>
                      <Typography variant="subtitle2" sx={{ mb: 1 }}>Guest Email Address</Typography>
                      <CippFormComponent
                        formControl={formHook}
                        type="textField"
                        name="userEmail"
                        label="Guest Email Address"
                        placeholder="user@external-domain.com"
                        validators={{
                          required: "Email is required",
                          pattern: {
                            value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
                            message: "Enter a valid email",
                          },
                        }}
                      />
                    </Box>

                    <Box>
                      <Typography variant="subtitle2" sx={{ mb: 1 }}>Resource Type</Typography>
                      <ToggleButtonGroup
                        value={watchedResourceType}
                        exclusive
                        onChange={(_, val) => { if (val !== null) formHook.setValue("resourceType", val); }}
                        fullWidth
                        sx={{
                          "& .MuiToggleButton-root": {
                            textTransform: "none",
                            py: 1.5,
                            flexDirection: "column",
                            gap: 0.5,
                          },
                        }}
                      >
                        <ToggleButton value="auto">
                          <AutoFixHigh />
                          <Typography variant="body2">Auto-detect</Typography>
                        </ToggleButton>
                        <ToggleButton value="sharepoint">
                          <Language />
                          <Typography variant="body2">SharePoint</Typography>
                        </ToggleButton>
                        <ToggleButton value="teams">
                          <Groups />
                          <Typography variant="body2">Teams</Typography>
                        </ToggleButton>
                      </ToggleButtonGroup>
                    </Box>

                    <Box>
                      <Typography variant="subtitle2" sx={{ mb: 1 }}>
                        {watchedResourceType === "teams" ? "Team (Optional)" : "SharePoint Site (Optional)"}
                      </Typography>
                      {watchedResourceType === "teams" ? (
                        <CippFormComponent
                          key="troubleshoot-teams"
                          formControl={formHook}
                          type="autoComplete"
                          name="resourceUrl"
                          label="Search or enter a Team"
                          multiple={false}
                          creatable={true}
                          size="medium"
                          api={{
                            url: "/api/ListTeams",
                            data: { type: "list" },
                            queryKey: `troubleshoot-teams-${currentTenant}`,
                            labelField: (team) => team.displayName || team.id,
                            valueField: "id",
                          }}
                        />
                      ) : (
                        <CippFormComponent
                          key="troubleshoot-sites"
                          formControl={formHook}
                          type="autoComplete"
                          name="resourceUrl"
                          label="Search or enter a site URL"
                          multiple={false}
                          creatable={true}
                          size="medium"
                          api={{
                            url: "/api/ListSites",
                            data: { type: "SharePointSiteUsage" },
                            queryKey: `troubleshoot-sites-${currentTenant}`,
                            labelField: (site) => site.displayName ? `${site.displayName} (${site.webUrl})` : site.webUrl,
                            valueField: "webUrl",
                          }}
                        />
                      )}
                    </Box>

                    <Stack direction="row" justifyContent="flex-end">
                      <Button
                        variant="contained"
                        type="submit"
                        size="large"
                        disabled={!formHook.formState.isValid || isLoading}
                        startIcon={isLoading ? <CircularProgress size={18} /> : <Search />}
                        sx={{ px: 4 }}
                      >
                        {isLoading ? "Running Checks..." : "Run Troubleshooter"}
                      </Button>
                    </Stack>
                  </Stack>
                </form>
              </CardContent>
            </Card>
          </>
        )}

        {isLoading && (
          <Stack alignItems="center" spacing={2} sx={{ py: 6 }}>
            <CircularProgress size={40} />
            <Typography variant="body1" color="text.secondary">
              Running diagnostic checks...
            </Typography>
          </Stack>
        )}

        {results && !isLoading && (
          <Stack spacing={3}>
            <Card>
              <CardContent>
                <Stack direction="row" spacing={2} alignItems="center">
                  <Chip label={overallInfo.label} color={overallInfo.color} />
                  {results.email && (
                    <Typography variant="body2" color="text.secondary">
                      {results.email}
                    </Typography>
                  )}
                  {results.domainType && (
                    <Chip
                      label={results.domainType === "consumer" ? "Personal Email" : results.domainType === "organizational" ? "Work/School" : "Unknown"}
                      size="small"
                      variant="outlined"
                      color={results.domainType === "consumer" ? "warning" : "info"}
                    />
                  )}
                  {summary && (
                    <Stack direction="row" spacing={1} sx={{ ml: "auto" }}>
                      <Chip label={`${summary.passed} passed`} size="small" color="success" variant="outlined" />
                      {summary.failed > 0 && (
                        <Chip label={`${summary.failed} failed`} size="small" color="error" variant="outlined" />
                      )}
                      {summary.warnings > 0 && (
                        <Chip label={`${summary.warnings} warnings`} size="small" color="warning" variant="outlined" />
                      )}
                    </Stack>
                  )}
                </Stack>
              </CardContent>
            </Card>

            <Card>
              <CardHeader title="Diagnostic Timeline" />
              <CardContent>
                <Timeline position="right" sx={{ p: 0 }}>
                  {checks.map((check, idx) => (
                    <TimelineItem key={idx}>
                      <TimelineSeparator>
                        <TimelineDot color={getCheckColor(check.status)} variant="outlined">
                          {getCheckIcon(check.status)}
                        </TimelineDot>
                        {idx < checks.length - 1 && <TimelineConnector />}
                      </TimelineSeparator>
                      <TimelineContent sx={{ py: 1.5, px: 2 }}>
                        <Stack spacing={0.5}>
                          <Stack direction="row" spacing={1} alignItems="center">
                            <Typography variant="subtitle2">{check.step}</Typography>
                            {check.category && (
                              <Chip label={check.category} size="small" variant="outlined" sx={{ height: 20, fontSize: "0.65rem" }} />
                            )}
                          </Stack>
                          <Typography variant="body2" color="text.secondary">
                            {check.detail}
                          </Typography>
                          {check.fix && (
                            <Alert severity="info" variant="outlined" icon={false} sx={{ py: 0.25, mt: 0.5 }}>
                              <Typography variant="caption">
                                <strong>Fix:</strong> {check.fix}
                              </Typography>
                            </Alert>
                          )}
                          {check.settingsPage && (
                            <Box sx={{ mt: 0.5 }}>
                              <Link href={`${check.settingsPage}?tenantFilter=${currentTenant}`} passHref legacyBehavior>
                                <Button
                                  component="a"
                                  size="small"
                                  variant="outlined"
                                  target="_blank"
                                  endIcon={<OpenInNew fontSize="small" />}
                                  sx={{ textTransform: "none", fontSize: "0.7rem" }}
                                >
                                  Open Settings
                                </Button>
                              </Link>
                            </Box>
                          )}
                        </Stack>
                      </TimelineContent>
                    </TimelineItem>
                  ))}
                </Timeline>
              </CardContent>
            </Card>
          </Stack>
        )}
      </Box>
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
