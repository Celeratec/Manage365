import { useEffect } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippHead } from "../../../../components/CippComponents/CippHead.jsx";
import {
  Alert,
  Box,
  Card,
  CardContent,
  CardHeader,
  Chip,
  Grid,
  LinearProgress,
  Skeleton,
  Stack,
  Typography,
  Button,
} from "@mui/material";
import {
  CheckCircleOutline,
  ErrorOutline,
  HealthAndSafetyOutlined,
  InfoOutlined,
  OpenInNew,
  Refresh,
  WarningAmberOutlined,
} from "@mui/icons-material";
import Link from "next/link";
import { useSettings } from "../../../../hooks/use-settings.js";
import { ApiGetCall } from "../../../../api/ApiCall.jsx";

const SeverityIcon = ({ severity }) => {
  switch (severity) {
    case "Critical":
      return <ErrorOutline color="error" />;
    case "Warning":
      return <WarningAmberOutlined color="warning" />;
    case "Info":
      return <InfoOutlined color="info" />;
    default:
      return <CheckCircleOutline color="success" />;
  }
};

const getSeverityColor = (severity) => {
  switch (severity) {
    case "Critical":
      return "error";
    case "Warning":
      return "warning";
    case "Info":
      return "info";
    default:
      return "success";
  }
};

const FindingCard = ({ finding }) => (
  <Card variant="outlined" sx={{ mb: 1 }}>
    <CardContent sx={{ py: 1.5, "&:last-child": { pb: 1.5 } }}>
      <Stack direction="row" spacing={2} alignItems="flex-start">
        <Box sx={{ pt: 0.5 }}>
          <SeverityIcon severity={finding.Severity} />
        </Box>
        <Box sx={{ flex: 1 }}>
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 0.5 }}>
            <Typography variant="subtitle2">{finding.Finding}</Typography>
            <Chip label={finding.Severity} size="small" color={getSeverityColor(finding.Severity)} />
          </Stack>
          <Stack direction="row" spacing={1} sx={{ mb: 0.5 }}>
            <Chip label={finding.Category} size="small" variant="outlined" />
            <Chip label={finding.Area} size="small" variant="outlined" />
          </Stack>
          <Typography variant="body2" color="text.secondary">
            {finding.Recommendation}
          </Typography>
          {finding.RelatedLink && finding.RelatedPage && (
            <Box sx={{ mt: 1 }}>
              <Link href={finding.RelatedLink} passHref legacyBehavior>
                <Button
                  component="a"
                  size="small"
                  variant="outlined"
                  endIcon={<OpenInNew fontSize="small" />}
                  sx={{ textTransform: "none" }}
                >
                  Go to {finding.RelatedPage}
                </Button>
              </Link>
            </Box>
          )}
        </Box>
      </Stack>
    </CardContent>
  </Card>
);

