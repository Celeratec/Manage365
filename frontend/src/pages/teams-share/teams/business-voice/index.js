import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import {
  Paper,
  Avatar,
  Typography,
  Chip,
  Divider,
  useTheme,
  useMediaQuery,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  PersonAdd,
  PersonRemove,
  LocationOn,
  Phone,
  Person,
  CheckCircle,
  Warning,
  Flag,
  SyncAlt,
} from "@mui/icons-material";
import { useSettings } from "../../../../hooks/use-settings";
import { useRouter } from "next/router";
import { useMemo, useCallback } from "react";

const formatCapability = (cap) =>
  cap.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2");

const parseCapabilities = (value) => {
  if (!value) return [];
  if (Array.isArray(value)) return value.map(formatCapability);
  if (typeof value !== "string") return [String(value)];
  if (value.includes(",")) return value.split(",").map((s) => formatCapability(s.trim())).filter(Boolean);
  const known = [
    "FirstPartyAppAssignment", "Geographic", "InboundCalling", "Office365",
    "OutboundCalling", "SharedCalling", "AzureConferenceAssignment",
    "InboundA2PSms", "OutboundA2PSms", "ThirdPartyAppAssignment",
    "UserAssignment", "ConferenceAssignment", "VoiceAppAssignment", "PrivateLineAssignment",
  ];
  const caps = [];
  let remaining = value;
  while (remaining.length > 0) {
    let matched = false;
    for (const cap of known) {
      if (remaining.startsWith(cap)) {
        caps.push(formatCapability(cap));
        remaining = remaining.slice(cap.length);
        matched = true;
        break;
      }
    }
    if (!matched) {
      const match = remaining.match(/^([A-Z][a-z]+(?:[A-Z][a-z]+)*)/);
      if (match) {
        caps.push(formatCapability(match[1]));
        remaining = remaining.slice(match[1].length);
      } else {
        caps.push(remaining);
        break;
      }
    }
  }
  return caps;
};

// Format NumberType values like "CallingPlan" -> "Calling Plan", "DirectRouting" -> "Direct Routing"
const formatNumberType = (value) => {
  if (!value || typeof value !== "string") return value;
  return value.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2");
};

// Helper to safely extract a display string from AssignedTo (may be string or object)
const getAssignedToDisplay = (value) => {
  if (!value) return "";
  if (typeof value === "string") return value;
  if (typeof value === "object") {
    return value.displayName || value.userPrincipalName || value.id || "";
  }
  return String(value);
};

