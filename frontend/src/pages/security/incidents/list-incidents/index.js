import { useState } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import {
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
  Button,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  SvgIcon,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack, Grid } from "@mui/system";
import { 
  PersonAdd, 
  PlayArrow, 
  Assignment, 
  Done,
  Warning,
  Error as ErrorIcon,
  Info as InfoIcon,
  CheckCircle,
  Pending,
  OpenInNew,
  CalendarToday,
  LocalOffer,
} from "@mui/icons-material";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import { useForm } from "react-hook-form";
import CippFormComponent from "../../../../components/CippComponents/CippFormComponent";
import { FunnelIcon, XMarkIcon } from "@heroicons/react/24/outline";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";
import { useSettings } from "../../../../hooks/use-settings";

const defaultStartDate = (() => {
  const d = new Date();
  d.setDate(d.getDate() - 30);
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
})();

const Page = () => {
  const pageTitle = "Incidents List";
  const theme = useTheme();
  const userSettingsDefaults = useSettings();

  const formControl = useForm({ defaultValues: { startDate: defaultStartDate, endDate: null } });
  const [expanded, setExpanded] = useState(false);
  const [filterEnabled, setFilterEnabled] = useState(true);
  const [startDate, setStartDate] = useState(
    new Date(defaultStartDate * 1000).toISOString().split("T")[0].replace(/-/g, ""),
  );
  const [endDate, setEndDate] = useState(null);

  const onSubmit = (data) => {
    setStartDate(
      data.startDate
        ? new Date(data.startDate * 1000).toISOString().split("T")[0].replace(/-/g, "")
        : null,
    );
    setEndDate(
      data.endDate
        ? new Date(data.endDate * 1000).toISOString().split("T")[0].replace(/-/g, "")
        : null,
    );
    setFilterEnabled(data.startDate !== null || data.endDate !== null);
    setExpanded(false);
  };

  const clearFilters = () => {
    formControl.reset({ startDate: null, endDate: null });
    setFilterEnabled(false);
    setStartDate(null);
    setEndDate(null);
    setExpanded(false);
  };

  const fmt = (yyyymmdd) =>
    yyyymmdd
      ? new Date(
          yyyymmdd.replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3") + "T00:00:00",
        ).toLocaleDateString()
      : null;

  const tableFilter = (
    <Accordion expanded={expanded} onChange={(_, v) => setExpanded(v)}>
      <AccordionSummary expandIcon={<ExpandMoreIcon />}>
        <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
          <SvgIcon fontSize="small">
            <FunnelIcon />
          </SvgIcon>
          <Typography variant="body2">
            {filterEnabled && (startDate || endDate)
              ? startDate && endDate
                ? `Date Filter: ${fmt(startDate)} — ${fmt(endDate)}`
                : startDate
                  ? `Date Filter: From ${fmt(startDate)}`
                  : `Date Filter: Up to ${fmt(endDate)}`
              : "Date Filter"}
          </Typography>
        </Box>
      </AccordionSummary>
      <AccordionDetails>
        <Grid container spacing={2} alignItems="flex-end">
          <Grid size={{ xs: 12, md: 4 }}>
            <CippFormComponent
              type="datePicker"
              name="startDate"
              label="Start Date"
              dateTimeType="date"
              formControl={formControl}
            />
          </Grid>
          <Grid size={{ xs: 12, md: 4 }}>
            <CippFormComponent
              type="datePicker"
              name="endDate"
              label="End Date"
              dateTimeType="date"
              formControl={formControl}
            />
          </Grid>
          <Grid size={{ xs: 12, md: 4 }}>
            <Stack direction="row" spacing={1}>
              <Button variant="contained" onClick={formControl.handleSubmit(onSubmit)}>
                Apply
              </Button>
              <Button
                variant="outlined"
                startIcon={
                  <SvgIcon fontSize="small">
                    <XMarkIcon />
                  </SvgIcon>
                }
                onClick={clearFilters}
              >
                Clear
              </Button>
            </Stack>
          </Grid>
        </Grid>
      </AccordionDetails>
    </Accordion>
  );

  // Define actions for incidents
  const actions = [
    {
      label: "Assign to self",
      type: "POST",
      icon: <PersonAdd />,
      url: "/api/ExecSetSecurityIncident",
      data: {
        GUID: "Id",
      },
      confirmText: "Are you sure you want to assign this incident to yourself?",
      category: "edit",
    },
    {
      label: "Set status to active",
      type: "POST",
      icon: <PlayArrow />,
      url: "/api/ExecSetSecurityIncident",
      data: {
        GUID: "Id",
        Status: "!active",
        Assigned: "AssignedTo",
      },
      confirmText: "Are you sure you want to set the status to active?",
      category: "manage",
    },
    {
      label: "Set status to in progress",
      type: "POST",
      icon: <Assignment />,
      url: "/api/ExecSetSecurityIncident",
      data: {
        GUID: "Id",
        Status: "!inProgress",
        Assigned: "AssignedTo",
      },
      confirmText: "Are you sure you want to set the status to in progress?",
      category: "manage",
    },
    {
      label: "Set status to resolved",
      type: "POST",
      icon: <Done />,
      url: "/api/ExecSetSecurityIncident",
      data: {
        GUID: "Id",
        Status: "!resolved",
      },
      fields: [
        {
          type: "textField",
          name: "Comment",
          label: "Resolving comment (optional)",
          multiline: true,
          rows: 3,
        },
      ],
      confirmText: "Are you sure you want to set the status to resolved?",
      category: "manage",
    },
    {
      label: "Set severity",
      type: "POST",
      icon: <Warning />,
      url: "/api/ExecSetSecurityIncident",
      data: {
        GUID: "Id",
      },
      fields: [
        {
          type: "autoComplete",
          name: "Severity",
          label: "Severity",
          multiple: false,
          creatable: false,
          options: [
            { value: "informational", label: "Informational" },
            { value: "low", label: "Low" },
            { value: "medium", label: "Medium" },
            { value: "high", label: "High" },
          ],
          validators: { required: "Severity is required" },
        },
      ],
      confirmText: "Select the severity to set for this incident.",
      category: "manage",
    },
  ];

  // Helper functions
  const getSeverityInfo = (severity) => {
    switch (String(severity || "").toLowerCase()) {
      case "high":
        return { label: "High", color: theme.palette.error.main, icon: <ErrorIcon fontSize="small" /> };
      case "medium":
        return { label: "Medium", color: theme.palette.warning.main, icon: <Warning fontSize="small" /> };
      case "low":
        return { label: "Low", color: theme.palette.info.main, icon: <InfoIcon fontSize="small" /> };
      default:
        return { label: severity || "Unknown", color: theme.palette.grey[500], icon: <InfoIcon fontSize="small" /> };
    }
  };

  const getStatusInfo = (status) => {
    switch (String(status || "").toLowerCase()) {
      case "resolved":
        return { label: "Resolved", color: theme.palette.success.main, icon: <CheckCircle fontSize="small" /> };
      case "inprogress":
        return { label: "In Progress", color: theme.palette.warning.main, icon: <Assignment fontSize="small" /> };
      case "active":
        return { label: "Active", color: theme.palette.error.main, icon: <PlayArrow fontSize="small" /> };
      default:
        return { label: status || "Unknown", color: theme.palette.grey[500], icon: <Pending fontSize="small" /> };
    }
  };

  // Define off-canvas details
  const offCanvas = {
    actions: actions,
    children: (row) => {
      const severityInfo = getSeverityInfo(row.Severity);
      const statusInfo = getStatusInfo(row.Status);
      const tags = row.Tags ? (Array.isArray(row.Tags) ? row.Tags : [row.Tags]) : [];
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(severityInfo.color, 0.15)} 0%, ${alpha(severityInfo.color, 0.05)} 100%)`,
              borderLeft: `4px solid ${severityInfo.color}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: severityInfo.color,
                  width: 56,
                  height: 56,
                }}
              >
                {severityInfo.icon}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.DisplayName || "Unknown Incident"}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {row.Tenant}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Status & Severity */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Incident Status
            </Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip
                icon={statusInfo.icon}
                label={statusInfo.label}
                sx={{ 
                  fontWeight: 600, 
                  bgcolor: alpha(statusInfo.color, 0.1),
                  color: statusInfo.color,
                  borderColor: statusInfo.color,
                }}
                variant="outlined"
              />
              <Chip
                icon={severityInfo.icon}
                label={`Severity: ${severityInfo.label}`}
                color={severityInfo.label === "High" ? "error" : severityInfo.label === "Medium" ? "warning" : "info"}
                variant="filled"
                size="small"
              />
            </Stack>
          </Box>

          <Divider />

          {/* Details */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <InfoIcon fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Incident Details
              </Typography>
            </Stack>
            <Stack spacing={1}>
              {row.AssignedTo && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Assigned To</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.AssignedTo}
                  </Typography>
                </Stack>
              )}
              {row.Classification && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Classification</Typography>
                  <Chip label={row.Classification} size="small" variant="outlined" />
                </Stack>
              )}
              {row.Determination && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Determination</Typography>
                  <Chip label={row.Determination} size="small" variant="outlined" />
                </Stack>
              )}
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Incident ID</Typography>
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
                  {row.Id}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          {/* Timeline */}
          <Divider />
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <CalendarToday fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Timeline
              </Typography>
            </Stack>
            <Stack spacing={1}>
              {row.Created && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Created</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.Created, "Created")}
                  </Typography>
                </Stack>
              )}
              {row.Updated && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Last Updated</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.Updated, "Updated")}
                  </Typography>
                </Stack>
              )}
            </Stack>
          </Box>

          {/* Tags */}
          {tags.length > 0 && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                  <LocalOffer fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Tags
                  </Typography>
                </Stack>
                <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
                  {tags.map((tag, index) => (
                    <Chip key={index} label={tag} size="small" variant="outlined" />
                  ))}
                </Stack>
              </Box>
            </>
          )}

          {/* Incident URL */}
          {row.IncidentUrl && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                  <OpenInNew fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    View in Microsoft 365
                  </Typography>
                </Stack>
                <Typography 
                  component="a"
                  href={row.IncidentUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  variant="body2"
                  sx={{ 
                    color: "primary.main",
                    textDecoration: "none",
                    "&:hover": { textDecoration: "underline" },
                    wordBreak: "break-all",
                  }}
                >
                  {row.IncidentUrl}
                </Typography>
              </Box>
            </>
          )}
        </Stack>
      );
    },
  };

  // Simplified columns for the table
  const simpleColumns = [
    "Created",
    "Tenant",
    "Id",
    "DisplayName",
    "Status",
    "Severity",
    "Tags",
    "IncidentUrl",
  ];

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ExecIncidentsList"
      apiDataKey="Results"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      tableFilter={tableFilter}
      queryKey={`ExecIncidentsList-${userSettingsDefaults.currentTenant}-${startDate}-${endDate}`}
      apiData={{ StartDate: startDate, EndDate: endDate }}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout allTenantsSupport={true}>{page}</DashboardLayout>;

export default Page;
