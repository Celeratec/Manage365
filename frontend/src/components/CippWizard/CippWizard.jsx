import { useCallback, useMemo, useState } from "react";
import { Card, CardContent, Container, Stack, useMediaQuery, LinearProgress, Box, Typography, Chip } from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { Grid } from "@mui/system";
import { WizardSteps } from "./wizard-steps";
import { useForm, useWatch } from "react-hook-form";

export const CippWizard = (props) => {
  const { 
    postUrl, 
    orientation = "horizontal", 
    steps,
    contentMaxWidth = "md",
  } = props;
  
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  const formControl = useForm({ mode: "onChange", defaultValues: props.initialState });
  const formWatcher = useWatch({
    control: formControl.control,
  });

  const stepsWithVisibility = useMemo(() => {
    return steps.filter((step) => {
      if (step.hideStepWhen) {
        return !step.hideStepWhen(formWatcher);
      }
      if (step.showStepWhen) {
        return step.showStepWhen(formWatcher);
      }
      return true;
    });
  }, [steps, formWatcher]);

  const [activeStep, setActiveStep] = useState(0);
  // Navigation clamps against the *visible* step list: conditional steps can
  // shrink it below the stored index (e.g. a form change hides a later step).
  const handleBack = useCallback(() => {
    setActiveStep((prevState) => {
      const current = Math.min(prevState, stepsWithVisibility.length - 1);
      return current > 0 ? current - 1 : current;
    });
  }, [stepsWithVisibility.length]);

  const handleNext = useCallback(() => {
    setActiveStep((prevState) => {
      const current = Math.min(prevState, stepsWithVisibility.length - 1);
      return current < stepsWithVisibility.length - 1 ? current + 1 : current;
    });
  }, [stepsWithVisibility.length]);

  // Conditional steps can shrink the visible list below the current index
  // (e.g. a form change hides a later step while it is active). Clamp at
  // render time so we never index past the filtered list and crash.
  const boundedStep = Math.min(activeStep, Math.max(stepsWithVisibility.length - 1, 0));

  const content = useMemo(() => {
    const currentStep = stepsWithVisibility[boundedStep];
    const StepComponent = currentStep.component;

    return (
      <StepComponent
        onNextStep={handleNext}
        onPreviousStep={handleBack}
        formControl={formControl}
        lastStep={stepsWithVisibility.length - 1}
        currentStep={boundedStep}
        postUrl={postUrl}
        options={currentStep.componentProps?.options}
        title={currentStep.componentProps?.title}
        subtext={currentStep.componentProps?.subtext}
        valuesKey={currentStep.componentProps?.valuesKey}
        {...currentStep.componentProps}
      />
    );
  }, [boundedStep, handleNext, handleBack, stepsWithVisibility, formControl]);

  // Get the maxWidth for the current step, fallback to global setting
  const currentStepMaxWidth = useMemo(() => {
    const currentStep = stepsWithVisibility[boundedStep];
    return currentStep.maxWidth ?? contentMaxWidth;
  }, [boundedStep, stepsWithVisibility, contentMaxWidth]);

  // Calculate progress percentage
  const progressPercentage = useMemo(() => {
    return ((boundedStep + 1) / stepsWithVisibility.length) * 100;
  }, [boundedStep, stepsWithVisibility.length]);

  // Get summary of selected values for display
  const selectedSummary = useMemo(() => {
    const summary = [];
    const tenant = formWatcher?.tenantFilter;
    const user = formWatcher?.user;
    
    if (tenant?.label || tenant?.value) {
      summary.push({ label: "Tenant", value: tenant.label || tenant.value });
    }
    if (user) {
      const userCount = Array.isArray(user) ? user.length : 1;
      summary.push({ label: "Users", value: `${userCount} selected` });
    }
    return summary;
  }, [formWatcher?.tenantFilter, formWatcher?.user]);

  return (
    <Card sx={{ overflow: 'visible' }}>
      {/* Progress bar */}
      <LinearProgress 
        variant="determinate" 
        value={progressPercentage} 
        sx={{ 
          height: smDown ? 3 : 4,
          borderRadius: 0,
          '& .MuiLinearProgress-bar': {
            transition: 'transform 0.3s ease',
          },
        }} 
      />
      
      {orientation === "vertical" ? (
        <CardContent sx={{ p: smDown ? 2 : 3 }}>
          <Grid container spacing={smDown ? 2 : 3}>
            <Grid size={{ md: 4, xs: 12 }}>
              <WizardSteps
                postUrl={postUrl}
                activeStep={boundedStep}
                orientation={orientation}
                steps={stepsWithVisibility}
              />
            </Grid>
            <Grid size={{ md: 8, xs: 12 }}>
              {content}
            </Grid>
          </Grid>
        </CardContent>
      ) : (
        <CardContent sx={{ p: smDown ? 1.5 : 3 }}>
          <Stack spacing={smDown ? 2 : 4}>
            <Box>
              <WizardSteps
                postUrl={postUrl}
                activeStep={boundedStep}
                orientation={orientation}
                steps={stepsWithVisibility}
              />
              {/* Selection summary chips - hidden on mobile as info is shown differently */}
              {selectedSummary.length > 0 && activeStep > 0 && !smDown && (
                <Stack 
                  direction="row" 
                  spacing={1} 
                  sx={{ mt: 2, justifyContent: 'center', flexWrap: 'wrap', gap: 1 }}
                >
                  {selectedSummary.map((item) => (
                    <Chip
                      key={item.label}
                      label={`${item.label}: ${item.value}`}
                      size="small"
                      variant="outlined"
                      color="primary"
                    />
                  ))}
                </Stack>
              )}
            </Box>
            <Box sx={{ px: smDown ? 0.5 : 0 }}>
              <Container 
                maxWidth={currentStepMaxWidth} 
                sx={{ px: smDown ? 0 : 2 }}
                disableGutters={smDown}
              >
                {content}
              </Container>
            </Box>
          </Stack>
        </CardContent>
      )}
    </Card>
  );
};
