import { Layout as DashboardLayout } from '../../../layouts/index.js'
import {
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  Container,
  Skeleton,
  Typography,
  Chip,
  TextField,
  InputAdornment,
  ToggleButton,
  ToggleButtonGroup,
  Divider,
  Alert,
  MenuItem,
  FormControl,
  Select,
  Tooltip,
} from "@mui/material";
import { Grid, Stack } from "@mui/system";
import extensions from "../../../data/Extensions";
import { Sync, Search, CheckCircle, Cancel, Settings, Category } from "@mui/icons-material";
import { useSettings } from "../../../hooks/use-settings";
import { ApiGetCall } from "../../../api/ApiCall";
import Link from "next/link";
import { CippHead } from "../../../components/CippComponents/CippHead";
import { CippInfoBar } from "../../../components/CippCards/CippInfoBar";
import {
  CheckCircleIcon,
  XCircleIcon,
  CogIcon,
  LinkIcon,
} from "@heroicons/react/24/outline";
import { useState, useMemo } from "react";

const Page = () => {
  const settings = useSettings();
  const preferredTheme = settings.currentTheme?.value;
  const [searchTerm, setSearchTerm] = useState("");
  const [filterStatus, setFilterStatus] = useState("all");
  const [filterCategory, setFilterCategory] = useState("all");

  const integrations = ApiGetCall({
    url: '/api/ListExtensionsConfig',
    queryKey: 'Integrations',
    refetchOnMount: false,
    refetchOnReconnect: false,
  })

  // Calculate stats
  const stats = useMemo(() => {
    if (!integrations.isSuccess) return { enabled: 0, disabled: 0, unconfigured: 0, total: 0 };

    let enabled = 0;
    let disabled = 0;
    let unconfigured = 0;

    extensions.forEach((ext) => {
      const config = integrations.data?.[ext.id];
      const isEnabled = config?.Enabled || ext.id === "cippapi";

      if (config && isEnabled) {
        enabled++;
      } else if (config && !isEnabled) {
        disabled++;
      } else {
        unconfigured++;
      }
    });

    return { enabled, disabled, unconfigured, total: extensions.length };
  }, [integrations.isSuccess, integrations.data]);

  // Get unique categories
  const categories = useMemo(() => {
    const cats = [...new Set(extensions.map((ext) => ext.cat))];
    return cats.sort();
  }, []);

  // Get status for an extension
  const getExtensionStatus = (ext) => {
    const config = integrations.data?.[ext.id];
    const isEnabled = config?.Enabled || ext.id === "cippapi";
    if (config && isEnabled) return "enabled";
    if (config && !isEnabled) return "disabled";
    return "unconfigured";
  };

  // Filter and sort extensions - enabled first
  const filteredExtensions = useMemo(() => {
    let filtered = extensions.filter((ext) => {
      // Search filter
      if (searchTerm) {
        const search = searchTerm.toLowerCase();
        const matchesSearch =
          ext.name.toLowerCase().includes(search) ||
          ext.description.toLowerCase().includes(search) ||
          ext.cat.toLowerCase().includes(search);
        if (!matchesSearch) return false;
      }

      // Category filter
      if (filterCategory !== "all" && ext.cat !== filterCategory) {
        return false;
      }

      // Status filter
      if (filterStatus !== "all" && integrations.isSuccess) {
        const status = getExtensionStatus(ext);
        if (filterStatus !== status) return false;
      }

      return true;
    });

    // Sort: enabled first, then by name
    if (integrations.isSuccess) {
      filtered.sort((a, b) => {
        const statusA = getExtensionStatus(a);
        const statusB = getExtensionStatus(b);
        
        // Enabled first
        if (statusA === "enabled" && statusB !== "enabled") return -1;
        if (statusA !== "enabled" && statusB === "enabled") return 1;
        
        // Then disabled
        if (statusA === "disabled" && statusB === "unconfigured") return -1;
        if (statusA === "unconfigured" && statusB === "disabled") return 1;
        
        // Then alphabetically
        return a.name.localeCompare(b.name);
      });
    }

    return filtered;
  }, [searchTerm, filterCategory, filterStatus, integrations.isSuccess, integrations.data]);

  // Separate enabled from others for display
  const { enabledExtensions, otherExtensions } = useMemo(() => {
    if (!integrations.isSuccess) {
      return { enabledExtensions: [], otherExtensions: filteredExtensions };
    }
    
    const enabled = filteredExtensions.filter((ext) => getExtensionStatus(ext) === "enabled");
    const others = filteredExtensions.filter((ext) => getExtensionStatus(ext) !== "enabled");
    
    return { enabledExtensions: enabled, otherExtensions: others };
  }, [filteredExtensions, integrations.isSuccess, integrations.data]);

  const infoBarData = [
    {
      name: "Total",
      data: stats.total,
      icon: <LinkIcon />,
      color: "primary",
    },
    {
      name: "Enabled",
      data: stats.enabled,
      icon: <CheckCircleIcon />,
      color: "success",
    },
    {
      name: "Disabled",
      data: stats.disabled,
      icon: <XCircleIcon />,
      color: "warning",
    },
    {
      name: "Not Configured",
      data: stats.unconfigured,
      icon: <CogIcon />,
      color: "default",
    },
  ];

  const getStatusInfo = (extension) => {
    const status = getExtensionStatus(extension);
    if (status === "enabled") {
      return { status: "Enabled", color: "success", icon: <CheckCircle sx={{ fontSize: 14 }} /> };
    } else if (status === "disabled") {
      return { status: "Disabled", color: "warning", icon: <Cancel sx={{ fontSize: 14 }} /> };
    }
    return { status: "Not Configured", color: "default", icon: <Settings sx={{ fontSize: 14 }} /> };
  };

  // Compact integration card component
  const IntegrationCard = ({ extension }) => {
    let logo = extension.logo;
    if (preferredTheme === "dark" && extension?.logoDark) {
      logo = extension.logoDark;
    }

    const statusInfo = integrations.isSuccess
      ? getStatusInfo(extension)
      : { status: "Loading", color: "default", icon: null };

    const isEnabled = statusInfo.status === "Enabled";

    return (
      <CardActionArea
        component={Link}
        href={`/cipp/integrations/configure?id=${extension.id}`}
        sx={{ height: "100%" }}
      >
        <Card
          variant="outlined"
          sx={{
            height: "100%",
            transition: "all 0.2s",
            borderColor: isEnabled ? "success.main" : "divider",
            borderWidth: isEnabled ? 2 : 1,
            bgcolor: isEnabled ? "success.50" : "background.paper",
            "&:hover": {
              borderColor: "primary.main",
              boxShadow: 2,
              transform: "translateY(-2px)",
            },
          }}
        >
          <CardContent sx={{ p: 1.5, "&:last-child": { pb: 1.5 } }}>
            <Stack direction="row" spacing={1.5} alignItems="center">
              {/* Logo - smaller */}
              <Box
                sx={{
                  width: 40,
                  height: 40,
                  flexShrink: 0,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  borderRadius: 1,
                  bgcolor: "background.default",
                  overflow: "hidden",
                }}
              >
                {extension?.logo ? (
                  <Box
                    component="img"
                    src={logo}
                    alt={extension.name}
                    sx={{
                      maxWidth: "100%",
                      maxHeight: "100%",
                      objectFit: "contain",
                    }}
                  />
                ) : (
                  <Typography variant="caption" fontWeight={600}>
                    {extension.name.substring(0, 2).toUpperCase()}
                  </Typography>
                )}
              </Box>

              {/* Content */}
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Stack direction="row" alignItems="center" spacing={0.5}>
                  <Typography
                    variant="subtitle2"
                    fontWeight={600}
                    noWrap
                    sx={{ flex: 1 }}
                  >
                    {extension.name}
                  </Typography>
                  {integrations.isSuccess ? (
                    <Chip
                      label={statusInfo.status}
                      size="small"
                      color={statusInfo.color}
                      variant={isEnabled ? "filled" : "outlined"}
                      sx={{ 
                        height: 20, 
                        fontSize: "0.7rem",
                        "& .MuiChip-label": { px: 0.75 }
                      }}
                    />
                  ) : (
                    <Skeleton variant="rounded" width={60} height={20} />
                  )}
                </Stack>
                <Tooltip title={extension.description} arrow enterDelay={500}>
                  <Typography
                    variant="caption"
                    color="text.secondary"
                    sx={{
                      display: "-webkit-box",
                      WebkitLineClamp: 1,
                      WebkitBoxOrient: "vertical",
                      overflow: "hidden",
                    }}
                  >
                    {extension.description}
                  </Typography>
                </Tooltip>
              </Box>
            </Stack>
          </CardContent>
        </Card>
      </CardActionArea>
    );
  };

  return (
    <Container maxWidth={'xl'}>
      <CippHead title="Integrations" noTenant={true} />

      <Stack spacing={2}>
        {/* Header */}
        <Stack
          direction={{ xs: "column", sm: "row" }}
          justifyContent="space-between"
          alignItems={{ xs: "flex-start", sm: "center" }}
          spacing={2}
        >
          <Typography variant="h4">Integrations</Typography>
          <Button
            variant="contained"
            color="primary"
            startIcon={<Sync />}
            LinkComponent={Link}
            href="/cipp/integrations/sync"
          >
            Sync Jobs
          </Button>
        </Stack>

        {/* Status Summary */}
        <CippInfoBar data={infoBarData} isFetching={integrations.isFetching} />

        {/* Filters - Compact */}
        <Card variant="outlined">
          <CardContent sx={{ py: 1.5, "&:last-child": { pb: 1.5 } }}>
            <Stack
              direction={{ xs: "column", sm: "row" }}
              spacing={2}
              alignItems={{ xs: "stretch", sm: "center" }}
            >
              {/* Search */}
              <TextField
                size="small"
                placeholder="Search integrations..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                sx={{ minWidth: 200, flex: { xs: 1, sm: "none" } }}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <Search fontSize="small" />
                    </InputAdornment>
                  ),
                }}
              />

              {/* Status Filter */}
              <ToggleButtonGroup
                size="small"
                value={filterStatus}
                exclusive
                onChange={(e, value) => value && setFilterStatus(value)}
              >
                <ToggleButton value="all">All</ToggleButton>
                <ToggleButton value="enabled">
                  <CheckCircle sx={{ fontSize: 16, mr: 0.5 }} />
                  Enabled
                </ToggleButton>
                <ToggleButton value="disabled">Disabled</ToggleButton>
                <ToggleButton value="unconfigured">Not Configured</ToggleButton>
              </ToggleButtonGroup>

              {/* Category Dropdown */}
              <FormControl size="small" sx={{ minWidth: 180 }}>
                <Select
                  value={filterCategory}
                  onChange={(e) => setFilterCategory(e.target.value)}
                  displayEmpty
                  startAdornment={
                    <InputAdornment position="start">
                      <Category fontSize="small" sx={{ ml: 1 }} />
                    </InputAdornment>
                  }
                >
                  <MenuItem value="all">All Categories</MenuItem>
                  <Divider />
                  {categories.map((cat) => (
                    <MenuItem key={cat} value={cat}>
                      {cat}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Stack>
          </CardContent>
        </Card>

        {/* No results */}
        {filteredExtensions.length === 0 && (
          <Alert severity="info">
            No integrations found matching your filters. Try adjusting your search or filter criteria.
          </Alert>
        )}

        {/* Enabled Integrations Section */}
        {enabledExtensions.length > 0 && (
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <CheckCircleIcon style={{ width: 20, height: 20, color: "var(--mui-palette-success-main)" }} />
              <Typography variant="subtitle1" fontWeight={600}>
                Enabled Integrations
              </Typography>
              <Chip label={enabledExtensions.length} size="small" color="success" />
            </Stack>
            <Grid container spacing={1.5}>
              {enabledExtensions.map((extension) => (
                <Grid size={{ xs: 12, sm: 6, md: 4, lg: 3 }} key={extension.id}>
                  <IntegrationCard extension={extension} />
                </Grid>
              ))}
            </Grid>
          </Box>
        )}

        {/* Divider between sections */}
        {enabledExtensions.length > 0 && otherExtensions.length > 0 && (
          <Divider sx={{ my: 1 }} />
        )}

        {/* Other Integrations Section */}
        {otherExtensions.length > 0 && (
          <Box>
            <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
              <CogIcon style={{ width: 20, height: 20, opacity: 0.6 }} />
              <Typography variant="subtitle1" fontWeight={600} color="text.secondary">
                {enabledExtensions.length > 0 ? "Available Integrations" : "All Integrations"}
              </Typography>
              <Chip label={otherExtensions.length} size="small" variant="outlined" />
            </Stack>
            <Grid container spacing={1.5}>
              {otherExtensions.map((extension) => (
                <Grid size={{ xs: 12, sm: 6, md: 4, lg: 3 }} key={extension.id}>
                  <IntegrationCard extension={extension} />
                </Grid>
              ))}
            </Grid>
          </Box>
        )}
      </Stack>
    </Container>
  )
}

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>

export default Page
