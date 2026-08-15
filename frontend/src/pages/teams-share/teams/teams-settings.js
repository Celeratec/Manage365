import { useEffect, useState, useMemo, useCallback } from "react";
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
  Grid,
  IconButton,
  Link,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  MenuItem,
  Radio,
  RadioGroup,
  Skeleton,
  Stack,
  Switch,
  Tab,
  Tabs,
  TextField,
  Typography,
} from "@mui/material";
import { Add, Delete, Save, Refresh, OpenInNew, Wallpaper } from "@mui/icons-material";
import { useSettings } from "../../../hooks/use-settings.js";
import { ApiGetCall, ApiPostCall } from "../../../api/ApiCall.jsx";
import { CippApiResults } from "../../../components/CippComponents/CippApiResults.jsx";
import CippRelatedSettings from "../../../components/CippComponents/CippRelatedSettings.jsx";
import CippRiskAlert from "../../../components/CippComponents/CippRiskAlert.jsx";
import CippRiskSummaryDialog from "../../../components/CippComponents/CippRiskSummaryDialog.jsx";
import CippAccessTypeGuide from "../../../components/CippComponents/CippAccessTypeGuide";

const TabPanel = ({ children, value, index }) => (
  <div role="tabpanel" hidden={value !== index}>
    {value === index && <Box sx={{ py: 3 }}>{children}</Box>}
  </div>
);

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

const TEAMS_RISK_RULES = [
  // Federation tab
  {
    id: "federation-allow-all",
    test: (d) => d.federationMode === "AllowAllExternal",
    severity: "warning",
    title: "All External Domains Allowed",
    description:
      "Any external Teams organization can initiate chat and calls with your users. This includes unknown or untrusted organizations.",
    recommendation:
      "Use the allow-list mode to permit federation only with known partner domains.",
  },
  {
    id: "teams-consumer",
    test: (d) => d.allowTeamsConsumer === true,
    severity: "warning",
    title: "Personal Teams Accounts Allowed",
    description:
      "Users can communicate with people using personal (non-work) Teams accounts. These accounts have no organizational security controls.",
    recommendation: "Disable unless there is a business requirement for personal account communication.",
  },
  {
    id: "teams-consumer-unmanaged",
    test: (d) => d.enableTeamsConsumerAccess === true,
    severity: "warning",
    title: "Unmanaged Teams Accounts Allowed",
    description:
      "Users can communicate with Teams accounts not managed by any organization. These accounts lack any admin oversight.",
    recommendation: "Disable to prevent communication with unmanaged external accounts.",
  },
  // Meeting tab
  {
    id: "anon-start-meeting",
    test: (d) => d.allowAnonymousUsersToStartMeeting === true,
    severity: "error",
    title: "High Risk — Anonymous Users Can Start Meetings",
    description:
      "Unauthenticated users can start meetings in your organization. This allows unknown individuals to initiate meetings on behalf of your tenant.",
    recommendation: "Disable this setting. Only authenticated users should be able to start meetings.",
  },
  {
    id: "auto-admit-everyone",
    test: (d) => d.autoAdmittedUsers === "Everyone",
    severity: "error",
    title: "High Risk — Everyone Bypasses the Lobby",
    description:
      "All participants, including anonymous and external users, are automatically admitted to meetings without waiting in the lobby. There is no opportunity to screen attendees.",
    recommendation:
      'Set to "People in my organization" or "Only organizers and co-organizers" for better meeting security.',
  },
  {
    id: "pstn-bypass-lobby",
    test: (d) => d.allowPSTNUsersToBypassLobby === true,
    severity: "warning",
    title: "Dial-in Callers Bypass Lobby",
    description:
      "Phone dial-in participants skip the lobby and join meetings directly. Their identity cannot be verified the same way as authenticated users.",
    recommendation: "Disable to require dial-in callers to wait in the lobby for admission.",
  },
  {
    id: "external-request-control",
    test: (d) => d.allowExternalParticipantGiveRequestControl === true,
    severity: "warning",
    title: "External Participants Can Request Control",
    description:
      "External meeting participants can request screen sharing control from presenters. This could allow external users to interact with shared content.",
    recommendation: "Disable unless external screen control is specifically needed for collaboration.",
  },
  {
    id: "presenter-everyone",
    test: (d) => d.designatedPresenterRoleMode === "EveryoneUserOverride",
    severity: "warning",
    title: "Everyone Can Present by Default",
    description:
      "All meeting participants, including external guests, can present by default. This means anyone can share their screen or take over the presentation.",
    recommendation:
      'Set to "People in my organization" or "Only organizer" to restrict who can present.',
  },
  // Client tab
  {
    id: "cloud-storage-enabled",
    test: (d) =>
      d.allowGoogleDrive === true ||
      d.allowDropBox === true ||
      d.allowBox === true ||
      d.allowShareFile === true ||
      d.allowEgnyte === true,
    severity: "warning",
    title: "Third-Party Cloud Storage Enabled",
    description:
      "One or more third-party cloud storage providers are enabled in Teams. Users can access files from these services, which means organizational data can flow outside the Microsoft 365 boundary.",
    recommendation:
      "Disable third-party storage providers unless specifically required. Keep data within Microsoft 365 for better DLP and compliance coverage.",
  },
  // Messaging tab
  {
    id: "owner-delete-messages",
    test: (d) => d.allowOwnerDeleteMessage === true,
    severity: "info",
    title: "Team Owners Can Delete Any Message",
    description:
      "Team owners can delete any member's messages in channels. This may affect audit trails and compliance record-keeping.",
    recommendation:
      "Disable if your organization requires complete message retention for compliance or eDiscovery.",
  },
  {
    id: "user-delete-messages-chats",
    test: (d) => d.allowUserDeleteMessage === true && d.allowUserDeleteChat === true,
    severity: "info",
    title: "Users Can Delete Messages and Chats",
    description:
      "Users can delete their own messages and entire chat conversations. Deleted content may not be recoverable and could impact eDiscovery.",
    recommendation:
      "Consider disabling if retention policies require all messages to be preserved.",
  },
  {
    id: "security-reporting-disabled",
    test: (d) => d.allowSecurityEndUserReporting === false,
    severity: "warning",
    title: "Security Reporting Disabled",
    description:
      "End-user security reporting is turned off. Users cannot flag suspicious messages as potential phishing or security threats.",
    recommendation:
      "Enable security reporting so users can help identify and report potential threats.",
  },
];