const Page = () => {
  const settings = useSettings();
  const currentTenant = settings.currentTenant;

  const healthQuery = ApiGetCall({
    url: "/api/ListCrossTenantHealth",
    data: { tenantFilter: currentTenant },
    queryKey: `CrossTenantHealth-${currentTenant}`,
    waiting: true,
  });

  useEffect(() => {
    if (currentTenant) {
      healthQuery.refetch();
    }
  }, [currentTenant]);

  if (!currentTenant || currentTenant === "AllTenants") {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="warning">
          Please select a specific tenant to view cross-tenant health report.
        </Alert>
      </Box>
    );
  }

  const healthData = healthQuery.data?.Results;
  const findings = healthData?.Findings ?? [];

  const criticalFindings = findings.filter((f) => f.Severity === "Critical");
  const warningFindings = findings.filter((f) => f.Severity === "Warning");
  const infoFindings = findings.filter((f) => f.Severity === "Info");

  const getHealthColor = (status) => {
    switch (status) {
      case "Healthy":
        return "success";
      case "Needs Attention":
        return "warning";
      case "At Risk":
        return "warning";
      case "Critical":
        return "error";
      default:
        return "info";
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <CippHead title="Cross-Tenant Health Report" />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Cross-Tenant Health Report
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Configuration analysis, conflict detection, and security recommendations for
            cross-tenant access policies.
          </Typography>
        </Box>
        <Button
          variant="outlined"
          startIcon={<Refresh />}
          onClick={() => healthQuery.refetch()}
          disabled={healthQuery.isFetching}
        >
          Refresh
        </Button>
      </Stack>

      {healthQuery.isFetching ? (
        <Stack spacing={2}>
          <Skeleton variant="rectangular" height={150} />
          <Skeleton variant="rectangular" height={300} />
        </Stack>
      ) : healthData ? (
        <Stack spacing={3}>
          {/* Health Score Overview */}
          <Card>
            <CardContent>
              <Grid container spacing={3} alignItems="center">
                <Grid item xs={12} md={4}>
                  <Stack alignItems="center" spacing={1}>
                    <HealthAndSafetyOutlined
                      sx={{ fontSize: 48 }}
                      color={getHealthColor(healthData.HealthStatus)}
                    />
                    <Typography variant="h2" fontWeight="bold">
                      {healthData.HealthScore}
                    </Typography>
                    <Chip
                      label={healthData.HealthStatus}
                      color={getHealthColor(healthData.HealthStatus)}
                      size="medium"
                    />
                  </Stack>
                </Grid>
                <Grid item xs={12} md={8}>
                  <Stack spacing={2}>
                    <Box>
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                        Health Score
                      </Typography>
                      <LinearProgress
                        variant="determinate"
                        value={healthData.HealthScore}
                        color={getHealthColor(healthData.HealthStatus)}
                        sx={{ height: 10, borderRadius: 5 }}
                      />
                    </Box>
                    <Grid container spacing={2}>
                      <Grid item xs={4}>
                        <Card variant="outlined">
                          <CardContent sx={{ textAlign: "center", py: 1, "&:last-child": { pb: 1 } }}>
                            <Typography variant="h5" color="error.main">
                              {healthData.CriticalCount}
                            </Typography>
                            <Typography variant="caption">Critical</Typography>
                          </CardContent>
                        </Card>
                      </Grid>
                      <Grid item xs={4}>
                        <Card variant="outlined">
                          <CardContent sx={{ textAlign: "center", py: 1, "&:last-child": { pb: 1 } }}>
                            <Typography variant="h5" color="warning.main">
                              {healthData.WarningCount}
                            </Typography>
                            <Typography variant="caption">Warnings</Typography>
                          </CardContent>
                        </Card>
                      </Grid>
                      <Grid item xs={4}>
                        <Card variant="outlined">
                          <CardContent sx={{ textAlign: "center", py: 1, "&:last-child": { pb: 1 } }}>
                            <Typography variant="h5" color="info.main">
                              {healthData.InfoCount}
                            </Typography>
                            <Typography variant="caption">Info</Typography>
                          </CardContent>
                        </Card>
                      </Grid>
                    </Grid>
                    <Typography variant="body2" color="text.secondary">
                      {healthData.PartnerCount} partner organization(s) configured
                    </Typography>
                  </Stack>
                </Grid>
              </Grid>
            </CardContent>
          </Card>

          {/* Findings */}
          {criticalFindings.length > 0 && (
            <Card>
              <CardHeader
                title={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <ErrorOutline color="error" />
                    <Typography variant="h6">Critical Findings ({criticalFindings.length})</Typography>
                  </Stack>
                }
              />
              <CardContent>
                {criticalFindings.map((finding, idx) => (
                  <FindingCard key={`critical-${idx}`} finding={finding} />
                ))}
              </CardContent>
            </Card>
          )}

          {warningFindings.length > 0 && (
            <Card>
              <CardHeader
                title={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <WarningAmberOutlined color="warning" />
                    <Typography variant="h6">Warnings ({warningFindings.length})</Typography>
                  </Stack>
                }
              />
              <CardContent>
                {warningFindings.map((finding, idx) => (
                  <FindingCard key={`warning-${idx}`} finding={finding} />
                ))}
              </CardContent>
            </Card>
          )}

          {infoFindings.length > 0 && (
            <Card>
              <CardHeader
                title={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <InfoOutlined color="info" />
                    <Typography variant="h6">Informational ({infoFindings.length})</Typography>
                  </Stack>
                }
              />
              <CardContent>
                {infoFindings.map((finding, idx) => (
                  <FindingCard key={`info-${idx}`} finding={finding} />
                ))}
              </CardContent>
            </Card>
          )}

          {findings.length === 0 && (
            <Card>
              <CardContent>
                <Stack alignItems="center" spacing={2} sx={{ py: 3 }}>
                  <CheckCircleOutline sx={{ fontSize: 48 }} color="success" />
                  <Typography variant="h6">No findings detected</Typography>
                  <Typography variant="body2" color="text.secondary">
                    Your cross-tenant access configuration looks good!
                  </Typography>
                </Stack>
              </CardContent>
            </Card>
          )}
        </Stack>
      ) : null}
    </Box>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
