import { useState, useEffect, useMemo } from "react";
import { Alert, Box, Button, Typography } from "@mui/material";
import { Grid } from "@mui/system";
import { useForm, useFormState } from "react-hook-form";
import { Send } from "@mui/icons-material";
import { CippOffCanvas } from "./CippOffCanvas";
import CippFormComponent from "./CippFormComponent";
import { CippApiResults } from "./CippApiResults";
import CippAccessTypeGuide from "./CippAccessTypeGuide";
import { useSettings } from "../../hooks/use-settings";
import { ApiPostCall } from "../../api/ApiCall";
import { getCippValidator } from "../../utils/get-cipp-validator";

const CONSUMER_DOMAINS = new Set([
  "gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "aol.com",
  "icloud.com", "live.com", "msn.com", "protonmail.com", "zoho.com",
  "ymail.com", "mail.com", "gmx.com", "fastmail.com",
]);

export const CippInviteGuestDrawer = ({
  buttonText = "Invite Guest",
  requiredPermissions = [],
  PermissionButton = Button,
  buttonProps = {},
}) => {
  const [drawerVisible, setDrawerVisible] = useState(false);
  const userSettingsDefaults = useSettings();

  const formControl = useForm({
    mode: "onBlur",
    defaultValues: {
      tenantFilter: userSettingsDefaults.currentTenant,
      displayName: "",
      mail: "",
      redirectUri: "",
      message: "",
      sendInvite: true,
    },
  });

  const { isValid } = useFormState({ control: formControl.control });

  const watchedEmail = formControl.watch("mail");
  const consumerDomain = useMemo(() => {
    if (!watchedEmail || !watchedEmail.includes("@")) return null;
    const domain = watchedEmail.split("@")[1]?.toLowerCase();
    return domain && CONSUMER_DOMAINS.has(domain) ? domain : null;
  }, [watchedEmail]);

  const inviteGuest = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [`Users-${userSettingsDefaults.currentTenant}`],
  });

  // Reset form fields on successful invitation
  useEffect(() => {
    if (inviteGuest.isSuccess) {
      formControl.reset();
    }
  }, [inviteGuest.isSuccess, formControl]);

  const handleSubmit = () => {
    formControl.trigger();
    // Check if the form is valid before proceeding
    if (!isValid) {
      return;
    }
    const formData = formControl.getValues();
    inviteGuest.mutate({
      url: "/api/AddGuest",
      data: formData,
      relatedQueryKeys: [`Users-${userSettingsDefaults.currentTenant}`],
    });
  };

  const handleCloseDrawer = () => {
    setDrawerVisible(false);
    formControl.reset({
      tenantFilter: userSettingsDefaults.currentTenant,
      displayName: "",
      mail: "",
      redirectUri: "",
      message: "",
      sendInvite: true,
    });
  };

  const handleOpenDrawer = () => {
    formControl.reset({
      tenantFilter: userSettingsDefaults.currentTenant,
      displayName: "",
      mail: "",
      redirectUri: "",
      message: "",
      sendInvite: true,
    });
    setDrawerVisible(true);
  };

  return (
    <>
      <PermissionButton
        requiredPermissions={requiredPermissions}
        onClick={handleOpenDrawer}
        startIcon={<Send />}
        {...buttonProps}
      >
        {buttonText}
      </PermissionButton>
      <CippOffCanvas
        title="Invite Guest User"
        visible={drawerVisible}
        onClose={handleCloseDrawer}
        size="md"
        footer={
          <div style={{ display: "flex", gap: "8px", justifyContent: "flex-start" }}>
            <Button
              variant="contained"
              color="primary"
              onClick={handleSubmit}
              disabled={inviteGuest.isLoading || !isValid}
            >
              {inviteGuest.isLoading
                ? "Sending Invite..."
                : inviteGuest.isSuccess
                  ? "Send Another Invite"
                  : "Send Invite"}
            </Button>
            <Button variant="outlined" onClick={handleCloseDrawer}>
              Close
            </Button>
          </div>
        }
      >
        <Box sx={{ mb: 2 }}>
          <CippAccessTypeGuide
            type="guest"
            variant="banner"
            context="userManagement"
            showSettingsLinks={false}
          />
        </Box>
        <Grid container spacing={2}>
          <Grid size={{ md: 6, xs: 12 }}>
            <CippFormComponent
              type="textField"
              fullWidth
              label="Display Name"
              name="displayName"
              formControl={formControl}
              validators={{ required: "Display name is required" }}
            />
          </Grid>
          <Grid size={{ md: 6, xs: 12 }}>
            <CippFormComponent
              type="textField"
              fullWidth
              label="E-mail Address"
              name="mail"
              formControl={formControl}
              validators={{
                required: "Email address is required",
                validate: (value) => !value || getCippValidator(value, "email"),
              }}
            />
          </Grid>
          {consumerDomain && (
            <Grid size={{ md: 12, xs: 12 }}>
              <Alert severity="info" sx={{ py: 0.5 }}>
                <Typography variant="caption">
                  <strong>{consumerDomain}</strong> is a personal email domain. The guest will authenticate via Email One-Time Passcode (OTP) instead of a Microsoft account.
                </Typography>
              </Alert>
            </Grid>
          )}
          <Grid size={{ md: 12, xs: 12 }}>
            <CippFormComponent
              type="textField"
              fullWidth
              label="Redirect URL"
              name="redirectUri"
              placeholder="Optional Redirect URL defaults to https://myapps.microsoft.com if blank"
              formControl={formControl}
            />
          </Grid>
          <Grid size={{ md: 12, xs: 12 }}>
            <CippFormComponent
              type="textField"
              fullWidth
              label="Custom invite message"
              name="message"
              multiline
              minRows={3}
              placeholder="Optional message included in the invite email"
              formControl={formControl}
            />
          </Grid>
          <Grid size={{ md: 12, xs: 12 }}>
            <CippFormComponent
              type="switch"
              fullWidth
              label="Send invite via e-mail"
              name="sendInvite"
              formControl={formControl}
            />
          </Grid>

          <CippApiResults apiObject={inviteGuest} />
        </Grid>
      </CippOffCanvas>
    </>
  );
};
