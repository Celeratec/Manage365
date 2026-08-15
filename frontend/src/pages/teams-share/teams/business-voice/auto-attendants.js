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
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  SmartToy,
  Phone,
  PhoneDisabled,
  Language,
  Schedule,
  AccessTime,
  RecordVoiceOver,
  EventBusy,
} from "@mui/icons-material";
import { useMemo, useCallback } from "react";

const Page = () => {
  const pageTitle = "Auto Attendants";
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  const getCallFlowSummary = (callFlow) => {
    if (!callFlow) return "Not configured";
    if (callFlow.Menu) {
      const options = callFlow.Menu.MenuOptions;
      if (Array.isArray(options)) {
        return `${options.length} menu option${options.length !== 1 ? "s" : ""}`;
      }
    }
    return "Configured";
  };

  const getOperatorName = (item) => {
    if (!item?.Operator) return null;
    if (item.Operator.DisplayName) return item.Operator.DisplayName;
    if (item.Operator.Id) return item.Operator.Id;
    return "Configured";
  };

  const hasPhoneNumber = (item) => {
    if (!item) return false;
    if (item.LineUris && Array.isArray(item.LineUris) && item.LineUris.length > 0) return true;
    if (item.PhoneNumber) return true;
    return false;
  };

  const getPhoneNumbers = (item) => {
    if (!item) return [];
    if (item.LineUris && Array.isArray(item.LineUris)) return item.LineUris;
    if (item.PhoneNumber) return [item.PhoneNumber];
    return [];
  };

  const filters = useMemo(
    () => [
      {
        filterName: "Has Phone Number",
        value: [{ id: "hasPhone", value: "true" }],
        type: "column",
      },
      {
        filterName: "Voice Response Enabled",
        value: [{ id: "VoiceResponseEnabled", value: "true" }],
        type: "column",
      },
    ],
    []
  );

  const cardConfig = useMemo(
    () => ({
      title: "Name",
      avatar: {
        field: "Name",
        icon: () => <SmartToy />,
      },
      badges: [
        {
          field: "VoiceResponseEnabled",
          conditions: {
            true: {
              label: "Voice Response",
              color: "success",
              icon: <RecordVoiceOver fontSize="small" />,
              tooltip: "Voice commands enabled (IVR)",
            },
            True: {
              label: "Voice Response",
              color: "success",
              icon: <RecordVoiceOver fontSize="small" />,
              tooltip: "Voice commands enabled (IVR)",
            },
          },
        },
      ],
      extraFields: [
        {
          field: "Operator",
          icon: <Phone />,
          label: "Operator",
          formatter: (value) => {
            if (!value) return "Not set";
            return value.DisplayName || value.Id || "Configured";
          },
        },
        {
          field: "LanguageId",
          icon: <Language />,
          label: "Language",
          formatter: (value) => value || "Not set",
        },
      ],
      desktopFields: [
        {
          field: "TimeZoneId",
          icon: <AccessTime />,
          label: "Timezone",
        },
      ],
      cardGridProps: {
        md: 6,
        lg: 4,
      },
    }),
    []
  );

  const offCanvasChildren = useCallback(
    (row) => {
      const phoneNumbers = getPhoneNumbers(row);
      const operatorName = getOperatorName(row);
      const isVoiceEnabled =
        row.VoiceResponseEnabled === true || row.VoiceResponseEnabled === "True" || row.VoiceResponseEnabled === "true";

      return (
        <Stack spacing={3}>
          {/* Hero Section */}
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
                <SmartToy sx={{ fontSize: 28 }} />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.Name}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                  {phoneNumbers.length > 0 ? (
                    <Chip
                      icon={<Phone fontSize="small" />}
                      label={phoneNumbers[0]}
                      size="small"
                      color="success"
                      variant="outlined"
                    />
                  ) : (
                    <Chip
                      icon={<PhoneDisabled fontSize="small" />}
                      label="No number"
                      size="small"
                      color="default"
                      variant="outlined"
                    />
                  )}
                  {isVoiceEnabled && (
                    <Chip
                      icon={<RecordVoiceOver fontSize="small" />}
                      label="Voice Response"
                      size="small"
                      color="info"
                      variant="outlined"
                    />
                  )}
                </Stack>
              </Box>
            </Stack>
          </Paper>

          {/* General Settings */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              General Settings
            </Typography>
            <Stack spacing={1}>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Language
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.LanguageId || "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Timezone
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.TimeZoneId || "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Operator
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {operatorName || "—"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Voice Response
                </Typography>
                <Chip
                  label={isVoiceEnabled ? "Enabled" : "Disabled"}
                  size="small"
                  color={isVoiceEnabled ? "success" : "default"}
                  variant="outlined"
                />
              </Stack>
            </Stack>
          </Box>

          {/* Phone Numbers */}
          {phoneNumbers.length > 0 && (
            <>
              <Divider />
              <Box>
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
                  Phone Numbers ({phoneNumbers.length})
                </Typography>
                <Stack spacing={0.5}>
                  {phoneNumbers.map((num, index) => (
                    <Stack key={index} direction="row" spacing={1} alignItems="center">
                      <Phone fontSize="small" color="action" />
                      <Typography variant="body2" sx={{ fontWeight: 500 }}>
                        {typeof num === "string" ? num : num.LineUri || num.PhoneNumber || JSON.stringify(num)}
                      </Typography>
                    </Stack>
                  ))}
                </Stack>
              </Box>
            </>
          )}

          <Divider />

          {/* Business Hours Call Flow */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              <Stack direction="row" spacing={0.75} alignItems="center">
                <Schedule fontSize="small" />
                <span>Business Hours Call Flow</span>
              </Stack>
            </Typography>
            {row.DefaultCallFlow ? (
              <Stack spacing={1}>
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">
                    Name
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {row.DefaultCallFlow.Name || "Default"}
                  </Typography>
                </Stack>
                <Stack direction="row" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" color="text.secondary">
                    Menu Options
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 500 }}>
                    {getCallFlowSummary(row.DefaultCallFlow)}
                  </Typography>
                </Stack>
                {row.DefaultCallFlow.Greetings && Array.isArray(row.DefaultCallFlow.Greetings) && row.DefaultCallFlow.Greetings.length > 0 && (
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="body2" color="text.secondary">
                      Greeting
                    </Typography>
                    <Chip label="Configured" size="small" color="success" variant="outlined" />
                  </Stack>
                )}
              </Stack>
            ) : (
              <Typography variant="body2" color="text.secondary">
                Not configured
              </Typography>
            )}
          </Box>

          <Divider />

          {/* After Hours Call Flow */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              <Stack direction="row" spacing={0.75} alignItems="center">
                <AccessTime fontSize="small" />
                <span>After Hours Call Flows</span>
              </Stack>
            </Typography>
            {row.CallFlows && Array.isArray(row.CallFlows) && row.CallFlows.length > 0 ? (
              <Stack spacing={1.5}>
                {row.CallFlows.map((flow, index) => (
                  <Paper key={index} variant="outlined" sx={{ p: 1.5, borderRadius: 1 }}>
                    <Stack spacing={0.5}>
                      <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {flow.Name || `Call Flow ${index + 1}`}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {getCallFlowSummary(flow)}
                      </Typography>
                    </Stack>
                  </Paper>
                ))}
              </Stack>
            ) : (
              <Typography variant="body2" color="text.secondary">
                No after-hours call flows configured
              </Typography>
            )}
          </Box>

          {/* Holiday Schedules */}
          {row.CallHandlingAssociations &&
            Array.isArray(row.CallHandlingAssociations) &&
            row.CallHandlingAssociations.length > 0 && (
              <>
                <Divider />
                <Box>
                  <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
                    <Stack direction="row" spacing={0.75} alignItems="center">
                      <EventBusy fontSize="small" />
                      <span>Call Handling Associations ({row.CallHandlingAssociations.length})</span>
                    </Stack>
                  </Typography>
                  <Stack spacing={1}>
                    {row.CallHandlingAssociations.map((assoc, index) => (
                      <Paper key={index} variant="outlined" sx={{ p: 1.5, borderRadius: 1 }}>
                        <Stack direction="row" justifyContent="space-between" alignItems="center">
                          <Typography variant="body2" sx={{ fontWeight: 500 }}>
                            {assoc.Type || `Association ${index + 1}`}
                          </Typography>
                          <Chip
                            label={assoc.Enabled === true || assoc.Enabled === "true" ? "Enabled" : "Disabled"}
                            size="small"
                            color={assoc.Enabled === true || assoc.Enabled === "true" ? "success" : "default"}
                            variant="outlined"
                          />
                        </Stack>
                      </Paper>
                    ))}
                  </Stack>
                </Box>
              </>
            )}

          {/* Menu Options from Default Call Flow */}
          {row.DefaultCallFlow?.Menu?.MenuOptions &&
            Array.isArray(row.DefaultCallFlow.Menu.MenuOptions) &&
            row.DefaultCallFlow.Menu.MenuOptions.length > 0 && (
              <>
                <Divider />
                <Box>
                  <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
                    Menu Options
                  </Typography>
                  <Paper variant="outlined" sx={{ borderRadius: 1, overflow: "hidden" }}>
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell sx={{ fontWeight: 600, fontSize: "0.75rem" }}>
                            Key
                          </TableCell>
                          <TableCell sx={{ fontWeight: 600, fontSize: "0.75rem" }}>
                            Action
                          </TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {row.DefaultCallFlow.Menu.MenuOptions.map((opt, index) => (
                          <TableRow key={index}>
                            <TableCell sx={{ fontSize: "0.8125rem" }}>
                              {opt.DtmfResponse || opt.VoiceResponses?.[0] || `Option ${index + 1}`}
                            </TableCell>
                            <TableCell sx={{ fontSize: "0.8125rem" }}>
                              {opt.Action || "—"}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </Paper>
                </Box>
              </>
            )}
        </Stack>
      );
    },
    [theme]
  );

  const offCanvas = useMemo(
    () => ({
      children: offCanvasChildren,
      size: "lg",
    }),
    [offCanvasChildren]
  );

  const simpleColumns = useMemo(
    () =>
      isMobile
        ? ["Name", "LanguageId", "VoiceResponseEnabled"]
        : [
            "Name",
            "LanguageId",
            "TimeZoneId",
            "VoiceResponseEnabled",
            "Operator",
            "DefaultCallFlow",
            "CallFlows",
          ],
    [isMobile]
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListTeamsAutoAttendants"
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      filters={filters}
      cardConfig={cardConfig}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
