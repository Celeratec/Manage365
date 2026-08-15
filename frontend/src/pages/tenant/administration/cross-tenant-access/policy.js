import { useEffect, useState, useMemo } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippHead } from "../../../../components/CippComponents/CippHead.jsx";
import {
  Alert,
  Box,
  Card,
  CardContent,
  CardHeader,
  Chip,
  Divider,
  Grid,
  Skeleton,
  Stack,
  Tab,
  Tabs,
  Typography,
  Button,
  Switch,
  FormControlLabel,
  Radio,
  RadioGroup,
  FormControl,
  FormLabel,
} from "@mui/material";
import { useSettings } from "../../../../hooks/use-settings.js";
import { ApiGetCall, ApiPostCall } from "../../../../api/ApiCall.jsx";
import { CippApiResults } from "../../../../components/CippComponents/CippApiResults.jsx";
import CippRelatedSettings from "../../../../components/CippComponents/CippRelatedSettings.jsx";
import CippRiskAlert from "../../../../components/CippComponents/CippRiskAlert.jsx";
import CippRiskSummaryDialog from "../../../../components/CippComponents/CippRiskSummaryDialog.jsx";
import { Save } from "@mui/icons-material";

const TabPanel = ({ children, value, index }) => (
  <div role="tabpanel" hidden={value !== index}>
    {value === index && <Box sx={{ py: 3 }}>{children}</Box>}
  </div>
);

const AccessSettingsEditor = ({ title, description, settings, onChange }) => {
  const usersAccessType = settings?.usersAndGroups?.accessType ?? "allowed";
  const appsAccessType = settings?.applications?.accessType ?? "allowed";

  const handleUsersAccessChange = (e) => {
    onChange({
      ...settings,
      usersAndGroups: {
        ...settings?.usersAndGroups,
        accessType: e.target.value,
        targets: [{ target: "AllUsers", targetType: "user" }],
      },
    });
  };

  const handleAppsAccessChange = (e) => {
    onChange({
      ...settings,
      applications: {
        ...settings?.applications,
        accessType: e.target.value,
        targets: [{ target: "AllApplications", targetType: "application" }],
      },
    });
  };

  return (
    <Card variant="outlined" sx={{ mb: 2 }}>
      <CardHeader title={title} subheader={description} />
      <CardContent>
        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <FormControl component="fieldset">
              <FormLabel>Users & Groups Access</FormLabel>
              <RadioGroup value={usersAccessType} onChange={handleUsersAccessChange}>
                <FormControlLabel value="allowed" control={<Radio />} label="Allow access" />
                <FormControlLabel value="blocked" control={<Radio />} label="Block access" />
              </RadioGroup>
            </FormControl>
          </Grid>
          <Grid item xs={12} md={6}>
            <FormControl component="fieldset">
              <FormLabel>Applications Access</FormLabel>
              <RadioGroup value={appsAccessType} onChange={handleAppsAccessChange}>
                <FormControlLabel value="allowed" control={<Radio />} label="Allow access" />
                <FormControlLabel value="blocked" control={<Radio />} label="Block access" />
              </RadioGroup>
            </FormControl>
          </Grid>
        </Grid>
      </CardContent>
    </Card>
  );
};

