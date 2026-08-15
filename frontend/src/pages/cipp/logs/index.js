import { useState, useMemo } from "react";
import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { CippTablePage } from "../../../components/CippComponents/CippTablePage.jsx";
import {
  Button,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Typography,
  SvgIcon,
  Alert,
  Box,
  Card,
  CardContent,
  Chip,
  Divider,
  Tooltip,
} from "@mui/material";
import { Grid, Stack } from "@mui/system";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import { useForm } from "react-hook-form";
import CippFormComponent from "../../../components/CippComponents/CippFormComponent";
import {
  FunnelIcon,
  XMarkIcon,
  CalendarDaysIcon,
  UserIcon,
  ExclamationTriangleIcon,
  InformationCircleIcon,
  ExclamationCircleIcon,
  BugAntIcon,
  BellAlertIcon,
  FireIcon,
  ClockIcon,
  GlobeAltIcon,
  ServerIcon,
  BuildingOfficeIcon,
  DocumentTextIcon,
} from "@heroicons/react/24/outline";
import { EyeIcon } from "@heroicons/react/24/outline";
import { getCippFormatting } from "../../../utils/get-cipp-formatting";
import { useSettings } from "../../../hooks/use-settings.js";

const offcanvas = {
  extendedInfoFields: ["DateTime", "API", "Severity", "Message", "User", "AppId", "IP", "LogData"],
};

const apiUrl = "/api/Listlogs";
const pageTitle = "Logbook";

const actions = [
  {
    label: "View Log Entry",
    link: "/cipp/logs/logentry?logentry=[RowKey]&date=[PartitionKey]",
    icon: <EyeIcon />,
    color: "info",
    category: "view",
  },
];

// Severity configuration with colors and icons
const severityConfig = {
  Info: { color: "info", icon: <InformationCircleIcon style={{ width: 14, height: 14 }} /> },
  Warn: { color: "warning", icon: <ExclamationTriangleIcon style={{ width: 14, height: 14 }} /> },
  Error: { color: "error", icon: <ExclamationCircleIcon style={{ width: 14, height: 14 }} /> },
  Critical: { color: "error", icon: <FireIcon style={{ width: 14, height: 14 }} /> },
  Alert: { color: "warning", icon: <BellAlertIcon style={{ width: 14, height: 14 }} /> },
  Debug: { color: "default", icon: <BugAntIcon style={{ width: 14, height: 14 }} /> },
};

// Quick date presets
const getDatePreset = (preset) => {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  switch (preset) {
    case "today":
      return { start: today, end: today };
    case "yesterday": {
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      return { start: yesterday, end: yesterday };
    }
    case "last7days": {
      const weekAgo = new Date(today);
      weekAgo.setDate(weekAgo.getDate() - 7);
      return { start: weekAgo, end: today };
    }
    case "last30days": {
      const monthAgo = new Date(today);
      monthAgo.setDate(monthAgo.getDate() - 30);
      return { start: monthAgo, end: today };
    }
    default:
      return { start: null, end: null };
  }
};

