import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Collapse,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Stack,
  Typography,
} from "@mui/material";
import { alpha, useTheme } from "@mui/material/styles";
import {
  Send,
  OpenInNew,
  ErrorOutline,
  CheckCircle,
  Search,
  WarningAmber,
  PersonAdd,
} from "@mui/icons-material";
import { useForm } from "react-hook-form";
import { useEffect, useState, useCallback } from "react";
import { ApiPostCall } from "../../api/ApiCall";
import CippFormComponent from "./CippFormComponent";
import CippAccessTypeGuide from "./CippAccessTypeGuide";
import Link from "next/link";
import axios from "axios";
import { buildVersionedHeaders } from "../../utils/cippVersion";

/**
 * Detects whether an error message is a domain collaboration restriction.
 */
const isDomainCollaborationError = (messages) => {
  if (!messages || !Array.isArray(messages)) return false;
  return messages.some(
    (msg) =>
      typeof msg === "string" &&
      (msg.toLowerCase().includes("does not allow collaboration") ||
        msg.toLowerCase().includes("collaboration with the domain"))
  );
};

/**
 * Client-side diagnostic engine. Fetches External Collaboration settings and
 * context-specific settings (SharePoint sharing or Teams guest access), then
 * analyzes them against the blocked domain.
 * @param {"sharepoint"|"teams"} context - Which resource type we're inviting to
 */
