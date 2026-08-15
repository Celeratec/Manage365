import { useEffect, useState, useMemo, useCallback } from "react";
import { useRouter } from "next/router";
import { Layout as DashboardLayout } from "../../../../../layouts/index.js";
import { CippHead } from "../../../../../components/CippComponents/CippHead.jsx";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CardHeader,
  CircularProgress,
  Divider,
  FormControl,
  FormControlLabel,
  FormLabel,
  Grid,
  InputAdornment,
  Radio,
  RadioGroup,
  Stack,
  Switch,
  TextField,
  Typography,
} from "@mui/material";
import { Save, ArrowBack, Search } from "@mui/icons-material";
import { useSettings } from "../../../../../hooks/use-settings.js";
import { ApiGetCall, ApiPostCall } from "../../../../../api/ApiCall.jsx";
import { CippApiResults } from "../../../../../components/CippComponents/CippApiResults.jsx";
import CippRiskAlert from "../../../../../components/CippComponents/CippRiskAlert.jsx";
import CippRiskSummaryDialog from "../../../../../components/CippComponents/CippRiskSummaryDialog.jsx";
import Link from "next/link";

const AccessSettingsEditor = ({ title, description, settings, onChange }) => {
  const usersAccessType = settings?.usersAndGroups?.accessType ?? "inherited";
  const appsAccessType = settings?.applications?.accessType ?? "inherited";

  const handleUsersAccessChange = (e) => {
    const val = e.target.value;
    if (val === "inherited" && appsAccessType === "inherited") {
      onChange(null);
      return;
    }
    onChange({
      ...(settings ?? {}),
      usersAndGroups: val === "inherited" ? undefined : {
        accessType: val,
        targets: [{ target: "AllUsers", targetType: "user" }],
      },
    });
  };

  const handleAppsAccessChange = (e) => {
    const val = e.target.value;
    if (val === "inherited" && usersAccessType === "inherited") {
      onChange(null);
      return;
    }
    onChange({
      ...(settings ?? {}),
      applications: val === "inherited" ? undefined : {
        accessType: val,
        targets: [{ target: "AllApplications", targetType: "application" }],
      },
    });
  };

  return (
    <Card variant="outlined" sx={{ mb: 2 }}>
      <CardHeader title={title} subheader={description} titleTypographyProps={{ variant: "subtitle1" }} />
      <CardContent>
        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <FormControl component="fieldset">
              <FormLabel>Users & Groups</FormLabel>
              <RadioGroup value={usersAccessType} onChange={handleUsersAccessChange}>
                <FormControlLabel
                  value="inherited"
                  control={<Radio size="small" />}
                  label={
                    <Typography variant="body2">
                      Inherit from default policy
                    </Typography>
                  }
                />
                <FormControlLabel value="allowed" control={<Radio size="small" />} label="Allow" />
                <FormControlLabel value="blocked" control={<Radio size="small" />} label="Block" />
              </RadioGroup>
            </FormControl>
          </Grid>
          <Grid item xs={12} md={6}>
            <FormControl component="fieldset">
              <FormLabel>Applications</FormLabel>
              <RadioGroup value={appsAccessType} onChange={handleAppsAccessChange}>
                <FormControlLabel
                  value="inherited"
                  control={<Radio size="small" />}
                  label={
                    <Typography variant="body2">
                      Inherit from default policy
                    </Typography>
                  }
                />
                <FormControlLabel value="allowed" control={<Radio size="small" />} label="Allow" />
                <FormControlLabel value="blocked" control={<Radio size="small" />} label="Block" />
              </RadioGroup>
            </FormControl>
          </Grid>
        </Grid>
      </CardContent>
    </Card>
  );
};

