import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { useState, useCallback, useEffect } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CardHeader,
  Chip,
  CircularProgress,
  Divider,
  Grid,
  IconButton,
  Stack,
  Step,
  StepLabel,
  Stepper,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from "@mui/material";
import {
  Add,
  ArrowBack,
  ArrowForward,
  CheckCircle,
  Close,
  ErrorOutline,
  Groups,
  Language,
  PersonAdd,
  Send,
  Share,
  Warning,
} from "@mui/icons-material";
import CippFormComponent from "../../../components/CippComponents/CippFormComponent";
import { ApiPostCall } from "../../../api/ApiCall";
import { useSettings } from "../../../hooks/use-settings";
import { CippHead } from "../../../components/CippComponents/CippHead.jsx";
import CippAccessTypeGuide from "../../../components/CippComponents/CippAccessTypeGuide.jsx";
import axios from "axios";
import { buildVersionedHeaders } from "../../../utils/cippVersion";

const STEPS = ["Who", "Where", "Review", "Execute"];

const CONSUMER_DOMAINS = new Set([
  "gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "aol.com",
  "icloud.com", "live.com", "msn.com", "me.com", "protonmail.com",
  "zoho.com", "yandex.com", "mail.com", "gmx.com", "inbox.com",
]);

const Page = () => {
  const settings = useSettings();
  const currentTenant = settings.currentTenant;
  const [activeStep, setActiveStep] = useState(0);
  const [validations, setValidations] = useState({});
  const [validating, setValidating] = useState({});
  const [executionResults, setExecutionResults] = useState([]);
  const [executing, setExecuting] = useState(false);

  const formHook = useForm({
    defaultValues: {
      guests: [{ email: "", displayName: "" }],
      resourceType: "sharepoint",
      resourceId: null,
      resourceName: "",
      sendInvite: true,
    },
    mode: "onChange",
  });

  const { fields: guestFields, append: appendGuest, remove: removeGuest } = useFieldArray({
    control: formHook.control,
    name: "guests",
  });

  const inviteApi = ApiPostCall({});

  const watchedResourceType = formHook.watch("resourceType");
  const watchedResourceId = formHook.watch("resourceId");
  const watchedGuests = formHook.watch("guests");

  useEffect(() => {
    formHook.setValue("resourceId", null);
  }, [watchedResourceType, formHook]);

  const validateEmail = useCallback(
    async (email, index) => {
      if (!email || !email.includes("@") || !currentTenant) return;
      setValidating((prev) => ({ ...prev, [index]: true }));
      try {
        const headers = await buildVersionedHeaders();
        const resp = await axios.post(
          "/api/ExecValidateExternalDomain",
          { email, tenantFilter: currentTenant, context: formHook.getValues("resourceType") === "teams-shared" ? "teams-shared" : "general" },
          { headers }
        );
        setValidations((prev) => ({ ...prev, [index]: resp.data?.Results }));
      } catch {
        setValidations((prev) => ({ ...prev, [index]: { domainType: "unknown", canProceed: true, policyChecks: [] } }));
      } finally {
        setValidating((prev) => ({ ...prev, [index]: false }));
      }
    },
    [currentTenant, formHook]
  );

  const isAnyValidating = Object.values(validating).some((v) => v);

  const hasConsumerByDomain = watchedGuests.some((g) => {
    const domain = g.email?.split("@")[1]?.toLowerCase();
    return domain && CONSUMER_DOMAINS.has(domain);
  });
  const hasConsumerEmails =
    hasConsumerByDomain || Object.values(validations).some((v) => v?.domainType === "consumer");
  const hasBlockedPolicies = Object.values(validations).some((v) => v?.canProceed === false);
  const allValidated = guestFields.every((_, i) => validations[i]);

  // Shared channels (B2B Direct Connect) don't support consumer accounts; fall
  // back to SharePoint if a personal email appears after the type was chosen.
  // This effect must stay below the hasConsumerEmails declaration: consts are
  // not hoisted, and referencing it earlier crashes the page at render time.
  useEffect(() => {
    if (hasConsumerEmails && watchedResourceType === "teams-shared") {
      formHook.setValue("resourceType", "sharepoint");
    }
  }, [hasConsumerEmails, watchedResourceType, formHook]);

  const handleNext = () => {
    if (activeStep < STEPS.length - 1) {
      setActiveStep(activeStep + 1);
    }
  };

  const handleBack = () => {
    if (activeStep > 0) {
      setActiveStep(activeStep - 1);
    }
  };

  const handleExecute = async () => {
    const data = formHook.getValues();

    if (data.resourceType === "teams-shared") {
      const blocked = data.guests.filter((g, i) => {
        const domain = g.email?.split("@")[1]?.toLowerCase();
        return CONSUMER_DOMAINS.has(domain) || validations[i]?.domainType === "consumer";
      });
      if (blocked.length > 0) {
        setExecutionResults(blocked.map((g) => ({
          email: g.email,
          status: "error",
          messages: ["Personal email addresses cannot use shared channels (B2B Direct Connect). Use a work/school account or choose a different resource type."],
        })));
        setActiveStep(3);
        return;
      }
    }

    setExecuting(true);
    setExecutionResults([]);
    const results = [];

    for (const guest of data.guests) {
      try {
        const headers = await buildVersionedHeaders();
        const payload = {
          tenantFilter: currentTenant,
          displayName: guest.displayName || guest.email.split("@")[0],
          mail: guest.email,
          sendInvite: data.sendInvite,
        };

        const resourceIdValue = data.resourceId?.value || data.resourceId;

        if (data.resourceType === "sharepoint") {
          payload.URL = resourceIdValue;
          payload.SharePointType = data.resourceId?.addedFields?.SharePointType || "Group";
          payload.groupId = data.groupId;
        } else if (data.resourceType === "teams-shared") {
          payload.TeamID = data.resourceId?.addedFields?.teamId || resourceIdValue;
          payload.ChannelID = resourceIdValue;
        } else if (data.resourceType === "teams-standard") {
          payload.TeamID = resourceIdValue;
        }

        const resp = await axios.post("/api/ExecSharePointInviteGuest", payload, { headers });
        results.push({
          email: guest.email,
          status: "success",
          messages: resp.data?.Results || ["Invitation sent successfully."],
        });
      } catch (err) {
        results.push({
          email: guest.email,
          status: "error",
          messages: err?.response?.data?.Results || [err?.message || "Failed to invite guest."],
        });
      }
    }

    setExecutionResults(results);
    setExecuting(false);
    setActiveStep(3);
  };

  const canProceedFromStep = (step) => {
    switch (step) {
      case 0:
        return (
          watchedGuests.length > 0 &&
          watchedGuests.every((g) => g.email && g.email.includes("@")) &&
          allValidated &&
          !isAnyValidating
        );
      case 1:
        return Boolean(watchedResourceId?.value || watchedResourceId);
      case 2:
        return !hasBlockedPolicies && !(hasConsumerEmails && watchedResourceType === "teams-shared");
      default:
        return false;
    }
  };

  return (
    <>
      <CippHead title="External Access Wizard" />
      <Box sx={{ p: 3 }}>
        <Typography variant="h4" sx={{ mb: 1 }}>
          External Access Wizard
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
          Grant external users access to SharePoint sites and Teams. The wizard validates policies, recommends the right access type, and handles the invitation flow.
        </Typography>

        {!currentTenant && (
          <Alert severity="info">Select a tenant to use the External Access Wizard.</Alert>
        )}

        {currentTenant && (
          <>
            <Stepper activeStep={activeStep} sx={{ mb: 4 }}>
              {STEPS.map((label) => (
                <Step key={label}>
                  <StepLabel>{label}</StepLabel>
                </Step>
              ))}
            </Stepper>

            {/* Step 1: Who */}
            {activeStep === 0 && (
              <Card>
                <CardHeader title="Who needs access?" subheader="Enter the email addresses of external users you want to invite." />
                <CardContent>
                  <Stack spacing={2}>
                    {guestFields.map((field, index) => (
                      <Card key={field.id} variant="outlined">
                        <CardContent sx={{ py: 1.5, "&:last-child": { pb: 1.5 } }}>
                          <Grid container spacing={2} alignItems="flex-start">
                            <Grid item xs={12} sm={5}>
                              <CippFormComponent
                                formControl={formHook}
                                type="textField"
                                name={`guests.${index}.email`}
                                label="Email Address"
                                placeholder="user@example.com"
                                validators={{
                                  required: "Email is required",
                                  pattern: { value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i, message: "Invalid email" },
                                  onBlur: (e) => validateEmail(e.target.value, index),
                                }}
                              />
                            </Grid>
                            <Grid item xs={12} sm={5}>
                              <CippFormComponent
                                formControl={formHook}
                                type="textField"
                                name={`guests.${index}.displayName`}
                                label="Display Name (Optional)"
                                placeholder="Guest Name"
                              />
                            </Grid>
                            <Grid item xs={12} sm={2} sx={{ display: "flex", alignItems: "center", pt: 1 }}>
                              {guestFields.length > 1 && (
                                <IconButton size="small" onClick={() => { removeGuest(index); setValidations((p) => { const n = { ...p }; delete n[index]; return n; }); }}>
                                  <Close fontSize="small" />
                                </IconButton>
                              )}
                            </Grid>
                          </Grid>

                          {validating[index] && (
                            <Stack direction="row" alignItems="center" spacing={1} sx={{ mt: 1 }}>
                              <CircularProgress size={14} />
                              <Typography variant="caption" color="text.secondary">Validating...</Typography>
                            </Stack>
                          )}

                          {validations[index] && !validating[index] && (
                            <Stack spacing={0.5} sx={{ mt: 1 }}>
                              <Stack direction="row" spacing={1} alignItems="center">
                                <Chip
                                  size="small"
                                  label={validations[index].domainType === "consumer" ? "Personal Email" : validations[index].domainType === "organizational" ? "Work/School" : "Unknown"}
                                  color={validations[index].domainType === "consumer" ? "warning" : "info"}
                                />
                                {validations[index].existingGuest && (
                                  <Chip size="small" label="Already a guest" color="success" variant="outlined" />
                                )}
                                {validations[index].canProceed === false && (
                                  <Chip size="small" label="Policy block" color="error" />
                                )}
                              </Stack>
                              {validations[index].policyChecks?.filter((c) => c.status === "fail").map((c, ci) => (
                                <Alert key={ci} severity="error" sx={{ py: 0.25, mt: 0.5 }}>
                                  <Typography variant="caption"><strong>{c.source}:</strong> {c.detail}</Typography>
                                </Alert>
                              ))}
                            </Stack>
                          )}
                        </CardContent>
                      </Card>
                    ))}

                    <Button startIcon={<Add />} onClick={() => appendGuest({ email: "", displayName: "" })} sx={{ alignSelf: "flex-start", textTransform: "none" }}>
                      Add Another Guest
                    </Button>

                    {!allValidated && !isAnyValidating && watchedGuests.some((g) => g.email?.includes("@")) && (
                      <Alert severity="info" sx={{ py: 0.5 }}>
                        <Typography variant="caption">
                          Click into each email field and tab out to validate before proceeding.
                        </Typography>
                      </Alert>
                    )}
                  </Stack>
                </CardContent>
              </Card>
            )}

            {/* Step 2: Where */}
            {activeStep === 1 && (
              <Card>
                <CardHeader title="Where should they have access?" subheader="Select the target resource." />
                <CardContent>
                  <Stack spacing={3}>
                    <Box>
                      <Typography variant="subtitle2" sx={{ mb: 1 }}>Resource Type</Typography>
                      <ToggleButtonGroup
                        value={watchedResourceType}
                        exclusive
                        onChange={(_, val) => { if (val !== null) formHook.setValue("resourceType", val); }}
                        fullWidth
                        sx={{
                          "& .MuiToggleButton-root": {
                            textTransform: "none",
                            py: 1.5,
                            flexDirection: "column",
                            gap: 0.5,
                          },
                        }}
                      >
                        <ToggleButton value="sharepoint">
                          <Language />
                          <Typography variant="body2">SharePoint Site</Typography>
                        </ToggleButton>
                        <ToggleButton value="teams-standard">
                          <Groups />
                          <Typography variant="body2">Teams (Standard)</Typography>
                        </ToggleButton>
                        {!hasConsumerEmails && (
                          <ToggleButton value="teams-shared">
                            <Share />
                            <Typography variant="body2">Teams (Shared Channel)</Typography>
                          </ToggleButton>
                        )}
                      </ToggleButtonGroup>
                    </Box>

                    <Box>
                      <Typography variant="subtitle2" sx={{ mb: 1 }}>
                        {watchedResourceType === "sharepoint" ? "SharePoint Site" :
                         watchedResourceType === "teams-shared" ? "Shared Channel" : "Team"}
                      </Typography>
                      {watchedResourceType === "sharepoint" && (
                        <CippFormComponent
                          key="sharepoint-picker"
                          formControl={formHook}
                          type="autoComplete"
                          name="resourceId"
                          label="Search or enter a site URL"
                          multiple={false}
                          creatable={true}
                          size="medium"
                          api={{
                            url: "/api/ListSites",
                            data: { type: "SharePointSiteUsage" },
                            queryKey: `extaccess-sites-${currentTenant}`,
                            labelField: (site) => site.displayName ? `${site.displayName} (${site.webUrl})` : site.webUrl,
                            valueField: "webUrl",
                            addedField: {
                              SharePointType: "rootWebTemplate",
                              displayName: "displayName",
                            },
                          }}
                          validators={{ required: "Please select a SharePoint site" }}
                        />
                      )}
                      {watchedResourceType === "teams-standard" && (
                        <CippFormComponent
                          key="teams-picker"
                          formControl={formHook}
                          type="autoComplete"
                          name="resourceId"
                          label="Search or enter a Team name"
                          multiple={false}
                          creatable={true}
                          size="medium"
                          api={{
                            url: "/api/ListTeams",
                            data: { type: "list" },
                            queryKey: `extaccess-teams-${currentTenant}`,
                            labelField: (team) => team.displayName || team.id,
                            valueField: "id",
                            addedField: {
                              displayName: "displayName",
                            },
                          }}
                          validators={{ required: "Please select a Team" }}
                        />
                      )}
                      {watchedResourceType === "teams-shared" && (
                        <CippFormComponent
                          key="shared-channel-picker"
                          formControl={formHook}
                          type="autoComplete"
                          name="resourceId"
                          label="Select a shared channel"
                          multiple={false}
                          creatable={false}
                          size="medium"
                          api={{
                            url: "/api/ListTeams",
                            data: { type: "SharedChannels" },
                            queryKey: `extaccess-sharedchannels-${currentTenant}`,
                            labelField: (ch) => ch.teamName ? `${ch.teamName} → ${ch.displayName}` : ch.displayName,
                            valueField: "id",
                            addedField: {
                              teamId: "teamId",
                              teamName: "teamName",
                              displayName: "displayName",
                            },
                          }}
                          validators={{ required: "Please select a shared channel" }}
                        />
                      )}
                    </Box>

                    <Box>
                      <CippFormComponent
                        formControl={formHook}
                        type="switch"
                        name="sendInvite"
                        label="Send email invitation to guests"
                      />
                    </Box>

                    {hasConsumerEmails && (
                      <Alert severity="info">
                        Some guests have personal email addresses. Teams shared channels are not available as a target since they require work/school accounts.
                      </Alert>
                    )}

                    <CippAccessTypeGuide
                      variant="decision"
                      context={
                        watchedResourceType === "sharepoint" ? "sharepoint" :
                        watchedResourceType === "teams-shared" ? "teamsShared" :
                        "teamsStandard"
                      }
                    />
                  </Stack>
                </CardContent>
              </Card>
            )}

            {/* Step 3: Review */}
            {activeStep === 2 && (() => {
              const reviewData = formHook.getValues();
              const resourceLabel = reviewData.resourceId?.label || reviewData.resourceId?.value || reviewData.resourceId;
              const isShared = reviewData.resourceType === "teams-shared";
              const isSharePoint = reviewData.resourceType === "sharepoint";
              const isTeamsStandard = reviewData.resourceType === "teams-standard";

              return (
                <Stack spacing={3}>
                  <Card>
                    <CardHeader title="Review Proposed Changes" subheader="Verify the actions below before proceeding. No changes will be made until you confirm." />
                    <CardContent>
                      <Stack spacing={3}>
                        {/* Access method */}
                        <Box>
                          <Typography variant="subtitle2" gutterBottom>Access Method</Typography>
                          <Alert severity="info" variant="outlined" icon={false}>
                            {isShared ? (
                              <>
                                <Typography variant="body2" sx={{ fontWeight: 600 }}>B2B Direct Connect (External Access)</Typography>
                                <Typography variant="body2" color="text.secondary">
                                  Users will access the shared channel from their own tenant. They are NOT added to your directory.
                                  Requires work/school accounts — personal emails are not supported.
                                </Typography>
                              </>
                            ) : (
                              <>
                                <Typography variant="body2" sx={{ fontWeight: 600 }}>B2B Collaboration (Guest Access)</Typography>
                                <Typography variant="body2" color="text.secondary">
                                  Users will be invited as guest accounts in your Entra ID directory,
                                  then granted access to the {isSharePoint ? "SharePoint site" : "Team"}.
                                  {reviewData.sendInvite ? " An email invitation will be sent." : " No email invitation will be sent."}
                                </Typography>
                              </>
                            )}
                          </Alert>
                        </Box>

                        {/* Target resource */}
                        <Box>
                          <Typography variant="subtitle2" gutterBottom>Target Resource</Typography>
                          <Card variant="outlined">
                            <CardContent sx={{ py: 1.5, "&:last-child": { pb: 1.5 } }}>
                              <Stack direction="row" spacing={1} alignItems="center">
                                {isSharePoint ? <Language color="action" /> : isShared ? <Share color="action" /> : <Groups color="action" />}
                                <Box>
                                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                    {isSharePoint ? "SharePoint Site" : isShared ? "Shared Channel" : "Team"}
                                  </Typography>
                                  <Typography variant="body2" color="text.secondary">{resourceLabel}</Typography>
                                </Box>
                              </Stack>
                            </CardContent>
                          </Card>
                        </Box>

                        <Divider />

                        {/* Per-guest action plan */}
                        <Box>
                          <Typography variant="subtitle2" gutterBottom>
                            Actions per Guest ({reviewData.guests.length})
                          </Typography>
                          <Stack spacing={1.5}>
                            {reviewData.guests.map((guest, i) => {
                              const domain = guest.email?.split("@")[1]?.toLowerCase();
                              const isConsumer = CONSUMER_DOMAINS.has(domain) || validations[i]?.domainType === "consumer";
                              const isExisting = validations[i]?.existingGuest;
                              const isBlocked = validations[i]?.canProceed === false;
                              const consumerSharedConflict = isConsumer && isShared;

                              return (
                                <Card key={i} variant="outlined" sx={isBlocked || consumerSharedConflict ? { borderColor: "error.main" } : undefined}>
                                  <CardContent sx={{ py: 1.5, "&:last-child": { pb: 1.5 } }}>
                                    <Stack spacing={1}>
                                      <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                                        <PersonAdd fontSize="small" color="action" />
                                        <Typography variant="body2" sx={{ fontWeight: 600 }}>{guest.email}</Typography>
                                        {guest.displayName && (
                                          <Typography variant="caption" color="text.secondary">({guest.displayName})</Typography>
                                        )}
                                        {isConsumer && <Chip size="small" label="Personal Email" color="warning" variant="outlined" />}
                                        {isExisting && <Chip size="small" label="Existing Guest" color="success" variant="outlined" />}
                                        {isBlocked && <Chip size="small" label="Blocked" color="error" />}
                                      </Stack>

                                      {consumerSharedConflict ? (
                                        <Alert severity="error" sx={{ py: 0.25 }}>
                                          <Typography variant="caption">
                                            Personal email addresses cannot be used with shared channels (B2B Direct Connect requires a work/school account).
                                            Go back and choose a different resource type, or remove this guest.
                                          </Typography>
                                        </Alert>
                                      ) : isBlocked ? (
                                        <Alert severity="error" sx={{ py: 0.25 }}>
                                          <Typography variant="caption">
                                            Policy checks failed for this guest. Go back to resolve, or use the Sharing Troubleshooter.
                                          </Typography>
                                        </Alert>
                                      ) : (
                                        <Stack spacing={0.25} sx={{ pl: 3.5 }}>
                                          {!isShared && !isExisting && (
                                            <Typography variant="caption" color="text.secondary">
                                              1. Create guest account in your directory
                                            </Typography>
                                          )}
                                          {!isShared && isExisting && (
                                            <Typography variant="caption" color="text.secondary">
                                              1. Use existing guest account (already in directory)
                                            </Typography>
                                          )}
                                          {!isShared && reviewData.sendInvite && (
                                            <Typography variant="caption" color="text.secondary">
                                              2. Send email invitation to {guest.email}
                                            </Typography>
                                          )}
                                          {isSharePoint && (
                                            <Typography variant="caption" color="text.secondary">
                                              {reviewData.sendInvite ? "3" : "2"}. Add to SharePoint site members
                                            </Typography>
                                          )}
                                          {isTeamsStandard && (
                                            <Typography variant="caption" color="text.secondary">
                                              {reviewData.sendInvite ? "3" : "2"}. Add as Team member
                                            </Typography>
                                          )}
                                          {isShared && (
                                            <Typography variant="caption" color="text.secondary">
                                              1. Add to shared channel via B2B Direct Connect
                                            </Typography>
                                          )}
                                        </Stack>
                                      )}
                                    </Stack>
                                  </CardContent>
                                </Card>
                              );
                            })}
                          </Stack>
                        </Box>

                        {/* Warnings summary */}
                        {hasBlockedPolicies && (
                          <Alert severity="error">
                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                              One or more guests have policy blocks. Go back and resolve the issues or use the Sharing Troubleshooter.
                            </Typography>
                          </Alert>
                        )}
                        {hasConsumerEmails && isShared && (
                          <Alert severity="error">
                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                              Personal email addresses are not compatible with shared channels. Change the resource type or remove the affected guests.
                            </Typography>
                          </Alert>
                        )}
                      </Stack>
                    </CardContent>
                  </Card>
                </Stack>
              );
            })()}

            {/* Step 4: Execute / Results */}
            {activeStep === 3 && (
              <Card>
                <CardHeader title="Results" />
                <CardContent>
                  {executing && (
                    <Stack alignItems="center" spacing={2} sx={{ py: 4 }}>
                      <CircularProgress />
                      <Typography variant="body1" color="text.secondary">Sending invitations...</Typography>
                    </Stack>
                  )}

                  {!executing && executionResults.length > 0 && (
                    <Stack spacing={2}>
                      {executionResults.map((result, i) => (
                        <Alert key={i} severity={result.status === "success" ? "success" : "error"} icon={result.status === "success" ? <CheckCircle /> : <ErrorOutline />}>
                          <Typography variant="body2" sx={{ fontWeight: 600 }}>{result.email}</Typography>
                          {result.messages.map((msg, mi) => (
                            <Typography key={mi} variant="body2">{msg}</Typography>
                          ))}
                        </Alert>
                      ))}

                      <Alert severity="info" variant="outlined" sx={{ mt: 2 }}>
                        <Typography variant="body2">
                          It may take a few minutes for guests to appear in the target resource. If a guest reports issues accessing the resource, use the Sharing Troubleshooter to diagnose.
                        </Typography>
                      </Alert>
                    </Stack>
                  )}
                </CardContent>
              </Card>
            )}

            {/* Navigation */}
            <Stack direction="row" justifyContent="space-between" sx={{ mt: 3 }}>
              <Button
                startIcon={<ArrowBack />}
                onClick={handleBack}
                disabled={activeStep === 0 || activeStep === 3}
                sx={{ textTransform: "none" }}
              >
                Back
              </Button>

              {activeStep < 2 && (
                <Button
                  variant="contained"
                  endIcon={<ArrowForward />}
                  onClick={handleNext}
                  disabled={!canProceedFromStep(activeStep)}
                  sx={{ textTransform: "none" }}
                >
                  Next
                </Button>
              )}

              {activeStep === 2 && (
                <Button
                  variant="contained"
                  color="success"
                  startIcon={<Send />}
                  onClick={handleExecute}
                  disabled={!canProceedFromStep(2) || executing}
                  sx={{ textTransform: "none" }}
                >
                  Confirm &amp; Send Invitations
                </Button>
              )}

              {activeStep === 3 && (
                <Button
                  variant="outlined"
                  onClick={() => {
                    setActiveStep(0);
                    setExecutionResults([]);
                    setValidations({});
                    formHook.reset();
                  }}
                  sx={{ textTransform: "none" }}
                >
                  Start New Wizard
                </Button>
              )}
            </Stack>
          </>
        )}
      </Box>
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
