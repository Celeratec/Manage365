import { useRouter } from "next/router";
import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { ApiGetCall } from "../../../api/ApiCall";
import { Button, SvgIcon, Box, Container, Chip, Card, CardHeader, CardContent, Typography, Alert } from "@mui/material";
import { Grid, Stack } from "@mui/system";
import { CippPropertyListCard } from "../../../components/CippCards/CippPropertyListCard";
import { CippInfoBar } from "../../../components/CippCards/CippInfoBar";
import CippFormSkeleton from "../../../components/CippFormPages/CippFormSkeleton";
import { getCippTranslation } from "../../../utils/get-cipp-translation";
import { getCippFormatting } from "../../../utils/get-cipp-formatting";
import {
  ClockIcon,
  ServerIcon,
  ExclamationTriangleIcon,
  InformationCircleIcon,
  ExclamationCircleIcon,
  FireIcon,
  BellAlertIcon,
  BugAntIcon,
  ArrowLeftIcon,
  DocumentTextIcon,
  UserIcon,
  BuildingOfficeIcon,
  GlobeAltIcon,
  IdentificationIcon,
  ChatBubbleLeftRightIcon,
  CodeBracketIcon,
  CubeIcon,
} from "@heroicons/react/24/outline";
import { CippHead } from "../../../components/CippComponents/CippHead";
import Link from "next/link";

// Severity configuration
const severityConfig = {
  Info: { color: "info", icon: <InformationCircleIcon />, label: "Informational" },
  Warn: { color: "warning", icon: <ExclamationTriangleIcon />, label: "Warning" },
  Warning: { color: "warning", icon: <ExclamationTriangleIcon />, label: "Warning" },
  Error: { color: "error", icon: <ExclamationCircleIcon />, label: "Error" },
  Critical: { color: "error", icon: <FireIcon />, label: "Critical" },
  CRITICAL: { color: "error", icon: <FireIcon />, label: "Critical" },
  Alert: { color: "warning", icon: <BellAlertIcon />, label: "Alert" },
  Debug: { color: "default", icon: <BugAntIcon />, label: "Debug" },
};