const PARTNER_RISK_RULES = [
  {
    id: "auto-consent-inbound",
    test: (d) => d.automaticUserConsentSettings?.inboundAllowed === true,
    severity: "warning",
    title: "Automatic Inbound Consent Enabled",
    description:
      "Inbound invitations from this partner are auto-redeemed without user consent prompts. External users gain access without explicitly accepting an invitation.",
    recommendation:
      "Disable unless you have a specific cross-tenant sync agreement with this partner.",
  },
  {
    id: "auto-consent-outbound",
    test: (d) => d.automaticUserConsentSettings?.outboundAllowed === true,
    severity: "warning",
    title: "Automatic Outbound Consent Enabled",
    description:
      "Your users' invitations to this partner are auto-redeemed without an explicit consent step.",
    recommendation:
      "Disable unless you have a specific cross-tenant sync agreement with this partner.",
  },
  {
    id: "all-trust-enabled",
    test: (d) =>
      d.inboundTrust?.isMfaAccepted === true &&
      d.inboundTrust?.isCompliantDeviceAccepted === true &&
      d.inboundTrust?.isHybridAzureADJoinedDeviceAccepted === true,
    severity: "info",
    title: "All Inbound Trust Claims Accepted",
    description:
      "All three trust settings (MFA, device compliance, hybrid AD join) are enabled for this partner. You are fully trusting this partner's security posture.",
    recommendation:
      "Ensure you have verified this partner's security practices before trusting all claims.",
  },
  {
    id: "b2b-direct-connect-inbound-open",
    test: (d) => d.b2bDirectConnectInbound?.usersAndGroups?.accessType === "allowed",
    severity: "info",
    title: "B2B Direct Connect Inbound Allowed",
    description:
      "B2B direct connect is allowed inbound from this partner. Their users can be added to Teams shared channels without guest accounts -- they will have no footprint in your directory and are not subject to your Conditional Access policies unless inbound trust is configured for this partner.",
    recommendation:
      "Enable inbound trust settings for this partner if you want Conditional Access policies to apply to their direct connect users.",
  },
  {
    id: "all-access-open",
    test: (d) =>
      d.b2bCollaborationInbound?.usersAndGroups?.accessType === "allowed" &&
      d.b2bCollaborationOutbound?.usersAndGroups?.accessType === "allowed" &&
      d.b2bDirectConnectInbound?.usersAndGroups?.accessType === "allowed" &&
      d.b2bDirectConnectOutbound?.usersAndGroups?.accessType === "allowed",
    severity: "info",
    title: "All Access Policies Fully Open",
    description:
      "Both B2B Collaboration and B2B Direct Connect are set to allow all users in both directions for this partner. This is the most permissive configuration.",
  },
];

