import { useEffect, useState } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippHead } from "../../../../components/CippComponents/CippHead.jsx";
import {
  Alert,
  Box,
  Card,
  CardContent,
  CardHeader,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Grid,
  LinearProgress,
  Skeleton,
  Stack,
  Typography,
  Button,
} from "@mui/material";
import {
  ShieldOutlined,
  PeopleOutline,
  BusinessOutlined,
  HealthAndSafetyOutlined,
  CheckCircleOutline,
  WarningAmberOutlined,
  ErrorOutline,
  OpenInNew,
  PersonAdd,
  Send,
} from "@mui/icons-material";
import { useSettings } from "../../../../hooks/use-settings.js";
import { ApiGetCall } from "../../../../api/ApiCall.jsx";
import Link from "next/link";
import axios from "axios";
import { buildVersionedHeaders } from "../../../../utils/cippVersion";
import CippAccessTypeGuide from "../../../../components/CippComponents/CippAccessTypeGuide";

const HealthScoreCard = ({ healthData, isFetching }) => {
  if (isFetching) {
    return (
      <Card>
        <CardContent>
          <Skeleton variant="rectangular" height={120} />
        </CardContent>
      </Card>
    );
  }

  const score = healthData?.HealthScore ?? 0;
  const status = healthData?.HealthStatus ?? "Unknown";

  const getStatusColor = (status) => {
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
        return "default";
    }
  };

  return (
    <Card>
      <CardHeader
        title="Cross-Tenant Health Score"
        avatar={<HealthAndSafetyOutlined color={getStatusColor(status)} />}
      />
      <CardContent>
        <Stack spacing={2}>
          <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
            <Typography variant="h3" fontWeight="bold">
              {score}
            </Typography>
            <Chip label={status} color={getStatusColor(status)} size="medium" />
          </Box>
          <LinearProgress
            variant="determinate"
            value={score}
            color={getStatusColor(status)}
            sx={{ height: 8, borderRadius: 4 }}
          />
          <Stack direction="row" spacing={3}>
            {healthData?.CriticalCount > 0 && (
              <Stack direction="row" spacing={0.5} alignItems="center">
                <ErrorOutline color="error" fontSize="small" />
                <Typography variant="body2">{healthData.CriticalCount} Critical</Typography>
              </Stack>
            )}
            <Stack direction="row" spacing={0.5} alignItems="center">
              <WarningAmberOutlined color="warning" fontSize="small" />
              <Typography variant="body2">{healthData?.WarningCount ?? 0} Warnings</Typography>
            </Stack>
            <Stack direction="row" spacing={0.5} alignItems="center">
              <CheckCircleOutline color="info" fontSize="small" />
              <Typography variant="body2">{healthData?.InfoCount ?? 0} Info</Typography>
            </Stack>
          </Stack>
        </Stack>
      </CardContent>
    </Card>
  );
};

const PolicySummaryCard = ({ healthData, isFetching }) => {
  if (isFetching) {
    return (
      <Card>
        <CardContent>
          <Skeleton variant="rectangular" height={200} />
        </CardContent>
      </Card>
    );
  }

  const summary = healthData?.Summary;

  const getAccessChip = (value) => {
    if (!value || value === "Not configured") {
      return <Chip label="Not Configured" size="small" color="default" />;
    }
    return (
      <Chip
        label={value.charAt(0).toUpperCase() + value.slice(1)}
        size="small"
        color={value === "allowed" ? "success" : value === "blocked" ? "error" : "default"}
      />
    );
  };

  return (
    <Card>
      <CardHeader title="Policy Summary" avatar={<ShieldOutlined color="primary" />} />
      <CardContent>
        <Stack spacing={1.5}>
          <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <Typography variant="body2" color="text.secondary">
              B2B Collaboration (Inbound)
            </Typography>
            {getAccessChip(summary?.b2bCollaborationInbound)}
          </Box>
          <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <Typography variant="body2" color="text.secondary">
              B2B Collaboration (Outbound)
            </Typography>
            {getAccessChip(summary?.b2bCollaborationOutbound)}
          </Box>
          <Divider />
          <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <Typography variant="body2" color="text.secondary">
              B2B Direct Connect (Inbound)
            </Typography>
            {getAccessChip(summary?.b2bDirectConnectInbound)}
          </Box>
          <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <Typography variant="body2" color="text.secondary">
              B2B Direct Connect (Outbound)
            </Typography>
            {getAccessChip(summary?.b2bDirectConnectOutbound)}
          </Box>
          <Divider />
          <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <Typography variant="body2" color="text.secondary">
              Trust External MFA
            </Typography>
            <Chip
              label={summary?.trustExternalMFA ? "Enabled" : "Disabled"}
              size="small"
              color={summary?.trustExternalMFA ? "success" : "default"}
            />
          </Box>
          <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <Typography variant="body2" color="text.secondary">
              Trust Compliant Devices
            </Typography>
            <Chip
              label={summary?.trustCompliantDevices ? "Enabled" : "Disabled"}
              size="small"
              color={summary?.trustCompliantDevices ? "success" : "default"}
            />
          </Box>
          <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <Typography variant="body2" color="text.secondary">
              Trust Hybrid AD Joined
            </Typography>
            <Chip
              label={summary?.trustHybridJoinedDevices ? "Enabled" : "Disabled"}
              size="small"
              color={summary?.trustHybridJoinedDevices ? "success" : "default"}
            />
          </Box>
        </Stack>
      </CardContent>
    </Card>
  );
};

