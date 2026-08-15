// this page is going to need some love for accounting for filters: https://github.com/KelvinTegelaar/CIPP/blob/main/src/views/tenant/administration/ListEnterpriseApps.jsx#L83
import { Layout as DashboardLayout } from '../../../../layouts/index.js'
import { TabbedLayout } from '../../../../layouts/TabbedLayout'
import { CippTablePage } from '../../../../components/CippComponents/CippTablePage.jsx'
import CippPermissionPreview from '../../../../components/CippComponents/CippPermissionPreview.jsx'
import {
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  Apps,
  Language,
  VpnKey,
} from "@mui/icons-material";
import { usePermissions } from '../../../../hooks/use-permissions.js'
import tabOptions from './tabOptions'
import { getAppRegistrationListActions } from '../../../../components/CippComponents/AppRegistrationActions.jsx'
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";

const Page = () => {
  const pageTitle = 'App Registrations'
  const apiUrl = '/api/ListGraphRequest'
  const theme = useTheme();

  const { checkPermissions } = usePermissions()
  const canWriteApplication = checkPermissions(['Tenant.Application.ReadWrite'])

  const actions = getAppRegistrationListActions(canWriteApplication)

  const offCanvas = {
    extendedInfoFields: [
      'displayName',
      'id',
      'appId',
      'createdDateTime',
      'signInAudience',
      'disabledByMicrosoftStatus',
      'replyUrls',
      'passwordCredentials',
      'keyCredentials',
    ],
    actions: actions,
    children: (row) => {
      const hasPasswords = row.passwordCredentials?.length > 0;
      const hasCerts = row.keyCredentials?.length > 0;
      const audienceLabel = row.signInAudience === "AzureADMultipleOrgs" ? "Multi-Tenant" 
        : row.signInAudience === "AzureADMyOrg" ? "Single-Tenant" 
        : row.signInAudience === "AzureADandPersonalMicrosoftAccount" ? "All Accounts"
        : row.signInAudience || "Unknown";
      
      return (
        <Stack spacing={3}>
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.15)} 0%, ${alpha(theme.palette.primary.main, 0.05)} 100%)`,
              borderLeft: `4px solid ${theme.palette.primary.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: stringToColor(row.displayName || "A"),
                  width: 56,
                  height: 56,
                  fontSize: "1.25rem",
                  fontWeight: 600,
                }}
              >
                {getInitials(row.displayName || "App")}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.displayName || "Unknown Application"}
                </Typography>
                <Typography variant="body2" color="text.secondary" noWrap>
                  {row.publisherDomain}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          <Box>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                icon={<Language fontSize="small" />}
                label={audienceLabel}
                color={row.signInAudience === "AzureADMultipleOrgs" ? "info" : "default"}
                variant="outlined"
                sx={{ fontWeight: 600 }}
              />
              {row.disabledByMicrosoftStatus && (
                <Chip
                  label="Disabled by Microsoft"
                  color="error"
                  variant="filled"
                  size="small"
                />
              )}
            </Stack>
          </Box>

          <Divider />

          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <Apps fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Application IDs
              </Typography>
            </Stack>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Application (Client) ID</Typography>
                <Typography 
                  variant="caption" 
                  sx={{ 
                    fontFamily: "monospace",
                    bgcolor: alpha(theme.palette.text.primary, 0.05),
                    px: 1,
                    py: 0.25,
                    borderRadius: 0.5,
                  }}
                >
                  {row.appId}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Object ID</Typography>
                <Typography 
                  variant="caption" 
                  sx={{ 
                    fontFamily: "monospace",
                    bgcolor: alpha(theme.palette.text.primary, 0.05),
                    px: 1,
                    py: 0.25,
                    borderRadius: 0.5,
                  }}
                >
                  {row.id}
                </Typography>
              </Stack>
              {row.createdDateTime && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Created</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.createdDateTime, "createdDateTime")}
                  </Typography>
                </Stack>
              )}
            </Stack>
          </Box>

          {(hasPasswords || hasCerts) && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
                  <VpnKey fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Credentials
                  </Typography>
                </Stack>
                <Stack spacing={1}>
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="body2" color="text.secondary">Client Secrets</Typography>
                    <Chip 
                      label={row.passwordCredentials?.length || 0} 
                      size="small" 
                      color={hasPasswords ? "warning" : "default"}
                      variant="outlined"
                    />
                  </Stack>
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="body2" color="text.secondary">Certificates</Typography>
                    <Chip 
                      label={row.keyCredentials?.length || 0} 
                      size="small" 
                      color={hasCerts ? "warning" : "default"}
                      variant="outlined"
                    />
                  </Stack>
                </Stack>
              </Box>
            </>
          )}

          <Divider />

          <CippPermissionPreview
            applicationManifest={row}
            title="API Permissions"
            maxHeight="400px"
            showAppIds={true}
          />
        </Stack>
      )
    },
  }

  const simpleColumns = [
    'displayName',
    'appId',
    'createdDateTime',
    'signInAudience',
    'web.redirectUris',
    'publisherDomain',
    'passwordCredentials',
    'keyCredentials',
  ]

  const apiParams = {
    Endpoint: 'applications',
    $count: true,
    $top: 999,
  }

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl={apiUrl}
      apiData={apiParams}
      apiDataKey="Results"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
    />
  )
}

Page.getLayout = (page) => (
  <DashboardLayout>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
)

export default Page
