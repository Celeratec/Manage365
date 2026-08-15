import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { CippHead } from "../../../components/CippComponents/CippHead";
import {
  Alert,
  Box,
  Card,
  CardContent,
  Container,
  Stack,
  Step,
  StepLabel,
  Stepper,
  Typography,
} from "@mui/material";
import { useState } from "react";
import { StepSelectScope } from "../../../components/CippWizard/TempFileCleanup/StepSelectScope";
import { StepConfigureFilters } from "../../../components/CippWizard/TempFileCleanup/StepConfigureFilters";
import { StepScanResults } from "../../../components/CippWizard/TempFileCleanup/StepScanResults";
import { StepSelectFiles } from "../../../components/CippWizard/TempFileCleanup/StepSelectFiles";
import { StepConfirmDelete } from "../../../components/CippWizard/TempFileCleanup/StepConfirmDelete";

const steps = [
  { label: "Select Scope", description: "Choose where to look" },
  { label: "Configure Filters", description: "Select file types" },
  { label: "Scan", description: "Find matching files" },
  { label: "Select Files", description: "Review and select" },
  { label: "Confirm", description: "Execute cleanup" },
];

const TempFileCleanupPage = () => {
  const [activeStep, setActiveStep] = useState(0);
  const [wizardData, setWizardData] = useState({
    tenant: null,
    scope: "site",
    siteId: null,
    userId: null,
    filters: {
      officeTemp: true,
      tempFiles: true,
      zeroByteFiles: true,
      systemJunk: true,
      backupFiles: false,
    },
    scanResults: [],
    selectedFiles: [],
  });

  const handleNext = () => setActiveStep((prev) => Math.min(prev + 1, steps.length - 1));
  const handleBack = () => setActiveStep((prev) => Math.max(prev - 1, 0));
  const updateWizardData = (data) => setWizardData((prev) => ({ ...prev, ...data }));

  const renderStep = () => {
    switch (activeStep) {
      case 0:
        return <StepSelectScope data={wizardData} onUpdate={updateWizardData} onNext={handleNext} />;
      case 1:
        return (
          <StepConfigureFilters
            data={wizardData}
            onUpdate={updateWizardData}
            onNext={handleNext}
            onBack={handleBack}
          />
        );
      case 2:
        return (
          <StepScanResults
            data={wizardData}
            onUpdate={updateWizardData}
            onNext={handleNext}
            onBack={handleBack}
          />
        );
      case 3:
        return (
          <StepSelectFiles
            data={wizardData}
            onUpdate={updateWizardData}
            onNext={handleNext}
            onBack={handleBack}
          />
        );
      case 4:
        return <StepConfirmDelete data={wizardData} onBack={handleBack} />;
      default:
        return null;
    }
  };

  return (
    <Box sx={{ flexGrow: 1, py: 4 }}>
      <CippHead title="Temp File Cleanup" />
      <Container maxWidth="lg">
        <Stack spacing={4}>
          <Box>
            <Typography variant="h4" sx={{ mb: 1 }}>
              Temp File Cleanup
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Find and remove temporary files from SharePoint and OneDrive to free up storage space.
            </Typography>
          </Box>

          <Alert severity="info">
            This wizard helps you find and remove temporary files from SharePoint and OneDrive.
            Deleted files are moved to the recycle bin and can be recovered for 93 days.
          </Alert>

          <Stepper activeStep={activeStep} alternativeLabel sx={{ mb: 2 }}>
            {steps.map((step) => (
              <Step key={step.label}>
                <StepLabel
                  optional={
                    <Typography variant="caption" color="text.secondary">
                      {step.description}
                    </Typography>
                  }
                >
                  {step.label}
                </StepLabel>
              </Step>
            ))}
          </Stepper>

          <Card>
            <CardContent sx={{ p: 3 }}>{renderStep()}</CardContent>
          </Card>
        </Stack>
      </Container>
    </Box>
  );
};

const Page = () => <TempFileCleanupPage />;

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
