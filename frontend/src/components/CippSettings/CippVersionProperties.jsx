import { useState } from "react";
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Box,
  Button,
  SvgIcon,
  Tooltip,
  Typography,
  Card,
  CardHeader,
  CardContent,
  CardActions,
  Chip,
  Stack,
  Divider,
  alpha,
  useTheme,
  CircularProgress,
} from "@mui/material";
import {
  CheckCircle,
  Warning,
  Sync,
  Refresh,
  Delete,
  Computer,
  Cloud,
  Storage,
  Hub,
  ExpandMore,
} from "@mui/icons-material";
import { ApiGetCall } from "../../api/ApiCall";
import { useEffect } from "react";

const CippVersionProperties = () => {
  const theme = useTheme();
  const [cleaningUp, setCleaningUp] = useState(false);

  const manage365Version = ApiGetCall({
    url: "/manage365-version.json",
    queryKey: "Manage365Version",
  });

  const version = ApiGetCall({
    url: "/version.json",
    queryKey: "LocalVersion",
  });

  const cippVersion = ApiGetCall({
    url: `/api/GetVersion?LocalVersion=${encodeURIComponent(version?.data?.version ?? "")}`,
    queryKey: "CippVersion",
    waiting: false,
  });

  useEffect(() => {
    if (version.isFetched && !cippVersion.isFetched) {
      cippVersion.waiting = true;
      cippVersion.refetch();
    }
  }, [version, cippVersion]);

  // Cleanup stale versions and refresh
  const handleCleanupAndRefresh = async () => {
    setCleaningUp(true);
    try {
      // Call API with cleanup flag
      await fetch(
        `/api/GetVersion?LocalVersion=${encodeURIComponent(version?.data?.version ?? "")}&CleanupStale=true`
      );
      // Refetch to get updated data
      await cippVersion.refetch();
    } catch (error) {
      console.error("Failed to cleanup stale versions:", error);
    } finally {
      setCleaningUp(false);
    }
  };

  // Version badge component
  const VersionBadge = ({ version, latestVersion, isOutOfDate, label, icon }) => {
    const isUpToDate = !isOutOfDate;
    
    return (
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          p: 1.5,
          borderRadius: 1,
          bgcolor: isUpToDate
            ? alpha(theme.palette.success.main, 0.08)
            : alpha(theme.palette.warning.main, 0.08),
          border: `1px solid ${
            isUpToDate
              ? alpha(theme.palette.success.main, 0.2)
              : alpha(theme.palette.warning.main, 0.2)
          }`,
        }}
      >
        <Stack direction="row" spacing={1.5} alignItems="center">
          <SvgIcon
            sx={{
              color: isUpToDate ? "success.main" : "warning.main",
              fontSize: 20,
            }}
          >
            {icon}
          </SvgIcon>
          <Box>
            <Typography variant="body2" fontWeight={600}>
              {label}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {version ? `v${version}` : "Unknown"}
            </Typography>
          </Box>
        </Stack>
        <Stack direction="row" spacing={0.5} alignItems="center">
          {isOutOfDate && (
            <Chip
              label={`v${latestVersion} available`}
              size="small"
              color="warning"
              variant="outlined"
              sx={{ height: 24, fontSize: "0.7rem" }}
            />
          )}
          <SvgIcon
            sx={{
              color: isUpToDate ? "success.main" : "warning.main",
              fontSize: 18,
            }}
          >
            {isUpToDate ? <CheckCircle /> : <Warning />}
          </SvgIcon>
        </Stack>
      </Box>
    );
  };

  // Backend app version row
  const BackendVersionRow = ({ app, isLast }) => {
    const isOutOfSync = app?.OutOfSync;
    
    return (
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          py: 1,
          px: 1.5,
          borderBottom: isLast ? "none" : `1px solid ${theme.palette.divider}`,
          bgcolor: isOutOfSync ? alpha(theme.palette.warning.main, 0.06) : "transparent",
        }}
      >
        <Stack direction="row" spacing={1} alignItems="center">
          <SvgIcon sx={{ color: "text.secondary", fontSize: 16 }}>
            <Storage />
          </SvgIcon>
          <Typography variant="body2">
            {app.FriendlyName || app.Name}
          </Typography>
        </Stack>
        <Stack direction="row" spacing={1} alignItems="center">
          <Typography
            variant="body2"
            sx={{
              fontFamily: "monospace",
              bgcolor: alpha(theme.palette.primary.main, 0.08),
              px: 1,
              py: 0.25,
              borderRadius: 0.5,
              fontSize: "0.75rem",
            }}
          >
            v{app?.Version || "?"}
          </Typography>
          {isOutOfSync ? (
            <Tooltip title="Out of sync with main API">
              <SvgIcon sx={{ color: "warning.main", fontSize: 16 }}>
                <Sync />
              </SvgIcon>
            </Tooltip>
          ) : (
            <Tooltip title="In sync">
              <SvgIcon sx={{ color: "success.main", fontSize: 16 }}>
                <CheckCircle />
              </SvgIcon>
            </Tooltip>
          )}
        </Stack>
      </Box>
    );
  };

  const backendVersions = cippVersion?.data?.BackendVersions || [];

  return (
    <Card sx={{ display: "flex", flexDirection: "column", height: "100%", width: "100%" }}>
      <CardHeader
        title="Manage365 Version"
        titleTypographyProps={{ variant: "h6" }}
        action={
          cippVersion.isFetching ? (
            <CircularProgress size={20} />
          ) : null
        }
      />
      <Divider />
      <CardContent sx={{ flex: 1, p: 2 }}>
        <Stack spacing={2}>
          {/* Manage365 Fork Version */}
          <Box
            sx={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              p: 1.5,
              borderRadius: 1,
              bgcolor: alpha(theme.palette.info.main, 0.08),
              border: `1px solid ${alpha(theme.palette.info.main, 0.2)}`,
            }}
          >
            <Stack direction="row" spacing={1.5} alignItems="center">
              <SvgIcon sx={{ color: "info.main", fontSize: 20 }}>
                <Hub />
              </SvgIcon>
              <Box>
                <Typography variant="body2" fontWeight={600}>
                  Manage365
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {manage365Version?.data?.version
                    ? `v${manage365Version.data.version}${
                        manage365Version.data.upstreamBaseline
                          ? ` (upstream baseline v${manage365Version.data.upstreamBaseline})`
                          : ""
                      }`
                    : "Unknown"}
                </Typography>
              </Box>
            </Stack>
            <Chip
              icon={<Hub sx={{ fontSize: 14 }} />}
              label="Fork"
              size="small"
              color="info"
              variant="outlined"
              sx={{ height: 22, fontSize: "0.7rem" }}
            />
          </Box>

          {/* Upstream CIPP section */}
          <Typography
            variant="caption"
            color="text.secondary"
            sx={{ display: "block", fontWeight: 600, textTransform: "uppercase", mt: 1 }}
          >
            Upstream CIPP
          </Typography>

          {/* Frontend Version */}
          <VersionBadge
            label="Frontend"
            version={version?.data?.version}
            latestVersion={cippVersion?.data?.RemoteCIPPVersion}
            isOutOfDate={cippVersion?.data?.OutOfDateCIPP}
            icon={<Computer />}
          />

          {/* Backend Version */}
          <VersionBadge
            label="Backend API"
            version={cippVersion?.data?.LocalCIPPAPIVersion}
            latestVersion={cippVersion?.data?.RemoteCIPPAPIVersion}
            isOutOfDate={cippVersion?.data?.OutOfDateCIPPAPI}
            icon={<Cloud />}
          />

          {/* Backend Function Apps -- collapsible, auto-expands when out of sync */}
          {backendVersions.length > 0 && (() => {
            const outOfSyncCount = backendVersions.filter((app) => app.OutOfSync).length;
            const hasOutOfSync = outOfSyncCount > 0;

            return (
              <Accordion
                defaultExpanded={hasOutOfSync}
                disableGutters
                elevation={0}
                sx={{
                  border: `1px solid ${
                    hasOutOfSync
                      ? alpha(theme.palette.warning.main, 0.3)
                      : theme.palette.divider
                  }`,
                  borderRadius: "8px !important",
                  "&::before": { display: "none" },
                  overflow: "hidden",
                }}
              >
                <AccordionSummary
                  expandIcon={<ExpandMore />}
                  sx={{
                    minHeight: 44,
                    px: 1.5,
                    bgcolor: hasOutOfSync
                      ? alpha(theme.palette.warning.main, 0.06)
                      : "transparent",
                    "& .MuiAccordionSummary-content": { my: 0.75 },
                  }}
                >
                  <Stack direction="row" spacing={1} alignItems="center" sx={{ width: "100%" }}>
                    <Typography
                      variant="caption"
                      color="text.secondary"
                      sx={{ fontWeight: 600, textTransform: "uppercase" }}
                    >
                      Function Apps ({backendVersions.length})
                    </Typography>
                    {hasOutOfSync ? (
                      <Chip
                        icon={<Warning sx={{ fontSize: 14 }} />}
                        label={`${outOfSyncCount} out of sync`}
                        size="small"
                        color="warning"
                        variant="outlined"
                        sx={{ height: 22, fontSize: "0.7rem", ml: "auto" }}
                      />
                    ) : (
                      <Chip
                        icon={<CheckCircle sx={{ fontSize: 14 }} />}
                        label="All in sync"
                        size="small"
                        color="success"
                        variant="outlined"
                        sx={{ height: 22, fontSize: "0.7rem", ml: "auto" }}
                      />
                    )}
                  </Stack>
                </AccordionSummary>
                <AccordionDetails sx={{ p: 0 }}>
                  {backendVersions.map((app, index) => (
                    <BackendVersionRow
                      key={app.Name || index}
                      app={app}
                      isLast={index === backendVersions.length - 1}
                    />
                  ))}
                </AccordionDetails>
              </Accordion>
            );
          })()}
        </Stack>
      </CardContent>
      <Divider />
      <CardActions sx={{ p: 1.5, gap: 1, flexWrap: "wrap" }}>
        <Button
          variant="contained"
          color="primary"
          size="small"
          startIcon={<Refresh />}
          onClick={() => {
            version.refetch();
            cippVersion.refetch();
          }}
          disabled={cippVersion.isFetching}
        >
          Check Updates
        </Button>
        <Tooltip title="Remove outdated version entries (v6.x and older) from the database">
          <Button
            variant="outlined"
            color="secondary"
            size="small"
            startIcon={cleaningUp ? <CircularProgress size={16} /> : <Delete />}
            onClick={handleCleanupAndRefresh}
            disabled={cleaningUp || cippVersion.isFetching}
          >
            Cleanup Old Versions
          </Button>
        </Tooltip>
      </CardActions>
    </Card>
  );
};

export default CippVersionProperties;
