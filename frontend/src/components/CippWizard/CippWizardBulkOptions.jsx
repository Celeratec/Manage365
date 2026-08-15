import { 
  Stack, 
  Box, 
  Typography, 
  Card, 
  CardContent,
  alpha,
  useMediaQuery,
} from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { Grid } from "@mui/system";
import CippWizardStepButtons from "./CippWizardStepButtons";
import CippFormComponent from "../CippComponents/CippFormComponent";
import { CippFormDomainSelector } from "../CippComponents/CippFormDomainSelector";
import countryList from "../../data/countryList.json";
import { CippFormLicenseSelector } from "../CippComponents/CippFormLicenseSelector";
import { Tune, Public, CardMembership, Security, Domain } from "@mui/icons-material";

export const CippWizardBulkOptions = (props) => {
  const { postUrl, formControl, onPreviousStep, onNextStep, currentStep } = props;
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));

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
          <Tune sx={{ fontSize: smDown ? 28 : 36 }} />
        </Box>
        <Typography variant={smDown ? "h6" : "h5"} fontWeight={600} gutterBottom>
          Bulk Options
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 400, mx: 'auto' }}>
          Configure usage location and license assignments for users
        </Typography>
      </Box>

      <Card variant="outlined">
        <CardContent sx={{ p: smDown ? 2 : 3 }}>
          <Grid container spacing={smDown ? 2 : 3}>
            <Grid size={{ xs: 12 }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1.5 }}>
                <Box
                  sx={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 32,
                    height: 32,
                    borderRadius: 1,
                    bgcolor: alpha(theme.palette.primary.main, 0.1),
                    color: "primary.main",
                  }}
                >
                  <Domain fontSize="small" />
                </Box>
                <Typography variant="subtitle2" fontWeight={600}>
                  Primary Domain
                </Typography>
              </Stack>
              <CippFormDomainSelector
                formControl={formControl}
                name="primDomain"
                label="Select domain for user accounts"
                required={true}
                validators={{ required: "Primary Domain is required" }}
              />
              <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
                This domain will be used for all users that don&apos;t have a domain specified in the CSV
              </Typography>
            </Grid>
            <Grid size={{ xs: 12 }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1.5 }}>
                <Box
                  sx={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 32,
                    height: 32,
                    borderRadius: 1,
                    bgcolor: alpha(theme.palette.info.main, 0.1),
                    color: "info.main",
                  }}
                >
                  <Public fontSize="small" />
                </Box>
                <Typography variant="subtitle2" fontWeight={600}>
                  Usage Location
                </Typography>
              </Stack>
              <CippFormComponent
                type="autoComplete"
                label="Select country"
                fullWidth
                name="usageLocation"
                multiple={false}
                defaultValue="US"
                options={countryList.map(({ Code, Name }) => ({
                  label: Name,
                  value: Code,
                }))}
                formControl={formControl}
              />
            </Grid>
            <Grid size={{ xs: 12 }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1.5 }}>
                <Box
                  sx={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 32,
                    height: 32,
                    borderRadius: 1,
                    bgcolor: alpha(theme.palette.success.main, 0.1),
                    color: "success.main",
                  }}
                >
                  <CardMembership fontSize="small" />
                </Box>
                <Typography variant="subtitle2" fontWeight={600}>
                  License Assignment
                </Typography>
              </Stack>
              <CippFormLicenseSelector
                fullWidth
                label="Select licenses to assign (if available)"
                name="licenses"
                formControl={formControl}
              />
            </Grid>
            <Grid size={{ xs: 12 }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1.5 }}>
                <Box
                  sx={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    width: 32,
                    height: 32,
                    borderRadius: 1,
                    bgcolor: alpha(theme.palette.warning.main, 0.1),
                    color: "warning.main",
                  }}
                >
                  <Security fontSize="small" />
                </Box>
                <Typography variant="subtitle2" fontWeight={600}>
                  Security Options
                </Typography>
              </Stack>
              <CippFormComponent
                type="switch"
                label="Disable legacy protocols (IMAP & POP)"
                name="disableLegacyProtocols"
                formControl={formControl}
                defaultValue={true}
              />
              <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
                Disabling IMAP and POP improves mailbox security by blocking insecure authentication methods
              </Typography>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      <CippWizardStepButtons
        postUrl={postUrl}
        currentStep={currentStep}
        onPreviousStep={onPreviousStep}
        onNextStep={onNextStep}
        formControl={formControl}
      />
    </Stack>
  );
};