const Page = () => {
  const settings = useSettings();
  const currentTenant = settings.currentTenant;
  const [tabValue, setTabValue] = useState(0);
  const [formData, setFormData] = useState(null);
  const [changedSections, setChangedSections] = useState(new Set());
  const [riskDialogOpen, setRiskDialogOpen] = useState(false);
  const [assignUser, setAssignUser] = useState("");
  const [selectedPolicy, setSelectedPolicy] = useState("");

  const assignPolicy = ApiPostCall({
    relatedQueryKeys: [`TeamsSettings-${currentTenant}`],
  });

  const handleAssignPolicy = useCallback(() => {
    if (!assignUser || !selectedPolicy) return;
    assignPolicy.mutate({
      url: "/api/EditTeamsSettings",
      data: {
        tenantFilter: currentTenant,
        section: "backgrounds",
        assignUser,
        policyName: selectedPolicy,
      },
    });
    setAssignUser("");
    setSelectedPolicy("");
  }, [assignUser, selectedPolicy, currentTenant]);

  const activeRisks = useMemo(() => {
    if (!formData) return [];
    return TEAMS_RISK_RULES.filter((r) => r.test(formData)).map(({ test, ...rest }) => rest);
  }, [formData]);

  const teamsSettings = ApiGetCall({
    url: "/api/ListTeamsSettings",
    data: { tenantFilter: currentTenant },
    queryKey: `TeamsSettings-${currentTenant}`,
    waiting: true,
  });

  const updateSettings = ApiPostCall({
    relatedQueryKeys: [`TeamsSettings-${currentTenant}`],
  });

  useEffect(() => {
    if (currentTenant) {
      teamsSettings.refetch();
    }
  }, [currentTenant]);

  useEffect(() => {
    if (teamsSettings.data?.Results && !formData) {
      const d = teamsSettings.data.Results;
      setFormData({
        // Federation
        federationMode: d.federationMode ?? "AllowAllExternal",
        allowTeamsConsumer: d.allowTeamsConsumer ?? false,
        federationAllowedDomains: d.federationAllowedDomains ?? [],
        federationBlockedDomains: d.federationBlockedDomains ?? [],
        enableFederationAccess: d.enableFederationAccess ?? true,
        enableTeamsConsumerAccess: d.enableTeamsConsumerAccess ?? false,
        // Client
        allowGuestUser: d.allowGuestUser ?? false,
        allowGoogleDrive: d.allowGoogleDrive ?? false,
        allowShareFile: d.allowShareFile ?? false,
        allowBox: d.allowBox ?? false,
        allowDropBox: d.allowDropBox ?? false,
        allowEgnyte: d.allowEgnyte ?? false,
        // Meeting
        allowAnonymousUsersToJoinMeeting: d.allowAnonymousUsersToJoinMeeting ?? true,
        allowAnonymousUsersToStartMeeting: d.allowAnonymousUsersToStartMeeting ?? false,
        autoAdmittedUsers: d.autoAdmittedUsers ?? "EveryoneInCompanyExcludingGuests",
        allowPSTNUsersToBypassLobby: d.allowPSTNUsersToBypassLobby ?? false,
        meetingChatEnabledType: d.meetingChatEnabledType ?? "Enabled",
        designatedPresenterRoleMode: d.designatedPresenterRoleMode ?? "EveryoneUserOverride",
        allowExternalParticipantGiveRequestControl:
          d.allowExternalParticipantGiveRequestControl ?? false,
        // Messaging
        allowOwnerDeleteMessage: d.allowOwnerDeleteMessage ?? false,
        allowUserDeleteMessage: d.allowUserDeleteMessage ?? true,
        allowUserEditMessage: d.allowUserEditMessage ?? true,
        allowUserDeleteChat: d.allowUserDeleteChat ?? true,
        readReceiptsEnabledType: d.readReceiptsEnabledType ?? "UserPreference",
        createCustomEmojis: d.createCustomEmojis ?? true,
        deleteCustomEmojis: d.deleteCustomEmojis ?? false,
        allowSecurityEndUserReporting: d.allowSecurityEndUserReporting ?? true,
        allowCommunicationComplianceEndUserReporting:
          d.allowCommunicationComplianceEndUserReporting ?? true,
        // Backgrounds
        enableMeetingBackgroundImages: d.enableMeetingBackgroundImages ?? false,
        meetingBackgroundImages: d.meetingBackgroundImages ?? [],
        brandingPolicies: d.brandingPolicies ?? [],
      });
    }
  }, [teamsSettings.data]);

  const sectionMap = {
    0: "federation",
    1: "client",
    2: "meeting",
    3: "messaging",
    4: "backgrounds",
  };

  const handleFieldChange = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    setChangedSections((prev) => new Set(prev).add(sectionMap[tabValue]));
  };

  const handleRefresh = () => {
    setFormData(null);
    setChangedSections(new Set());
    teamsSettings.refetch();
  };

  const handleSave = () => {
    const section = sectionMap[tabValue];
    const payload = { tenantFilter: currentTenant, section };

    if (section === "federation") {
      payload.federationMode = formData.federationMode;
      payload.allowTeamsConsumer = formData.allowTeamsConsumer;
      payload.federationAllowedDomains = formData.federationAllowedDomains;
      payload.federationBlockedDomains = formData.federationBlockedDomains;
      payload.enableFederationAccess = formData.enableFederationAccess;
      payload.enableTeamsConsumerAccess = formData.enableTeamsConsumerAccess;
    } else if (section === "client") {
      payload.allowGuestUser = formData.allowGuestUser;
      payload.allowGoogleDrive = formData.allowGoogleDrive;
      payload.allowShareFile = formData.allowShareFile;
      payload.allowBox = formData.allowBox;
      payload.allowDropBox = formData.allowDropBox;
      payload.allowEgnyte = formData.allowEgnyte;
    } else if (section === "meeting") {
      payload.allowAnonymousUsersToJoinMeeting = formData.allowAnonymousUsersToJoinMeeting;
      payload.allowAnonymousUsersToStartMeeting = formData.allowAnonymousUsersToStartMeeting;
      payload.autoAdmittedUsers = formData.autoAdmittedUsers;
      payload.allowPSTNUsersToBypassLobby = formData.allowPSTNUsersToBypassLobby;
      payload.meetingChatEnabledType = formData.meetingChatEnabledType;
      payload.designatedPresenterRoleMode = formData.designatedPresenterRoleMode;
      payload.allowExternalParticipantGiveRequestControl =
        formData.allowExternalParticipantGiveRequestControl;
    } else if (section === "messaging") {
      payload.allowOwnerDeleteMessage = formData.allowOwnerDeleteMessage;
      payload.allowUserDeleteMessage = formData.allowUserDeleteMessage;
      payload.allowUserEditMessage = formData.allowUserEditMessage;
      payload.allowUserDeleteChat = formData.allowUserDeleteChat;
      payload.readReceiptsEnabledType = formData.readReceiptsEnabledType;
      payload.createCustomEmojis = formData.createCustomEmojis;
      payload.deleteCustomEmojis = formData.deleteCustomEmojis;
      payload.allowSecurityEndUserReporting = formData.allowSecurityEndUserReporting;
      payload.allowCommunicationComplianceEndUserReporting =
        formData.allowCommunicationComplianceEndUserReporting;
    } else if (section === "backgrounds") {
      payload.enableMeetingBackgroundImages = formData.enableMeetingBackgroundImages;
    }

    updateSettings.mutate({
      url: "/api/EditTeamsSettings",
      data: payload,
    });
    setChangedSections((prev) => {
      const next = new Set(prev);
      next.delete(section);
      return next;
    });
  };

  const handleSaveWithRiskCheck = () => {
    const significantRisks = activeRisks.filter((r) => r.severity !== "info");
    if (significantRisks.length > 0) {
      setRiskDialogOpen(true);
    } else {
      handleSave();
    }
  };

  if (!currentTenant || currentTenant === "AllTenants") {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="warning">
          Please select a specific tenant to manage Teams settings.
        </Alert>
      </Box>
    );
  }

  const hasCurrentTabChanges = changedSections.has(sectionMap[tabValue]);

  return (
    <Box sx={{ p: 3 }}>
      <CippHead title="Teams Settings" />
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 3 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Teams Tenant Settings
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Manage tenant-wide Microsoft Teams policies for federation, meetings, messaging, and
            external access.
          </Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          <Button
            variant="outlined"
            startIcon={<Refresh />}
            onClick={handleRefresh}
            disabled={teamsSettings.isFetching}
          >
            Refresh
          </Button>
          <Button
            variant="contained"
            startIcon={<Save />}
            onClick={handleSaveWithRiskCheck}
            disabled={!hasCurrentTabChanges || updateSettings.isPending}
          >
            Save {sectionMap[tabValue].charAt(0).toUpperCase() + sectionMap[tabValue].slice(1)}{" "}
            Settings
          </Button>
        </Stack>
      </Stack>

      <CippApiResults apiObject={updateSettings} />

      {teamsSettings.isFetching ? (
        <Stack spacing={3}>
          <Skeleton variant="rectangular" height={48} />
          <Skeleton variant="rectangular" height={400} />
        </Stack>
      ) : formData ? (
        <>
          <Box sx={{ borderBottom: 1, borderColor: "divider" }}>
            <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)}>
              <Tab
                label={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <span>Federation & External Access</span>
                    {changedSections.has("federation") && (
                      <Chip label="modified" size="small" color="warning" />
                    )}
                  </Stack>
                }
              />
              <Tab
                label={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <span>Guest & Cloud Storage</span>
                    {changedSections.has("client") && (
                      <Chip label="modified" size="small" color="warning" />
                    )}
                  </Stack>
                }
              />
              <Tab
                label={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <span>Meeting Policy</span>
                    {changedSections.has("meeting") && (
                      <Chip label="modified" size="small" color="warning" />
                    )}
                  </Stack>
                }
              />
              <Tab
                label={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <span>Messaging Policy</span>
                    {changedSections.has("messaging") && (
                      <Chip label="modified" size="small" color="warning" />
                    )}
                  </Stack>
                }
              />
              <Tab
                label={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <span>Meeting Backgrounds</span>
                    {changedSections.has("backgrounds") && (
                      <Chip label="modified" size="small" color="warning" />
                    )}
                  </Stack>
                }
              />
            </Tabs>
          </Box>

          {/* Federation & External Access Tab */}
          <TabPanel value={tabValue} index={0}>
            <Stack spacing={3}>
              <CippRelatedSettings
                title="Teams federation is separate from B2B collaboration"
                description="Teams federation controls direct chat and calling between organizations. Guest access to Teams channels is controlled separately by Entra B2B Collaboration and the Cross-Tenant Access Policy. Teams shared channels use B2B Direct Connect, not federation."
                links={[
                  {
                    label: "Cross-Tenant Access Policy",
                    href: "/tenant/administration/cross-tenant-access/policy",
                  },
                  {
                    label: "External Collaboration (Entra)",
                    href: "/tenant/administration/cross-tenant-access/external-collaboration",
                  },
                ]}
              />
              <Card>
                <CardHeader
                  title="Federation Configuration"
                  subheader="Controls whether users can communicate with people from other organizations via Teams"
                />
                <CardContent>
                  <Stack spacing={3}>
                    <FormControl component="fieldset">
                      <RadioGroup
                        value={formData.federationMode}
                        onChange={(e) => handleFieldChange("federationMode", e.target.value)}
                      >
                        <FormControlLabel
                          value="AllowAllExternal"
                          control={<Radio />}
                          label={
                            <Box>
                              <Typography variant="body1">Allow all external domains</Typography>
                              <Typography variant="body2" color="text.secondary">
                                Users can communicate with anyone in any federated organization.
                              </Typography>
                            </Box>
                          }
                        />
                        <FormControlLabel
                          value="BlockAllExternal"
                          control={<Radio />}
                          label={
                            <Box>
                              <Typography variant="body1">Block all external domains</Typography>
                              <Typography variant="body2" color="text.secondary">
                                No external federation is allowed.
                              </Typography>
                            </Box>
                          }
                        />
                        <FormControlLabel
                          value="AllowSpecificExternal"
                          control={<Radio />}
                          label={
                            <Box>
                              <Typography variant="body1">
                                Allow only specific external domains
                              </Typography>
                              <Typography variant="body2" color="text.secondary">
                                Only domains in the allow list can federate.
                              </Typography>
                            </Box>
                          }
                        />
                        <FormControlLabel
                          value="BlockSpecificExternal"
                          control={<Radio />}
                          label={
                            <Box>
                              <Typography variant="body1">
                                Block specific external domains
                              </Typography>
                              <Typography variant="body2" color="text.secondary">
                                All domains except those in the block list can federate.
                              </Typography>
                            </Box>
                          }
                        />
                      </RadioGroup>
                    </FormControl>
                    <CippRiskAlert
                      visible={formData.federationMode === "AllowAllExternal"}
                      severity="warning"
                      title="All External Domains Allowed"
                      description="Any external Teams organization can initiate chat and calls with your users, including unknown or untrusted organizations."
                      recommendation="Use the allow-list mode to permit federation only with known partner domains."
                    />

                    {formData.federationMode === "AllowSpecificExternal" && (
                      <>
                        <Divider />
                        <DomainListEditor
                          title="Allowed Domains"
                          description="Only these domains can communicate with your users via Teams federation."
                          domains={formData.federationAllowedDomains}
                          onChange={(val) => handleFieldChange("federationAllowedDomains", val)}
                        />
                      </>
                    )}

                    {formData.federationMode === "BlockSpecificExternal" && (
                      <>
                        <Divider />
                        <DomainListEditor
                          title="Blocked Domains"
                          description="These domains are blocked from communicating with your users."
                          domains={formData.federationBlockedDomains}
                          onChange={(val) => handleFieldChange("federationBlockedDomains", val)}
                        />
                      </>
                    )}
                  </Stack>
                </CardContent>
              </Card>

              <Card>
                <CardHeader
                  title="External Access Policy"
                  subheader="Fine-grained controls for external communication channels"
                />
                <CardContent>
                  <Stack spacing={2}>
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.enableFederationAccess}
                          onChange={(e) =>
                            handleFieldChange("enableFederationAccess", e.target.checked)
                          }
                        />
                      }
                      label={
                        <Box>
                          <Typography variant="body1">
                            Allow communication from trusted organizations
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Users can chat and call with people from federated organizations.
                          </Typography>
                        </Box>
                      }
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowTeamsConsumer}
                          onChange={(e) =>
                            handleFieldChange("allowTeamsConsumer", e.target.checked)
                          }
                        />
                      }
                      label={
                        <Box>
                          <Typography variant="body1">
                            Allow Teams consumer (personal account) communication
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Users can communicate with people using personal Teams accounts.
                          </Typography>
                        </Box>
                      }
                    />
                    <CippRiskAlert
                      visible={formData.allowTeamsConsumer === true}
                      severity="warning"
                      title="Personal Teams Accounts Allowed"
                      description="Users can communicate with personal (non-work) Teams accounts that have no organizational security controls."
                      recommendation="Disable unless there is a business requirement for personal account communication."
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.enableTeamsConsumerAccess}
                          onChange={(e) =>
                            handleFieldChange("enableTeamsConsumerAccess", e.target.checked)
                          }
                        />
                      }
                      label={
                        <Box>
                          <Typography variant="body1">
                            Allow communication with unmanaged Teams accounts
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Users can reach people with Teams accounts not managed by any
                            organization.
                          </Typography>
                        </Box>
                      }
                    />
                    <CippRiskAlert
                      visible={formData.enableTeamsConsumerAccess === true}
                      severity="warning"
                      title="Unmanaged Teams Accounts Allowed"
                      description="Users can communicate with Teams accounts not managed by any organization. These accounts lack any admin oversight."
                      recommendation="Disable to prevent communication with unmanaged external accounts."
                    />
                  </Stack>
                </CardContent>
              </Card>
            </Stack>
          </TabPanel>

          {/* Guest & Cloud Storage Tab */}
          <TabPanel value={tabValue} index={1}>
            <Stack spacing={3}>
              <CippAccessTypeGuide
                type="guest"
                variant="banner"
                context="teamsGuestSettings"
              />
              <CippRelatedSettings
                title="Guest access requires multiple settings to align"
                description="The Guest Access toggle below only controls whether guests can use Teams. To actually invite guests, Entra External Collaboration settings must allow invitations, the Cross-Tenant Access Policy must allow B2B inbound, and SharePoint sharing must be enabled for guests to access files."
                links={[
                  {
                    label: "External Collaboration (Entra)",
                    href: "/tenant/administration/cross-tenant-access/external-collaboration",
                  },
                  {
                    label: "Cross-Tenant Access Policy",
                    href: "/tenant/administration/cross-tenant-access/policy",
                  },
                  {
                    label: "SharePoint Sharing Settings",
                    href: "/teams-share/sharepoint/sharing-settings",
                  },
                ]}
              />
              <Card>
                <CardHeader
                  title="Guest Access"
                  subheader="Control whether guest users can access Microsoft Teams"
                />
                <CardContent>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={formData.allowGuestUser}
                        onChange={(e) => handleFieldChange("allowGuestUser", e.target.checked)}
                      />
                    }
                    label={
                      <Box>
                        <Typography variant="body1">Allow guest users in Teams</Typography>
                        <Typography variant="body2" color="text.secondary">
                          When enabled, guest users can be invited to teams and channels to
                          collaborate.
                        </Typography>
                      </Box>
                    }
                  />
                </CardContent>
              </Card>

              <Card>
                <CardHeader
                  title="External Cloud Storage Services"
                  subheader="Control which third-party cloud storage providers are available in Teams"
                />
                <CardContent>
                  <Stack spacing={1}>
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowGoogleDrive}
                          onChange={(e) =>
                            handleFieldChange("allowGoogleDrive", e.target.checked)
                          }
                        />
                      }
                      label="Allow Google Drive"
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowShareFile}
                          onChange={(e) => handleFieldChange("allowShareFile", e.target.checked)}
                        />
                      }
                      label="Allow ShareFile (Citrix)"
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowBox}
                          onChange={(e) => handleFieldChange("allowBox", e.target.checked)}
                        />
                      }
                      label="Allow Box"
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowDropBox}
                          onChange={(e) => handleFieldChange("allowDropBox", e.target.checked)}
                        />
                      }
                      label="Allow Dropbox"
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowEgnyte}
                          onChange={(e) => handleFieldChange("allowEgnyte", e.target.checked)}
                        />
                      }
                      label="Allow Egnyte"
                    />
                    <CippRiskAlert
                      visible={
                        formData.allowGoogleDrive === true ||
                        formData.allowDropBox === true ||
                        formData.allowBox === true ||
                        formData.allowShareFile === true ||
                        formData.allowEgnyte === true
                      }
                      severity="warning"
                      title="Third-Party Cloud Storage Enabled"
                      description="One or more third-party cloud storage providers are enabled. Organizational data can flow outside the Microsoft 365 boundary, reducing DLP and compliance coverage."
                      recommendation="Disable third-party storage providers unless specifically required. Keep data within Microsoft 365."
                    />
                  </Stack>
                </CardContent>
              </Card>
            </Stack>
          </TabPanel>

          {/* Meeting Policy Tab */}
          <TabPanel value={tabValue} index={2}>
            <Stack spacing={3}>
              <Card>
                <CardHeader
                  title="Anonymous & External Participant Access"
                  subheader="Controls for anonymous and external users joining meetings"
                />
                <CardContent>
                  <Stack spacing={2}>
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowAnonymousUsersToJoinMeeting}
                          onChange={(e) =>
                            handleFieldChange(
                              "allowAnonymousUsersToJoinMeeting",
                              e.target.checked
                            )
                          }
                        />
                      }
                      label={
                        <Box>
                          <Typography variant="body1">
                            Allow anonymous users to join meetings
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Unauthenticated users can join meetings via a meeting link.
                          </Typography>
                        </Box>
                      }
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowAnonymousUsersToStartMeeting}
                          onChange={(e) =>
                            handleFieldChange(
                              "allowAnonymousUsersToStartMeeting",
                              e.target.checked
                            )
                          }
                        />
                      }
                      label="Allow anonymous users to start meetings"
                    />
                    <CippRiskAlert
                      visible={formData.allowAnonymousUsersToStartMeeting === true}
                      severity="error"
                      title="High Risk — Anonymous Users Can Start Meetings"
                      description="Unauthenticated users can start meetings in your organization, allowing unknown individuals to initiate meetings on behalf of your tenant."
                      recommendation="Disable this setting. Only authenticated users should be able to start meetings."
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowPSTNUsersToBypassLobby}
                          onChange={(e) =>
                            handleFieldChange("allowPSTNUsersToBypassLobby", e.target.checked)
                          }
                        />
                      }
                      label="Allow PSTN (dial-in) users to bypass the lobby"
                    />
                    <CippRiskAlert
                      visible={formData.allowPSTNUsersToBypassLobby === true}
                      severity="warning"
                      title="Dial-in Callers Bypass Lobby"
                      description="Phone dial-in participants skip the lobby and join meetings directly. Their identity cannot be verified the same way as authenticated users."
                      recommendation="Disable to require dial-in callers to wait in the lobby for admission."
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowExternalParticipantGiveRequestControl}
                          onChange={(e) =>
                            handleFieldChange(
                              "allowExternalParticipantGiveRequestControl",
                              e.target.checked
                            )
                          }
                        />
                      }
                      label="Allow external participants to give or request control"
                    />
                    <CippRiskAlert
                      visible={formData.allowExternalParticipantGiveRequestControl === true}
                      severity="warning"
                      title="External Participants Can Request Control"
                      description="External meeting participants can request screen sharing control from presenters, allowing them to interact with shared content."
                      recommendation="Disable unless external screen control is specifically needed for collaboration."
                    />
                  </Stack>
                </CardContent>
              </Card>

              <Card>
                <CardHeader
                  title="Lobby & Presenter Settings"
                  subheader="Control who is admitted automatically and who can present"
                />
                <CardContent>
                  <Stack spacing={3}>
                    <TextField
                      select
                      fullWidth
                      label="Who can bypass the lobby?"
                      InputLabelProps={{ shrink: true }}
                      value={formData.autoAdmittedUsers}
                      onChange={(e) => handleFieldChange("autoAdmittedUsers", e.target.value)}
                    >
                      <MenuItem value="OrganizerOnly">Only organizers and co-organizers</MenuItem>
                      <MenuItem value="InvitedUsers">People who were invited</MenuItem>
                      <MenuItem value="EveryoneInCompanyExcludingGuests">
                        People in my organization (excluding guests)
                      </MenuItem>
                      <MenuItem value="EveryoneInSameAndFederatedCompany">
                        People in my org and trusted organizations
                      </MenuItem>
                      <MenuItem value="Everyone">Everyone</MenuItem>
                    </TextField>
                    <CippRiskAlert
                      visible={formData.autoAdmittedUsers === "Everyone"}
                      severity="error"
                      title="High Risk — Everyone Bypasses the Lobby"
                      description="All participants, including anonymous and external users, are automatically admitted without waiting in the lobby. There is no opportunity to screen attendees."
                      recommendation='Set to "People in my organization" or "Only organizers and co-organizers" for better meeting security.'
                    />

                    <TextField
                      select
                      fullWidth
                      label="Who can present?"
                      InputLabelProps={{ shrink: true }}
                      value={formData.designatedPresenterRoleMode}
                      onChange={(e) =>
                        handleFieldChange("designatedPresenterRoleMode", e.target.value)
                      }
                    >
                      <MenuItem value="OrganizerOnlyUserOverride">Only organizer</MenuItem>
                      <MenuItem value="EveryoneInCompanyUserOverride">
                        People in my organization
                      </MenuItem>
                      <MenuItem value="EveryoneInSameAndFederatedCompanyUserOverride">
                        People in my org and trusted organizations
                      </MenuItem>
                      <MenuItem value="EveryoneUserOverride">Everyone</MenuItem>
                    </TextField>
                    <CippRiskAlert
                      visible={formData.designatedPresenterRoleMode === "EveryoneUserOverride"}
                      severity="warning"
                      title="Everyone Can Present by Default"
                      description="All meeting participants, including external guests, can present by default."
                      recommendation='Set to "People in my organization" or "Only organizer" to restrict who can present.'
                    />

                    <TextField
                      select
                      fullWidth
                      label="Meeting chat"
                      InputLabelProps={{ shrink: true }}
                      value={formData.meetingChatEnabledType}
                      onChange={(e) =>
                        handleFieldChange("meetingChatEnabledType", e.target.value)
                      }
                    >
                      <MenuItem value="Enabled">On for everyone</MenuItem>
                      <MenuItem value="EnabledExceptAnonymous">
                        On for everyone except anonymous users
                      </MenuItem>
                      <MenuItem value="Disabled">Off for everyone</MenuItem>
                    </TextField>
                  </Stack>
                </CardContent>
              </Card>
            </Stack>
          </TabPanel>

          {/* Messaging Policy Tab */}
          <TabPanel value={tabValue} index={3}>
            <Stack spacing={3}>
              <Card>
                <CardHeader
                  title="Message Management"
                  subheader="Controls for editing and deleting messages and chats"
                />
                <CardContent>
                  <Stack spacing={1}>
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowOwnerDeleteMessage}
                          onChange={(e) =>
                            handleFieldChange("allowOwnerDeleteMessage", e.target.checked)
                          }
                        />
                      }
                      label="Allow team owners to delete all messages"
                    />
                    <CippRiskAlert
                      visible={formData.allowOwnerDeleteMessage === true}
                      severity="info"
                      title="Team Owners Can Delete Any Message"
                      description="Team owners can delete any member's messages in channels. This may affect audit trails and compliance record-keeping."
                      recommendation="Disable if your organization requires complete message retention for compliance or eDiscovery."
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowUserDeleteMessage}
                          onChange={(e) =>
                            handleFieldChange("allowUserDeleteMessage", e.target.checked)
                          }
                        />
                      }
                      label="Allow users to delete their own messages"
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowUserEditMessage}
                          onChange={(e) =>
                            handleFieldChange("allowUserEditMessage", e.target.checked)
                          }
                        />
                      }
                      label="Allow users to edit their own messages"
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowUserDeleteChat}
                          onChange={(e) =>
                            handleFieldChange("allowUserDeleteChat", e.target.checked)
                          }
                        />
                      }
                      label="Allow users to delete chats"
                    />
                    <CippRiskAlert
                      visible={
                        formData.allowUserDeleteMessage === true &&
                        formData.allowUserDeleteChat === true
                      }
                      severity="info"
                      title="Users Can Delete Messages and Chats"
                      description="Users can delete their own messages and entire chat conversations. Deleted content may not be recoverable and could impact eDiscovery."
                      recommendation="Consider disabling if retention policies require all messages to be preserved."
                    />
                  </Stack>
                </CardContent>
              </Card>

              <Card>
                <CardHeader
                  title="Additional Messaging Settings"
                  subheader="Read receipts, custom emojis, and reporting"
                />
                <CardContent>
                  <Stack spacing={2}>
                    <TextField
                      select
                      fullWidth
                      label="Read receipts"
                      InputLabelProps={{ shrink: true }}
                      value={formData.readReceiptsEnabledType}
                      onChange={(e) =>
                        handleFieldChange("readReceiptsEnabledType", e.target.value)
                      }
                    >
                      <MenuItem value="UserPreference">User controlled</MenuItem>
                      <MenuItem value="Everyone">Turned on for everyone</MenuItem>
                      <MenuItem value="None">Turned off for everyone</MenuItem>
                    </TextField>
                    <Divider />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.createCustomEmojis}
                          onChange={(e) =>
                            handleFieldChange("createCustomEmojis", e.target.checked)
                          }
                        />
                      }
                      label="Allow creating custom emojis"
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.deleteCustomEmojis}
                          onChange={(e) =>
                            handleFieldChange("deleteCustomEmojis", e.target.checked)
                          }
                        />
                      }
                      label="Allow deleting custom emojis"
                    />
                    <Divider />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowSecurityEndUserReporting}
                          onChange={(e) =>
                            handleFieldChange("allowSecurityEndUserReporting", e.target.checked)
                          }
                        />
                      }
                      label="Allow users to report messages as security concerns"
                    />
                    <CippRiskAlert
                      visible={formData.allowSecurityEndUserReporting === false}
                      severity="warning"
                      title="Security Reporting Disabled"
                      description="End-user security reporting is turned off. Users cannot flag suspicious messages as potential phishing or security threats."
                      recommendation="Enable security reporting so users can help identify and report potential threats."
                    />
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.allowCommunicationComplianceEndUserReporting}
                          onChange={(e) =>
                            handleFieldChange(
                              "allowCommunicationComplianceEndUserReporting",
                              e.target.checked
                            )
                          }
                        />
                      }
                      label="Allow users to report messages as inappropriate content"
                    />
                  </Stack>
                </CardContent>
              </Card>
            </Stack>
          </TabPanel>

          {/* Meeting Backgrounds Tab */}
          <TabPanel value={tabValue} index={4}>
            <Stack spacing={3}>
              <Alert severity="info" variant="outlined">
                Custom meeting backgrounds require <strong>Teams Premium</strong> licenses for users
                to see admin-uploaded backgrounds. Users without Teams Premium can still upload their
                own personal backgrounds.
              </Alert>

              <Card>
                <CardHeader
                  title="Custom Meeting Backgrounds"
                  subheader="Enable organization-wide custom backgrounds for Teams meetings"
                />
                <CardContent>
                  <Stack spacing={3}>
                    <FormControlLabel
                      control={
                        <Switch
                          checked={formData.enableMeetingBackgroundImages}
                          onChange={(e) =>
                            handleFieldChange("enableMeetingBackgroundImages", e.target.checked)
                          }
                        />
                      }
                      label={
                        <Box>
                          <Typography variant="body1">
                            Use background images from my organization
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            When enabled, users with Teams Premium can select from custom backgrounds
                            uploaded by the admin in meetings, webinars, and town halls.
                          </Typography>
                        </Box>
                      }
                    />

                    <Divider />

                    <Box>
                      <Typography variant="subtitle2" gutterBottom>
                        Current Background Images
                      </Typography>
                      {formData.meetingBackgroundImages?.length > 0 ? (
                        <List dense>
                          {formData.meetingBackgroundImages.map((img, idx) => (
                            <ListItem key={idx}>
                              <ListItemIcon>
                                <Wallpaper fontSize="small" />
                              </ListItemIcon>
                              <ListItemText
                                primary={img?.FileName ?? img?.Id ?? `Background ${idx + 1}`}
                                secondary={img?.ContentType ?? null}
                              />
                            </ListItem>
                          ))}
                        </List>
                      ) : (
                        <Typography variant="body2" color="text.secondary" fontStyle="italic">
                          No custom background images found. Upload backgrounds via the Teams Admin
                          Center.
                        </Typography>
                      )}
                    </Box>

                    <Divider />

                    <Box>
                      <Typography variant="subtitle2" gutterBottom>
                        Upload Background Images
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        Microsoft does not provide an API for uploading background images. Backgrounds
                        must be uploaded through the Teams Admin Center.
                      </Typography>
                      <Button
                        variant="outlined"
                        endIcon={<OpenInNew />}
                        component={Link}
                        href="https://admin.teams.microsoft.com/meetings/customization"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        Open Teams Admin Center
                      </Button>
                    </Box>

                    <Divider />

                    <Box>
                      <Typography variant="subtitle2" gutterBottom>
                        Image Requirements
                      </Typography>
                      <Grid container spacing={2}>
                        <Grid item xs={12} sm={6}>
                          <Stack spacing={0.5}>
                            <Typography variant="body2">
                              <strong>Formats:</strong> PNG, JPEG
                            </Typography>
                            <Typography variant="body2">
                              <strong>Recommended:</strong> 1920 x 1080 px (16:9)
                            </Typography>
                            <Typography variant="body2">
                              <strong>Minimum:</strong> 360 x 360 px
                            </Typography>
                          </Stack>
                        </Grid>
                        <Grid item xs={12} sm={6}>
                          <Stack spacing={0.5}>
                            <Typography variant="body2">
                              <strong>Maximum:</strong> 3840 x 2160 px
                            </Typography>
                            <Typography variant="body2">
                              <strong>Limit:</strong> 50 images per organization
                            </Typography>
                          </Stack>
                        </Grid>
                      </Grid>
                      <Alert severity="warning" sx={{ mt: 2 }}>
                        Images below 1920 x 1080 may appear blurry or distorted when displayed as a
                        full-screen meeting background. GIF format is not supported by Microsoft for
                        meeting backgrounds.
                      </Alert>
                    </Box>
                  </Stack>
                </CardContent>
              </Card>

              <Card>
                <CardHeader
                  title="Assign Branding Policy to User"
                  subheader="Grant a specific meeting branding policy to an individual user"
                />
                <CardContent>
                  <Stack spacing={2}>
                    {formData.brandingPolicies?.length > 0 ? (
                      <>
                        <TextField
                          fullWidth
                          label="User (UPN or Object ID)"
                          InputLabelProps={{ shrink: true }}
                          value={assignUser}
                          onChange={(e) => setAssignUser(e.target.value)}
                          placeholder="user@domain.com"
                        />
                        <TextField
                          select
                          fullWidth
                          label="Branding policy"
                          InputLabelProps={{ shrink: true }}
                          value={selectedPolicy}
                          onChange={(e) => setSelectedPolicy(e.target.value)}
                        >
                          <MenuItem value="">
                            <em>Select a policy</em>
                          </MenuItem>
                          {formData.brandingPolicies.map((p) => (
                            <MenuItem key={p.Identity} value={p.Identity}>
                              {p.Identity}
                              {p.Description ? ` — ${p.Description}` : ""}
                            </MenuItem>
                          ))}
                        </TextField>
                        <Box>
                          <Button
                            variant="contained"
                            onClick={handleAssignPolicy}
                            disabled={
                              !assignUser || !selectedPolicy || assignPolicy.isPending
                            }
                          >
                            Assign Policy
                          </Button>
                        </Box>
                        <CippApiResults apiObject={assignPolicy} />
                      </>
                    ) : (
                      <Typography variant="body2" color="text.secondary" fontStyle="italic">
                        No branding policies found for this tenant. Create a policy in the Teams
                        Admin Center before assigning it to users.
                      </Typography>
                    )}
                  </Stack>
                </CardContent>
              </Card>
            </Stack>
          </TabPanel>
        </>
      ) : (
        <Alert severity="error">
          Failed to load Teams settings. Please try refreshing the page.
        </Alert>
      )}

      <CippRiskSummaryDialog
        open={riskDialogOpen}
        onClose={() => setRiskDialogOpen(false)}
        onConfirm={() => {
          setRiskDialogOpen(false);
          handleSave();
        }}
        risks={activeRisks.filter((r) => r.severity !== "info")}
      />
    </Box>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
