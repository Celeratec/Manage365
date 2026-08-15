import { useState } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import {
  Button,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Typography,
  SvgIcon,
  Paper,
  Avatar,
  Chip,
  Divider,
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Grid, Box, Stack } from "@mui/system";
import { 
  Visibility, 
  CheckCircle, 
  ExpandMore, 
  Security,
  Apps,
  Person,
  CalendarToday,
  Pending,
  Cancel,
  OpenInNew,
} from "@mui/icons-material";
import { FunnelIcon, XMarkIcon } from "@heroicons/react/24/outline";
import { useForm } from "react-hook-form";
import CippFormComponent from "../../../../components/CippComponents/CippFormComponent";
import { useSettings } from "../../../../hooks/use-settings";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getInitials, stringToColor } from "../../../../utils/get-initials";

const apiUrl = "/api/ListAppConsentRequests";
const pageTitle = "App Consent Requests";

const Page = () => {
  const tenantFilter = useSettings().currentTenant;
  const theme = useTheme();
  const formControl = useForm({
    defaultValues: {
      requestStatus: "InProgress",
    },
  });

  const [expanded, setExpanded] = useState(true); // Accordion state - start expanded since we have a default filter
  const [filterEnabled, setFilterEnabled] = useState(true); // State for filter toggle - start with filter enabled
  const [requestStatus, setRequestStatus] = useState("InProgress"); // State for request status filter - default to InProgress
  const [requestStatusLabel, setRequestStatusLabel] = useState("Pending"); // State for displaying filter label - default label

  const onSubmit = (data) => {
    // Handle the case where requestStatus could be an object {label, value} or a string
    const statusValue =
      typeof data.requestStatus === "object" && data.requestStatus?.value
        ? data.requestStatus.value
        : data.requestStatus;
    const statusLabel =
      typeof data.requestStatus === "object" && data.requestStatus?.label
        ? data.requestStatus.label
        : data.requestStatus;

    // Check if any filter is applied
    const hasFilter = statusValue !== "All";
    setFilterEnabled(hasFilter);

    // Set request status filter if not "All"
    setRequestStatus(hasFilter ? statusValue : null);
    setRequestStatusLabel(hasFilter ? statusLabel : null);

    // Close the accordion after applying filters
    setExpanded(false);
  };

  const clearFilters = () => {
    formControl.reset({
      requestStatus: "All",
    });
    setFilterEnabled(false);
    setRequestStatus(null);
    setRequestStatusLabel(null);
    setExpanded(false); // Close the accordion when clearing filters
  };

  const actions = [
    {
      label: "Review in Entra",
      link: `https://entra.microsoft.com/${tenantFilter}/#view/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/~/AccessRequests`,
      color: "info",
      icon: <Visibility />,
      target: "_blank",
      external: true,
      category: "view",
    },
    {
      label: "Approve in Entra",
      link: "[consentUrl]",
      color: "info",
      icon: <CheckCircle />,
      target: "_blank",
      external: true,
      category: "security",
    },
  ];

  const simpleColumns = [
    "requestDate", // Request Date
    "requestUser", // Requester
    "appDisplayName", // Application Name
    "appId", // Application ID
    "requestReason", // Reason
    "requestStatus", // Status
    "reviewedBy", // Reviewed by
    "reviewedJustification", // Reviewed Reason
    "consentUrl", // Consent URL
  ];

  const filters = [
    {
      filterName: "Pending requests",
      value: [{ id: "requestStatus", value: "InProgress" }],
      type: "column",
    },
    {
      filterName: "Expired requests",
      value: [{ id: "requestStatus", value: "Expired" }],
      type: "column",
    },
    {
      filterName: "Completed requests",
      value: [{ id: "requestStatus", value: "Completed" }],
      type: "column",
    },
  ];

  // Helper for request status
  const getRequestStatusInfo = (status) => {
    switch (String(status || "").toLowerCase()) {
      case "completed":
        return { label: "Completed", color: theme.palette.success.main, icon: <CheckCircle fontSize="small" /> };
      case "expired":
        return { label: "Expired", color: theme.palette.error.main, icon: <Cancel fontSize="small" /> };
      case "inprogress":
      default:
        return { label: "Pending", color: theme.palette.warning.main, icon: <Pending fontSize="small" /> };
    }
  };

  const offCanvas = {
    actions: actions,
    children: (row) => {
      const statusInfo = getRequestStatusInfo(row.requestStatus);
      
      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper 
            elevation={0}
            sx={{ 
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(statusInfo.color, 0.15)} 0%, ${alpha(statusInfo.color, 0.05)} 100%)`,
              borderLeft: `4px solid ${statusInfo.color}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: stringToColor(row.appDisplayName || "A"),
                  width: 56,
                  height: 56,
                }}
              >
                <Apps />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.appDisplayName || "Unknown Application"}
                </Typography>
                <Typography variant="body2" color="text.secondary" noWrap>
                  Requested by: {row.requestUser}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Status */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Request Status
            </Typography>
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
          </Box>

          <Divider />

          {/* Request Details */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <Person fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Request Details
              </Typography>
            </Stack>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">Requester</Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }} noWrap>
                  {row.requestUser}
                </Typography>
              </Stack>
              {row.requestDate && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">Request Date</Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCippFormatting(row.requestDate, "requestDate")}
                  </Typography>
                </Stack>
              )}
              {row.requestReason && (
                <Box>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>Reason</Typography>
                  <Paper 
                    variant="outlined" 
                    sx={{ 
                      p: 1.5, 
                      borderRadius: 1.5,
                      backgroundColor: alpha(theme.palette.background.default, 0.5),
                    }}
                  >
                    <Typography variant="body2" color="text.secondary">
                      {row.requestReason}
                    </Typography>
                  </Paper>
                </Box>
              )}
            </Stack>
          </Box>

          {/* Application Info */}
          <Divider />
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <Apps fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Application Info
              </Typography>
            </Stack>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">App ID</Typography>
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
            </Stack>
          </Box>

          {/* Review Info */}
          {(row.reviewedBy || row.reviewedJustification) && (
            <>
              <Divider />
              <Box>
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1 }}>
                  Review Information
                </Typography>
                <Stack spacing={1}>
                  {row.reviewedBy && (
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2" color="text.secondary">Reviewed By</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {row.reviewedBy}
                      </Typography>
                    </Stack>
                  )}
                  {row.reviewedJustification && (
                    <Box>
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>Justification</Typography>
                      <Paper 
                        variant="outlined" 
                        sx={{ 
                          p: 1.5, 
                          borderRadius: 1.5,
                          backgroundColor: alpha(theme.palette.background.default, 0.5),
                        }}
                      >
                        <Typography variant="body2" color="text.secondary">
                          {row.reviewedJustification}
                        </Typography>
                      </Paper>
                    </Box>
                  )}
                </Stack>
              </Box>
            </>
          )}

          {/* Consent URL */}
          {row.consentUrl && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                  <OpenInNew fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Consent URL
                  </Typography>
                </Stack>
                <Typography 
                  component="a"
                  href={row.consentUrl}
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
                  {row.consentUrl}
                </Typography>
              </Box>
            </>
          )}
        </Stack>
      );
    },
  };

  return (
    <CippTablePage
      tableFilter={
        <Accordion expanded={expanded} onChange={() => setExpanded(!expanded)}>
          <AccordionSummary expandIcon={<ExpandMore />}>
            <Stack direction="row" spacing={1} alignItems="center">
              <SvgIcon>
                <FunnelIcon />
              </SvgIcon>
              <Typography variant="h6">
                App Consent Request Filters
                {filterEnabled ? (
                  <span style={{ fontSize: "0.8em", marginLeft: "10px", fontWeight: "normal" }}>
                    ({requestStatusLabel && <>Status: {requestStatusLabel}</>})
                  </span>
                ) : (
                  <span style={{ fontSize: "0.8em", marginLeft: "10px", fontWeight: "normal" }}>
                    (No filters applied)
                  </span>
                )}
              </Typography>
            </Stack>
          </AccordionSummary>
          <AccordionDetails>
            <form onSubmit={formControl.handleSubmit(onSubmit)}>
              <Grid container spacing={2}>
                {/* Request Status Filter */}
                <Grid size={{ xs: 12 }}>
                  <CippFormComponent
                    type="autoComplete"
                    name="requestStatus"
                    multiple={false}
                    label="Request Status"
                    options={[
                      { label: "All", value: "All" },
                      { label: "Pending", value: "InProgress" },
                      { label: "Expired", value: "Expired" },
                      { label: "Completed", value: "Completed" },
                    ]}
                    formControl={formControl}
                  />
                </Grid>

                {/* Action Buttons */}
                <Grid size={{ xs: 12 }}>
                  <Stack direction="row" spacing={2}>
                    <Button
                      type="submit"
                      variant="contained"
                      color="primary"
                      startIcon={
                        <SvgIcon>
                          <FunnelIcon />
                        </SvgIcon>
                      }
                    >
                      Apply Filters
                    </Button>
                    <Button
                      variant="outlined"
                      color="primary"
                      startIcon={
                        <SvgIcon>
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
      }
      title={pageTitle}
      apiUrl={apiUrl}
      simpleColumns={simpleColumns}
      filters={filters}
      queryKey={`AppConsentRequests-${requestStatus}-${filterEnabled}-${tenantFilter}`}
      apiData={{
        RequestStatus: requestStatus, // Pass request status filter from state
        Filter: filterEnabled, // Pass filter toggle state
      }}
      offCanvas={offCanvas}
      actions={actions}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout allTenantsSupport={false}>{page}</DashboardLayout>;

export default Page;
