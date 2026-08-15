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
  Business,
  AccountTree,
  Email,
  Language,
  CalendarToday,
  Info,
  CheckCircle,
  Cancel,
  LocationCity,
} from "@mui/icons-material";
import { useRouter } from "next/router";
import { useMemo, useCallback } from "react";
import { ApiGetCall } from "../../../../api/ApiCall";
import { useSettings } from "../../../../hooks/use-settings";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";

const Page = () => {
  const pageTitle = "Dynamics 365 Business Units";
  const router = useRouter();
  const { dynamicsUrl, envName } = router.query;
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));
  const tenant = useSettings().currentTenant;

  const environmentsList = ApiGetCall({
    url: "/api/ListDynamicsEnvironments",
    queryKey: `dynamics-environments-for-bus-${tenant}`,
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
        filterName: "Active",
        value: [{ id: "isdisabled", value: false }],
        type: "column",
      },
      {
        filterName: "Root Units",
        value: [{ id: "isRoot", value: true }],
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
                theme.palette.secondary.main,
                0.15
              )} 0%, ${alpha(theme.palette.secondary.main, 0.05)} 100%)`,
              borderLeft: `4px solid ${theme.palette.secondary.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(theme.palette.secondary.main, 0.15),
                  color: theme.palette.secondary.main,
                  width: 56,
                  height: 56,
                }}
              >
                <Business />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.name || "Unknown Business Unit"}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center">
                  {row.isRoot && (
                    <Chip
                      icon={<AccountTree fontSize="small" />}
                      label="Root"
                      size="small"
                      color="primary"
                      variant="outlined"
                    />
                  )}
                  <Chip
                    icon={
                      row.isdisabled ? (
                        <Cancel fontSize="small" />
                      ) : (
                        <CheckCircle fontSize="small" />
                      )
                    }
                    label={row.isdisabled ? "Disabled" : "Active"}
                    size="small"
                    color={row.isdisabled ? "error" : "success"}
                    variant="outlined"
                  />
                </Stack>
              </Box>
            </Stack>
          </Paper>

          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Business Unit Details
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between">
                <Typography variant="body2" color="text.secondary">
                  Parent Business Unit
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.parentName || "N/A"}
                </Typography>
              </Stack>
              {row.divisionname && (
                <Stack direction="row" justifyContent="space-between">
                  <Typography variant="body2" color="text.secondary">
                    Division
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.divisionname}
                  </Typography>
                </Stack>
              )}
              {row.emailaddress && (
                <Stack direction="row" justifyContent="space-between">
                  <Typography variant="body2" color="text.secondary">
                    Email
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.emailaddress}
                  </Typography>
                </Stack>
              )}
              {(row.city || row.stateOrProvince || row.country) && (
                <Stack direction="row" justifyContent="space-between">
                  <Typography variant="body2" color="text.secondary">
                    Location
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {[row.city, row.stateOrProvince, row.country].filter(Boolean).join(", ")}
                  </Typography>
                </Stack>
              )}
              {row.websiteurl && (
                <Stack direction="row" justifyContent="space-between">
                  <Typography variant="body2" color="text.secondary">
                    Website
                  </Typography>
                  <Typography
                    component="a"
                    href={row.websiteurl}
                    target="_blank"
                    rel="noopener noreferrer"
                    variant="body2"
                    sx={{
                      color: "primary.main",
                      textDecoration: "none",
                      "&:hover": { textDecoration: "underline" },
                    }}
                  >
                    {row.websiteurl}
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
        ? ["name", "parentName", "isdisabled"]
        : ["name", "parentName", "isdisabled", "divisionname", "emailaddress", "websiteurl", "createdon"],
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
              Select a Dynamics 365 environment to view its business units.
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
                      `/dynamics/administration/business-units?dynamicsUrl=${encodeURIComponent(
                        env.apiUrl
                      )}&envName=${encodeURIComponent(env.displayName)}`
                    )
                  }
                >
                  <Stack direction="row" alignItems="center" spacing={2}>
                    <Avatar sx={{ bgcolor: alpha(theme.palette.secondary.main, 0.15) }}>
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
      apiUrl="/api/ListDynamicsBusinessUnits"
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
