import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { useSettings } from "../../../hooks/use-settings";
import { ApiGetCall, ApiPostCall } from "../../../api/ApiCall";
import { getFileIcon } from "../../../utils/get-file-icon";
import { useForm } from "react-hook-form";
import { useState, useMemo, useCallback, useEffect, useRef } from "react";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CardHeader,
  Chip,
  Checkbox,
  CircularProgress,
  Divider,
  FormControlLabel,
  Paper,
  Radio,
  RadioGroup,
  Stack,
  Step,
  StepLabel,
  Stepper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
  Breadcrumbs,
  IconButton,
  Tooltip,
  Link as MuiLink,
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import {
  ArrowBack,
  ArrowForward,
  ContentCopy,
  DriveFileMove,
  Folder,
  Home,
  Language,
  PersonOutline,
  SwapHoriz,
} from "@mui/icons-material";
import CippFormComponent from "../../../components/CippComponents/CippFormComponent";
import { CippApiResults } from "../../../components/CippComponents/CippApiResults";

const STEPS = ["Select Source", "Select Destination", "Review & Execute"];

// ─── Location Picker (OneDrive user or SharePoint site) ──────────────────────
const LocationPicker = ({ prefix, formControl, tenantFilter, onLocationReady }) => {
  const [locationType, setLocationType] = useState("onedrive");
  const prevValueRef = useRef(null);

  const handleTypeChange = (_e, val) => {
    if (!val) return;
    setLocationType(val);
    formControl.setValue(`${prefix}User`, null);
    formControl.setValue(`${prefix}Site`, null);
    prevValueRef.current = null;
    onLocationReady(null);
  };

  // Watch the form field values and react to changes
  const userValue = formControl.watch(`${prefix}User`);
  const siteValue = formControl.watch(`${prefix}Site`);

  useEffect(() => {
    if (locationType === "onedrive") {
      const val = userValue;
      const key = val?.value || null;
      if (key !== prevValueRef.current) {
        prevValueRef.current = key;
        if (val?.value) {
          onLocationReady({ type: "onedrive", userId: val.value, label: val.label });
        } else {
          onLocationReady(null);
        }
      }
    }
  }, [userValue, locationType, onLocationReady]);

  useEffect(() => {
    if (locationType === "sharepoint") {
      const val = siteValue;
      const key = val?.value || null;
      if (key !== prevValueRef.current) {
        prevValueRef.current = key;
        if (val?.value) {
          onLocationReady({ type: "sharepoint", siteId: val.value, label: val.label });
        } else {
          onLocationReady(null);
        }
      }
    }
  }, [siteValue, locationType, onLocationReady]);

  return (
    <Stack spacing={3}>
      <ToggleButtonGroup
        value={locationType}
        exclusive
        onChange={handleTypeChange}
        size="small"
        fullWidth
      >
        <ToggleButton value="onedrive">
          <PersonOutline sx={{ mr: 1 }} /> OneDrive User
        </ToggleButton>
        <ToggleButton value="sharepoint">
          <Language sx={{ mr: 1 }} /> SharePoint Site
        </ToggleButton>
      </ToggleButtonGroup>

      {locationType === "onedrive" && (
        <CippFormComponent
          type="autoComplete"
          name={`${prefix}User`}
          label="Select User"
          formControl={formControl}
          multiple={false}
          api={{
            tenantFilter,
            url: "/api/ListGraphRequest",
            data: {
              Endpoint: "users",
              $filter: "accountEnabled eq true",
              $top: 999,
              $count: true,
              $orderby: "displayName",
              $select: "id,displayName,userPrincipalName",
            },
            dataKey: "Results",
            labelField: (u) => `${u.displayName} (${u.userPrincipalName})`,
            valueField: "id",
            queryKey: `transfer-users-${prefix}-${tenantFilter}`,
          }}
        />
      )}

      {locationType === "sharepoint" && (
        <CippFormComponent
          type="autoComplete"
          name={`${prefix}Site`}
          label="Select SharePoint Site"
          formControl={formControl}
          multiple={false}
          api={{
            tenantFilter,
            url: "/api/ListSites",
            data: { Type: "SharePointSiteUsage" },
            queryKey: `transfer-sites-${prefix}-${tenantFilter}`,
            labelField: (s) => s.displayName || s.webUrl || s.siteId,
            valueField: "siteId",
          }}
        />
      )}
    </Stack>
  );
};