const Page = () => {
  const pageTitle = "Teams Business Voice";
  const tenantFilter = useSettings().currentTenant;
  const router = useRouter();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  const handleCardClick = useCallback(
    (item) => {
      router.push(
        `/teams-share/teams/business-voice/number?number=${encodeURIComponent(item.TelephoneNumber)}`
      );
    },
    [router]
  );

  const actions = useMemo(
    () => [
      {
        label: "Assign User",
        type: "POST",
        icon: <PersonAdd />,
        url: "/api/ExecTeamsVoicePhoneNumberAssignment",
        data: {
          PhoneNumber: "TelephoneNumber",
          PhoneNumberType: "NumberType",
          locationOnly: false,
        },
        fields: [
          {
            type: "autoComplete",
            name: "input",
            label: "Select User",
            multiple: false,
            creatable: false,
            api: {
              url: "/api/ListGraphRequest",
              dataKey: "Results",
              data: {
                Endpoint: "users",
                manualPagination: true,
                $select: "id,userPrincipalName,displayName",
                $count: true,
                $orderby: "displayName",
                $top: 999,
              },
              labelField: (input) => `${input.displayName} (${input.userPrincipalName})`,
              valueField: "userPrincipalName",
            },
          },
        ],
        confirmText: "Select the User to assign the phone number '[TelephoneNumber]' to.",
        category: "edit",
        quickAction: true,
      },
      {
        label: "Unassign User",
        type: "POST",
        icon: <PersonRemove />,
        url: "/api/ExecRemoveTeamsVoicePhoneNumberAssignment",
        data: {
          PhoneNumber: "TelephoneNumber",
          AssignedTo: "AssignedTo",
          PhoneNumberType: "NumberType",
        },
        confirmText:
          "Are you sure you want to remove the assignment for '[TelephoneNumber]' from '[AssignedTo]'?",
        category: "edit",
        quickAction: true,
      },
      {
        label: "Set Emergency Location",
        type: "POST",
        icon: <LocationOn />,
        url: "/api/ExecTeamsVoicePhoneNumberAssignment",
        data: {
          PhoneNumber: "TelephoneNumber",
          locationOnly: true,
        },
        fields: [
          {
            type: "autoComplete",
            name: "input",
            label: "Emergency Location",
            api: {
              url: "/api/ListTeamsLisLocation",
              labelField: "Description",
              valueField: "LocationId",
            },
          },
        ],
        confirmText: "Select the Emergency Location for '[TelephoneNumber]'.",
        category: "security",
        quickAction: true,
      },
    ],
    []
  );

  const filters = useMemo(
    () => [
      {
        filterName: "Assigned Numbers",
        value: [{ id: "AssignmentStatus", value: "Assigned" }],
        type: "column",
      },
      {
        filterName: "Unassigned Numbers",
        value: [{ id: "AssignmentStatus", value: "Unassigned" }],
        type: "column",
      },
      {
        filterName: "Operator Connect",
        value: [{ id: "IsOperatorConnect", value: "true" }],
        type: "column",
      },
      {
        filterName: "User Assignment Capable",
        value: [{ id: "AcquiredCapabilities", value: "UserAssignment" }],
        type: "column",
      },
    ],
    []
  );

  const cardConfig = useMemo(
    () => ({
      title: "TelephoneNumber",
      subtitle: "AssignedTo",
      subtitleFormatter: (value) => getAssignedToDisplay(value) || "Unassigned",
      avatar: {
        field: "TelephoneNumber",
        icon: () => <Phone />,
      },
      badges: [
        {
          field: "AssignmentStatus",
          conditions: {
            Assigned: {
              label: "Assigned",
              color: "success",
              icon: <CheckCircle fontSize="small" />,
            },
            Unassigned: {
              label: "Unassigned",
              color: "warning",
              icon: <Warning fontSize="small" />,
            },
          },
          iconOnly: true,
        },
        {
          field: "IsOperatorConnect",
          conditions: {
            true: {
              label: "Operator Connect",
              color: "info",
              icon: <SyncAlt fontSize="small" />,
            },
          },
          transform: (value) => (value === true || value === "True" || value === "true" ? "true" : null),
          iconOnly: true,
        },
      ],
      extraFields: [
        {
          field: "AssignedTo",
          icon: <Person />,
          label: "Assigned To",
          formatter: (value) => getAssignedToDisplay(value) || "Unassigned",
        },
        [
          { field: "NumberType", icon: <Phone />, label: "Type", formatter: formatNumberType },
          { field: "IsoCountryCode", icon: <Flag />, label: "Country", align: "right" },
        ],
      ],
      desktopFields: [
        { field: "PlaceName", icon: <LocationOn />, label: "Location" },
      ],
      cardGridProps: {
        md: 6,
        lg: 4,
      },
      mobileQuickActions: [
        "Assign User",
        "Unassign User",
        "Set Emergency Location",
      ],
      maxQuickActions: 8,
    }),
    []
  );

  const offCanvasChildren = useCallback(
    (row) => {
      const isAssigned = row.AssignmentStatus === "Assigned";
      const isOperatorConnect = row.IsOperatorConnect === true || row.IsOperatorConnect === "True" || row.IsOperatorConnect === "true";

      return (
        <Stack spacing={3}>
          {/* Hero Section */}
          <Paper
            elevation={0}
            sx={{
              p: 2.5,
              borderRadius: 2,
              background: `linear-gradient(135deg, ${alpha(
                isAssigned ? theme.palette.success.main : theme.palette.warning.main,
                0.15
              )} 0%, ${alpha(
                isAssigned ? theme.palette.success.main : theme.palette.warning.main,
                0.05
              )} 100%)`,
              borderLeft: `4px solid ${isAssigned ? theme.palette.success.main : theme.palette.warning.main}`,
            }}
          >
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                sx={{
                  bgcolor: alpha(
                    isAssigned ? theme.palette.success.main : theme.palette.warning.main,
                    0.15
                  ),
                  color: isAssigned ? theme.palette.success.main : theme.palette.warning.main,
                  width: 56,
                  height: 56,
                }}
              >
                <Phone sx={{ fontSize: 28 }} />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.TelephoneNumber}
                </Typography>
                {isAssigned && (
                  <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mb: 0.5 }}>
                    <Person sx={{ fontSize: 16, color: "text.secondary" }} />
                    <Typography variant="body1" sx={{ fontWeight: 600 }}>
                      {getAssignedToDisplay(row.AssignedTo)}
                    </Typography>
                  </Stack>
                )}
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                  <Chip
                    label={isAssigned ? "Assigned" : "Unassigned"}
                    size="small"
                    color={isAssigned ? "success" : "warning"}
                    variant="outlined"
                  />
                  {row.NumberType && (
                    <Chip label={formatNumberType(row.NumberType)} size="small" variant="outlined" />
                  )}
                  {isOperatorConnect && (
                    <Chip
                      icon={<SyncAlt fontSize="small" />}
                      label="Operator Connect"
                      size="small"
                      color="info"
                      variant="outlined"
                    />
                  )}
                </Stack>
              </Box>
            </Stack>
          </Paper>

          {/* Assignment Info */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Assignment
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Status
                </Typography>
                <Chip
                  label={row.AssignmentStatus || "Unknown"}
                  size="small"
                  color={isAssigned ? "success" : "warning"}
                  variant="outlined"
                />
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Assigned To
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {getAssignedToDisplay(row.AssignedTo) || "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Number Type
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {formatNumberType(row.NumberType) || "—"}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Capabilities */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Capabilities
            </Typography>
            <Stack spacing={1.5}>
              <Box>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 0.75 }}>
                  Acquired
                </Typography>
                <Stack direction="row" flexWrap="wrap" useFlexGap spacing={0.5}>
                  {parseCapabilities(row.AcquiredCapabilities).length > 0 ? (
                    parseCapabilities(row.AcquiredCapabilities).map((cap, i) => (
                      <Chip key={i} label={cap} size="small" color="success" variant="outlined" />
                    ))
                  ) : (
                    <Typography variant="body2" color="text.disabled">None</Typography>
                  )}
                </Stack>
              </Box>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Activation State
                </Typography>
                <Chip
                  label={row.ActivationState || "Unknown"}
                  size="small"
                  color={
                    row.ActivationState === "Activated"
                      ? "success"
                      : row.ActivationState === "AssignmentPending"
                      ? "info"
                      : "default"
                  }
                  variant="outlined"
                />
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Location */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Location
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Country Code
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.IsoCountryCode || "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Place Name
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.PlaceName || "—"}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Additional Details */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Additional Details
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Operator Connect
                </Typography>
                <Chip
                  label={isOperatorConnect ? "Yes" : "No"}
                  size="small"
                  color={isOperatorConnect ? "info" : "default"}
                  variant="outlined"
                />
              </Stack>
              {row.AcquisitionDate && (
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">
                    Acquisition Date
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {new Date(row.AcquisitionDate).toLocaleDateString()}
                  </Typography>
                </Stack>
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
        ? ["TelephoneNumber", "AssignedTo", "AssignmentStatus"]
        : [
            "TelephoneNumber",
            "AssignedTo",
            "AssignmentStatus",
            "NumberType",
            "AcquiredCapabilities",
            "IsoCountryCode",
            "PlaceName",
            "ActivationState",
            "IsOperatorConnect",
            "AcquisitionDate",
          ],
    [isMobile]
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListTeamsVoice"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      filters={filters}
      cardConfig={cardConfig}
      onCardClick={handleCardClick}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
