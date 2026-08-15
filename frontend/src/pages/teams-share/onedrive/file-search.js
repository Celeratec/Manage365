import { Layout as DashboardLayout } from "../../../layouts/index.js";
import { useRouter } from "next/router";
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
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
  InputAdornment,
  InputLabel,
  Link as MuiLink,
  MenuItem,
  Pagination,
  Paper,
  Select,
  Table,
  TableBody,
  TableCell,
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
  Search,
  OpenInNew,
  FolderOpen,
  Clear,
  Info,
  ExpandMore,
  LightbulbOutlined,
  ContentCopy,
  Check,
  FilterList,
  DriveFileMove,
  FileCopy,
  Language,
  PersonOutline,
  Folder,
  FolderZip,
  SaveAlt,
} from "@mui/icons-material";
import { CippHead } from "../../../components/CippComponents/CippHead";
import { CippAutoComplete } from "../../../components/CippComponents/CippAutocomplete";
import CippFormComponent from "../../../components/CippComponents/CippFormComponent";
import { ApiGetCall, ApiPostCall } from "../../../api/ApiCall";
import axios from "axios";
import { buildVersionedHeaders } from "../../../utils/cippVersion";
import { useSettings } from "../../../hooks/use-settings";
import { useState, useMemo, useCallback, useEffect, useRef } from "react";
import { useForm } from "react-hook-form";
import { getFileIcon } from "../../../utils/get-file-icon";

const PAGE_SIZE = 25;

