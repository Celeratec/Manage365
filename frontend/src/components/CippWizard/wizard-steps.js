import PropTypes from "prop-types";
import CheckIcon from "@heroicons/react/24/outline/CheckIcon";
import {
  Box,
  Step,
  StepConnector,
  stepConnectorClasses,
  StepLabel,
  Stepper,
  SvgIcon,
  Typography,
  useMediaQuery,
  CircularProgress,
} from "@mui/material";
import { styled, useTheme } from "@mui/material/styles";
import { ClearIcon } from "@mui/x-date-pickers";

const WizardStepConnector = styled(StepConnector)(({ theme }) => ({
  [`&.${stepConnectorClasses.vertical}`]: {
    marginLeft: 14,
  },
  [`& .${stepConnectorClasses.lineVertical}`]: {
    borderColor:
      theme.palette.mode === "dark" ? theme.palette.neutral[800] : theme.palette.neutral[200],
    borderLeftWidth: 2,
  },
  [`& .${stepConnectorClasses.lineHorizontal}`]: {
    borderColor:
      theme.palette.mode === "dark" ? theme.palette.neutral[800] : theme.palette.neutral[200],
    borderTopWidth: 2,
  },
}));

const WizardStepIcon = (props) => {
  const { active, completed, error, compact = false, loading } = props;
  const size = compact ? 28 : 36;
  const innerSize = compact ? 8 : 12;

  if (loading) {
    return (
      <Box
        sx={{
          alignItems: "center",
          borderColor: "primary.main",
          borderRadius: "50%",
          borderStyle: "solid",
          borderWidth: 2,
          color: "primary.main",
          display: "flex",
          height: 36,
          justifyContent: "center",
          width: 36,
        }}
      >
        <CircularProgress size={20} />
      </Box>
    );
  }
  if (error) {
    return (
      <Box
        sx={{
          alignItems: "center",
          backgroundColor: "error.main",
          borderRadius: "50%",
          color: "primary.contrastText",
          display: "flex",
          height: size,
          justifyContent: "center",
          width: size,
        }}
      >
        <SvgIcon fontSize="small">
          <ClearIcon />
        </SvgIcon>
      </Box>
    );
  }
  if (active) {
    return (
      <Box
        sx={{
          alignItems: "center",
          borderColor: "primary.main",
          borderRadius: "50%",
          borderStyle: "solid",
          borderWidth: 2,
          color: "primary.main",
          display: "flex",
          height: size,
          justifyContent: "center",
          width: size,
        }}
      >
        <Box
          sx={{
            backgroundColor: "primary.main",
            borderRadius: "50%",
            height: innerSize,
            width: innerSize,
          }}
        />
      </Box>
    );
  }
  if (completed) {
    return (
      <Box
        sx={{
          alignItems: "center",
          backgroundColor: "primary.main",
          borderRadius: "50%",
          color: "primary.contrastText",
          display: "flex",
          height: size,
          justifyContent: "center",
          width: size,
        }}
      >
        <SvgIcon fontSize="small">
          <CheckIcon />
        </SvgIcon>
      </Box>
    );
  }

  return (
    <Box
      sx={{
        borderColor: (theme) => (theme.palette.mode === "dark" ? "neutral.700" : "neutral.300"),
        borderRadius: "50%",
        borderStyle: "solid",
        borderWidth: 2,
        height: size,
        width: size,
      }}
    />
  );
};

export const WizardSteps = (props) => {
  const { activeStep = 1, orientation = "vertical", steps = [] } = props;
  const theme = useTheme();
  const isHorizontal = orientation === "horizontal";
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));

  // Create a custom step icon component that passes the compact prop
  const CompactStepIcon = (stepIconProps) => (
    <WizardStepIcon {...stepIconProps} compact={isHorizontal} />
  );

  // Mobile-friendly step indicator
  if (smDown && isHorizontal) {
    const currentStepData = steps[activeStep];
    return (
      <Box sx={{ textAlign: 'center', py: 1 }}>
        <Typography variant="overline" color="text.secondary" sx={{ letterSpacing: 1 }}>
          Step {activeStep + 1} of {steps.length}
        </Typography>
        <Typography variant="subtitle1" fontWeight={600}>
          {currentStepData?.description}
        </Typography>
        {/* Mobile step dots */}
        <Box sx={{ display: 'flex', justifyContent: 'center', gap: 1, mt: 1.5 }}>
          {steps.map((step, index) => (
            <Box
              key={index}
              sx={{
                width: index === activeStep ? 24 : 8,
                height: 8,
                borderRadius: 4,
                bgcolor: index <= activeStep ? 'primary.main' : 'action.disabled',
                transition: 'all 0.3s ease',
              }}
            />
          ))}
        </Box>
      </Box>
    );
  }

  return (
    <div>
      <Stepper
        orientation={orientation}
        activeStep={activeStep}
        connector={<WizardStepConnector />}
        sx={{
          ...(isHorizontal && {
            '& .MuiStepLabel-root': {
              py: 0,
            },
          }),
        }}
      >
        {steps.map((step, index) => (
          <Step key={step.title || index}>
            <StepLabel 
              error={step.error ?? false} 
              slots={{ stepIcon: CompactStepIcon }}
              slotProps={{ stepIcon: { loading: step.loading ?? false } }}
              sx={{
                '& .MuiStepLabel-labelContainer': {
                  ...(isHorizontal && {
                    maxWidth: 120,
                  }),
                },
              }}
            >
              <Typography 
                variant={isHorizontal ? "caption" : "subtitle2"} 
                fontWeight={600}
                sx={{ 
                  lineHeight: 1.2,
                }}
              >
                {step.description}
              </Typography>
            </StepLabel>
          </Step>
        ))}
      </Stepper>
    </div>
  );
};

WizardSteps.propTypes = {
  activeStep: PropTypes.number,
  orientation: PropTypes.oneOf(["vertical", "horizontal"]),
  steps: PropTypes.array,
};