const POLICY_RISK_RULES = [
  {
    id: "auto-consent-inbound",
    test: (d) => d?.automaticUserConsentSettings?.inboundAllowed === true,
    severity: "warning",
    title: "Automatic Inbound Consent Enabled",
    description:
      "Inbound guest invitations are auto-redeemed without user consent prompts. External users gain access to resources without explicitly accepting an invitation.",
    recommendation:
      "Disable unless you have a specific cross-tenant sync or B2B collaboration agreement that requires auto-redemption.",
  },
  {
    id: "auto-consent-outbound",
    test: (d) => d?.automaticUserConsentSettings?.outboundAllowed === true,
    severity: "warning",
    title: "Automatic Outbound Consent Enabled",
    description:
      "Your users' outbound invitations are auto-redeemed in partner organizations. Users may gain access to external resources without an explicit consent step.",
    recommendation:
      "Disable unless you have a specific cross-tenant sync agreement with partner organizations.",
  },
  {
    id: "all-trust-enabled",
    test: (d) =>
      d?.inboundTrust?.isMfaAccepted === true &&
      d?.inboundTrust?.isCompliantDeviceAccepted === true &&
      d?.inboundTrust?.isHybridAzureADJoinedDeviceAccepted === true,
    severity: "info",
    title: "All Inbound Trust Claims Accepted",
    description:
      "All three trust settings (MFA, device compliance, hybrid AD join) are enabled. This accepts all security claims from every external organization, reducing your control over device posture verification for guest users.",
    recommendation:
      "Consider enabling trust only for specific partner organizations via per-partner policies rather than in the defaults.",
  },
  {
    id: "b2b-direct-connect-inbound-open",
    test: (d) => d?.b2bDirectConnectInbound?.usersAndGroups?.accessType === "allowed",
    severity: "warning",
    title: "B2B Direct Connect Inbound Allowed for All Organizations",
    description:
      "The default policy allows B2B direct connect inbound from every external organization. Direct connect users access Teams shared channels without guest accounts -- they have no footprint in your directory and are not subject to your Conditional Access policies unless inbound trust is configured. Consider using partner-specific policies to allow direct connect only for trusted organizations.",
    recommendation:
      "Block B2B direct connect in the default policy and create partner-specific policies for organizations that need shared channel access.",
  },
  {
    id: "b2b-defaults-all-open",
    test: (d) =>
      d?.b2bCollaborationInbound?.usersAndGroups?.accessType === "allowed" &&
      d?.b2bCollaborationOutbound?.usersAndGroups?.accessType === "allowed" &&
      d?.b2bDirectConnectInbound?.usersAndGroups?.accessType === "allowed" &&
      d?.b2bDirectConnectOutbound?.usersAndGroups?.accessType === "allowed",
    severity: "info",
    title: "All Default Access Policies Are Open",
    description:
      "Both B2B Collaboration and B2B Direct Connect are set to allow all users in both directions. This is the most permissive default configuration. Consider restricting at least one direction or using per-partner overrides.",
  },
];

