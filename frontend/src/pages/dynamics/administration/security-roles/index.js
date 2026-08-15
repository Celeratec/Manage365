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
  Security,
  Business,
  CalendarToday,
  Info,
  Lock,
  LockOpen,
} from "@mui/icons-material";
import { useRouter } from "next/router";
import { useMemo, useCallback } from "react";
import { ApiGetCall } from "../../../../api/ApiCall";
import { useSettings } from "../../../../hooks/use-settings";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";

const Page = () => {
  const pageTitle = "Dynamics 365 Security Roles";
  const router = useRouter();
  const { dynamicsUrl, envName } = router.query;
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));
  const tenant = useSettings().currentTenant;

  const environmentsList = ApiGetCall({
    url: "/api/ListDynamicsEnvironments",
    queryKey: `dynamics-environments-for-roles-${tenant}`,
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
        filterName: "Managed",
        value: [{ id: "roleType", value: "Managed" }],
        type: "column",
      },
      {
        filterName: "Custom",
        value: [{ id: "roleType", value: "Custom" }],
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
                theme.palette.info.main,
                0.15
              )} 0%, ${alpha(theme.palette.info.main, 0.05)} 100%)`,
              borderLeft: `4px solid ${theme.palette.info.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(theme.palette.info.main, 0.15),
                  color: theme.palette.info.main,
                  width: 56,
                  height: 56,
                }}
              >
                <Security />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.name || "Unknown Role"}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center">
                  <Chip
                    icon={row.ismanaged ? <Lock fontSize="small" /> : <LockOpen fontSize="small" />}
                    label={row.roleType}
                    size="small"
                    color={row.ismanaged ? "default" : "warning"}
                    variant="outlined"
                  />
                </Stack>
              </Box>
            </Stack>
          </Paper>

          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Role Details
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Type
                </Typography>
                <Chip
                  label={row.roleType}
                  size="small"
                  color={row.ismanaged ? "default" : "warning"}
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
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Can Be Deleted
                </Typography>
                <Chip
                  label={row.canbedeleted ? "Yes" : "No"}
                  size="small"
                  color={row.canbedeleted ? "success" : "error"}
                  variant="outlined"
                />
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Inherited
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.isinherited ? "Yes" : "No"}
                </Typography>
              </Stack>
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
        ? ["name", "roleType", "businessUnit"]
        : ["name", "roleType", "businessUnit", "isinherited", "canbedeleted", "createdon", "modifiedon"],
    [isMobile]
  );

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
              Select a Dynamics 365 environment to view its security roles.
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
                      `/dynamics/administration/security-roles?dynamicsUrl=${encodeURIComponent(
                        env.apiUrl
                      )}&envName=${encodeURIComponent(env.displayName)}`
                    )
                  }
                >
                  <Stack direction="row" alignItems="center" spacing={2}>
                    <Avatar sx={{ bgcolor: alpha(theme.palette.info.main, 0.15) }}>
                      <Business />
                    </Avatar>
                    <Box>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                        {env.displayName}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {env.environmentType} &middot; {env.region}
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
      apiUrl="/api/ListDynamicsSecurityRoles"
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