const Page = () => {
  const router = useRouter();
  const { logentry, date } = router.query;

  const logRequest = ApiGetCall({
    url: `/api/Listlogs`,
    data: {
      logentryid: logentry,
      datefilter: date || null,
    },
    queryKey: `GetLogEntry-${logentry}-${date}`,
    waiting: !!logentry,
  });

  const logData = logRequest.data?.[0];
  const sevConfig = severityConfig[logData?.Severity] || severityConfig.Info;

  // Top info bar data
  const logInfo = logData
    ? [
        {
          name: "Date & Time",
          data: getCippFormatting(logData.DateTime, "DateTime"),
          icon: <ClockIcon />,
        },
        {
          name: "API Endpoint",
          data: logData.API,
          icon: <ServerIcon />,
        },
        {
          name: "Severity",
          data: (
            <Chip
              label={logData.Severity}
              color={sevConfig.color}
              variant={logData.Severity === "Error" || logData.Severity === "Critical" || logData.Severity === "CRITICAL" ? "filled" : "outlined"}
              size="small"
              icon={sevConfig.icon}
            />
          ),
          icon: <ExclamationTriangleIcon />,
        },
        {
          name: "Log ID",
          data: (
            <Typography variant="body2" fontFamily="monospace" fontSize="0.75rem">
              {logData.RowKey?.substring(0, 20)}...
            </Typography>
          ),
          icon: <IdentificationIcon />,
        },
      ]
    : [];

  // Main log properties with icons
  const propertyItems = logData
    ? [
        {
          label: "Tenant",
          value: logData.Tenant,
          icon: <BuildingOfficeIcon style={{ width: 18, height: 18 }} />,
        },
        {
          label: "User",
          value: logData.User,
          icon: <UserIcon style={{ width: 18, height: 18 }} />,
        },
        {
          label: "Message",
          value: logData.Message,
          icon: <ChatBubbleLeftRightIcon style={{ width: 18, height: 18 }} />,
        },
        {
          label: "Tenant ID",
          value: logData.TenantID || "N/A",
          icon: <IdentificationIcon style={{ width: 18, height: 18 }} />,
        },
        {
          label: "App ID",
          value: logData.AppId || "N/A",
          icon: <CubeIcon style={{ width: 18, height: 18 }} />,
        },
        {
          label: "IP Address",
          value: logData.IP || "N/A",
          icon: <GlobeAltIcon style={{ width: 18, height: 18 }} />,
        },
      ]
    : [];

  // LogData properties
  const logDataItems =
    logData?.LogData && typeof logData.LogData === "object"
      ? Object.entries(logData.LogData).map(([key, value]) => ({
          label: key,
          value: typeof value === "object" ? JSON.stringify(value, null, 2) : String(value),
        }))
      : [];

  return (
    <>
      <CippHead title="Log Entry Details" noTenant={true} />
      <Box sx={{ flexGrow: 1, py: 2 }}>
        <Container maxWidth={false}>
          <Stack spacing={2}>
            {/* Back Button */}
            <Box>
              <Button
                component={Link}
                href="/cipp/logs"
                startIcon={
                  <SvgIcon fontSize="small">
                    <ArrowLeftIcon />
                  </SvgIcon>
                }
                color="inherit"
                sx={{ mb: 1 }}
              >
                Back to Logbook
              </Button>
            </Box>

            {logRequest.isLoading && <CippFormSkeleton layout={[1, 1, 1]} />}

            {logRequest.isError && (
              <Alert severity="error" icon={<ExclamationCircleIcon style={{ width: 20 }} />}>
                Failed to load log entry. The log may have been deleted or the ID is invalid.
              </Alert>
            )}

            {logRequest.isSuccess && !logData && (
              <Alert severity="warning" icon={<ExclamationTriangleIcon style={{ width: 20 }} />}>
                Log entry not found. It may have been deleted or expired.
              </Alert>
            )}

            {logRequest.isSuccess && logData && (
              <>
                {/* Status Info Bar */}
                <CippInfoBar data={logInfo} isFetching={logRequest.isLoading} />

                {/* Main Content Grid */}
                <Grid container spacing={2}>
                  {/* Log Details Card */}
                  <Grid size={{ xs: 12, lg: logDataItems.length > 0 ? 6 : 12 }}>
                    <CippPropertyListCard
                      title="Log Details"
                      propertyItems={propertyItems}
                      isFetching={logRequest.isLoading}
                      cardSx={{ height: "100%" }}
                    />
                  </Grid>

                  {/* Additional Log Data Card */}
                  {logDataItems.length > 0 && (
                    <Grid size={{ xs: 12, lg: 6 }}>
                      <Card variant="outlined" sx={{ height: "100%" }}>
                        <CardHeader
                          title={
                            <Stack direction="row" spacing={1} alignItems="center">
                              <SvgIcon fontSize="small" color="primary">
                                <CodeBracketIcon />
                              </SvgIcon>
                              <Typography variant="h6">Additional Data</Typography>
                            </Stack>
                          }
                        />
                        <CardContent>
                          <Stack spacing={2}>
                            {logDataItems.map((item, index) => (
                              <Box key={index}>
                                <Typography
                                  variant="caption"
                                  color="text.secondary"
                                  sx={{ textTransform: "uppercase", fontWeight: 600 }}
                                >
                                  {item.label}
                                </Typography>
                                <Typography
                                  variant="body2"
                                  sx={{
                                    fontFamily: item.value.includes("{") ? "monospace" : "inherit",
                                    fontSize: item.value.includes("{") ? "0.75rem" : "inherit",
                                    whiteSpace: item.value.includes("{") ? "pre-wrap" : "normal",
                                    backgroundColor: item.value.includes("{")
                                      ? "action.hover"
                                      : "transparent",
                                    p: item.value.includes("{") ? 1 : 0,
                                    borderRadius: 1,
                                    wordBreak: "break-word",
                                  }}
                                >
                                  {item.value}
                                </Typography>
                              </Box>
                            ))}
                          </Stack>
                        </CardContent>
                      </Card>
                    </Grid>
                  )}

                  {/* Standard Card */}
                  {logData?.Standard?.Standard && (
                    <Grid size={12}>
                      <CippPropertyListCard
                        title="Standard Information"
                        propertyItems={Object.entries(logData.Standard).map(([key, value]) => ({
                          label: getCippTranslation(key),
                          value: value ?? "N/A",
                        }))}
                        isFetching={logRequest.isLoading}
                        layout="multiple"
                        showDivider={false}
                        variant="outlined"
                      />
                    </Grid>
                  )}
                </Grid>
              </>
            )}
          </Stack>
        </Container>
      </Box>
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
