import { useEffect, useState, useCallback, useMemo } from "react";
import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { CippHead } from "../../../components/CippComponents/CippHead.jsx";
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
  MenuItem,
  Radio,
  RadioGroup,
  Skeleton,
  Stack,
  Switch,
  TextField,
  Typography,
} from "@mui/material";
import { Add, Save, Refresh } from "@mui/icons-material";
import { useSettings } from "../../../hooks/use-settings.js";
import { ApiGetCall, ApiPostCall } from "../../../api/ApiCall.jsx";
import { CippApiResults } from "../../../components/CippComponents/CippApiResults.jsx";
import CippRelatedSettings from "../../../components/CippComponents/CippRelatedSettings.jsx";
import CippRiskAlert from "../../../components/CippComponents/CippRiskAlert.jsx";
import CippRiskSummaryDialog from "../../../components/CippComponents/CippRiskSummaryDialog.jsx";
import { getCippError } from "../../../utils/get-cipp-error.js";

const DomainListEditor = ({ title, description, domains, onChange }) => {
  const [newDomain, setNewDomain] = useState("");

  const handleAdd = () => {
    const trimmed = newDomain.toLowerCase().trim();
    if (trimmed && !domains.includes(trimmed)) {
      onChange([...domains, trimmed]);
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
      <Typography variant="subtitle2" sx={{ mb: 0.5 }}>
        {title}
      </Typography>
      {description && (
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          {description}
        </Typography>
      )}
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
          <Typography variant="body2" color="text.secondary" fontStyle="italic">
            No domains configured
          </Typography>
        )}
      </Stack>
    </Box>
  );
};

const populateForm = (rawData) => {
  const data = Array.isArray(rawData) ? rawData[0] : rawData;
  if (!data) return null;
  return {
    sharingCapability: data.sharingCapability ?? "disabled",
    sharingDomainRestrictionMode: data.sharingDomainRestrictionMode ?? "none",
    sharingAllowedDomainList: data.sharingAllowedDomainList ?? [],
    sharingBlockedDomainList: data.sharingBlockedDomainList ?? [],
    isResharingByExternalUsersEnabled: data.isResharingByExternalUsersEnabled ?? false,
    defaultSharingLinkType: data.defaultSharingLinkType ?? "specificPeople",
    defaultLinkPermission: data.defaultLinkPermission ?? "view",
    fileAnonymousLinkType: data.fileAnonymousLinkType ?? "view",
    folderAnonymousLinkType: data.folderAnonymousLinkType ?? "view",
    requireAnonymousLinksExpireInDays: data.requireAnonymousLinksExpireInDays ?? 0,
  };
};

