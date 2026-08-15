import {
  Stack,
  Typography,
  Button,
  Box,
  Chip,
  TextField,
  InputAdornment,
  Paper,
  Menu,
  MenuItem,
  Divider,
} from "@mui/material";
import { Search, FilterList, CheckBox, CheckBoxOutlineBlank } from "@mui/icons-material";
import { MaterialReactTable, useMaterialReactTable } from "material-react-table";
import { useState, useMemo, useCallback } from "react";

const typeLabels = {
  officeTemp: "Office Temp",
  tempFiles: "Temp File",
  zeroByteFiles: "Zero Byte",
  systemJunk: "System Junk",
  backupFiles: "Backup",
};

const typeColors = {
  officeTemp: "primary",
  tempFiles: "secondary",
  zeroByteFiles: "warning",
  systemJunk: "info",
  backupFiles: "error",
};

const formatFileSize = (bytes) => {
  if (bytes === 0 || bytes === null || bytes === undefined) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const k = 1024;
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  const size = bytes / Math.pow(k, i);
  return `${size.toFixed(i > 0 ? 1 : 0)} ${units[i]}`;
};

const formatDate = (dateString) => {
  if (!dateString) return "-";
  try {
    return new Date(dateString).toLocaleDateString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return dateString;
  }
};

export const StepSelectFiles = ({ data, onUpdate, onNext, onBack }) => {
  const [search, setSearch] = useState("");
  const [filterMenuAnchor, setFilterMenuAnchor] = useState(null);

  const scanResults = (data.scanResults || []).filter(Boolean);
  const selectedFiles = (data.selectedFiles || []).filter(Boolean);

  const rowSelection = useMemo(() => {
    const selection = {};
    selectedFiles.forEach((file) => {
      selection[file.id] = true;
    });
    return selection;
  }, [selectedFiles]);

  const filteredFiles = useMemo(() => {
    if (!search) return scanResults;
    const searchLower = search.toLowerCase();
    return scanResults.filter(
      (file) =>
        file.name?.toLowerCase().includes(searchLower) ||
        file.path?.toLowerCase().includes(searchLower) ||
        typeLabels[file.type]?.toLowerCase().includes(searchLower)
    );
  }, [scanResults, search]);

  const handleRowSelectionChange = useCallback(
    (updaterOrValue) => {
      const newSelection =
        typeof updaterOrValue === "function" ? updaterOrValue(rowSelection) : updaterOrValue;

      const newSelectedFiles = scanResults.filter((file) => newSelection[file.id]);
      onUpdate({ selectedFiles: newSelectedFiles });
    },
    [scanResults, rowSelection, onUpdate]
  );

  const handleSelectAll = () => {
    onUpdate({ selectedFiles: [...scanResults] });
  };

  const handleSelectNone = () => {
    onUpdate({ selectedFiles: [] });
  };

  const handleSelectByType = (type) => {
    const filesOfType = scanResults.filter((f) => f.type === type);
    const currentIds = new Set(selectedFiles.map((f) => f.id));
    const allOfTypeSelected = filesOfType.every((f) => currentIds.has(f.id));

    let newSelection;
    if (allOfTypeSelected) {
      newSelection = selectedFiles.filter((f) => f.type !== type);
    } else {
      const typeIds = new Set(filesOfType.map((f) => f.id));
      const existingOther = selectedFiles.filter((f) => !typeIds.has(f.id));
      newSelection = [...existingOther, ...filesOfType];
    }
    onUpdate({ selectedFiles: newSelection });
    setFilterMenuAnchor(null);
  };

  const selectedSize = useMemo(
    () => selectedFiles.reduce((sum, f) => sum + (f?.size || 0), 0),
    [selectedFiles]
  );

  const typeCounts = useMemo(() => {
    const counts = {};
    scanResults.forEach((file) => {
      counts[file.type] = (counts[file.type] || 0) + 1;
    });
    return counts;
  }, [scanResults]);

  const selectedTypeCounts = useMemo(() => {
    const counts = {};
    selectedFiles.forEach((file) => {
      counts[file.type] = (counts[file.type] || 0) + 1;
    });
    return counts;
  }, [selectedFiles]);

  const columns = useMemo(
    () => [
      {
        accessorKey: "name",
        header: "Name",
        size: 200,
        Cell: ({ cell }) => (
          <Typography
            variant="body2"
            sx={{ fontFamily: "monospace", wordBreak: "break-word" }}
          >
            {cell.getValue()}
          </Typography>
        ),
      },
      {
        accessorKey: "path",
        header: "Path",
        size: 250,
        Cell: ({ cell }) => (
          <Typography
            variant="body2"
            color="text.secondary"
            sx={{ wordBreak: "break-word" }}
          >
            {cell.getValue() || "/"}
          </Typography>
        ),
      },
      {
        accessorKey: "size",
        header: "Size",
        size: 100,
        Cell: ({ cell }) => formatFileSize(cell.getValue()),
        sortingFn: "basic",
      },
      {
        accessorKey: "type",
        header: "Type",
        size: 120,
        Cell: ({ cell }) => {
          const type = cell.getValue();
          return (
            <Chip
              label={typeLabels[type] || type}
              size="small"
              color={typeColors[type] || "default"}
              variant="outlined"
            />
          );
        },
        filterVariant: "select",
        filterSelectOptions: Object.entries(typeLabels).map(([value, label]) => ({
          value,
          label,
        })),
      },
      {
        accessorKey: "lastModifiedDateTime",
        header: "Modified",
        size: 180,
        Cell: ({ cell }) => formatDate(cell.getValue()),
        sortingFn: "datetime",
      },
    ],
    []
  );

  const table = useMaterialReactTable({
    columns,
    data: filteredFiles,
    enableRowSelection: true,
    enableSelectAll: true,
    getRowId: (row) => row.id,
    onRowSelectionChange: handleRowSelectionChange,
    state: {
      rowSelection,
    },
    enableColumnFilters: true,
    enableGlobalFilter: false,
    enablePagination: true,
    initialState: {
      pagination: { pageSize: 25, pageIndex: 0 },
      density: "compact",
    },
    muiTableContainerProps: {
      sx: { maxHeight: "400px" },
    },
    muiTableBodyRowProps: ({ row }) => ({
      sx: {
        cursor: "pointer",
        "&:hover": { backgroundColor: "action.hover" },
      },
    }),
    enableStickyHeader: true,
    enableTopToolbar: false,
    enableBottomToolbar: true,
    positionToolbarAlertBanner: "none",
  });

  return (
    <Stack spacing={3}>
      <Box>
        <Typography variant="h6">Review and Select Files</Typography>
        <Typography variant="body2" color="text.secondary">
          Uncheck any files you want to keep. All checked files will be deleted.
        </Typography>
      </Box>

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Box sx={{ display: "flex", gap: 2, flexWrap: "wrap", alignItems: "center", mb: 2 }}>
          <TextField
            placeholder="Search files..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            size="small"
            sx={{ minWidth: 250 }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Search fontSize="small" />
                </InputAdornment>
              ),
            }}
          />

          <Box sx={{ display: "flex", gap: 1 }}>
            <Button
              size="small"
              variant="outlined"
              onClick={handleSelectAll}
              startIcon={<CheckBox />}
            >
              Select All
            </Button>
            <Button
              size="small"
              variant="outlined"
              onClick={handleSelectNone}
              startIcon={<CheckBoxOutlineBlank />}
            >
              Select None
            </Button>
            <Button
              size="small"
              variant="outlined"
              onClick={(e) => setFilterMenuAnchor(e.currentTarget)}
              startIcon={<FilterList />}
            >
              By Type
            </Button>
          </Box>

          <Menu
            anchorEl={filterMenuAnchor}
            open={Boolean(filterMenuAnchor)}
            onClose={() => setFilterMenuAnchor(null)}
          >
            {Object.entries(typeLabels).map(([type, label]) => {
              const count = typeCounts[type] || 0;
              const selectedCount = selectedTypeCounts[type] || 0;
              if (count === 0) return null;
              return (
                <MenuItem key={type} onClick={() => handleSelectByType(type)}>
                  <Chip
                    label={label}
                    size="small"
                    color={typeColors[type] || "default"}
                    variant="outlined"
                    sx={{ mr: 1 }}
                  />
                  <Typography variant="body2" color="text.secondary">
                    {selectedCount}/{count} selected
                  </Typography>
                </MenuItem>
              );
            })}
          </Menu>
        </Box>

        <Box sx={{ display: "flex", gap: 2, flexWrap: "wrap", mb: 2 }}>
          {Object.entries(typeCounts).map(([type, count]) => {
            const selectedCount = selectedTypeCounts[type] || 0;
            return (
              <Chip
                key={type}
                label={`${typeLabels[type] || type}: ${selectedCount}/${count}`}
                size="small"
                color={selectedCount === count ? typeColors[type] : "default"}
                variant={selectedCount > 0 ? "filled" : "outlined"}
                onClick={() => handleSelectByType(type)}
                sx={{ cursor: "pointer" }}
              />
            );
          })}
        </Box>

        <Divider sx={{ mb: 2 }} />

        <MaterialReactTable table={table} />
      </Paper>

      <Paper
        variant="outlined"
        sx={{
          p: 2,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          backgroundColor: "action.hover",
        }}
      >
        <Box>
          <Typography variant="body1" fontWeight="medium">
            {selectedFiles.length} of {scanResults.length} files selected
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Total size to delete: {formatFileSize(selectedSize)}
          </Typography>
        </Box>
        {selectedFiles.length > 0 && (
          <Typography variant="body2" color="warning.main">
            These files will be permanently deleted
          </Typography>
        )}
      </Paper>

      <Box sx={{ display: "flex", justifyContent: "space-between", mt: 2 }}>
        <Button onClick={onBack}>Back</Button>
        <Button
          variant="contained"
          color="error"
          onClick={onNext}
          disabled={selectedFiles.length === 0}
        >
          Continue to Confirmation ({selectedFiles.length} files)
        </Button>
      </Box>
    </Stack>
  );
};

export default StepSelectFiles;