const QuickLinksCard = () => {
  const links = [
    {
      title: "Default Policy",
      description: "Manage B2B Collaboration, Direct Connect, and Tenant Restrictions defaults",
      href: "/tenant/administration/cross-tenant-access/policy",
      icon: <ShieldOutlined />,
    },
    {
      title: "Partner Organizations",
      description: "Configure per-organization cross-tenant access overrides",
      href: "/tenant/administration/cross-tenant-access/partners",
      icon: <BusinessOutlined />,
    },
    {
      title: "External Collaboration",
      description: "Guest invite settings, domain allow/deny lists, and guest permissions",
      href: "/tenant/administration/cross-tenant-access/external-collaboration",
      icon: <PeopleOutline />,
    },
    {
      title: "Health Report",
      description: "Configuration conflict detection and security recommendations",
      href: "/tenant/administration/cross-tenant-access/health",
      icon: <HealthAndSafetyOutlined />,
    },
    {
      title: "Security Templates",
      description: "Create and deploy standardized cross-tenant security baselines",
      href: "/tenant/administration/cross-tenant-access/templates",
      icon: <ShieldOutlined />,
    },
  ];

  return (
    <Card>
      <CardHeader title="Cross-Tenant Access Management" />
      <CardContent>
        <Stack spacing={2}>
          {links.map((link) => (
            <Link key={link.href} href={link.href} passHref legacyBehavior>
              <Card
                variant="outlined"
                sx={{
                  cursor: "pointer",
                  "&:hover": { borderColor: "primary.main", bgcolor: "action.hover" },
                  transition: "all 0.2s",
                }}
                component="a"
              >
                <CardContent sx={{ py: 1.5, "&:last-child": { pb: 1.5 } }}>
                  <Stack direction="row" spacing={2} alignItems="center">
                    <Box sx={{ color: "primary.main" }}>{link.icon}</Box>
                    <Box sx={{ flex: 1 }}>
                      <Typography variant="subtitle2">{link.title}</Typography>
                      <Typography variant="body2" color="text.secondary">
                        {link.description}
                      </Typography>
                    </Box>
                    <OpenInNew fontSize="small" color="action" />
                  </Stack>
                </CardContent>
              </Card>
            </Link>
          ))}
        </Stack>
      </CardContent>
    </Card>
  );
};

