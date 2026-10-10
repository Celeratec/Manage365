import PropTypes from "prop-types";
import CheckIcon from "@heroicons/react/24/outline/CheckIcon";
import { useIsMobileLayout } from "../../hooks/use-breakpoint";
import { CippWizardProgressHeader } from "./CippWizardProgressHeader";
import {
  Box,
  Step,
  StepConnector,
  stepConnectorClasses,
  StepLabel,
  Stepper,
  SvgIcon,
  Typography,
  CircularProgress,
} from "@mui/material";
import { styled } from "@mui/material/styles";
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
  const isHorizontal = orientation === "horizontal";
  const isMobile = useIsMobileLayout();

  // Create a custom step icon component that passes the compact prop
  const CompactStepIcon = (stepIconProps) => (
    <WizardStepIcon {...stepIconProps} compact={isHorizontal} />
  );

  // Only the horizontal stepper is wizard navigation. The vertical one is a status list —
  // GDAP onboarding feeds it server-side steps where each step's message and pass/fail
  // state IS the content, so collapsing it to a progress bar would delete that.
  if (isMobile && orientation === "horizontal") {
    return <CippWizardProgressHeader activeStep={activeStep} steps={steps} />;
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
        {/* Onboarding's steps carry only a description, so keying on title alone made
            every key undefined and reconciliation index-driven by accident. */}
        {steps.map((step, index) => (
          <Step key={step.title ?? step.description ?? index}>
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
