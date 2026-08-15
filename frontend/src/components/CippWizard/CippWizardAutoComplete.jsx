import { Stack, Typography, useMediaQuery, Box, alpha } from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { CippWizardStepButtons } from "./CippWizardStepButtons";
import CippFormComponent from "../CippComponents/CippFormComponent";
import { People } from "@mui/icons-material";

export const CippWizardAutoComplete = (props) => {
  const {
    title,
    type = "single",
    name,
    placeholder,
    api,
    onNextStep,
    formControl,
    currentStep,
    onPreviousStep,
    icon: CustomIcon,
    subtext,
  } = props;

  const currentTenant = formControl.watch("tenantFilter");
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  
  // Use custom icon if provided, otherwise default to People
  const IconComponent = CustomIcon || People;

  return (
    <Stack spacing={smDown ? 1.5 : 2.5}>
      {/* Header - more compact on mobile */}
      <Box sx={{ textAlign: "center", mb: smDown ? 0.5 : 1 }}>
        <Box
          sx={{
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            width: smDown ? 48 : 56,
            height: smDown ? 48 : 56,
            borderRadius: "50%",
            bgcolor: alpha(theme.palette.primary.main, 0.1),
            color: "primary.main",
            mb: 1,
          }}
        >
          <IconComponent sx={{ fontSize: smDown ? 24 : 28 }} />
        </Box>
        <Typography variant={smDown ? "subtitle1" : "h6"} fontWeight={600}>
          {title}
        </Typography>
        {!smDown && (
          <Typography variant="body2" color="text.secondary">
            {subtext || (type === "single" ? "Choose an option to continue" : "Choose one or more options to continue")}
          </Typography>
        )}
      </Box>
      <CippFormComponent
        key={currentTenant ? currentTenant.value : "default"}
        type="autoComplete"
        name={name}
        formControl={formControl}
        placeholder={placeholder || (smDown ? "Search..." : undefined)}
        api={{
          ...api,
          tenantFilter: currentTenant ? currentTenant.value : undefined,
          queryKey: api.queryKey ? api.queryKey.replace('{tenant}', currentTenant ? currentTenant.value : "default") : `${api.url}-${currentTenant ? currentTenant.value : "default"}`,
        }}
        multiple={type === "single" ? false : true}
        disableClearable={true}
        validators={{
          required: { value: true, message: "This field is required" },
        }}
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