const GuestReadyCard = ({ tenantFilter }) => {
  const [open, setOpen] = useState(false);
  const [applying, setApplying] = useState(false);
  const [result, setResult] = useState(null);

  const handleApply = async () => {
    setApplying(true);
    setResult(null);
    const results = [];
    const headers = await buildVersionedHeaders();

    try {
      await axios.post(
        "/api/EditExternalCollaboration",
        { tenantFilter, allowInvitesFrom: "adminsAndGuestInviters" },
        { headers }
      );
      results.push({ step: "Entra guest invite policy", status: "success" });
    } catch (err) {
      results.push({
        step: "Entra guest invite policy",
        status: "error",
        detail: err?.response?.data?.Results || err?.message,
      });
    }

    try {
      await axios.post(
        "/api/EditSharepointSettings",
        { tenantFilter, sharingCapability: "externalUserAndGuestSharing" },
        { headers }
      );
      results.push({ step: "SharePoint external sharing", status: "success" });
    } catch (err) {
      results.push({
        step: "SharePoint external sharing",
        status: "error",
        detail: err?.response?.data?.Results || err?.message,
      });
    }

    try {
      await axios.post(
        "/api/EditTeamsSettings",
        { tenantFilter, AllowGuestUser: true },
        { headers }
      );
      results.push({ step: "Teams guest access", status: "success" });
    } catch (err) {
      results.push({
        step: "Teams guest access",
        status: "error",
        detail: err?.response?.data?.Results || err?.message,
      });
    }

    setResult(results);
    setApplying(false);
  };

  return (
    <>
      <Card>
        <CardHeader title="Quick Setup: Guest-Ready Configuration" />
        <CardContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Configure this tenant for external guest collaboration in one click. This sets up Entra,
            SharePoint, and Teams to allow guest users with secure defaults.
          </Typography>
          <Button variant="contained" onClick={() => setOpen(true)} startIcon={<PersonAdd />}>
            Configure for Guest Access
          </Button>
        </CardContent>
      </Card>

      <Dialog open={open} onClose={() => !applying && setOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Configure Guest Access</DialogTitle>
        <DialogContent>
          {!result && (
            <Stack spacing={2}>
              <Typography variant="body2">This will apply the following settings:</Typography>
              <Alert severity="info" variant="outlined" icon={false}>
                <Stack spacing={1}>
                  <Typography variant="body2">
                    <strong>Entra:</strong> Guest invite restrictions &rarr; Admins and Guest Inviter
                    role
                  </Typography>
                  <Typography variant="body2">
                    <strong>SharePoint:</strong> External sharing &rarr; New and existing guests
                  </Typography>
                  <Typography variant="body2">
                    <strong>Teams:</strong> Guest access &rarr; Enabled
                  </Typography>
                </Stack>
              </Alert>
            </Stack>
          )}
          {result && (
            <Stack spacing={1}>
              {result.map((r, i) => (
                <Alert key={i} severity={r.status === "success" ? "success" : "error"} sx={{ py: 0.25 }}>
                  <Typography variant="body2">
                    {r.step}: {r.status === "success" ? "Applied" : r.detail || "Failed"}
                  </Typography>
                </Alert>
              ))}
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => {
              setOpen(false);
              setResult(null);
            }}
          >
            {result ? "Close" : "Cancel"}
          </Button>
          {!result && (
            <Button
              variant="contained"
              onClick={handleApply}
              disabled={applying}
              startIcon={applying ? <CircularProgress size={16} /> : <Send />}
            >
              {applying ? "Applying..." : "Apply Configuration"}
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </>
  );
};

const Page = () => {
  const settings = useSettings();
  const currentTenant = settings.currentTenant;

  const healthReport = ApiGetCall({
    url: "/api/ListCrossTenantHealth",
    data: { tenantFilter: currentTenant },
    queryKey: `CrossTenantHealth-${currentTenant}`,
    waiting: true,
  });

  useEffect(() => {
    if (currentTenant) {
      healthReport.refetch();
    }
  }, [currentTenant]);

  return (
    <Box sx={{ p: 3 }}>
      <CippHead title="Cross-Tenant Access" />
      <Typography variant="h4" gutterBottom>
        Cross-Tenant Access & External Collaboration
      </Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        Centralized management of Microsoft Entra cross-tenant access policies, B2B collaboration
        settings, and external identity governance.
      </Typography>
      <CippAccessTypeGuide variant="panel" context="crossTenantAccess" />

      {!currentTenant || currentTenant === "AllTenants" ? (
        <Card>
          <CardContent>
            <Typography color="text.secondary">
              Please select a specific tenant to view cross-tenant access settings.
            </Typography>
          </CardContent>
        </Card>
      ) : (
        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <Stack spacing={3}>
              <HealthScoreCard
                healthData={healthReport.data?.Results}
                isFetching={healthReport.isFetching}
              />
              <PolicySummaryCard
                healthData={healthReport.data?.Results}
                isFetching={healthReport.isFetching}
              />
            </Stack>
          </Grid>
          <Grid item xs={12} md={6}>
            <Stack spacing={3}>
              <QuickLinksCard />
              <GuestReadyCard tenantFilter={currentTenant} />
            </Stack>
          </Grid>
        </Grid>
      )}
    </Box>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