const Page = () => {
  const formControl = useForm({
    defaultValues: {
      startDate: null,
      endDate: null,
      username: "",
      severity: [],
    },
  });

  const [expanded, setExpanded] = useState(false);
  const [filterEnabled, setFilterEnabled] = useState(false);
  const [startDate, setStartDate] = useState(null);
  const [endDate, setEndDate] = useState(null);
  const [username, setUsername] = useState(null);
  const [severity, setSeverity] = useState(null);
  const [activePreset, setActivePreset] = useState(null);
  const settings = useSettings();
  const currentTenant = settings?.currentTenant;

  const watchStartDate = formControl.watch("startDate");
  const watchEndDate = formControl.watch("endDate");

  // Custom columns with better formatting
  const columns = useMemo(
    () => [
      {
        header: "Date/Time",
        id: "DateTime",
        accessorKey: "DateTime",
        size: 180,
        Cell: ({ row }) => (
          <Stack direction="row" spacing={1} alignItems="center">
            <ClockIcon style={{ width: 14, height: 14, opacity: 0.6 }} />
            <Typography variant="body2">
              {getCippFormatting(row.original.DateTime, "DateTime")}
            </Typography>
          </Stack>
        ),
      },
      {
        header: "Tenant",
        id: "Tenant",
        accessorKey: "Tenant",
        size: 200,
        Cell: ({ row }) => (
          <Stack direction="row" spacing={1} alignItems="center">
            <BuildingOfficeIcon style={{ width: 14, height: 14, opacity: 0.6 }} />
            <Tooltip title={row.original.Tenant} arrow>
              <Typography
                variant="body2"
                sx={{
                  maxWidth: 180,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {row.original.Tenant}
              </Typography>
            </Tooltip>
          </Stack>
        ),
      },
      {
        header: "User",
        id: "User",
        accessorKey: "User",
        size: 180,
        Cell: ({ row }) => (
          <Stack direction="row" spacing={1} alignItems="center">
            <UserIcon style={{ width: 14, height: 14, opacity: 0.6 }} />
            <Tooltip title={row.original.User} arrow>
              <Typography
                variant="body2"
                sx={{
                  maxWidth: 160,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {row.original.User}
              </Typography>
            </Tooltip>
          </Stack>
        ),
      },
      {
        header: "Message",
        id: "Message",
        accessorKey: "Message",
        size: 350,
        Cell: ({ row }) => (
          <Tooltip title={row.original.Message} arrow>
            <Typography
              variant="body2"
              sx={{
                maxWidth: 330,
                overflow: "hidden",
                textOverflow: "ellipsis",
                whiteSpace: "nowrap",
              }}
            >
              {row.original.Message}
            </Typography>
          </Tooltip>
        ),
      },
      {
        header: "API",
        id: "API",
        accessorKey: "API",
        size: 150,
        Cell: ({ row }) => (
          <Stack direction="row" spacing={1} alignItems="center">
            <ServerIcon style={{ width: 14, height: 14, opacity: 0.6 }} />
            <Typography variant="body2" fontFamily="monospace" fontSize="0.8rem">
              {row.original.API}
            </Typography>
          </Stack>
        ),
      },
      {
        header: "Severity",
        id: "Severity",
        accessorKey: "Severity",
        size: 120,
        Cell: ({ row }) => {
          const sev = row.original.Severity;
          const config = severityConfig[sev] || { color: "default", icon: null };
          return (
            <Chip
              label={sev}
              size="small"
              color={config.color}
              variant={sev === "Error" || sev === "Critical" ? "filled" : "outlined"}
              icon={config.icon}
            />
          );
        },
      },
      {
        header: "IP Address",
        id: "IP",
        accessorKey: "IP",
        size: 130,
        Cell: ({ row }) => (
          <Stack direction="row" spacing={1} alignItems="center">
            <GlobeAltIcon style={{ width: 14, height: 14, opacity: 0.6 }} />
            <Typography variant="body2" fontFamily="monospace" fontSize="0.8rem">
              {row.original.IP || "-"}
            </Typography>
          </Stack>
        ),
      },
    ],
    []
  );

  // Date range warning component
  const DateRangeWarning = () => {
    if (!watchStartDate || !watchEndDate) return null;

    const startDateMs = new Date(watchStartDate * 1000);
    const endDateMs = new Date(watchEndDate * 1000);
    const daysDifference = (endDateMs - startDateMs) / (1000 * 60 * 60 * 24);

    if (daysDifference > 10) {
      return (
        <Grid size={{ sm: 12, md: 8 }}>
          <Alert severity="info" icon={<InformationCircleIcon style={{ width: 20 }} />}>
            You have selected a date range of <strong>{Math.ceil(daysDifference)} days</strong>.
            Results load progressively in small batches (newest first), so the full range may
            take a moment to finish loading.
          </Alert>
        </Grid>
      );
    }

    return null;
  };

  const applyDatePreset = (preset) => {
    const { start, end } = getDatePreset(preset);
    if (start && end) {
      formControl.setValue("startDate", Math.floor(start.getTime() / 1000));
      formControl.setValue("endDate", Math.floor(end.getTime() / 1000));
      setActivePreset(preset);
    }
  };

  const onSubmit = (data) => {
    const hasFilter =
      data.startDate !== null ||
      data.endDate !== null ||
      data.username !== null ||
      data.severity?.length > 0;
    setFilterEnabled(hasFilter);

    setStartDate(
      data.startDate
        ? new Date(data.startDate * 1000).toISOString().split("T")[0].replace(/-/g, "")
        : null
    );

    setEndDate(
      data.endDate
        ? new Date(data.endDate * 1000).toISOString().split("T")[0].replace(/-/g, "")
        : null
    );

    setUsername(data.username || null);

    setSeverity(
      data.severity && data.severity.length > 0
        ? data.severity.map((item) => item.value).join(",")
        : null
    );

    setExpanded(false);
  };

  const clearFilters = () => {
    formControl.reset({
      startDate: null,
      endDate: null,
      username: "",
      severity: [],
    });
    setFilterEnabled(false);
    setStartDate(null);
    setEndDate(null);
    setUsername(null);
    setSeverity(null);
    setActivePreset(null);
    setExpanded(false);
  };

  // Build filter summary chips
  const filterChips = useMemo(() => {
    const chips = [];
    if (startDate || endDate) {
      const startFormatted = startDate
        ? new Date(startDate.replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3") + "T00:00:00").toLocaleDateString()
        : "Start";
      const endFormatted = endDate
        ? new Date(endDate.replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3") + "T00:00:00").toLocaleDateString()
        : "End";
      chips.push({ label: `${startFormatted} - ${endFormatted}`, icon: <CalendarDaysIcon style={{ width: 14 }} /> });
    }
    if (username) {
      chips.push({ label: `User: ${username}`, icon: <UserIcon style={{ width: 14 }} /> });
    }
    if (severity) {
      chips.push({ label: `Severity: ${severity.replace(/,/g, ", ")}`, icon: <ExclamationTriangleIcon style={{ width: 14 }} /> });
    }
    return chips;
  }, [startDate, endDate, username, severity]);

  return (
    <CippTablePage
      tableFilter={
        <Card variant="outlined">
          <Accordion
            expanded={expanded}
            onChange={() => setExpanded(!expanded)}
            sx={{
              boxShadow: "none",
              "&:before": { display: "none" },
              backgroundColor: "transparent",
            }}
          >
            <AccordionSummary
              expandIcon={<ExpandMoreIcon />}
              sx={{
                minHeight: 56,
                "& .MuiAccordionSummary-content": {
                  alignItems: "center",
                },
              }}
            >
              <Stack
                direction="row"
                spacing={2}
                alignItems="center"
                sx={{ width: "100%" }}
                flexWrap="wrap"
              >
                <Stack direction="row" spacing={1} alignItems="center">
                  <SvgIcon fontSize="small" color="primary">
                    <FunnelIcon />
                  </SvgIcon>
                  <Typography variant="subtitle1" fontWeight={600}>
                    Filters
                  </Typography>
                </Stack>

                {filterEnabled ? (
                  <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                    {filterChips.map((chip, index) => (
                      <Chip
                        key={index}
                        label={chip.label}
                        size="small"
                        color="primary"
                        variant="outlined"
                        icon={chip.icon}
                      />
                    ))}
                  </Stack>
                ) : (
                  <Chip
                    label={`Today: ${new Date().toLocaleDateString()}`}
                    size="small"
                    variant="outlined"
                    icon={<CalendarDaysIcon style={{ width: 14 }} />}
                  />
                )}
              </Stack>
            </AccordionSummary>
            <Divider />
            <AccordionDetails sx={{ pt: 3 }}>
              <form onSubmit={formControl.handleSubmit(onSubmit)}>
                <Grid container spacing={3}>
                  {/* Quick Presets */}
                  <Grid size={12}>
                    <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
                      <Typography variant="body2" color="text.secondary" sx={{ mr: 1 }}>
                        Quick Select:
                      </Typography>
                      {[
                        { key: "today", label: "Today" },
                        { key: "yesterday", label: "Yesterday" },
                        { key: "last7days", label: "Last 7 Days" },
                        { key: "last30days", label: "Last 30 Days" },
                      ].map((preset) => (
                        <Chip
                          key={preset.key}
                          label={preset.label}
                          size="small"
                          onClick={() => applyDatePreset(preset.key)}
                          color={activePreset === preset.key ? "primary" : "default"}
                          variant={activePreset === preset.key ? "filled" : "outlined"}
                          sx={{ cursor: "pointer" }}
                        />
                      ))}
                    </Stack>
                  </Grid>

                  {/* Info Alert */}
                  <Grid size={{ xs: 12, md: 8 }}>
                    <Alert severity="info" icon={<InformationCircleIcon style={{ width: 20 }} />}>
                      <Typography variant="body2">
                        Filter logs by date range, username, and severity levels. By default, the
                        logbook shows the current day based on UTC time. Your local timezone is{" "}
                        <strong>UTC{new Date().getTimezoneOffset() / -60 >= 0 ? "+" : ""}
                        {new Date().getTimezoneOffset() / -60}</strong>.
                      </Typography>
                    </Alert>
                  </Grid>

                  {/* Date Filters */}
                  <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                    <CippFormComponent
                      type="datePicker"
                      name="startDate"
                      label="Start Date"
                      dateTimeType="date"
                      formControl={formControl}
                    />
                  </Grid>
                  <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                    <CippFormComponent
                      type="datePicker"
                      name="endDate"
                      label="End Date"
                      dateTimeType="date"
                      formControl={formControl}
                      validators={{
                        validate: (value) => {
                          const startDate = formControl.getValues("startDate");
                          if (value && !startDate) {
                            return "Start date must be set when using an end date";
                          }
                          if (
                            startDate &&
                            value &&
                            new Date(value * 1000) < new Date(startDate * 1000)
                          ) {
                            return "End date must be after start date";
                          }
                          return true;
                        },
                      }}
                    />
                  </Grid>

                  {/* Date Range Warning */}
                  <DateRangeWarning />

                  {/* Username Filter */}
                  <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                    <CippFormComponent
                      type="textField"
                      name="username"
                      label="Filter by Username"
                      formControl={formControl}
                      placeholder="Enter username"
                      fullWidth
                    />
                  </Grid>

                  {/* Severity Filter */}
                  <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                    <CippFormComponent
                      type="autoComplete"
                      name="severity"
                      label="Filter by Severity"
                      formControl={formControl}
                      multiple={true}
                      options={[
                        { value: "Info", label: "Info" },
                        { value: "Warn", label: "Warning" },
                        { value: "Error", label: "Error" },
                        { value: "Critical", label: "Critical" },
                        { value: "Alert", label: "Alert" },
                        { value: "Debug", label: "Debug" },
                      ]}
                      placeholder="Select severity levels"
                    />
                  </Grid>

                  {/* Action Buttons */}
                  <Grid size={12}>
                    <Divider sx={{ my: 1 }} />
                    <Stack direction="row" spacing={2} sx={{ mt: 2 }}>
                      <Button
                        type="submit"
                        variant="contained"
                        color="primary"
                        startIcon={
                          <SvgIcon fontSize="small">
                            <FunnelIcon />
                          </SvgIcon>
                        }
                      >
                        Apply Filters
                      </Button>
                      <Button
                        variant="outlined"
                        color="inherit"
                        startIcon={
                          <SvgIcon fontSize="small">
                            <XMarkIcon />
                          </SvgIcon>
                        }
                        onClick={clearFilters}
                      >
                        Clear Filters
                      </Button>
                    </Stack>
                  </Grid>
                </Grid>
              </form>
            </AccordionDetails>
          </Accordion>
        </Card>
      }
      title={pageTitle}
      apiUrl={apiUrl}
      apiDataKey="Results"
      columns={columns}
      queryKey={`Listlogs-${startDate}-${endDate}-${username}-${severity}-${filterEnabled}-${currentTenant}`}
      tenantInTitle={true}
      apiData={{
        StartDate: startDate,
        EndDate: endDate,
        User: username,
        Severity: severity,
        Filter: filterEnabled,
        Tenant: currentTenant,
        // ListLogs pages date ranges via Metadata.nextLink. tenantFilter must not be
        // "AllTenants" or getNextPageParam stops pagination after the first batch
        // (that guard is for queued Graph AllTenants requests, which don't apply here).
        tenantFilter: null,
      }}
      actions={actions}
      spacing={1}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
