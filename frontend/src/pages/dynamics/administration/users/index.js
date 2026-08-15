import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import {
  Chip,
  Typography,
  Stack,
  Paper,
  Avatar,
  Divider,
  Alert,
  useTheme,
  useMediaQuery,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Container } from "@mui/system";
import {
  Person,
  Security,
  Business,
  Email,
  CalendarToday,
  Info,
  CheckCircle,
  Cancel,
} from "@mui/icons-material";
import { useRouter } from "next/router";
import { useMemo, useCallback } from "react";
import { ApiGetCall } from "../../../../api/ApiCall";
import { useSettings } from "../../../../hooks/use-settings";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";

const Page = () => {
  const pageTitle = "Dynamics 365 Users";
  const router = useRouter();
  const { dynamicsUrl, envName } = router.query;
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));
  const tenant = useSettings().currentTenant;

  // If no dynamicsUrl provided, show a list of environments to select from
  const environmentsList = ApiGetCall({
    url: "/api/ListDynamicsEnvironments",
    queryKey: `dynamics-environments-for-users-${tenant}`,
    data: { tenantFilter: tenant },
    waiting: !dynamicsUrl && !!tenant,
  });

  const actions = useMemo(
    () => [
      {
        label: "View Details",
        type: "link",
        icon: <Info />,
        link: "#",
        category: "view",
        quickAction: true,
      },
    ],
    []
  );

  const filters = useMemo(
    () => [
      {
        filterName: "Active Users",
        value: [{ id: "isdisabled", value: false }],
        type: "column",
      },
      {
        filterName: "Read-Write",
        value: [{ id: "accessmode", value: "Read-Write" }],
        type: "column",
      },
      {
        filterName: "Administrative",
        value: [{ id: "accessmode", value: "Administrative" }],
        type: "column",
      },
      {
        filterName: "Non-Interactive",
        value: [{ id: "accessmode", value: "Non-Interactive" }],
        type: "column",
      },
    ],
    []
  );

  const offCanvasChildren = useCallback(
    (row) => {
      return (
        <Stack spacing={3}>
          <Paper
            elevation={0}
            sx={{
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(
                theme.palette.primary.main,
                0.15
              )} 0%, ${alpha(theme.palette.primary.main, 0.05)} 100%)`,
              borderLeft: `4px solid ${theme.palette.primary.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(theme.palette.primary.main, 0.15),
                  color: theme.palette.primary.main,
                  width: 56,
                  height: 56,
                }}
              >
                <Person />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.fullname || "Unknown User"}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {row.email}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              User Details
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Domain Name
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.domainname || "N/A"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Access Mode
                </Typography>
                <Chip label={row.accessmode} size="small" color="primary" variant="outlined" />
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Status
                </Typography>
                <Chip
                  icon={row.isdisabled ? <Cancel fontSize="small" /> : <CheckCircle fontSize="small" />}
                  label={row.isdisabled ? "Disabled" : "Active"}
                  size="small"
                  color={row.isdisabled ? "error" : "success"}
                  variant="outlined"
                />
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Business Unit
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.businessUnit || "N/A"}
                </Typography>
              </Stack>
              {row.title && (
                <Stack direction="row" justifyContent="space-between">
                  <Typography variant="body2" color="text.secondary">
                    Title
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.title}
                  </Typography>
                </Stack>
              )}
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Created
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.createdon ? getCippFormatting(row.createdon, "createdon") : "N/A"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Modified
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.modifiedon ? getCippFormatting(row.modifiedon, "modifiedon") : "N/A"}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <Security fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Security Roles ({row.securityRoles?.length || 0})
              </Typography>
            </Stack>
            <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
              {row.securityRoles && row.securityRoles.length > 0 ? (
                row.securityRoles.map((role, index) => (
                  <Chip
                    key={role.roleid || index}
                    label={role.name}
                    size="small"
                    color="info"
                    variant="outlined"
                    sx={{ mb: 0.5 }}
                  />
                ))
              ) : (
                <Typography variant="body2" color="text.secondary">
                  No security roles assigned
                </Typography>
              )}
            </Stack>
          </Box>
        </Stack>
      );
    },
    [theme]
  );

  const offCanvas = useMemo(
    () => ({
      actions: actions,
      children: offCanvasChildren,
      size: "lg",
    }),
    [actions, offCanvasChildren]
  );

  const simpleColumns = useMemo(
    () =>
      isMobile
        ? ["fullname", "email", "accessmode"]
        : [
            "fullname",
            "email",
            "domainname",
            "accessmode",
            "businessUnit",
            "securityRoleList",
            "createdon",
          ],
    [isMobile]
  );

  // If no dynamicsUrl, show environment selection
  if (!dynamicsUrl) {
    const environments = environmentsList?.data?.Results || [];
    return (
      <DashboardLayout>
        <Box sx={{ py: 3 }}>
          <Container maxWidth={false}>
            <Typography variant="h4" sx={{ mb: 3 }}>
              {pageTitle}
            </Typography>
            <Alert severity="info" sx={{ mb: 3 }}>
              Select a Dynamics 365 environment to view its users.
            </Alert>
            <Stack spacing={2}>
              {environments.map((env) => (
                <Paper
                  key={env.name}
                  sx={{
                    p: 2,
                    cursor: "pointer",
                    "&:hover": { bgcolor: "action.hover" },
                    borderRadius: 2,
                  }}
                  variant="outlined"
                  onClick={() =>
                    router.push(
                      `/dynamics/administration/users?dynamicsUrl=${encodeURIComponent(
                        env.apiUrl
                      )}&envName=${encodeURIComponent(env.displayName)}`
                    )
                  }
                >
                  <Stack direction="row" alignItems="center" spacing={2}>
                    <Avatar sx={{ bgcolor: alpha(theme.palette.primary.main, 0.15) }}>
                      <Business />
                    </Avatar>
                    <Box>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                        {env.displayName}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {env.environmentType} &middot; {env.region} &middot; {env.url || env.apiUrl}
                      </Typography>
                    </Box>
                  </Stack>
                </Paper>
              ))}
              {environments.length === 0 && tenant && (
                <Alert severity="warning">
                  No Dynamics 365 environments found for this tenant, or still loading.
                </Alert>
              )}
            </Stack>
          </Container>
        </Box>
      </DashboardLayout>
    );
  }

  return (
    <CippTablePage
      title={envName ? `${pageTitle} - ${envName}` : pageTitle}
      tenantInTitle={true}
      apiUrl="/api/ListDynamicsUsers"
      apiData={{ DynamicsUrl: dynamicsUrl }}
      apiDataKey="Results"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      filters={filters}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
