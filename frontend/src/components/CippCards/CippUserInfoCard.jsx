import PropTypes from "prop-types";
import {
  Avatar,
  Card,
  CardContent,
  Divider,
  Skeleton,
  Typography,
  IconButton,
  Tooltip,
  CircularProgress,
  Chip,
  Paper,
  ButtonBase,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  Button,
  Alert,
  FormControl,
  Select,
  MenuItem,
} from "@mui/material";
import { 
  AccountCircle, 
  PhotoCamera, 
  Delete, 
  PersonAddAlt1,
  Work,
  Phone,
  LocationOn,
  Badge,
  CheckCircle,
  Cancel,
  Sync,
  Cloud,
  Business,
  Email,
  OpenInNew,
  Close,
  ContentCopy,
  Check as CheckIcon,
  Add,
  Lightbulb,
  Devices,
} from "@mui/icons-material";
import { getCippFormatting } from "../../utils/get-cipp-formatting";
import { getCippLicenseTranslation } from "../../utils/get-cipp-license-translation";
import { useLicenseBackfill } from "../../hooks/use-license-backfill";
import { Stack, Grid, Box } from "@mui/system";
import { useState, useRef, useMemo } from "react";
import { ApiGetCall, ApiPostCall } from "../../api/ApiCall";
import { alpha, useTheme } from "@mui/material/styles";
import { useRouter } from "next/router";
import { useQueryClient } from "@tanstack/react-query";

// Section component for consistent styling
const InfoSection = ({ icon: Icon, title, children, isEmpty = false }) => {
  if (isEmpty) return null;
  
  return (
    <Box sx={{ mb: 2.5 }}>
      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1.5 }}>
        <Icon fontSize="small" color="primary" />
        <Typography variant="subtitle2" fontWeight={600}>
          {title}
        </Typography>
      </Stack>
      {children}
    </Box>
  );
};

// Info row component for label-value pairs
const InfoRow = ({ label, value, fullWidth = false }) => {
  if (!value) return null;
  
  return (
    <Grid size={{ xs: 12, sm: fullWidth ? 12 : 6 }}>
      <Typography variant="caption" color="text.secondary" display="block">
        {label}
      </Typography>
      <Typography variant="body2" sx={{ fontWeight: 500 }}>
        {value}
      </Typography>
    </Grid>
  );
};

