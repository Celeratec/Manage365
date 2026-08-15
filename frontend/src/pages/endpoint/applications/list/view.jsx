import { useMemo } from "react";
import { useRouter } from "next/router";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { useSettings } from "../../../../hooks/use-settings";
import { ApiGetCall } from "../../../../api/ApiCall";
import { useDialog } from "../../../../hooks/use-dialog";
import { CippApiDialog } from "../../../../components/CippComponents/CippApiDialog";
import {
  Alert,
  Avatar,
  Button,
  Chip,
  CircularProgress,
  Container,
  Divider,
  Paper,
  Tooltip,
  Typography,
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Grid, Stack } from "@mui/system";
import {
  ArrowBack,
  Apps,
  CheckCircle,
  Cancel,
  Assignment,
  LaptopMac,
  CalendarToday,
  GroupAdd,
  People,
  Devices,
  Delete,
} from "@mui/icons-material";
import Link from "next/link";
import { stringToColor } from "../../../../utils/get-initials";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";

const InfoRow = ({ label, value, mono = false }) => {
  if (!value) return null;
  return (
    <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ py: 0.5 }}>
      <Typography variant="body2" color="text.secondary">{label}</Typography>
      <Typography
        variant="body2"
        sx={{
          fontWeight: 500,
          maxWidth: "60%",
          textAlign: "right",
          wordBreak: "break-all",
          ...(mono && {
            fontFamily: "monospace",
            fontSize: "0.8rem",
            bgcolor: (t) => alpha(t.palette.text.primary, 0.05),
            px: 1,
            py: 0.25,
            borderRadius: 0.5,
          }),
        }}
      >
        {value}
      </Typography>
    </Stack>
  );
};

const StatBox = ({ label, value, color = "primary.main" }) => (
  <Box sx={{ textAlign: "center", px: 3 }}>
    <Typography variant="h5" sx={{ fontWeight: 700, color }}>{value}</Typography>
    <Typography variant="caption" color="text.secondary">{label}</Typography>
  </Box>
);

