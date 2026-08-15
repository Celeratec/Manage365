import React, { useState } from "react";
import {
  Alert,
  Collapse,
  Divider,
  IconButton,
  Paper,
  Tooltip,
  Typography,
} from "@mui/material";
import { Box, Grid } from "@mui/system";
import { useForm, useWatch } from "react-hook-form";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import CippFormPage from "../../../../components/CippFormPages/CippFormPage";
import CippFormComponent from "../../../../components/CippComponents/CippFormComponent";
import { useSettings } from "../../../../hooks/use-settings";
import {
  Info as InfoIcon,
  Help as HelpIcon,
  ExpandMore,
  ExpandLess,
} from "@mui/icons-material";

// Helper component for section headers with optional help tooltip
const SectionHeader = ({ title, helpText, children }) => (
  <Box sx={{ display: "flex", alignItems: "center", gap: 1, mb: 1, mt: 2 }}>
    <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
      {title}
    </Typography>
    {helpText && (
      <Tooltip title={helpText} arrow placement="right">
        <IconButton size="small" sx={{ p: 0.5 }}>
          <HelpIcon fontSize="small" color="action" />
        </IconButton>
      </Tooltip>
    )}
    {children}
  </Box>
);

// Info box component for contextual help
const InfoBox = ({ children, severity = "info" }) => (
  <Alert severity={severity} sx={{ mb: 2 }} icon={<InfoIcon fontSize="small" />}>
    <Typography variant="body2">{children}</Typography>
  </Alert>
);

// Collapsible settings section
const CollapsibleSection = ({ title, helpText, defaultOpen = false, children }) => {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <>
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          cursor: "pointer",
          gap: 1,
          mb: 1,
          mt: 2,
          "&:hover": { opacity: 0.8 },
        }}
        onClick={() => setOpen(!open)}
      >
        <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
          {title}
        </Typography>
        {helpText && (
          <Tooltip title={helpText} arrow placement="right">
            <IconButton
              size="small"
              sx={{ p: 0.5 }}
              onClick={(e) => e.stopPropagation()}
            >
              <HelpIcon fontSize="small" color="action" />
            </IconButton>
          </Tooltip>
        )}
        <IconButton size="small" sx={{ ml: "auto" }}>
          {open ? <ExpandLess fontSize="small" /> : <ExpandMore fontSize="small" />}
        </IconButton>
      </Box>
      <Collapse in={open}>{children}</Collapse>
    </>
  );
};

