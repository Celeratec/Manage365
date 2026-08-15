import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { useRouter } from "next/router";
import {
  Alert,
  Breadcrumbs,
  Button,
  Checkbox,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  IconButton,
  InputLabel,
  LinearProgress,
  Link as MuiLink,
  MenuItem,
  Paper,
  Select,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Tooltip,
  Typography,
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  Folder,
  ArrowBack,
  ArrowForward,
  Home,
  OpenInNew,
  CloudQueue,
  Search,
  Edit,
  DriveFileMove,
  CompareArrows,
  ContentCopy,
  Delete,
  Download,
  CreateNewFolder,
  Language,
  PersonOutline,
  SwapHoriz,
  Block,
  FolderZip,
} from "@mui/icons-material";
import { CippTablePage } from "../../../components/CippComponents/CippTablePage.jsx";
import CippFormComponent from "../../../components/CippComponents/CippFormComponent";
import { CippApiResults } from "../../../components/CippComponents/CippApiResults";
import { ApiGetCall, ApiPostCall } from "../../../api/ApiCall";
import axios from "axios";
import { buildVersionedHeaders } from "../../../utils/cippVersion";
import { useSettings } from "../../../hooks/use-settings";
import { useMemo, useState, useCallback, useEffect, useRef } from "react";
import { useForm } from "react-hook-form";
import { getFileIcon } from "../../../utils/get-file-icon";

// ─── Cross-Drive Transfer Dialog ─────────────────────────────────────────────
// Rendered via customComponent action pattern from CippDataTable (single item)
const CrossDriveTransferDrawer = (row, { drawerVisible, setDrawerVisible }, actionType, sourceIdentity) => {
  return (
    <CrossDriveTransferDialog
      open={drawerVisible}
      onClose={() => setDrawerVisible(false)}
      items={[row]}
      actionType={actionType}
      sourceIdentity={sourceIdentity}
    />
  );
};