const Page = () => {
  const router = useRouter();
  const { tenantId: editTenantId } = router.query;
  const isEditing = !!editTenantId;

  const settings = useSettings();
  const currentTenant = settings.currentTenant;

  const [partnerTenantId, setPartnerTenantId] = useState("");
  const [domainInput, setDomainInput] = useState("");
  const [domainLookupState, setDomainLookupState] = useState({ loading: false, error: null, resolvedDomain: null });
  const [riskDialogOpen, setRiskDialogOpen] = useState(false);
  const [partnerData, setPartnerData] = useState({
    b2bCollaborationInbound: null,
    b2bCollaborationOutbound: null,
    b2bDirectConnectInbound: null,
    b2bDirectConnectOutbound: null,
    inboundTrust: {
      isMfaAccepted: false,
      isCompliantDeviceAccepted: false,
      isHybridAzureADJoinedDeviceAccepted: false,
    },
    automaticUserConsentSettings: {
      inboundAllowed: false,
      outboundAllowed: false,
    },
  });

  const activeRisks = useMemo(() => {
    return PARTNER_RISK_RULES.filter((r) => r.test(partnerData)).map(({ test, ...rest }) => rest);
  }, [partnerData]);

  // If editing, fetch existing partner data
  const partnersQuery = ApiGetCall({
    url: "/api/ListCrossTenantPartners",
    data: { tenantFilter: currentTenant },
    queryKey: `CrossTenantPartners-${currentTenant}`,
    waiting: isEditing,
  });

  const savePartner = ApiPostCall({
    relatedQueryKeys: [`CrossTenantPartners-${currentTenant}`, "CrossTenantPartners"],
  });

  useEffect(() => {
    if (isEditing && partnersQuery.data?.Results) {
      const existing = partnersQuery.data.Results.find((p) => p.tenantId === editTenantId);
      if (existing) {
        setPartnerTenantId(existing.tenantId);
        setPartnerData({
          b2bCollaborationInbound: existing.b2bCollaborationInbound,
          b2bCollaborationOutbound: existing.b2bCollaborationOutbound,
          b2bDirectConnectInbound: existing.b2bDirectConnectInbound,
          b2bDirectConnectOutbound: existing.b2bDirectConnectOutbound,
          inboundTrust: existing.inboundTrust ?? {
            isMfaAccepted: false,
            isCompliantDeviceAccepted: false,
            isHybridAzureADJoinedDeviceAccepted: false,
          },
          automaticUserConsentSettings: existing.automaticUserConsentSettings ?? {
            inboundAllowed: false,
            outboundAllowed: false,
          },
        });
      }
    }
  }, [partnersQuery.data, editTenantId]);

  const handleFieldChange = (field, value) => {
    setPartnerData((prev) => ({
      ...prev,
      [field]: value,
    }));
  };

  const MSA_TENANT_ID = "9188040d-6c67-4c5b-b112-36a304b66dad";

  const handleDomainLookup = useCallback(async () => {
    const domain = domainInput.trim().toLowerCase();
    if (!domain) return;

    setDomainLookupState({ loading: true, error: null, resolvedDomain: null });
    try {
      const res = await fetch(
        `https://login.microsoftonline.com/${encodeURIComponent(domain)}/.well-known/openid-configuration`
      );
      if (!res.ok) throw new Error(`Could not resolve domain '${domain}'`);
      const data = await res.json();
      const tenantId = data.issuer?.split("/")[3];
      if (!tenantId) throw new Error(`No tenant ID found for '${domain}'`);
      if (tenantId === MSA_TENANT_ID) {
        setDomainLookupState({
          loading: false,
          error: `'${domain}' is a consumer domain (personal Microsoft accounts), not a Microsoft 365 organization.`,
          resolvedDomain: null,
        });
        return;
      }
      setPartnerTenantId(tenantId);
      setDomainLookupState({ loading: false, error: null, resolvedDomain: domain });
    } catch (e) {
      setDomainLookupState({
        loading: false,
        error: `Could not resolve '${domain}'. Ensure this is a valid domain belonging to a Microsoft 365 organization.`,
        resolvedDomain: null,
      });
    }
  }, [domainInput]);

  const normalizeAccessSection = (section) => {
    if (!section) return null;
    const users = section.usersAndGroups;
    const apps = section.applications;
    if (!users && !apps) return null;
    return {
      usersAndGroups: users ?? { accessType: apps.accessType, targets: [{ target: "AllUsers", targetType: "user" }] },
      applications: apps ?? { accessType: users.accessType, targets: [{ target: "AllApplications", targetType: "application" }] },
    };
  };

  const executeSave = () => {
    const url = isEditing ? "/api/EditCrossTenantPartner" : "/api/ExecAddCrossTenantPartner";
    const payload = {
      tenantFilter: currentTenant,
      partnerTenantId: partnerTenantId,
      b2bCollaborationInbound: normalizeAccessSection(partnerData.b2bCollaborationInbound),
      b2bCollaborationOutbound: normalizeAccessSection(partnerData.b2bCollaborationOutbound),
      b2bDirectConnectInbound: normalizeAccessSection(partnerData.b2bDirectConnectInbound),
      b2bDirectConnectOutbound: normalizeAccessSection(partnerData.b2bDirectConnectOutbound),
      inboundTrust: partnerData.inboundTrust,
      automaticUserConsentSettings: partnerData.automaticUserConsentSettings,
    };
    savePartner.mutate({ url, data: payload });
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
          Please select a specific tenant to manage partner organizations.
        </Alert>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      <CippHead title="Partner Organization" />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
        <Box>
          <Link href="/tenant/administration/cross-tenant-access/partners" passHref>
            <Button startIcon={<ArrowBack />} size="small" sx={{ mb: 1 }}>
              Back to Partners
            </Button>
          </Link>
          <Typography variant="h4">
            {isEditing ? "Edit Partner Organization" : "Add Partner Organization"}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Configure cross-tenant access settings for a specific partner organization.
          </Typography>
        </Box>
        <Button
          variant="contained"
          startIcon={<Save />}
          onClick={handleSave}
          disabled={!partnerTenantId || savePartner.isPending}
        >
          {isEditing ? "Save Changes" : "Add Partner"}
        </Button>
      </Stack>

      <CippApiResults apiObject={savePartner} />

      <Stack spacing={3}>
        {/* Partner Tenant ID */}
        <Card>
          <CardHeader title="Partner Identification" />
          <CardContent>
            <Stack spacing={2}>
              {!isEditing && (
                <>
                  <Stack direction="row" spacing={1} alignItems="flex-start">
                    <TextField
                      label="Look up by domain"
                      value={domainInput}
                      onChange={(e) => setDomainInput(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") {
                          e.preventDefault();
                          handleDomainLookup();
                        }
                      }}
                      fullWidth
                      placeholder="e.g. oracle.com"
                      helperText="Enter a domain name to resolve its tenant ID automatically"
                      InputProps={{
                        endAdornment: domainLookupState.loading ? (
                          <InputAdornment position="end">
                            <CircularProgress size={20} />
                          </InputAdornment>
                        ) : null,
                      }}
                    />
                    <Button
                      variant="outlined"
                      onClick={handleDomainLookup}
                      disabled={!domainInput.trim() || domainLookupState.loading}
                      startIcon={<Search />}
                      sx={{ mt: "8px", minWidth: 100 }}
                    >
                      Resolve
                    </Button>
                  </Stack>
                  {domainLookupState.error && (
                    <Alert severity="error" variant="outlined">
                      {domainLookupState.error}
                    </Alert>
                  )}
                  {domainLookupState.resolvedDomain && (
                    <Alert severity="success" variant="outlined">
                      Resolved <strong>{domainLookupState.resolvedDomain}</strong> to tenant ID{" "}
                      <strong>{partnerTenantId}</strong>
                    </Alert>
                  )}
                  <Divider>or enter directly</Divider>
                </>
              )}
              <TextField
                label="Partner Tenant ID"
                value={partnerTenantId}
                onChange={(e) => setPartnerTenantId(e.target.value)}
                fullWidth
                disabled={isEditing}
                placeholder="Azure AD tenant ID (GUID)"
                helperText={isEditing ? "Tenant ID cannot be changed" : "The Azure AD tenant ID of the partner organization"}
              />
            </Stack>
          </CardContent>
        </Card>

        {/* B2B Collaboration */}
        <Card>
          <CardHeader
            title="B2B Collaboration"
            subheader="Configure guest access settings for this partner"
          />
          <CardContent>
            <AccessSettingsEditor
              title="Inbound Access"
              description="External users from this partner accessing your resources"
              settings={partnerData.b2bCollaborationInbound}
              onChange={(val) => handleFieldChange("b2bCollaborationInbound", val)}
            />
            <AccessSettingsEditor
              title="Outbound Access"
              description="Your users accessing this partner's resources as guests"
              settings={partnerData.b2bCollaborationOutbound}
              onChange={(val) => handleFieldChange("b2bCollaborationOutbound", val)}
            />
          </CardContent>
        </Card>

        {/* B2B Direct Connect */}
        <Card>
          <CardHeader
            title="B2B Direct Connect"
            subheader="Configure Teams shared channel access for this partner. Unlike B2B collaboration (guest access), direct connect users have no directory footprint in your tenant."
          />
          <CardContent>
            <AccessSettingsEditor
              title="Inbound Access"
              description="External users accessing your Teams shared channels"
              settings={partnerData.b2bDirectConnectInbound}
              onChange={(val) => handleFieldChange("b2bDirectConnectInbound", val)}
            />
            <CippRiskAlert
              visible={partnerData.b2bDirectConnectInbound?.usersAndGroups?.accessType === "allowed"}
              severity="info"
              title="Direct Connect Users Are Not Covered by Conditional Access"
              description="B2B direct connect users access shared channels without guest accounts. They are not visible in your directory and are not subject to your Conditional Access policies unless inbound trust is enabled for this partner."
              recommendation="Enable inbound trust settings below if you want your Conditional Access policies to apply to this partner's direct connect users."
            />
            <AccessSettingsEditor
              title="Outbound Access"
              description="Your users accessing this partner's shared channels"
              settings={partnerData.b2bDirectConnectOutbound}
              onChange={(val) => handleFieldChange("b2bDirectConnectOutbound", val)}
            />
          </CardContent>
        </Card>

        {/* Inbound Trust */}
        <Card>
          <CardHeader
            title="Inbound Trust Settings"
            subheader="Trust claims from this partner organization"
          />
          <CardContent>
            <Stack spacing={2}>
              <FormControlLabel
                control={
                  <Switch
                    checked={partnerData.inboundTrust?.isMfaAccepted ?? false}
                    onChange={(e) =>
                      handleFieldChange("inboundTrust", {
                        ...partnerData.inboundTrust,
                        isMfaAccepted: e.target.checked,
                      })
                    }
                  />
                }
                label="Trust multi-factor authentication from this partner"
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={partnerData.inboundTrust?.isCompliantDeviceAccepted ?? false}
                    onChange={(e) =>
                      handleFieldChange("inboundTrust", {
                        ...partnerData.inboundTrust,
                        isCompliantDeviceAccepted: e.target.checked,
                      })
                    }
                  />
                }
                label="Trust compliant devices from this partner"
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={
                      partnerData.inboundTrust?.isHybridAzureADJoinedDeviceAccepted ?? false
                    }
                    onChange={(e) =>
                      handleFieldChange("inboundTrust", {
                        ...partnerData.inboundTrust,
                        isHybridAzureADJoinedDeviceAccepted: e.target.checked,
                      })
                    }
                  />
                }
                label="Trust hybrid Azure AD joined devices from this partner"
              />
              <CippRiskAlert
                visible={
                  partnerData.inboundTrust?.isMfaAccepted === true &&
                  partnerData.inboundTrust?.isCompliantDeviceAccepted === true &&
                  partnerData.inboundTrust?.isHybridAzureADJoinedDeviceAccepted === true
                }
                severity="info"
                title="All Inbound Trust Claims Accepted"
                description="All three trust settings are enabled for this partner. You are fully trusting this partner's security posture."
                recommendation="Ensure you have verified this partner's security practices before trusting all claims."
              />
            </Stack>
          </CardContent>
        </Card>

        {/* Automatic User Consent */}
        <Card>
          <CardHeader
            title="Automatic User Consent"
            subheader="Control automatic invitation redemption for this partner"
          />
          <CardContent>
            <Stack spacing={2}>
              <FormControlLabel
                control={
                  <Switch
                    checked={partnerData.automaticUserConsentSettings?.inboundAllowed ?? false}
                    onChange={(e) =>
                      handleFieldChange("automaticUserConsentSettings", {
                        ...partnerData.automaticUserConsentSettings,
                        inboundAllowed: e.target.checked,
                      })
                    }
                  />
                }
                label="Automatically redeem invitations for inbound users"
              />
              <CippRiskAlert
                visible={partnerData.automaticUserConsentSettings?.inboundAllowed === true}
                severity="warning"
                title="Automatic Inbound Consent Enabled"
                description="Inbound invitations from this partner are auto-redeemed without user consent prompts."
                recommendation="Disable unless you have a specific cross-tenant sync agreement with this partner."
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={partnerData.automaticUserConsentSettings?.outboundAllowed ?? false}
                    onChange={(e) =>
                      handleFieldChange("automaticUserConsentSettings", {
                        ...partnerData.automaticUserConsentSettings,
                        outboundAllowed: e.target.checked,
                      })
                    }
                  />
                }
                label="Automatically redeem invitations for outbound users"
              />
              <CippRiskAlert
                visible={partnerData.automaticUserConsentSettings?.outboundAllowed === true}
                severity="warning"
                title="Automatic Outbound Consent Enabled"
                description="Your users' invitations to this partner are auto-redeemed without an explicit consent step."
                recommendation="Disable unless you have a specific cross-tenant sync agreement with this partner."
              />
            </Stack>
          </CardContent>
        </Card>
      </Stack>

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
