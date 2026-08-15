import { useEffect, useState, useMemo } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippHead } from "../../../../components/CippComponents/CippHead.jsx";
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
  Grid,
  IconButton,
  MenuItem,
  Radio,
  RadioGroup,
  Skeleton,
  Stack,
  Switch,
  TextField,
  Typography,
} from "@mui/material";
import { Add, Delete, Save } from "@mui/icons-material";
import { useSettings } from "../../../../hooks/use-settings.js";
import { ApiGetCall, ApiPostCall } from "../../../../api/ApiCall.jsx";
import { CippApiResults } from "../../../../components/CippComponents/CippApiResults.jsx";
import CippRelatedSettings from "../../../../components/CippComponents/CippRelatedSettings.jsx";
import CippRiskAlert from "../../../../components/CippComponents/CippRiskAlert.jsx";
import CippRiskSummaryDialog from "../../../../components/CippComponents/CippRiskSummaryDialog.jsx";
import CippAccessTypeGuide from "../../../../components/CippComponents/CippAccessTypeGuide";

const DomainListEditor = ({ title, domains, onChange }) => {
  const [newDomain, setNewDomain] = useState("");

  const handleAdd = () => {
    if (newDomain && !domains.includes(newDomain)) {
      onChange([...domains, newDomain.toLowerCase().trim()]);
      setNewDomain("");
    }
  };

  const handleRemove = (domain) => {
    onChange(domains.filter((d) => d !== domain));
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleAdd();
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
          onKeyDown={handleKeyDown}
          placeholder="example.com"
          fullWidth
        />
        <Button variant="outlined" onClick={handleAdd} startIcon={<Add />}>
          Add
        </Button>
      </Stack>
      <Stack direction="row" flexWrap="wrap" gap={1}>
        {domains.map((domain) => (
          <Chip
            key={domain}
            label={domain}
            onDelete={() => handleRemove(domain)}
            size="small"
            variant="outlined"
          />
        ))}
        {domains.length === 0 && (
          <Typography variant="body2" color="text.secondary">
            No domains configured
          </Typography>
        )}
      </Stack>
    </Box>
  );
};

const RISK_RULES = [
  {
    id: "invites-everyone",
    test: (d) => d.allowInvitesFrom === "everyone",
    severity: "error",
    title: "High Risk — Unrestricted Guest Invitations",
    description:
      "Anyone, including existing guest users, can invite additional guests. This creates uncontrolled transitive access where external users bring in more external users.",
    recommendation:
      'Set to "Only admins and Guest Inviter role" or "Member users and admins" to maintain invitation oversight.',
  },
  {
    id: "guest-member-access",
    test: (d) => d.guestUserRoleId === "a0b1b346-4d3e-4e8b-98f8-753987be4970",
    severity: "error",
    title: "High Risk — Guests Have Full Member Access",
    description:
      "Guest users have the same directory permissions as member users, including the ability to enumerate all users, groups, and other directory objects.",
    recommendation:
      'Set to "Limited access" (default) or "Restricted access" to prevent directory enumeration by external users.',
  },
  {
    id: "email-verified-join",
    test: (d) => d.allowEmailVerifiedUsersToJoinOrganization === true,
    severity: "warning",
    title: "Self-Service Join Enabled",
    description:
      "Anyone with a verified email address can self-register into this directory without an admin invitation. This may add unintended accounts to the tenant.",
    recommendation: "Disable unless specifically required for a self-service workflow.",
  },
  {
    id: "no-domain-restrictions",
    test: (d) => d.domainRestrictionType === "none",
    severity: "warning",
    title: "No Domain Restrictions",
    description:
      "Guest invitations are allowed from any email domain. Without restrictions, users can invite guests from any organization, including competitors or untrusted entities.",
    recommendation:
      "Use an allow-list of trusted partner domains to limit which organizations can be invited.",
  },
  {
    id: "msn-allowed",
    test: (d) => d.blockMsnSignIn === false,
    severity: "info",
    title: "Personal Microsoft Accounts Allowed",
    description:
      "Users can sign in with personal Microsoft accounts (MSN, Hotmail, Outlook.com). These accounts are not managed by any organization and lack enterprise security controls.",
    recommendation: "Enable the MSN block if personal accounts are not needed for this tenant.",
  },
];