const CrossDriveTransferDialog = ({ open, onClose, items = [], actionType, sourceIdentity = {} }) => {
  const tenantFilter = useSettings().currentTenant;
  const formControl = useForm({ mode: "onChange" });
  const theme = useTheme();

  const [locationType, setLocationType] = useState("onedrive");
  const [destLocation, setDestLocation] = useState(null);
  const [destFolderId, setDestFolderId] = useState(null);
  const [currentFolderId, setCurrentFolderId] = useState(null);
  const [breadcrumbs, setBreadcrumbs] = useState([{ label: "Root", id: null }]);
  const prevValueRef = useRef(null);

  // Bulk transfer progress state
  const [isTransferring, setIsTransferring] = useState(false);
  const [itemStatuses, setItemStatuses] = useState({});
  const [transferComplete, setTransferComplete] = useState(false);
  const [conflictBehavior, setConflictBehavior] = useState("rename");

  const userValue = formControl.watch("destUser");
  const siteValue = formControl.watch("destSite");

  useEffect(() => {
    if (locationType === "onedrive") {
      const key = userValue?.value || null;
      if (key !== prevValueRef.current) {
        prevValueRef.current = key;
        if (userValue?.value) {
          setDestLocation({ type: "onedrive", userId: userValue.value, label: userValue.label });
        } else {
          setDestLocation(null);
        }
        setDestFolderId(null);
        setCurrentFolderId(null);
        setBreadcrumbs([{ label: userValue?.label || "Root", id: null }]);
      }
    }
  }, [userValue, locationType]);

  useEffect(() => {
    if (locationType === "sharepoint") {
      const key = siteValue?.value || null;
      if (key !== prevValueRef.current) {
        prevValueRef.current = key;
        if (siteValue?.value) {
          setDestLocation({ type: "sharepoint", siteId: siteValue.value, label: siteValue.label });
        } else {
          setDestLocation(null);
        }
        setDestFolderId(null);
        setCurrentFolderId(null);
        setBreadcrumbs([{ label: siteValue?.label || "Root", id: null }]);
      }
    }
  }, [siteValue, locationType]);

  const handleTypeChange = (_e, val) => {
    if (!val) return;
    setLocationType(val);
    formControl.setValue("destUser", null);
    formControl.setValue("destSite", null);
    prevValueRef.current = null;
    setDestLocation(null);
    setDestFolderId(null);
    setCurrentFolderId(null);
    setBreadcrumbs([{ label: "Root", id: null }]);
  };

  const folderApiParams = useMemo(() => {
    if (!destLocation) return null;
    const params = { TenantFilter: tenantFilter };
    if (destLocation.type === "onedrive") params.UserId = destLocation.userId;
    if (destLocation.type === "sharepoint") params.SiteId = destLocation.siteId;
    if (currentFolderId) params.FolderId = currentFolderId;
    return params;
  }, [tenantFilter, destLocation, currentFolderId]);

  const folderQueryKey = `xdrive-folders-${destLocation?.userId || destLocation?.siteId}-${currentFolderId || "root"}`;

  const foldersQuery = ApiGetCall({
    url: "/api/ListOneDriveFiles",
    data: folderApiParams || {},
    queryKey: folderQueryKey,
    waiting: !!destLocation,
  });

  const folders = useMemo(() => {
    const raw = Array.isArray(foldersQuery.data) ? foldersQuery.data : [];
    return raw.filter((f) => f.isFolder);
  }, [foldersQuery.data]);

  const navigateToFolder = (fId, fName) => {
    setCurrentFolderId(fId);
    setDestFolderId(fId);
    setBreadcrumbs((prev) => [...prev, { label: fName, id: fId }]);
  };

  const navigateToBreadcrumb = (index) => {
    const crumb = breadcrumbs[index];
    setCurrentFolderId(crumb.id);
    setDestFolderId(crumb.id);
    setBreadcrumbs((prev) => prev.slice(0, index + 1));
  };

  const handleExecute = async () => {
    const action = actionType === "move" ? "CrossMove" : "CrossCopy";
    const destIdentity = {};
    if (destLocation.type === "onedrive") {
      destIdentity.DestinationUserId = destLocation.userId;
    } else {
      destIdentity.DestinationSiteId = destLocation.siteId;
    }

    setIsTransferring(true);
    setTransferComplete(false);
    const statuses = {};
    items.forEach((it) => { statuses[it.id || it.Id || it.ItemId || it.name] = { status: "pending" }; });
    setItemStatuses({ ...statuses });

    if (conflictBehavior === "skip") {
      try {
        const destParams = new URLSearchParams({ TenantFilter: tenantFilter });
        if (destLocation.type === "onedrive") destParams.set("UserId", destLocation.userId);
        if (destLocation.type === "sharepoint") destParams.set("SiteId", destLocation.siteId);
        if (destFolderId) destParams.set("FolderId", destFolderId);

        const checkResp = await axios.get("/api/ListOneDriveFiles", {
          params: Object.fromEntries(destParams),
          headers: await buildVersionedHeaders(),
        });
        if (checkResp.status === 200) {
          const destItems = checkResp.data;
          if (Array.isArray(destItems)) {
            const destNames = new Set(destItems.map((d) => d.name?.toLowerCase()));
            for (const it of items) {
              const key = it.id || it.Id || it.ItemId || it.name;
              if (!it.isFolder && destNames.has(it.name?.toLowerCase())) {
                statuses[key] = {
                  status: "skipped",
                  message: `Skipped '${it.name}' — already exists at the destination.`,
                };
              }
            }
            setItemStatuses({ ...statuses });
          }
        }
      } catch {
        // Pre-check failed; per-item backend check will still handle skip
      }
    }

    for (const it of items) {
      const itemId = it.id || it.Id || it.ItemId;
      const key = itemId ?? it.name;

      if (statuses[key]?.status === "skipped") continue;

      statuses[key] = { status: "in_progress" };
      setItemStatuses({ ...statuses });

      if (!itemId) {
        statuses[it.name] = { status: "error", message: `No item ID found. Keys: ${Object.keys(it).join(", ")}` };
        setItemStatuses({ ...statuses });
        continue;
      }

      try {
        const payload = {
          TenantFilter: tenantFilter,
          ...sourceIdentity,
          ItemId: itemId,
          ItemName: it.name,
          Action: action,
          ConflictBehavior: conflictBehavior,
          ...destIdentity,
          ...(destFolderId ? { DestinationFolderId: destFolderId } : {}),
        };
        const resp = await axios.post("/api/ExecOneDriveFileAction", payload, {
          headers: await buildVersionedHeaders(),
        });
        const data = resp.data;
        const msg = data?.Results || "Done";
        const isSkipped = msg.toLowerCase().startsWith("skipped");
        statuses[itemId] = { status: isSkipped ? "skipped" : "success", message: msg };
      } catch (err) {
        const errData = err.response?.data;
        statuses[itemId] = {
          status: "error",
          message: errData?.Results || errData?.error || err.message || "Network error",
        };
      }
      setItemStatuses({ ...statuses });
    }

    setIsTransferring(false);
    setTransferComplete(true);
  };

  const handleClose = () => {
    onClose();
    setDestLocation(null);
    setDestFolderId(null);
    setCurrentFolderId(null);
    setBreadcrumbs([{ label: "Root", id: null }]);
    formControl.reset();
    prevValueRef.current = null;
    setIsTransferring(false);
    setItemStatuses({});
    setConflictBehavior("rename");
    setTransferComplete(false);
  };

  const successCount = Object.values(itemStatuses).filter((s) => s.status === "success").length;
  const skippedCount = Object.values(itemStatuses).filter((s) => s.status === "skipped").length;
  const errorCount = Object.values(itemStatuses).filter((s) => s.status === "error").length;
  const completedCount = successCount + skippedCount + errorCount;
  const isBulk = items.length > 1;

  return (
    <Dialog open={open} onClose={isTransferring ? undefined : handleClose} fullWidth maxWidth="sm">
      <DialogTitle>
        <Stack direction="row" alignItems="center" spacing={1}>
          {actionType === "move" ? <DriveFileMove color="primary" /> : <ContentCopy color="primary" />}
          <span>{actionType === "move" ? "Move" : "Copy"} to Another Drive</span>
          {isBulk && (
            <Chip label={`${items.length} items`} size="small" color="primary" variant="outlined" />
          )}
        </Stack>
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2.5}>
          <Alert severity="info" variant="outlined">
            {actionType === "move" ? "Move" : "Copy"}{" "}
            {isBulk ? (
              <><strong>{items.length} items</strong> to a different user&apos;s OneDrive or a SharePoint site.</>
            ) : (
              <><strong>{items[0]?.name}</strong> to a different user&apos;s OneDrive or a SharePoint site.</>
            )}
          </Alert>

          {/* Item list for bulk transfers */}
          {isBulk && !transferComplete && !isTransferring && (
            <Paper variant="outlined" sx={{ maxHeight: 120, overflow: "auto", p: 1 }}>
              {items.map((it) => (
                <Typography key={it.id} variant="body2" color="text.secondary" noWrap sx={{ py: 0.25 }}>
                  {it.isFolder ? "📁" : "📄"} {it.name}
                </Typography>
              ))}
            </Paper>
          )}

          {/* Transfer progress */}
          {(isTransferring || transferComplete) && (
            <Stack spacing={1}>
              {transferComplete && (
                <Alert severity={errorCount === 0 ? "success" : errorCount === items.length ? "error" : "warning"}>
                  {errorCount === 0 && skippedCount === 0
                    ? `All ${successCount} item${successCount !== 1 ? "s" : ""} transferred successfully.`
                    : [
                        successCount > 0 && `${successCount} succeeded`,
                        skippedCount > 0 && `${skippedCount} skipped`,
                        errorCount > 0 && `${errorCount} failed`,
                      ].filter(Boolean).join(", ") + "."}
                </Alert>
              )}
              <Paper variant="outlined" sx={{ maxHeight: 200, overflow: "auto" }}>
                <Table size="small">
                  <TableBody>
                    {items.map((it) => {
                      const key = it.id || it.Id || it.ItemId || it.name;
                      const st = itemStatuses[key] || { status: "pending" };
                      return (
                        <TableRow key={key}>
                          <TableCell sx={{ py: 0.5, width: "50%" }}>
                            <Typography variant="body2" noWrap>{it.name}</Typography>
                          </TableCell>
                          <TableCell sx={{ py: 0.5 }}>
                            {st.status === "pending" && (
                              <Chip label="Waiting" size="small" variant="outlined" sx={{ height: 22 }} />
                            )}
                            {st.status === "in_progress" && (
                              <Stack direction="row" alignItems="center" spacing={0.5}>
                                <CircularProgress size={14} />
                                <Typography variant="caption" color="text.secondary">Transferring...</Typography>
                              </Stack>
                            )}
                            {st.status === "success" && (
                              <Chip label="Done" size="small" color="success" sx={{ height: 22 }} />
                            )}
                            {st.status === "skipped" && (
                              <Tooltip title={st.message}>
                                <Chip label="Skipped" size="small" color="info" sx={{ height: 22 }} />
                              </Tooltip>
                            )}
                            {st.status === "error" && (
                              <Tooltip title={st.message}>
                                <Chip label="Failed" size="small" color="error" sx={{ height: 22 }} />
                              </Tooltip>
                            )}
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </Paper>
              {isTransferring && (
                <Typography variant="body2" color="text.secondary" textAlign="center">
                  {completedCount} of {items.length} complete...
                </Typography>
              )}
            </Stack>
          )}

          {/* Destination picker (hidden during/after transfer) */}
          {!isTransferring && !transferComplete && (
            <>
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

              <FormControl size="small" fullWidth>
                <InputLabel>If a file or folder already exists</InputLabel>
                <Select
                  value={conflictBehavior}
                  label="If a file or folder already exists"
                  onChange={(e) => setConflictBehavior(e.target.value)}
                >
                  <MenuItem value="rename">Rename (keep both)</MenuItem>
                  <MenuItem value="replace">Replace existing</MenuItem>
                  <MenuItem value="skip">Skip duplicates</MenuItem>
                </Select>
              </FormControl>

              {locationType === "onedrive" && (
                <CippFormComponent
                  type="autoComplete"
                  name="destUser"
                  label="Destination User"
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
                    queryKey: `xdrive-users-${tenantFilter}`,
                  }}
                />
              )}
              {locationType === "sharepoint" && (
                <CippFormComponent
                  type="autoComplete"
                  name="destSite"
                  label="Destination SharePoint Site"
                  formControl={formControl}
                  multiple={false}
                  api={{
                    tenantFilter,
                    url: "/api/ListSites",
                    data: { Type: "SharePointSiteUsage" },
                    queryKey: `xdrive-sites-${tenantFilter}`,
                    labelField: (s) => s.displayName || s.webUrl || s.siteId,
                    valueField: "siteId",
                  }}
                />
              )}

              {destLocation && (
                <>
                  <Divider />
                  <Typography variant="subtitle2" color="text.secondary">
                    Navigate to select a destination folder, or leave at root.
                  </Typography>
                  <Paper
                    elevation={0}
                    sx={{
                      px: 2,
                      py: 1,
                      borderBottom: `1px solid ${theme.palette.divider}`,
                      bgcolor: alpha(theme.palette.info.main, 0.04),
                    }}
                  >
                    <Stack direction="row" alignItems="center" spacing={1}>
                      {breadcrumbs.length > 1 && (
                        <Tooltip title="Go up one level">
                          <IconButton size="small" onClick={() => navigateToBreadcrumb(breadcrumbs.length - 2)}>
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
                              color="primary"
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
                    </Stack>
                  </Paper>

                  {foldersQuery.isLoading ? (
                    <Box sx={{ p: 3, textAlign: "center" }}>
                      <CircularProgress size={24} />
                    </Box>
                  ) : folders.length === 0 ? (
                    <Typography variant="body2" color="text.secondary" sx={{ px: 1 }}>
                      No sub-folders. Files will be placed here.
                    </Typography>
                  ) : (
                    <TableContainer component={Paper} variant="outlined" sx={{ maxHeight: 250 }}>
                      <Table size="small" stickyHeader>
                        <TableBody>
                          {folders.map((folder) => (
                            <TableRow
                              key={folder.id}
                              hover
                              sx={{ cursor: "pointer" }}
                              onClick={() => navigateToFolder(folder.id, folder.name)}
                            >
                              <TableCell>
                                <Stack direction="row" alignItems="center" spacing={1}>
                                  <Folder fontSize="small" color="info" />
                                  <Typography variant="body2" fontWeight={600}>
                                    {folder.name}
                                  </Typography>
                                  {folder.childCount != null && (
                                    <Chip label={`${folder.childCount}`} size="small" variant="outlined" sx={{ height: 18, fontSize: "0.65rem" }} />
                                  )}
                                </Stack>
                              </TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </TableContainer>
                  )}
                </>
              )}
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={handleClose} color="inherit" disabled={isTransferring}>
          {transferComplete ? "Done" : "Cancel"}
        </Button>
        {!transferComplete && (
          <Button
            variant="contained"
            onClick={handleExecute}
            disabled={!destLocation || isTransferring}
            startIcon={
              isTransferring ? (
                <CircularProgress size={18} color="inherit" />
              ) : actionType === "move" ? (
                <DriveFileMove />
              ) : (
                <ContentCopy />
              )
            }
          >
            {isTransferring
              ? `Transferring ${completedCount}/${items.length}...`
              : actionType === "move"
              ? `Move ${isBulk ? `${items.length} Items` : "Here"}`
              : `Copy ${isBulk ? `${items.length} Items` : "Here"}`}
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
};

// ─── Folder Compare Dialog ──────────────────────────────────────────────────
const FolderCompareDialog = ({ open, onClose, currentLocation, tenantFilter }) => {
  const theme = useTheme();
  const rightForm = useForm({ mode: "onChange" });

  const [rightLocationType, setRightLocationType] = useState("onedrive");
  const [rightLocation, setRightLocation] = useState(null);
  const [rightFolderId, setRightFolderId] = useState(null);
  const [rightCurrentFolderId, setRightCurrentFolderId] = useState(null);
  const [rightBreadcrumbs, setRightBreadcrumbs] = useState([{ label: "Root", id: null }]);
  const prevRightRef = useRef(null);

  const [leftFolderId, setLeftFolderId] = useState(null);
  const [leftCurrentFolderId, setLeftCurrentFolderId] = useState(null);
  const [leftBreadcrumbs, setLeftBreadcrumbs] = useState([]);

  const [diffResults, setDiffResults] = useState([]);
  const [isComparing, setIsComparing] = useState(false);
  const [hasCompared, setHasCompared] = useState(false);
  const [compareError, setCompareError] = useState(null);
  const [compareInfo, setCompareInfo] = useState(null);

  const [selected, setSelected] = useState(new Set());
  const [copyDirections, setCopyDirections] = useState({});
  const [isCopying, setIsCopying] = useState(false);
  const [copyStatuses, setCopyStatuses] = useState({});
  const [copyComplete, setCopyComplete] = useState(false);

  useEffect(() => {
    if (open && currentLocation) {
      const rootLabel = currentLocation.name || "Root";
      const crumbs = [{ label: rootLabel, id: null }];
      if (currentLocation.folderPath) {
        const parts = currentLocation.folderPath.split("/").filter(Boolean);
        for (let i = 0; i < parts.length; i += 2) {
          crumbs.push({ label: parts[i], id: parts[i + 1] || null });
        }
      }
      setLeftFolderId(currentLocation.folderId || null);
      setLeftCurrentFolderId(currentLocation.folderId || null);
      setLeftBreadcrumbs(crumbs);
    }
  }, [open, currentLocation]);

  const rightUserValue = rightForm.watch("rightUser");
  const rightSiteValue = rightForm.watch("rightSite");

  useEffect(() => {
    if (rightLocationType === "onedrive") {
      const key = rightUserValue?.value || null;
      if (key !== prevRightRef.current) {
        prevRightRef.current = key;
        if (rightUserValue?.value) {
          setRightLocation({ type: "onedrive", userId: rightUserValue.value, label: rightUserValue.label });
        } else {
          setRightLocation(null);
        }
        setRightFolderId(null);
        setRightCurrentFolderId(null);
        setRightBreadcrumbs([{ label: rightUserValue?.label || "Root", id: null }]);
      }
    }
  }, [rightUserValue, rightLocationType]);

  useEffect(() => {
    if (rightLocationType === "sharepoint") {
      const key = rightSiteValue?.value || null;
      if (key !== prevRightRef.current) {
        prevRightRef.current = key;
        if (rightSiteValue?.value) {
          setRightLocation({ type: "sharepoint", siteId: rightSiteValue.value, label: rightSiteValue.label });
        } else {
          setRightLocation(null);
        }
        setRightFolderId(null);
        setRightCurrentFolderId(null);
        setRightBreadcrumbs([{ label: rightSiteValue?.label || "Root", id: null }]);
      }
    }
  }, [rightSiteValue, rightLocationType]);

  const handleRightTypeChange = (_e, val) => {
    if (!val) return;
    setRightLocationType(val);
    rightForm.setValue("rightUser", null);
    rightForm.setValue("rightSite", null);
    prevRightRef.current = null;
    setRightLocation(null);
    setRightFolderId(null);
    setRightCurrentFolderId(null);
    setRightBreadcrumbs([{ label: "Root", id: null }]);
  };

  const leftFolderParams = useMemo(() => {
    if (!currentLocation) return null;
    const params = { TenantFilter: tenantFilter };
    if (currentLocation.userId) params.UserId = currentLocation.userId;
    if (currentLocation.siteId) params.SiteId = currentLocation.siteId;
    if (leftCurrentFolderId) params.FolderId = leftCurrentFolderId;
    return params;
  }, [tenantFilter, currentLocation, leftCurrentFolderId]);

  const leftFolderQuery = ApiGetCall({
    url: "/api/ListOneDriveFiles",
    data: leftFolderParams || {},
    queryKey: `compare-left-${currentLocation?.userId || currentLocation?.siteId}-${leftCurrentFolderId || "root"}`,
    waiting: !!currentLocation && open,
  });

  const leftFolders = useMemo(() => {
    const raw = Array.isArray(leftFolderQuery.data) ? leftFolderQuery.data : [];
    return raw.filter((f) => f.isFolder);
  }, [leftFolderQuery.data]);

  const rightFolderParams = useMemo(() => {
    if (!rightLocation) return null;
    const params = { TenantFilter: tenantFilter };
    if (rightLocation.type === "onedrive") params.UserId = rightLocation.userId;
    if (rightLocation.type === "sharepoint") params.SiteId = rightLocation.siteId;
    if (rightCurrentFolderId) params.FolderId = rightCurrentFolderId;
    return params;
  }, [tenantFilter, rightLocation, rightCurrentFolderId]);

  const rightFolderQuery = ApiGetCall({
    url: "/api/ListOneDriveFiles",
    data: rightFolderParams || {},
    queryKey: `compare-right-${rightLocation?.userId || rightLocation?.siteId}-${rightCurrentFolderId || "root"}`,
    waiting: !!rightLocation,
  });

  const rightFolders = useMemo(() => {
    const raw = Array.isArray(rightFolderQuery.data) ? rightFolderQuery.data : [];
    return raw.filter((f) => f.isFolder);
  }, [rightFolderQuery.data]);

  const navigateLeft = (fId, fName) => {
    setLeftCurrentFolderId(fId);
    setLeftFolderId(fId);
    setLeftBreadcrumbs((prev) => [...prev, { label: fName, id: fId }]);
  };
  const navigateLeftBreadcrumb = (index) => {
    const crumb = leftBreadcrumbs[index];
    setLeftCurrentFolderId(crumb.id);
    setLeftFolderId(crumb.id);
    setLeftBreadcrumbs((prev) => prev.slice(0, index + 1));
  };
  const navigateRight = (fId, fName) => {
    setRightCurrentFolderId(fId);
    setRightFolderId(fId);
    setRightBreadcrumbs((prev) => [...prev, { label: fName, id: fId }]);
  };
  const navigateRightBreadcrumb = (index) => {
    const crumb = rightBreadcrumbs[index];
    setRightCurrentFolderId(crumb.id);
    setRightFolderId(crumb.id);
    setRightBreadcrumbs((prev) => prev.slice(0, index + 1));
  };

  const handleCompare = async () => {
    setIsComparing(true);
    setCompareError(null);
    setDiffResults([]);
    setSelected(new Set());
    setCopyDirections({});
    setCopyStatuses({});
    setCopyComplete(false);
    setHasCompared(false);

    try {
      const payload = { TenantFilter: tenantFilter };
      if (currentLocation.userId) payload.SourceUserId = currentLocation.userId;
      if (currentLocation.siteId) payload.SourceSiteId = currentLocation.siteId;
      if (leftFolderId) payload.SourceFolderId = leftFolderId;
      if (rightLocation.type === "onedrive") payload.DestUserId = rightLocation.userId;
      if (rightLocation.type === "sharepoint") payload.DestSiteId = rightLocation.siteId;
      if (rightFolderId) payload.DestFolderId = rightFolderId;

      const resp = await axios.post("/api/ExecOneDriveCompare", payload, {
        headers: await buildVersionedHeaders(),
      });
      const data = resp.data;

      if (Array.isArray(data?.Results)) {
        setDiffResults(data.Results);
        const defaultDirs = {};
        data.Results.forEach((item) => {
          if (item.status === "source_only") {
            defaultDirs[item.path] = "toDest";
          } else if (item.status === "dest_only") {
            defaultDirs[item.path] = "toSource";
          } else if (item.status === "size_differs" || item.status === "modified_differs") {
            const srcDate = item.sourceModified ? new Date(item.sourceModified) : null;
            const dstDate = item.destModified ? new Date(item.destModified) : null;
            if (srcDate && dstDate) {
              defaultDirs[item.path] = srcDate >= dstDate ? "toDest" : "toSource";
            } else {
              defaultDirs[item.path] = "skip";
            }
          }
        });
        setCopyDirections(defaultDirs);
        setCompareInfo({
          sourceDriveId: data.SourceDriveId,
          destDriveId: data.DestDriveId,
          matchCount: data.MatchCount || 0,
        });
        setHasCompared(true);
      } else {
        setCompareError(data?.Results || "Comparison returned unexpected data");
      }
    } catch (err) {
      const errData = err.response?.data;
      setCompareError(
        errData?.Results || errData?.error || err.message || "Network error"
      );
    }
    setIsComparing(false);
  };

  const toggleSelect = (path) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return next;
    });
  };

  const selectAll = () => setSelected(new Set(diffResults.map((d) => d.path)));
  const clearSelection = () => setSelected(new Set());

  const handleCopy = async () => {
    const selectedItems = diffResults.filter((d) => selected.has(d.path));
    const itemsToCopy = selectedItems.filter((d) => {
      const dir = copyDirections[d.path];
      if (dir === "skip" || !dir) return false;
      if (dir === "toDest") return d.status === "source_only" || d.status === "size_differs" || d.status === "modified_differs";
      if (dir === "toSource") return d.status === "dest_only" || d.status === "size_differs" || d.status === "modified_differs";
      return false;
    });
    if (itemsToCopy.length === 0) return;

    setIsCopying(true);
    setCopyComplete(false);
    const statuses = {};

    for (const item of itemsToCopy) {
      const direction = copyDirections[item.path];
      statuses[item.path] = { status: "in_progress" };
      setCopyStatuses({ ...statuses });

      try {
        const payload = { TenantFilter: tenantFilter, Action: "CrossCopy", ConflictBehavior: "replace" };

        if (direction === "toDest") {
          if (currentLocation.userId) payload.UserId = currentLocation.userId;
          if (currentLocation.siteId) payload.SiteId = currentLocation.siteId;
          payload.ItemId = item.sourceId;
          payload.ItemName = item.name;
          if (rightLocation.type === "onedrive") payload.DestinationUserId = rightLocation.userId;
          if (rightLocation.type === "sharepoint") payload.DestinationSiteId = rightLocation.siteId;
          payload.DestinationFolderId = item.destParentId || rightFolderId || null;
        } else {
          if (rightLocation.type === "onedrive") payload.UserId = rightLocation.userId;
          if (rightLocation.type === "sharepoint") payload.SiteId = rightLocation.siteId;
          payload.ItemId = item.destId;
          payload.ItemName = item.name;
          if (currentLocation.userId) payload.DestinationUserId = currentLocation.userId;
          if (currentLocation.siteId) payload.DestinationSiteId = currentLocation.siteId;
          payload.DestinationFolderId = item.sourceParentId || leftFolderId || null;
        }

        const resp = await axios.post("/api/ExecOneDriveFileAction", payload, {
          headers: await buildVersionedHeaders(),
        });
        const data = resp.data;
        statuses[item.path] = { status: "success", message: data?.Results || "Done" };
      } catch (err) {
        const errData = err.response?.data;
        statuses[item.path] = {
          status: "error",
          message: errData?.Results || errData?.error || err.message || "Network error",
        };
      }
      setCopyStatuses({ ...statuses });
    }
    setIsCopying(false);
    setCopyComplete(true);
  };

  const handleClose = () => {
    if (isCopying) return;
    onClose();
    setRightLocation(null);
    setRightFolderId(null);
    setRightCurrentFolderId(null);
    setRightBreadcrumbs([{ label: "Root", id: null }]);
    rightForm.reset();
    prevRightRef.current = null;
    setDiffResults([]);
    setIsComparing(false);
    setHasCompared(false);
    setCompareError(null);
    setCompareInfo(null);
    setSelected(new Set());
    setCopyDirections({});
    setCopyStatuses({});
    setCopyComplete(false);
  };

  const sourceOnlyCount = diffResults.filter((d) => d.status === "source_only").length;
  const destOnlyCount = diffResults.filter((d) => d.status === "dest_only").length;
  const sizeDiffersCount = diffResults.filter((d) => d.status === "size_differs").length;
  const modifiedDiffersCount = diffResults.filter((d) => d.status === "modified_differs").length;

  const selectedCopyCount = [...selected].filter((p) => {
    const dir = copyDirections[p];
    return dir && dir !== "skip";
  }).length;

  const getStatusChip = (status) => {
    switch (status) {
      case "source_only":
        return <Chip label="Source Only" size="small" color="primary" sx={{ height: 22 }} />;
      case "dest_only":
        return <Chip label="Dest Only" size="small" color="warning" sx={{ height: 22 }} />;
      case "size_differs":
        return <Chip label="Size Differs" size="small" color="error" sx={{ height: 22 }} />;
      case "modified_differs":
        return <Chip label="Modified Differs" size="small" color="info" sx={{ height: 22 }} />;
      default:
        return null;
    }
  };

  const formatSize = (bytes) => {
    if (bytes == null) return "\u2014";
    if (bytes === 0) return "0 B";
    const units = ["B", "KB", "MB", "GB", "TB"];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return `${(bytes / Math.pow(1024, i)).toFixed(i > 0 ? 1 : 0)} ${units[i]}`;
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return "\u2014";
    const d = new Date(dateStr);
    return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) +
      " " + d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
  };

  const getNewerSide = (item) => {
    if (!item.sourceModified || !item.destModified) return null;
    const src = new Date(item.sourceModified);
    const dst = new Date(item.destModified);
    if (src.getTime() === dst.getTime()) return null;
    return src > dst ? "source" : "dest";
  };

  const getDepth = (path) => (path.match(/\//g) || []).length;
  const canCompare = !!rightLocation && !isComparing && !isCopying;

  const renderBreadcrumbs = (crumbs, onNavigate, color) => (
    <Paper
      elevation={0}
      sx={{ px: 1.5, py: 0.75, mb: 1, bgcolor: alpha(theme.palette[color].main, 0.04), borderRadius: 1 }}
    >
      <Stack direction="row" alignItems="center" spacing={0.5}>
        {crumbs.length > 1 && (
          <IconButton size="small" onClick={() => onNavigate(crumbs.length - 2)}>
            <ArrowBack sx={{ fontSize: 16 }} />
          </IconButton>
        )}
        <Breadcrumbs separator="/" sx={{ flex: 1, "& .MuiBreadcrumbs-separator": { mx: 0.5 } }}>
          {crumbs.map((crumb, i) => {
            const isLast = i === crumbs.length - 1;
            return isLast ? (
              <Chip
                key={i}
                icon={i === 0 ? <Home sx={{ fontSize: 14 }} /> : <Folder sx={{ fontSize: 14 }} />}
                label={crumb.label}
                size="small"
                color={color}
                variant="outlined"
              />
            ) : (
              <MuiLink
                key={i}
                component="button"
                underline="hover"
                variant="caption"
                color="text.secondary"
                onClick={() => onNavigate(i)}
                sx={{ cursor: "pointer" }}
              >
                {crumb.label}
              </MuiLink>
            );
          })}
        </Breadcrumbs>
      </Stack>
    </Paper>
  );

  const renderFolderList = (folders, isLoading, onNavigate, color) => {
    if (isLoading) {
      return (
        <Box sx={{ py: 2, textAlign: "center" }}>
          <CircularProgress size={20} />
        </Box>
      );
    }
    if (folders.length === 0) {
      return (
        <Typography variant="caption" color="text.secondary">
          No subfolders
        </Typography>
      );
    }
    return (
      <TableContainer sx={{ maxHeight: 150 }}>
        <Table size="small">
          <TableBody>
            {folders.map((f) => (
              <TableRow key={f.id} hover sx={{ cursor: "pointer" }} onClick={() => onNavigate(f.id, f.name)}>
                <TableCell sx={{ py: 0.25 }}>
                  <Stack direction="row" alignItems="center" spacing={0.5}>
                    <Folder sx={{ fontSize: 16, color: `${color}.main` }} />
                    <Typography variant="caption">{f.name}</Typography>
                  </Stack>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    );
  };

  return (
    <Dialog open={open} onClose={isCopying ? undefined : handleClose} fullWidth maxWidth="lg">
      <DialogTitle>
        <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap">
          <CompareArrows color="primary" />
          <span>Compare Folders</span>
          {hasCompared && (
            <>
              {sourceOnlyCount > 0 && (
                <Chip label={`${sourceOnlyCount} source only`} size="small" color="primary" />
              )}
              {destOnlyCount > 0 && (
                <Chip label={`${destOnlyCount} dest only`} size="small" color="warning" />
              )}
              {sizeDiffersCount > 0 && (
                <Chip label={`${sizeDiffersCount} size differ`} size="small" color="error" />
              )}
              {modifiedDiffersCount > 0 && (
                <Chip label={`${modifiedDiffersCount} modified differ`} size="small" color="info" />
              )}
              {compareInfo?.matchCount > 0 && (
                <Chip
                  label={`${compareInfo.matchCount} match`}
                  size="small"
                  color="success"
                  variant="outlined"
                />
              )}
            </>
          )}
        </Stack>
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2}>
          <Stack direction={{ xs: "column", md: "row" }} spacing={2}>
            {/* Left Panel - Source */}
            <Paper variant="outlined" sx={{ flex: 1, p: 2, minWidth: 0 }}>
              <Typography variant="subtitle2" color="primary" gutterBottom>
                Source
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }} noWrap>
                {currentLocation?.name || "Current Location"}
                {currentLocation?.siteId ? " (SharePoint)" : " (OneDrive)"}
              </Typography>
              {renderBreadcrumbs(leftBreadcrumbs, navigateLeftBreadcrumb, "info")}
              {renderFolderList(leftFolders, leftFolderQuery.isLoading, navigateLeft, "info")}
            </Paper>

            {/* Right Panel - Destination */}
            <Paper variant="outlined" sx={{ flex: 1, p: 2, minWidth: 0 }}>
              <Typography variant="subtitle2" color="warning.main" gutterBottom>
                Destination
              </Typography>
              <ToggleButtonGroup
                value={rightLocationType}
                exclusive
                onChange={handleRightTypeChange}
                size="small"
                fullWidth
                sx={{ mb: 1 }}
              >
                <ToggleButton value="onedrive">
                  <PersonOutline sx={{ mr: 0.5, fontSize: 16 }} /> OneDrive
                </ToggleButton>
                <ToggleButton value="sharepoint">
                  <Language sx={{ mr: 0.5, fontSize: 16 }} /> SharePoint
                </ToggleButton>
              </ToggleButtonGroup>

              {rightLocationType === "onedrive" && (
                <CippFormComponent
                  type="autoComplete"
                  name="rightUser"
                  label="User"
                  formControl={rightForm}
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
                    queryKey: `compare-users-${tenantFilter}`,
                  }}
                />
              )}
              {rightLocationType === "sharepoint" && (
                <CippFormComponent
                  type="autoComplete"
                  name="rightSite"
                  label="SharePoint Site"
                  formControl={rightForm}
                  multiple={false}
                  api={{
                    tenantFilter,
                    url: "/api/ListSites",
                    data: { Type: "SharePointSiteUsage" },
                    queryKey: `compare-sites-${tenantFilter}`,
                    labelField: (s) => s.displayName || s.webUrl || s.siteId,
                    valueField: "siteId",
                  }}
                />
              )}

              {rightLocation && (
                <>
                  {renderBreadcrumbs(rightBreadcrumbs, navigateRightBreadcrumb, "warning")}
                  {renderFolderList(rightFolders, rightFolderQuery.isLoading, navigateRight, "warning")}
                </>
              )}
            </Paper>
          </Stack>

          <Button
            variant="contained"
            onClick={handleCompare}
            disabled={!canCompare}
            startIcon={isComparing ? <CircularProgress size={18} color="inherit" /> : <CompareArrows />}
            fullWidth
          >
            {isComparing ? "Comparing..." : "Compare"}
          </Button>

          {isComparing && <LinearProgress />}
          {compareError && <Alert severity="error">{compareError}</Alert>}

          {hasCompared && diffResults.length === 0 && !isComparing && (
            <Alert severity="success">
              Folders are identical
              {compareInfo?.matchCount > 0 ? ` \u2014 ${compareInfo.matchCount} matching files.` : "."}
            </Alert>
          )}

          {hasCompared && diffResults.length > 0 && !isComparing && (
            <>
              <Stack direction="row" alignItems="center" justifyContent="space-between">
                <Typography variant="subtitle2">
                  {diffResults.length} difference{diffResults.length !== 1 ? "s" : ""} found
                </Typography>
                <Stack direction="row" spacing={1}>
                  <Button size="small" onClick={selectAll} disabled={isCopying}>
                    Select All
                  </Button>
                  <Button size="small" onClick={clearSelection} disabled={isCopying}>
                    Clear
                  </Button>
                </Stack>
              </Stack>

              <TableContainer component={Paper} variant="outlined" sx={{ maxHeight: 400 }}>
                <Table size="small" stickyHeader>
                  <TableHead>
                    <TableRow>
                      <TableCell padding="checkbox" sx={{ width: 42 }} />
                      <TableCell>Name</TableCell>
                      <TableCell align="right" sx={{ width: 90 }}>Source Size</TableCell>
                      <TableCell sx={{ width: 140 }}>Source Modified</TableCell>
                      <TableCell align="right" sx={{ width: 90 }}>Dest Size</TableCell>
                      <TableCell sx={{ width: 140 }}>Dest Modified</TableCell>
                      <TableCell sx={{ width: 120 }}>Status</TableCell>
                      <TableCell sx={{ width: 130 }} align="center">Action</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {diffResults.map((item) => {
                      const depth = getDepth(item.path);
                      const cs = copyStatuses[item.path];
                      const newer = (item.status === "size_differs" || item.status === "modified_differs") ? getNewerSide(item) : null;
                      const dir = copyDirections[item.path] || "skip";
                      return (
                        <TableRow key={item.path} hover>
                          <TableCell padding="checkbox">
                            <Checkbox
                              size="small"
                              checked={selected.has(item.path)}
                              onChange={() => toggleSelect(item.path)}
                              disabled={isCopying}
                            />
                          </TableCell>
                          <TableCell>
                            <Stack direction="row" alignItems="center" spacing={0.5} sx={{ pl: depth * 2 }}>
                              {item.type === "folder" && (
                                <Folder sx={{ fontSize: 16, color: "info.main" }} />
                              )}
                              <Typography variant="body2" noWrap>
                                {item.name}
                              </Typography>
                              {cs?.status === "in_progress" && <CircularProgress size={14} />}
                              {cs?.status === "success" && (
                                <Chip label="Copied" size="small" color="success" sx={{ height: 20, ml: 0.5 }} />
                              )}
                              {cs?.status === "error" && (
                                <Tooltip title={cs.message}>
                                  <Chip label="Error" size="small" color="error" sx={{ height: 20, ml: 0.5 }} />
                                </Tooltip>
                              )}
                            </Stack>
                          </TableCell>
                          <TableCell align="right">
                            <Typography variant="caption" color="text.secondary">
                              {item.sourceSize != null ? formatSize(item.sourceSize) : "\u2014"}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Stack direction="row" alignItems="center" spacing={0.5}>
                              <Typography variant="caption" color="text.secondary">
                                {formatDate(item.sourceModified)}
                              </Typography>
                              {newer === "source" && (
                                <Chip label="Newer" size="small" color="success" sx={{ height: 18, fontSize: "0.65rem" }} />
                              )}
                            </Stack>
                          </TableCell>
                          <TableCell align="right">
                            <Typography variant="caption" color="text.secondary">
                              {item.destSize != null ? formatSize(item.destSize) : "\u2014"}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Stack direction="row" alignItems="center" spacing={0.5}>
                              <Typography variant="caption" color="text.secondary">
                                {formatDate(item.destModified)}
                              </Typography>
                              {newer === "dest" && (
                                <Chip label="Newer" size="small" color="success" sx={{ height: 18, fontSize: "0.65rem" }} />
                              )}
                            </Stack>
                          </TableCell>
                          <TableCell>{getStatusChip(item.status)}</TableCell>
                          <TableCell align="center">
                            <Stack direction="row" spacing={0} justifyContent="center">
                              <Tooltip title="Copy source to destination">
                                <IconButton
                                  size="small"
                                  color={dir === "toDest" ? "primary" : "default"}
                                  onClick={() => setCopyDirections((prev) => ({ ...prev, [item.path]: "toDest" }))}
                                  disabled={isCopying || !item.sourceId}
                                >
                                  <ArrowForward sx={{ fontSize: 16 }} />
                                </IconButton>
                              </Tooltip>
                              <Tooltip title="Copy destination to source">
                                <IconButton
                                  size="small"
                                  color={dir === "toSource" ? "warning" : "default"}
                                  onClick={() => setCopyDirections((prev) => ({ ...prev, [item.path]: "toSource" }))}
                                  disabled={isCopying || !item.destId}
                                >
                                  <ArrowBack sx={{ fontSize: 16 }} />
                                </IconButton>
                              </Tooltip>
                              <Tooltip title="Skip — don't copy">
                                <IconButton
                                  size="small"
                                  color={dir === "skip" ? "error" : "default"}
                                  onClick={() => setCopyDirections((prev) => ({ ...prev, [item.path]: "skip" }))}
                                  disabled={isCopying}
                                >
                                  <Block sx={{ fontSize: 16 }} />
                                </IconButton>
                              </Tooltip>
                            </Stack>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </TableContainer>
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={handleClose} color="inherit" disabled={isCopying}>
          {hasCompared ? "Done" : "Cancel"}
        </Button>
        {hasCompared && diffResults.length > 0 && !copyComplete && selectedCopyCount > 0 && (
          <Button
            variant="contained"
            color="primary"
            disabled={isCopying}
            onClick={() => handleCopy()}
            startIcon={isCopying ? <CircularProgress size={18} color="inherit" /> : <ContentCopy />}
          >
            Copy {selectedCopyCount} Selected
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
};

const LocationPickerLanding = () => {
  const router = useRouter();
  const formControl = useForm({ mode: "onChange" });
  const [loading, setLoading] = useState(false);
  const [locationType, setLocationType] = useState("onedrive");

  const handleTypeChange = (_e, val) => {
    if (!val) return;
    setLocationType(val);
    formControl.setValue("selectedUser", null);
    formControl.setValue("selectedSite", null);
  };

  const handleBrowseUser = (values) => {
    const user = values.selectedUser;
    if (!user) return;
    setLoading(true);
    router.push({
      pathname: router.pathname,
      query: {
        userId: user.value || user,
        name: user.label || user.value || "OneDrive",
      },
    });
  };

  const handleBrowseSite = (values) => {
    const site = values.selectedSite;
    if (!site) return;
    setLoading(true);
    router.push({
      pathname: router.pathname,
      query: {
        siteId: site.value || site,
        name: site.label || site.value || "SharePoint",
      },
    });
  };

  return (
    <Box sx={{ p: 4, display: "flex", justifyContent: "center" }}>
      <Paper sx={{ p: 4, textAlign: "center", maxWidth: 520, width: "100%" }}>
        <CloudQueue sx={{ fontSize: 64, color: "text.disabled", mb: 2 }} />
        <Typography variant="h6" color="text.secondary" sx={{ mb: 1 }}>
          Browse Files
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
          Select a user&apos;s OneDrive or a SharePoint site to browse files and folders.
        </Typography>
        <Stack spacing={2}>
          <ToggleButtonGroup
            value={locationType}
            exclusive
            onChange={handleTypeChange}
            size="small"
            fullWidth
          >
            <ToggleButton value="onedrive">
              <PersonOutline sx={{ mr: 1 }} /> OneDrive
            </ToggleButton>
            <ToggleButton value="sharepoint">
              <Language sx={{ mr: 1 }} /> SharePoint Site
            </ToggleButton>
          </ToggleButtonGroup>

          {locationType === "onedrive" && (
            <>
              <CippFormComponent
                type="autoComplete"
                name="selectedUser"
                label="Select User"
                formControl={formControl}
                multiple={false}
                api={{
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
                  labelField: (user) => `${user.displayName} (${user.userPrincipalName})`,
                  valueField: "id",
                }}
              />
              <Button
                variant="contained"
                startIcon={loading ? <CircularProgress size={18} color="inherit" /> : <Search />}
                onClick={formControl.handleSubmit(handleBrowseUser)}
                disabled={loading || !formControl.watch("selectedUser")}
                fullWidth
              >
                {loading ? "Loading..." : "Browse OneDrive"}
              </Button>
            </>
          )}

          {locationType === "sharepoint" && (
            <>
              <CippFormComponent
                type="autoComplete"
                name="selectedSite"
                label="Select SharePoint Site"
                formControl={formControl}
                multiple={false}
                api={{
                  url: "/api/ListSites",
                  data: { Type: "SharePointSiteUsage" },
                  queryKey: "file-browser-sites",
                  labelField: (s) => s.displayName || s.webUrl || s.siteId,
                  valueField: "siteId",
                }}
              />
              <Button
                variant="contained"
                startIcon={loading ? <CircularProgress size={18} color="inherit" /> : <Search />}
                onClick={formControl.handleSubmit(handleBrowseSite)}
                disabled={loading || !formControl.watch("selectedSite")}
                fullWidth
              >
                {loading ? "Loading..." : "Browse SharePoint"}
              </Button>
            </>
          )}
        </Stack>
      </Paper>
    </Box>
  );
};

const Page = () => {
  const router = useRouter();
  const theme = useTheme();
  const { siteId, driveId, folderId, name, folderPath, userId } = router.query;

  // Query key for the current folder view - used for cache invalidation
  const currentQueryKey = `onedrive-files-${siteId || userId || driveId}-${folderId || "root"}`;

  // New Folder dialog state
  const tenantFilter = useSettings().currentTenant;
  const [newFolderOpen, setNewFolderOpen] = useState(false);
  const [newFolderName, setNewFolderName] = useState("");
  const newFolderMutation = ApiPostCall({
    relatedQueryKeys: [currentQueryKey],
  });

  const handleNewFolderSubmit = () => {
    if (!newFolderName.trim()) return;
    const identity = {};
    if (driveId) identity.DriveId = driveId;
    else if (userId) identity.UserId = userId;
    else if (siteId) identity.SiteId = siteId;

    newFolderMutation.mutate({
      url: "/api/ExecOneDriveFileAction",
      data: {
        tenantFilter,
        ...identity,
        Action: "CreateFolder",
        FolderName: newFolderName.trim(),
        ...(folderId ? { ParentId: folderId } : {}),
      },
    });
  };

  const handleNewFolderClose = () => {
    setNewFolderOpen(false);
    setNewFolderName("");
    newFolderMutation.reset();
  };

  // Bulk cross-drive transfer state
  const [bulkTransfer, setBulkTransfer] = useState({ open: false, items: [], actionType: "move" });

  // Bulk zip download state
  const [isZipping, setIsZipping] = useState(false);
  const handleBulkZipDownload = useCallback(async (items) => {
    if (!items.length || !tenantFilter) return;
    setIsZipping(true);
    try {
      const payload = {
        TenantFilter: tenantFilter,
        Items: items.map((it) => ({ DriveId: it.driveId || driveId, ItemId: it.id, Name: it.name })),
        ZipFileName: `Manage365-Archive-${new Date().toISOString().slice(0, 10)}.zip`,
      };
      const resp = await axios.post("/api/ExecZipFiles", payload, {
        headers: await buildVersionedHeaders(),
        timeout: 300000,
      });
      const { zipBase64, zipFileName } = resp.data || {};
      if (zipBase64) {
        const byteChars = atob(zipBase64);
        const byteArray = new Uint8Array(byteChars.length);
        for (let i = 0; i < byteChars.length; i++) byteArray[i] = byteChars.charCodeAt(i);
        const blob = new Blob([byteArray], { type: "application/zip" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = zipFileName || "Manage365-Archive.zip";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    } catch {
      // Errors handled by the Results toast pattern
    }
    setIsZipping(false);
  }, [tenantFilter, driveId]);

  // Compare dialog state
  const [compareOpen, setCompareOpen] = useState(false);

  // Location switcher state
  const currentLocationType = siteId ? "sharepoint" : "onedrive";
  const [switcherOpen, setSwitcherOpen] = useState(false);
  const [switcherType, setSwitcherType] = useState(currentLocationType);
  const switcherForm = useForm({ mode: "onChange" });

  const handleSwitcherOpen = () => {
    setSwitcherType(currentLocationType);
    switcherForm.reset();
    setSwitcherOpen(true);
  };

  const handleSwitchLocation = (values) => {
    if (switcherType === "onedrive") {
      const user = values.switchUser;
      if (!user) return;
      router.push({
        pathname: router.pathname,
        query: { userId: user.value || user, name: user.label || user.value || "OneDrive" },
      });
    } else {
      const site = values.switchSite;
      if (!site) return;
      router.push({
        pathname: router.pathname,
        query: { siteId: site.value || site, name: site.label || site.value || "SharePoint" },
      });
    }
    setSwitcherOpen(false);
  };

  // Build breadcrumb from folderPath
  const breadcrumbs = useMemo(() => {
    const rootLabel = name || (siteId ? "SharePoint" : "OneDrive");
    const crumbs = [{ label: rootLabel, folderId: null }];
    if (folderPath) {
      const parts = folderPath.split("/").filter(Boolean);
      for (let i = 0; i < parts.length; i += 2) {
        crumbs.push({
          label: parts[i],
          folderId: parts[i + 1] || null,
        });
      }
    }
    return crumbs;
  }, [folderPath, name]);

  const navigateToFolder = useCallback(
    (itemId, itemName) => {
      const newPath = folderPath
        ? `${folderPath}/${itemName}/${itemId}`
        : `${itemName}/${itemId}`;
      router.push(
        {
          pathname: router.pathname,
          query: {
            ...(siteId && { siteId }),
            ...(driveId && { driveId }),
            ...(userId && { userId }),
            name,
            folderId: itemId,
            folderPath: newPath,
          },
        },
        undefined,
        { shallow: true }
      );
    },
    [router, siteId, driveId, userId, name, folderPath]
  );

  const navigateToBreadcrumb = (index) => {
    const crumb = breadcrumbs[index];
    if (index === 0) {
      const { folderId: _f, folderPath: _fp, ...rest } = router.query;
      router.push({ pathname: router.pathname, query: rest }, undefined, { shallow: true });
    } else {
      const parts = folderPath.split("/").filter(Boolean);
      const newPath = parts.slice(0, index * 2).join("/");
      router.push(
        {
          pathname: router.pathname,
          query: {
            ...(siteId && { siteId }),
            ...(driveId && { driveId }),
            ...(userId && { userId }),
            name,
            folderId: crumb.folderId,
            folderPath: newPath,
          },
        },
        undefined,
        { shallow: true }
      );
    }
  };

  const goUp = () => {
    if (breadcrumbs.length <= 1) return;
    navigateToBreadcrumb(breadcrumbs.length - 2);
  };

  // Build API query params for listing files
  const apiData = useMemo(() => {
    const data = {};
    if (siteId) data.SiteId = siteId;
    if (driveId) data.DriveId = driveId;
    if (userId) data.UserId = userId;
    if (folderId) data.FolderId = folderId;
    return data;
  }, [siteId, driveId, userId, folderId]);

  // Build the common data payload for file actions (drive identity)
  // The `!` prefix marks literal values for CippApiDialog action processing
  const driveIdentity = useMemo(() => {
    if (driveId) return { DriveId: `!${driveId}` };
    if (userId) return { UserId: `!${userId}` };
    if (siteId) return { SiteId: `!${siteId}` };
    return {};
  }, [driveId, userId, siteId]);

  // Raw identity without `!` prefix for direct API calls (cross-drive dialogs)
  const rawDriveIdentity = useMemo(() => {
    if (driveId) return { DriveId: driveId };
    if (userId) return { UserId: userId };
    if (siteId) return { SiteId: siteId };
    return {};
  }, [driveId, userId, siteId]);

  // Build folder picker API config for Move/Copy destination
  const folderPickerApi = useMemo(
    () => ({
      url: "/api/ListOneDriveFiles",
      data: {
        ...(siteId && { SiteId: siteId }),
        ...(driveId && { DriveId: driveId }),
        ...(userId && { UserId: userId }),
      },
      queryKey: `onedrive-root-folders-${siteId || userId || driveId}`,
      labelField: (item) => item.name,
      valueField: "id",
      dataFilter: (data) => data.filter((item) => item.rawData?.isFolder),
    }),
    [siteId, driveId, userId]
  );

  // Custom columns with icons and clickable folder names
  const columns = useMemo(
    () => [
      {
        id: "name",
        header: "Name",
        accessorKey: "name",
        size: 350,
        Cell: ({ row }) => {
          const item = row.original;
          const { icon, color } = getFileIcon(item.fileExtension, item.isFolder);
          const colorValue =
            color === "action"
              ? theme.palette.action.active
              : theme.palette[color]?.main || theme.palette.primary.main;

          return (
            <Stack
              direction="row"
              alignItems="center"
              spacing={1.5}
              sx={{
                ...(item.isFolder && {
                  cursor: "pointer",
                  "&:hover .folder-name": {
                    color: "primary.main",
                    textDecoration: "underline",
                  },
                }),
              }}
              onClick={
                item.isFolder
                  ? (e) => {
                      e.stopPropagation();
                      navigateToFolder(item.id, item.name);
                    }
                  : undefined
              }
            >
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
                className="folder-name"
                sx={{
                  fontWeight: item.isFolder ? 600 : 400,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {item.name}
              </Typography>
              {item.isFolder && item.childCount != null && (
                <Chip
                  label={`${item.childCount}`}
                  size="small"
                  variant="outlined"
                  sx={{
                    height: 20,
                    fontSize: "0.7rem",
                    "& .MuiChip-label": { px: 0.75 },
                  }}
                />
              )}
            </Stack>
          );
        },
      },
      {
        id: "sizeFormatted",
        header: "Size",
        accessorKey: "sizeFormatted",
        size: 120,
        Cell: ({ row }) => (
          <Typography
            variant="body2"
            color={row.original.isFolder ? "text.secondary" : "text.primary"}
          >
            {row.original.sizeFormatted}
          </Typography>
        ),
      },
      {
        id: "lastModified",
        header: "Modified",
        accessorKey: "lastModified",
        size: 180,
        Cell: ({ row }) => {
          const date = row.original.lastModified;
          if (!date) return null;
          try {
            return (
              <Typography variant="body2" color="text.secondary">
                {new Date(date).toLocaleString(undefined, {
                  month: "short",
                  day: "numeric",
                  year: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                })}
              </Typography>
            );
          } catch {
            return (
              <Typography variant="body2" color="text.secondary">
                {date}
              </Typography>
            );
          }
        },
      },
      {
        id: "createdBy",
        header: "Created By",
        accessorKey: "createdBy",
        size: 160,
      },
      {
        id: "type",
        header: "Type",
        accessorKey: "type",
        size: 80,
        Cell: ({ row }) => {
          const item = row.original;
          if (item.isFolder) {
            return (
              <Chip
                label="Folder"
                size="small"
                color="info"
                variant="outlined"
                sx={{ height: 22, fontSize: "0.7rem" }}
              />
            );
          }
          return (
            <Typography
              variant="body2"
              color="text.secondary"
              sx={{ textTransform: "uppercase", fontSize: "0.75rem" }}
            >
              {item.fileExtension || "File"}
            </Typography>
          );
        },
      },
    ],
    [theme, navigateToFolder]
  );

  // File/folder actions
  const actions = useMemo(
    () => [
      // -- View --
      {
        label: "Open in Browser",
        type: "link",
        icon: <OpenInNew />,
        link: "[webUrl]",
        external: true,
        category: "view",
      },
      {
        label: "Download",
        type: "POST",
        icon: <Download />,
        url: "/api/ExecOneDriveFileAction",
        data: {
          ...driveIdentity,
          ItemId: "id",
          ItemName: "name",
          Action: "!Download",
        },
        confirmText: "Download '[name]'? A download link will be generated.",
        multiPost: false,
        condition: (row) => !row.isFolder,
        category: "view",
        // The backend returns a downloadUrl field - we handle it via the Results toast
        // and the user can open it from there. For a smoother UX we use onComplete below.
      },

      // -- Edit --
      {
        label: "Rename",
        type: "POST",
        icon: <Edit />,
        url: "/api/ExecOneDriveFileAction",
        data: {
          ...driveIdentity,
          ItemId: "id",
          ItemName: "name",
          Action: "!Rename",
        },
        confirmText: "Enter a new name for '[name]'.",
        fields: [
          {
            type: "textField",
            name: "NewName",
            label: "New Name",
            required: true,
          },
        ],
        relatedQueryKeys: [currentQueryKey],
        multiPost: false,
        category: "edit",
      },
      {
        label: "Move to Folder",
        type: "POST",
        icon: <DriveFileMove />,
        url: "/api/ExecOneDriveFileAction",
        data: {
          ...driveIdentity,
          ItemId: "id",
          ItemName: "name",
          Action: "!Move",
        },
        confirmText:
          "Select a destination folder to move '[name]' into. Only top-level folders are shown.",
        fields: [
          {
            type: "autoComplete",
            name: "DestinationFolderId",
            label: "Destination Folder",
            multiple: false,
            creatable: false,
            api: folderPickerApi,
          },
        ],
        relatedQueryKeys: [currentQueryKey],
        multiPost: false,
        category: "manage",
      },
      {
        label: "Copy",
        type: "POST",
        icon: <ContentCopy />,
        url: "/api/ExecOneDriveFileAction",
        data: {
          ...driveIdentity,
          ItemId: "id",
          ItemName: "name",
          Action: "!Copy",
        },
        confirmText:
          "Copy '[name]'. Optionally provide a new name or select a destination folder. Leave both blank to copy in the same location.",
        fields: [
          {
            type: "textField",
            name: "CopyName",
            label: "New Name (optional)",
          },
          {
            type: "autoComplete",
            name: "DestinationFolderId",
            label: "Destination Folder (optional, defaults to same location)",
            multiple: false,
            creatable: false,
            api: folderPickerApi,
          },
        ],
        relatedQueryKeys: [currentQueryKey],
        multiPost: false,
        category: "manage",
      },

      // -- Cross-drive --
      {
        label: "Move to Another Drive",
        icon: <SwapHoriz />,
        customComponent: (row, opts) => CrossDriveTransferDrawer(row, opts, "move", rawDriveIdentity),
        customBulkHandler: ({ data, clearSelection }) => {
          setBulkTransfer({ open: true, items: data, actionType: "move" });
          clearSelection();
        },
        category: "manage",
      },
      {
        label: "Copy to Another Drive",
        icon: <ContentCopy />,
        customComponent: (row, opts) => CrossDriveTransferDrawer(row, opts, "copy", rawDriveIdentity),
        customBulkHandler: ({ data, clearSelection }) => {
          setBulkTransfer({ open: true, items: data, actionType: "copy" });
          clearSelection();
        },
        category: "manage",
      },

      // -- Zip --
      {
        label: "Download as Zip",
        icon: isZipping ? <CircularProgress size={16} /> : <FolderZip />,
        customBulkHandler: ({ data, clearSelection }) => {
          handleBulkZipDownload(data);
          clearSelection();
        },
        condition: (row) => !row.isFolder,
        category: "view",
      },

      // -- Danger --
      {
        label: "Delete",
        type: "POST",
        icon: <Delete />,
        url: "/api/ExecOneDriveFileAction",
        data: {
          ...driveIdentity,
          ItemId: "id",
          ItemName: "name",
          Action: "!Delete",
        },
        confirmText:
          "Are you sure you want to delete '[name]'? It will be moved to the OneDrive recycle bin and can be restored within 93 days.",
        color: "error",
        relatedQueryKeys: [currentQueryKey],
        multiPost: false,
        category: "danger",
      },
    ],
    [driveIdentity, rawDriveIdentity, folderPickerApi, currentQueryKey, isZipping, handleBulkZipDownload]
  );

  const defaultLabel = siteId ? "SharePoint" : "OneDrive";
  const pageTitle = `Files — ${name || defaultLabel}`;

  if (!siteId && !driveId && !userId) {
    return <LocationPickerLanding />;
  }

  return (
    <Box sx={{ display: "flex", flexDirection: "column", height: "100%" }}>
      {/* Breadcrumb Navigation */}
      <Paper
        elevation={0}
        sx={{
          px: 3,
          py: 1.5,
          mb: 0,
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
                  sx={{
                    cursor: "pointer",
                    display: "flex",
                    alignItems: "center",
                    gap: 0.5,
                  }}
                >
                  {i === 0 && <Home fontSize="small" />}
                  {crumb.label}
                </MuiLink>
              );
            })}
          </Breadcrumbs>
          <Tooltip title="Switch OneDrive or SharePoint site">
            <Button
              size="small"
              variant="outlined"
              startIcon={<SwapHoriz />}
              onClick={handleSwitcherOpen}
              sx={{ whiteSpace: "nowrap", flexShrink: 0 }}
            >
              Switch
            </Button>
          </Tooltip>
          <Tooltip title="Compare folders between two locations">
            <Button
              size="small"
              variant="outlined"
              startIcon={<CompareArrows />}
              onClick={() => setCompareOpen(true)}
              sx={{ whiteSpace: "nowrap", flexShrink: 0 }}
            >
              Compare
            </Button>
          </Tooltip>
          <Button
            size="small"
            variant="contained"
            startIcon={<CreateNewFolder />}
            onClick={() => setNewFolderOpen(true)}
            sx={{ whiteSpace: "nowrap", flexShrink: 0 }}
          >
            New Folder
          </Button>
        </Stack>
      </Paper>

      {/* New Folder Dialog */}
      <Dialog open={newFolderOpen} onClose={handleNewFolderClose} fullWidth maxWidth="xs">
        <DialogTitle>
          <Stack direction="row" alignItems="center" spacing={1}>
            <CreateNewFolder color="primary" />
            <span>New Folder</span>
          </Stack>
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Create a new folder in the current directory.
          </Typography>
          <TextField
            autoFocus
            fullWidth
            label="Folder Name"
            value={newFolderName}
            onChange={(e) => setNewFolderName(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && newFolderName.trim()) {
                handleNewFolderSubmit();
              }
            }}
            size="small"
          />
          <CippApiResults apiObject={newFolderMutation} />
        </DialogContent>
        <DialogActions>
          <Button onClick={handleNewFolderClose} color="inherit">
            Close
          </Button>
          <Button
            variant="contained"
            onClick={handleNewFolderSubmit}
            disabled={!newFolderName.trim() || newFolderMutation.isPending}
            startIcon={
              newFolderMutation.isPending ? (
                <CircularProgress size={18} color="inherit" />
              ) : (
                <CreateNewFolder />
              )
            }
          >
            {newFolderMutation.isPending ? "Creating..." : "Create"}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Switch Location Dialog */}
      <Dialog
        open={switcherOpen}
        onClose={() => setSwitcherOpen(false)}
        fullWidth
        maxWidth="xs"
      >
        <DialogTitle>
          <Stack direction="row" alignItems="center" spacing={1}>
            <SwapHoriz color="primary" />
            <span>Switch Location</span>
          </Stack>
        </DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 0.5 }}>
            <ToggleButtonGroup
              value={switcherType}
              exclusive
              onChange={(_e, val) => {
                if (!val) return;
                setSwitcherType(val);
                switcherForm.reset();
              }}
              size="small"
              fullWidth
            >
              <ToggleButton value="onedrive">
                <PersonOutline sx={{ mr: 1 }} /> OneDrive
              </ToggleButton>
              <ToggleButton value="sharepoint">
                <Language sx={{ mr: 1 }} /> SharePoint
              </ToggleButton>
            </ToggleButtonGroup>

            {switcherType === "onedrive" && (
              <CippFormComponent
                type="autoComplete"
                name="switchUser"
                label="Select User"
                formControl={switcherForm}
                multiple={false}
                api={{
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
                  labelField: (user) => `${user.displayName} (${user.userPrincipalName})`,
                  valueField: "id",
                }}
              />
            )}

            {switcherType === "sharepoint" && (
              <CippFormComponent
                type="autoComplete"
                name="switchSite"
                label="Select SharePoint Site"
                formControl={switcherForm}
                multiple={false}
                api={{
                  url: "/api/ListSites",
                  data: { Type: "SharePointSiteUsage" },
                  queryKey: "file-browser-sites",
                  labelField: (s) => s.displayName || s.webUrl || s.siteId,
                  valueField: "siteId",
                }}
              />
            )}
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSwitcherOpen(false)} color="inherit">
            Cancel
          </Button>
          <Button
            variant="contained"
            startIcon={<Search />}
            onClick={switcherForm.handleSubmit(handleSwitchLocation)}
            disabled={
              switcherType === "onedrive"
                ? !switcherForm.watch("switchUser")
                : !switcherForm.watch("switchSite")
            }
          >
            Browse
          </Button>
        </DialogActions>
      </Dialog>

      {/* File Table */}
      <CippTablePage
        title={pageTitle}
        apiUrl="/api/ListOneDriveFiles"
        apiData={apiData}
        actions={actions}
        queryKey={currentQueryKey}
        columns={columns}
        defaultViewMode="table"
        defaultSorting={[
          { id: "type", desc: true },
          { id: "name", desc: false },
        ]}
      />

      {/* Bulk Cross-Drive Transfer Dialog */}
      <CrossDriveTransferDialog
        open={bulkTransfer.open}
        onClose={() => setBulkTransfer({ open: false, items: [], actionType: "move" })}
        items={bulkTransfer.items}
        actionType={bulkTransfer.actionType}
        sourceIdentity={rawDriveIdentity}
      />

      {/* Folder Compare Dialog */}
      <FolderCompareDialog
        open={compareOpen}
        onClose={() => setCompareOpen(false)}
        currentLocation={{ userId, siteId, driveId, folderId, folderPath, name }}
        tenantFilter={tenantFilter}
      />
    </Box>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
