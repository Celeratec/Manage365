import { 
  Card, 
  Stack, 
  Typography, 
  Box, 
  Divider, 
  alpha, 
  useMediaQuery,
  Chip,
  Paper,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
} from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { Grid } from "@mui/system";
import CippWizardStepButtons from "./CippWizardStepButtons";
import { getCippTranslation } from "../../utils/get-cipp-translation";
import { getCippFormatting } from "../../utils/get-cipp-formatting";
import { 
  TaskAlt,
  Business,
  People,
  Settings,
  Check,
  Close,
  Schedule,
  Email,
  Security,
  Storage,
  Tune,
} from "@mui/icons-material";

// Helper to get icon for a setting category
const getSettingIcon = (key) => {
  const keyLower = key.toLowerCase();
  if (keyLower.includes('email') || keyLower.includes('mail') || keyLower.includes('forward') || keyLower.includes('ooo')) {
    return <Email fontSize="small" />;
  }
  if (keyLower.includes('schedule') || keyLower.includes('date') || keyLower.includes('time')) {
    return <Schedule fontSize="small" />;
  }
  if (keyLower.includes('security') || keyLower.includes('mfa') || keyLower.includes('password') || keyLower.includes('session')) {
    return <Security fontSize="small" />;
  }
  if (keyLower.includes('license') || keyLower.includes('group') || keyLower.includes('access')) {
    return <Storage fontSize="small" />;
  }
  return <Tune fontSize="small" />;
};

// PowerShell type patterns that indicate unserialized data
const powershellTypePatterns = [
  "System.Collections.Hashtable",
  "System.Object[]",
  "System.Collections.ArrayList",
  "System.Collections.Generic.List",
  "System.Collections.Generic.Dictionary",
  "System.Management.Automation.PSCustomObject",
];

// Helper to check if a value is an unserialized PowerShell type
const isPowerShellTypeString = (value) => {
  if (typeof value !== 'string') return false;
  return powershellTypePatterns.some(pattern => value.includes(pattern));
};

// Helper to format value for display
const formatDisplayValue = (value, key) => {
  if (value === true) return { text: "Yes", isBoolean: true, enabled: true };
  if (value === false) return { text: "No", isBoolean: true, enabled: false };
  if (value === null || value === undefined) return { text: "Not set", isBoolean: false };
  
  // Handle PowerShell type strings that weren't properly serialized
  if (isPowerShellTypeString(value)) {
    return { text: "Complex data", isBoolean: false };
  }
  
  if (typeof value === 'object') {
    if (Array.isArray(value)) {
      return { text: `${value.length} item${value.length !== 1 ? 's' : ''} selected`, isBoolean: false };
    }
    if (value.label) return { text: value.label, isBoolean: false };
    if (value.value) return { text: value.value, isBoolean: false };
  }
  return { text: String(value), isBoolean: false };
};