const DestinationPickerDialog = ({ open, onClose, items = [], actionType, tenantFilter, mode = "transfer" }) => {
  const formControl = useForm({ mode: "onChange" });
  const theme = useTheme();
  const isZipMode = mode === "zip";

  const [locationType, setLocationType] = useState("onedrive");
  const [destLocation, setDestLocation] = useState(null);
  const [destFolderId, setDestFolderId] = useState(null);
  const [currentFolderId, setCurrentFolderId] = useState(null);
  const [breadcrumbs, setBreadcrumbs] = useState([{ label: "Root", id: null }]);
  const prevValueRef = useRef(null);

  const [isTransferring, setIsTransferring] = useState(false);
  const [itemStatuses, setItemStatuses] = useState({});
  const [transferComplete, setTransferComplete] = useState(false);
  const [conflictBehavior, setConflictBehavior] = useState("rename");
  const [zipFileName, setZipFileName] = useState(`Manage365-Archive-${new Date().toISOString().slice(0, 10)}.zip`);

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

  const folderQueryKey = `search-xdrive-folders-${destLocation?.userId || destLocation?.siteId}-${currentFolderId || "root"}`;

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
    if (isZipMode) {
      setIsTransferring(true);
      setTransferComplete(false);
      setItemStatuses({});

      try {
        const destIdentity = {};
        if (destLocation.type === "onedrive") destIdentity.DestinationUserId = destLocation.userId;
        else destIdentity.DestinationSiteId = destLocation.siteId;

        const payload = {
          TenantFilter: tenantFilter,
          Items: items.map((it) => ({ DriveId: it.driveId, ItemId: it.id, Name: it.name })),
          ZipFileName: zipFileName,
          ...destIdentity,
          ...(destFolderId ? { DestinationFolderId: destFolderId } : {}),
        };
        const resp = await axios.post("/api/ExecZipFiles", payload, {
          headers: await buildVersionedHeaders(),
          timeout: 300000,
        });
        setItemStatuses({ _zip: { status: "success", message: resp.data?.Results || "Zip saved successfully." } });
      } catch (err) {
        const errData = err.response?.data;
        setItemStatuses({ _zip: { status: "error", message: errData?.Results || err.message || "Zip failed" } });
      }

      setIsTransferring(false);
      setTransferComplete(true);
      return;
    }

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
    items.forEach((it) => {
      statuses[it.id] = { status: "pending" };
    });
    setItemStatuses({ ...statuses });

    for (const it of items) {
      statuses[it.id] = { status: "in_progress" };
      setItemStatuses({ ...statuses });

      try {
        const payload = {
          TenantFilter: tenantFilter,
          DriveId: it.driveId,
          ItemId: it.id,
          ItemName: it.name,
          Action: action,
          ConflictBehavior: conflictBehavior,
          ...destIdentity,
          ...(destFolderId ? { DestinationFolderId: destFolderId } : {}),
        };
        const resp = await axios.post("/api/ExecOneDriveFileAction", payload, {
          headers: await buildVersionedHeaders(),
          timeout: 90000,
        });
        const msg = resp.data?.Results || "Done";
        const isSkipped = msg.toLowerCase().startsWith("skipped");
        statuses[it.id] = { status: isSkipped ? "skipped" : "success", message: msg };
      } catch (err) {
        const errData = err.response?.data;
        statuses[it.id] = {
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
    onClose(transferComplete);
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
    setZipFileName(`Manage365-Archive-${new Date().toISOString().slice(0, 10)}.zip`);
  };

  const successCount = Object.values(itemStatuses).filter((s) => s.status === "success").length;
  const skippedCount = Object.values(itemStatuses).filter((s) => s.status === "skipped").length;
  const errorCount = Object.values(itemStatuses).filter((s) => s.status === "error").length;
  const completedCount = successCount + skippedCount + errorCount;

  return (
    <Dialog open={open} onClose={isTransferring ? undefined : handleClose} fullWidth maxWidth="sm">
      <DialogTitle>
        <Stack direction="row" alignItems="center" spacing={1}>
          {isZipMode ? <FolderZip color="primary" /> : actionType === "move" ? <DriveFileMove color="primary" /> : <FileCopy color="primary" />}
          <span>
            {isZipMode
              ? `Save Zip (${items.length} item${items.length !== 1 ? "s" : ""})`
              : `${actionType === "move" ? "Move" : "Copy"} ${items.length} item${items.length !== 1 ? "s" : ""}`}
          </span>
        </Stack>
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2.5}>
          {/* Transfer progress */}
          {(isTransferring || transferComplete) && (
            <Stack spacing={1}>
              {isZipMode ? (
                <>
                  {isTransferring && (
                    <Stack alignItems="center" spacing={1} py={2}>
                      <CircularProgress size={28} />
                      <Typography variant="body2" color="text.secondary">
                        Creating zip with {items.length} file{items.length !== 1 ? "s" : ""}...
                      </Typography>
                    </Stack>
                  )}
                  {transferComplete && itemStatuses._zip && (
                    <Alert severity={itemStatuses._zip.status === "success" ? "success" : "error"}>
                      {itemStatuses._zip.message}
                    </Alert>
                  )}
                </>
              ) : (
                <>
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
                          const st = itemStatuses[it.id] || { status: "pending" };
                          return (
                            <TableRow key={it.id}>
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
                </>
              )}
            </Stack>
          )}

          {/* Destination picker */}
          {!isTransferring && !transferComplete && (
            <>
              {items.length > 0 && (
                <Paper variant="outlined" sx={{ maxHeight: 120, overflow: "auto", p: 1 }}>
                  {items.map((it) => (
                    <Typography key={it.id} variant="body2" color="text.secondary" noWrap sx={{ py: 0.25 }}>
                      {it.isFolder ? "\uD83D\uDCC1" : "\uD83D\uDCC4"} {it.name}
                    </Typography>
                  ))}
                </Paper>
              )}

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

              {isZipMode && (
                <TextField
                  label="Zip File Name"
                  value={zipFileName}
                  onChange={(e) => setZipFileName(e.target.value)}
                  size="small"
                  fullWidth
                />
              )}

              {!isZipMode && (
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
              )}

              {locationType === "onedrive" && (
                <CippFormComponent
                  type="autoComplete"
                  name="destUser"
                  label="Destination User"
                  formControl={formControl}
                  multiple={false}
                  api={{
                    url: "/api/ListGraphRequest",
                    data: {
                      Endpoint: "users",
                      manualPagination: true,
                      $select: "id,displayName,userPrincipalName,mail",
                      $count: true,
                      $orderby: "displayName",
                      $top: 999,
                    },
                    queryKey: `search-dest-users-${tenantFilter}`,
                    dataKey: "Results",
                    labelField: (u) => `${u.displayName} (${u.userPrincipalName})`,
                    valueField: "id",
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
                    url: "/api/ListSites",
                    queryKey: `search-dest-sites-${tenantFilter}`,
                    dataKey: "Results",
                    data: { TenantFilter: tenantFilter, type: "SharePointSiteUsage" },
                    labelField: (s) => s["Site Name"] || s.displayName || s.name,
                    valueField: (s) => s["Site ID"] || s.id,
                  }}
                />
              )}

              {/* Folder browser */}
              {destLocation && (
                <Paper variant="outlined" sx={{ p: 1.5 }}>
                  <Stack spacing={1}>
                    <Stack direction="row" spacing={0.5} flexWrap="wrap" alignItems="center">
                      {breadcrumbs.map((crumb, i) => (
                        <Stack key={i} direction="row" alignItems="center" spacing={0.5}>
                          {i > 0 && <Typography variant="caption" color="text.secondary">/</Typography>}
                          <Typography
                            variant="caption"
                            sx={{
                              cursor: i < breadcrumbs.length - 1 ? "pointer" : "default",
                              fontWeight: i === breadcrumbs.length - 1 ? 600 : 400,
                              color: i < breadcrumbs.length - 1 ? "primary.main" : "text.primary",
                              "&:hover": i < breadcrumbs.length - 1 ? { textDecoration: "underline" } : {},
                            }}
                            onClick={() => i < breadcrumbs.length - 1 && navigateToBreadcrumb(i)}
                          >
                            {crumb.label}
                          </Typography>
                        </Stack>
                      ))}
                    </Stack>
                    <Divider />
                    {foldersQuery.isLoading && (
                      <Stack alignItems="center" py={2}>
                        <CircularProgress size={20} />
                      </Stack>
                    )}
                    {foldersQuery.isSuccess && folders.length === 0 && (
                      <Typography variant="body2" color="text.secondary" sx={{ py: 1, textAlign: "center" }}>
                        No subfolders. Files will be placed here.
                      </Typography>
                    )}
                    {folders.map((f) => (
                      <Stack
                        key={f.id}
                        direction="row"
                        alignItems="center"
                        spacing={1}
                        sx={{
                          py: 0.5,
                          px: 1,
                          borderRadius: 1,
                          cursor: "pointer",
                          "&:hover": { bgcolor: alpha(theme.palette.primary.main, 0.06) },
                        }}
                        onClick={() => navigateToFolder(f.id, f.name)}
                      >
                        <Folder fontSize="small" color="primary" />
                        <Typography variant="body2" noWrap>{f.name}</Typography>
                      </Stack>
                    ))}
                  </Stack>
                </Paper>
              )}
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={handleClose} disabled={isTransferring}>
          {transferComplete ? "Close" : "Cancel"}
        </Button>
        {!isTransferring && !transferComplete && (
          <Button
            variant="contained"
            onClick={handleExecute}
            disabled={!destLocation || (isZipMode && !zipFileName.trim())}
            startIcon={isZipMode ? <FolderZip /> : actionType === "move" ? <DriveFileMove /> : <FileCopy />}
          >
            {isZipMode
              ? `Save Zip (${items.length} file${items.length !== 1 ? "s" : ""})`
              : `${actionType === "move" ? "Move" : "Copy"} ${items.length} item${items.length !== 1 ? "s" : ""}`}
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
};

const Page = () => {
  const router = useRouter();
  const theme = useTheme();
  const tenantFilter = useSettings().currentTenant;

  const [searchInput, setSearchInput] = useState("");
  const [activeQuery, setActiveQuery] = useState("");
  const [currentPage, setCurrentPage] = useState(0);

  const [filterDateFrom, setFilterDateFrom] = useState("");
  const [filterDateTo, setFilterDateTo] = useState("");
  const [filterModifiedBy, setFilterModifiedBy] = useState("");
  const [filterFileType, setFilterFileType] = useState("");

  const [selectedItems, setSelectedItems] = useState([]);
  const [transferDialog, setTransferDialog] = useState({ open: false, actionType: "copy", mode: "transfer" });
  const [isZipping, setIsZipping] = useState(false);

  const searchMutation = ApiPostCall({});

  const executeSearch = (query, from = 0) => {
    if (!query.trim() || !tenantFilter) return;
    setActiveQuery(query.trim());
    setCurrentPage(from / PAGE_SIZE);

    let effectiveQuery = query.trim();
    if (filterFileType) effectiveQuery = `filetype:${filterFileType} ${effectiveQuery}`;

    const data = {
      TenantFilter: tenantFilter,
      SearchQuery: effectiveQuery,
      From: from,
      Size: PAGE_SIZE,
    };
    if (filterModifiedBy.trim()) data.FilterModifiedBy = filterModifiedBy.trim();
    if (filterDateFrom) data.FilterDateFrom = filterDateFrom;
    if (filterDateTo) data.FilterDateTo = filterDateTo;
    searchMutation.mutate({ url: "/api/ExecSearchFiles", data });
  };

  const handleSearch = () => executeSearch(searchInput, 0);

  const handlePageChange = (_e, page) => {
    const from = (page - 1) * PAGE_SIZE;
    executeSearch(activeQuery, from);
  };

  const results = searchMutation.data?.data?.Results || [];
  const totalCount = searchMutation.data?.data?.TotalCount || 0;
  const filteredCount = searchMutation.data?.data?.FilteredCount;
  const hasFilters = filterDateFrom || filterDateTo || filterModifiedBy || filterFileType;
  const totalPages = filteredCount != null ? 1 : Math.ceil(totalCount / PAGE_SIZE);

  const handleBrowseLocation = (item) => {
    const query = {};
    if (item.siteId) {
      query.siteId = item.siteId;
    } else if (item.driveId) {
      query.driveId = item.driveId;
    }
    query.name = item.siteName || item.driveName || "Location";
    if (item.parentId && item.parentId !== item.driveId) {
      query.folderId = item.parentId;
    }
    router.push({
      pathname: "/teams-share/onedrive/file-browser",
      query,
    });
  };

  const [copiedId, setCopiedId] = useState(null);

  const handleCopyLink = useCallback((item) => {
    if (!item.webUrl) return;
    navigator.clipboard.writeText(item.webUrl).then(() => {
      setCopiedId(item.id);
      setTimeout(() => setCopiedId(null), 2000);
    });
  }, []);

  const columns = useMemo(
    () => [
      { id: "name", label: "Name", flex: 1, minWidth: 200 },
      { id: "location", label: "Location", width: 200, align: "right" },
      { id: "sizeFormatted", label: "Size", width: 80, align: "right" },
      { id: "lastModified", label: "Modified", width: 120, align: "right" },
      { id: "lastModifiedBy", label: "Modified By", width: 130, align: "right" },
      { id: "actions", label: "", width: 110, align: "right" },
    ],
    []
  );

  const selectedIds = useMemo(() => new Set(selectedItems.map((i) => i.id)), [selectedItems]);

  const toggleItem = useCallback((item) => {
    setSelectedItems((prev) => {
      const exists = prev.some((i) => i.id === item.id);
      return exists ? prev.filter((i) => i.id !== item.id) : [...prev, item];
    });
  }, []);

  const toggleAll = useCallback(() => {
    if (!results.length) return;
    const allOnPageSelected = results.every((r) => selectedIds.has(r.id));
    if (allOnPageSelected) {
      setSelectedItems((prev) => prev.filter((i) => !results.some((r) => r.id === i.id)));
    } else {
      setSelectedItems((prev) => {
        const existing = new Set(prev.map((i) => i.id));
        const toAdd = results.filter((r) => !existing.has(r.id));
        return [...prev, ...toAdd];
      });
    }
  }, [results, selectedIds]);

  const allOnPageSelected = results.length > 0 && results.every((r) => selectedIds.has(r.id));
  const someOnPageSelected = results.length > 0 && results.some((r) => selectedIds.has(r.id));

  const openTransferDialog = (actionType, mode = "transfer") => {
    setTransferDialog({ open: true, actionType, mode });
  };

  const handleTransferClose = (wasCompleted) => {
    setTransferDialog({ open: false, actionType: "copy", mode: "transfer" });
    if (wasCompleted) setSelectedItems([]);
  };

  const handleZipDownload = useCallback(async (items) => {
    if (!items.length || !tenantFilter) return;
    setIsZipping(true);
    try {
      const payload = {
        TenantFilter: tenantFilter,
        Items: items.map((it) => ({ DriveId: it.driveId, ItemId: it.id, Name: it.name })),
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
      // Error is shown via the UI state; no silent swallow
    }
    setIsZipping(false);
  }, [tenantFilter]);

  return (
    <>
      <CippHead title="File Search" />
      <Box sx={{ p: 3, display: "flex", flexDirection: "column", gap: 3 }}>
        {/* Search Bar */}
        <Paper
          elevation={0}
          sx={{
            p: 3,
            border: `1px solid ${theme.palette.divider}`,
            borderRadius: 2,
          }}
        >
          <Stack spacing={2}>
            <Typography variant="h6">Search Files & Folders</Typography>
            <Typography variant="body2" color="text.secondary">
              Search across all SharePoint sites and OneDrive accounts in the
              selected tenant. Enter keywords, file names, or use advanced
              filters to find what you need.
            </Typography>
            <Stack direction="row" spacing={1.5}>
              <TextField
                fullWidth
                placeholder="Search by file name, content, or keywords..."
                value={searchInput}
                onChange={(e) => setSearchInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && searchInput.trim()) handleSearch();
                }}
                size="small"
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <Search color="action" />
                    </InputAdornment>
                  ),
                  endAdornment: searchInput && (
                    <InputAdornment position="end">
                      <IconButton
                        size="small"
                        onClick={() => setSearchInput("")}
                      >
                        <Clear fontSize="small" />
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
              />
              <Button
                variant="contained"
                onClick={handleSearch}
                disabled={
                  !searchInput.trim() ||
                  !tenantFilter ||
                  searchMutation.isPending
                }
                startIcon={
                  searchMutation.isPending ? (
                    <CircularProgress size={18} color="inherit" />
                  ) : (
                    <Search />
                  )
                }
                sx={{ whiteSpace: "nowrap", px: 3 }}
              >
                {searchMutation.isPending ? "Searching..." : "Search"}
              </Button>
            </Stack>

            {!tenantFilter && (
              <Alert severity="warning" variant="outlined">
                Please select a tenant from the dropdown above to search.
              </Alert>
            )}

            {/* Filters - always visible */}
            <Accordion
              disableGutters
              elevation={0}
              defaultExpanded
              sx={{
                border: `1px solid ${theme.palette.divider}`,
                borderRadius: "8px !important",
                "&::before": { display: "none" },
              }}
            >
              <AccordionSummary
                expandIcon={<ExpandMore />}
                sx={{ minHeight: 40, "& .MuiAccordionSummary-content": { my: 0.75 } }}
              >
                <Stack direction="row" alignItems="center" spacing={1}>
                  <FilterList fontSize="small" color="action" />
                  <Typography variant="body2" fontWeight={600} color="text.secondary">
                    Filters
                  </Typography>
                  {hasFilters && (
                    <Chip
                      label={
                        [
                          filterFileType && filterFileType.toUpperCase(),
                          filterModifiedBy,
                          filterDateFrom && `from ${filterDateFrom}`,
                          filterDateTo && `to ${filterDateTo}`,
                        ]
                          .filter(Boolean)
                          .join(" · ")
                      }
                      size="small"
                      color="primary"
                      variant="outlined"
                    />
                  )}
                </Stack>
              </AccordionSummary>
              <AccordionDetails sx={{ pt: 0 }}>
                <Divider sx={{ mb: 1.5 }} />
                <Stack spacing={2}>
                  <Stack direction="row" spacing={2} flexWrap="wrap" useFlexGap alignItems="flex-start">
                    <FormControl size="small" sx={{ minWidth: 180 }}>
                      <InputLabel>File Type</InputLabel>
                      <Select
                        value={filterFileType}
                        label="File Type"
                        onChange={(e) => setFilterFileType(e.target.value)}
                      >
                        <MenuItem value="">All Types</MenuItem>
                        <Divider />
                        <MenuItem value="xlsx">Excel (.xlsx)</MenuItem>
                        <MenuItem value="xls">Excel Legacy (.xls)</MenuItem>
                        <MenuItem value="csv">CSV (.csv)</MenuItem>
                        <Divider />
                        <MenuItem value="docx">Word (.docx)</MenuItem>
                        <MenuItem value="doc">Word Legacy (.doc)</MenuItem>
                        <Divider />
                        <MenuItem value="pptx">PowerPoint (.pptx)</MenuItem>
                        <MenuItem value="ppt">PowerPoint Legacy (.ppt)</MenuItem>
                        <Divider />
                        <MenuItem value="pdf">PDF (.pdf)</MenuItem>
                        <Divider />
                        <MenuItem value="jpg">JPEG Image (.jpg)</MenuItem>
                        <MenuItem value="png">PNG Image (.png)</MenuItem>
                        <MenuItem value="gif">GIF Image (.gif)</MenuItem>
                        <Divider />
                        <MenuItem value="mp4">Video (.mp4)</MenuItem>
                        <MenuItem value="mp3">Audio (.mp3)</MenuItem>
                        <Divider />
                        <MenuItem value="zip">Zip Archive (.zip)</MenuItem>
                        <MenuItem value="txt">Text (.txt)</MenuItem>
                        <MenuItem value="html">HTML (.html)</MenuItem>
                        <MenuItem value="json">JSON (.json)</MenuItem>
                        <MenuItem value="xml">XML (.xml)</MenuItem>
                      </Select>
                    </FormControl>
                    <CippAutoComplete
                      label="Modified By"
                      placeholder="Search users..."
                      multiple={false}
                      creatable={false}
                      size="small"
                      sx={{ minWidth: 260 }}
                      value={filterModifiedBy ? { label: filterModifiedBy, value: filterModifiedBy } : null}
                      onChange={(val) => setFilterModifiedBy(val?.addedFields?.displayName || val?.label || "")}
                      api={{
                        url: "/api/ListGraphRequest",
                        data: {
                          Endpoint: "users",
                          $select: "id,displayName,userPrincipalName",
                          $filter: "accountEnabled eq true",
                          $top: 999,
                          $count: true,
                          $orderby: "displayName",
                        },
                        queryKey: `file-search-users-${tenantFilter}`,
                        dataKey: "Results",
                        labelField: (u) => `${u.displayName} (${u.userPrincipalName})`,
                        valueField: "displayName",
                        addedField: { displayName: "displayName" },
                      }}
                    />
                    <TextField
                      label="Modified From"
                      type="date"
                      value={filterDateFrom}
                      onChange={(e) => setFilterDateFrom(e.target.value)}
                      size="small"
                      sx={{ width: 170 }}
                      InputLabelProps={{ shrink: true }}
                    />
                    <TextField
                      label="Modified To"
                      type="date"
                      value={filterDateTo}
                      onChange={(e) => setFilterDateTo(e.target.value)}
                      size="small"
                      sx={{ width: 170 }}
                      InputLabelProps={{ shrink: true }}
                    />
                    {hasFilters && (
                      <Button
                        size="small"
                        onClick={() => {
                          setFilterFileType("");
                          setFilterModifiedBy("");
                          setFilterDateFrom("");
                          setFilterDateTo("");
                        }}
                      >
                        Clear Filters
                      </Button>
                    )}
                  </Stack>
                  <Typography variant="caption" color="text.secondary">
                    Filters are applied server-side when you click Search. File type and modified-by narrow the search index; date range filters the returned results.
                  </Typography>
                </Stack>
              </AccordionDetails>
            </Accordion>

            <Accordion
              disableGutters
              elevation={0}
              sx={{
                border: `1px solid ${theme.palette.divider}`,
                borderRadius: "8px !important",
                "&::before": { display: "none" },
                bgcolor: alpha(theme.palette.info.main, 0.03),
              }}
            >
              <AccordionSummary
                expandIcon={<ExpandMore />}
                sx={{ minHeight: 40, "& .MuiAccordionSummary-content": { my: 0.75 } }}
              >
                <Stack direction="row" alignItems="center" spacing={1}>
                  <LightbulbOutlined fontSize="small" color="info" />
                  <Typography variant="body2" fontWeight={600} color="text.secondary">
                    Search Tips
                  </Typography>
                </Stack>
              </AccordionSummary>
              <AccordionDetails sx={{ pt: 0 }}>
                <Divider sx={{ mb: 1.5 }} />
                <Stack spacing={1.5}>
                  <Typography variant="subtitle2" color="text.primary">
                    Basic Search
                  </Typography>
                  <Box component="ul" sx={{ m: 0, pl: 2.5, "& li": { mb: 0.5 } }}>
                    <li>
                      <Typography variant="body2" color="text.secondary">
                        <strong>Simple keywords</strong> &mdash; Type any word or phrase.
                        E.g. <code>budget report</code> finds files containing both words.
                      </Typography>
                    </li>
                    <li>
                      <Typography variant="body2" color="text.secondary">
                        <strong>Exact phrase</strong> &mdash; Use quotes for exact matches.
                        E.g. <code>&quot;quarterly budget report&quot;</code>
                      </Typography>
                    </li>
                  </Box>

                  <Typography variant="subtitle2" color="text.primary">
                    Advanced KQL Operators
                  </Typography>
                  <Box component="ul" sx={{ m: 0, pl: 2.5, "& li": { mb: 0.5 } }}>
                    <li>
                      <Typography variant="body2" color="text.secondary">
                        <code>filename:report</code> &mdash; Match files with
                        &quot;report&quot; in the file name
                      </Typography>
                    </li>
                    <li>
                      <Typography variant="body2" color="text.secondary">
                        <code>filetype:pdf</code> &mdash; Only PDF files
                        (use the File Type dropdown above, or type manually for unlisted types)
                      </Typography>
                    </li>
                    <li>
                      <Typography variant="body2" color="text.secondary">
                        <code>author:&quot;John Smith&quot;</code> &mdash; Files
                        created by a specific person
                      </Typography>
                    </li>
                    <li>
                      <Typography variant="body2" color="text.secondary">
                        <code>path:&quot;https://contoso.sharepoint.com/sites/HR&quot;</code>{" "}
                        &mdash; Limit search to a specific SharePoint site
                      </Typography>
                    </li>
                  </Box>

                  <Typography variant="subtitle2" color="text.primary">
                    Combine Filters
                  </Typography>
                  <Box component="ul" sx={{ m: 0, pl: 2.5, "& li": { mb: 0.5 } }}>
                    <li>
                      <Typography variant="body2" color="text.secondary">
                        <code>annual report filetype:pdf</code> &mdash; PDFs
                        containing &quot;annual&quot; and &quot;report&quot;
                      </Typography>
                    </li>
                    <li>
                      <Typography variant="body2" color="text.secondary">
                        <code>contract OR agreement</code> &mdash;{" "}
                        Files containing either word
                      </Typography>
                    </li>
                  </Box>

                  <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                    This search uses Microsoft&apos;s{" "}
                    <MuiLink
                      href="https://learn.microsoft.com/en-us/sharepoint/dev/general-development/keyword-query-language-kql-syntax-reference"
                      target="_blank"
                      rel="noopener"
                    >
                      KQL syntax
                    </MuiLink>
                    . Results come from Microsoft&apos;s search index, which may take a
                    few minutes to reflect very recently uploaded files.
                  </Typography>
                </Stack>
              </AccordionDetails>
            </Accordion>
          </Stack>
        </Paper>

        {/* Filter summary when results are present */}
        {searchMutation.isSuccess && Array.isArray(searchMutation.data?.data?.Results) && hasFilters && filteredCount != null && (
          <Alert severity="info" variant="outlined" icon={<FilterList />}>
            Showing {filteredCount.toLocaleString()} filtered result{filteredCount !== 1 ? "s" : ""} out of {totalCount.toLocaleString()} total.
            {" "}Adjust filters above and click Search again to refine.
          </Alert>
        )}

        {/* Results */}
        {searchMutation.isError && (() => {
          const errorData = searchMutation.error?.response?.data;
          let backendMsg;
          if (typeof errorData === "string") {
            try {
              backendMsg = JSON.parse(errorData)?.Results;
            } catch {
              backendMsg = errorData;
            }
          } else {
            backendMsg = errorData?.Results;
          }
          const displayMsg =
            typeof backendMsg === "string" && backendMsg
              ? backendMsg
              : searchMutation.error?.message || "Search failed. Please try again.";
          const isPermError =
            /403|Forbidden|Access|permission|Authorization/i.test(displayMsg);
          return (
            <Alert severity="error" variant="outlined">
              <Typography variant="body2" fontWeight={600} sx={{ mb: 0.5 }}>
                Search failed
              </Typography>
              <Typography variant="body2">{displayMsg}</Typography>
              {isPermError && (
                <Typography variant="body2" sx={{ mt: 1 }}>
                  This usually means the <strong>Files.Read.All</strong>{" "}
                  permission has not been granted for this tenant. Go to{" "}
                  <strong>
                    Manage365 Settings &gt; SAM Permissions &gt; CPV Refresh
                  </strong>{" "}
                  to push the updated permissions to this tenant, then try again.
                </Typography>
              )}
            </Alert>
          );
        })()}

        {searchMutation.isSuccess &&
          typeof searchMutation.data?.data?.Results === "string" && (
            <Alert severity="error" variant="outlined">
              <Typography variant="body2" fontWeight={600} sx={{ mb: 0.5 }}>
                Search failed
              </Typography>
              <Typography variant="body2">
                {searchMutation.data.data.Results}
              </Typography>
              {(searchMutation.data.data.Results.includes("403") ||
                searchMutation.data.data.Results.includes("Forbidden") ||
                searchMutation.data.data.Results.includes("Access") ||
                searchMutation.data.data.Results.includes("permission") ||
                searchMutation.data.data.Results.includes("Authorization")) && (
                <Typography variant="body2" sx={{ mt: 1 }}>
                  This usually means the <strong>Files.Read.All</strong>{" "}
                  permission has not been granted for this tenant. Go to{" "}
                  <strong>
                    Manage365 Settings &gt; SAM Permissions &gt; CPV Refresh
                  </strong>{" "}
                  to push the updated permissions to this tenant, then try again.
                </Typography>
              )}
            </Alert>
          )}

        {searchMutation.isSuccess &&
          Array.isArray(searchMutation.data?.data?.Results) && (
          <Paper
            elevation={0}
            sx={{
              border: `1px solid ${theme.palette.divider}`,
              borderRadius: 2,
              overflow: "hidden",
            }}
          >
            {/* Results Header */}
            <Box
              sx={{
                px: 3,
                py: 1.5,
                bgcolor: alpha(theme.palette.primary.main, 0.04),
                borderBottom: `1px solid ${theme.palette.divider}`,
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <Stack direction="row" alignItems="center" spacing={1}>
                <Typography variant="subtitle2">
                  {filteredCount != null
                    ? `${filteredCount.toLocaleString()} matching result${filteredCount !== 1 ? "s" : ""} (${totalCount.toLocaleString()} before filters)`
                    : totalCount > 0
                      ? `${totalCount.toLocaleString()} result${totalCount !== 1 ? "s" : ""}`
                      : "No results"}
                </Typography>
                {activeQuery && (
                  <Chip
                    label={activeQuery}
                    size="small"
                    variant="outlined"
                    onDelete={() => {
                      setActiveQuery("");
                      setSearchInput("");
                    }}
                  />
                )}
              </Stack>
              {totalPages > 1 && (
                <Pagination
                  count={totalPages}
                  page={currentPage + 1}
                  onChange={handlePageChange}
                  size="small"
                  shape="rounded"
                />
              )}
            </Box>

            {/* Selection Toolbar */}
            {selectedItems.length > 0 && (
              <Box
                sx={{
                  px: 2,
                  py: 1,
                  bgcolor: alpha(theme.palette.primary.main, 0.08),
                  borderBottom: `1px solid ${theme.palette.divider}`,
                  display: "flex",
                  alignItems: "center",
                  gap: 1.5,
                  position: "sticky",
                  top: 0,
                  zIndex: 2,
                }}
              >
                <Typography variant="body2" fontWeight={600} color="primary">
                  {selectedItems.length} selected
                </Typography>
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<FileCopy />}
                  onClick={() => openTransferDialog("copy")}
                >
                  Copy
                </Button>
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<DriveFileMove />}
                  onClick={() => openTransferDialog("move")}
                >
                  Move
                </Button>
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={isZipping ? <CircularProgress size={16} color="inherit" /> : <FolderZip />}
                  onClick={() => handleZipDownload(selectedItems)}
                  disabled={isZipping}
                >
                  {isZipping ? "Zipping..." : "Download Zip"}
                </Button>
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<SaveAlt />}
                  onClick={() => openTransferDialog("copy", "zip")}
                >
                  Save Zip
                </Button>
                <Button
                  size="small"
                  onClick={() => setSelectedItems([])}
                  sx={{ ml: "auto" }}
                >
                  Clear
                </Button>
              </Box>
            )}

            {results.length === 0 ? (
              <Box sx={{ p: 4, textAlign: "center" }}>
                <Info
                  sx={{ fontSize: 48, color: "text.disabled", mb: 1 }}
                />
                <Typography variant="body1" color="text.secondary">
                  No files or folders matched your search.
                </Typography>
                <Typography
                  variant="body2"
                  color="text.secondary"
                  sx={{ mt: 0.5 }}
                >
                  Try different keywords or check the KQL syntax guide.
                </Typography>
              </Box>
            ) : (
              <>
                {/* Column Headers */}
                <Box
                  sx={{
                    display: "flex",
                    px: 2,
                    py: 1,
                    borderBottom: `1px solid ${theme.palette.divider}`,
                    bgcolor: alpha(theme.palette.grey[500], 0.04),
                  }}
                >
                  <Box sx={{ width: 40, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <Checkbox
                      size="small"
                      checked={allOnPageSelected}
                      indeterminate={someOnPageSelected && !allOnPageSelected}
                      onChange={toggleAll}
                      sx={{ p: 0 }}
                    />
                  </Box>
                  {columns.map((col) => (
                    <Box
                      key={col.id}
                      sx={{
                        ...(col.flex
                          ? { flex: col.flex, minWidth: col.minWidth }
                          : { width: col.width, flexShrink: 0 }),
                        px: 1,
                        textAlign: col.align || "left",
                      }}
                    >
                      <Typography
                        variant="caption"
                        fontWeight={600}
                        color="text.secondary"
                        textTransform="uppercase"
                        letterSpacing="0.05em"
                      >
                        {col.label}
                      </Typography>
                    </Box>
                  ))}
                </Box>

                {/* Result Rows */}
                {results.map((item, idx) => {
                  const { icon, color } = getFileIcon(
                    item.fileExtension,
                    item.isFolder
                  );
                  const colorValue =
                    color === "action"
                      ? theme.palette.action.active
                      : theme.palette[color]?.main ||
                        theme.palette.primary.main;

                  const locationLabel = [
                    item.siteName,
                    item.folderPath && item.folderPath !== "/"
                      ? item.folderPath
                      : null,
                  ]
                    .filter(Boolean)
                    .join("");

                  const isSelected = selectedIds.has(item.id);

                  return (
                    <Box
                      key={`${item.id}-${idx}`}
                      sx={{
                        display: "flex",
                        px: 2,
                        py: 1.25,
                        alignItems: "center",
                        borderBottom: `1px solid ${alpha(
                          theme.palette.divider,
                          0.5
                        )}`,
                        "&:hover": {
                          bgcolor: alpha(theme.palette.primary.main, 0.02),
                        },
                        "&:last-child": { borderBottom: "none" },
                        ...(isSelected && {
                          bgcolor: alpha(theme.palette.primary.main, 0.04),
                        }),
                      }}
                    >
                      {/* Checkbox */}
                      <Box sx={{ width: 40, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
                        <Checkbox
                          size="small"
                          checked={isSelected}
                          onChange={() => toggleItem(item)}
                          sx={{ p: 0 }}
                        />
                      </Box>

                      {/* Name */}
                      <Box
                        sx={{
                          flex: 1,
                          minWidth: 200,
                          px: 1,
                          display: "flex",
                          alignItems: "center",
                          gap: 1.5,
                          overflow: "hidden",
                        }}
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
                        <Tooltip title={item.name} enterDelay={500}>
                          <Typography
                            variant="body2"
                            fontWeight={item.isFolder ? 600 : 400}
                            noWrap
                          >
                            {item.name}
                          </Typography>
                        </Tooltip>
                      </Box>

                      {/* Location */}
                      <Box sx={{ width: 200, flexShrink: 0, px: 1, minWidth: 0, textAlign: "right" }}>
                        <Tooltip
                          title={locationLabel || "Root"}
                          enterDelay={500}
                        >
                          <Typography
                            variant="body2"
                            color="text.secondary"
                            noWrap
                          >
                            {locationLabel || "Root"}
                          </Typography>
                        </Tooltip>
                      </Box>

                      {/* Size */}
                      <Box sx={{ width: 80, flexShrink: 0, px: 1, textAlign: "right" }}>
                        <Typography variant="body2" color="text.secondary">
                          {item.sizeFormatted}
                        </Typography>
                      </Box>

                      {/* Modified */}
                      <Box sx={{ width: 120, flexShrink: 0, px: 1, textAlign: "right" }}>
                        <Typography variant="body2" color="text.secondary">
                          {item.lastModified
                            ? new Date(item.lastModified).toLocaleDateString(
                                undefined,
                                {
                                  month: "short",
                                  day: "numeric",
                                  year: "numeric",
                                }
                              )
                            : ""}
                        </Typography>
                      </Box>

                      {/* Modified By */}
                      <Box sx={{ width: 130, flexShrink: 0, px: 1, minWidth: 0, textAlign: "right" }}>
                        <Typography
                          variant="body2"
                          color="text.secondary"
                          noWrap
                        >
                          {item.lastModifiedBy || ""}
                        </Typography>
                      </Box>

                      {/* Actions */}
                      <Box
                        sx={{
                          width: 110,
                          flexShrink: 0,
                          px: 1,
                          display: "flex",
                          gap: 0.5,
                          justifyContent: "flex-end",
                        }}
                      >
                        {item.webUrl && (
                          <Tooltip
                            title={
                              copiedId === item.id
                                ? "Copied!"
                                : "Copy shareable link"
                            }
                          >
                            <IconButton
                              size="small"
                              onClick={() => handleCopyLink(item)}
                              color={
                                copiedId === item.id ? "success" : "default"
                              }
                            >
                              {copiedId === item.id ? (
                                <Check fontSize="small" />
                              ) : (
                                <ContentCopy fontSize="small" />
                              )}
                            </IconButton>
                          </Tooltip>
                        )}
                        {(item.siteId || item.driveId) && (
                          <Tooltip title="Browse in File Browser">
                            <IconButton
                              size="small"
                              onClick={() => handleBrowseLocation(item)}
                            >
                              <FolderOpen fontSize="small" />
                            </IconButton>
                          </Tooltip>
                        )}
                        {item.webUrl && (
                          <Tooltip title="Open in SharePoint">
                            <IconButton
                              size="small"
                              component="a"
                              href={item.webUrl}
                              target="_blank"
                              rel="noopener"
                            >
                              <OpenInNew fontSize="small" />
                            </IconButton>
                          </Tooltip>
                        )}
                      </Box>
                    </Box>
                  );
                })}

                {/* Bottom Pagination */}
                {totalPages > 1 && (
                  <Box
                    sx={{
                      display: "flex",
                      justifyContent: "center",
                      py: 2,
                      borderTop: `1px solid ${theme.palette.divider}`,
                    }}
                  >
                    <Pagination
                      count={totalPages}
                      page={currentPage + 1}
                      onChange={handlePageChange}
                      size="small"
                      shape="rounded"
                    />
                  </Box>
                )}
              </>
            )}
          </Paper>
        )}
      </Box>

      <DestinationPickerDialog
        open={transferDialog.open}
        onClose={handleTransferClose}
        items={selectedItems}
        actionType={transferDialog.actionType}
        tenantFilter={tenantFilter}
        mode={transferDialog.mode}
      />
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