// ─── File Browser Table (used in Steps 1 and 2) ─────────────────────────────
const FileBrowserTable = ({
  tenantFilter,
  location,
  selectable = false,
  foldersOnly = false,
  selectedItems,
  onSelectionChange,
  selectedFolder,
  onFolderSelect,
}) => {
  const theme = useTheme();
  const [currentFolderId, setCurrentFolderId] = useState(null);
  const [breadcrumbs, setBreadcrumbs] = useState([{ label: location?.label || "Root", id: null }]);

  // Reset state when location changes
  const locationKey = location?.userId || location?.siteId;
  const prevLocationKeyRef = useRef(locationKey);
  useEffect(() => {
    if (locationKey !== prevLocationKeyRef.current) {
      prevLocationKeyRef.current = locationKey;
      setCurrentFolderId(null);
      setBreadcrumbs([{ label: location?.label || "Root", id: null }]);
    }
  }, [locationKey, location?.label]);

  // Build API params
  const apiParams = useMemo(() => {
    const params = { TenantFilter: tenantFilter };
    if (location?.type === "onedrive") params.UserId = location.userId;
    if (location?.type === "sharepoint") params.SiteId = location.siteId;
    if (currentFolderId) params.FolderId = currentFolderId;
    return params;
  }, [tenantFilter, location, currentFolderId]);

  const queryKey = `file-transfer-${locationKey}-${currentFolderId || "root"}`;

  const filesQuery = ApiGetCall({
    url: "/api/ListOneDriveFiles",
    data: apiParams,
    queryKey,
    waiting: !!location,
  });

  const items = useMemo(() => {
    const raw = Array.isArray(filesQuery.data) ? filesQuery.data : [];
    if (foldersOnly) return raw.filter((item) => item.isFolder);
    return raw;
  }, [filesQuery.data, foldersOnly]);

  const navigateToFolder = useCallback(
    (folderId, folderName) => {
      setCurrentFolderId(folderId);
      setBreadcrumbs((prev) => [...prev, { label: folderName, id: folderId }]);
      if (onFolderSelect) {
        onFolderSelect(folderId);
      }
    },
    [onFolderSelect]
  );

  const navigateToBreadcrumb = useCallback(
    (index) => {
      const crumb = breadcrumbs[index];
      setCurrentFolderId(crumb.id);
      setBreadcrumbs((prev) => prev.slice(0, index + 1));
      if (onFolderSelect) {
        onFolderSelect(crumb.id);
      }
    },
    [breadcrumbs, onFolderSelect]
  );

  const goUp = () => {
    if (breadcrumbs.length <= 1) return;
    navigateToBreadcrumb(breadcrumbs.length - 2);
  };

  const isItemSelected = useCallback(
    (itemId) => selectedItems?.some((i) => i.id === itemId) ?? false,
    [selectedItems]
  );

  const toggleItem = useCallback(
    (item) => {
      if (!onSelectionChange) return;
      if (isItemSelected(item.id)) {
        onSelectionChange(selectedItems.filter((i) => i.id !== item.id));
      } else {
        onSelectionChange([...selectedItems, item]);
      }
    },
    [selectedItems, onSelectionChange, isItemSelected]
  );

  const allSelected = items.length > 0 && items.every((item) => isItemSelected(item.id));
  const someSelected = items.some((item) => isItemSelected(item.id)) && !allSelected;

  const toggleAll = () => {
    if (!onSelectionChange) return;
    if (allSelected) {
      const currentIds = new Set(items.map((i) => i.id));
      onSelectionChange(selectedItems.filter((i) => !currentIds.has(i.id)));
    } else {
      const existing = new Set(selectedItems.map((i) => i.id));
      const toAdd = items.filter((i) => !existing.has(i.id));
      onSelectionChange([...selectedItems, ...toAdd]);
    }
  };

  if (!location) {
    return (
      <Paper sx={{ p: 4, textAlign: "center" }}>
        <Typography color="text.secondary">Select a location above to browse files.</Typography>
      </Paper>
    );
  }

  return (
    <Box>
      {/* Breadcrumbs */}
      <Paper
        elevation={0}
        sx={{
          px: 2,
          py: 1,
          mb: 1,
          borderBottom: `1px solid ${theme.palette.divider}`,
          bgcolor: alpha(theme.palette.info.main, 0.04),
        }}
      >
        <Stack direction="row" alignItems="center" spacing={1}>
          {breadcrumbs.length > 1 && (
            <Tooltip title="Go up one level">
              <IconButton size="small" onClick={goUp}>
                <ArrowBack fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
          <Breadcrumbs separator="/" sx={{ flex: 1 }}>
            {breadcrumbs.map((crumb, i) => {
              const isLast = i === breadcrumbs.length - 1;
              return isLast ? (
                <Chip
                  key={i}
                  icon={i === 0 ? <Home fontSize="small" /> : <Folder fontSize="small" />}
                  label={crumb.label}
                  size="small"
                  color="info"
                  variant="outlined"
                />
              ) : (
                <MuiLink
                  key={i}
                  component="button"
                  underline="hover"
                  color="text.secondary"
                  variant="body2"
                  onClick={() => navigateToBreadcrumb(i)}
                  sx={{ cursor: "pointer", display: "flex", alignItems: "center", gap: 0.5 }}
                >
                  {i === 0 && <Home fontSize="small" />}
                  {crumb.label}
                </MuiLink>
              );
            })}
          </Breadcrumbs>
          {foldersOnly && (
            <Chip
              label={`Target: ${breadcrumbs[breadcrumbs.length - 1]?.label || "Root"}`}
              color="primary"
              size="small"
              variant="filled"
            />
          )}
        </Stack>
      </Paper>

      {/* Table */}
      {filesQuery.isLoading ? (
        <Box sx={{ p: 4, textAlign: "center" }}>
          <CircularProgress size={32} />
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            Loading files...
          </Typography>
        </Box>
      ) : filesQuery.isError ? (
        <Alert severity="error" sx={{ m: 2 }}>
          Failed to load files. {filesQuery.error?.message}
        </Alert>
      ) : items.length === 0 ? (
        <Paper sx={{ p: 4, textAlign: "center" }}>
          <Typography color="text.secondary">
            {foldersOnly ? "No folders found. Files will be placed here." : "This location is empty."}
          </Typography>
        </Paper>
      ) : (
        <TableContainer component={Paper} variant="outlined" sx={{ maxHeight: 400 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {selectable && (
                  <TableCell padding="checkbox">
                    <Checkbox
                      indeterminate={someSelected}
                      checked={allSelected}
                      onChange={toggleAll}
                      size="small"
                    />
                  </TableCell>
                )}
                <TableCell>Name</TableCell>
                <TableCell>Size</TableCell>
                <TableCell>Modified</TableCell>
                <TableCell>Type</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {items.map((item) => {
                const { icon, color } = getFileIcon(item.fileExtension, item.isFolder);
                const colorValue =
                  color === "action"
                    ? theme.palette.action.active
                    : theme.palette[color]?.main || theme.palette.primary.main;

                return (
                  <TableRow
                    key={item.id}
                    hover
                    selected={isItemSelected(item.id)}
                    sx={{
                      cursor: item.isFolder ? "pointer" : selectable ? "pointer" : "default",
                    }}
                    onClick={() => {
                      if (item.isFolder) {
                        navigateToFolder(item.id, item.name);
                      } else if (selectable) {
                        toggleItem(item);
                      }
                    }}
                  >
                    {selectable && (
                      <TableCell padding="checkbox">
                        <Checkbox
                          checked={isItemSelected(item.id)}
                          onChange={(e) => {
                            e.stopPropagation();
                            toggleItem(item);
                          }}
                          size="small"
                          onClick={(e) => e.stopPropagation()}
                        />
                      </TableCell>
                    )}
                    <TableCell>
                      <Stack direction="row" alignItems="center" spacing={1.5}>
                        <Box
                          sx={{
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            width: 28,
                            height: 28,
                            borderRadius: 0.75,
                            bgcolor: alpha(colorValue, 0.1),
                            color: colorValue,
                            flexShrink: 0,
                            "& .MuiSvgIcon-root": { fontSize: 18 },
                          }}
                        >
                          {icon}
                        </Box>
                        <Typography
                          variant="body2"
                          sx={{
                            fontWeight: item.isFolder ? 600 : 400,
                            overflow: "hidden",
                            textOverflow: "ellipsis",
                            whiteSpace: "nowrap",
                            ...(item.isFolder && {
                              "&:hover": { color: "primary.main", textDecoration: "underline" },
                            }),
                          }}
                        >
                          {item.name}
                        </Typography>
                        {item.isFolder && item.childCount != null && (
                          <Chip
                            label={`${item.childCount}`}
                            size="small"
                            variant="outlined"
                            sx={{ height: 20, fontSize: "0.7rem" }}
                          />
                        )}
                      </Stack>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary">
                        {item.sizeFormatted}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary">
                        {item.lastModified
                          ? new Date(item.lastModified).toLocaleDateString(undefined, {
                              month: "short",
                              day: "numeric",
                              year: "numeric",
                            })
                          : ""}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      {item.isFolder ? (
                        <Chip
                          label="Folder"
                          size="small"
                          color="info"
                          variant="outlined"
                          sx={{ height: 22, fontSize: "0.7rem" }}
                        />
                      ) : (
                        <Typography
                          variant="body2"
                          color="text.secondary"
                          sx={{ textTransform: "uppercase", fontSize: "0.75rem" }}
                        >
                          {item.fileExtension || "File"}
                        </Typography>
                      )}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </Box>
  );
};

// ─── Step 1: Source Selection ────────────────────────────────────────────────
const SourceStep = ({ formControl, tenantFilter, sourceLocation, setSourceLocation, selectedItems, setSelectedItems }) => (
  <Stack spacing={3}>
    <Typography variant="h6">Where are the files you want to transfer?</Typography>
    <LocationPicker
      prefix="source"
      formControl={formControl}
      tenantFilter={tenantFilter}
      onLocationReady={(loc) => {
        setSourceLocation(loc);
        setSelectedItems([]);
      }}
    />
    {sourceLocation && (
      <>
        <Divider />
        <Typography variant="subtitle2" color="text.secondary">
          Browse and select the files or folders you want to transfer. Click folders to navigate into them, use the checkboxes to select items.
        </Typography>
        <FileBrowserTable
          tenantFilter={tenantFilter}
          location={sourceLocation}
          selectable
          selectedItems={selectedItems}
          onSelectionChange={setSelectedItems}
        />
        {selectedItems.length > 0 && (
          <Alert severity="info">
            {selectedItems.length} item{selectedItems.length !== 1 ? "s" : ""} selected for transfer.
          </Alert>
        )}
      </>
    )}
  </Stack>
);

// ─── Step 2: Destination Selection ───────────────────────────────────────────
const DestinationStep = ({ formControl, tenantFilter, destLocation, setDestLocation, destFolderId, setDestFolderId }) => (
  <Stack spacing={3}>
    <Typography variant="h6">Where should the files be transferred to?</Typography>
    <LocationPicker
      prefix="dest"
      formControl={formControl}
      tenantFilter={tenantFilter}
      onLocationReady={(loc) => {
        setDestLocation(loc);
        setDestFolderId(null);
      }}
    />
    {destLocation && (
      <>
        <Divider />
        <Typography variant="subtitle2" color="text.secondary">
          Navigate to the destination folder. Files will be placed in the currently displayed folder.
        </Typography>
        <FileBrowserTable
          tenantFilter={tenantFilter}
          location={destLocation}
          foldersOnly
          selectedItems={[]}
          selectedFolder={destFolderId}
          onFolderSelect={setDestFolderId}
        />
      </>
    )}
  </Stack>
);

// ─── Step 3: Review & Execute ────────────────────────────────────────────────
const ReviewStep = ({
  sourceLocation,
  destLocation,
  selectedItems,
  destFolderId,
  transferMode,
  setTransferMode,
  onExecute,
  transferMutation,
}) => (
  <Stack spacing={3}>
    <Typography variant="h6">Review and Execute Transfer</Typography>

    {/* Summary Cards */}
    <Stack direction={{ xs: "column", md: "row" }} spacing={2}>
      <Card variant="outlined" sx={{ flex: 1 }}>
        <CardHeader
          title="Source"
          titleTypographyProps={{ variant: "subtitle2" }}
          avatar={
            sourceLocation?.type === "onedrive" ? (
              <PersonOutline color="primary" />
            ) : (
              <Language color="primary" />
            )
          }
          sx={{ pb: 0 }}
        />
        <CardContent>
          <Typography variant="body2" color="text.secondary">
            {sourceLocation?.type === "onedrive" ? "OneDrive" : "SharePoint"}
          </Typography>
          <Typography variant="body1" fontWeight={600}>
            {sourceLocation?.label}
          </Typography>
          <Divider sx={{ my: 1 }} />
          <Typography variant="body2" color="text.secondary">
            {selectedItems.length} item{selectedItems.length !== 1 ? "s" : ""} selected:
          </Typography>
          <Stack direction="row" flexWrap="wrap" gap={0.5} sx={{ mt: 0.5 }}>
            {selectedItems.slice(0, 10).map((item) => (
              <Chip
                key={item.id}
                label={item.name}
                size="small"
                variant="outlined"
                color={item.isFolder ? "info" : "default"}
              />
            ))}
            {selectedItems.length > 10 && (
              <Chip label={`+${selectedItems.length - 10} more`} size="small" color="default" />
            )}
          </Stack>
        </CardContent>
      </Card>

      <Box sx={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
        <SwapHoriz sx={{ fontSize: 40, color: "text.disabled" }} />
      </Box>

      <Card variant="outlined" sx={{ flex: 1 }}>
        <CardHeader
          title="Destination"
          titleTypographyProps={{ variant: "subtitle2" }}
          avatar={
            destLocation?.type === "onedrive" ? (
              <PersonOutline color="primary" />
            ) : (
              <Language color="primary" />
            )
          }
          sx={{ pb: 0 }}
        />
        <CardContent>
          <Typography variant="body2" color="text.secondary">
            {destLocation?.type === "onedrive" ? "OneDrive" : "SharePoint"}
          </Typography>
          <Typography variant="body1" fontWeight={600}>
            {destLocation?.label}
          </Typography>
          <Divider sx={{ my: 1 }} />
          <Typography variant="body2" color="text.secondary">
            Target folder: {destFolderId ? "Selected sub-folder" : "Root"}
          </Typography>
        </CardContent>
      </Card>
    </Stack>

    {/* Transfer Mode */}
    <Card variant="outlined">
      <CardContent>
        <Typography variant="subtitle2" sx={{ mb: 1 }}>
          Transfer Mode
        </Typography>
        <RadioGroup
          value={transferMode}
          onChange={(e) => setTransferMode(e.target.value)}
          row
        >
          <FormControlLabel
            value="copy"
            control={<Radio />}
            label={
              <Stack>
                <Typography variant="body2" fontWeight={600}>
                  Copy
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Files remain in the source location
                </Typography>
              </Stack>
            }
          />
          <FormControlLabel
            value="move"
            control={<Radio />}
            label={
              <Stack>
                <Typography variant="body2" fontWeight={600}>
                  Move
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Files are removed from the source after transfer
                </Typography>
              </Stack>
            }
          />
        </RadioGroup>
      </CardContent>
    </Card>

    {transferMode === "move" && (
      <Alert severity="warning">
        Move will copy each item to the destination and then delete the original. For large files or
        folders this may take some time. If the copy is still in progress when the timeout is reached,
        the source will NOT be deleted and you can retry or remove it manually.
      </Alert>
    )}

    <Button
      variant="contained"
      size="large"
      startIcon={
        transferMutation.isPending ? (
          <CircularProgress size={20} color="inherit" />
        ) : transferMode === "move" ? (
          <DriveFileMove />
        ) : (
          <ContentCopy />
        )
      }
      onClick={onExecute}
      disabled={transferMutation.isPending}
      fullWidth
    >
      {transferMutation.isPending
        ? "Transferring..."
        : `${transferMode === "move" ? "Move" : "Copy"} ${selectedItems.length} Item${selectedItems.length !== 1 ? "s" : ""}`}
    </Button>

    {/* Results */}
    <CippApiResults apiObject={transferMutation} />
  </Stack>
);

// ─── Main Page ───────────────────────────────────────────────────────────────
const FileTransferPage = () => {
  const tenantFilter = useSettings().currentTenant;
  const formControl = useForm({ mode: "onChange" });

  const [activeStep, setActiveStep] = useState(0);

  // Step 1 state
  const [sourceLocation, setSourceLocation] = useState(null);
  const [selectedItems, setSelectedItems] = useState([]);

  // Step 2 state
  const [destLocation, setDestLocation] = useState(null);
  const [destFolderId, setDestFolderId] = useState(null);

  // Step 3 state
  const [transferMode, setTransferMode] = useState("copy");

  const transferMutation = ApiPostCall({
    onResult: () => {},
  });

  const canGoNext = useMemo(() => {
    switch (activeStep) {
      case 0:
        return sourceLocation && selectedItems.length > 0;
      case 1:
        return !!destLocation;
      default:
        return false;
    }
  }, [activeStep, sourceLocation, selectedItems, destLocation]);

  const handleNext = () => {
    if (activeStep < STEPS.length - 1) setActiveStep((s) => s + 1);
  };
  const handleBack = () => {
    if (activeStep > 0) setActiveStep((s) => s - 1);
  };

  const handleExecute = () => {
    const action = transferMode === "move" ? "CrossMove" : "CrossCopy";

    // Build destination identity
    const destIdentity = {};
    if (destLocation.type === "onedrive") {
      destIdentity.DestinationUserId = destLocation.userId;
    } else {
      destIdentity.DestinationSiteId = destLocation.siteId;
    }

    // Build source identity
    const sourceIdentity = {};
    if (sourceLocation.type === "onedrive") {
      sourceIdentity.UserId = sourceLocation.userId;
    } else {
      sourceIdentity.SiteId = sourceLocation.siteId;
    }

    // Send one request per item using bulkRequest
    const requests = selectedItems.map((item) => ({
      TenantFilter: tenantFilter,
      ...sourceIdentity,
      ...destIdentity,
      ItemId: item.id,
      ItemName: item.name,
      Action: action,
      ...(destFolderId ? { DestinationFolderId: destFolderId } : {}),
    }));

    transferMutation.mutate({
      url: "/api/ExecOneDriveFileAction",
      data: requests,
      bulkRequest: true,
    });
  };

  return (
    <Box sx={{ p: 3, maxWidth: 960, mx: "auto" }}>
      <Typography variant="h4" sx={{ mb: 1 }}>
        File Transfer
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Move or copy files between OneDrive accounts and SharePoint sites within the same tenant.
      </Typography>

      {!tenantFilter ? (
        <Alert severity="warning">Please select a tenant from the tenant selector first.</Alert>
      ) : (
        <>
          <Stepper activeStep={activeStep} alternativeLabel sx={{ mb: 4 }}>
            {STEPS.map((label, index) => (
              <Step key={label} completed={index < activeStep}>
                <StepLabel>{label}</StepLabel>
              </Step>
            ))}
          </Stepper>

          <Card>
            <CardContent>
              {activeStep === 0 && (
                <SourceStep
                  formControl={formControl}
                  tenantFilter={tenantFilter}
                  sourceLocation={sourceLocation}
                  setSourceLocation={setSourceLocation}
                  selectedItems={selectedItems}
                  setSelectedItems={setSelectedItems}
                />
              )}
              {activeStep === 1 && (
                <DestinationStep
                  formControl={formControl}
                  tenantFilter={tenantFilter}
                  destLocation={destLocation}
                  setDestLocation={setDestLocation}
                  destFolderId={destFolderId}
                  setDestFolderId={setDestFolderId}
                />
              )}
              {activeStep === 2 && (
                <ReviewStep
                  sourceLocation={sourceLocation}
                  destLocation={destLocation}
                  selectedItems={selectedItems}
                  destFolderId={destFolderId}
                  transferMode={transferMode}
                  setTransferMode={setTransferMode}
                  onExecute={handleExecute}
                  transferMutation={transferMutation}
                />
              )}
            </CardContent>
          </Card>

          {/* Navigation Buttons */}
          <Stack direction="row" justifyContent="space-between" sx={{ mt: 3 }}>
            <Button
              variant="outlined"
              startIcon={<ArrowBack />}
              onClick={handleBack}
              disabled={activeStep === 0}
            >
              Back
            </Button>
            {activeStep < STEPS.length - 1 && (
              <Button
                variant="contained"
                endIcon={<ArrowForward />}
                onClick={handleNext}
                disabled={!canGoNext}
              >
                Next
              </Button>
            )}
          </Stack>
        </>
      )}
    </Box>
  );
};

const Page = () => <FileTransferPage />;

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
