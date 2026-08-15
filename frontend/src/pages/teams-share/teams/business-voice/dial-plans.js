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
  Dialpad,
  Rule,
  Description,
  Phone,
} from "@mui/icons-material";
import { useMemo, useCallback } from "react";

const Page = () => {
  const pageTitle = "Dial Plans";
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  const getRuleCount = (item) => {
    if (Array.isArray(item?.NormalizationRules)) return item.NormalizationRules.length;
    return 0;
  };

  const cardConfig = useMemo(
    () => ({
      title: "Identity",
      subtitle: "Description",
      avatar: {
        field: "Identity",
        icon: () => <Dialpad />,
      },
      badges: [
        {
          field: "NormalizationRules",
          conditions: {},
          transform: (value) => {
            const count = Array.isArray(value) ? value.length : 0;
            return count > 0 ? `${count}` : null;
          },
          customBadge: (value) => {
            if (!value) return null;
            const count = Array.isArray(value) ? value.length : 0;
            if (count === 0) return null;
            return {
              label: `${count} rule${count !== 1 ? "s" : ""}`,
              color: "info",
              icon: <Rule fontSize="small" />,
              tooltip: `${count} normalization rule${count !== 1 ? "s" : ""} configured`,
            };
          },
        },
      ],
      extraFields: [
        {
          field: "Description",
          icon: <Description />,
          label: "Description",
          formatter: (value) => value || "No description",
        },
        {
          field: "ExternalAccessPrefix",
          icon: <Phone />,
          label: "External Prefix",
          formatter: (value) => value || "None",
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
      const rules = Array.isArray(row.NormalizationRules) ? row.NormalizationRules : [];

      return (
        <Stack spacing={3}>
          {/* Hero Section */}
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
                <Dialpad sx={{ fontSize: 28 }} />
              </Avatar>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.25 }}>
                  {row.Identity || row.Name || "Unknown Dial Plan"}
                </Typography>
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                  <Chip
                    icon={<Rule fontSize="small" />}
                    label={`${rules.length} rule${rules.length !== 1 ? "s" : ""}`}
                    size="small"
                    color="info"
                    variant="outlined"
                  />
                  {row.ExternalAccessPrefix && (
                    <Chip
                      icon={<Phone fontSize="small" />}
                      label={`Prefix: ${row.ExternalAccessPrefix}`}
                      size="small"
                      variant="outlined"
                    />
                  )}
                </Stack>
              </Box>
            </Stack>
          </Paper>

          {/* Dial Plan Details */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Dial Plan Details
            </Typography>
            <Stack spacing={1}>
              {row.Description && (
                <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                  <Typography variant="body2" color="text.secondary">
                    Description
                  </Typography>
                  <Typography
                    variant="body2"
                    sx={{ fontWeight: 500, maxWidth: 250, textAlign: "right" }}
                  >
                    {row.Description}
                  </Typography>
                </Stack>
              )}
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  External Access Prefix
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.ExternalAccessPrefix || "None"}
                </Typography>
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Optimize Device Dialing
                </Typography>
                <Chip
                  label={
                    row.OptimizeDeviceDialing === true || row.OptimizeDeviceDialing === "true"
                      ? "Enabled"
                      : "Disabled"
                  }
                  size="small"
                  color={
                    row.OptimizeDeviceDialing === true || row.OptimizeDeviceDialing === "true"
                      ? "success"
                      : "default"
                  }
                  variant="outlined"
                />
              </Stack>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="body2" color="text.secondary">
                  Simple Name
                </Typography>
                <Typography variant="body2" sx={{ fontWeight: 500 }}>
                  {row.SimpleName || "—"}
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Divider />

          {/* Normalization Rules */}
          <Box>
            <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1.5 }}>
              Normalization Rules ({rules.length})
            </Typography>
            {rules.length > 0 ? (
              <Paper variant="outlined" sx={{ borderRadius: 1, overflow: "hidden" }}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell sx={{ fontWeight: 600, fontSize: "0.75rem" }}>
                        Name
                      </TableCell>
                      <TableCell sx={{ fontWeight: 600, fontSize: "0.75rem" }}>
                        Pattern
                      </TableCell>
                      <TableCell sx={{ fontWeight: 600, fontSize: "0.75rem" }}>
                        Translation
                      </TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {rules.map((rule, index) => (
                      <TableRow key={index}>
                        <TableCell sx={{ fontSize: "0.8125rem", fontWeight: 500 }}>
                          {rule.Name || rule.Description || `Rule ${index + 1}`}
                        </TableCell>
                        <TableCell>
                          <Typography
                            variant="body2"
                            sx={{
                              fontFamily: "monospace",
                              fontSize: "0.75rem",
                              bgcolor: alpha(theme.palette.text.primary, 0.04),
                              px: 0.75,
                              py: 0.25,
                              borderRadius: 0.5,
                              display: "inline-block",
                            }}
                          >
                            {rule.Pattern || "—"}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography
                            variant="body2"
                            sx={{
                              fontFamily: "monospace",
                              fontSize: "0.75rem",
                              bgcolor: alpha(theme.palette.text.primary, 0.04),
                              px: 0.75,
                              py: 0.25,
                              borderRadius: 0.5,
                              display: "inline-block",
                            }}
                          >
                            {rule.Translation || "—"}
                          </Typography>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </Paper>
            ) : (
              <Typography variant="body2" color="text.secondary">
                No normalization rules configured
              </Typography>
            )}
          </Box>
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
        ? ["Identity", "Description", "NormalizationRules"]
        : [
            "Identity",
            "Description",
            "ExternalAccessPrefix",
            "OptimizeDeviceDialing",
            "SimpleName",
            "NormalizationRules",
          ],
    [isMobile]
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListTeamsDialPlans"
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      cardConfig={cardConfig}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
