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
  Extension,
  Business,
  CalendarToday,
  Info,
  Lock,
  LockOpen,
  Description,
} from "@mui/icons-material";
import { useRouter } from "next/router";
import { useMemo, useCallback } from "react";
import { ApiGetCall } from "../../../../api/ApiCall";
import { useSettings } from "../../../../hooks/use-settings";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";

const Page = () => {
  const pageTitle = "Dynamics 365 Solutions";
  const router = useRouter();
  const { dynamicsUrl, envName } = router.query;
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));
  const tenant = useSettings().currentTenant;

  const environmentsList = ApiGetCall({
    url: "/api/ListDynamicsEnvironments",
    queryKey: `dynamics-environments-for-solutions-${tenant}`,
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
        value: [{ id: "solutionType", value: "Managed" }],
        type: "column",
      },
      {
        filterName: "Unmanaged",
        value: [{ id: "solutionType", value: "Unmanaged" }],
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
                <Extension />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.friendlyname || "Unknown Solution"}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center">
                  <Chip
                    label={`v${row.version}`}
                    size="small"
                    color="primary"
                    variant="outlined"
                  />
                  <Chip
                    icon={
                      row.ismanaged ? (
                        <Lock fontSize="small" />
                      ) : (
                        <LockOpen fontSize="small" />
                      )
                    }
                    label={row.solutionType}
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
              Solution Details
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Unique Name
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.uniquename || "N/A"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Version
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.version || "N/A"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Publisher
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.publisher || "N/A"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Type
                </Typography>
                <Chip
                  label={row.solutionType}
                  size="small"
                  color={row.ismanaged ? "default" : "warning"}
                />
              </Stack>
              {row.description && (
                <Box>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                    Description
                  </Typography>
                  <Typography variant="body2">{row.description}</Typography>
                </Box>
              )}
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Installed
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.installedon ? getCippFormatting(row.installedon, "installedon") : "N/A"}
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
        ? ["friendlyname", "version", "solutionType"]
        : [
            "friendlyname",
            "uniquename",
            "version",
            "publisher",
            "solutionType",
            "installedon",
            "modifiedon",
          ],
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
              Select a Dynamics 365 environment to view its installed solutions.
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
                      `/dynamics/administration/solutions?dynamicsUrl=${encodeURIComponent(
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
      apiUrl="/api/ListDynamicsSolutions"
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