const Page = () => {
  const router = useRouter();
  const { appId } = router.query;
  const tenant = useSettings().currentTenant;
  const theme = useTheme();

  const assignAllUsersDialog = useDialog();
  const assignAllDevicesDialog = useDialog();
  const assignGroupDialog = useDialog();
  const deleteDialog = useDialog();

  const appData = ApiGetCall({
    url: "/api/ListApps",
    data: { tenantFilter: tenant },
    queryKey: `App-${appId}-${tenant}`,
    waiting: !!(appId && tenant),
  });

  const app = useMemo(() => {
    if (!appData.data) return null;
    const data = Array.isArray(appData.data) ? appData.data : [appData.data];
    return data.find((a) => a.id === appId) || null;
  }, [appData.data, appId]);

  if (!appId || !tenant) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/endpoint/applications/list" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Applications
        </Button>
        <Alert severity="warning">No application selected. Please select an application from the list.</Alert>
      </Container>
    );
  }

  if (appData.isLoading) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/endpoint/applications/list" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Applications
        </Button>
        <Box sx={{ display: "flex", justifyContent: "center", py: 8 }}>
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  if (appData.isError || !app) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/endpoint/applications/list" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Applications
        </Button>
        <Alert severity="error">Failed to load application details. Please try again.</Alert>
      </Container>
    );
  }

  const isAssigned = app.isAssigned === true;

  return (
    <Container maxWidth={false} sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Button
          component={Link}
          href="/endpoint/applications/list"
          startIcon={<ArrowBack />}
          sx={{ alignSelf: "flex-start" }}
        >
          Back to Applications
        </Button>

        {/* Hero + Stats */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, lg: 7 }}>
            <Paper
              elevation={0}
              sx={{
                p: 3,
                borderRadius: 2,
                background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.15)} 0%, ${alpha(theme.palette.primary.main, 0.05)} 100%)`,
                borderLeft: `4px solid ${theme.palette.primary.main}`,
                height: "100%",
              }}
            >
              <Stack direction="row" spacing={2} alignItems="center">
                <Avatar
                  sx={{
                    bgcolor: stringToColor(app.displayName || "A"),
                    width: 56,
                    height: 56,
                  }}
                >
                  <Apps />
                </Avatar>
                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5 }}>
                    {app.displayName || "Unknown Application"}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                    {app.publishingState || "Unknown state"}
                  </Typography>
                  <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                    <Chip
                      icon={isAssigned ? <CheckCircle fontSize="small" /> : <Cancel fontSize="small" />}
                      label={isAssigned ? "Assigned" : "Unassigned"}
                      size="small"
                      color={isAssigned ? "success" : "default"}
                      variant="outlined"
                      sx={{ fontWeight: 600 }}
                    />
                    {app.isFeatured && (
                      <Chip label="Featured" size="small" color="info" variant="outlined" />
                    )}
                  </Stack>
                </Box>
              </Stack>
            </Paper>
          </Grid>
          <Grid size={{ xs: 12, lg: 5 }}>
            <Paper variant="outlined" sx={{ p: 2, borderRadius: 2, height: "100%" }}>
              <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
                Quick Actions
              </Typography>
              <Stack spacing={1}>
                <Button variant="outlined" color="primary" startIcon={<People />} fullWidth onClick={() => assignAllUsersDialog.handleOpen()}>
                  Assign to All Users
                </Button>
                <Button variant="outlined" color="primary" startIcon={<Devices />} fullWidth onClick={() => assignAllDevicesDialog.handleOpen()}>
                  Assign to All Devices
                </Button>
                <Button variant="outlined" color="info" startIcon={<GroupAdd />} fullWidth onClick={() => assignGroupDialog.handleOpen()}>
                  Assign to Custom Group
                </Button>
                <Divider />
                <Button variant="outlined" color="error" startIcon={<Delete />} fullWidth onClick={() => deleteDialog.handleOpen()}>
                  Delete Application
                </Button>
              </Stack>
            </Paper>
          </Grid>
        </Grid>

        {/* Assignments + Install / Detection + Timeline */}
        <Grid container spacing={2}>
          <Grid size={{ xs: 12, md: 6 }}>
            <Stack spacing={2}>
              {/* Assignments */}
              {(app.AppAssignment || app.AppExclude) && (
                <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                  <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                    <Assignment fontSize="small" color="action" />
                    <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Assignments</Typography>
                  </Stack>
                  <Stack spacing={0.5}>
                    {app.AppAssignment && (
                      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" sx={{ py: 0.5 }}>
                        <Typography variant="body2" color="text.secondary">Assigned To</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 500, textAlign: "right", maxWidth: "60%" }}>
                          {app.AppAssignment}
                        </Typography>
                      </Stack>
                    )}
                    {app.AppExclude && (
                      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" sx={{ py: 0.5 }}>
                        <Typography variant="body2" color="text.secondary">Excluded</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 500, textAlign: "right", maxWidth: "60%" }}>
                          {app.AppExclude}
                        </Typography>
                      </Stack>
                    )}
                    {app.dependentAppCount > 0 && (
                      <InfoRow label="Dependencies" value={String(app.dependentAppCount)} />
                    )}
                  </Stack>
                </Paper>
              )}

              {/* Install Experience */}
              {app.installExperience && (
                <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                  <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                    <LaptopMac fontSize="small" color="action" />
                    <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Install Experience</Typography>
                  </Stack>
                  <Stack spacing={0.5}>
                    <InfoRow label="Run As" value={app.installExperience.runAsAccount} />
                    <InfoRow label="Restart Behavior" value={app.installExperience.deviceRestartBehavior} />
                  </Stack>
                </Paper>
              )}
            </Stack>
          </Grid>
          <Grid size={{ xs: 12, md: 6 }}>
            <Stack spacing={2}>
              {/* Detection Rules */}
              {app.rules?.[0] && (
                <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 2 }}>
                    Detection Rules
                  </Typography>
                  <Stack spacing={0.5}>
                    <InfoRow label="Type" value={app.rules[0].ruleType} />
                    <InfoRow label="Path" value={app.rules[0].path} mono />
                    {app.rules[0].fileOrFolderName && (
                      <InfoRow label="File/Folder" value={app.rules[0].fileOrFolderName} />
                    )}
                    {app.rules[0].check32BitOn64System !== undefined && (
                      <InfoRow label="Check 32-bit on 64-bit" value={app.rules[0].check32BitOn64System ? "Yes" : "No"} />
                    )}
                  </Stack>
                </Paper>
              )}

              {/* Timeline */}
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <CalendarToday fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>Timeline</Typography>
                </Stack>
                <Stack spacing={0.5}>
                  <InfoRow label="Created" value={app.createdDateTime ? getCippFormatting(app.createdDateTime, "createdDateTime") : null} />
                  <InfoRow label="Last Modified" value={app.lastModifiedDateTime ? getCippFormatting(app.lastModifiedDateTime, "lastModifiedDateTime") : null} />
                  <InfoRow label="Application ID" value={app.id} mono />
                </Stack>
              </Paper>
            </Stack>
          </Grid>
        </Grid>
      </Stack>

      {/* Dialogs */}
      <CippApiDialog
        title="Assign to All Users"
        createDialog={assignAllUsersDialog}
        api={{
          url: "/api/ExecAssignApp",
          type: "POST",
          data: { AssignTo: "allLicensedUsers", appId: app?.id, tenantFilter: tenant },
          confirmText: "Are you sure you want to assign this application to all licensed users?",
          multiPost: false,
        }}
        row={app || {}}
        relatedQueryKeys={[`App-${appId}-${tenant}`]}
      />
      <CippApiDialog
        title="Assign to All Devices"
        createDialog={assignAllDevicesDialog}
        api={{
          url: "/api/ExecAssignApp",
          type: "POST",
          data: { AssignTo: "AllDevices", appId: app?.id, tenantFilter: tenant },
          confirmText: "Are you sure you want to assign this application to all devices?",
          multiPost: false,
        }}
        row={app || {}}
        relatedQueryKeys={[`App-${appId}-${tenant}`]}
      />
      <CippApiDialog
        title="Assign to Custom Group"
        createDialog={assignGroupDialog}
        api={{
          url: "/api/ExecAssignApp",
          type: "POST",
          data: { appId: app?.id, tenantFilter: tenant },
          confirmText: "Select a group to assign this application to.",
          multiPost: false,
        }}
        row={app || {}}
        fields={[
          {
            type: "autoComplete",
            name: "customGroup",
            label: "Select Group",
            multiple: false,
            creatable: false,
            api: {
              url: "/api/ListGroups",
              data: { tenantFilter: tenant },
              queryKey: `ListGroups-${tenant}`,
              labelField: "displayName",
              valueField: "id",
            },
          },
        ]}
        relatedQueryKeys={[`App-${appId}-${tenant}`]}
      />
      <CippApiDialog
        title="Delete Application"
        createDialog={deleteDialog}
        api={{
          url: "/api/RemoveApp",
          type: "POST",
          data: { ID: app?.id, tenantFilter: tenant },
          confirmText: "Are you sure you want to delete this application? This action cannot be undone.",
          multiPost: false,
        }}
        row={app || {}}
        relatedQueryKeys={[`App-${appId}-${tenant}`]}
      />
    </Container>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