const Page = () => {
  const settings = useSettings();
  const currentTenant = settings.currentTenant;
  const [tabValue, setTabValue] = useState(0);
  const [policyData, setPolicyData] = useState(null);
  const [hasChanges, setHasChanges] = useState(false);
  const [riskDialogOpen, setRiskDialogOpen] = useState(false);

  const activeRisks = useMemo(() => {
    if (!policyData) return [];
    return POLICY_RISK_RULES.filter((r) => r.test(policyData)).map(({ test, ...rest }) => rest);
  }, [policyData]);

  const policyQuery = ApiGetCall({
    url: "/api/ListCrossTenantPolicy",
    data: { tenantFilter: currentTenant },
    queryKey: `CrossTenantPolicy-${currentTenant}`,
    waiting: true,
  });

  const updatePolicy = ApiPostCall({
    relatedQueryKeys: [`CrossTenantPolicy-${currentTenant}`, `CrossTenantHealth-${currentTenant}`],
  });

  useEffect(() => {
    if (currentTenant) {
      policyQuery.refetch();
    }
  }, [currentTenant]);

  useEffect(() => {
    if (policyQuery.data?.Results && !policyData) {
      setPolicyData(policyQuery.data.Results);
    }
  }, [policyQuery.data]);

  const handleFieldChange = (field, value) => {
    setPolicyData((prev) => ({
      ...prev,
      [field]: value,
    }));
    setHasChanges(true);
  };

  const executeSave = () => {
    updatePolicy.mutate({
      url: "/api/EditCrossTenantPolicy",
      data: {
        tenantFilter: currentTenant,
        ...policyData,
      },
    });
    setHasChanges(false);
  };

  const handleSave = () => {
    const significantRisks = activeRisks.filter((r) => r.severity !== "info");
    if (significantRisks.length > 0) {
      setRiskDialogOpen(true);
    } else {
      executeSave();
    }
  };

  if (!currentTenant || currentTenant === "AllTenants") {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="warning">
          Please select a specific tenant to manage cross-tenant access policy.
        </Alert>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      <CippHead title="Cross-Tenant Access Policy" />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Cross-Tenant Access Policy Defaults
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Configure default settings for B2B Collaboration, Direct Connect, Inbound Trust, and
            Tenant Restrictions.
          </Typography>
        </Box>
        <Button
          variant="contained"
          startIcon={<Save />}
          onClick={handleSave}
          disabled={!hasChanges || updatePolicy.isPending}
        >
          Save Changes
        </Button>
      </Stack>

      <CippApiResults apiObject={updatePolicy} />

      <CippRelatedSettings
        title="Multiple settings layers control external access"
        description="B2B Collaboration and Direct Connect settings only control the cross-tenant access layer. Guest invitations are also gated by Entra External Collaboration (domain lists, invite permissions) and SharePoint Sharing Settings (domain restrictions, sharing level). Teams shared channels also depend on Teams Federation settings."
        links={[
          {
            label: "External Collaboration",
            href: "/tenant/administration/cross-tenant-access/external-collaboration",
          },
          { label: "SharePoint Sharing Settings", href: "/teams-share/sharepoint/sharing-settings" },
          { label: "Teams Settings", href: "/teams-share/teams/teams-settings" },
        ]}
      />

      {policyQuery.isFetching ? (
        <Skeleton variant="rectangular" height={400} />
      ) : (
        <>
          <Tabs value={tabValue} onChange={(e, v) => setTabValue(v)} sx={{ mb: 1 }}>
            <Tab label="B2B Collaboration" />
            <Tab label="B2B Direct Connect" />
            <Tab label="Inbound Trust" />
            <Tab label="Tenant Restrictions" />
            <Tab label="Automatic Consent" />
          </Tabs>

          {/* B2B Collaboration */}
          <TabPanel value={tabValue} index={0}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Control which external users and applications can collaborate with your organization
              through B2B collaboration (guest access).
            </Typography>
            <AccessSettingsEditor
              title="Inbound Access"
              description="External users accessing your organization's resources"
              settings={policyData?.b2bCollaborationInbound}
              onChange={(val) => handleFieldChange("b2bCollaborationInbound", val)}
            />
            <AccessSettingsEditor
              title="Outbound Access"
              description="Your users accessing external organization's resources"
              settings={policyData?.b2bCollaborationOutbound}
              onChange={(val) => handleFieldChange("b2bCollaborationOutbound", val)}
            />
          </TabPanel>

          {/* B2B Direct Connect */}
          <TabPanel value={tabValue} index={1}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              B2B Direct Connect enables seamless collaboration through Teams shared channels without
              requiring guest accounts. Unlike B2B collaboration (guest access), direct connect users
              have no directory footprint in your tenant.
            </Typography>
            <AccessSettingsEditor
              title="Inbound Access"
              description="External users accessing your Teams shared channels"
              settings={policyData?.b2bDirectConnectInbound}
              onChange={(val) => handleFieldChange("b2bDirectConnectInbound", val)}
            />
            <CippRiskAlert
              visible={policyData?.b2bDirectConnectInbound?.usersAndGroups?.accessType === "allowed"}
              severity="warning"
              title="Direct Connect Inbound Open to All Organizations"
              description="Allowing B2B direct connect inbound in the default policy means users from ANY external organization can be added to Teams shared channels. These users access resources without guest accounts, so they are not visible in your directory and are not subject to your Conditional Access policies unless you configure inbound trust."
              recommendation="Block direct connect inbound in the default policy and create partner-specific policies for trusted organizations that need shared channel access."
            />
            <AccessSettingsEditor
              title="Outbound Access"
              description="Your users accessing external Teams shared channels"
              settings={policyData?.b2bDirectConnectOutbound}
              onChange={(val) => handleFieldChange("b2bDirectConnectOutbound", val)}
            />
          </TabPanel>

          {/* Inbound Trust */}
          <TabPanel value={tabValue} index={2}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Control whether your Conditional Access policies accept claims from external
              organizations when external users access your resources.
            </Typography>
            <Card variant="outlined">
              <CardContent>
                <Stack spacing={2}>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={policyData?.inboundTrust?.isMfaAccepted ?? false}
                        onChange={(e) =>
                          handleFieldChange("inboundTrust", {
                            ...policyData?.inboundTrust,
                            isMfaAccepted: e.target.checked,
                          })
                        }
                      />
                    }
                    label="Trust multi-factor authentication from external tenants"
                  />
                  <Typography variant="body2" color="text.secondary" sx={{ ml: 6 }}>
                    When enabled, your Conditional Access policies will accept MFA claims from
                    external organizations, so external users won't need to perform MFA in your
                    tenant.
                  </Typography>

                  <Divider />

                  <FormControlLabel
                    control={
                      <Switch
                        checked={policyData?.inboundTrust?.isCompliantDeviceAccepted ?? false}
                        onChange={(e) =>
                          handleFieldChange("inboundTrust", {
                            ...policyData?.inboundTrust,
                            isCompliantDeviceAccepted: e.target.checked,
                          })
                        }
                      />
                    }
                    label="Trust compliant devices from external tenants"
                  />
                  <Typography variant="body2" color="text.secondary" sx={{ ml: 6 }}>
                    Accept device compliance claims from partner organizations' Intune-managed
                    devices.
                  </Typography>

                  <Divider />

                  <FormControlLabel
                    control={
                      <Switch
                        checked={
                          policyData?.inboundTrust?.isHybridAzureADJoinedDeviceAccepted ?? false
                        }
                        onChange={(e) =>
                          handleFieldChange("inboundTrust", {
                            ...policyData?.inboundTrust,
                            isHybridAzureADJoinedDeviceAccepted: e.target.checked,
                          })
                        }
                      />
                    }
                    label="Trust Microsoft Entra hybrid joined devices from external tenants"
                  />
                  <Typography variant="body2" color="text.secondary" sx={{ ml: 6 }}>
                    Accept hybrid Azure AD join claims from partner organizations.
                  </Typography>
                  <CippRiskAlert
                    visible={
                      policyData?.inboundTrust?.isMfaAccepted === true &&
                      policyData?.inboundTrust?.isCompliantDeviceAccepted === true &&
                      policyData?.inboundTrust?.isHybridAzureADJoinedDeviceAccepted === true
                    }
                    severity="info"
                    title="All Inbound Trust Claims Accepted"
                    description="All three trust settings are enabled in the defaults, accepting security claims from every external organization. This reduces your control over device posture verification for guest users."
                    recommendation="Consider enabling trust only for specific partner organizations via per-partner policies rather than in the defaults."
                  />
                </Stack>
              </CardContent>
            </Card>
          </TabPanel>

          {/* Tenant Restrictions */}
          <TabPanel value={tabValue} index={3}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Tenant Restrictions v2 control which external tenants your users can access using
              devices and network your organization manages. These defaults apply to all external
              tenants.
            </Typography>
            <AccessSettingsEditor
              title="Tenant Restrictions Defaults"
              description="Control which external tenants your users can access"
              settings={policyData?.tenantRestrictions}
              onChange={(val) => handleFieldChange("tenantRestrictions", val)}
            />
          </TabPanel>

          {/* Automatic User Consent */}
          <TabPanel value={tabValue} index={4}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Automatic user consent settings control whether users can automatically redeem
              invitations from external organizations.
            </Typography>
            <Card variant="outlined">
              <CardContent>
                <Stack spacing={2}>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={
                          policyData?.automaticUserConsentSettings?.inboundAllowed ?? false
                        }
                        onChange={(e) =>
                          handleFieldChange("automaticUserConsentSettings", {
                            ...policyData?.automaticUserConsentSettings,
                            inboundAllowed: e.target.checked,
                          })
                        }
                      />
                    }
                    label="Automatically redeem invitations for inbound users"
                  />
                  <Typography variant="body2" color="text.secondary" sx={{ ml: 6 }}>
                    External users will automatically redeem invitations when accessing your
                    resources without needing to accept a consent prompt.
                  </Typography>
                  <CippRiskAlert
                    visible={policyData?.automaticUserConsentSettings?.inboundAllowed === true}
                    severity="warning"
                    title="Automatic Inbound Consent Enabled"
                    description="Inbound guest invitations are auto-redeemed without user consent prompts. External users gain access without explicitly accepting."
                    recommendation="Disable unless you have a specific cross-tenant sync or B2B collaboration agreement that requires auto-redemption."
                  />

                  <Divider />

                  <FormControlLabel
                    control={
                      <Switch
                        checked={
                          policyData?.automaticUserConsentSettings?.outboundAllowed ?? false
                        }
                        onChange={(e) =>
                          handleFieldChange("automaticUserConsentSettings", {
                            ...policyData?.automaticUserConsentSettings,
                            outboundAllowed: e.target.checked,
                          })
                        }
                      />
                    }
                    label="Automatically redeem invitations for outbound users"
                  />
                  <Typography variant="body2" color="text.secondary" sx={{ ml: 6 }}>
                    Your users will automatically redeem invitations when accessing external
                    organizations' resources.
                  </Typography>
                  <CippRiskAlert
                    visible={policyData?.automaticUserConsentSettings?.outboundAllowed === true}
                    severity="warning"
                    title="Automatic Outbound Consent Enabled"
                    description="Your users' outbound invitations are auto-redeemed in partner organizations without an explicit consent step."
                    recommendation="Disable unless you have a specific cross-tenant sync agreement with partner organizations."
                  />
                </Stack>
              </CardContent>
            </Card>
          </TabPanel>
        </>
      )}

      <CippRiskSummaryDialog
        open={riskDialogOpen}
        onClose={() => setRiskDialogOpen(false)}
        onConfirm={() => {
          setRiskDialogOpen(false);
          executeSave();
        }}
        risks={activeRisks.filter((r) => r.severity !== "info")}
      />
    </Box>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
