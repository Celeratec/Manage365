import { 
  Box, 
  Card, 
  CardContent, 
  Stack, 
  SvgIcon, 
  Typography, 
  alpha,
  useMediaQuery,
} from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { useEffect, useState } from "react";
import { CippWizardStepButtons } from "./CippWizardStepButtons";
import { Checklist, Check } from "@mui/icons-material";

export const CippWizardOptionsList = (props) => {
  const {
    onNextStep,
    options,
    title,
    subtext,
    formControl,
    currentStep,
    onPreviousStep,
    name = "selectedOption",
  } = props;
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  const [selectedOption, setSelectedOption] = useState(null);
  
  // Register the name field in react-hook-form
  formControl.register(name, {
    required: true,
  });

  //only perform a reset if the form has more options than 'selectedOption'
  useEffect(() => {
    //find if we have more properties than just 'selectedOption'
    const formValues = formControl.getValues();
    const formEntries = Object.entries(formValues);
    const formKeys = formEntries.map(([key]) => key);
    const hasMoreThanSelectedOption = formKeys.length > 1;
    if (hasMoreThanSelectedOption) {
      formControl.reset({ selectedOption: "" });
    }
  }, [formControl]);

  const handleOptionClick = (value) => {
    setSelectedOption(value); // Visually select the option
    formControl.setValue(name, value); // Update form value in React Hook Form
    formControl.trigger();
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
            bgcolor: alpha(theme.palette.primary.main, 0.1),
            color: "primary.main",
            mb: 1.5,
            border: `2px solid ${alpha(theme.palette.primary.main, 0.2)}`,
          }}
        >
          <Checklist sx={{ fontSize: smDown ? 28 : 36 }} />
        </Box>
        <Typography variant={smDown ? "h6" : "h5"} fontWeight={600} gutterBottom>
          {title}
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 400, mx: 'auto' }}>
          {subtext}
        </Typography>
      </Box>

      {/* Options */}
      <Stack spacing={smDown ? 1.5 : 2}>
        {options.map((option) => {
          const isSelected = selectedOption === option.value;

          return (
            <Card
              key={option.value}
              onClick={() => handleOptionClick(option.value)}
              variant="outlined"
              sx={{
                cursor: "pointer",
                transition: "all 0.2s ease-in-out",
                position: "relative",
                overflow: "visible",
                ...(isSelected && {
                  borderColor: "primary.main",
                  borderWidth: 2,
                  bgcolor: alpha(theme.palette.primary.main, 0.02),
                }),
                "&:hover": {
                  borderColor: isSelected ? "primary.main" : "primary.light",
                  transform: "translateY(-2px)",
                  boxShadow: theme.shadows[4],
                },
              }}
            >
              {/* Selected indicator */}
              {isSelected && (
                <Box
                  sx={{
                    position: "absolute",
                    top: -10,
                    right: -10,
                    width: 24,
                    height: 24,
                    borderRadius: "50%",
                    bgcolor: "primary.main",
                    color: "primary.contrastText",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    boxShadow: theme.shadows[2],
                  }}
                >
                  <Check sx={{ fontSize: 16 }} />
                </Box>
              )}
              <CardContent sx={{ p: smDown ? 2 : 3 }}>
                <Stack 
                  direction="row" 
                  spacing={smDown ? 1.5 : 2.5} 
                  alignItems="center"
                >
                  <Box
                    sx={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      width: smDown ? 44 : 56,
                      height: smDown ? 44 : 56,
                      borderRadius: 2,
                      bgcolor: isSelected 
                        ? alpha(theme.palette.primary.main, 0.1)
                        : alpha(theme.palette.action.active, 0.04),
                      color: isSelected ? "primary.main" : "text.secondary",
                      flexShrink: 0,
                      transition: "all 0.2s ease-in-out",
                    }}
                  >
                    <SvgIcon sx={{ fontSize: smDown ? 24 : 28 }}>{option.icon}</SvgIcon>
                  </Box>
                  <Stack spacing={0.5} sx={{ minWidth: 0 }}>
                    <Typography 
                      variant={smDown ? "subtitle1" : "h6"} 
                      fontWeight={600}
                      color={isSelected ? "primary.main" : "text.primary"}
                    >
                      {option.label}
                    </Typography>
                    <Typography 
                      variant="body2" 
                      color="text.secondary"
                      sx={{
                        display: smDown ? "-webkit-box" : "block",
                        WebkitLineClamp: smDown ? 2 : "unset",
                        WebkitBoxOrient: "vertical",
                        overflow: smDown ? "hidden" : "visible",
                      }}
                    >
                      {option.description}
                    </Typography>
                  </Stack>
                </Stack>
              </CardContent>
            </Card>
          );
        })}
      </Stack>

      <CippWizardStepButtons
        currentStep={currentStep}
        onPreviousStep={onPreviousStep}
        onNextStep={onNextStep}
        formControl={formControl}
      />
    </Stack>
  );
};