const runClientDiagnostics = async (tenantFilter, domain, context = "sharepoint") => {
  const findings = [];
  const headers = await buildVersionedHeaders();

  // --- Fetch Entra External Collaboration settings ---
  try {
    const collabResp = await axios.get("/api/ListExternalCollaboration", {
      params: { tenantFilter },
      headers,
    });
    const collab = collabResp.data?.Results;

    if (collab) {
      // Check if invitations are completely disabled
      if (collab.allowInvitesFrom === "none") {
        findings.push({
          source: "Entra External Collaboration",
          issue: "Guest invitations are completely disabled",
          detail:
            "The 'Guest invite restrictions' setting is set to 'No one in the organization can invite guest users including admins'. All guest invitations are blocked regardless of domain.",
          fix: "Change the guest invite restrictions to allow at least admins and users in the Guest Inviter role to send invitations.",
          settingsPage: "/tenant/administration/cross-tenant-access/external-collaboration",
          severity: "error",
        });
      }

      // Check domain allow/block lists
      const domainPolicy =
        collab.domainRestrictions?.InvitationsAllowedAndBlockedDomainsPolicy;

      if (domainPolicy) {
        const allowed = domainPolicy.AllowedDomains || [];
        const blocked = domainPolicy.BlockedDomains || [];

        if (allowed.length > 0 && !allowed.includes(domain)) {
          findings.push({
            source: "Entra External Collaboration",
            issue: `Domain '${domain}' is not in the allowed domains list`,
            detail: `The tenant uses a domain allow-list for guest invitations. Only users from these domains can be invited. The domain '${domain}' is not on this list.`,
            fix: `Add '${domain}' to the allowed domains list in External Collaboration settings, or switch to a block-list approach.`,
            settingsPage: "/tenant/administration/cross-tenant-access/external-collaboration",
            severity: "error",
            currentList: allowed,
            listType: "allowList",
            canQuickFix: true,
          });
        }

        if (blocked.length > 0 && blocked.includes(domain)) {
          findings.push({
            source: "Entra External Collaboration",
            issue: `Domain '${domain}' is explicitly blocked`,
            detail: `The domain '${domain}' appears in the blocked domains list for guest invitations. Users from this domain cannot be invited.`,
            fix: `Remove '${domain}' from the blocked domains list in External Collaboration settings.`,
            settingsPage: "/tenant/administration/cross-tenant-access/external-collaboration",
            severity: "error",
            currentList: blocked,
            listType: "blockList",
            canQuickFix: true,
          });
        }

        // Policy exists but empty lists — restriction is somewhere else
        if (allowed.length === 0 && blocked.length === 0) {
          findings.push({
            source: "Entra External Collaboration",
            issue: "No domain restrictions found in B2B Management Policy",
            detail:
              "The B2B Management Policy exists but has no domain allow-list or block-list configured. The restriction blocking this invitation may be configured directly in the Azure portal under External Identities > External collaboration settings > Collaboration restrictions, or through a Conditional Access policy.",
            fix: `Open External Collaboration settings and set up an allow-list that includes '${domain}', or check the Azure portal directly.`,
            settingsPage: "/tenant/administration/cross-tenant-access/external-collaboration",
            severity: "error",
            canQuickFix: true,
          });
        }
      } else {
        // No B2B Management Policy found — the domain restriction is configured
        // through the Azure portal or another mechanism that the Graph legacy
        // policies API doesn't expose. This is the most common scenario when
        // restrictions were set up via the Azure portal UI.
        findings.push({
          source: "Entra External Collaboration",
          issue: `Domain '${domain}' is blocked by a collaboration restriction`,
          detail:
            "This tenant has a domain collaboration restriction that is blocking this invitation. The restriction was likely configured in the Azure portal (External Identities > External collaboration settings > Collaboration restrictions) and is not currently managed through Manage365. You can take over management of this setting in Manage365 by configuring the domain restrictions below.",
          fix: `Open External Collaboration settings and configure a domain allow-list that includes '${domain}'. This will create the policy through the Graph API so Manage365 can manage it going forward.`,
          settingsPage: "/tenant/administration/cross-tenant-access/external-collaboration",
          severity: "error",
          canQuickFix: true,
        });
      }
    }
  } catch {
    // External Collaboration endpoint not available
    findings.push({
      source: "Entra External Collaboration",
      issue: "Could not retrieve External Collaboration settings",
      detail:
        "The External Collaboration settings API returned an error. Check permissions or try viewing the settings page directly.",
      fix: "Open External Collaboration settings to review domain restrictions manually.",
      settingsPage: "/tenant/administration/cross-tenant-access/external-collaboration",
      severity: "warning",
    });
  }

  if (context === "teams") {
    // --- Fetch Teams guest access settings ---
    try {
      const teamsResp = await axios.get("/api/ListTeamsSettings", {
        params: { tenantFilter },
        headers,
      });
      const teamsData = teamsResp.data;

      if (teamsData && teamsData.allowGuestUser === false) {
        findings.push({
          source: "Teams Guest Access",
          issue: "Guest access is disabled for Microsoft Teams",
          detail:
            "The Teams tenant setting 'Allow guest access' is currently disabled. Guests cannot be added to any teams until this is enabled.",
          fix: "Enable guest access in Teams Settings > Guest & Cloud Storage, or use the Manage365 Teams Settings page.",
          settingsPage: "/teams-share/teams/teams-settings",
          severity: "error",
        });
      }
    } catch {
      // Teams settings not available - non-critical
    }
  } else {
    // --- Fetch SharePoint Sharing settings ---
    try {
      const spResp = await axios.get("/api/ListSharepointSettings", {
        params: { tenantFilter },
        headers,
      });
      const spData = Array.isArray(spResp.data) ? spResp.data[0] : spResp.data;

      if (spData) {
        if (spData.sharingCapability === "disabled") {
          findings.push({
            source: "SharePoint Sharing Settings",
            issue: "External sharing is completely disabled for SharePoint",
            detail:
              "SharePoint external sharing is set to 'Only people in your organization'. Even if the guest is invited to the tenant, they cannot access SharePoint content.",
            fix: "Enable external sharing in SharePoint Sharing Settings. At minimum, set it to 'Existing guests' or 'New and existing guests'.",
            settingsPage: "/teams-share/sharepoint/sharing-settings",
            severity: "warning",
          });
        }

        if (spData.sharingDomainRestrictionMode === "allowList") {
          const spAllowed = spData.sharingAllowedDomainList || [];
          if (spAllowed.length > 0 && !spAllowed.includes(domain)) {
            findings.push({
              source: "SharePoint Sharing Settings",
              issue: `Domain '${domain}' is not in the SharePoint allowed domains list`,
              detail: `SharePoint uses a separate domain allow-list for external sharing. The domain '${domain}' is not on this list, so even if the guest is invited to the tenant, they won't be able to access SharePoint content.`,
              fix: `Add '${domain}' to the SharePoint sharing allowed domains list.`,
              settingsPage: "/teams-share/sharepoint/sharing-settings",
              severity: "warning",
              currentList: spAllowed,
              listType: "allowList",
            });
          }
        } else if (spData.sharingDomainRestrictionMode === "blockList") {
          const spBlocked = spData.sharingBlockedDomainList || [];
          if (spBlocked.length > 0 && spBlocked.includes(domain)) {
            findings.push({
              source: "SharePoint Sharing Settings",
              issue: `Domain '${domain}' is blocked in SharePoint sharing settings`,
              detail: `The domain '${domain}' appears in the SharePoint blocked domains list.`,
              fix: `Remove '${domain}' from the SharePoint sharing blocked domains list.`,
              settingsPage: "/teams-share/sharepoint/sharing-settings",
              severity: "warning",
              currentList: spBlocked,
              listType: "blockList",
            });
          }
        }
      }
    } catch {
      // SharePoint settings not available - non-critical
    }
  }

  return findings;
};

