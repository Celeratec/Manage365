import { useEffect, useState, useMemo } from "react";
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
  Chip,
  Divider,
  FormControl,
  FormControlLabel,
  FormLabel,
  Grid,
  MenuItem,
  Radio,
  RadioGroup,
  Stack,
  Switch,
  TextField,
  Typography,
} from "@mui/material";
import { ArrowBack, Save } from "@mui/icons-material";
import { ApiGetCall, ApiPostCall } from "../../../../../api/ApiCall.jsx";
import { CippApiResults } from "../../../../../components/CippComponents/CippApiResults.jsx";
import CippRiskAlert from "../../../../../components/CippComponents/CippRiskAlert.jsx";
import CippRiskSummaryDialog from "../../../../../components/CippComponents/CippRiskSummaryDialog.jsx";
import Link from "next/link";

const AccessSettingsEditor = ({ title, description, settings, onChange }) => {
  const usersAccessType = settings?.usersAndGroups?.accessType ?? "allowed";
  const appsAccessType = settings?.applications?.accessType ?? "allowed";

  return (
    <Card variant="outlined" sx={{ mb: 2 }}>
      <CardHeader title={title} subheader={description} titleTypographyProps={{ variant: "subtitle1" }} />
      <CardContent>
        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <FormControl component="fieldset">
              <FormLabel>Users & Groups</FormLabel>
              <RadioGroup
                value={usersAccessType}
                onChange={(e) =>
                  onChange({
                    ...settings,
                    usersAndGroups: {
                      ...settings?.usersAndGroups,
                      accessType: e.target.value,
                      targets: [{ target: "AllUsers", targetType: "user" }],
                    },
                  })
                }
              >
                <FormControlLabel value="allowed" control={<Radio size="small" />} label="Allow" />
                <FormControlLabel value="blocked" control={<Radio size="small" />} label="Block" />
              </RadioGroup>
            </FormControl>
          </Grid>
          <Grid item xs={12} md={6}>
            <FormControl component="fieldset">
              <FormLabel>Applications</FormLabel>
              <RadioGroup
                value={appsAccessType}
                onChange={(e) =>
                  onChange({
                    ...settings,
                    applications: {
                      ...settings?.applications,
                      accessType: e.target.value,
                      targets: [{ target: "AllApplications", targetType: "application" }],
                    },
                  })
                }
              >
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

const DomainListEditor = ({ title, domains, onChange }) => {
  const [newDomain, setNewDomain] = useState("");

  const handleAdd = () => {
    if (newDomain && !domains.includes(newDomain)) {
      onChange([...domains, newDomain.toLowerCase().trim()]);
      setNewDomain("");
    }
  };

  return (
    <Box>
      <Typography variant="subtitle2" sx={{ mb: 1 }}>
        {title}
      </Typography>
      <Stack direction="row" spacing={1} sx={{ mb: 1 }}>
        <TextField
          size="small"
          value={newDomain}
          onChange={(e) => setNewDomain(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              handleAdd();
            }
          }}
          placeholder="example.com"
          fullWidth
        />
        <Button variant="outlined" onClick={handleAdd}>
          Add
        </Button>
      </Stack>
      <Stack direction="row" flexWrap="wrap" gap={1}>
        {domains.map((domain) => (
          <Chip
            key={domain}
            label={domain}
            onDelete={() => onChange(domains.filter((d) => d !== domain))}
            size="small"
            variant="outlined"
          />
        ))}
      </Stack>
    </Box>
  );
};

const TEMPLATE_RISK_RULES = [
  {
    id: "invites-everyone",
    test: (d) => d.settings.allowInvitesFrom === "everyone",
    severity: "error",
    title: "High Risk — Unrestricted Guest Invitations",
    description:
      "Anyone, including existing guests, can invite additional guests. This template will enable uncontrolled transitive guest access on every tenant it is applied to.",
    recommendation:
      'Set to "Admins + Guest Inviter role" or "Members + Admins" to maintain invitation oversight.',
  },
  {
    id: "guest-member-access",
    test: (d) => d.settings.guestUserRoleId === "a0b1b346-4d3e-4e8b-98f8-753987be4970",
    severity: "error",
    title: "High Risk — Guests Have Full Member Access",
    description:
      "Guest users will have the same directory permissions as members, including the ability to enumerate all users and groups. This applies to every tenant using this template.",
    recommendation:
      'Set to "Limited access" (default) or "Restricted access" to prevent directory enumeration by external users.',
  },
  {
    id: "email-verified-join",
    test: (d) => d.settings.allowEmailVerifiedUsersToJoinOrganization === true,
    severity: "warning",
    title: "Self-Service Join Enabled",
    description:
      "Anyone with a verified email can self-register into tenant directories using this template.",
    recommendation: "Disable unless specifically required for a self-service workflow.",
  },
  {
    id: "no-domain-restrictions",
    test: (d) => d.domainRestrictionType === "none",
    severity: "warning",
    title: "No Domain Restrictions",
    description:
      "This template has no domain restrictions on guest invitations. Tenants using it will allow guests from any domain.",
    recommendation: "Use an allow-list of trusted partner domains.",
  },
  {
    id: "msn-allowed",
    test: (d) => d.settings.blockMsnSignIn === false,
    severity: "info",
    title: "Personal Microsoft Accounts Allowed",
    description:
      "This template allows personal Microsoft account sign-in. These accounts lack enterprise security controls.",
    recommendation: "Enable the MSN block if personal accounts are not needed.",
  },
  {
    id: "auto-consent-inbound",
    test: (d) => d.settings.automaticUserConsentSettings?.inboundAllowed === true,
    severity: "warning",
    title: "Automatic Inbound Consent Enabled",
    description:
      "Inbound invitations will be auto-redeemed without user consent prompts on every tenant using this template.",
    recommendation: "Disable unless a cross-tenant sync agreement requires auto-redemption.",
  },
  {
    id: "auto-consent-outbound",
    test: (d) => d.settings.automaticUserConsentSettings?.outboundAllowed === true,
    severity: "warning",
    title: "Automatic Outbound Consent Enabled",
    description:
      "Outbound invitations will be auto-redeemed on every tenant using this template.",
    recommendation: "Disable unless a cross-tenant sync agreement requires auto-redemption.",
  },
  {
    id: "all-trust-enabled",
    test: (d) =>
      d.settings.inboundTrust?.isMfaAccepted === true &&
      d.settings.inboundTrust?.isCompliantDeviceAccepted === true &&
      d.settings.inboundTrust?.isHybridAzureADJoinedDeviceAccepted === true,
    severity: "info",
    title: "All Inbound Trust Claims Accepted",
    description:
      "All three trust settings are enabled. Tenants using this template will accept all security claims from every external organization.",
    recommendation:
      "Consider enabling trust only for specific partners via per-partner policies rather than in the defaults.",
  },
];

const Page = () => {
  const router = useRouter();
  const { GUID: editGUID } = router.query;
  const isEditing = !!editGUID;

  const [templateName, setTemplateName] = useState("");
  const [riskDialogOpen, setRiskDialogOpen] = useState(false);
  const [description, setDescription] = useState("");
  const [settings, setSettings] = useState({
    b2bCollaborationInbound: null,
    b2bCollaborationOutbound: null,
    b2bDirectConnectInbound: null,
    b2bDirectConnectOutbound: null,
    inboundTrust: {
      isMfaAccepted: false,
      isCompliantDeviceAccepted: false,
      isHybridAzureADJoinedDeviceAccepted: false,
    },
    tenantRestrictions: null,
    automaticUserConsentSettings: {
      inboundAllowed: false,
      outboundAllowed: false,
    },
    allowInvitesFrom: "adminsAndGuestInviters",
    guestUserRoleId: "10dae51f-b6af-4016-8d66-8c2a99b929b3",
    allowedToSignUpEmailBasedSubscriptions: true,
    allowEmailVerifiedUsersToJoinOrganization: false,
    blockMsnSignIn: false,
    domainRestrictions: null,
  });
  const [domainRestrictionType, setDomainRestrictionType] = useState("none");
  const [allowedDomains, setAllowedDomains] = useState([]);
  const [blockedDomains, setBlockedDomains] = useState([]);

  const activeRisks = useMemo(() => {
    const riskContext = { settings, domainRestrictionType };
    return TEMPLATE_RISK_RULES.filter((r) => r.test(riskContext)).map(({ test, ...rest }) => rest);
  }, [settings, domainRestrictionType]);

  const templatesQuery = ApiGetCall({
    url: "/api/ListCrossTenantTemplates",
    queryKey: "CrossTenantTemplates",
    waiting: isEditing,
  });

  const saveTemplate = ApiPostCall({
    relatedQueryKeys: ["CrossTenantTemplates"],
  });

  useEffect(() => {
    if (isEditing && templatesQuery.data?.Results) {
      const existing = templatesQuery.data.Results.find((t) => t.GUID === editGUID);
      if (existing) {
        setTemplateName(existing.templateName);
        setDescription(existing.description ?? "");
        if (existing.settings) {
          setSettings(existing.settings);
          // Parse domain restrictions
          const dr = existing.settings.domainRestrictions;
          if (dr?.InvitationsAllowedAndBlockedDomainsPolicy?.BlockedDomains?.length > 0) {
            setDomainRestrictionType("blocklist");
            setBlockedDomains(dr.InvitationsAllowedAndBlockedDomainsPolicy.BlockedDomains);
          } else if (dr?.InvitationsAllowedAndBlockedDomainsPolicy?.AllowedDomains?.length > 0) {
            setDomainRestrictionType("allowlist");
            setAllowedDomains(dr.InvitationsAllowedAndBlockedDomainsPolicy.AllowedDomains);
          }
        }
      }
    }
  }, [templatesQuery.data, editGUID]);

  const handleSettingsChange = (field, value) => {
    setSettings((prev) => ({
      ...prev,
      [field]: value,
    }));
  };

  const executeSave = () => {
    const finalSettings = { ...settings };

    // Build domain restrictions
    if (domainRestrictionType === "allowlist" && allowedDomains.length > 0) {
      finalSettings.domainRestrictions = {
        InvitationsAllowedAndBlockedDomainsPolicy: {
          AllowedDomains: allowedDomains,
          BlockedDomains: [],
        },
      };
    } else if (domainRestrictionType === "blocklist" && blockedDomains.length > 0) {
      finalSettings.domainRestrictions = {
        InvitationsAllowedAndBlockedDomainsPolicy: {
          AllowedDomains: [],
          BlockedDomains: blockedDomains,
        },
      };
    } else {
      finalSettings.domainRestrictions = null;
    }

    saveTemplate.mutate({
      url: "/api/ExecAddCrossTenantTemplate",
      data: {
        GUID: editGUID ?? undefined,
        templateName,
        description,
        settings: finalSettings,
      },
    });
  };

  const handleSave = () => {
    const significantRisks = activeRisks.filter((r) => r.severity !== "info");
    if (significantRisks.length > 0) {
      setRiskDialogOpen(true);
    } else {
      executeSave();
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <CippHead title="Security Baseline Template" noTenant />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
        <Box>
          <Link href="/tenant/administration/cross-tenant-access/templates" passHref>
            <Button startIcon={<ArrowBack />} size="small" sx={{ mb: 1 }}>
              Back to Templates
            </Button>
          </Link>
          <Typography variant="h4">
            {isEditing ? "Edit Security Template" : "Create Security Template"}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Define a cross-tenant access security baseline that can be applied to any tenant.
          </Typography>
        </Box>
        <Button
          variant="contained"
          startIcon={<Save />}
          onClick={handleSave}
          disabled={!templateName || saveTemplate.isPending}
        >
          {isEditing ? "Save Template" : "Create Template"}
        </Button>
      </Stack>

      <CippApiResults apiObject={saveTemplate} />

      <Stack spacing={3}>
        {/* Template Info */}
        <Card>
          <CardHeader title="Template Information" />
          <CardContent>
            <Stack spacing={2}>
              <TextField
                label="Template Name"
                value={templateName}
                onChange={(e) => setTemplateName(e.target.value)}
                fullWidth
                required
                placeholder="e.g., MSP Restrictive Baseline"
              />
              <TextField
                label="Description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                fullWidth
                multiline
                rows={2}
                placeholder="Describe the purpose and security posture of this template"
              />
            </Stack>
          </CardContent>
        </Card>

        {/* B2B Collaboration */}
        <Card>
          <CardHeader
            title="B2B Collaboration Defaults"
            subheader="Guest access settings for the cross-tenant access policy"
          />
          <CardContent>
            <AccessSettingsEditor
              title="Inbound (External users accessing tenant)"
              description=""
              settings={settings.b2bCollaborationInbound}
              onChange={(val) => handleSettingsChange("b2bCollaborationInbound", val)}
            />
            <AccessSettingsEditor
              title="Outbound (Users accessing external tenants)"
              description=""
              settings={settings.b2bCollaborationOutbound}
              onChange={(val) => handleSettingsChange("b2bCollaborationOutbound", val)}
            />
          </CardContent>
        </Card>

        {/* B2B Direct Connect */}
        <Card>
          <CardHeader
            title="B2B Direct Connect Defaults"
            subheader="Teams shared channel settings"
          />
          <CardContent>
            <AccessSettingsEditor
              title="Inbound"
              description=""
              settings={settings.b2bDirectConnectInbound}
              onChange={(val) => handleSettingsChange("b2bDirectConnectInbound", val)}
            />
            <AccessSettingsEditor
              title="Outbound"
              description=""
              settings={settings.b2bDirectConnectOutbound}
              onChange={(val) => handleSettingsChange("b2bDirectConnectOutbound", val)}
            />
          </CardContent>
        </Card>

        {/* Inbound Trust */}
        <Card>
          <CardHeader title="Inbound Trust Settings" />
          <CardContent>
            <Stack spacing={1}>
              <FormControlLabel
                control={
                  <Switch
                    checked={settings.inboundTrust?.isMfaAccepted ?? false}
                    onChange={(e) =>
                      handleSettingsChange("inboundTrust", {
                        ...settings.inboundTrust,
                        isMfaAccepted: e.target.checked,
                      })
                    }
                  />
                }
                label="Trust external MFA"
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={settings.inboundTrust?.isCompliantDeviceAccepted ?? false}
                    onChange={(e) =>
                      handleSettingsChange("inboundTrust", {
                        ...settings.inboundTrust,
                        isCompliantDeviceAccepted: e.target.checked,
                      })
                    }
                  />
                }
                label="Trust compliant devices"
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={settings.inboundTrust?.isHybridAzureADJoinedDeviceAccepted ?? false}
                    onChange={(e) =>
                      handleSettingsChange("inboundTrust", {
                        ...settings.inboundTrust,
                        isHybridAzureADJoinedDeviceAccepted: e.target.checked,
                      })
                    }
                  />
                }
                label="Trust hybrid Azure AD joined devices"
              />
              <CippRiskAlert
                visible={
                  settings.inboundTrust?.isMfaAccepted === true &&
                  settings.inboundTrust?.isCompliantDeviceAccepted === true &&
                  settings.inboundTrust?.isHybridAzureADJoinedDeviceAccepted === true
                }
                severity="info"
                title="All Inbound Trust Claims Accepted"
                description="All three trust settings are enabled. Tenants using this template will accept all security claims from every external organization."
                recommendation="Consider enabling trust only for specific partners via per-partner policies."
              />
            </Stack>
          </CardContent>
        </Card>

        {/* Automatic Consent */}
        <Card>
          <CardHeader title="Automatic User Consent" />
          <CardContent>
            <Stack spacing={1}>
              <FormControlLabel
                control={
                  <Switch
                    checked={settings.automaticUserConsentSettings?.inboundAllowed ?? false}
                    onChange={(e) =>
                      handleSettingsChange("automaticUserConsentSettings", {
                        ...settings.automaticUserConsentSettings,
                        inboundAllowed: e.target.checked,
                      })
                    }
                  />
                }
                label="Automatically redeem inbound invitations"
              />
              <CippRiskAlert
                visible={settings.automaticUserConsentSettings?.inboundAllowed === true}
                severity="warning"
                title="Automatic Inbound Consent Enabled"
                description="Inbound invitations will be auto-redeemed without user consent on every tenant using this template."
                recommendation="Disable unless a cross-tenant sync agreement requires auto-redemption."
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={settings.automaticUserConsentSettings?.outboundAllowed ?? false}
                    onChange={(e) =>
                      handleSettingsChange("automaticUserConsentSettings", {
                        ...settings.automaticUserConsentSettings,
                        outboundAllowed: e.target.checked,
                      })
                    }
                  />
                }
                label="Automatically redeem outbound invitations"
              />
              <CippRiskAlert
                visible={settings.automaticUserConsentSettings?.outboundAllowed === true}
                severity="warning"
                title="Automatic Outbound Consent Enabled"
                description="Outbound invitations will be auto-redeemed on every tenant using this template."
                recommendation="Disable unless a cross-tenant sync agreement requires auto-redemption."
              />
            </Stack>
          </CardContent>
        </Card>

        {/* External Collaboration */}
        <Card>
          <CardHeader
            title="External Collaboration Settings"
            subheader="Guest invite and access settings"
          />
          <CardContent>
            <Stack spacing={3}>
              <TextField
                select
                fullWidth
                label="Guest invite restrictions"
                InputLabelProps={{ shrink: true }}
                value={settings.allowInvitesFrom ?? "adminsAndGuestInviters"}
                onChange={(e) => handleSettingsChange("allowInvitesFrom", e.target.value)}
              >
                <MenuItem value="none">No one can invite guests</MenuItem>
                <MenuItem value="adminsAndGuestInviters">Admins + Guest Inviter role</MenuItem>
                <MenuItem value="adminsGuestInvitersAndAllMembers">Members + Admins</MenuItem>
                <MenuItem value="everyone">Anyone including guests</MenuItem>
              </TextField>
              <CippRiskAlert
                visible={settings.allowInvitesFrom === "everyone"}
                severity="error"
                title="High Risk — Unrestricted Guest Invitations"
                description="Anyone, including existing guests, can invite additional guests. This template will enable uncontrolled transitive access on every tenant it is applied to."
                recommendation='Set to "Admins + Guest Inviter role" or "Members + Admins" to maintain invitation oversight.'
              />

              <TextField
                select
                fullWidth
                label="Guest user access level"
                InputLabelProps={{ shrink: true }}
                value={
                  settings.guestUserRoleId ?? "10dae51f-b6af-4016-8d66-8c2a99b929b3"
                }
                onChange={(e) => handleSettingsChange("guestUserRoleId", e.target.value)}
              >
                <MenuItem value="a0b1b346-4d3e-4e8b-98f8-753987be4970">
                  Same as members
                </MenuItem>
                <MenuItem value="10dae51f-b6af-4016-8d66-8c2a99b929b3">
                  Limited access (default)
                </MenuItem>
                <MenuItem value="2af84b1e-32c8-42b7-82bc-daa82404023b">
                  Restricted access
                </MenuItem>
              </TextField>
              <CippRiskAlert
                visible={settings.guestUserRoleId === "a0b1b346-4d3e-4e8b-98f8-753987be4970"}
                severity="error"
                title="High Risk — Guests Have Full Member Access"
                description="Guest users will have the same directory permissions as members on every tenant using this template."
                recommendation='Set to "Limited access" (default) or "Restricted access" to prevent directory enumeration.'
              />

              <Stack spacing={1}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.allowedToSignUpEmailBasedSubscriptions ?? true}
                      onChange={(e) =>
                        handleSettingsChange(
                          "allowedToSignUpEmailBasedSubscriptions",
                          e.target.checked
                        )
                      }
                    />
                  }
                  label="Allow email-based subscriptions"
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.allowEmailVerifiedUsersToJoinOrganization ?? false}
                      onChange={(e) =>
                        handleSettingsChange(
                          "allowEmailVerifiedUsersToJoinOrganization",
                          e.target.checked
                        )
                      }
                    />
                  }
                  label="Allow email-verified users to join"
                />
                <CippRiskAlert
                  visible={settings.allowEmailVerifiedUsersToJoinOrganization === true}
                  severity="warning"
                  title="Self-Service Join Enabled"
                  description="Anyone with a verified email can self-register into tenant directories using this template."
                  recommendation="Disable unless specifically required for a self-service workflow."
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.blockMsnSignIn ?? false}
                      onChange={(e) => handleSettingsChange("blockMsnSignIn", e.target.checked)}
                    />
                  }
                  label="Block MSN sign-in"
                />
                <CippRiskAlert
                  visible={settings.blockMsnSignIn === false}
                  severity="info"
                  title="Personal Microsoft Accounts Allowed"
                  description="This template allows personal Microsoft account sign-in. These accounts lack enterprise security controls."
                  recommendation="Enable the MSN block if personal accounts are not needed."
                />
              </Stack>
            </Stack>
          </CardContent>
        </Card>

        {/* Domain Restrictions */}
        <Card>
          <CardHeader
            title="Domain Restrictions"
            subheader="Control which domains can be invited"
          />
          <CardContent>
            <Stack spacing={2}>
              <FormControl component="fieldset">
                <RadioGroup
                  value={domainRestrictionType}
                  onChange={(e) => setDomainRestrictionType(e.target.value)}
                >
                  <FormControlLabel value="none" control={<Radio />} label="No restrictions" />
                  <FormControlLabel
                    value="allowlist"
                    control={<Radio />}
                    label="Allow only specified domains"
                  />
                  <FormControlLabel
                    value="blocklist"
                    control={<Radio />}
                    label="Block specified domains"
                  />
                </RadioGroup>
              </FormControl>
              <CippRiskAlert
                visible={domainRestrictionType === "none"}
                severity="warning"
                title="No Domain Restrictions"
                description="This template has no domain restrictions. Tenants using it will allow guest invitations from any domain."
                recommendation="Use an allow-list of trusted partner domains."
              />

              {domainRestrictionType === "allowlist" && (
                <DomainListEditor
                  title="Allowed Domains"
                  domains={allowedDomains}
                  onChange={setAllowedDomains}
                />
              )}

              {domainRestrictionType === "blocklist" && (
                <DomainListEditor
                  title="Blocked Domains"
                  domains={blockedDomains}
                  onChange={setBlockedDomains}
                />
              )}
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
