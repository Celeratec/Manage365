import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { getCippFormatting } from "../../../../utils/get-cipp-formatting";
import { getCippTranslation } from "../../../../utils/get-cipp-translation";
import { Avatar, Box, Chip, Divider, Paper, Stack, Typography, useMediaQuery } from "@mui/material";
import { alpha, useTheme } from "@mui/material/styles";
import {
  AccessTime,
  CheckCircle,
  Clear,
  Error as ErrorIcon,
  Info as InfoIcon,
  Key,
  Password,
  Person,
  PhonelinkSetup,
  PersonOff,
  Search,
  Warning,
} from "@mui/icons-material";
import { ShieldCheckIcon } from "@heroicons/react/24/outline";
import { ApiGetCall } from "../../../../api/ApiCall";
import { getInitials, stringToColor } from "../../../../utils/get-initials";

const Page = () => {
  const pageTitle = "Risky Users";
  const theme = useTheme();
  const mdDown = useMediaQuery(theme.breakpoints.down("md"));
  const auth = ApiGetCall({ url: "/api/me", queryKey: "authmecipp" });
  const currentUser = auth.data?.clientPrincipal?.userDetails || "anonymous";

  // ============ HELPER FUNCTIONS ============
  const formatLabel = (value) => {
    if (!value) return "Unknown";
    return String(value)
      .replace(/([a-z])([A-Z])/g, "$1 $2")
      .replace(/^./, (match) => match.toUpperCase());
  };

  const riskStateColor = (state) => {
    switch (String(state || "").toLowerCase()) {
      case "atrisk":
      case "confirmedcompromised":
        return "error";
      case "remediated":
        return "success";
      case "dismissed":
        return "default";
      default:
        return "warning";
    }
  };

  const riskLevelColor = (level) => {
    switch (String(level || "").toLowerCase()) {
      case "high":
        return "error";
      case "medium":
        return "warning";
      case "low":
        return "info";
      case "none":
        return "default";
      default:
        return "secondary";
    }
  };

  // Risk state chip config
  const getRiskStateChip = (state) => {
    const s = String(state || "").toLowerCase();
    switch (s) {
      case "atrisk":
        return { label: "At Risk", color: "error", icon: <ErrorIcon fontSize="small" /> };
      case "confirmedcompromised":
        return { label: "Compromised", color: "error", icon: <ErrorIcon fontSize="small" /> };
      case "remediated":
        return { label: "Remediated", color: "success", icon: <CheckCircle fontSize="small" /> };
      case "dismissed":
        return { label: "Dismissed", color: "default", icon: <Clear fontSize="small" /> };
      default:
        return { label: formatLabel(state), color: "warning", icon: <Warning fontSize="small" /> };
    }
  };

  // Risk level chip config
  const getRiskLevelChip = (level) => {
    const l = String(level || "").toLowerCase();
    switch (l) {
      case "high":
        return { label: "High", color: "error", variant: "filled" };
      case "medium":
        return { label: "Medium", color: "warning", variant: "filled" };
      case "low":
        return { label: "Low", color: "info", variant: "outlined" };
      case "none":
        return { label: "None", color: "default", variant: "outlined" };
      default:
        return { label: formatLabel(level), color: "secondary", variant: "outlined" };
    }
  };

  // Get severity level for combined state + level
  const getSeverity = (item) => {
    const state = String(item?.riskState || "").toLowerCase();
    const level = String(item?.riskLevel || "").toLowerCase();
    
    if (state === "confirmedcompromised") return "critical";
    if (state === "atrisk" && level === "high") return "critical";
    if (state === "atrisk") return "high";
    if (state === "remediated") return "remediated";
    if (state === "dismissed") return "dismissed";
    if (level === "high") return "high";
    if (level === "medium") return "medium";
    return "low";
  };

  // Map severity to colors
  const severityColors = {
    critical: { bg: alpha(theme.palette.error.main, 0.12), border: theme.palette.error.dark },
    high: { bg: alpha(theme.palette.error.main, 0.08), border: theme.palette.error.main },
    medium: { bg: alpha(theme.palette.warning.main, 0.08), border: theme.palette.warning.main },
    low: { bg: alpha(theme.palette.info.main, 0.06), border: theme.palette.info.main },
    remediated: { bg: alpha(theme.palette.success.main, 0.08), border: theme.palette.success.main },
    dismissed: { bg: alpha(theme.palette.grey[500], 0.08), border: theme.palette.grey[400] },
  };

  const riskPriority = (row) => {
    const state = String(row?.riskState || "").toLowerCase();
    if (state === "atrisk" || state === "confirmedcompromised") return 0;
    if (state === "remediated") return 1;
    if (state === "dismissed") return 2;
    return 3;
  };

  const riskLevelPriority = (row) => {
    const level = String(row?.riskLevel || "").toLowerCase();
    if (level === "high") return 0;
    if (level === "medium") return 1;
    if (level === "low") return 2;
    if (level === "none") return 3;
    return 4;
  };

  // ============ ACTIONS ============
  const actions = [
    {
      label: "Dismiss Risk",
      type: "POST",
      icon: <Clear />,
      url: "/api/ExecDismissRiskyUser",
      data: {
        userId: "id",
        userDisplayName: "userDisplayName",
        userPrincipalName: "userPrincipalName",
      },
      confirmText: "Are you sure you want to dismiss the risk for this user?",
      multiPost: false,
      category: "security",
      quickAction: true,
      color: "info",
    },
    {
      label: "Research",
      type: "GET",
      icon: <Search />,
      link: "/identity/administration/users/user/bec?userId=[id]",
      confirmText: "Are you sure you want to research this compromised account?",
      multiPost: false,
      category: "security",
      quickAction: true,
      color: "info",
    },
    {
      label: "Remediate",
      type: "POST",
      icon: <ShieldCheckIcon />,
      url: "/api/execBecRemediate",
      data: { userId: "id", username: "userPrincipalName" },
      confirmText:
        "This will remediate this user, blocking their signin, resetting their password, disconnecting their sessions, and disabling all their inbox rules. Are you sure you want to continue?",
      multiPost: false,
      category: "security",
      quickAction: true,
      color: "warning",
    },
    {
      label: "Reset Password",
      type: "POST",
      icon: <Password />,
      url: "/api/ExecResetPass",
      data: { ID: "userPrincipalName", displayName: "userDisplayName" },
      fields: [
        {
          type: "password",
          name: "password",
          label: "Password (leave blank to auto-generate)",
        },
        {
          type: "switch",
          name: "MustChange",
          label: "Must Change Password at Next Logon",
        },
      ],
      confirmText: "Are you sure you want to reset the password for the selected user(s)?",
      multiPost: true,
      category: "security",
      quickAction: true,
      color: "warning",
    },
    {
      label: "Expire Password",
      type: "POST",
      icon: <Key />,
      url: "/api/ExecExpirePassword",
      data: { ID: "userPrincipalName", displayName: "userDisplayName" },
      confirmText:
        "This will mark the password as expired for [userPrincipalName]. The user will be required to change their password on their next sign-in. Their current password remains valid until they log in. Use 'Revoke all user sessions' to force immediate re-authentication.",
      multiPost: false,
      category: "security",
      quickAction: true,
      color: "warning",
    },
    {
      label: "Reset MFA",
      type: "POST",
      icon: <PhonelinkSetup />,
      url: "/api/ExecResetMFA",
      data: { ID: "userPrincipalName" },
      confirmText: "Are you sure you want to reset MFA for [userPrincipalName]?",
      multiPost: false,
      category: "security",
      quickAction: true,
      color: "warning",
    },
    {
      label: "Revoke Sessions",
      type: "POST",
      icon: <PersonOff />,
      url: "/api/ExecRevokeSessions",
      data: { ID: "id", Username: "userPrincipalName" },
      confirmText: "Are you sure you want to revoke all sessions for [userPrincipalName]?",
      multiPost: false,
      category: "security",
      quickAction: true,
      color: "error",
    },
  ];

  // ============ OFF-CANVAS CONFIG ============
  // Get severity info for styling
  const getSeverityInfo = (item) => {
    const state = String(item?.riskState || "").toLowerCase();
    const level = String(item?.riskLevel || "").toLowerCase();
    
    if (state === "confirmedcompromised") 
      return { severity: "critical", label: "Critical", color: theme.palette.error.dark };
    if (state === "atrisk" && level === "high") 
      return { severity: "critical", label: "Critical", color: theme.palette.error.dark };
    if (state === "atrisk") 
      return { severity: "high", label: "High Risk", color: theme.palette.error.main };
    if (state === "remediated") 
      return { severity: "remediated", label: "Remediated", color: theme.palette.success.main };
    if (state === "dismissed") 
      return { severity: "dismissed", label: "Dismissed", color: theme.palette.grey[500] };
    if (level === "high") 
      return { severity: "high", label: "High Risk", color: theme.palette.error.main };
    if (level === "medium") 
      return { severity: "medium", label: "Medium Risk", color: theme.palette.warning.main };
    return { severity: "low", label: "Low Risk", color: theme.palette.info.main };
  };

  const offCanvas = {
    extendedInfoFields: [],
    actions: actions,
    size: "md",
    children: (row) => {
      const severityInfo = getSeverityInfo(row);
      const stateChip = getRiskStateChip(row.riskState);
      const levelChip = getRiskLevelChip(row.riskLevel);
      const isDismissed = String(row?.riskState || "").toLowerCase() === "dismissed";
      const dismissedBy = row?.dismissedBy;
      const dismissedDateTime = row?.dismissedDateTime;

      return (
        <Stack spacing={3}>
          {/* Hero Section with severity indicator */}
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
                  bgcolor: stringToColor(row.userDisplayName || "U"),
                  width: 56,
                  height: 56,
                  fontSize: "1.25rem",
                  fontWeight: 600,
                }}
              >
                {getInitials(row.userDisplayName || "Unknown")}
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.userDisplayName || "Unknown User"}
                </Typography>
                <Typography variant="body2" color="text.secondary" noWrap>
                  {row.userPrincipalName}
                </Typography>
              </Box>
            </Stack>
          </Paper>

          {/* Risk Status Section */}
          <Box>
            <Typography 
              variant="overline" 
              color="text.secondary" 
              sx={{ fontWeight: 600, letterSpacing: 1, mb: 1.5, display: "block" }}
            >
              Risk Assessment
            </Typography>
            <Stack direction="row" spacing={1.5} flexWrap="wrap" useFlexGap>
              <Chip
                icon={stateChip.icon}
                label={stateChip.label}
                color={stateChip.color}
                variant="filled"
                sx={{ fontWeight: 600, px: 0.5 }}
              />
              <Chip
                label={`Level: ${levelChip.label}`}
                color={levelChip.color}
                variant={levelChip.variant}
                sx={{ px: 0.5 }}
              />
            </Stack>
          </Box>

          {isDismissed && (dismissedBy || dismissedDateTime) && (
            <>
              <Divider />
              <Box>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                  <Person fontSize="small" color="action" />
                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                    Dismissal
                  </Typography>
                </Stack>
                <Paper
                  variant="outlined"
                  sx={{
                    p: 2,
                    borderRadius: 1.5,
                    backgroundColor: alpha(theme.palette.background.default, 0.5),
                  }}
                >
                  <Stack spacing={1}>
                    {dismissedBy && (
                      <Stack
                        direction="row"
                        justifyContent="space-between"
                        alignItems="center"
                        spacing={2}
                      >
                        <Typography variant="body2" color="text.secondary">
                          Dismissed by
                        </Typography>
                        <Typography
                          variant="body2"
                          sx={{ fontWeight: 500, textAlign: "right", wordBreak: "break-all" }}
                        >
                          {dismissedBy}
                        </Typography>
                      </Stack>
                    )}
                    {dismissedDateTime && (
                      <Stack
                        direction="row"
                        justifyContent="space-between"
                        alignItems="center"
                        spacing={2}
                      >
                        <Typography variant="body2" color="text.secondary">
                          Dismissed at
                        </Typography>
                        <Typography variant="body2" sx={{ fontWeight: 500 }}>
                          {getCippFormatting(dismissedDateTime, "dismissedDateTime")}
                        </Typography>
                      </Stack>
                    )}
                  </Stack>
                </Paper>
              </Box>
            </>
          )}

          <Divider />

          {/* Details Section */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
              <InfoIcon fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Risk Details
              </Typography>
            </Stack>
            <Paper 
              variant="outlined" 
              sx={{ 
                p: 2, 
                borderRadius: 1.5,
                backgroundColor: alpha(theme.palette.background.default, 0.5),
              }}
            >
              <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.6 }}>
                {row.riskDetail ? getCippTranslation(row.riskDetail) : "No additional details available for this risk assessment."}
              </Typography>
            </Paper>
          </Box>

          {/* Metadata Section */}
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <AccessTime fontSize="small" color="action" />
              <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                Timeline
              </Typography>
            </Stack>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Last Updated
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {getCippFormatting(row.riskLastUpdatedDateTime, "riskLastUpdatedDateTime")}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  User ID
                </Typography>
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
                  {row.id}
                </Typography>
              </Stack>
            </Stack>
          </Box>
        </Stack>
      );
    },
  };

  // ============ COLUMNS ============
  // Using simpleColumns approach to avoid Cell function issues
  const simpleColumns = [
    "userDisplayName",
    "userPrincipalName",
    "riskState",
    "riskLevel",
    "riskDetail",
    "riskLastUpdatedDateTime",
    "dismissedBy",
    "dismissedDateTime",
  ];

  // ============ CARD CONFIG ============
  const cardConfig = {
    title: "userDisplayName",
    subtitle: "userPrincipalName",
    avatar: {
      field: "userDisplayName",
      photoField: false,
    },
    // Sort "At Risk" users to the top, then by level, then by date
    sortFn: (a, b) => {
      // First, sort by risk state priority
      const statePriorityA = riskPriority(a);
      const statePriorityB = riskPriority(b);
      if (statePriorityA !== statePriorityB) return statePriorityA - statePriorityB;
      
      // Within same state, sort by risk level (High > Medium > Low > None)
      const levelPriorityA = riskLevelPriority(a);
      const levelPriorityB = riskLevelPriority(b);
      if (levelPriorityA !== levelPriorityB) return levelPriorityA - levelPriorityB;
      
      // Within same state and level, sort by last updated (most recent first)
      const dateA = new Date(a.riskLastUpdatedDateTime || 0);
      const dateB = new Date(b.riskLastUpdatedDateTime || 0);
      return dateB - dateA;
    },
    // Dynamic card styling based on risk severity
    cardSx: (item) => {
      const severity = getSeverity(item);
      const colors = severityColors[severity] || severityColors.low;
      return {
        backgroundColor: colors.bg,
        borderLeft: `5px solid ${colors.border}`,
      };
    },
    // Custom content renderer for risk badges section
    customContent: (item) => {
      const stateChip = getRiskStateChip(item.riskState);
      const levelChip = getRiskLevelChip(item.riskLevel);
      const isDismissed = String(item?.riskState || "").toLowerCase() === "dismissed";
      const dismissedBy = item?.dismissedBy;
      return (
        <Box sx={{ mb: 1.5 }}>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Chip
              size="small"
              icon={stateChip.icon}
              label={stateChip.label}
              color={stateChip.color}
              variant="filled"
              sx={{ fontWeight: 600 }}
            />
            <Chip
              size="small"
              label={`Level: ${levelChip.label}`}
              color={levelChip.color}
              variant={levelChip.variant}
            />
          </Stack>
          {isDismissed && dismissedBy && (
            <Stack direction="row" spacing={0.5} alignItems="center" sx={{ mt: 1 }}>
              <Person sx={{ fontSize: 14, color: "text.secondary" }} />
              <Typography
                variant="caption"
                color="text.secondary"
                sx={{ wordBreak: "break-all" }}
              >
                Dismissed by <strong>{dismissedBy}</strong>
              </Typography>
            </Stack>
          )}
        </Box>
      );
    },
    // No icon-only badges since we have custom content
    badges: [],
    // Extra fields for key info
    extraFields: [
      { 
        field: "riskDetail", 
        label: "Details",
        formatter: (value) => value ? getCippTranslation(value) : "No details available",
      },
    ],
    extraFieldsMax: 1,
    desktopFields: [
      {
        field: "riskLastUpdatedDateTime",
        icon: <AccessTime />,
        label: "Updated",
        formatter: (value) => {
          if (!value) return "N/A";
          try {
            const date = new Date(value);
            return date.toLocaleDateString(undefined, { 
              month: "short", 
              day: "numeric", 
              year: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            });
          } catch {
            return value;
          }
        },
      },
    ],
    desktopFieldsLayout: "column",
    desktopFieldsMax: 1,
    quickActionsVariant: "button",
    mobileQuickActionsVariant: "icon",
    cardGridProps: {
      md: 6,
      lg: 4,
    },
  };

  const filterList = [
    {
      filterName: "Users at Risk",
      value: [{ id: "riskState", value: "at Risk" }],
      type: "column",
    },
    {
      filterName: "Dismissed Users",
      value: [{ id: "riskState", value: "dismissed" }],
      type: "column",
    },
    {
      filterName: "Remediated Users",
      value: [{ id: "riskState", value: "remediated" }],
      type: "column",
    },
  ];

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListRiskyUsers"
      apiDataKey="Results"
      actions={actions}
      offCanvas={offCanvas}
      offCanvasOnRowClick={false}
      showRowActionsMenu={false}
      simpleColumns={simpleColumns}
      columnVisibility={{
        id: false,
        Tenant: false,
      }}
      defaultSorting={[
        { id: "riskLastUpdatedDateTime", desc: true },
      ]}
      cardConfig={cardConfig}
      defaultViewMode="cards"
      viewModeStorageKey={`cipp-view-mode-${currentUser}-risky-users`}
      rowSx={(row) => {
        const color = riskStateColor(row?.riskState);
        if (color === "default") {
          return {
            backgroundColor: alpha(theme.palette.grey[200], 0.35),
            "&:hover": { backgroundColor: alpha(theme.palette.grey[200], 0.5) },
          };
        }
        return {
          backgroundColor: alpha(theme.palette[color].main, 0.08),
          "&:hover": { backgroundColor: alpha(theme.palette[color].main, 0.12) },
        };
      }}
      filters={filterList}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