export const CippUserInfoCard = (props) => {
  const { user, tenant, isFetching = false, onRefresh, ...other } = props;
  const theme = useTheme();
  const router = useRouter();
  const queryClient = useQueryClient();
  const { updateTrigger } = useLicenseBackfill();
  const [photoTimestamp, setPhotoTimestamp] = useState(Date.now());
  const [uploadError, setUploadError] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);
  const fileInputRef = useRef(null);
  
  // License removal state
  const [licenseDialog, setLicenseDialog] = useState({
    open: false,
    license: null,
    licenseName: null,
  });
  const [isRemovingLicense, setIsRemovingLicense] = useState(false);
  const [licenseError, setLicenseError] = useState(null);
  const [copiedLicenseId, setCopiedLicenseId] = useState(null);
  
  // License add state
  const [addLicenseDialogOpen, setAddLicenseDialogOpen] = useState(false);
  const [selectedLicenseToAdd, setSelectedLicenseToAdd] = useState("");
  const [isAddingLicense, setIsAddingLicense] = useState(false);
  const [addLicenseError, setAddLicenseError] = useState(null);
  const [addLicenseSuccess, setAddLicenseSuccess] = useState(null);
  const [removeLicenseSuccess, setRemoveLicenseSuccess] = useState(null);
  
  // Fetch user's registered devices
  const registeredDevicesRequest = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: `users/${user?.id}/registeredDevices`,
      tenantFilter: tenant,
      $select: "id",
      noPagination: true,
    },
    queryKey: `UserRegisteredDevices-${user?.id}-${tenant}`,
    waiting: !!user?.id && !!tenant && tenant !== "AllTenants",
    staleTime: 1000 * 60 * 5,
  });

  // Fetch user's owned devices
  const ownedDevicesRequest = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: `users/${user?.id}/ownedDevices`,
      tenantFilter: tenant,
      $select: "id",
      noPagination: true,
    },
    queryKey: `UserOwnedDevices-${user?.id}-${tenant}`,
    waiting: !!user?.id && !!tenant && tenant !== "AllTenants",
    staleTime: 1000 * 60 * 5,
  });

  // Helper to get device array from API response (backend may return Results or raw Graph value)
  const getDeviceList = (data) => {
    if (!data) return [];
    const list = data.Results ?? data.value;
    return Array.isArray(list) ? list : [];
  };

  // Compute deduplicated device count
  const deviceCount = useMemo(() => {
    const registered = getDeviceList(registeredDevicesRequest.data);
    const owned = getDeviceList(ownedDevicesRequest.data);
    const deviceIds = new Set();
    registered.forEach((d) => d?.id && deviceIds.add(d.id));
    owned.forEach((d) => d?.id && deviceIds.add(d.id));
    return deviceIds.size;
  }, [registeredDevicesRequest.data, ownedDevicesRequest.data]);

  const devicesLoading = registeredDevicesRequest.isLoading || ownedDevicesRequest.isLoading;
  const canShowDevices = !!user?.id && !!tenant && tenant !== "AllTenants";

  // Fetch tenant's subscribed SKUs for license name mapping
  const licensesRequest = ApiGetCall({
    url: `/api/ListLicenses?tenantFilter=${tenant}`,
    queryKey: `Licenses-${tenant}`,
    waiting: !!tenant && tenant !== "AllTenants",
    staleTime: 1000 * 60 * 5, // Cache for 5 minutes
  });
  
  // Build a map from skuId to license display name
  const licenseNameMap = useMemo(() => {
    const map = new Map();
    const licenses = licensesRequest.data || [];
    licenses.forEach((lic) => {
      if (lic.skuId && lic.License) {
        // License field contains the display name from backend
        map.set(lic.skuId.toLowerCase(), lic.License);
      }
    });
    return map;
  }, [licensesRequest.data]);
  
  // Get available licenses for adding (non-trial, with available units, not already assigned)
  const availableLicenses = useMemo(() => {
    const licenses = licensesRequest.data || [];
    const assignedSkuIds = new Set(
      (user?.assignedLicenses || []).map((lic) => lic.skuId?.toLowerCase())
    );
    
    return licenses.filter((lic) => {
      // Must have available units
      const availableUnits = parseInt(lic.availableUnits, 10) || 0;
      if (availableUnits <= 0) return false;
      
      // Exclude trial licenses (check TermInfo for IsTrial or license name contains "Trial")
      const termInfoArray = Array.isArray(lic.TermInfo) ? lic.TermInfo : [];
      const isTrial = termInfoArray.some((term) => term.IsTrial === true) ||
                      (lic.License || "").toLowerCase().includes("trial");
      if (isTrial) return false;
      
      // Exclude already assigned licenses
      if (assignedSkuIds.has(lic.skuId?.toLowerCase())) return false;
      
      return true;
    }).sort((a, b) => (a.License || "").localeCompare(b.License || ""));
  }, [licensesRequest.data, user?.assignedLicenses]);
  
  // License removal API
  const removeLicenseMutation = ApiPostCall({
    urlFromData: true,
  });
  
  // License add API
  const addLicenseMutation = ApiPostCall({
    urlFromData: true,
  });
  
  // Handle license chip click for removal
  const handleLicenseClick = (license, licenseName) => {
    setLicenseDialog({
      open: true,
      license,
      licenseName,
    });
    setLicenseError(null);
  };
  
  // Handle dialog close
  const handleLicenseDialogClose = () => {
    setLicenseDialog({
      open: false,
      license: null,
      licenseName: null,
    });
    setLicenseError(null);
  };
  
  // Handle license removal
  const handleRemoveLicense = async () => {
    const { license } = licenseDialog;
    setIsRemovingLicense(true);
    setLicenseError(null);
    
    try {
      const response = await removeLicenseMutation.mutateAsync({
        url: "/api/ExecBulkLicense",
        data: [{
          tenantFilter: tenant,
          userIds: user.id,
          LicenseOperation: "Remove",
          Licenses: [{ value: license.skuId }],
        }],
      });
      
      const results = response?.data?.Results || [];
      const hasError = results.some((r) => typeof r === "string" && r.toLowerCase().includes("fail"));
      
      if (hasError) {
        setLicenseError(results.join(" "));
        return;
      }
      
      queryClient.invalidateQueries({
        predicate: (query) => {
          const key = String(query.queryKey?.[0] || "");
          return key.startsWith(`ListUsers-${user?.id}`);
        },
      });
      
      if (onRefresh) {
        onRefresh();
      }
      
      setRemoveLicenseSuccess(results[0] || "License removed successfully.");
      handleLicenseDialogClose();
      setTimeout(() => setRemoveLicenseSuccess(null), 6000);
    } catch (error) {
      console.error("Failed to remove license:", error);
      setLicenseError(error.message || "Failed to remove license");
    } finally {
      setIsRemovingLicense(false);
    }
  };
  
  // Handle copying license name
  const handleCopyLicense = (licenseId, displayName) => {
    navigator.clipboard.writeText(displayName).then(() => {
      setCopiedLicenseId(licenseId);
      setTimeout(() => setCopiedLicenseId(null), 2000);
    });
  };
  
  // Handle add license dialog open
  const handleAddLicenseOpen = () => {
    setAddLicenseDialogOpen(true);
    setSelectedLicenseToAdd("");
    setAddLicenseError(null);
    setAddLicenseSuccess(null);
  };
  
  // Handle add license dialog close
  const handleAddLicenseClose = () => {
    setAddLicenseDialogOpen(false);
    setSelectedLicenseToAdd("");
    setAddLicenseError(null);
    setAddLicenseSuccess(null);
  };
  
  // Handle adding a license
  const handleAddLicense = async () => {
    if (!selectedLicenseToAdd) return;
    
    setIsAddingLicense(true);
    setAddLicenseError(null);
    setAddLicenseSuccess(null);
    
    try {
      const response = await addLicenseMutation.mutateAsync({
        url: "/api/ExecBulkLicense",
        data: [{
          tenantFilter: tenant,
          userIds: user.id,
          LicenseOperation: "Add",
          Licenses: [{ value: selectedLicenseToAdd }],
        }],
      });
      
      const results = response?.data?.Results || [];
      const hasError = results.some((r) => typeof r === "string" && r.toLowerCase().includes("fail"));
      
      if (hasError) {
        setAddLicenseError(results.join(" "));
        return;
      }
      
      queryClient.invalidateQueries({
        predicate: (query) => {
          const key = String(query.queryKey?.[0] || "");
          return key.startsWith(`ListUsers-${user?.id}`);
        },
      });
      queryClient.invalidateQueries({ queryKey: [`Licenses-${tenant}`] });
      
      if (onRefresh) {
        onRefresh();
      }
      
      setAddLicenseSuccess(results[0] || "License added successfully.");
    } catch (error) {
      console.error("Failed to add license:", error);
      setAddLicenseError(error.message || "Failed to add license");
    } finally {
      setIsAddingLicense(false);
    }
  };
  
  // Get display name for selected license to add
  const getSelectedLicenseDisplayName = () => {
    if (!selectedLicenseToAdd) return "";
    const license = availableLicenses.find((lic) => lic.skuId === selectedLicenseToAdd);
    return license?.License || "";
  };
  
  // Get translated license names with skuId preserved
  const getLicenseChips = () => {
    if (!user?.assignedLicenses || user.assignedLicenses.length === 0) {
      return null;
    }
    
    return user.assignedLicenses.map((license, index) => {
      const licenseId = license.skuId || index;
      
      // First, try to get the name from the tenant's subscribed SKUs (most accurate)
      let displayName = null;
      if (license.skuId && licenseNameMap.size > 0) {
        displayName = licenseNameMap.get(license.skuId.toLowerCase());
      }
      
      // Fall back to static translation if not found in tenant SKUs
      if (!displayName) {
        const translatedNames = getCippLicenseTranslation([license]);
        displayName = Array.isArray(translatedNames) ? translatedNames[0] : translatedNames;
      }
      
      const isCopied = copiedLicenseId === licenseId;
      
      return (
        <Box 
          key={licenseId}
          sx={{
            display: "inline-flex",
            alignItems: "stretch",
            border: `1px solid ${alpha(theme.palette.info.main, 0.5)}`,
            borderRadius: 1,
            overflow: "hidden",
            maxWidth: "100%",
            bgcolor: alpha(theme.palette.info.main, 0.04),
            "&:hover": {
              borderColor: theme.palette.info.main,
            },
          }}
        >
          {/* Copy button */}
          <Tooltip title={isCopied ? "Copied!" : "Copy license name"}>
            <ButtonBase
              onClick={() => handleCopyLicense(licenseId, displayName)}
              sx={{
                display: "flex",
                alignItems: "center",
                gap: 0.5,
                px: 1,
                py: 0.5,
                minWidth: 0,
                flex: 1,
                justifyContent: "flex-start",
                "&:hover": {
                  bgcolor: alpha(theme.palette.info.main, 0.08),
                },
              }}
            >
              {isCopied ? (
                <CheckIcon sx={{ fontSize: 14, color: "success.main", flexShrink: 0 }} />
              ) : (
                <ContentCopy sx={{ fontSize: 14, color: "info.main", flexShrink: 0 }} />
              )}
              <Typography
                variant="caption"
                sx={{
                  fontWeight: 500,
                  color: isCopied ? "success.main" : "text.primary",
                  whiteSpace: "normal",
                  wordBreak: "break-word",
                  textAlign: "left",
                  lineHeight: 1.3,
                }}
              >
                {displayName}
              </Typography>
            </ButtonBase>
          </Tooltip>
          
          {/* Remove button */}
          <Tooltip title="Remove license">
            <ButtonBase
              onClick={() => handleLicenseClick(license, displayName)}
              sx={{
                px: 0.75,
                borderLeft: `1px solid ${alpha(theme.palette.info.main, 0.3)}`,
                color: "text.secondary",
                "&:hover": {
                  bgcolor: alpha(theme.palette.error.main, 0.08),
                  color: "error.main",
                },
              }}
            >
              <Close sx={{ fontSize: 16 }} />
            </ButtonBase>
          </Tooltip>
        </Box>
      );
    });
  };

  // API mutations
  const setPhotoMutation = ApiPostCall({ urlFromData: true });
  const removePhotoMutation = ApiPostCall({ urlFromData: true });

  // Navigate to View User page
  const handleViewUser = () => {
    if (user?.id) {
      router.push(`/identity/administration/users/user?userId=${user.id}`);
    }
  };

  // Helper function to check if a section has any data
  const hasWorkInfo =
    user?.jobTitle || user?.department || user?.manager?.displayName || user?.companyName;
  const hasAddressInfo =
    user?.streetAddress || user?.postalCode || user?.city || user?.country || user?.officeLocation;
  const hasContactInfo =
    user?.mobilePhone || (user?.businessPhones && user?.businessPhones.length > 0);

  // Handle image URL with timestamp for cache busting
  const imageUrl =
    user?.id && tenant
      ? `/api/ListUserPhoto?tenantFilter=${tenant}&UserID=${user.id}&t=${photoTimestamp}`
      : undefined;

  const handleFileSelect = async (event) => {
    const file = event.target.files[0];
    setUploadError(null);
    setSuccessMessage(null);

    if (!file) return;
    
    // Guard: Ensure user data is available before attempting upload
    if (!user?.id || !tenant) {
      setUploadError("Unable to upload photo - user data not available. Please refresh the page.");
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
      return;
    }

    // Validate file type
    const validTypes = ["image/jpeg", "image/jpg", "image/png"];
    if (!validTypes.includes(file.type)) {
      setUploadError("Please select a valid image file (JPEG or PNG)");
      return;
    }

    // Validate file size (4MB max)
    const maxSize = 4 * 1024 * 1024;
    if (file.size > maxSize) {
      setUploadError(
        `File size exceeds 4MB limit. Current size: ${(file.size / (1024 * 1024)).toFixed(2)}MB`
      );
      return;
    }

    // Convert to base64 and upload
    const reader = new FileReader();
    reader.onloadend = async () => {
      try {
        await setPhotoMutation.mutateAsync({
          url: "/api/ExecSetUserPhoto",
          data: {
            userId: user.id,
            tenantFilter: tenant,
            action: "set",
            photoData: reader.result,
          },
        });
        setPhotoTimestamp(Date.now());
        setSuccessMessage("Photo updated!");
        setTimeout(() => setSuccessMessage(null), 3000);
      } catch (error) {
        setUploadError(error.message || "Failed to upload photo");
      }
    };
    reader.onerror = () => {
      setUploadError("Failed to read file");
    };
    reader.readAsDataURL(file);

    // Clear the input
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const handleRemovePhoto = async () => {
    setUploadError(null);
    setSuccessMessage(null);

    // Guard: Ensure user data is available before attempting removal
    if (!user?.id || !tenant) {
      setUploadError("Unable to remove photo - user data not available. Please refresh the page.");
      return;
    }

    try {
      await removePhotoMutation.mutateAsync({
        url: "/api/ExecSetUserPhoto",
        data: {
          userId: user.id,
          tenantFilter: tenant,
          action: "remove",
        },
      });
      setPhotoTimestamp(Date.now());
      setSuccessMessage("Photo removed!");
      setTimeout(() => setSuccessMessage(null), 3000);
    } catch (error) {
      setUploadError(error.message || "Failed to remove photo");
    }
  };

  const isLoading = setPhotoMutation.isPending || removePhotoMutation.isPending;

  if (isFetching) {
    return (
      <Card {...other}>
        <CardContent>
          <Stack spacing={2}>
            <Stack direction="row" spacing={2} alignItems="center">
              <Skeleton variant="circular" width={80} height={80} />
              <Box sx={{ flex: 1 }}>
                <Skeleton variant="text" width="60%" height={32} />
                <Skeleton variant="text" width="80%" />
              </Box>
            </Stack>
            <Skeleton variant="rectangular" height={100} />
            <Skeleton variant="rectangular" height={80} />
          </Stack>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card {...other}>
      <CardContent sx={{ p: 0 }}>
        {/* Hero Section with Photo and Name */}
        <Paper
          elevation={0}
          sx={{
            p: 3,
            background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.08)} 0%, ${alpha(theme.palette.primary.main, 0.02)} 100%)`,
            borderBottom: `1px solid ${theme.palette.divider}`,
          }}
        >
          <Stack direction="row" spacing={2.5} alignItems="flex-start">
            {/* Avatar with photo controls */}
            <Box sx={{ position: "relative" }}>
              <Tooltip title="View User">
                <ButtonBase
                  onClick={handleViewUser}
                  sx={{
                    borderRadius: "50%",
                    "&:hover": {
                      "& .MuiAvatar-root": {
                        boxShadow: theme.shadows[4],
                        transform: "scale(1.02)",
                      },
                    },
                  }}
                >
                  <Avatar
                    sx={{
                      width: 80,
                      height: 80,
                      border: `3px solid ${theme.palette.background.paper}`,
                      boxShadow: theme.shadows[2],
                      cursor: "pointer",
                      transition: "all 150ms ease-out",
                    }}
                    src={imageUrl}
                  >
                    <AccountCircle sx={{ fontSize: 48 }} />
                  </Avatar>
                </ButtonBase>
              </Tooltip>
              {isLoading && (
                <CircularProgress
                  size={86}
                  sx={{
                    position: "absolute",
                    top: -3,
                    left: -3,
                    zIndex: 1,
                  }}
                />
              )}
              {/* Photo action buttons */}
              <Stack 
                direction="row" 
                spacing={0.5} 
                sx={{ 
                  position: "absolute", 
                  bottom: -8, 
                  left: "50%", 
                  transform: "translateX(-50%)",
                }}
              >
                <input
                  type="file"
                  ref={fileInputRef}
                  style={{ display: "none" }}
                  accept="image/jpeg,image/jpg,image/png"
                  onChange={handleFileSelect}
                />
                <Tooltip title={!user?.id || !tenant ? "User data not available" : "Change Photo"}>
                  <span>
                    <IconButton
                      size="small"
                      onClick={() => fileInputRef.current?.click()}
                      disabled={isLoading || !user?.id || !tenant}
                      sx={{
                        bgcolor: "background.paper",
                        boxShadow: 1,
                        width: 28,
                        height: 28,
                        "&:hover": { bgcolor: "action.hover" },
                      }}
                    >
                      <PhotoCamera sx={{ fontSize: 14 }} />
                    </IconButton>
                  </span>
                </Tooltip>
                <Tooltip title={!user?.id || !tenant ? "User data not available" : "Remove Photo"}>
                  <span>
                    <IconButton
                      size="small"
                      onClick={handleRemovePhoto}
                      disabled={isLoading || !user?.id || !tenant}
                      sx={{
                        bgcolor: "background.paper",
                        boxShadow: 1,
                        width: 28,
                        height: 28,
                        "&:hover": { bgcolor: "error.light", color: "error.contrastText" },
                      }}
                    >
                      <Delete sx={{ fontSize: 14 }} />
                    </IconButton>
                  </span>
                </Tooltip>
              </Stack>
            </Box>

            {/* Name and basic info */}
            <Box sx={{ flex: 1, minWidth: 0, pt: 0.5 }}>
              <Tooltip title="View User">
                <Typography 
                  variant="h6" 
                  onClick={handleViewUser}
                  sx={{ 
                    fontWeight: 600, 
                    mb: 0.5,
                    cursor: "pointer",
                    display: "inline-flex",
                    alignItems: "center",
                    gap: 0.5,
                    "&:hover": {
                      color: "primary.main",
                      textDecoration: "underline",
                    },
                  }}
                >
                  {user?.displayName || "Unknown User"}
                  <OpenInNew sx={{ fontSize: 16, opacity: 0.5 }} />
                </Typography>
              </Tooltip>
              <Typography 
                variant="body2" 
                color="text.secondary" 
                sx={{ 
                  mb: 1.5,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {user?.userPrincipalName}
              </Typography>
              
              {/* Status chips */}
              <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
                <Tooltip title={user?.accountEnabled ? "Account is enabled" : "Account is disabled"}>
                  <Chip
                    icon={user?.accountEnabled ? <CheckCircle fontSize="small" /> : <Cancel fontSize="small" />}
                    label={user?.accountEnabled ? "Enabled" : "Disabled"}
                    color={user?.accountEnabled ? "success" : "error"}
                    size="small"
                    variant="outlined"
                    sx={{ height: 22 }}
                  />
                </Tooltip>
                {user?.onPremisesSyncEnabled && (
                  <Tooltip title="Synced from Active Directory">
                    <Chip
                      icon={<Sync fontSize="small" />}
                      label="AD Synced"
                      color="info"
                      size="small"
                      variant="outlined"
                      sx={{ height: 22 }}
                    />
                  </Tooltip>
                )}
                {user?.userType === "Guest" && (
                  <Tooltip title="Guest user account">
                    <Chip
                      icon={<PersonAddAlt1 fontSize="small" />}
                      label="Guest"
                      color="warning"
                      size="small"
                      variant="outlined"
                      sx={{ height: 22 }}
                    />
                  </Tooltip>
                )}
                {canShowDevices && (
                  devicesLoading ? (
                    <Tooltip title="Loading device count">
                      <Chip
                        icon={<CircularProgress size={14} />}
                        label="Devices..."
                        size="small"
                        variant="outlined"
                        sx={{ height: 22 }}
                      />
                    </Tooltip>
                  ) : (
                    <Tooltip title={`${deviceCount} device${deviceCount !== 1 ? "s" : ""} registered or owned`}>
                      <Chip
                        icon={<Devices fontSize="small" />}
                        label={`${deviceCount} Device${deviceCount !== 1 ? "s" : ""}`}
                        color={deviceCount > 0 ? "primary" : "default"}
                        size="small"
                        variant="outlined"
                        sx={{ height: 22 }}
                      />
                    </Tooltip>
                  )
                )}
              </Stack>

              {/* Photo status messages */}
              {successMessage && (
                <Typography variant="caption" color="success.main" sx={{ display: "block", mt: 1 }}>
                  {successMessage}
                </Typography>
              )}
              {uploadError && (
                <Typography variant="caption" color="error" sx={{ display: "block", mt: 1 }}>
                  {uploadError}
                </Typography>
              )}
            </Box>
          </Stack>
        </Paper>

        {/* Content Sections */}
        <Box sx={{ p: 2.5 }}>
          {/* Licenses Section */}
          <Box key={`licenses-${updateTrigger}`} sx={{ mb: 2.5 }}>
            <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1.5 }}>
              <Stack direction="row" alignItems="center" spacing={1}>
                <Badge fontSize="small" color="primary" />
                <Typography variant="subtitle2" fontWeight={600}>
                  Licenses
                </Typography>
              </Stack>
              {availableLicenses.length > 0 && (
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<Add />}
                  onClick={handleAddLicenseOpen}
                  sx={{ textTransform: "none" }}
                >
                  Add License
                </Button>
              )}
            </Stack>
            {removeLicenseSuccess && (
              <Alert severity="success" sx={{ mb: 1 }} onClose={() => setRemoveLicenseSuccess(null)}>
                {removeLicenseSuccess}
              </Alert>
            )}
            {!user?.assignedLicenses || user?.assignedLicenses.length === 0 ? (
              <Paper 
                variant="outlined" 
                sx={{ 
                  p: 1.5, 
                  bgcolor: alpha(theme.palette.info.main, 0.04),
                  borderColor: alpha(theme.palette.info.main, 0.2),
                }}
              >
                <Typography variant="body2" color="text.secondary">
                  No licenses assigned
                </Typography>
              </Paper>
            ) : (
              <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
                {getLicenseChips()}
              </Stack>
            )}
          </Box>

          <Divider sx={{ my: 2 }} />

          {/* Work Information */}
          <InfoSection icon={Work} title="Work" isEmpty={!hasWorkInfo}>
            <Grid container spacing={1.5}>
              <InfoRow label="Job Title" value={user?.jobTitle} />
              <InfoRow label="Department" value={user?.department} />
              <InfoRow label="Company" value={user?.companyName} />
              <InfoRow label="Manager" value={user?.manager?.displayName} fullWidth />
            </Grid>
          </InfoSection>

          {!hasWorkInfo && (
            <Paper 
              variant="outlined" 
              sx={{ 
                p: 1.5, 
                mb: 2.5,
                bgcolor: alpha(theme.palette.grey[500], 0.04),
              }}
            >
              <Stack direction="row" alignItems="center" spacing={1}>
                <Work fontSize="small" color="disabled" />
                <Typography variant="body2" color="text.secondary">
                  No work information available
                </Typography>
              </Stack>
            </Paper>
          )}

          {/* Contact Information */}
          <InfoSection icon={Phone} title="Contact" isEmpty={!hasContactInfo}>
            <Grid container spacing={1.5}>
              <InfoRow label="Mobile" value={user?.mobilePhone} />
              <InfoRow 
                label="Business Phone" 
                value={user?.businessPhones?.length > 0 ? user.businessPhones.join(", ") : null} 
              />
            </Grid>
          </InfoSection>

          {!hasContactInfo && (
            <Paper 
              variant="outlined" 
              sx={{ 
                p: 1.5, 
                mb: 2.5,
                bgcolor: alpha(theme.palette.grey[500], 0.04),
              }}
            >
              <Stack direction="row" alignItems="center" spacing={1}>
                <Phone fontSize="small" color="disabled" />
                <Typography variant="body2" color="text.secondary">
                  No contact information available
                </Typography>
              </Stack>
            </Paper>
          )}

          {/* Address Information */}
          <InfoSection icon={LocationOn} title="Location" isEmpty={!hasAddressInfo}>
            <Grid container spacing={1.5}>
              <InfoRow label="Office" value={user?.officeLocation} />
              <InfoRow label="Street" value={user?.streetAddress} fullWidth />
              <InfoRow label="City" value={user?.city} />
              <InfoRow label="Postal Code" value={user?.postalCode} />
              <InfoRow label="Country" value={user?.country} />
            </Grid>
          </InfoSection>

          {!hasAddressInfo && (
            <Paper 
              variant="outlined" 
              sx={{ 
                p: 1.5, 
                bgcolor: alpha(theme.palette.grey[500], 0.04),
              }}
            >
              <Stack direction="row" alignItems="center" spacing={1}>
                <LocationOn fontSize="small" color="disabled" />
                <Typography variant="body2" color="text.secondary">
                  No location information available
                </Typography>
              </Stack>
            </Paper>
          )}
        </Box>
      </CardContent>
      
      {/* License Removal Confirmation Dialog */}
      <Dialog
        open={licenseDialog.open}
        onClose={handleLicenseDialogClose}
        maxWidth="sm"
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle>
          Remove License?
        </DialogTitle>
        <DialogContent>
          <DialogContentText component="div">
            Are you sure you want to remove the following license from{" "}
            <strong>{user?.displayName}</strong>?
            
            <Paper 
              variant="outlined" 
              sx={{ 
                p: 2, 
                mt: 2, 
                bgcolor: alpha(theme.palette.warning.main, 0.04),
                borderColor: alpha(theme.palette.warning.main, 0.3),
              }}
            >
              <Typography variant="body1" fontWeight={600}>
                {licenseDialog.licenseName}
              </Typography>
            </Paper>
            
            <Alert severity="warning" sx={{ mt: 2 }}>
              This action will immediately remove the license from the user's account. 
              The user may lose access to associated services and features.
            </Alert>
          </DialogContentText>
          
          {licenseError && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {licenseError}
            </Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleLicenseDialogClose} disabled={isRemovingLicense}>
            Cancel
          </Button>
          <Button
            onClick={handleRemoveLicense}
            color="error"
            variant="contained"
            disabled={isRemovingLicense}
            startIcon={isRemovingLicense ? <CircularProgress size={16} color="inherit" /> : <Delete />}
          >
            {isRemovingLicense ? "Removing..." : "Remove License"}
          </Button>
        </DialogActions>
      </Dialog>
      
      {/* Add License Dialog */}
      <Dialog
        open={addLicenseDialogOpen}
        onClose={handleAddLicenseClose}
        maxWidth="sm"
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle>
          Add License
        </DialogTitle>
        <DialogContent>
          <DialogContentText component="div" sx={{ mb: 2 }}>
            Select a license to assign to <strong>{user?.displayName}</strong>.
          </DialogContentText>
          
          <FormControl fullWidth sx={{ mt: 2 }}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1, fontWeight: 500 }}>
              Select License
            </Typography>
            <Select
              id="add-license-select"
              value={selectedLicenseToAdd}
              onChange={(e) => setSelectedLicenseToAdd(e.target.value)}
              displayEmpty
              disabled={isAddingLicense}
              sx={{
                '& .MuiSelect-select': {
                  py: 1.5,
                },
              }}
            >
              <MenuItem value="" disabled>
                <Typography color="text.secondary">Choose a license...</Typography>
              </MenuItem>
              {availableLicenses.map((license) => (
                <MenuItem key={license.skuId} value={license.skuId}>
                  <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ width: "100%" }}>
                    <Typography variant="body2" sx={{ mr: 2 }}>
                      {license.License}
                    </Typography>
                    <Chip
                      size="small"
                      label={`${license.availableUnits} available`}
                      color="success"
                      variant="outlined"
                    />
                  </Stack>
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          
          {selectedLicenseToAdd && !addLicenseSuccess && (
            <Alert severity="info" sx={{ mt: 2 }}>
              <Typography variant="body2">
                <strong>{getSelectedLicenseDisplayName()}</strong> will be assigned to this user.
              </Typography>
            </Alert>
          )}
          
          {!addLicenseSuccess && (
            <Alert 
              severity="info" 
              icon={<Lightbulb fontSize="small" />}
              sx={{ 
                mt: 2,
                backgroundColor: (theme) => alpha(theme.palette.info.main, 0.08),
                '& .MuiAlert-icon': {
                  color: 'info.main',
                },
              }}
            >
              <Typography variant="body2">
                <strong>Tip:</strong> If you do not see the license you need, you will need to add it to the tenant first.
              </Typography>
            </Alert>
          )}
          
          {addLicenseSuccess && (
            <Alert severity="success" sx={{ mt: 2 }}>
              {addLicenseSuccess}
            </Alert>
          )}
          
          {addLicenseError && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {addLicenseError}
            </Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleAddLicenseClose}>
            {addLicenseSuccess ? "Close" : "Cancel"}
          </Button>
          {!addLicenseSuccess && (
            <Button
              onClick={handleAddLicense}
              color="primary"
              variant="contained"
              disabled={isAddingLicense || !selectedLicenseToAdd}
              startIcon={isAddingLicense ? <CircularProgress size={16} color="inherit" /> : <Add />}
            >
              {isAddingLicense ? "Adding..." : "Add License"}
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Card>
  );
};

CippUserInfoCard.propTypes = {
  user: PropTypes.object,
  tenant: PropTypes.string,
  isFetching: PropTypes.bool,
  onRefresh: PropTypes.func,
};