const TeamsAddTeamForm = () => {
  const tenantDomain = useSettings().currentTenant;

  const formControl = useForm({
    mode: "onChange",
    defaultValues: {
      displayName: "",
      description: "",
      owner: null,
      additionalMembers: [],
      visibility: { label: "Private - Invite only", value: "private" },
      templateName: { label: "Standard", value: "standard" },
      // Member settings
      allowCreateUpdateChannels: true,
      allowDeleteChannels: false,
      allowAddRemoveApps: true,
      allowCreatePrivateChannels: true,
      allowCreateUpdateRemoveTabs: true,
      allowCreateUpdateRemoveConnectors: true,
      // Guest settings
      allowGuestCreateUpdateChannels: false,
      allowGuestDeleteChannels: false,
      // Messaging settings
      allowUserEditMessages: true,
      allowUserDeleteMessages: true,
      allowOwnerDeleteMessages: true,
      allowTeamMentions: true,
      allowChannelMentions: true,
      // Fun settings
      allowGiphy: true,
      giphyContentRating: { label: "Moderate", value: "moderate" },
      allowStickersAndMemes: true,
      allowCustomMemes: true,
    },
  });

  const visibility = useWatch({ control: formControl.control, name: "visibility" });
  const templateName = useWatch({ control: formControl.control, name: "templateName" });

  return (
    <CippFormPage
      formControl={formControl}
      queryKey="Teams-AddTeam"
      title="Add Team"
      backButtonTitle="Teams Overview"
      postUrl="/api/AddTeam"
      resetForm={true}
      customDataformatter={(values) => {
        const shippedValues = {
          tenantID: tenantDomain,
          displayName: values.displayName,
          description: values.description,
          owner: values.owner?.value,
          visibility: values.visibility?.value || values.visibility,
          templateName: values.templateName?.value || values.templateName || "standard",
          // Additional members
          additionalMembers:
            values.additionalMembers?.map?.((m) => m.value || m) || [],
          // Member settings
          allowCreateUpdateChannels: values.allowCreateUpdateChannels,
          allowDeleteChannels: values.allowDeleteChannels,
          allowAddRemoveApps: values.allowAddRemoveApps,
          allowCreatePrivateChannels: values.allowCreatePrivateChannels,
          allowCreateUpdateRemoveTabs: values.allowCreateUpdateRemoveTabs,
          allowCreateUpdateRemoveConnectors: values.allowCreateUpdateRemoveConnectors,
          // Guest settings
          allowGuestCreateUpdateChannels: values.allowGuestCreateUpdateChannels,
          allowGuestDeleteChannels: values.allowGuestDeleteChannels,
          // Messaging settings
          allowUserEditMessages: values.allowUserEditMessages,
          allowUserDeleteMessages: values.allowUserDeleteMessages,
          allowOwnerDeleteMessages: values.allowOwnerDeleteMessages,
          allowTeamMentions: values.allowTeamMentions,
          allowChannelMentions: values.allowChannelMentions,
          // Fun settings
          allowGiphy: values.allowGiphy,
          giphyContentRating:
            values.giphyContentRating?.value || values.giphyContentRating || "moderate",
          allowStickersAndMemes: values.allowStickersAndMemes,
          allowCustomMemes: values.allowCustomMemes,
        };
        return shippedValues;
      }}
    >
      <Grid container spacing={2} sx={{ mb: 2 }}>
        {/* Intro guidance */}
        <Grid size={{ xs: 12 }}>
          <Paper sx={{ p: 2, mb: 2, bgcolor: "background.default" }}>
            <Typography variant="body2" color="text.secondary">
              Create a new Microsoft Teams team for your organization. A team provides a
              collaboration space with channels for conversations, file sharing, and app
              integrations. Choose between <strong>Public</strong> (anyone in the org can join) or{" "}
              <strong>Private</strong> (invite only) visibility. You must assign at least one owner
              who will manage the team.
            </Typography>
          </Paper>
        </Grid>

        {/* Basic Information Section */}
        <Grid size={{ xs: 12 }}>
          <SectionHeader
            title="Basic Information"
            helpText="Enter the core details for your new team. The display name and owner are required."
          />
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <CippFormComponent
            type="textField"
            label="Team Name"
            name="displayName"
            formControl={formControl}
            validators={{ required: "Team name is required" }}
            placeholder="e.g., Marketing Team, Project Alpha"
            helperText="The name displayed in Teams. Keep it short and descriptive so users can easily find it."
          />
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <CippFormComponent
            type="autoComplete"
            name="owner"
            label="Team Owner"
            formControl={formControl}
            multiple={false}
            api={{
              url: "/api/ListGraphRequest",
              data: {
                Endpoint: "users",
                $filter: "accountEnabled eq true",
                $top: 999,
                $count: true,
                $orderby: "displayName",
                $select: "id,displayName,userPrincipalName",
              },
              dataKey: "Results",
              labelField: (user) => `${user.displayName} (${user.userPrincipalName})`,
              valueField: "userPrincipalName",
            }}
            validators={{
              validate: (value) => {
                if (!value) return "Team owner is required. Must have a Teams license.";
                return true;
              },
            }}
            helperText="The owner has full control to manage settings, channels, and membership. Must have a Teams license."
          />
        </Grid>

        <Grid size={{ xs: 12 }}>
          <CippFormComponent
            type="textField"
            label="Description"
            name="description"
            formControl={formControl}
            multiline
            rows={2}
            placeholder="e.g., Collaboration space for the marketing team to share campaigns, assets, and ideas"
            helperText="A clear description helps users understand the team's purpose when browsing or searching."
          />
        </Grid>

        <Grid size={{ xs: 12 }}>
          <Divider sx={{ my: 1 }} />
          <SectionHeader
            title="Visibility & Template"
            helpText="Control who can discover and join the team, and choose a starting template."
          />
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <CippFormComponent
            type="autoComplete"
            name="visibility"
            label="Visibility"
            formControl={formControl}
            multiple={false}
            options={[
              { label: "Public - Anyone in the org can join", value: "public" },
              { label: "Private - Invite only", value: "private" },
            ]}
            validators={{
              validate: (value) => {
                if (!value) return "Visibility is required";
                return true;
              },
            }}
            helperText="Public teams appear in search and anyone can join. Private teams require an invitation or approval."
          />
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <CippFormComponent
            type="autoComplete"
            name="templateName"
            label="Team Template"
            formControl={formControl}
            multiple={false}
            options={[
              { label: "Standard", value: "standard" },
              { label: "Education - Class", value: "educationClass" },
              { label: "Education - Staff", value: "educationStaff" },
              { label: "Education - PLC", value: "educationProfessionalLearningCommunity" },
            ]}
            helperText="Templates pre-configure channels, tabs, and apps based on common use cases."
          />
        </Grid>

        {/* Template-specific guidance */}
        <Collapse
          in={visibility?.value === "public"}
          sx={{ width: "100%" }}
        >
          <Grid container spacing={2} sx={{ pt: 1 }}>
            <Grid size={{ xs: 12 }}>
              <InfoBox>
                <strong>Public Team:</strong> All members of your organization can discover and join
                this team without an invitation. Ideal for company-wide announcements, social
                groups, or open collaboration spaces. All conversations and files are visible to
                anyone who joins.
              </InfoBox>
            </Grid>
          </Grid>
        </Collapse>

        <Collapse
          in={visibility?.value === "private"}
          sx={{ width: "100%" }}
        >
          <Grid container spacing={2} sx={{ pt: 1 }}>
            <Grid size={{ xs: 12 }}>
              <InfoBox>
                <strong>Private Team:</strong> Only team owners can add members, and the team
                won&apos;t appear in search results for non-members. Best for sensitive projects,
                management teams, or any group that requires controlled access.
              </InfoBox>
            </Grid>
          </Grid>
        </Collapse>

        {/* Additional Members */}
        <Grid size={{ xs: 12 }}>
          <Divider sx={{ my: 1 }} />
          <SectionHeader
            title="Additional Members"
            helpText="Optionally add members during team creation. You can always add more members later."
          />
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Select users to add as members when the team is created. They will have standard member
            permissions. The owner specified above is added automatically.
          </Typography>
        </Grid>

        <Grid size={{ xs: 12 }}>
          <CippFormComponent
            type="autoComplete"
            name="additionalMembers"
            label="Members (optional)"
            formControl={formControl}
            multiple={true}
            api={{
              url: "/api/ListGraphRequest",
              data: {
                Endpoint: "users",
                $filter: "accountEnabled eq true",
                $top: 999,
                $count: true,
                $orderby: "displayName",
                $select: "id,displayName,userPrincipalName",
              },
              dataKey: "Results",
              labelField: (user) => `${user.displayName} (${user.userPrincipalName})`,
              valueField: "userPrincipalName",
            }}
            helperText="Search and select multiple users. Each must have a Teams license to participate."
          />
        </Grid>

        {/* Advanced Settings - Member Permissions */}
        <Grid size={{ xs: 12 }}>
          <Divider sx={{ my: 1 }} />
          <CollapsibleSection
            title="Member Permissions"
            helpText="Control what regular team members are allowed to do. Owners always have full permissions regardless of these settings."
          >
            <Grid container spacing={2} sx={{ pt: 1 }}>
              <Grid size={{ xs: 12 }}>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                  These settings control what regular members (non-owners) can do within the team.
                  Leave defaults for a typical collaborative team.
                </Typography>
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowCreateUpdateChannels"
                  label="Create & update channels"
                  formControl={formControl}
                  helperText="Members can create new channels and rename existing ones."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowDeleteChannels"
                  label="Delete channels"
                  formControl={formControl}
                  helperText="Members can delete channels they've created."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowAddRemoveApps"
                  label="Add & remove apps"
                  formControl={formControl}
                  helperText="Members can install and remove apps for the team."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowCreatePrivateChannels"
                  label="Create private channels"
                  formControl={formControl}
                  helperText="Members can create channels only visible to select members."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowCreateUpdateRemoveTabs"
                  label="Create, update & remove tabs"
                  formControl={formControl}
                  helperText="Members can manage tabs in channels."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowCreateUpdateRemoveConnectors"
                  label="Create, update & remove connectors"
                  formControl={formControl}
                  helperText="Members can manage connectors that bring external data into channels."
                />
              </Grid>
            </Grid>
          </CollapsibleSection>
        </Grid>

        {/* Guest Permissions */}
        <Grid size={{ xs: 12 }}>
          <CollapsibleSection
            title="Guest Permissions"
            helpText="Control what guest users (external to your organization) are allowed to do. Guests must first be added as members."
          >
            <Grid container spacing={2} sx={{ pt: 1 }}>
              <Grid size={{ xs: 12 }}>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                  These settings apply to guest users who are invited to the team from outside your
                  organization.
                </Typography>
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowGuestCreateUpdateChannels"
                  label="Guests can create & update channels"
                  formControl={formControl}
                  helperText="Allow guest users to create and modify channels."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowGuestDeleteChannels"
                  label="Guests can delete channels"
                  formControl={formControl}
                  helperText="Allow guest users to delete channels."
                />
              </Grid>
            </Grid>
          </CollapsibleSection>
        </Grid>

        {/* Messaging Settings */}
        <Grid size={{ xs: 12 }}>
          <CollapsibleSection
            title="Messaging Settings"
            helpText="Configure how messages work in the team's channels. These affect all members."
          >
            <Grid container spacing={2} sx={{ pt: 1 }}>
              <Grid size={{ xs: 12 }}>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                  Control message editing, deletion, and mention capabilities for the team.
                </Typography>
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowUserEditMessages"
                  label="Users can edit their messages"
                  formControl={formControl}
                  helperText="Members can edit messages after sending them."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowUserDeleteMessages"
                  label="Users can delete their messages"
                  formControl={formControl}
                  helperText="Members can delete their own messages."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowOwnerDeleteMessages"
                  label="Owners can delete any message"
                  formControl={formControl}
                  helperText="Team owners can delete any message in channels."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowTeamMentions"
                  label="@team mentions"
                  formControl={formControl}
                  helperText="Allow @team mentions that notify all team members."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowChannelMentions"
                  label="@channel mentions"
                  formControl={formControl}
                  helperText="Allow @channel mentions that notify everyone who follows the channel."
                />
              </Grid>
            </Grid>
          </CollapsibleSection>
        </Grid>

        {/* Fun Settings */}
        <Grid size={{ xs: 12 }}>
          <CollapsibleSection
            title="Fun Settings"
            helpText="Configure Giphy, stickers, memes, and other fun features. These add personality to conversations."
          >
            <Grid container spacing={2} sx={{ pt: 1 }}>
              <Grid size={{ xs: 12 }}>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                  Control fun and engagement features in team conversations. Disable these for more
                  formal or compliance-sensitive teams.
                </Typography>
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowGiphy"
                  label="Allow Giphy"
                  formControl={formControl}
                  helperText="Members can use animated GIFs from Giphy in conversations."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="autoComplete"
                  name="giphyContentRating"
                  label="Giphy Content Rating"
                  formControl={formControl}
                  multiple={false}
                  options={[
                    { label: "Strict - Family-friendly only", value: "strict" },
                    { label: "Moderate - Most content allowed", value: "moderate" },
                  ]}
                  helperText="Control the content rating for Giphy images. Strict filters out mature content."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowStickersAndMemes"
                  label="Allow stickers & memes"
                  formControl={formControl}
                  helperText="Members can use stickers and memes in conversations."
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="switch"
                  name="allowCustomMemes"
                  label="Allow custom memes"
                  formControl={formControl}
                  helperText="Members can upload and use custom meme images."
                />
              </Grid>
            </Grid>
          </CollapsibleSection>
        </Grid>

        {/* Final guidance */}
        <Grid size={{ xs: 12 }}>
          <Alert severity="info" sx={{ mt: 2 }}>
            <Typography variant="body2">
              <strong>What happens next?</strong> After clicking submit, the team will be created
              and provisioned. This typically takes 15-30 seconds. The owner will receive full access
              and can then customize channels, add apps, and invite additional members. All settings
              configured above can be changed later from the team details page.
            </Typography>
          </Alert>
          <Alert severity="warning" sx={{ mt: 1 }}>
            <Typography variant="body2">
              <strong>SharePoint site provisioning:</strong> A SharePoint site is automatically
              created alongside the team, but it may take <strong>5-15 minutes</strong> to fully
              provision. The site will not appear in the Manage365 SharePoint Sites list until
              Microsoft&apos;s usage reports refresh, which can take <strong>24-48 hours</strong>.
              You can verify the site exists immediately by visiting it directly at{" "}
              <em>https://yourtenant.sharepoint.com/sites/TeamName</em> or by opening the
              Files tab in the Teams channel.
            </Typography>
          </Alert>
        </Grid>
      </Grid>
    </CippFormPage>
  );
};

TeamsAddTeamForm.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default TeamsAddTeamForm;