const CippGuestInviteDialog = ({
  open,
  onClose,
  tenantFilter,
  groupId,
  webUrl,
  sharePointType,
  teamId,
  teamName,
  relatedQueryKeys = [],
}) => {
  const theme = useTheme();
  const [diagnostics, setDiagnostics] = useState(null);
  const [blockedDomain, setBlockedDomain] = useState(null);
  const [resultMessages, setResultMessages] = useState([]);
  const [status, setStatus] = useState("idle"); // idle | loading | success | error
  const [diagLoading, setDiagLoading] = useState(false);
  const [quickFixStatus, setQuickFixStatus] = useState("idle"); // idle | loading | success | error
  const [quickFixMessage, setQuickFixMessage] = useState("");
  const [quickFixAttempted, setQuickFixAttempted] = useState(false);
  const [nonGroupSiteWarning, setNonGroupSiteWarning] = useState(false);
  const [teamsAddWarning, setTeamsAddWarning] = useState(false);
  const [preflightResult, setPreflightResult] = useState(null);
  const [preflightLoading, setPreflightLoading] = useState(false);

  const isTeamsMode = Boolean(teamId);
  const diagContext = isTeamsMode ? "teams" : "sharepoint";
  const isNonGroupSite = !isTeamsMode && sharePointType && !sharePointType.includes("Group");

  const formHook = useForm({
    defaultValues: {
      displayName: "",
      mail: "",
      redirectUri: "",
      sendInvite: true,
    },
    mode: "onChange",
  });

  const inviteApi = ApiPostCall({
    relatedQueryKeys,
  });

  const resetForNewGuest = useCallback(() => {
    setDiagnostics(null);
    setBlockedDomain(null);
    setResultMessages([]);
    setStatus("idle");
    setDiagLoading(false);
    setQuickFixStatus("idle");
    setQuickFixMessage("");
    setNonGroupSiteWarning(false);
    setTeamsAddWarning(false);
    setPreflightResult(null);
    setPreflightLoading(false);
    formHook.reset({
      displayName: "",
      mail: "",
      redirectUri: "",
      sendInvite: true,
    });
  }, [formHook]);

  const runPreflight = useCallback(
    async (email) => {
      if (!email || !email.includes("@") || !tenantFilter) return;
      setPreflightLoading(true);
      setPreflightResult(null);
      try {
        const headers = await buildVersionedHeaders();
        const resp = await axios.post("/api/ExecValidateExternalDomain", {
          email,
          tenantFilter,
          context: isTeamsMode ? "teams-standard" : "sharepoint",
        }, { headers });
        setPreflightResult(resp.data?.Results);
      } catch {
        // Pre-flight is best-effort
      } finally {
        setPreflightLoading(false);
      }
    },
    [tenantFilter, isTeamsMode]
  );

  const watchedEmail = formHook.watch("mail");
  useEffect(() => {
    if (!watchedEmail || !watchedEmail.includes("@") || !/^[^@]+@[^@]+\.[^@]+$/.test(watchedEmail)) {
      setPreflightResult(null);
      return;
    }
    const timer = setTimeout(() => {
      runPreflight(watchedEmail);
    }, 800);
    return () => clearTimeout(timer);
  }, [watchedEmail, runPreflight]);

  // Reset state when dialog opens/closes
  useEffect(() => {
    if (open) {
      setQuickFixAttempted(false);
      resetForNewGuest();
    }
  }, [open]);

  const runDiagnostics = useCallback(
    async (errorMessages, email, fixWasAttempted) => {
      const domain = email?.split("@")[1];
      if (!domain || !isDomainCollaborationError(errorMessages)) return;

      setBlockedDomain(domain);
      setDiagLoading(true);

      const contextLabel = isTeamsMode ? "Teams Settings" : "SharePoint Sharing settings";

      try {
        if (fixWasAttempted) {
          setDiagnostics([
            {
              source: "Microsoft Entra Admin Center",
              issue: `Domain '${domain}' is blocked by an Azure-managed restriction`,
              detail:
                "The domain allow-list was updated through the Graph API, but the invitation is still blocked. This means the collaboration restriction for this tenant is managed directly by Azure and cannot be modified through the Graph API. You need to change it in the Microsoft Entra admin center.",
              fix: `In the Entra admin center, go to External Identities > External collaboration settings > Collaboration restrictions. Change the setting to either 'Allow invitations to any domain' or add '${domain}' to the allowed domains list.`,
              severity: "error",
              entraPortalLink: true,
            },
          ]);
        } else {
          const findings = await runClientDiagnostics(tenantFilter, domain, diagContext);
          const actionable = findings.filter((f) => f.severity !== "info");
          setDiagnostics(actionable.length > 0 ? actionable : findings);
        }
      } catch {
        setDiagnostics([
          {
            source: "Diagnostic Engine",
            issue: "Diagnostics failed",
            detail: "Could not retrieve tenant settings to diagnose the issue.",
            fix: `Check External Collaboration settings and ${contextLabel} manually.`,
            settingsPage: "/tenant/administration/cross-tenant-access/external-collaboration",
            severity: "warning",
          },
        ]);
      } finally {
        setDiagLoading(false);
      }
    },
    [tenantFilter, isTeamsMode, diagContext]
  );

  /**
   * Quick-fix: adds the blocked domain to the External Collaboration allow-list
   * (or removes it from the block-list), then retries the invitation.
   */
  const handleQuickFix = useCallback(async () => {
    if (!blockedDomain) return;

    setQuickFixStatus("loading");
    setQuickFixMessage("");

    try {
      const headers = await buildVersionedHeaders();

      // First, read the current External Collaboration settings
      const collabResp = await axios.get("/api/ListExternalCollaboration", {
        params: { tenantFilter },
        headers,
      });
      const collab = collabResp.data?.Results;
      const domainPolicy =
        collab?.domainRestrictions?.InvitationsAllowedAndBlockedDomainsPolicy;

      // Determine the fix action
      let allowedDomains = domainPolicy?.AllowedDomains || [];
      let blockedDomains = domainPolicy?.BlockedDomains || [];

      if (blockedDomains.includes(blockedDomain)) {
        // Remove from block list
        blockedDomains = blockedDomains.filter((d) => d !== blockedDomain);
      } else if (allowedDomains.length > 0 && !allowedDomains.includes(blockedDomain)) {
        // Add to existing allow list
        allowedDomains = [...allowedDomains, blockedDomain];
      } else {
        // No existing lists — create an allow-list with this domain
        // We also need common domains, so let's just add this one and let
        // the admin review further
        allowedDomains = [blockedDomain];
      }

      // Apply the fix
      await axios.post(
        "/api/EditExternalCollaboration",
        {
          tenantFilter,
          domainRestrictions: {
            InvitationsAllowedAndBlockedDomainsPolicy: {
              AllowedDomains: allowedDomains,
              BlockedDomains: blockedDomains,
            },
          },
        },
        { headers }
      );

      setQuickFixStatus("success");
      setQuickFixAttempted(true);
      setQuickFixMessage(
        `Added '${blockedDomain}' to the allowed domains list. You can now retry the invitation.`
      );

      // Clear the error state so the user can retry
      setDiagnostics(null);
      setResultMessages([]);
      setStatus("idle");
    } catch (err) {
      setQuickFixStatus("error");
      const errMsg =
        err?.response?.data?.Results ||
        err?.message ||
        "Failed to update domain restrictions.";
      setQuickFixMessage(
        typeof errMsg === "string" ? errMsg : Array.isArray(errMsg) ? errMsg.join(" ") : String(errMsg)
      );
    }
  }, [blockedDomain, tenantFilter]);

  const onSubmit = (data) => {
    setStatus("loading");
    setDiagnostics(null);
    setBlockedDomain(null);
    setResultMessages([]);
    setDiagLoading(false);
    setTeamsAddWarning(false);

    const payload = isTeamsMode
      ? { tenantFilter, TeamID: teamId, ...data }
      : { tenantFilter, groupId, URL: webUrl, SharePointType: sharePointType, ...data };

    inviteApi.mutate(
      {
        url: "/api/ExecSharePointInviteGuest",
        data: payload,
      },
      {
        onSuccess: (response) => {
          const results = response?.data?.Results || [];
          setResultMessages(results);
          setStatus("success");
          if (response?.data?.NonGroupSiteWarning) {
            setNonGroupSiteWarning(true);
          }
          if (response?.data?.TeamsAddWarning) {
            setTeamsAddWarning(true);
          }
        },
        onError: (error) => {
          const responseData = error?.response?.data;
          const results = responseData?.Results || [
            error?.message || "An unexpected error occurred.",
          ];
          setResultMessages(results);
          setStatus("error");

          // Check if backend provided specific diagnostics (not fallback)
          const backendDiags = responseData?.Diagnostics;
          const hasRealDiag =
            backendDiags?.length > 0 &&
            !backendDiags.every((d) => d.source === "Unknown Policy");

          if (hasRealDiag && !quickFixAttempted) {
            setDiagnostics(backendDiags);
            setBlockedDomain(responseData?.BlockedDomain);
          } else {
            // Run client-side diagnostics - more reliable since it uses
            // the same API endpoints as the settings pages
            runDiagnostics(results, data.mail, quickFixAttempted);
          }
        },
      }
    );
  };

  const handleClose = () => {
    onClose();
  };

  const fields = [
    {
      type: "textField",
      name: "displayName",
      label: "Display Name",
      placeholder: "Guest user's display name",
      validators: { required: "Display name is required" },
    },
    {
      type: "textField",
      name: "mail",
      label: "Email Address",
      placeholder: "guest@externaldomain.com",
      validators: {
        required: "Email address is required",
        pattern: {
          value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
          message: "Please enter a valid email address",
        },
      },
    },
    {
      type: "textField",
      name: "redirectUri",
      label: "Redirect URL (Optional)",
      placeholder: "https://myapps.microsoft.com",
    },
    {
      type: "switch",
      name: "sendInvite",
      label: "Send email invitation to guest",
    },
  ];

  const hasDiagnostics = diagnostics && diagnostics.length > 0;

  return (
    <Dialog fullWidth maxWidth="sm" onClose={handleClose} open={open} disableRestoreFocus>
      <form onSubmit={formHook.handleSubmit(onSubmit)}>
        <DialogTitle>
          <Stack direction="row" alignItems="center" spacing={1}>
            <Send sx={{ fontSize: 22 }} />
            <span>Invite External Guest</span>
          </Stack>
        </DialogTitle>

        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {isTeamsMode
              ? `Invite an external guest user to this Team${teamName ? ` (${teamName})` : ""}. The guest will be invited to the tenant and automatically added as a team member.`
              : "Invite an external guest user to this SharePoint site. The guest will be invited to the tenant and automatically added as a site member."}
          </Typography>
          <CippAccessTypeGuide
            type="guest"
            variant="banner"
            context={isTeamsMode ? "teamsStandardChannel" : "sharepoint"}
            showSettingsLinks={false}
          />
        </DialogContent>

        {/* Form Fields */}
        <Collapse in={status === "idle" || status === "loading"}>
          <DialogContent>
            <Stack spacing={2}>
              {fields.map((fieldProps, i) => (
                <Box key={i} sx={{ width: "100%" }}>
                  <CippFormComponent formControl={formHook} {...fieldProps} />
                </Box>
              ))}
            </Stack>
            {preflightLoading && (
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mt: 1 }}>
                <CircularProgress size={16} />
                <Typography variant="caption" color="text.secondary">
                  Validating domain...
                </Typography>
              </Stack>
            )}
            {preflightResult && !preflightLoading && (
              <Stack spacing={1} sx={{ mt: 1.5 }}>
                {preflightResult.domainType === "consumer" && (
                  <Alert severity="info" sx={{ py: 0.5 }}>
                    <Typography variant="caption">
                      <strong>{preflightResult.domain}</strong> is a personal email domain. The user will authenticate via Email One-Time Passcode (OTP).
                    </Typography>
                  </Alert>
                )}
                {preflightResult.existingGuest && (
                  <Alert severity="success" sx={{ py: 0.5 }}>
                    <Typography variant="caption">
                      This user already exists as a guest: <strong>{preflightResult.existingGuest.displayName}</strong> ({preflightResult.existingGuest.externalUserState || "Active"})
                    </Typography>
                  </Alert>
                )}
                {preflightResult.policyChecks?.filter((c) => c.status === "fail").map((check, i) => (
                  <Alert key={i} severity="error" sx={{ py: 0.5 }}>
                    <Typography variant="caption">
                      <strong>{check.source}:</strong> {check.detail}
                      {check.fix && <> — <em>{check.fix}</em></>}
                    </Typography>
                  </Alert>
                ))}
                {preflightResult.policyChecks?.filter((c) => c.status === "warning").map((check, i) => (
                  <Alert key={`w${i}`} severity="warning" sx={{ py: 0.5 }}>
                    <Typography variant="caption">
                      <strong>{check.source}:</strong> {check.detail}
                    </Typography>
                  </Alert>
                ))}
                {preflightResult.canProceed === false && (
                  <Alert severity="error" sx={{ py: 0.5 }}>
                    <Typography variant="caption" sx={{ fontWeight: 600 }}>
                      This invitation will likely fail due to the policy issues above. Fix them first or use the Sharing Troubleshooter for more details.
                    </Typography>
                  </Alert>
                )}
              </Stack>
            )}
          </DialogContent>
        </Collapse>

        {/* Loading State */}
        <Collapse in={status === "loading"}>
          <DialogContent>
            <Stack alignItems="center" spacing={1} sx={{ py: 2 }}>
              <CircularProgress size={28} />
              <Typography variant="body2" color="text.secondary">
                Inviting guest...
              </Typography>
            </Stack>
          </DialogContent>
        </Collapse>

        {/* Success State */}
        <Collapse in={status === "success"}>
          <DialogContent>
            <Stack spacing={1.5}>
              {resultMessages.map((msg, i) => {
                const isGraphFallback =
                  typeof msg === "string" && msg.includes("Graph API fallback");
                const isWarning =
                  typeof msg === "string" &&
                  !isGraphFallback &&
                  (msg.includes("could not add") || msg.includes("not available for automatic"));
                const isSharePointAccessError =
                  typeof msg === "string" &&
                  !isGraphFallback &&
                  (msg.includes("Failed to obtain a SharePoint token") || msg.includes("SharePoint denied access"));
                return (
                  <Alert
                    key={i}
                    severity={isGraphFallback ? "info" : isWarning ? "warning" : "success"}
                    icon={isGraphFallback ? <WarningAmber /> : isWarning ? <WarningAmber /> : <CheckCircle />}
                  >
                    {isSharePointAccessError ? (
                      <Stack spacing={1}>
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          Guest invited to tenant, but could not add to site members.
                        </Typography>
                        <Typography variant="body2">{msg}</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          Suggested steps:
                        </Typography>
                        <Typography variant="body2" component="div">
                          <ol style={{ margin: 0, paddingLeft: "1.2em" }}>
                            <li>
                              Run a <strong>CPV Refresh</strong> for this tenant from the tenant
                              overview page
                            </li>
                            <li>
                              Verify the site does not have restricted or unique permissions in
                              SharePoint
                            </li>
                            <li>
                              If the issue persists, check that the Manage365 SAM app has the necessary
                              SharePoint delegated permissions
                            </li>
                          </ol>
                        </Typography>
                      </Stack>
                    ) : isGraphFallback ? (
                      <Stack spacing={0.5}>
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          Guest added via fallback method
                        </Typography>
                        <Typography variant="body2">
                          The SharePoint REST API denied access, so document library access was granted
                          via the Graph API instead. The guest can access the site&apos;s document
                          library, but may not have full site membership. Consider running a{" "}
                          <strong>CPV Refresh</strong> to resolve the underlying permission issue.
                        </Typography>
                      </Stack>
                    ) : (
                      <Typography variant="body2">{msg}</Typography>
                    )}
                  </Alert>
                );
              })}
              {teamsAddWarning && (
                <Alert severity="info" variant="outlined">
                  <Typography variant="body2">
                    The guest was invited to the tenant but could not be added to the Team
                    automatically. You can add them manually using the <strong>Add Member</strong>{" "}
                    button in the Members section.
                  </Typography>
                </Alert>
              )}
              {nonGroupSiteWarning && !resultMessages.some((m) => typeof m === "string" && (m.includes("Failed to obtain a SharePoint token") || m.includes("SharePoint denied access"))) && webUrl && (
                <Alert severity="info" variant="outlined">
                  <Typography variant="body2" sx={{ mb: 1 }}>
                    This is a non-group-connected site, so automatic membership assignment was not
                    possible. You can add the guest manually using the <strong>Add Member</strong>{" "}
                    button in the Site Members table, or assign permissions directly in SharePoint.
                  </Typography>
                  <Button
                    href={`${webUrl}/_layouts/15/people.aspx?MembershipGroupId=0`}
                    target="_blank"
                    rel="noopener noreferrer"
                    size="small"
                    variant="outlined"
                    startIcon={<OpenInNew sx={{ fontSize: 14 }} />}
                    sx={{ textTransform: "none", fontSize: "0.75rem" }}
                  >
                    Open SharePoint Site Permissions
                  </Button>
                </Alert>
              )}
              {!nonGroupSiteWarning && !teamsAddWarning && (
                <Alert severity="info" variant="outlined" sx={{ mt: 0.5 }}>
                  <Typography variant="body2">
                    {isTeamsMode
                      ? "It may take a minute or two for the guest to appear in the Members list while Teams syncs the membership."
                      : "It may take a minute or two for the guest to appear in the Site Members table while SharePoint syncs the membership."}
                  </Typography>
                </Alert>
              )}
            </Stack>
          </DialogContent>
        </Collapse>

        {/* Error State */}
        <Collapse in={status === "error"}>
          <DialogContent>
            <Stack spacing={2}>
              {/* Error messages */}
              {resultMessages.map((msg, i) => (
                <Alert key={i} severity="error" icon={<ErrorOutline />}>
                  <Typography variant="body2">{msg}</Typography>
                </Alert>
              ))}

              {/* Diagnostics Loading */}
              {diagLoading && (
                <Box
                  sx={{
                    border: `1px solid ${alpha(theme.palette.info.main, 0.3)}`,
                    borderRadius: 2,
                    px: 2,
                    py: 2,
                    bgcolor: alpha(theme.palette.info.main, 0.04),
                  }}
                >
                  <Stack direction="row" alignItems="center" spacing={1.5}>
                    <CircularProgress size={18} />
                    <Typography variant="body2" color="text.secondary">
                      Analyzing tenant settings to identify the cause...
                    </Typography>
                  </Stack>
                </Box>
              )}

              {/* Diagnostics Panel */}
              {hasDiagnostics && !diagLoading && (
                <Box
                  sx={{
                    border: `1px solid ${alpha(theme.palette.warning.main, 0.4)}`,
                    borderRadius: 2,
                    overflow: "hidden",
                  }}
                >
                  {/* Diagnostics Header */}
                  <Box
                    sx={{
                      px: 2,
                      py: 1.5,
                      bgcolor: alpha(theme.palette.warning.main, 0.08),
                      borderBottom: `1px solid ${alpha(theme.palette.warning.main, 0.2)}`,
                    }}
                  >
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Search sx={{ fontSize: 18, color: "warning.main" }} />
                      <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                        Root Cause Analysis
                      </Typography>
                      {blockedDomain && (
                        <Chip
                          label={blockedDomain}
                          size="small"
                          color="error"
                          variant="outlined"
                          sx={{ ml: "auto", height: 24, fontSize: "0.75rem" }}
                        />
                      )}
                    </Stack>
                    <Typography
                      variant="caption"
                      color="text.secondary"
                      sx={{ mt: 0.5, display: "block" }}
                    >
                      {(() => {
                        const errorCount = diagnostics.filter(
                          (d) => d.severity === "error"
                        ).length;
                        const warnCount = diagnostics.filter(
                          (d) => d.severity === "warning"
                        ).length;
                        if (errorCount > 0)
                          return `${errorCount} policy ${errorCount === 1 ? "restriction" : "restrictions"} identified that ${errorCount === 1 ? "is" : "are"} blocking this invitation:`;
                        if (warnCount > 0)
                          return `${warnCount} potential ${warnCount === 1 ? "issue" : "issues"} found — review the settings below:`;
                        return "Review the following settings:";
                      })()}
                    </Typography>
                  </Box>

                  {/* Individual Diagnostics */}
                  <Stack spacing={0} divider={<Divider />}>
                    {diagnostics.map((diag, idx) => (
                      <Box key={idx} sx={{ px: 2, py: 1.5 }}>
                        <Stack direction="row" alignItems="flex-start" spacing={1.5}>
                          <Box sx={{ pt: 0.25 }}>
                            {diag.severity === "error" ? (
                              <ErrorOutline sx={{ fontSize: 18, color: "error.main" }} />
                            ) : (
                              <WarningAmber sx={{ fontSize: 18, color: "warning.main" }} />
                            )}
                          </Box>
                          <Box sx={{ flex: 1, minWidth: 0 }}>
                            <Typography
                              variant="body2"
                              sx={{
                                fontWeight: 600,
                                mb: 0.5,
                                color:
                                  diag.severity === "error" ? "error.main" : "warning.main",
                              }}
                            >
                              {diag.issue}
                            </Typography>

                            <Typography
                              variant="caption"
                              color="text.secondary"
                              sx={{ display: "block", mb: 0.5 }}
                            >
                              <strong>Source:</strong> {diag.source}
                            </Typography>

                            <Typography variant="body2" sx={{ mb: 1 }}>
                              {diag.detail}
                            </Typography>

                            {diag.currentList && diag.currentList.length > 0 && (
                              <Box sx={{ mb: 1 }}>
                                <Typography
                                  variant="caption"
                                  color="text.secondary"
                                  sx={{ display: "block", mb: 0.5 }}
                                >
                                  Current{" "}
                                  {diag.listType === "allowList" ? "allowed" : "blocked"}{" "}
                                  domains:
                                </Typography>
                                <Stack direction="row" flexWrap="wrap" gap={0.5}>
                                  {diag.currentList.map((domain, di) => (
                                    <Chip
                                      key={di}
                                      label={domain}
                                      size="small"
                                      variant="outlined"
                                      color={
                                        diag.listType === "allowList" ? "success" : "error"
                                      }
                                      sx={{ height: 22, fontSize: "0.7rem" }}
                                    />
                                  ))}
                                </Stack>
                              </Box>
                            )}

                            <Alert
                              severity="info"
                              variant="outlined"
                              icon={false}
                              sx={{ py: 0.5 }}
                            >
                              <Typography variant="caption">
                                <strong>How to fix:</strong> {diag.fix}
                              </Typography>
                            </Alert>

                            <Stack direction="row" spacing={1} sx={{ mt: 1 }} flexWrap="wrap" useFlexGap>
                              {diag.entraPortalLink && (
                                <Button
                                  href="https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings"
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  size="small"
                                  variant="contained"
                                  color="primary"
                                  startIcon={<OpenInNew sx={{ fontSize: 14 }} />}
                                  sx={{ textTransform: "none", fontSize: "0.75rem" }}
                                >
                                  Open Entra Admin Center
                                </Button>
                              )}
                              {diag.canQuickFix && blockedDomain && !quickFixAttempted && (
                                <Button
                                  size="small"
                                  variant="contained"
                                  color="primary"
                                  disabled={quickFixStatus === "loading"}
                                  startIcon={
                                    quickFixStatus === "loading" ? (
                                      <CircularProgress size={14} />
                                    ) : (
                                      <Send sx={{ fontSize: 14 }} />
                                    )
                                  }
                                  onClick={handleQuickFix}
                                  sx={{ textTransform: "none", fontSize: "0.75rem" }}
                                >
                                  {quickFixStatus === "loading"
                                    ? "Updating..."
                                    : `Allow ${blockedDomain} & Retry`}
                                </Button>
                              )}
                              {diag.settingsPage && (
                                <Button
                                  component={Link}
                                  href={`${diag.settingsPage}?tenantFilter=${tenantFilter}`}
                                  target="_blank"
                                  size="small"
                                  variant="outlined"
                                  startIcon={<OpenInNew sx={{ fontSize: 14 }} />}
                                  sx={{ textTransform: "none", fontSize: "0.75rem" }}
                                >
                                  Open {diag.source}
                                </Button>
                              )}
                            </Stack>
                          </Box>
                        </Stack>
                      </Box>
                    ))}
                  </Stack>
                </Box>
              )}

              {/* Quick-fix result */}
              {quickFixStatus === "success" && quickFixMessage && (
                <Alert severity="success" icon={<CheckCircle />}>
                  <Typography variant="body2">{quickFixMessage}</Typography>
                </Alert>
              )}
              {quickFixStatus === "error" && quickFixMessage && (
                <Alert severity="error" icon={<ErrorOutline />}>
                  <Typography variant="body2">{quickFixMessage}</Typography>
                </Alert>
              )}
            </Stack>
          </DialogContent>
        </Collapse>

        <DialogActions>
          <Button color="inherit" onClick={handleClose}>
            Close
          </Button>
          {(status === "idle" || status === "loading") && (
            <Button
              variant="contained"
              type="submit"
              disabled={!formHook.formState.isValid || status === "loading"}
              startIcon={status === "loading" ? <CircularProgress size={16} /> : <Send />}
            >
              {status === "loading" ? "Inviting..." : "Send Invitation"}
            </Button>
          )}
          {status === "success" && (
            <Button
              variant="contained"
              startIcon={<PersonAdd />}
              onClick={resetForNewGuest}
            >
              Invite Another Guest
            </Button>
          )}
          {status === "error" && (
            <Button
              variant="contained"
              onClick={() => {
                setStatus("idle");
                setDiagnostics(null);
                setBlockedDomain(null);
                setResultMessages([]);
                setDiagLoading(false);
              }}
            >
              Try Again
            </Button>
          )}
        </DialogActions>
      </form>
    </Dialog>
  );
};

export default CippGuestInviteDialog;