const Page = () => {
  const settings = useSettings();
  const currentTenant = settings.currentTenant;
  const [formData, setFormData] = useState(null);
  const [hasChanges, setHasChanges] = useState(false);
  const [riskDialogOpen, setRiskDialogOpen] = useState(false);

  const activeRisks = useMemo(() => {
    if (!formData) return [];
    return RISK_RULES.filter((r) => r.test(formData)).map(({ test, ...rest }) => rest);
  }, [formData]);

  const collabQuery = ApiGetCall({
    url: "/api/ListExternalCollaboration",
    data: { tenantFilter: currentTenant },
    queryKey: `ExternalCollaboration-${currentTenant}`,
    waiting: true,
  });

  const updateCollab = ApiPostCall({
    relatedQueryKeys: [
      `ExternalCollaboration-${currentTenant}`,
      `CrossTenantHealth-${currentTenant}`,
    ],
  });

  useEffect(() => {
    if (currentTenant) {
      collabQuery.refetch();
    }
  }, [currentTenant]);

  useEffect(() => {
    if (collabQuery.data?.Results && !formData) {
      const data = collabQuery.data.Results;
      setFormData({
        allowInvitesFrom: data.allowInvitesFrom ?? "adminsAndGuestInviters",
        guestUserRoleId: data.guestUserRoleId ?? "10dae51f-b6af-4016-8d66-8c2a99b929b3",
        allowedToSignUpEmailBasedSubscriptions:
          data.allowedToSignUpEmailBasedSubscriptions ?? true,
        allowEmailVerifiedUsersToJoinOrganization:
          data.allowEmailVerifiedUsersToJoinOrganization ?? false,
        blockMsnSignIn: data.blockMsnSignIn ?? false,
        domainRestrictionType:
          data.domainRestrictions?.InvitationsAllowedAndBlockedDomainsPolicy?.BlockedDomains
            ?.length > 0
            ? "blocklist"
            : data.domainRestrictions?.InvitationsAllowedAndBlockedDomainsPolicy?.AllowedDomains
                  ?.length > 0
              ? "allowlist"
              : "none",
        allowedDomains:
          data.domainRestrictions?.InvitationsAllowedAndBlockedDomainsPolicy?.AllowedDomains ?? [],
        blockedDomains:
          data.domainRestrictions?.InvitationsAllowedAndBlockedDomainsPolicy?.BlockedDomains ?? [],
      });
    }
  }, [collabQuery.data]);

  const handleFieldChange = (field, value) => {
    setFormData((prev) => ({
      ...prev,
      [field]: value,
    }));
    setHasChanges(true);
  };

  const executeSave = () => {
    const payload = {
      tenantFilter: currentTenant,
      allowInvitesFrom: formData.allowInvitesFrom,
      guestUserRoleId: formData.guestUserRoleId,
      allowedToSignUpEmailBasedSubscriptions: formData.allowedToSignUpEmailBasedSubscriptions,
      allowEmailVerifiedUsersToJoinOrganization:
        formData.allowEmailVerifiedUsersToJoinOrganization,
      blockMsnSignIn: formData.blockMsnSignIn,
    };

    // Include domain restrictions if configured
    if (formData.domainRestrictionType !== "none") {
      payload.domainRestrictions = {
        InvitationsAllowedAndBlockedDomainsPolicy: {
          AllowedDomains:
            formData.domainRestrictionType === "allowlist" ? formData.allowedDomains : [],
          BlockedDomains:
            formData.domainRestrictionType === "blocklist" ? formData.blockedDomains : [],
        },
      };
    }

    updateCollab.mutate({
      url: "/api/EditExternalCollaboration",
      data: payload,
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
          Please select a specific tenant to manage external collaboration settings.
        </Alert>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      <CippHead title="External Collaboration Settings" />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            External Collaboration Settings
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Manage guest invitation permissions, guest user access levels, and domain allow/deny
            lists.
          </Typography>
        </Box>
        <Button
          variant="contained"
          startIcon={<Save />}
          onClick={handleSave}
          disabled={!hasChanges || updateCollab.isPending}
        >
          Save Changes
        </Button>
      </Stack>

      <CippApiResults apiObject={updateCollab} />
      <CippAccessTypeGuide
        type="guest"
        variant="banner"
        context="externalCollaboration"
      />

      {collabQuery.isFetching ? (
        <Skeleton variant="rectangular" height={400} />
      ) : formData ? (
        <Stack spacing={3}>
          {/* Guest Invite Settings */}
          <Card>
            <CardHeader
              title="Guest Invite Settings"
              subheader="Control who can invite guest users to the organization"
            />
            <CardContent>
              <TextField
                select
                fullWidth
                label="Guest invite restrictions"
                InputLabelProps={{ shrink: true }}
                value={formData.allowInvitesFrom}
                onChange={(e) => handleFieldChange("allowInvitesFrom", e.target.value)}
              >
                <MenuItem value="none">
                  No one in the organization can invite guests (most restrictive)
                </MenuItem>
                <MenuItem value="adminsAndGuestInviters">
                  Only admins and users in the Guest Inviter role can invite
                </MenuItem>
                <MenuItem value="adminsGuestInvitersAndAllMembers">
                  Member users and admins can invite
                </MenuItem>
                <MenuItem value="everyone">
                  Anyone can invite, including guests (least restrictive)
                </MenuItem>
              </TextField>
              <CippRiskAlert
                visible={formData.allowInvitesFrom === "everyone"}
                severity="error"
                title="High Risk — Unrestricted Guest Invitations"
                description="Anyone, including existing guest users, can invite additional guests. This creates uncontrolled transitive access."
                recommendation='Set to "Only admins and Guest Inviter role" or "Member users and admins" to maintain invitation oversight.'
              />
            </CardContent>
          </Card>

          {/* Guest User Permissions */}
          <Card>
            <CardHeader
              title="Guest User Access"
              subheader="Set the default access level for guest users"
            />
            <CardContent>
              <FormControl component="fieldset">
                <RadioGroup
                  value={formData.guestUserRoleId}
                  onChange={(e) => handleFieldChange("guestUserRoleId", e.target.value)}
                >
                  <FormControlLabel
                    value="a0b1b346-4d3e-4e8b-98f8-753987be4970"
                    control={<Radio />}
                    label={
                      <Box>
                        <Typography variant="body1">Same access as member users</Typography>
                        <Typography variant="body2" color="text.secondary">
                          Guests have the same access to directory data as regular member users
                        </Typography>
                      </Box>
                    }
                  />
                  <FormControlLabel
                    value="10dae51f-b6af-4016-8d66-8c2a99b929b3"
                    control={<Radio />}
                    label={
                      <Box>
                        <Typography variant="body1">Limited access (default)</Typography>
                        <Typography variant="body2" color="text.secondary">
                          Guests can see membership of all non-hidden groups
                        </Typography>
                      </Box>
                    }
                  />
                  <FormControlLabel
                    value="2af84b1e-32c8-42b7-82bc-daa82404023b"
                    control={<Radio />}
                    label={
                      <Box>
                        <Typography variant="body1">
                          Restricted access (most restrictive)
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          Guests can only see their own profile and enumeration of users and groups
                          is blocked
                        </Typography>
                      </Box>
                    }
                  />
                </RadioGroup>
              </FormControl>
              <CippRiskAlert
                visible={formData.guestUserRoleId === "a0b1b346-4d3e-4e8b-98f8-753987be4970"}
                severity="error"
                title="High Risk — Guests Have Full Member Access"
                description="Guest users have the same directory permissions as members, including the ability to enumerate all users, groups, and other directory objects."
                recommendation='Set to "Limited access" (default) or "Restricted access" to prevent directory enumeration by external users.'
              />
            </CardContent>
          </Card>

          {/* Additional Settings */}
          <Card>
            <CardHeader
              title="Additional External User Settings"
              subheader="Configure email-based subscription and sign-in options"
            />
            <CardContent>
              <Stack spacing={2}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={formData.allowedToSignUpEmailBasedSubscriptions}
                      onChange={(e) =>
                        handleFieldChange(
                          "allowedToSignUpEmailBasedSubscriptions",
                          e.target.checked
                        )
                      }
                    />
                  }
                  label="Allow email-based subscriptions (self-service sign-up)"
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={formData.allowEmailVerifiedUsersToJoinOrganization}
                      onChange={(e) =>
                        handleFieldChange(
                          "allowEmailVerifiedUsersToJoinOrganization",
                          e.target.checked
                        )
                      }
                    />
                  }
                  label="Allow email-verified users to join the organization"
                />
                <CippRiskAlert
                  visible={formData.allowEmailVerifiedUsersToJoinOrganization === true}
                  severity="warning"
                  title="Self-Service Join Enabled"
                  description="Anyone with a verified email address can self-register into this directory without an admin invitation."
                  recommendation="Disable unless specifically required for a self-service workflow."
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={formData.blockMsnSignIn}
                      onChange={(e) => handleFieldChange("blockMsnSignIn", e.target.checked)}
                    />
                  }
                  label="Block MSN sign-in (personal Microsoft accounts)"
                />
                <CippRiskAlert
                  visible={formData.blockMsnSignIn === false}
                  severity="info"
                  title="Personal Microsoft Accounts Allowed"
                  description="Users can sign in with personal Microsoft accounts (Hotmail, Outlook.com). These accounts lack enterprise security controls."
                  recommendation="Enable the MSN block if personal accounts are not needed for this tenant."
                />
              </Stack>
            </CardContent>
          </Card>

          {/* Domain Restrictions */}
          <Card>
            <CardHeader
              title="Collaboration Restrictions"
              subheader="Control which domains can be invited for B2B collaboration"
            />
            <CardContent sx={{ pt: 0, pb: 0 }}>
              <CippRelatedSettings
                title="SharePoint has a separate domain list"
                description="These domain restrictions apply to Entra B2B guest invitations across all Microsoft 365 services. SharePoint and OneDrive have their own separate domain allow/deny list. If guests can be invited but cannot access SharePoint, check SharePoint Sharing Settings."
                links={[
                  {
                    label: "SharePoint Sharing Settings",
                    href: "/teams-share/sharepoint/sharing-settings",
                  },
                  {
                    label: "Cross-Tenant Default Policy",
                    href: "/tenant/administration/cross-tenant-access/policy",
                  },
                ]}
              />
            </CardContent>
            <CardContent>
              <Stack spacing={3}>
                <FormControl component="fieldset">
                  <RadioGroup
                    value={formData.domainRestrictionType}
                    onChange={(e) => handleFieldChange("domainRestrictionType", e.target.value)}
                  >
                    <FormControlLabel
                      value="none"
                      control={<Radio />}
                      label="Allow invitations to any domain (no restrictions)"
                    />
                    <FormControlLabel
                      value="allowlist"
                      control={<Radio />}
                      label="Allow invitations only to specified domains (most restrictive)"
                    />
                    <FormControlLabel
                      value="blocklist"
                      control={<Radio />}
                      label="Deny invitations to specified domains"
                    />
                  </RadioGroup>
                </FormControl>
                <CippRiskAlert
                  visible={formData.domainRestrictionType === "none"}
                  severity="warning"
                  title="No Domain Restrictions"
                  description="Guest invitations are allowed from any email domain. Users can invite guests from any organization, including competitors or untrusted entities."
                  recommendation="Use an allow-list of trusted partner domains to limit which organizations can be invited."
                />

                {formData.domainRestrictionType === "allowlist" && (
                  <>
                    <Divider />
                    <DomainListEditor
                      title="Allowed Domains"
                      domains={formData.allowedDomains}
                      onChange={(val) => handleFieldChange("allowedDomains", val)}
                    />
                  </>
                )}

                {formData.domainRestrictionType === "blocklist" && (
                  <>
                    <Divider />
                    <DomainListEditor
                      title="Blocked Domains"
                      domains={formData.blockedDomains}
                      onChange={(val) => handleFieldChange("blockedDomains", val)}
                    />
                  </>
                )}
              </Stack>
            </CardContent>
          </Card>
        </Stack>
      ) : null}

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
