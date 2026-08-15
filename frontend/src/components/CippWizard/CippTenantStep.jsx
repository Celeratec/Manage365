import { Stack, Typography, useMediaQuery, Box, alpha } from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { CippWizardStepButtons } from "./CippWizardStepButtons";
import { CippFormTenantSelector } from "../CippComponents/CippFormTenantSelector";
import { Business } from "@mui/icons-material";

export const CippTenantStep = (props) => {
  const {
    allTenants,
    type = "single",
    valueField = "defaultDomainName",
    onNextStep,
    formControl,
    currentStep,
    onPreviousStep,
    preText,
    includeOffboardingDefaults = false,
  } = props;
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));

  return (
    <Stack spacing={smDown ? 2 : 3}>
      {preText}
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
            bgcolor: alpha(theme.palette.primary.main, 0.1),
            color: "primary.main",
            mb: 1.5,
            border: `2px solid ${alpha(theme.palette.primary.main, 0.2)}`,
          }}
        >
          <Business sx={{ fontSize: smDown ? 28 : 36 }} />
        </Box>
        <Typography variant={smDown ? "h6" : "h5"} fontWeight={600} gutterBottom>
          {type === "multiple" ? "Select Tenants" : "Select a Tenant"}
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 400, mx: 'auto' }}>
          {type === "multiple" 
            ? "Choose one or more tenants to apply this action to"
            : "Start typing to search and select a tenant"
          }
        </Typography>
      </Box>
      <CippFormTenantSelector
        valueField={valueField}
        formControl={formControl}
        allTenants={allTenants}
        type={type}
        includeOffboardingDefaults={includeOffboardingDefaults}
        preselectedEnabled={true}
      />
      <CippWizardStepButtons
        currentStep={currentStep}
        onPreviousStep={onPreviousStep}
        onNextStep={onNextStep}
        formControl={formControl}
      />
    </Stack>
  );
};