export const CippWizardConfirmation = (props) => {
  const { 
    postUrl, 
    lastStep, 
    formControl, 
    onPreviousStep, 
    onNextStep, 
    currentStep,
    columns = 2,
    replacementBehaviour,
    queryKeys,
  } = props;
  
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  const mdDown = useMediaQuery(theme.breakpoints.down("md"));
  const formValues = formControl.getValues();
  const formEntries = Object.entries(formValues);

  const blacklist = [
    "selectedOption",
    "GDAPAuth",
    "SAMWizard",
    "GUID",
    "ID",
    "noSubmitButton",
    "RAWJson",
    "TemplateList",
    "addrow",
    "Scheduled",
    "postExecution",
    "userTemplate",      // Contains template object with addedFields
    "userProperties",    // Contains copied user properties
    "copyFrom",          // User selector for copying groups
    "defaultAttributes", // Complex custom attributes object
    "customData",        // Custom data mappings
  ];

  // Filter and categorize entries
  const filteredFormEntries = formEntries.filter(
    ([key, value]) => value !== null && value !== undefined && !key.startsWith('HIDDEN_')
  );

  // Extract special entries
  const tenantEntry = filteredFormEntries.find(
    ([key]) => key === "tenantFilter" || key === "tenant"
  );
  const userEntry = filteredFormEntries.find(([key]) =>
    ["user", "userPrincipalName", "username"].includes(key)
  );

  // Get scheduling info
  const scheduledEnabled = formValues?.Scheduled?.enabled;
  const scheduledDate = formValues?.Scheduled?.date;

  // Filter settings entries (boolean switches and other settings)
  const settingsEntries = formEntries.filter(
    ([key, value]) =>
      !blacklist.includes(key) &&
      key !== "tenantFilter" &&
      key !== "tenant" &&
      !["user", "userPrincipalName", "username"].includes(key) &&
      !key.startsWith('HIDDEN_') &&
      value !== null &&
      value !== undefined &&
      !isPowerShellTypeString(value)  // Filter out unserialized PowerShell types
  );

  // Separate boolean settings from other settings
  const booleanSettings = settingsEntries.filter(([_, value]) => typeof value === 'boolean');
  const otherSettings = settingsEntries.filter(([_, value]) => 
    typeof value !== 'boolean' && !isPowerShellTypeString(value)
  );

  // Count enabled settings
  const enabledCount = booleanSettings.filter(([_, value]) => value === true).length;

  // Get user count
  const getUserCount = () => {
    const user = userEntry?.[1];
    if (!user) return 0;
    if (Array.isArray(user)) return user.length;
    return 1;
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
            bgcolor: alpha(theme.palette.success.main, 0.1),
            color: "success.main",
            mb: 1.5,
            border: `2px solid ${alpha(theme.palette.success.main, 0.2)}`,
          }}
        >
          <TaskAlt sx={{ fontSize: smDown ? 28 : 36 }} />
        </Box>
        <Typography variant={smDown ? "h6" : "h5"} fontWeight={600} gutterBottom>
          Ready to Submit
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 400, mx: 'auto' }}>
          Review your selections below before submitting
        </Typography>
      </Box>

      {/* Target Summary Card */}
      {(tenantEntry || userEntry) && (
        <Paper 
          variant="outlined" 
          sx={{ 
            p: smDown ? 2 : 2.5,
            bgcolor: alpha(theme.palette.primary.main, 0.02),
            borderColor: alpha(theme.palette.primary.main, 0.2),
          }}
        >
          <Grid container spacing={2}>
            {tenantEntry && (
              <Grid size={{ xs: 12, sm: userEntry ? 6 : 12 }}>
                <Stack direction="row" spacing={1.5} alignItems="center">
                  <Box
                    sx={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      width: 40,
                      height: 40,
                      borderRadius: 1.5,
                      bgcolor: alpha(theme.palette.primary.main, 0.1),
                      color: "primary.main",
                    }}
                  >
                    <Business />
                  </Box>
                  <Box sx={{ minWidth: 0, flex: 1 }}>
                    <Typography variant="caption" color="text.secondary" sx={{ textTransform: 'uppercase', letterSpacing: 0.5 }}>
                      Target Tenant
                    </Typography>
                    <Typography variant="body2" fontWeight={600} noWrap>
                      {tenantEntry[1]?.label || tenantEntry[1]?.value || tenantEntry[1]}
                    </Typography>
                  </Box>
                </Stack>
              </Grid>
            )}
            {userEntry && (
              <Grid size={{ xs: 12, sm: tenantEntry ? 6 : 12 }}>
                <Stack direction="row" spacing={1.5} alignItems="center">
                  <Box
                    sx={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      width: 40,
                      height: 40,
                      borderRadius: 1.5,
                      bgcolor: alpha(theme.palette.info.main, 0.1),
                      color: "info.main",
                    }}
                  >
                    <People />
                  </Box>
                  <Box sx={{ minWidth: 0, flex: 1 }}>
                    <Typography variant="caption" color="text.secondary" sx={{ textTransform: 'uppercase', letterSpacing: 0.5 }}>
                      {getUserCount() === 1 ? 'Target User' : 'Target Users'}
                    </Typography>
                    <Typography variant="body2" fontWeight={600}>
                      {getUserCount()} {getUserCount() === 1 ? 'user' : 'users'} selected
                    </Typography>
                  </Box>
                </Stack>
              </Grid>
            )}
          </Grid>
        </Paper>
      )}

      {/* Scheduling Info */}
      {scheduledEnabled && (
        <Paper 
          variant="outlined" 
          sx={{ 
            p: smDown ? 2 : 2.5,
            bgcolor: alpha(theme.palette.warning.main, 0.02),
            borderColor: alpha(theme.palette.warning.main, 0.3),
          }}
        >
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Box
              sx={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                width: 40,
                height: 40,
                borderRadius: 1.5,
                bgcolor: alpha(theme.palette.warning.main, 0.1),
                color: "warning.main",
              }}
            >
              <Schedule />
            </Box>
            <Box>
              <Typography variant="caption" color="text.secondary" sx={{ textTransform: 'uppercase', letterSpacing: 0.5 }}>
                Scheduled Execution
              </Typography>
              <Typography variant="body2" fontWeight={600}>
                {scheduledDate ? new Date(scheduledDate * 1000).toLocaleString() : 'Date not set'}
              </Typography>
            </Box>
          </Stack>
        </Paper>
      )}

      {/* Settings Summary */}
      {booleanSettings.length > 0 && (
        <Card variant="outlined">
          <Box sx={{ p: smDown ? 2 : 2.5, borderBottom: 1, borderColor: 'divider' }}>
            <Stack direction="row" alignItems="center" justifyContent="space-between">
              <Stack direction="row" spacing={1} alignItems="center">
                <Settings fontSize="small" color="action" />
                <Typography variant="subtitle2" fontWeight={600}>
                  Settings
                </Typography>
              </Stack>
              <Chip 
                label={`${enabledCount} of ${booleanSettings.length} enabled`}
                size="small"
                color={enabledCount > 0 ? "primary" : "default"}
                variant="outlined"
              />
            </Stack>
          </Box>
          <Box sx={{ p: smDown ? 1.5 : 2 }}>
            <Grid container spacing={smDown ? 0.5 : 1}>
              {booleanSettings.map(([key, value]) => (
                <Grid key={key} size={{ xs: 12, sm: 6, md: columns > 2 ? 4 : 6 }}>
                  <Stack 
                    direction="row" 
                    spacing={1} 
                    alignItems="center"
                    sx={{
                      py: 0.75,
                      px: 1.5,
                      borderRadius: 1,
                      bgcolor: value 
                        ? alpha(theme.palette.success.main, 0.08)
                        : alpha(theme.palette.action.disabled, 0.04),
                    }}
                  >
                    {value ? (
                      <Check sx={{ fontSize: 18, color: 'success.main' }} />
                    ) : (
                      <Close sx={{ fontSize: 18, color: 'text.disabled' }} />
                    )}
                    <Typography 
                      variant="body2" 
                      sx={{ 
                        color: value ? 'text.primary' : 'text.secondary',
                        fontWeight: value ? 500 : 400,
                      }}
                    >
                      {getCippTranslation(key)}
                    </Typography>
                  </Stack>
                </Grid>
              ))}
            </Grid>
          </Box>
        </Card>
      )}

      {/* Other Settings */}
      {otherSettings.length > 0 && (
        <Card variant="outlined">
          <Box sx={{ p: smDown ? 2 : 2.5, borderBottom: 1, borderColor: 'divider' }}>
            <Stack direction="row" spacing={1} alignItems="center">
              <Tune fontSize="small" color="action" />
              <Typography variant="subtitle2" fontWeight={600}>
                Additional Options
              </Typography>
            </Stack>
          </Box>
          <List disablePadding>
            {otherSettings.map(([key, value], index) => {
              const formatted = formatDisplayValue(value, key);
              return (
                <ListItem 
                  key={key}
                  divider={index < otherSettings.length - 1}
                  sx={{ py: smDown ? 1.5 : 2, px: smDown ? 2 : 2.5 }}
                >
                  <ListItemIcon sx={{ minWidth: 40 }}>
                    {getSettingIcon(key)}
                  </ListItemIcon>
                  <ListItemText
                    primary={getCippTranslation(key)}
                    secondary={getCippFormatting(value, key)}
                    primaryTypographyProps={{ variant: 'body2', fontWeight: 500 }}
                    secondaryTypographyProps={{ variant: 'body2', color: 'text.secondary' }}
                  />
                </ListItem>
              );
            })}
          </List>
        </Card>
      )}

      {/* Empty state */}
      {settingsEntries.length === 0 && !tenantEntry && !userEntry && (
        <Paper 
          variant="outlined" 
          sx={{ 
            p: smDown ? 3 : 4, 
            textAlign: 'center',
            bgcolor: alpha(theme.palette.action.hover, 0.02),
          }}
        >
          <TaskAlt sx={{ fontSize: 48, color: 'success.main', mb: 1 }} />
          <Typography variant="body1" color="text.secondary">
            You've completed all the steps. Click submit to save your changes.
          </Typography>
        </Paper>
      )}

      <CippWizardStepButtons
        postUrl={postUrl}
        lastStep={lastStep}
        currentStep={currentStep}
        onPreviousStep={onPreviousStep}
        onNextStep={onNextStep}
        formControl={formControl}
        noSubmitButton={formValues?.noSubmitButton}
        replacementBehaviour={replacementBehaviour}
        queryKeys={queryKeys}
      />
    </Stack>
  );
};

export default CippWizardConfirmation;
