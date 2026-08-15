import { 
  Alert, 
  Stack, 
  Typography, 
  Card, 
  CardContent, 
  Box, 
  Divider, 
  useMediaQuery,
  alpha,
  Chip,
} from "@mui/material";
import { useTheme } from "@mui/material/styles";
import CippWizardStepButtons from "./CippWizardStepButtons";
import CippFormComponent from "../CippComponents/CippFormComponent";
import { CippFormCondition } from "../CippComponents/CippFormCondition";
import CippRiskAlert from "../CippComponents/CippRiskAlert";
import { useWatch } from "react-hook-form";
import { useEffect, useMemo, useState } from "react";
import { Grid } from "@mui/system";
import { useSettings } from "../../hooks/use-settings";
import { ApiGetCall } from "../../api/ApiCall";
import { 
  PersonOff,
  Settings,
  Share,
  Schedule,
  NotificationsActive,
} from "@mui/icons-material";

// Shared mailboxes are capped at 50 GiB without a license; warn at 49 GiB.
const SHARED_MAILBOX_WARN_BYTES = 49 * 1024 ** 3;

export const CippWizardOffboarding = (props) => {
  const { postUrl, formControl, onPreviousStep, onNextStep, currentStep } = props;
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  const currentTenant = formControl.watch("tenantFilter");
  const selectedUsers = useWatch({ control: formControl.control, name: "user" }) || [];
  const [showAlert, setShowAlert] = useState(false);
  const userSettingsDefaults = useSettings().userSettingsDefaults;
  const disableForwarding = useWatch({ control: formControl.control, name: "disableForwarding" });

  // Watch risky offboarding fields for inline coaching
  const watchDeleteUser = useWatch({ control: formControl.control, name: "DeleteUser" });
  const watchClearImmutableId = useWatch({ control: formControl.control, name: "ClearImmutableId" });
  const watchRemoveLicenses = useWatch({ control: formControl.control, name: "RemoveLicenses" });
  const watchRemoveMFADevices = useWatch({ control: formControl.control, name: "RemoveMFADevices" });
  const watchRemoveGroups = useWatch({ control: formControl.control, name: "RemoveGroups" });
  const convertToShared = useWatch({ control: formControl.control, name: "ConvertToShared" });

  // Pull cached mailbox sizes (storageUsedInBytes, keyed by UPN) only when relevant
  const mailboxUsage = ApiGetCall({
    url: "/api/ListMailboxes",
    data: { tenantFilter: currentTenant?.value, UseReportDB: true },
    queryKey: `OffboardingMailboxUsage-${currentTenant?.value}`,
    waiting: !!convertToShared && !!currentTenant?.value && selectedUsers?.length > 0,
  });

  // Selected mailboxes whose cached size would exceed the shared-mailbox limit
  const oversizedMailboxes = useMemo(() => {
    if (!convertToShared || !mailboxUsage.isSuccess || !Array.isArray(mailboxUsage.data)) {
      return [];
    }
    const selectedUpns = (selectedUsers || []).map((u) =>
      (u?.value ?? u)?.toString().toLowerCase(),
    );
    return mailboxUsage.data
      .filter((mb) => {
        const upn = mb?.UPN?.toString().toLowerCase();
        const bytes = Number(mb?.storageUsedInBytes);
        return (
          upn &&
          selectedUpns.includes(upn) &&
          Number.isFinite(bytes) &&
          bytes >= SHARED_MAILBOX_WARN_BYTES
        );
      })
      .map((mb) => ({
        upn: mb.UPN,
        sizeGB: (Number(mb.storageUsedInBytes) / 1024 ** 3).toFixed(1),
      }));
  }, [convertToShared, mailboxUsage.isSuccess, mailboxUsage.data, selectedUsers]);

  useEffect(() => {
    if (selectedUsers.length >= 3) {
      setShowAlert(true);
      formControl.setValue("Scheduled.enabled", true);
    }
  }, [selectedUsers]);

  // Set initial defaults source on component mount if not already set
  useEffect(() => {
    const currentDefaultsSource = formControl.getValues("HIDDEN_defaultsSource");
    if (!currentDefaultsSource) {
      // Default to user defaults since form starts with user defaults from initialState within the wizard component
      formControl.setValue("HIDDEN_defaultsSource", "user");
    }
  }, [formControl]);

  // Apply defaults only once per tenant or when tenant changes
  useEffect(() => {
    const currentTenantId = currentTenant?.value;
    const appliedDefaultsForTenant = formControl.getValues("HIDDEN_appliedDefaultsForTenant");
    
    // Only apply defaults if we haven't applied them for this tenant yet
    if (currentTenantId && appliedDefaultsForTenant !== currentTenantId) {
      const tenantDefaults = currentTenant?.addedFields?.offboardingDefaults;
      
      if (tenantDefaults) {
        // Apply tenant defaults
        Object.entries(tenantDefaults).forEach(([key, value]) => {
          formControl.setValue(key, value);
        });
        // Set the source indicator
        formControl.setValue("HIDDEN_defaultsSource", "tenant");
      } else if (userSettingsDefaults?.offboardingDefaults) {
        // Apply user defaults if no tenant defaults
        userSettingsDefaults.offboardingDefaults.forEach((setting) => {
          formControl.setValue(setting.name, setting.value);
        });
        // Set the source indicator
        formControl.setValue("HIDDEN_defaultsSource", "user");
      }
      
      // Mark that we've applied defaults for this tenant
      formControl.setValue("HIDDEN_appliedDefaultsForTenant", currentTenantId);
    }
  }, [currentTenant?.value, userSettingsDefaults, formControl]);

  useEffect(() => {
    if (disableForwarding) {
      formControl.setValue("forward", null);
      formControl.setValue("KeepCopy", false);
    }
  }, [disableForwarding, formControl]);

  const getDefaultsSource = () => {
    return formControl.getValues("HIDDEN_defaultsSource") || "user";
  };

  return (
    <Stack spacing={smDown ? 2 : 3}>
      {/* Header */}
      <Box sx={{ textAlign: "center" }}>
        <Box
          sx={{
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            width: smDown ? 56 : 72,
            height: smDown ? 56 : 72,
            borderRadius: "50%",
            bgcolor: alpha(theme.palette.error.main, 0.1),
            color: "error.main",
            mb: 1.5,
            border: `2px solid ${alpha(theme.palette.error.main, 0.2)}`,
          }}
        >
          <PersonOff sx={{ fontSize: smDown ? 28 : 36 }} />
        </Box>
        <Typography variant={smDown ? "h6" : "h5"} fontWeight={600} gutterBottom>
          Offboarding Options
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 450, mx: 'auto' }}>
          Configure what actions to take when offboarding the selected user(s)
        </Typography>
      </Box>

      <Grid container spacing={smDown ? 2 : 3}>
        <Grid size={{ xs: 12, lg: 6 }}>
          <Card variant="outlined">
            <Box sx={{ p: smDown ? 2 : 2.5, borderBottom: 1, borderColor: 'divider' }}>
              <Stack direction="row" alignItems="center" justifyContent="space-between">
                <Stack direction="row" spacing={1.5} alignItems="center">
                  <Box
                    sx={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      width: 36,
                      height: 36,
                      borderRadius: 1.5,
                      bgcolor: alpha(theme.palette.primary.main, 0.1),
                      color: "primary.main",
                    }}
                  >
                    <Settings fontSize="small" />
                  </Box>
                  <Typography variant={smDown ? "subtitle1" : "h6"} fontWeight={600}>
                    Offboarding Settings
                  </Typography>
                </Stack>
                <Chip
                  label={getDefaultsSource() === "tenant" ? "Tenant Defaults" : "User Defaults"}
                  size="small"
                  color={getDefaultsSource() === "tenant" ? "primary" : "warning"}
                  variant="outlined"
                />
              </Stack>
            </Box>
            <CardContent sx={{ px: smDown ? 2 : 2.5, py: smDown ? 1.5 : 2 }}>
              <Stack spacing={smDown ? 0.5 : 1}>
                  <CippFormComponent
                    name="ConvertToShared"
                    label="Convert to Shared Mailbox"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="HideFromGAL"
                    label="Hide from Global Address List"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="removeCalendarInvites"
                    label="Cancel all calendar invites"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="removePermissions"
                    label="Remove user's mailbox permissions"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="removeCalendarPermissions"
                    label="Remove user's calendar permissions"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="RemoveRules"
                    label="Remove all Rules"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="RemoveMobile"
                    label="Remove all Mobile Devices"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="RemoveGroups"
                    label="Remove from all groups"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippRiskAlert
                    visible={watchRemoveGroups === true}
                    severity="warning"
                    title="Removes All Group Memberships"
                    description="This removes the user from all groups including security groups, Microsoft 365 groups, and distribution lists. The user may lose access to resources, VPNs, applications, and shared mailboxes tied to group membership."
                    recommendation="Review group memberships first if you need to preserve access to specific resources."
                  />
                  <CippFormComponent
                    name="RemoveLicenses"
                    label="Remove Licenses"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippRiskAlert
                    visible={watchRemoveLicenses === true}
                    severity="warning"
                    title="Immediate License Removal"
                    description="All licenses will be removed immediately. The user will lose access to Exchange mailbox, Teams, SharePoint, and all other licensed services. Mailbox data may be deleted after the retention period."
                    recommendation="Consider converting to a shared mailbox first if you need to preserve mailbox data without a license."
                  />
                  <CippFormComponent
                    name="RevokeSessions"
                    label="Revoke all sessions"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="DisableSignIn"
                    label="Disable Sign in"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="ClearImmutableId"
                    label="Clear Immutable ID"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippRiskAlert
                    visible={watchClearImmutableId === true}
                    severity="error"
                    title="High Risk — Breaks Hybrid Identity Sync"
                    description="Clearing the Immutable ID breaks the link between the on-premises Active Directory object and the Azure AD object. This can cause duplicate accounts, sync failures, and identity mismatches that are difficult to resolve."
                    recommendation="Only use this if you are intentionally decommissioning the on-premises account and understand the sync implications."
                  />
                  <CippFormComponent
                    name="ResetPass"
                    label="Reset Password"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="RemoveMFADevices"
                    label="Remove all MFA Devices"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippRiskAlert
                    visible={watchRemoveMFADevices === true}
                    severity="warning"
                    title="All MFA Methods Will Be Removed"
                    description="All registered MFA devices and methods will be removed. If the user still has sign-in access, their account will revert to password-only authentication until MFA is re-enrolled."
                    recommendation="Ensure sign-in is disabled before removing MFA devices to prevent a window of reduced security."
                  />
                  <CippFormComponent
                    name="RemoveTeamsPhoneDID"
                    label="Remove Teams Phone DID"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="DeleteUser"
                    label="Delete user"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippRiskAlert
                    visible={watchDeleteUser === true}
                    severity="error"
                    title="High Risk — Permanent Account Deletion"
                    description="The user account will be permanently deleted. After the soft-delete retention period (30 days), the account and all associated data (mailbox, OneDrive, Teams chats) cannot be recovered."
                    recommendation="Consider disabling sign-in and removing licenses instead to preserve the ability to restore the account if needed."
                  />
                  {convertToShared && oversizedMailboxes.length > 0 && (
                    <Alert severity="warning" sx={{ mt: 2 }}>
                      The following mailbox{oversizedMailboxes.length > 1 ? "es" : ""} exceed or are
                      near the 50 GB shared mailbox limit. Converting to shared may fail, or the
                      mailbox may stop receiving mail once unlicensed, unless an Exchange Online
                      Plan 2 license is retained:
                      <Box component="ul" sx={{ mt: 1, mb: 0, pl: 2.5 }}>
                        {oversizedMailboxes.map((mb) => (
                          <li key={mb.upn}>
                            {mb.upn} ({mb.sizeGB} GB)
                          </li>
                        ))}
                      </Box>
                    </Alert>
                  )}
                </Stack>
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, lg: 6 }}>
          <Card variant="outlined">
            <Box sx={{ p: smDown ? 2 : 2.5, borderBottom: 1, borderColor: 'divider' }}>
              <Stack direction="row" spacing={1.5} alignItems="center">
                <Box
                  sx={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 36,
                    height: 36,
                    borderRadius: 1.5,
                    bgcolor: alpha(theme.palette.info.main, 0.1),
                    color: "info.main",
                  }}
                >
                  <Share fontSize="small" />
                </Box>
                <Typography variant={smDown ? "subtitle1" : "h6"} fontWeight={600}>
                  Permissions & Forwarding
                </Typography>
              </Stack>
            </Box>
            <CardContent sx={{ px: smDown ? 2 : 2.5, py: smDown ? 1.5 : 2 }}>
              <Stack spacing={smDown ? 2 : 2.5}>
                <Stack spacing={smDown ? 1 : 1.5}>
                  <Typography variant={smDown ? "body2" : "subtitle2"} fontWeight={600} color="text.secondary">
                    Mailbox Access
                  </Typography>
                  <CippFormComponent
                    name="AccessNoAutomap"
                    label="Grant Full Access (no automap)"
                    type="autoComplete"
                    placeholder="Leave blank if not needed"
                    formControl={formControl}
                    multi
                    api={{
                      tenantFilter: currentTenant ? currentTenant.value : undefined,
                      url: "/api/ListGraphRequest",
                      dataKey: "Results",
                      labelField: (option) => `${option.displayName} (${option.userPrincipalName})`,
                      valueField: "userPrincipalName",
                      queryKey: "Offboarding-Users",
                      data: {
                        Endpoint: "users",
                        manualPagination: true,
                        $select: "id,userPrincipalName,displayName",
                        $count: true,
                        $orderby: "displayName",
                        $top: 999,
                      },
                    }}
                  />
                  <CippFormComponent
                    name="AccessAutomap"
                    label="Grant Full Access (automap)"
                    type="autoComplete"
                    placeholder="Leave blank if not needed"
                    formControl={formControl}
                    multi
                    api={{
                      labelField: (option) => `${option.displayName} (${option.userPrincipalName})`,
                      valueField: "userPrincipalName",
                      url: "/api/ListGraphRequest",
                      dataKey: "Results",
                      tenantFilter: currentTenant ? currentTenant.value : undefined,
                      queryKey: "Offboarding-Users",
                      data: {
                        Endpoint: "users",
                        manualPagination: true,
                        $select: "id,userPrincipalName,displayName",
                        $count: true,
                        $orderby: "displayName",
                        $top: 999,
                      },
                    }}
                  />
                  <CippFormComponent
                    name="OnedriveAccess"
                    label="Grant Onedrive Full Access"
                    type="autoComplete"
                    placeholder="Leave blank if not needed"
                    formControl={formControl}
                    multi
                    api={{
                      tenantFilter: currentTenant ? currentTenant.value : undefined,
                      labelField: (option) => `${option.displayName} (${option.userPrincipalName})`,
                      valueField: "userPrincipalName",
                      url: "/api/ListGraphRequest",
                      dataKey: "Results",
                      queryKey: "Offboarding-Users",
                      data: {
                        Endpoint: "users",
                        manualPagination: true,
                        $select: "id,userPrincipalName,displayName",
                        $count: true,
                        $orderby: "displayName",
                        $top: 999,
                      },
                    }}
                  />
                </Stack>

                <Divider />
                <Stack spacing={smDown ? 1 : 1.5}>
                  <Typography variant={smDown ? "body2" : "subtitle2"} fontWeight={600} color="text.secondary">
                    Email Forwarding
                  </Typography>
                  <CippFormComponent
                    name="disableForwarding"
                    label="Disable Email Forwarding"
                    type="switch"
                    formControl={formControl}
                  />

                  <CippFormCondition
                    formControl={formControl}
                    field={"disableForwarding"}
                    compareType="isNot"
                    compareValue={true}
                  >
                    <Stack spacing={smDown ? 1 : 1.5}>
                      <CippFormComponent
                        name="forward"
                        label="Forward Email To"
                        type="autoComplete"
                        placeholder="Leave blank if not needed"
                        formControl={formControl}
                        multiple={false}
                        api={{
                          tenantFilter: currentTenant ? currentTenant.value : undefined,
                          labelField: (option) => `${option.displayName} (${option.userPrincipalName})`,
                          valueField: "userPrincipalName",
                          url: "/api/ListGraphRequest",
                          dataKey: "Results",
                          queryKey: "Offboarding-Users",
                          data: {
                            Endpoint: "users",
                            manualPagination: true,
                            $select: "id,userPrincipalName,displayName",
                            $count: true,
                            $orderby: "displayName",
                            $top: 999,
                          },
                        }}
                      />
                      <CippFormComponent
                        name="KeepCopy"
                        label="Keep a copy of forwarded mail"
                        type="switch"
                        formControl={formControl}
                      />
                    </Stack>
                  </CippFormCondition>
                </Stack>

                <Divider />
                <Stack spacing={smDown ? 1 : 1.5}>
                  <Typography variant={smDown ? "body2" : "subtitle2"} fontWeight={600} color="text.secondary">
                    Out of Office
                  </Typography>
                  <CippFormComponent
                    name="OOO"
                    label="Out of Office Message"
                    type="richText"
                    placeholder="Leave blank to not set"
                    fullWidth
                    formControl={formControl}
                  />
                </Stack>
              </Stack>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {showAlert && (
        <Alert severity="warning" sx={{ py: smDown ? 1 : 1.5 }}>
          {smDown 
            ? "3+ users selected. Scheduling required." 
            : "You have selected more than 2 users. This offboarding must be scheduled."
          }
        </Alert>
      )}

      <Card variant="outlined">
        <Box sx={{ p: smDown ? 2 : 2.5, borderBottom: 1, borderColor: 'divider' }}>
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Box
              sx={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                width: 36,
                height: 36,
                borderRadius: 1.5,
                bgcolor: alpha(theme.palette.warning.main, 0.1),
                color: "warning.main",
              }}
            >
              <Schedule fontSize="small" />
            </Box>
            <Typography variant={smDown ? "subtitle1" : "h6"} fontWeight={600}>
              Scheduling & Notifications
            </Typography>
          </Stack>
        </Box>
        <CardContent sx={{ px: smDown ? 2 : 2.5, py: smDown ? 1.5 : 2 }}>
          <Grid container spacing={{ xs: 1.5, md: 3 }}>
            <Grid size={{ xs: 12 }}>
              <CippFormComponent
                name="Scheduled.enabled"
                label="Schedule this offboarding"
                type="switch"
                formControl={formControl}
              />
            </Grid>

            <CippFormCondition
              formControl={formControl}
              field={"Scheduled.enabled"}
              compareType="is"
              compareValue={true}
            >
              <Grid size={{ sm: 6, xs: 12 }}>
                <Typography variant={smDown ? "body2" : "subtitle2"} fontWeight={600} color="text.secondary" sx={{ mb: 0.5 }}>
                  Scheduled Offboarding Date
                </Typography>
                <CippFormComponent
                  name="Scheduled.date"
                  type="datePicker"
                  formControl={formControl}
                  fullWidth
                />
              </Grid>

              <Grid size={{ sm: 6, xs: 12 }}>
                <Typography variant={smDown ? "body2" : "subtitle2"} fontWeight={600} color="text.secondary" sx={{ mb: 0.5 }}>
                  Send results to:
                </Typography>
                <Stack spacing={smDown ? 0.5 : 1}>
                  <CippFormComponent
                    name="postExecution.webhook"
                    label="Webhook"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="postExecution.email"
                    label="E-mail"
                    type="switch"
                    formControl={formControl}
                  />
                  <CippFormComponent
                    name="postExecution.psa"
                    label="PSA"
                    type="switch"
                    formControl={formControl}
                  />
                </Stack>
              </Grid>

              <Grid size={{ xs: 12 }}>
                <CippFormComponent
                  type="textField"
                  fullWidth
                  label="Reference"
                  name="reference"
                  placeholder={smDown ? "Add a reference" : "Enter a reference that will be added to the notification title and scheduled task"}
                  formControl={formControl}
                />
              </Grid>
            </CippFormCondition>
          </Grid>
        </CardContent>
      </Card>

      <CippWizardStepButtons
        postUrl={postUrl}
        currentStep={currentStep}
        onPreviousStep={onPreviousStep}
        onNextStep={onNextStep}
        formControl={formControl}
        replacementBehaviour="removeNulls"
        sticky={true}
      />
    </Stack>
  );
};