const SP_RISK_RULES = [
  {
    id: "anyone-sharing",
    test: (d) => d.sharingCapability === "externalUserAndGuestSharing",
    severity: "error",
    title: "High Risk — Anonymous Sharing Enabled",
    description:
      'The "Anyone" sharing level enables anonymous links — files and folders can be accessed by anyone with the link, without authentication. This is the most common cause of accidental data leaks.',
    recommendation:
      'Set to "New and existing guests" at most. This requires recipients to authenticate before accessing shared content.',
  },
  {
    id: "default-link-anyone",
    test: (d) => d.defaultSharingLinkType === "anyone",
    severity: "error",
    title: "High Risk — Default Link Is Anonymous",
    description:
      'When users share files, the default link type is "Anyone." Users will create anonymous links by default without realizing the security implications.',
    recommendation:
      'Set the default to "Specific people" so users must explicitly choose to create broader links.',
  },
  {
    id: "anon-file-edit",
    test: (d) =>
      d.sharingCapability === "externalUserAndGuestSharing" && d.fileAnonymousLinkType === "edit",
    severity: "error",
    title: "High Risk — Anonymous File Links Grant Edit Access",
    description:
      "Anyone with an anonymous file link can modify the file. This means unauthenticated users can alter your data.",
    recommendation: 'Set anonymous file link permission to "View only."',
  },
  {
    id: "anon-folder-edit",
    test: (d) =>
      d.sharingCapability === "externalUserAndGuestSharing" && d.folderAnonymousLinkType === "edit",
    severity: "error",
    title: "High Risk — Anonymous Folder Links Grant Edit Access",
    description:
      "Anyone with an anonymous folder link can modify, upload, and delete files in the folder without authenticating.",
    recommendation: 'Set anonymous folder link permission to "View only."',
  },
  {
    id: "no-link-expiry",
    test: (d) =>
      d.sharingCapability === "externalUserAndGuestSharing" &&
      (d.requireAnonymousLinksExpireInDays === 0 || d.requireAnonymousLinksExpireInDays === "0"),
    severity: "error",
    title: "High Risk — Anonymous Links Never Expire",
    description:
      "Anonymous sharing links have no expiration date. Once created, these links provide permanent access to files unless manually revoked.",
    recommendation: "Set expiration to 30 days or less to limit the exposure window.",
  },
  {
    id: "no-domain-restriction",
    test: (d) => d.sharingDomainRestrictionMode === "none",
    severity: "warning",
    title: "No SharePoint Domain Restrictions",
    description:
      "External sharing is unrestricted by domain. Users can share content with any external email address.",
    recommendation:
      "Use an allow-list of trusted partner domains to control who content can be shared with.",
  },
  {
    id: "resharing-enabled",
    test: (d) => d.isResharingByExternalUsersEnabled === true,
    severity: "warning",
    title: "External Resharing Enabled",
    description:
      "External guests can reshare files and folders with additional external users, creating a chain of access beyond your original sharing intent.",
    recommendation: "Disable external resharing to maintain control over who accesses your content.",
  },
  {
    id: "default-edit-permission",
    test: (d) => d.defaultLinkPermission === "edit",
    severity: "warning",
    title: "Default Link Permission Is Edit",
    description:
      'When users share files, the default permission is "Edit." Recipients can modify shared files unless the user manually changes it to View.',
    recommendation:
      'Set the default to "View" so users must explicitly grant edit access when needed.',
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
    return SP_RISK_RULES.filter((r) => r.test(formData)).map(({ test, ...rest }) => rest);
  }, [formData]);

  const tenantReady = currentTenant && currentTenant !== "AllTenants";

  const spSettings = ApiGetCall({
    url: "/api/ListSharepointSettings",
    data: { tenantFilter: currentTenant },
    queryKey: `SharepointSettings-${currentTenant}`,
    waiting: tenantReady,
  });

  const updateSettings = ApiPostCall({
    relatedQueryKeys: [`SharepointSettings-${currentTenant}`],
  });

  // Populate form when data arrives (initial load or after refetch)
  useEffect(() => {
    if (spSettings.data) {
      const populated = populateForm(spSettings.data);
      if (populated) {
        setFormData(populated);
        setHasChanges(false);
      }
    }
  }, [spSettings.data, spSettings.dataUpdatedAt]);

  const handleFieldChange = (field, value) => {
    setFormData((prev) => ({
      ...prev,
      [field]: value,
    }));
    setHasChanges(true);
  };

  const handleRefresh = useCallback(() => {
    setFormData(null);
    setHasChanges(false);
    spSettings.refetch();
  }, [spSettings.refetch]);

  const executeSave = () => {
    const payload = {
      tenantFilter: currentTenant,
      sharingCapability: formData.sharingCapability,
      sharingDomainRestrictionMode: formData.sharingDomainRestrictionMode,
      isResharingByExternalUsersEnabled: formData.isResharingByExternalUsersEnabled,
      defaultSharingLinkType: formData.defaultSharingLinkType,
      defaultLinkPermission: formData.defaultLinkPermission,
      fileAnonymousLinkType: formData.fileAnonymousLinkType,
      folderAnonymousLinkType: formData.folderAnonymousLinkType,
      requireAnonymousLinksExpireInDays: formData.requireAnonymousLinksExpireInDays,
    };

    if (formData.sharingDomainRestrictionMode === "allowList") {
      payload.sharingAllowedDomainList = formData.sharingAllowedDomainList;
    } else if (formData.sharingDomainRestrictionMode === "blockList") {
      payload.sharingBlockedDomainList = formData.sharingBlockedDomainList;
    }

    updateSettings.mutate({
      url: "/api/EditSharepointSettings",
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

  if (!tenantReady) {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="warning">
          Please select a specific tenant to manage SharePoint sharing settings.
        </Alert>
      </Box>
    );
  }

  const isLoading = spSettings.isFetching || spSettings.isPending;

  return (
    <Box sx={{ p: 3 }}>
      <CippHead title="SharePoint Sharing Settings" />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            SharePoint Sharing Settings
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Manage tenant-wide SharePoint and OneDrive external sharing, domain restrictions, and
            link defaults.
          </Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          <Button
            variant="outlined"
            startIcon={<Refresh />}
            onClick={handleRefresh}
            disabled={isLoading}
          >
            Refresh
          </Button>
          <Button
            variant="contained"
            startIcon={<Save />}
            onClick={handleSave}
            disabled={!hasChanges || updateSettings.isPending}
          >
            Save Changes
          </Button>
        </Stack>
      </Stack>

      <CippApiResults apiObject={updateSettings} />

      {isLoading ? (
        <Stack spacing={3}>
          <Skeleton variant="rectangular" height={200} />
          <Skeleton variant="rectangular" height={250} />
          <Skeleton variant="rectangular" height={200} />
        </Stack>
      ) : spSettings.isError ? (
        <Alert severity="error" sx={{ mb: 2 }}>
          {spSettings.error
            ? getCippError(spSettings.error)
            : "Failed to load SharePoint settings. Please try refreshing the page."}
        </Alert>
      ) : formData ? (
        <Stack spacing={3}>
          {/* Sharing Capability */}
          <Card>
            <CardHeader
              title="External Sharing Level"
              subheader="Controls the top-level sharing capability for SharePoint and OneDrive across the entire tenant. Site-level sharing cannot exceed this setting."
            />
            <CardContent>
              <CippRelatedSettings
                title="Other settings also gate external access"
                description="Even if SharePoint allows external sharing, access may still be blocked by Entra External Collaboration domain restrictions or Cross-Tenant Access Policy B2B settings. All layers must be permissive enough for external sharing to work."
                links={[
                  {
                    label: "External Collaboration (Entra)",
                    href: "/tenant/administration/cross-tenant-access/external-collaboration",
                  },
                  {
                    label: "Cross-Tenant Access Policy",
                    href: "/tenant/administration/cross-tenant-access/policy",
                  },
                ]}
              />
              <Box sx={{ mt: 2 }}>
              <FormControl component="fieldset">
                <RadioGroup
                  value={formData.sharingCapability}
                  onChange={(e) => handleFieldChange("sharingCapability", e.target.value)}
                >
                  <FormControlLabel
                    value="disabled"
                    control={<Radio />}
                    label={
                      <Box>
                        <Typography variant="body1">
                          Only people in your organization (no external sharing)
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          No files or folders can be shared with anyone outside the organization.
                        </Typography>
                      </Box>
                    }
                  />
                  <FormControlLabel
                    value="existingExternalUserSharingOnly"
                    control={<Radio />}
                    label={
                      <Box>
                        <Typography variant="body1">Existing guests only</Typography>
                        <Typography variant="body2" color="text.secondary">
                          Allow sharing only with guests who are already in the directory. No new
                          guest invitations.
                        </Typography>
                      </Box>
                    }
                  />
                  <FormControlLabel
                    value="externalUserSharingOnly"
                    control={<Radio />}
                    label={
                      <Box>
                        <Typography variant="body1">New and existing guests</Typography>
                        <Typography variant="body2" color="text.secondary">
                          Guests must sign in or provide a verification code. New guests are added to
                          the directory.
                        </Typography>
                      </Box>
                    }
                  />
                  <FormControlLabel
                    value="externalUserAndGuestSharing"
                    control={<Radio />}
                    label={
                      <Box>
                        <Typography variant="body1">
                          Anyone (including anonymous links)
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          Users can share with anyone using links that do not require sign-in. This
                          is the least restrictive setting.
                        </Typography>
                      </Box>
                    }
                  />
                </RadioGroup>
              </FormControl>
              <CippRiskAlert
                visible={formData.sharingCapability === "externalUserAndGuestSharing"}
                severity="error"
                title="High Risk — Anonymous Sharing Enabled"
                description='The "Anyone" sharing level enables anonymous links — files can be accessed without authentication. This is the most common cause of accidental data leaks.'
                recommendation='Set to "New and existing guests" at most. This requires recipients to authenticate before accessing shared content.'
              />
              </Box>
            </CardContent>
          </Card>

          {/* Domain Restrictions */}
          <Card>
            <CardHeader
              title="Sharing Domain Restrictions"
              subheader="Control which external domains users can share SharePoint and OneDrive content with. This is separate from Entra's B2B collaboration domain restrictions."
            />
            <CardContent>
              <Stack spacing={3}>
                <CippRelatedSettings
                  severity="warning"
                  title="This is a separate domain list from Entra"
                  description="This domain allow/deny list is specific to SharePoint and OneDrive sharing. Entra External Collaboration has its own separate domain list that controls B2B guest invitations across all Microsoft 365 services. Both lists must allow a domain for full external access to work."
                  links={[
                    {
                      label: "Entra External Collaboration",
                      href: "/tenant/administration/cross-tenant-access/external-collaboration",
                    },
                  ]}
                />
                <FormControl component="fieldset">
                  <RadioGroup
                    value={formData.sharingDomainRestrictionMode}
                    onChange={(e) =>
                      handleFieldChange("sharingDomainRestrictionMode", e.target.value)
                    }
                  >
                    <FormControlLabel
                      value="none"
                      control={<Radio />}
                      label="No domain restrictions (allow sharing with any domain)"
                    />
                    <FormControlLabel
                      value="allowList"
                      control={<Radio />}
                      label="Allow sharing only with specified domains (most restrictive)"
                    />
                    <FormControlLabel
                      value="blockList"
                      control={<Radio />}
                      label="Block sharing with specified domains"
                    />
                  </RadioGroup>
                </FormControl>
                <CippRiskAlert
                  visible={formData.sharingDomainRestrictionMode === "none"}
                  severity="warning"
                  title="No SharePoint Domain Restrictions"
                  description="External sharing is unrestricted by domain. Users can share content with any external email address."
                  recommendation="Use an allow-list of trusted partner domains to control who content can be shared with."
                />

                {formData.sharingDomainRestrictionMode === "allowList" && (
                  <>
                    <Divider />
                    <Alert severity="info" sx={{ mt: 1 }}>
                      Only users from the domains listed below will be able to receive sharing
                      invitations. All other domains are blocked.
                    </Alert>
                    <DomainListEditor
                      title="Allowed Domains"
                      description="Add domains that are permitted to receive shared content."
                      domains={formData.sharingAllowedDomainList}
                      onChange={(val) => handleFieldChange("sharingAllowedDomainList", val)}
                    />
                  </>
                )}

                {formData.sharingDomainRestrictionMode === "blockList" && (
                  <>
                    <Divider />
                    <Alert severity="warning" sx={{ mt: 1 }}>
                      Users from the domains listed below will be blocked from receiving sharing
                      invitations. All other domains are allowed.
                    </Alert>
                    <DomainListEditor
                      title="Blocked Domains"
                      description="Add domains that should be blocked from receiving shared content."
                      domains={formData.sharingBlockedDomainList}
                      onChange={(val) => handleFieldChange("sharingBlockedDomainList", val)}
                    />
                  </>
                )}
              </Stack>
            </CardContent>
          </Card>

          {/* External User Behavior */}
          <Card>
            <CardHeader
              title="External User Behavior"
              subheader="Configure how external users interact with shared content"
            />
            <CardContent>
              <Stack spacing={2}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={formData.isResharingByExternalUsersEnabled}
                      onChange={(e) =>
                        handleFieldChange("isResharingByExternalUsersEnabled", e.target.checked)
                      }
                    />
                  }
                  label={
                    <Box>
                      <Typography variant="body1">Allow external users to reshare</Typography>
                      <Typography variant="body2" color="text.secondary">
                        When enabled, guests can share files and folders with other external users.
                        Disable to prevent guests from re-sharing content they received.
                      </Typography>
                    </Box>
                  }
                />
                <CippRiskAlert
                  visible={formData.isResharingByExternalUsersEnabled === true}
                  severity="warning"
                  title="External Resharing Enabled"
                  description="External guests can reshare files and folders with additional external users, creating a chain of access beyond your original sharing intent."
                  recommendation="Disable external resharing to maintain control over who accesses your content."
                />
              </Stack>
            </CardContent>
          </Card>

          {/* Default Link Settings */}
          <Card>
            <CardHeader
              title="Default Sharing Link Settings"
              subheader="Configure the default link type and permissions when users share files and folders"
            />
            <CardContent>
              <Stack spacing={3}>
                <TextField
                  select
                  fullWidth
                  label="Default sharing link type"
                  InputLabelProps={{ shrink: true }}
                  value={formData.defaultSharingLinkType}
                  onChange={(e) => handleFieldChange("defaultSharingLinkType", e.target.value)}
                >
                  <MenuItem value="specificPeople">
                    Specific people (only the people the user specifies)
                  </MenuItem>
                  <MenuItem value="organizationMembers">
                    Only people in your organization
                  </MenuItem>
                  <MenuItem value="anyone">Anyone with the link</MenuItem>
                </TextField>
                <CippRiskAlert
                  visible={formData.defaultSharingLinkType === "anyone"}
                  severity="error"
                  title="High Risk — Default Link Is Anonymous"
                  description='When users share files, the default link type is "Anyone." Users will create anonymous links by default without realizing the security implications.'
                  recommendation='Set the default to "Specific people" so users must explicitly choose broader links.'
                />

                <TextField
                  select
                  fullWidth
                  label="Default link permission"
                  InputLabelProps={{ shrink: true }}
                  value={formData.defaultLinkPermission}
                  onChange={(e) => handleFieldChange("defaultLinkPermission", e.target.value)}
                >
                  <MenuItem value="view">View only</MenuItem>
                  <MenuItem value="edit">Edit</MenuItem>
                </TextField>
                <CippRiskAlert
                  visible={formData.defaultLinkPermission === "edit"}
                  severity="warning"
                  title="Default Link Permission Is Edit"
                  description='When users share files, the default permission is "Edit." Recipients can modify shared files unless the user manually changes it to View.'
                  recommendation='Set the default to "View" so users must explicitly grant edit access when needed.'
                />

                <Divider />

                {formData.sharingCapability === "externalUserAndGuestSharing" && (
                  <>
                    <Typography variant="subtitle2">Anonymous Link Settings</Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mt: -1 }}>
                      These settings apply when &quot;Anyone&quot; links are used.
                    </Typography>

                    <Stack direction={{ xs: "column", md: "row" }} spacing={2}>
                      <TextField
                        select
                        fullWidth
                        label="File anonymous link permission"
                        InputLabelProps={{ shrink: true }}
                        value={formData.fileAnonymousLinkType}
                        onChange={(e) =>
                          handleFieldChange("fileAnonymousLinkType", e.target.value)
                        }
                      >
                        <MenuItem value="view">View only</MenuItem>
                        <MenuItem value="edit">View and edit</MenuItem>
                      </TextField>

                      <TextField
                        select
                        fullWidth
                        label="Folder anonymous link permission"
                        InputLabelProps={{ shrink: true }}
                        value={formData.folderAnonymousLinkType}
                        onChange={(e) =>
                          handleFieldChange("folderAnonymousLinkType", e.target.value)
                        }
                      >
                        <MenuItem value="view">View only</MenuItem>
                        <MenuItem value="edit">View and edit</MenuItem>
                      </TextField>
                    </Stack>
                    <CippRiskAlert
                      visible={formData.fileAnonymousLinkType === "edit"}
                      severity="error"
                      title="High Risk — Anonymous File Links Grant Edit Access"
                      description="Anyone with an anonymous file link can modify the file without authenticating."
                      recommendation='Set anonymous file link permission to "View only."'
                    />
                    <CippRiskAlert
                      visible={formData.folderAnonymousLinkType === "edit"}
                      severity="error"
                      title="High Risk — Anonymous Folder Links Grant Edit Access"
                      description="Anyone with an anonymous folder link can modify, upload, and delete files in the folder without authenticating."
                      recommendation='Set anonymous folder link permission to "View only."'
                    />

                    <TextField
                      type="number"
                      label="Anonymous link expiration (days)"
                      helperText="Set to 0 for no expiration. Recommended: 30 days or less."
                      value={formData.requireAnonymousLinksExpireInDays}
                      onChange={(e) =>
                        handleFieldChange(
                          "requireAnonymousLinksExpireInDays",
                          parseInt(e.target.value, 10) || 0
                        )
                      }
                      inputProps={{ min: 0 }}
                      fullWidth
                    />
                    <CippRiskAlert
                      visible={
                        formData.requireAnonymousLinksExpireInDays === 0 ||
                        formData.requireAnonymousLinksExpireInDays === "0"
                      }
                      severity="error"
                      title="High Risk — Anonymous Links Never Expire"
                      description="Anonymous sharing links have no expiration date. Once created, these links provide permanent access unless manually revoked."
                      recommendation="Set expiration to 30 days or less to limit the exposure window."
                    />
                  </>
                )}
              </Stack>
            </CardContent>
          </Card>
        </Stack>
      ) : (
        <Alert severity="warning">
          No SharePoint settings data was returned. Please try refreshing the page or verify that
          the selected tenant has SharePoint configured.
        </Alert>
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
