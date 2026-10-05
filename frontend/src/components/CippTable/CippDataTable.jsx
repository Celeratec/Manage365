import { MaterialReactTable, useMaterialReactTable } from "material-react-table";
import {
  Card,
  CardContent,
  CardHeader,
  Divider,
  ListItemIcon,
  ListItemText,
  ListSubheader,
  MenuItem,
  Menu,
  SvgIcon,
  useMediaQuery,
  useTheme,
  Avatar,
  Typography,
  Chip,
  Stack,
  IconButton,
  TextField,
  InputAdornment,
  Skeleton,
  Grid,
  ToggleButton,
  ToggleButtonGroup,
  Tooltip,
  CircularProgress,
  ClickAwayListener,
  Checkbox,
  Button,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { ResourceUnavailable } from "../resource-unavailable";
import { ResourceError } from "../resource-error";
import { Scrollbar } from "../scrollbar";
import { useEffect, useMemo, useState, useCallback, isValidElement, useRef } from "react";
import { useRouter } from "next/router";
import { ApiGetCallWithPagination, ApiPostCall } from "../../api/ApiCall";
import { utilTableMode } from "./util-tablemode";
import { utilColumnsFromAPI, resolveSimpleColumnVariables } from "./util-columnsFromAPI";
import { CIPPTableToptoolbar } from "./CIPPTableToptoolbar";
import {
  Info,
  More,
  MoreHoriz,
  Search,
  CheckCircle,
  Cancel,
  Refresh,
  ViewModule,
  TableChart,
  Email,
  Phone,
  Business,
  CalendarToday,
  Badge,
  Visibility,
  Edit,
  Security,
  Settings,
  Warning,
  Circle,
  CheckBox,
  CheckBoxOutlineBlank,
  IndeterminateCheckBox,
} from "@mui/icons-material";
import { ChevronDownIcon } from "@heroicons/react/24/outline";
import { CippOffCanvas } from "../CippComponents/CippOffCanvas";
import { useDialog } from "../../hooks/use-dialog";
import { CippApiDialog } from "../CippComponents/CippApiDialog";
import { getCippError } from "../../utils/get-cipp-error";
import { CippQuickActions } from "../CippComponents/CippActionMenu";
import { Box } from "@mui/system";
import { useSettings } from "../../hooks/use-settings";
import { parseCippDate } from "../../utils/parse-cipp-date";
import { isEqual } from "lodash";
import { getCippTranslation } from "../../utils/get-cipp-translation";
import CippUserAvatar from "../CippComponents/CippUserAvatar";
import { useLicenseBackfill } from "../../hooks/use-license-backfill";
import { resolvePaletteMainColor } from "../../theme/utils";
import {
  getCategoryColor,
  getCategoryIcon,
  getCategoryLabel,
  sortCategoryEntries,
} from "../../utils/action-categories";
import { useTableViewMode, useIsNarrowForTables } from "../../hooks/use-breakpoint";
import { CippMobileCardList } from "./CippMobileCardList";
import { CippPageActionsFab } from "../CippComponents/CippPageActionsFab";
import CippDataTableButton from "./CippDataTableButton";
import { CippTableCardButton } from "./CippTableCardButton";
import {
  subTableIsSelected,
  subTableShowsCachedColumn,
  resolveSubTableSimpleColumns,
  getSubTableDisplayColumnIds,
  columnOrderHasStaleIds,
} from "./util-subTables";
import { attachParentRow, getRowTenant } from "../../utils/resolve-row-templates";

// Helper functions for row action category grouping and styling
// Resolve dot-delimited property paths against arbitrary data objects.
const getNestedValue = (source, path) => {
  if (!source) {
    return undefined;
  }
  if (!path) {
    return source;
  }

  return path.split(".").reduce((acc, key) => {
    if (acc === undefined || acc === null) {
      return undefined;
    }
    if (typeof acc !== "object") {
      return undefined;
    }
    return acc[key];
  }, source);
};

// Recursively test whether any string/number leaf within a value contains the
// (already lower-cased) search term. Traverses nested objects and arrays so card
// view search matches nested fields (e.g. manager.displayName) and array entries
// (e.g. proxyAddresses), matching the breadth of the table's global filter.
// Depth-capped and cycle-guarded to keep large rows performant and safe.
const valueContainsTerm = (value, term, depth = 0, seen = null) => {
  if (value === null || value === undefined) {
    return false;
  }
  const type = typeof value;
  if (type === "string") {
    return value.toLowerCase().includes(term);
  }
  if (type === "number" || type === "boolean") {
    return String(value).toLowerCase().includes(term);
  }
  if (type !== "object" || depth > 4) {
    return false;
  }
  const visited = seen || new Set();
  if (visited.has(value)) {
    return false;
  }
  visited.add(value);
  if (Array.isArray(value)) {
    return value.some((entry) => valueContainsTerm(entry, term, depth + 1, visited));
  }
  return Object.values(value).some((entry) => valueContainsTerm(entry, term, depth + 1, visited));
};

// Resolve dot-delimited column ids against the original row data so nested fields can sort/filter properly.
const getRowValueByColumnId = (row, columnId) => {
  if (!row?.original || !columnId) {
    return undefined;
  }

  if (columnId.includes("@odata")) {
    return row.original[columnId];
  }

  return getNestedValue(row.original, columnId);
};

const compareNullable = (aVal, bVal) => {
  if (aVal === null && bVal === null) {
    return 0;
  }
  if (aVal === null) {
    return 1;
  }
  if (bVal === null) {
    return -1;
  }
  if (aVal === bVal) {
    return 0;
  }
  return aVal > bVal ? 1 : -1;
};

// walk up from the card surface to the page's scrolling ancestor (LayoutContainer,
// overflowY auto) and align the surface with its top. the table flips in at the same
// page slot, so the height measurement taken right after reads a deterministic top
// and pages with content above the table keep the table in view
const scrollNodeToScrollableAncestorTop = (node) => {
  if (!node) {
    return;
  }
  let ancestor = node.parentElement;
  while (ancestor && ancestor !== document.body) {
    const overflowY = window.getComputedStyle(ancestor).overflowY;
    if (overflowY === "auto" || overflowY === "scroll") {
      ancestor.scrollTop += node.getBoundingClientRect().top - ancestor.getBoundingClientRect().top;
      return;
    }
    ancestor = ancestor.parentElement;
  }
  window.scrollTo(0, window.scrollY + node.getBoundingClientRect().top);
};

/**
 * Column order for a user-curated selection: the selected ids first, in selection order,
 * then everything else in its existing order. Exported for tests.
 *
 * MRT only reads initialState.columnOrder once, so when the graph filter swaps in a new
 * $select list after mount, the new columns (dot-delimited nested fields included) were
 * appended last — and the card view's three detail slots are filled in column order, so a
 * field the user explicitly selected was exactly the one that overflowed into "+N more".
 */
export const orderColumnsBySelection = (allIds, selectedIds) => {
  const selected = selectedIds.filter((id) => allIds.includes(id));
  const rest = allIds.filter((id) => !selected.includes(id));
  return [...selected, ...rest];
};

// ── Module-level constants ──────────────────────────────────────────────────
// These never change between renders, so extracting them avoids creating new
// object references on every render cycle.

// Stable ref so an undefined `data` prop doesn't create a fresh [] each render
// and loop the static-data sync effect.
const EMPTY_ARRAY = [];

// Stable MRT helpers — module-level to avoid new object refs each render.
const buildSubTableColumn = (sub) => ({
  id: sub.id,
  header: sub.header ?? sub.id,
  size: sub.size ?? 120,
  minSize: sub.minSize ?? 100,
  enableSorting: false,
  enableColumnFilter: false,
  enableGlobalFilter: false,
  accessorFn: (row) => {
    if (typeof sub.label === "function") {
      return sub.label(row);
    }
    return sub.label ?? "View";
  },
  Cell: ({ row }) => (
    <CippDataTableButton
      row={row.original}
      label={sub.label}
      condition={sub.condition}
      tableTitle={sub.header}
      {...(sub.table ?? {})}
    />
  ),
});

const SORTING_FNS = {
  dateTimeNullsLast: (a, b, id) => {
    const aRaw = getRowValueByColumnId(a, id);
    const bRaw = getRowValueByColumnId(b, id);
    const aDate = aRaw ? parseCippDate(aRaw) : null;
    const bDate = bRaw ? parseCippDate(bRaw) : null;
    const aTime = aDate && !Number.isNaN(aDate.getTime()) ? aDate.getTime() : null;
    const bTime = bDate && !Number.isNaN(bDate.getTime()) ? bDate.getTime() : null;

    return compareNullable(aTime, bTime);
  },
  number: (a, b, id) => {
    const aRaw = getRowValueByColumnId(a, id);
    const bRaw = getRowValueByColumnId(b, id);
    const aNum = typeof aRaw === "number" ? aRaw : Number(aRaw);
    const bNum = typeof bRaw === "number" ? bRaw : Number(bRaw);
    const aVal = Number.isNaN(aNum) ? null : aNum;
    const bVal = Number.isNaN(bNum) ? null : bNum;

    return compareNullable(aVal, bVal);
  },
  boolean: (a, b, id) => {
    const aRaw = getRowValueByColumnId(a, id);
    const bRaw = getRowValueByColumnId(b, id);
    const toBool = (value) => {
      if (value === null || value === undefined) {
        return null;
      }
      if (typeof value === "boolean") {
        return value;
      }
      if (typeof value === "string") {
        const lower = value.toLowerCase();
        if (lower === "true" || lower === "yes") {
          return true;
        }
        if (lower === "false" || lower === "no") {
          return false;
        }
      }
      if (typeof value === "number") {
        return value !== 0;
      }
      return null;
    };

    const aBool = toBool(aRaw);
    const bBool = toBool(bRaw);
    const aNumeric = aBool === null ? null : aBool ? 1 : 0;
    const bNumeric = bBool === null ? null : bBool ? 1 : 0;

    return compareNullable(aNumeric, bNumeric);
  },
};

const FILTER_FNS = {
  notContains: (row, columnId, value) => {
    const rowValue = row.getValue(columnId);
    if (rowValue === null || rowValue === undefined) {
      return false;
    }

    const stringValue = String(rowValue);
    if (
      stringValue.includes("[object Object]") ||
      !stringValue.toLowerCase().includes(value.toLowerCase())
    ) {
      return true;
    }
    return false;
  },
  regex: (row, columnId, value) => {
    try {
      const regex = new RegExp(value, "i");
      const rowValue = row.getValue(columnId);
      if (typeof rowValue === "string" && !rowValue.includes("[object Object]")) {
        return regex.test(rowValue);
      }
      return false;
    } catch {
      return true;
    }
  },
};

const computeSchemaKey = (data) => {
  if (!Array.isArray(data) || data.length === 0) {
    return "";
  }
  const sample = data.slice(0, 3);
  const keys = new Set();
  for (const row of sample) {
    if (row && typeof row === "object") {
      for (const key of Object.keys(row)) {
        keys.add(key);
      }
    }
  }
  return `${[...keys].sort().join(",")}|${data.length}`;
};

const getColumnKey = (col) => col?.id ?? col?.accessorKey;

// Get initials from a name string
const getInitials = (name) => {
  if (!name || typeof name !== "string") return "?";
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) {
    return parts[0].charAt(0).toUpperCase();
  }
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
};

// Generate a consistent color from a string
const stringToColor = (string) => {
  if (!string) return "#757575";
  let hash = 0;
  for (let i = 0; i < string.length; i++) {
    hash = string.charCodeAt(i) + ((hash << 5) - hash);
  }
  const colors = [
    "#1976d2", "#388e3c", "#d32f2f", "#7b1fa2", "#c2185b",
    "#0288d1", "#00796b", "#f57c00", "#5d4037", "#455a64",
  ];
  return colors[Math.abs(hash) % colors.length];
};

// Default cards per page for pagination
const DEFAULT_CARDS_PER_PAGE = 12;
const PAGE_SIZE_OPTIONS = [12, 21, 50, "All"];

// Unified Card View Component (works for both mobile and desktop)
const CardView = ({
  data,
  config,
  isLoading,
  searchTerm,
  searchInput,
  onSearchChange,
  onRefresh,
  title,
  isMobile = false,
  actions = [],
  tenant = null,
  showSearch = true,
  offCanvas = null,
  setOffCanvasData = null,
  setOffCanvasRowIndex = null,
  setOffcanvasVisible = null,
  onCardClick = null,
  editApiUrl = null,
  queryKey = null,
  columnFilters = [],
  // Lazy loading props for server-side pagination
  hasNextPage = false,
  onLoadMore = null,
  isFetchingNextPage = false,
}) => {
  const theme = useTheme();
  const router = useRouter();
  
  // Pagination state
  const [currentPage, setCurrentPage] = useState(0);
  const [pageSize, setPageSize] = useState(DEFAULT_CARDS_PER_PAGE);
  
  // Selection state for bulk actions
  const [selectedItems, setSelectedItems] = useState(new Set());
  const [bulkActionAnchor, setBulkActionAnchor] = useState(null);
  
  // Inline editing state: { itemId: { fieldName: { editing: bool, value: string, saving: bool } } }
  const [editingFields, setEditingFields] = useState({});
  const editInputRef = useRef(null);
  
  // State for emptyAction dialog (e.g., manager picker)
  const [emptyActionData, setEmptyActionData] = useState({ item: null, action: null, ready: false });
  const emptyActionDialog = useDialog();
  
  // State for bulk action dialog
  const [bulkActionData, setBulkActionData] = useState({ data: [], action: null, ready: false });
  const bulkActionDialog = useDialog();
  
  // API mutation for inline edits
  const editMutation = ApiPostCall({
    relatedQueryKeys: queryKey ? [queryKey] : [],
  });

  // Selection helpers for bulk actions - basic helpers that don't depend on paginatedData
  const getItemId = useCallback((item) => item.id || item.userPrincipalName || item.RowKey || JSON.stringify(item), []);
  
  const toggleItemSelection = useCallback((item) => {
    const itemId = getItemId(item);
    setSelectedItems(prev => {
      const newSet = new Set(prev);
      if (newSet.has(itemId)) {
        newSet.delete(itemId);
      } else {
        newSet.add(itemId);
      }
      return newSet;
    });
  }, [getItemId]);
  
  const clearSelection = useCallback(() => {
    setSelectedItems(new Set());
  }, []);
  
  const isItemSelected = useCallback((item) => {
    return selectedItems.has(getItemId(item));
  }, [selectedItems, getItemId]);
  
  // Get bulk actions (actions that support bulk operations)
  const bulkActions = useMemo(() => {
    return actions?.filter((action) => !action.link && !action?.hideBulk) || [];
  }, [actions]);
  
  // Get selected items data
  const selectedItemsData = useMemo(() => {
    if (!data || selectedItems.size === 0) return [];
    return data.filter(item => selectedItems.has(getItemId(item)));
  }, [data, selectedItems, getItemId]);

  const formatFieldValue = (value) => {
    if (value === null || value === undefined) return "";
    if (Array.isArray(value)) {
      return value.length ? value.join(", ") : "";
    }
    if (typeof value === "object") {
      if (value.displayName) return String(value.displayName);
      if (value.name) return String(value.name);
      return JSON.stringify(value);
    }
    return String(value);
  };

  const getPrimaryFieldValue = (value) => String(value).split(/[;,]/)[0]?.trim();

  const getFieldHref = (field, value) => {
    if (!value) return null;
    if (typeof field?.href === "function") {
      return field.href(value);
    }
    if (field?.linkType === "email") {
      return `mailto:${getPrimaryFieldValue(value)}`;
    }
    if (field?.linkType === "tel") {
      return `tel:${getPrimaryFieldValue(value).replace(/[^+\d]/g, "")}`;
    }
    return null;
  };

  // Inline editing helpers
  const startEditing = (itemId, fieldName, currentValue) => {
    setEditingFields(prev => ({
      ...prev,
      [itemId]: {
        ...prev[itemId],
        [fieldName]: { editing: true, value: currentValue || "", saving: false }
      }
    }));
    // Focus the input after state update
    setTimeout(() => editInputRef.current?.focus(), 50);
  };

  const cancelEditing = (itemId, fieldName) => {
    // Prevent prototype pollution by validating keys
    const dangerousKeys = ['__proto__', 'constructor', 'prototype'];
    if (dangerousKeys.includes(itemId) || dangerousKeys.includes(fieldName)) {
      return;
    }
    setEditingFields(prev => {
      const newState = { ...prev };
      if (Object.hasOwn(newState, itemId) && newState[itemId]) {
        delete newState[itemId][fieldName];
        if (Object.keys(newState[itemId]).length === 0) {
          delete newState[itemId];
        }
      }
      return newState;
    });
  };

  const updateEditValue = (itemId, fieldName, value) => {
    setEditingFields(prev => ({
      ...prev,
      [itemId]: {
        ...prev[itemId],
        [fieldName]: { ...prev[itemId]?.[fieldName], value }
      }
    }));
  };

  const saveEdit = async (item, field, newValue) => {
    const itemId = item.id || item.userPrincipalName;
    const fieldName = field.editField || field.field;
    
    if (!editApiUrl || !fieldName) {
      cancelEditing(itemId, fieldName);
      return;
    }

    // Mark as saving
    setEditingFields(prev => ({
      ...prev,
      [itemId]: {
        ...prev[itemId],
        [fieldName]: { ...prev[itemId]?.[fieldName], saving: true }
      }
    }));

    try {
      // Handle array fields (like businessPhones) - wrap single value in array
      let valueToSave = newValue;
      const originalValue = getNestedValue(item, field.field || fieldName);
      if (Array.isArray(originalValue) || fieldName === "businessPhones") {
        valueToSave = newValue ? [newValue] : [];
      }

      await editMutation.mutateAsync({
        url: editApiUrl,
        data: {
          tenantFilter: tenant,
          id: item.id,
          userPrincipalName: item.userPrincipalName,
          [fieldName]: valueToSave,
        },
      });
      // Update the item in local state (data is from parent, so this update is optimistic display only)
      // The queryKey invalidation in ApiPostCall should refresh the data
    } catch (error) {
      console.error("Failed to save edit:", error);
    } finally {
      cancelEditing(itemId, fieldName);
    }
  };

  const getEditState = (itemId, fieldName) => {
    return editingFields[itemId]?.[fieldName] || { editing: false, value: "", saving: false };
  };

  const CARD_HEIGHT = "100%";
  // Max card width sized to fit 8 quick-action icon buttons in a single row
  // Calculation: 8 buttons × 34px + 7 gaps × 6px + 32px padding + 5px borders ≈ 351px → 360px
  const CARD_MAX_WIDTH = 360;

  // Render badge based on config
  const renderBadge = (badge, item, badgeIndex, isCompact = false, router = null) => {
    let fieldValue = getNestedValue(item, badge.field);
    
    // Apply transform function if provided
    if (badge.transform && typeof badge.transform === "function") {
      fieldValue = badge.transform(fieldValue, item);
    }
    
    let badgeConfig = null;

    if (badge.conditions) {
      const key =
        fieldValue === true
          ? "true"
          : fieldValue === false
          ? "false"
          : String(fieldValue);
      badgeConfig = badge.conditions[key] || badge.conditions[fieldValue];
    }

    if (!badgeConfig) return null;

    // Helper to resolve link template with item data
    const resolveLink = (linkTemplate) => {
      if (!linkTemplate) return null;
      return linkTemplate.replace(/\[(\w+)\]/g, (match, key) => {
        return item[key] || "";
      });
    };

    // Get the link if badge has one and condition is met
    const badgeLink = badge.link ? resolveLink(badge.link) : null;
    const isClickable = !!badgeLink && router;

    // Wrapper for clickable badges
    const wrapWithClick = (element) => {
      if (!isClickable) return element;
      return (
        <Box
          key={badgeIndex}
          onClick={(e) => {
            e.stopPropagation();
            router.push(badgeLink);
          }}
          sx={{ 
            cursor: "pointer",
            display: "inline-flex",
            alignItems: "center",
            "&:hover": { opacity: 0.8 },
          }}
        >
          {element}
        </Box>
      );
    };

    if (badge.iconOnly && badgeConfig.icon && isValidElement(badgeConfig.icon)) {
      // Prefer condition-specific tooltip/label over generic badge tooltip
      const tooltipText = badgeConfig.tooltip || badgeConfig.label || badge.tooltip || getCippTranslation(badge.field);
      const color =
        badgeConfig.color === "success"
          ? "success.main"
          : badgeConfig.color === "error"
          ? "error.main"
          : badgeConfig.color === "warning"
          ? "warning.main"
          : badgeConfig.color === "info"
          ? "info.main"
          : badgeConfig.color === "primary"
          ? "primary.main"
          : badgeConfig.color === "secondary"
          ? "secondary.main"
          : "text.secondary";
      
      const badgeElement = (
        <Tooltip title={isClickable ? `${tooltipText} (Click to open)` : tooltipText}>
          <Box sx={{ display: "inline-flex", alignItems: "center" }}>
            <SvgIcon sx={{ fontSize: isCompact ? 18 : 20, color }}>
              {badgeConfig.icon}
            </SvgIcon>
          </Box>
        </Tooltip>
      );
      return wrapWithClick(badgeElement);
    }

    if (badgeConfig.icon === "check") {
      // Prefer condition-specific tooltip/label over generic badge tooltip
      const tooltipText = badgeConfig.tooltip || badgeConfig.label || badge.tooltip || getCippTranslation(badge.field);
      const badgeElement = (
        <Tooltip title={tooltipText}>
          <CheckCircle
            sx={{
              fontSize: isCompact ? 20 : 22,
              color: badgeConfig.color === "success" ? "success.main" : 
                     badgeConfig.color === "error" ? "error.main" : "text.secondary",
            }}
          />
        </Tooltip>
      );
      return wrapWithClick(badgeElement);
    } else if (badgeConfig.icon === "cancel") {
      // Prefer condition-specific tooltip/label over generic badge tooltip
      const tooltipText = badgeConfig.tooltip || badgeConfig.label || badge.tooltip || getCippTranslation(badge.field);
      const badgeElement = (
        <Tooltip title={tooltipText}>
          <Cancel
            sx={{
              fontSize: isCompact ? 20 : 22,
              color: badgeConfig.color === "error" ? "error.main" : 
                     badgeConfig.color === "warning" ? "warning.main" : "text.secondary",
            }}
          />
        </Tooltip>
      );
      return wrapWithClick(badgeElement);
    }

    const badgeElement = (
      <Chip
        label={badgeConfig.label}
        icon={
          badgeConfig.icon && isValidElement(badgeConfig.icon) ? badgeConfig.icon : undefined
        }
        size="small"
        color={badgeConfig.color || "default"}
        sx={{ 
          height: isCompact ? 22 : 24, 
          fontSize: isCompact ? "0.7rem" : "0.75rem",
          cursor: isClickable ? "pointer" : "default",
        }}
      />
    );
    return wrapWithClick(badgeElement);
  };

  // Filter and sort data based on search term, column filters, and custom sorting
  const filteredData = useMemo(() => {
    let result = data;
    
    // Apply column filters first
    if (columnFilters && columnFilters.length > 0 && result) {
      result = result.filter((item) => {
        // Each active filter must match
        return columnFilters.every((filter) => {
          // Handle filters that have nested value array (from filter definitions)
          // e.g., { filterName: "...", value: [{ id: "field", value: "val" }] }
          if (filter.value && Array.isArray(filter.value) && filter.value[0]?.id) {
            return filter.value.every((condition) => {
              const fieldValue = getNestedValue(item, condition.id);
              // Handle special cases for different field types
              if (condition.id === "assignedLicenses") {
                const hasLicenses = Array.isArray(fieldValue) && fieldValue.length > 0;
                return condition.value === "licensed" ? hasLicenses : !hasLicenses;
              }
              if (condition.id === "accountEnabled") {
                const isEnabled = fieldValue === true || fieldValue === "Yes";
                return condition.value === "Yes" ? isEnabled : !isEnabled;
              }
              // Default string comparison
              return String(fieldValue).toLowerCase() === String(condition.value).toLowerCase();
            });
          }
          // Handle simple {id, value} format (from MRT state)
          if (filter.id) {
            const fieldValue = getNestedValue(item, filter.id);
            // Handle special cases
            if (filter.id === "assignedLicenses") {
              const hasLicenses = Array.isArray(fieldValue) && fieldValue.length > 0;
              return filter.value === "licensed" ? hasLicenses : !hasLicenses;
            }
            if (filter.id === "accountEnabled") {
              const isEnabled = fieldValue === true || fieldValue === "Yes";
              return filter.value === "Yes" ? isEnabled : !isEnabled;
            }
            // Default: check if value matches or contains
            if (Array.isArray(filter.value)) {
              return filter.value.some(v => 
                String(fieldValue).toLowerCase().includes(String(v).toLowerCase())
              );
            }
            return String(fieldValue).toLowerCase().includes(String(filter.value).toLowerCase());
          }
          return true;
        });
      });
    }
    
    // Apply search filter - search across all relevant fields
    if (searchTerm && result) {
      const term = searchTerm.toLowerCase();
      result = result.filter((item) => {
        const titleValue = getNestedValue(item, config.title);
        const subtitleValue = config.subtitle ? getNestedValue(item, config.subtitle) : null;
        
        // Deep-search every field (including nested objects and arrays) so matches
        // aren't limited to top-level string/number values.
        const searchAllFields = () => valueContainsTerm(item, term);

        return (
          (titleValue && formatFieldValue(titleValue).toLowerCase().includes(term)) ||
          (subtitleValue && formatFieldValue(subtitleValue).toLowerCase().includes(term)) ||
          searchAllFields()
        );
      });
    }
    
    // Apply custom sorting if provided
    if (config.sortFn && result) {
      result = [...result].sort(config.sortFn);
    }
    
    return result;
  }, [data, searchTerm, config, columnFilters]);

  // Reset to first page when search term or filters change (user-initiated actions).
  // We intentionally exclude data?.length because:
  // 1. Pagination loading more items increases length but shouldn't reset to page 0
  // 2. Data reference changes are handled by the isEqual check in parent component
  useEffect(() => {
    setCurrentPage(0);
  }, [searchTerm, columnFilters]);
  
  // Clear selection when data changes (e.g., tenant switch, filter change)
  useEffect(() => {
    setSelectedItems(new Set());
  }, [data]);

  // Calculate pagination values
  const totalItems = filteredData?.length || 0;
  const effectivePageSize = pageSize === "All" ? totalItems : pageSize;
  const totalPages = effectivePageSize > 0 ? Math.ceil(totalItems / effectivePageSize) : 1;
  const startIndex = currentPage * effectivePageSize;
  const endIndex = pageSize === "All" ? totalItems : Math.min(startIndex + effectivePageSize, totalItems);
  
  // Get paginated data - only render cards for the current page (or all if "All" selected)
  const paginatedData = useMemo(() => {
    if (!filteredData) return [];
    if (pageSize === "All") return filteredData;
    return filteredData.slice(startIndex, endIndex);
  }, [filteredData, startIndex, endIndex, pageSize]);

  // Selection helpers that depend on paginatedData
  const selectAllVisible = useCallback(() => {
    if (!paginatedData) return;
    const newSet = new Set(selectedItems);
    paginatedData.forEach(item => newSet.add(getItemId(item)));
    setSelectedItems(newSet);
  }, [paginatedData, getItemId, selectedItems]);
  
  const allVisibleSelected = useMemo(() => {
    if (!paginatedData || paginatedData.length === 0) return false;
    return paginatedData.every(item => selectedItems.has(getItemId(item)));
  }, [paginatedData, selectedItems, getItemId]);
  
  // Handle bulk action click
  const handleBulkAction = useCallback((action) => {
    setBulkActionAnchor(null);
    
    if (typeof action.customBulkHandler === "function") {
      action.customBulkHandler({
        rows: selectedItemsData.map(item => ({ original: item })),
        data: selectedItemsData,
        closeMenu: () => setBulkActionAnchor(null),
        clearSelection: clearSelection,
      });
      return;
    }
    
    setBulkActionData({
      data: selectedItemsData,
      action: action,
      ready: true,
    });
    
    if (action?.noConfirm && action.customFunction) {
      selectedItemsData.forEach(item => action.customFunction(item, action, {}));
    } else {
      bulkActionDialog.handleOpen();
    }
  }, [selectedItemsData, clearSelection, bulkActionDialog]);

  // Pagination handlers with lazy loading support
  const handlePreviousPage = useCallback(() => {
    setCurrentPage((prev) => Math.max(0, prev - 1));
  }, []);

  const handleNextPage = useCallback(() => {
    const nextPage = currentPage + 1;
    const nextPageStartIndex = nextPage * effectivePageSize;
    
    // Check if we need to load more data for the next page
    if (nextPageStartIndex >= totalItems && hasNextPage && onLoadMore && !isFetchingNextPage) {
      // We need more data - fetch it, but also advance the page
      // The new data will be available after the fetch completes
      onLoadMore();
    }
    
    // Allow navigation if we have data for the next page OR if we're fetching more
    if (nextPage < totalPages || hasNextPage) {
      setCurrentPage(nextPage);
    }
  }, [currentPage, effectivePageSize, totalItems, hasNextPage, onLoadMore, isFetchingNextPage, totalPages]);

  const handlePageChange = useCallback((newPage) => {
    const targetStartIndex = newPage * effectivePageSize;
    
    // Check if we need to load more data for the target page
    if (targetStartIndex >= totalItems && hasNextPage && onLoadMore && !isFetchingNextPage) {
      onLoadMore();
    }
    
    // Allow navigation if we have the data or are fetching
    if (newPage < totalPages || (hasNextPage && newPage === totalPages)) {
      setCurrentPage(Math.max(0, newPage));
    } else {
      setCurrentPage(Math.max(0, Math.min(totalPages - 1, newPage)));
    }
  }, [effectivePageSize, totalItems, hasNextPage, onLoadMore, isFetchingNextPage, totalPages]);

  const handlePageSizeChange = useCallback((newSize) => {
    setPageSize(newSize);
    setCurrentPage(0); // Reset to first page when changing page size
  }, []);

  // Filter actions for mobile - use mobileQuickActions if defined, otherwise first 4
  const cardActions = useMemo(() => {
    if (!actions || actions.length === 0) return [];
    
    if (isMobile && config.mobileQuickActions) {
      // Filter to only mobile-specific actions
      return actions.filter(a => 
        config.mobileQuickActions.includes(a.label) && 
        (!a.condition || a.condition)
      );
    }
    
    return actions;
  }, [actions, isMobile, config.mobileQuickActions]);

  const renderedCards = useMemo(() => {
    return paginatedData?.map((item, index) => {
      const titleValue = getNestedValue(item, config.title) || "Unknown";
      const subtitleValue = config.subtitle ? getNestedValue(item, config.subtitle) : null;
      const avatarField = config.avatar?.field
        ? getNestedValue(item, config.avatar.field)
        : titleValue;

      // Get fields to display
      const desktopFields = !isMobile && config.desktopFields ? config.desktopFields : [];
      const extraFields = config.extraFields || [];
      
      // Check license status for visual indicator
      const isLicensed = item.assignedLicenses && item.assignedLicenses.length > 0;

      const gridProps = {
        xs: 12,
        sm: isMobile ? 12 : 6,
        md: 4,
        lg: 3,
        ...(config.cardGridProps || {}),
      };

      // Get dynamic card styles if cardSx function is provided
      const dynamicCardSx = typeof config.cardSx === "function" ? config.cardSx(item) : {};

      return (
        <Grid
          item
          xs={gridProps.xs}
          sm={gridProps.sm}
          md={gridProps.md}
          lg={gridProps.lg}
          key={item.id || item.RowKey || index}
          sx={{ 
            minWidth: 0, // Allow grid item to shrink below content size
            maxWidth: "100%",
          }}
        >
          <Card
            sx={{
              height: CARD_HEIGHT,
              width: "100%",
              maxWidth: CARD_MAX_WIDTH,
              mx: "auto", // Center card within grid cell when cell is wider than max
              minWidth: 0, // Allow card to shrink below content size
              overflow: "hidden", // Prevent content overflow
              transition: "all 0.15s ease-in-out",
              display: "flex",
              flexDirection: "column",
              border: `1px solid ${theme.palette.divider}`,
              // Highlight selected cards
              ...(isItemSelected(item) && {
                borderColor: theme.palette.primary.main,
                bgcolor: alpha(theme.palette.primary.main, 0.04),
              }),
              // Default border, can be overridden by cardSx
              borderLeft: config.cardSx 
                ? undefined 
                : `4px solid ${isItemSelected(item) ? theme.palette.primary.main : (isLicensed ? theme.palette.primary.main : theme.palette.grey[400])}`,
              "&:hover": {
                boxShadow: theme.shadows[4],
              },
              // Apply dynamic styles from cardSx
              ...dynamicCardSx,
            }}
          >
            <CardContent 
              sx={{ 
                p: 2, 
                pb: "12px !important",
                display: "flex", 
                flexDirection: "column",
                overflow: "hidden",
                flex: 1,
                position: "relative",
              }}
            >
              {/* Selection checkbox - shown when bulk actions are available */}
              {bulkActions.length > 0 && (
                <Checkbox
                  size="small"
                  checked={isItemSelected(item)}
                  onChange={(e) => {
                    e.stopPropagation();
                    toggleItemSelection(item);
                  }}
                  onClick={(e) => e.stopPropagation()}
                  sx={{
                    position: "absolute",
                    top: 4,
                    right: 4,
                    p: 0.25,
                    zIndex: 1,
                    bgcolor: "background.paper",
                    borderRadius: 0.5,
                    opacity: isItemSelected(item) ? 1 : 0.6,
                    "&:hover": {
                      opacity: 1,
                      bgcolor: "background.paper",
                    },
                  }}
                />
              )}
              
              {/* Header: Avatar + Name + Badges + Info Icon */}
              {/* Only load photos when showing 12 or 21 items to optimize performance */}
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1, width: "100%", overflow: "hidden" }}>
                {config.avatar?.photoField && tenant && item.id && (pageSize === 12 || pageSize === 21) ? (
                  <CippUserAvatar
                    userId={item.id}
                    tenantFilter={tenant}
                    displayName={avatarField}
                    size={48}
                    enablePhoto={true}
                    sx={{ 
                      flexShrink: 0,
                      cursor: onCardClick ? "pointer" : "default",
                    }}
                    onClick={onCardClick ? () => onCardClick(item) : undefined}
                  />
                ) : config.avatar?.customRender ? (
                  <Box
                    onClick={onCardClick ? () => onCardClick(item) : undefined}
                    sx={{
                      flexShrink: 0,
                      cursor: onCardClick ? "pointer" : "default",
                      "& .MuiAvatar-root": { width: 48, height: 48 },
                    }}
                  >
                    {config.avatar.customRender(avatarField, item)}
                  </Box>
                ) : config.avatar?.icon ? (
                  <Avatar
                    onClick={onCardClick ? () => onCardClick(item) : undefined}
                    sx={{
                      bgcolor: stringToColor(avatarField),
                      width: 48,
                      height: 48,
                      flexShrink: 0,
                      cursor: onCardClick ? "pointer" : "default",
                    }}
                  >
                    {typeof config.avatar.icon === "function"
                      ? config.avatar.icon(item)
                      : config.avatar.icon}
                  </Avatar>
                ) : (
                  <Avatar
                    onClick={onCardClick ? () => onCardClick(item) : undefined}
                    sx={{
                      bgcolor: stringToColor(avatarField),
                      width: 48,
                      height: 48,
                      fontSize: "1rem",
                      fontWeight: 600,
                      flexShrink: 0,
                      cursor: onCardClick ? "pointer" : "default",
                    }}
                  >
                    {getInitials(avatarField)}
                  </Avatar>
                )}

                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Stack direction="row" alignItems="center" spacing={0.5} sx={{ width: "100%" }}>
                    <Tooltip title={titleValue || ""} arrow enterDelay={500} placement="top">
                      <Typography
                        variant="subtitle2"
                        onClick={onCardClick ? () => onCardClick(item) : undefined}
                        sx={{
                          fontWeight: 600,
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          whiteSpace: "nowrap",
                          flex: 1,
                          minWidth: 0,
                          cursor: onCardClick ? "pointer" : "default",
                          "&:hover": onCardClick ? {
                            textDecoration: "underline",
                            color: "primary.main",
                          } : {},
                        }}
                      >
                        {titleValue}
                      </Typography>
                    </Tooltip>
                    {/* Compact badges */}
                    {config.badges?.length > 0 && (
                      <Box sx={{ display: "flex", gap: 0.5, ml: "auto", flexShrink: 0 }}>
                        {config.badges.map((badge, badgeIndex) =>
                          renderBadge(badge, item, badgeIndex, true, router)
                        )}
                      </Box>
                    )}
                    {/* Info icon to open offCanvas panel */}
                    {offCanvas && setOffCanvasData && setOffcanvasVisible && (
                      <Tooltip title="Quick Info" arrow>
                        <IconButton
                          size="small"
                          onClick={(e) => {
                            e.stopPropagation();
                            setOffCanvasData(item);
                            const idx = filteredData?.findIndex(r => r === item) ?? 0;
                            if (setOffCanvasRowIndex) setOffCanvasRowIndex(idx);
                            setOffcanvasVisible(true);
                          }}
                          sx={{
                            ml: 0.5,
                            p: 0.5,
                            color: "info.main",
                            "&:hover": {
                              bgcolor: "info.lighter",
                            },
                          }}
                        >
                          <Info sx={{ fontSize: 18 }} />
                        </IconButton>
                      </Tooltip>
                    )}
                  </Stack>

                  {subtitleValue && (
                    <Tooltip title={formatFieldValue(subtitleValue)} arrow enterDelay={500} placement="bottom">
                      <Typography
                        variant="caption"
                        color="text.secondary"
                        sx={{
                          display: "block",
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          whiteSpace: "nowrap",
                          maxWidth: "100%",
                        }}
                      >
                        {formatFieldValue(subtitleValue)}
                      </Typography>
                    </Tooltip>
                  )}
                </Box>
              </Stack>

              {/* Custom Content Section - rendered as separate row if customContentInline is false */}
              {typeof config.customContent === "function" && !config.customContentInline && config.customContent(item)}

              {/* Info Section */}
              <Box sx={{ overflow: "hidden", minWidth: 0, width: "100%" }}>
                {/* Extra fields (job title, department) */}
                {/* Inline custom content row - only renders when NO extraFields are defined */}
                {config.customContentInline && typeof config.customContent === "function" && extraFields.length === 0 && (
                  (() => {
                    const inlineContent = config.customContent(item);
                    if (inlineContent) {
                      return (
                        <Box sx={{ mb: 1, display: "flex", justifyContent: "flex-end" }}>
                          {inlineContent}
                        </Box>
                      );
                    }
                    return null;
                  })()
                )}
                {extraFields.length > 0 && (
                  <Stack spacing={0.25} sx={{ mb: 1, minWidth: 0, width: "100%", overflow: "hidden" }}>
                    {extraFields.slice(0, config.extraFieldsMax ?? 2).map((fieldOrRow, fieldIndex) => {
                      // Check if this is an array (paired fields in a row)
                      const isPairedRow = Array.isArray(fieldOrRow);
                      const fieldsInRow = isPairedRow ? fieldOrRow : [fieldOrRow];
                      
                      // Check if this is the first field (for inline custom content)
                      const isFirstField = fieldIndex === 0;
                      
                      const inlineContent = isFirstField && 
                        config.customContentInline && 
                        typeof config.customContent === "function" 
                          ? config.customContent(item) 
                          : null;

                      // Render a single field
                      const renderField = (field, isPaired = false, isLast = false) => {
                        const itemId = item.id || item.userPrincipalName;
                        const editFieldName = field.editField || field.field;
                        const rawValue = getNestedValue(item, field.field || field);
                        const formattedValue =
                          typeof field.formatter === "function"
                            ? field.formatter(rawValue, item)
                            : rawValue;
                        const value = formatFieldValue(formattedValue);
                        const hasValue = !!value;
                        const editState = getEditState(itemId, editFieldName);
                        const canEdit = field.editable && editApiUrl && !hasValue;
                        // Check for emptyAction (e.g., manager picker)
                        const hasEmptyAction = field.emptyAction && !hasValue;

                        // Editing mode
                        if (editState.editing) {
                          const isRightAlignedEdit = field.align === "right";
                          return (
                            <ClickAwayListener onClickAway={() => saveEdit(item, field, editState.value)}>
                              <Stack 
                                direction="row"
                                spacing={0.5} 
                                alignItems="center" 
                                sx={{ 
                                  minWidth: 0, 
                                  flex: isPaired ? 1 : undefined,
                                  maxWidth: isPaired ? "50%" : "100%",
                                  overflow: "hidden",
                                  justifyContent: isRightAlignedEdit ? "flex-end" : "flex-start",
                                }}
                              >
                                {field.icon && (
                                  <SvgIcon sx={{ fontSize: 14, color: "primary.main", flexShrink: 0 }}>
                                    {field.icon}
                                  </SvgIcon>
                                )}
                                <TextField
                                  inputRef={editInputRef}
                                  size="small"
                                  variant="standard"
                                  value={editState.value}
                                  onChange={(e) => updateEditValue(itemId, editFieldName, e.target.value)}
                                  onKeyDown={(e) => {
                                    if (e.key === "Enter") {
                                      saveEdit(item, field, editState.value);
                                    } else if (e.key === "Escape") {
                                      cancelEditing(itemId, editFieldName);
                                    }
                                  }}
                                  disabled={editState.saving}
                                  placeholder={field.label || editFieldName}
                                  sx={{ 
                                    flex: 1,
                                    "& .MuiInput-input": { 
                                      fontSize: "0.75rem",
                                      py: 0,
                                    },
                                  }}
                                  InputProps={{
                                    endAdornment: editState.saving ? (
                                      <InputAdornment position="end">
                                        <CircularProgress size={12} />
                                      </InputAdornment>
                                    ) : null,
                                  }}
                                />
                              </Stack>
                            </ClickAwayListener>
                          );
                        }

                        // Display mode
                        const isClickable = canEdit || hasEmptyAction;
                        const tooltipText = hasEmptyAction 
                          ? `Click to ${field.emptyAction.label?.toLowerCase() || 'set value'}`
                          : canEdit 
                            ? "Click to add" 
                            : (value || "");
                        
                        const handleFieldClick = () => {
                          if (hasEmptyAction) {
                            // Open emptyAction dialog (e.g., manager picker)
                            setEmptyActionData({
                              item: item,
                              action: field.emptyAction,
                              ready: true,
                            });
                            emptyActionDialog.handleOpen();
                          } else if (canEdit) {
                            startEditing(itemId, editFieldName, "");
                          }
                        };
                        
                        const isRightAligned = field.align === "right";
                        
                        return (
                          <Tooltip 
                            title={tooltipText} 
                            placement="top"
                            disableHoverListener={!value && !isClickable}
                          >
                            <Stack 
                              direction="row"
                              spacing={0.5} 
                              alignItems="center" 
                              onClick={isClickable ? handleFieldClick : undefined}
                              sx={{ 
                                minWidth: 0, 
                                flex: isPaired ? 1 : undefined,
                                maxWidth: isPaired ? "50%" : "100%",
                                overflow: "hidden",
                                cursor: isClickable ? "pointer" : "default",
                                borderRadius: 0.5,
                                px: isClickable ? 0.5 : 0,
                                mx: isClickable ? -0.5 : 0,
                                justifyContent: isRightAligned ? "flex-end" : "flex-start",
                                "&:hover": isClickable ? {
                                  bgcolor: "action.hover",
                                } : {},
                              }}
                            >
                              {field.icon && (
                                <SvgIcon sx={{ fontSize: 14, color: hasValue ? "text.secondary" : "info.main", opacity: hasValue ? 1 : 0.6, flexShrink: 0 }}>
                                  {field.icon}
                                </SvgIcon>
                              )}
                              <Typography
                                variant="caption"
                                sx={{
                                  overflow: "hidden",
                                  textOverflow: "ellipsis",
                                  maxWidth: "100%",
                                  minWidth: 0,
                                  flex: isRightAligned ? undefined : 1,
                                  color: hasValue ? "text.secondary" : "info.main",
                                  opacity: hasValue ? 1 : 0.6,
                                  fontStyle: hasValue ? "normal" : "italic",
                                  whiteSpace: "nowrap",
                                  textAlign: "left",
                                }}
                              >
                                {value || "—"}
                              </Typography>
                            </Stack>
                          </Tooltip>
                        );
                      };
                      
                      return (
                        <Stack 
                          key={fieldIndex} 
                          direction="row" 
                          spacing={isPairedRow ? 1 : 0.5}
                          alignItems="center"
                          justifyContent="space-between"
                          sx={{ minWidth: 0, width: "100%", overflow: "hidden", minHeight: 20 }}
                        >
                          {isPairedRow ? (
                            // Paired fields - each takes up to 50% width
                            <>
                              {fieldsInRow.map((f, i) => renderField(f, true, i === fieldsInRow.length - 1))}
                            </>
                          ) : (
                            // Single field row
                            <Stack direction="row" spacing={0.5} alignItems="center" sx={{ minWidth: 0, flex: 1, overflow: "hidden" }}>
                              {renderField(fieldsInRow[0], false, true)}
                            </Stack>
                          )}
                          {inlineContent}
                        </Stack>
                      );
                    })}
                  </Stack>
                )}

                {/* Desktop-only additional info in compact grid */}
                {!isMobile && desktopFields.length > 0 && (
                  <Box 
                    sx={{ 
                      mt: 0.5,
                      pt: 1, 
                      borderTop: `1px dashed ${theme.palette.divider}`,
                      minWidth: 0,
                      width: "100%",
                      overflow: "hidden",
                    }}
                  >
                    {config.desktopFieldsLayout === "column" ? (
                      <Stack spacing={0.5} sx={{ minWidth: 0, width: "100%", overflow: "hidden" }}>
                        {desktopFields.slice(0, config.desktopFieldsMax ?? 4).map((field, fieldIndex) => {
                          const itemId = item.id || item.userPrincipalName;
                          const editFieldName = field.editField || field.field;
                          const rawValue = getNestedValue(item, field.field || field);
                          const formattedValue =
                            typeof field.formatter === "function"
                              ? field.formatter(rawValue, item)
                              : rawValue;
                          const value = formatFieldValue(formattedValue);
                          const hasValue = !!value;
                          const href = hasValue ? getFieldHref(field, value) : null;
                          const editState = getEditState(itemId, editFieldName);
                          const canEdit = field.editable && editApiUrl && !hasValue;

                          // Editing mode for desktop fields
                          if (editState.editing) {
                            return (
                              <ClickAwayListener key={fieldIndex} onClickAway={() => saveEdit(item, field, editState.value)}>
                                <Stack direction="row" spacing={0.5} alignItems="center" sx={{ minWidth: 0, width: "100%", overflow: "hidden", minHeight: 18 }}>
                                  {field.icon && (
                                    <SvgIcon sx={{ fontSize: 12, color: "primary.main", flexShrink: 0 }}>
                                      {field.icon}
                                    </SvgIcon>
                                  )}
                                  <TextField
                                    inputRef={editInputRef}
                                    size="small"
                                    variant="standard"
                                    value={editState.value}
                                    onChange={(e) => updateEditValue(itemId, editFieldName, e.target.value)}
                                    onKeyDown={(e) => {
                                      if (e.key === "Enter") {
                                        saveEdit(item, field, editState.value);
                                      } else if (e.key === "Escape") {
                                        cancelEditing(itemId, editFieldName);
                                      }
                                    }}
                                    disabled={editState.saving}
                                    placeholder={field.label || editFieldName}
                                    sx={{ 
                                      flex: 1,
                                      "& .MuiInput-input": { 
                                        fontSize: "0.7rem",
                                        py: 0,
                                      },
                                    }}
                                    InputProps={{
                                      endAdornment: editState.saving ? (
                                        <InputAdornment position="end">
                                          <CircularProgress size={10} />
                                        </InputAdornment>
                                      ) : null,
                                    }}
                                  />
                                </Stack>
                              </ClickAwayListener>
                            );
                          }

                          return (
                            <Tooltip 
                              key={fieldIndex}
                              title={canEdit ? "Click to add" : (value || "")} 
                              placement="top"
                              disableHoverListener={!value && !canEdit}
                            >
                              <Stack 
                                direction="row" 
                                spacing={0.5} 
                                alignItems="center" 
                                onClick={canEdit ? () => startEditing(itemId, editFieldName, "") : undefined}
                                sx={{ 
                                  minWidth: 0, 
                                  width: "100%", 
                                  overflow: "hidden", 
                                  minHeight: 18,
                                  cursor: canEdit ? "pointer" : "default",
                                  borderRadius: 0.5,
                                  px: canEdit ? 0.5 : 0,
                                  mx: canEdit ? -0.5 : 0,
                                  "&:hover": canEdit ? {
                                    bgcolor: "action.hover",
                                  } : {},
                                }}
                              >
                                {field.icon && (
                                  <SvgIcon sx={{ fontSize: 12, color: hasValue ? "text.disabled" : "info.main", opacity: hasValue ? 1 : 0.6, flexShrink: 0 }}>
                                    {field.icon}
                                  </SvgIcon>
                                )}
                                <Typography
                                  variant="caption"
                                  component={href ? "a" : "span"}
                                  href={href || undefined}
                                  onClick={href ? (e) => e.stopPropagation() : undefined}
                                  sx={{
                                    fontSize: "0.7rem",
                                    overflow: "hidden",
                                    textOverflow: "ellipsis",
                                    whiteSpace: "nowrap",
                                    minWidth: 0,
                                    flex: 1,
                                    color: href ? "primary.main" : hasValue ? "text.secondary" : "info.main",
                                    opacity: hasValue || href ? 1 : 0.6,
                                    textDecoration: href ? "underline" : "none",
                                    fontStyle: hasValue ? "normal" : "italic",
                                  }}
                                >
                                  {value || "—"}
                                </Typography>
                              </Stack>
                            </Tooltip>
                          );
                        })}
                      </Stack>
                    ) : (
                      <Grid container spacing={0.5} sx={{ minWidth: 0, width: "100%" }}>
                        {desktopFields.slice(0, config.desktopFieldsMax ?? 4).map((field, fieldIndex) => {
                          const rawValue = getNestedValue(item, field.field || field);
                          const value = formatFieldValue(rawValue);
                          const hasValue = !!value;
                          const href = hasValue ? getFieldHref(field, value) : null;
                          
                          return (
                            <Grid item xs={6} key={fieldIndex} sx={{ minWidth: 0, overflow: "hidden" }}>
                              <Tooltip title={value || ""} arrow enterDelay={500} placement="top" disableHoverListener={!hasValue}>
                                <Stack direction="row" spacing={0.5} alignItems="center" sx={{ minWidth: 0, width: "100%", overflow: "hidden", minHeight: 18 }}>
                                  {field.icon && (
                                    <SvgIcon sx={{ fontSize: 12, color: hasValue ? "text.disabled" : "info.main", opacity: hasValue ? 1 : 0.6, flexShrink: 0 }}>
                                      {field.icon}
                                    </SvgIcon>
                                  )}
                                  <Typography 
                                    variant="caption" 
                                    component={href ? "a" : "span"}
                                    href={href || undefined}
                                    onClick={href ? (e) => e.stopPropagation() : undefined}
                                    sx={{ 
                                      fontSize: "0.7rem",
                                      overflow: "hidden",
                                      textOverflow: "ellipsis",
                                      whiteSpace: "nowrap",
                                      minWidth: 0,
                                      flex: 1,
                                      color: href ? "primary.main" : hasValue ? "text.secondary" : "info.main",
                                      opacity: hasValue || href ? 1 : 0.6,
                                      textDecoration: href ? "underline" : "none",
                                      fontStyle: hasValue ? "normal" : "italic",
                                    }}
                                  >
                                    {value || "—"}
                                  </Typography>
                                </Stack>
                              </Tooltip>
                            </Grid>
                          );
                        })}
                      </Grid>
                    )}
                  </Box>
                )}
              </Box>

              {/* Quick Actions - Always at bottom */}
              {cardActions && cardActions.length > 0 && (
                <Box
                  sx={{
                    pt: 1,
                    borderTop: `1px solid ${theme.palette.divider}`,
                  }}
                  onClick={(e) => e.stopPropagation()}
                >
                  <CippQuickActions
                    actions={cardActions}
                    data={item}
                    maxActions={isMobile ? (config.mobileMaxQuickActions ?? 7) : (config.maxQuickActions ?? 8)}
                    showOnHover={false}
                    variant={isMobile && config.mobileQuickActionsVariant ? config.mobileQuickActionsVariant : (config.quickActionsVariant ?? "icon")}
                    onOffCanvasClick={offCanvas ? (itemData) => {
                      setOffCanvasData(itemData);
                      // Find index for navigation
                      const idx = filteredData?.findIndex(r => r === itemData) ?? 0;
                      setOffCanvasRowIndex(idx);
                      setOffcanvasVisible(true);
                    } : undefined}
                  />
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>
      );
    });
    // Performance-critical render of the full card grid. The omitted inline helpers
    // (getFieldHref/saveEdit/getEditState) and props (editApiUrl/onCardClick/router/
    // filteredData) are re-created each render; including them would recompute every
    // card on every render. paginatedData (derived from filteredData) is the meaningful
    // trigger, and the helpers close over the state they need at call time.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    paginatedData,
    pageSize,
    config,
    isMobile,
    tenant,
    theme,
    cardActions,
    offCanvas,
    setOffCanvasData,
    setOffCanvasRowIndex,
    setOffcanvasVisible,
    emptyActionDialog,
    bulkActions,
    isItemSelected,
    toggleItemSelection,
  ]);

  // Fixed card height for uniform appearance
  if (isLoading) {
    return (
      <Box sx={{ p: 2 }}>
        <Grid container spacing={2}>
          {[1, 2, 3, 4, 5, 6].map((i) => (
              <Grid item xs={12} sm={isMobile ? 12 : 6} md={4} lg={3} key={i}>
              <Card sx={{ height: CARD_HEIGHT, maxWidth: CARD_MAX_WIDTH, mx: "auto" }}>
                <CardContent sx={{ height: "100%", p: 2 }}>
                  <Stack direction="row" spacing={2} alignItems="center">
                    <Skeleton variant="circular" width={52} height={52} />
                    <Box sx={{ flex: 1 }}>
                      <Skeleton variant="text" width="70%" height={24} />
                      <Skeleton variant="text" width="90%" height={18} />
                    </Box>
                  </Stack>
                  {!isMobile && (
                    <Box sx={{ mt: 2 }}>
                      <Skeleton variant="text" width="100%" height={18} />
                      <Skeleton variant="text" width="80%" height={18} />
                    </Box>
                  )}
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      </Box>
    );
  }

  return (
    <Box sx={{ width: "100%" }}>
      {/* Search and Refresh Bar */}
      {showSearch && (
        <Box sx={{ px: 2, py: 1.5, display: "flex", gap: 1, alignItems: "center", flexWrap: "wrap" }}>
          {/* Selection checkbox for visible items */}
          {bulkActions.length > 0 && paginatedData?.length > 0 && (
            <Tooltip title={allVisibleSelected ? "Deselect all visible" : "Select all visible"}>
              <Checkbox
                size="small"
                checked={allVisibleSelected}
                indeterminate={selectedItems.size > 0 && !allVisibleSelected}
                onChange={() => {
                  if (allVisibleSelected) {
                    // Deselect all visible items
                    const visibleIds = new Set(paginatedData.map(item => getItemId(item)));
                    setSelectedItems(prev => {
                      const newSet = new Set(prev);
                      visibleIds.forEach(id => newSet.delete(id));
                      return newSet;
                    });
                  } else {
                    selectAllVisible();
                  }
                }}
                sx={{ p: 0.5 }}
              />
            </Tooltip>
          )}
          
          <TextField
            size="small"
            placeholder={`Search ${title || "items"}...`}
            value={searchInput ?? searchTerm}
            onChange={(e) => onSearchChange(e.target.value)}
            sx={{ flex: 1, minWidth: 200, maxWidth: isMobile ? "100%" : 350 }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Search fontSize="small" />
                </InputAdornment>
              ),
            }}
          />
          
          {/* Selection indicator and bulk actions */}
          {selectedItems.size > 0 && (
            <>
              <Divider orientation="vertical" flexItem sx={{ mx: 0.5 }} />
              <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: "nowrap" }}>
                {selectedItems.size} selected
              </Typography>
              {bulkActions.length > 0 && selectedItems.size >= 2 && (
                <Button
                  size="small"
                  variant="outlined"
                  onClick={(e) => setBulkActionAnchor(e.currentTarget)}
                  startIcon={
                    <SvgIcon fontSize="small">
                      <ChevronDownIcon />
                    </SvgIcon>
                  }
                  sx={{ 
                    height: 32,
                    textTransform: "none",
                    whiteSpace: "nowrap",
                  }}
                >
                  Bulk Actions
                </Button>
              )}
              <Button
                size="small"
                variant="text"
                onClick={clearSelection}
                sx={{ 
                  height: 32,
                  textTransform: "none",
                  minWidth: "auto",
                  px: 1,
                }}
              >
                Clear
              </Button>
            </>
          )}
          
          <Box sx={{ display: "flex", alignItems: "center", gap: 1, ml: "auto" }}>
            {onRefresh && (
              <IconButton onClick={onRefresh} size="small" title="Refresh">
                <Refresh />
              </IconButton>
            )}
            {/* Page size selector */}
            <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
              <Typography variant="body2" color="text.secondary" sx={{ mr: 0.5 }}>
                Show:
              </Typography>
              {PAGE_SIZE_OPTIONS.map((option) => (
                <Chip
                  key={option}
                  label={option}
                  size="small"
                  onClick={() => handlePageSizeChange(option)}
                  variant={pageSize === option ? "filled" : "outlined"}
                  color={pageSize === option ? "primary" : "default"}
                  sx={{ 
                    minWidth: option === "All" ? 40 : 32,
                    height: 24,
                    fontSize: "0.75rem",
                    cursor: "pointer",
                    "& .MuiChip-label": { px: 1 },
                  }}
                />
              ))}
            </Box>
            <Divider orientation="vertical" flexItem sx={{ mx: 1 }} />
            <Typography variant="body2" color="text.secondary">
              {pageSize === "All" 
                ? `${totalItems} ${totalItems === 1 ? "result" : "results"}`
                : totalItems > effectivePageSize 
                  ? `${startIndex + 1}-${endIndex} of ${totalItems}`
                  : `${totalItems} ${totalItems === 1 ? "result" : "results"}`
              }
            </Typography>
          </Box>
        </Box>
      )}

      {/* Selection action bar for desktop card view: the search header (which
          normally hosts the selection indicator + bulk actions) is hidden when
          showSearch is false, yet per-card checkboxes are still shown. Without
          this bar, selected cards would be a dead-end with no way to act on them. */}
      {!showSearch && bulkActions.length > 0 && selectedItems.size > 0 && (
        <Box
          sx={{
            px: 2,
            py: 1,
            display: "flex",
            alignItems: "center",
            gap: 1,
            flexWrap: "wrap",
          }}
        >
          <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: "nowrap" }}>
            {selectedItems.size} selected
          </Typography>
          {selectedItems.size >= 2 && (
            <Button
              size="small"
              variant="outlined"
              onClick={(e) => setBulkActionAnchor(e.currentTarget)}
              startIcon={
                <SvgIcon fontSize="small">
                  <ChevronDownIcon />
                </SvgIcon>
              }
              sx={{ height: 32, textTransform: "none", whiteSpace: "nowrap" }}
            >
              Bulk Actions
            </Button>
          )}
          <Button
            size="small"
            variant="text"
            onClick={clearSelection}
            sx={{ height: 32, textTransform: "none", minWidth: "auto", px: 1 }}
          >
            Clear
          </Button>
        </Box>
      )}

      {/* Card Grid - Uniform sizing */}
      <Box sx={{ p: 2, pt: 1 }}>
        <Grid container spacing={2}>
          {renderedCards}
        </Grid>

        {/* Show loading indicator when fetching more data for current page */}
        {isFetchingNextPage && paginatedData?.length === 0 && (
          <Box sx={{ textAlign: "center", py: 8 }}>
            <CircularProgress size={32} />
            <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
              Loading more data...
            </Typography>
          </Box>
        )}

        {filteredData?.length === 0 && !isFetchingNextPage && (
          <Box sx={{ textAlign: "center", py: 8, color: "text.secondary" }}>
            <Typography variant="body1">
              {searchTerm ? `No results found for "${searchTerm}"` : "No data available"}
            </Typography>
          </Box>
        )}

        {/* Pagination Controls - hidden when "All" is selected */}
        {/* Show pagination if we have multiple pages OR if there's more data to load */}
        {pageSize !== "All" && (totalPages > 1 || hasNextPage) && (
          <Box 
            sx={{ 
              display: "flex", 
              justifyContent: "center", 
              alignItems: "center", 
              gap: 2, 
              mt: 3,
              pb: 1,
            }}
          >
            <IconButton 
              onClick={handlePreviousPage} 
              disabled={currentPage === 0 || isFetchingNextPage}
              size="small"
              sx={{ 
                border: 1, 
                borderColor: "divider",
                "&:disabled": { opacity: 0.5 },
              }}
            >
              <Typography variant="body2">←</Typography>
            </IconButton>
            
            <Stack direction="row" spacing={0.5} alignItems="center">
              {/* Show page numbers with ellipsis for large page counts */}
              {/* When hasNextPage is true, we show "..." to indicate more pages available */}
              {Array.from({ length: Math.min(totalPages, 7) }, (_, i) => {
                let pageNum;
                if (totalPages <= 7) {
                  pageNum = i;
                } else if (currentPage < 4) {
                  pageNum = i < 5 ? i : (i === 5 ? -1 : totalPages - 1);
                } else if (currentPage > totalPages - 5) {
                  pageNum = i === 0 ? 0 : (i === 1 ? -1 : totalPages - 6 + i);
                } else {
                  pageNum = i === 0 ? 0 : (i === 1 ? -1 : (i === 5 ? -1 : (i === 6 ? totalPages - 1 : currentPage - 2 + i)));
                }
                
                if (pageNum === -1) {
                  return <Typography key={`ellipsis-${i}`} variant="body2" color="text.secondary">...</Typography>;
                }
                
                return (
                  <IconButton
                    key={pageNum}
                    onClick={() => handlePageChange(pageNum)}
                    disabled={isFetchingNextPage}
                    size="small"
                    sx={{
                      minWidth: 32,
                      height: 32,
                      borderRadius: 1,
                      bgcolor: currentPage === pageNum ? "primary.main" : "transparent",
                      color: currentPage === pageNum ? "primary.contrastText" : "text.primary",
                      "&:hover": {
                        bgcolor: currentPage === pageNum ? "primary.dark" : "action.hover",
                      },
                    }}
                  >
                    <Typography variant="body2">{pageNum + 1}</Typography>
                  </IconButton>
                );
              })}
              {/* Show ellipsis and loading indicator if more data is available */}
              {hasNextPage && (
                <>
                  <Typography variant="body2" color="text.secondary">...</Typography>
                  {isFetchingNextPage && (
                    <CircularProgress size={16} sx={{ ml: 0.5 }} />
                  )}
                </>
              )}
            </Stack>
            
            <IconButton 
              onClick={handleNextPage} 
              disabled={(currentPage >= totalPages - 1 && !hasNextPage) || isFetchingNextPage}
              size="small"
              sx={{ 
                border: 1, 
                borderColor: "divider",
                "&:disabled": { opacity: 0.5 },
              }}
            >
              {isFetchingNextPage ? (
                <CircularProgress size={14} />
              ) : (
                <Typography variant="body2">→</Typography>
              )}
            </IconButton>
          </Box>
        )}
      </Box>
      
      {/* EmptyAction Dialog (e.g., manager picker) */}
      {emptyActionData.ready && (
        <CippApiDialog
          createDialog={emptyActionDialog}
          title={emptyActionData.action?.label || "Select Value"}
          fields={emptyActionData.action?.fields}
          api={emptyActionData.action}
          row={emptyActionData.item}
          relatedQueryKeys={emptyActionData.action?.relatedQueryKeys}
        />
      )}
      
      {/* Bulk Actions Menu */}
      <Menu
        anchorEl={bulkActionAnchor}
        open={Boolean(bulkActionAnchor)}
        onClose={() => setBulkActionAnchor(null)}
        anchorOrigin={{
          horizontal: "right",
          vertical: "bottom",
        }}
        transformOrigin={{
          horizontal: "right",
          vertical: "top",
        }}
        PaperProps={{
          sx: {
            mt: 1,
            borderRadius: 2,
            minWidth: 200,
          },
        }}
      >
        {bulkActions.map((action, index) => {
          // Check if action is disabled based on condition
          const isDisabled = action.condition
            ? !selectedItemsData.every((item) => action.condition({ original: item }))
            : false;
          
          return (
            <MenuItem
              key={index}
              disabled={isDisabled}
              onClick={() => handleBulkAction(action)}
            >
              {action.icon && (
                <ListItemIcon>
                  <SvgIcon fontSize="small">{action.icon}</SvgIcon>
                </ListItemIcon>
              )}
              <ListItemText>{action.label}</ListItemText>
            </MenuItem>
          );
        })}
      </Menu>
      
      {/* Bulk Action Dialog */}
      {bulkActionData.ready && (
        <CippApiDialog
          createDialog={bulkActionDialog}
          title="Confirmation"
          fields={bulkActionData.action?.fields}
          api={bulkActionData.action}
          row={bulkActionData.data}
          relatedQueryKeys={queryKey ? [queryKey] : []}
          onClose={() => {
            setBulkActionData({ data: [], action: null, ready: false });
            clearSelection();
          }}
        />
      )}
    </Box>
  );
};

// Legacy wrapper for backward compatibility
const MobileCardView = (props) => <CardView {...props} isMobile={true} />;

export const CippDataTable = (props) => {
  const {
    queryKey,
    data = EMPTY_ARRAY,
    columns = [],
    api = {},
    isFetching = false,
    columnVisibility: initialColumnVisibility = {
      id: false,
      RowKey: false,
      ETag: false,
      PartitionKey: false,
      Timestamp: false,
      TableTimestamp: false,
    },
    exportEnabled = true,
    simpleColumns = [],
    dataFilter,
    dataMap,
    // Whole-array transform applied after dataFilter/dataMap (e.g. grouping All Tenants rows).
    dataTransform,
    actions,
    title = "Report",
    simple = false,
    cardButton,
    offCanvas = false,
    offCanvasOnRowClick = false,
    noCard = false,
    hideTitle = false,
    refreshFunction,
    incorrectDataMessage = "Data not in correct format",
    onChange,
    filters,
    maxHeightOffset = "380px",
    defaultSorting = [],
    isInDialog = false,
    showBulkExportAction = true,
    cardConfig = null, // Configuration for card view (renamed from mobileCardConfig)
    mobileCardConfig = null, // Deprecated: use cardConfig instead
    defaultViewMode = "cards", // Default view mode: 'cards' or 'table'
    viewModeStorageKey: viewModeStorageKeyOverride = null,
    showRowActionsMenu = true,
    rowSx = null, // Optional row styling callback (row) => sx object
    onCardClick = null, // Callback when card avatar/title is clicked for navigation
    dataFreshnessField = null, // Field name to extract data freshness date from first row (e.g. "reportRefreshDate")
    initialColumnFilters = null, // Optional initial column filters (e.g. [{ id: "assignedLicenses", value: "licensed" }])
    viewMode: viewModeProp,
    mobileCard,
    dataSourceControls,
    subTables = EMPTY_ARRAY,
    persistenceKey,
    parentRow,
  } = props;

  const { updateTrigger } = useLicenseBackfill();

  // Create a map of column IDs to their filterType for quick lookup
  const filterTypeMap = useMemo(() => {
    if (!filters || !Array.isArray(filters)) return {};
    return filters.reduce((acc, filter) => {
      if (filter.value && Array.isArray(filter.value)) {
        filter.value.forEach((v) => {
          if (v.id && filter.filterType) {
            acc[v.id] = filter.filterType;
          }
        });
      }
      return acc;
    }, {});
  }, [filters]);

  const [columnVisibility, setColumnVisibility] = useState(initialColumnVisibility);
  const [configuredSimpleColumns, setConfiguredSimpleColumns] = useState(simpleColumns);
  const [usedData, setUsedData] = useState(data);
  const [usedColumns, setUsedColumns] = useState([]);
  const [offcanvasVisible, setOffcanvasVisible] = useState(false);
  const [offCanvasData, setOffCanvasData] = useState({});
  const [offCanvasRowIndex, setOffCanvasRowIndex] = useState(0);
  const [filteredRows, setFilteredRows] = useState([]);
  const [customComponentData, setCustomComponentData] = useState({});
  const [customComponentVisible, setCustomComponentVisible] = useState(false);
  const [actionData, setActionData] = useState({ data: {}, action: {}, ready: false });
  const [rowActionQueueIds, setRowActionQueueIds] = useState([]);
  const [graphFilterData, setGraphFilterData] = useState({});
  const [sorting, setSorting] = useState([]);
  const [columnFilters, setColumnFilters] = useState(() => {
    if (initialColumnFilters && Array.isArray(initialColumnFilters) && initialColumnFilters.length > 0) {
      return initialColumnFilters;
    }
    return [];
  });
  const [cardSearchInput, setCardSearchInput] = useState("");
  const [debouncedCardSearchTerm, setDebouncedCardSearchTerm] = useState("");
  const waitingBool = api?.url ? true : false;

  const settings = useSettings();
  const prevSchemaKeyRef = useRef("");
  const prevDataRef = useRef(data);
  const theme = useTheme();
  const router = useRouter();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));
  const isTablet = useMediaQuery(theme.breakpoints.down("md"));

  // Merge cardConfig and mobileCardConfig (cardConfig takes precedence)
  const effectiveCardConfig = cardConfig || mobileCardConfig;
  const lastOrderedSelectionRef = useRef(null);

  // The cards branch and the renderTopToolbar branch are two alternating CIPPTableToptoolbar
  // instances (only one is ever mounted), so state that must survive the cards<->table flip
  // lives here and is passed down as props to both.
  const [activeFilters, setActiveFilters] = useState({ graph: null, table: null });
  const [searchValue, setSearchValue] = useState("");
  const restoredFiltersRef = useRef(new Set());
  const searchFocusRef = useRef(null);

  const routerPageName = router.pathname.split("/").slice(1).join("/");
  const pageName = persistenceKey ?? (isInDialog ? "" : routerPageName);
  // The user's saved column selection for this page. Always layered over a full default
  // map, never used as the whole visibility state: TanStack treats a column with no entry
  // as visible, so a preference saved on a tenant whose data lacked a field would reveal
  // that field the moment another tenant's data contains it.
  const preferredColumnVisibility = pageName
    ? settings?.columnDefaults?.[pageName]
    : undefined;

  // 'cards' below the md breakpoint (or when forced via settings/prop), 'table' otherwise.
  // simple tables always resolve to 'table'.
  const resolvedViewMode = useTableViewMode({ viewMode: viewModeProp, simple });
  // same pivot as the cards/table auto mode, so the FAB and the card list agree on width
  const isNarrowViewport = useIsNarrowForTables();
  // viewMode prop or simple is a hard force, the toggle never overrides it
  const toggleAllowed = !viewModeProp && !simple;
  // Mobile select mode: checkboxes on cards + the bottom bulk bar. Lives here so the
  // toolbar (which renders the Select toggle) and the card list stay in sync. Picker
  // tables (onChange) force it on — selection is their entire purpose.
  const [mobileSelectMode, setMobileSelectMode] = useState(false);
  // portal target for the header's bulk-actions slot, set by the CardHeader's ref callback
  const [headerBulkSlot, setHeaderBulkSlot] = useState(null);

  // transient cards<->table override, session-only, never persisted
  const [viewOverride, setViewOverride] = useState(null);
  const effectiveViewMode = toggleAllowed ? viewOverride ?? resolvedViewMode : resolvedViewMode;
  const isCardView = effectiveViewMode === "cards";
  const tableViewActive = effectiveViewMode === "table";
  const CardViewSurface = noCard ? Box : Card;
  const [narrowTableMaxHeight, setNarrowTableMaxHeight] = useState(null);
  // way back button: table is only up because of the override, phone default is still cards
  const showReturnToCards = toggleAllowed && tableViewActive && resolvedViewMode === "cards";

  // Generate storage key for view mode preference
  const viewModeStorageKey =
    viewModeStorageKeyOverride || `cipp-view-mode-${router.pathname}`;

  // Initialize view mode from localStorage or default
  const [viewMode, setViewMode] = useState(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem(viewModeStorageKey);
      if (stored === 'cards' || stored === 'table') {
        return stored;
      }
    }
    return defaultViewMode;
  });

  // Persist view mode to localStorage
  const handleViewModeChange = useCallback((newMode) => {
    if (newMode && (newMode === 'cards' || newMode === 'table')) {
      setViewMode(newMode);
      if (typeof window !== 'undefined') {
        localStorage.setItem(viewModeStorageKey, newMode);
      }
    }
  }, [viewModeStorageKey]);

  // Debounce card search to avoid filtering on every keystroke
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedCardSearchTerm(cardSearchInput);
    }, 200);
    return () => clearTimeout(timer);
  }, [cardSearchInput]);


  // Determine if we should show card view
  // On mobile: always show cards if config exists
  // On desktop: respect viewMode setting
  const showCardView = effectiveCardConfig && (isMobile || viewMode === 'cards');
  
  // Legacy alias for backward compatibility
  const showMobileCardView = isMobile && effectiveCardConfig;

  // Compute effective query key - used consistently for fetching and cache invalidation
  const effectiveQueryKey = queryKey ? queryKey : title;

  const getRequestData = ApiGetCallWithPagination({
    url: api.url,
    data: { ...api.data },
    queryKey: effectiveQueryKey,
    waiting: waitingBool,
    ...graphFilterData,
  });

  // Note: The `filters` prop contains filter OPTIONS for the dropdown menu, not active filters.
  // Active filters are applied via setTableFilter in CIPPTableToptoolbar when user selects a filter.
  // Do NOT auto-apply filters here as it breaks filtering functionality.

  useEffect(() => {
    if (Array.isArray(data) && !api?.url && data !== prevDataRef.current) {
      prevDataRef.current = data;
      setUsedData(data);
    }
  }, [data, api?.url]);

  // Auto-pagination: automatically fetch all pages for table view.
  // For card view, we use lazy loading instead - only fetch when user needs more data.
  useEffect(() => {
    // Skip auto-pagination when in card view mode - CardView handles its own pagination
    if (showCardView) {
      return;
    }

    // Stop auto-paginating if a page fetch errored. A failed page is NOT appended
    // to data.pages, so the last *successful* page still carries its nextLink. Without
    // this guard the effect would call fetchNextPage() again on every render, retrying
    // the failing page forever. On large tenants (tens of thousands of users paged 999
    // at a time) Graph throttling/timeouts make such failures likely, which is what
    // leaves the refresh indicator spinning and the list never finishing loading.
    if (getRequestData.isError || getRequestData.isFetchNextPageError) {
      return;
    }

    if (api?.url && getRequestData.isSuccess && !getRequestData.isFetching) {
      const pages = getRequestData.data?.pages;
      if (pages && pages.length > 0) {
        const lastPage = pages[pages.length - 1];
        const nextLinkExists = lastPage?.Metadata?.nextLink;
        if (nextLinkExists) {
          getRequestData.fetchNextPage();
        }
      }
    }
    // Keyed to the specific request-state fields that should drive pagination. The
    // `getRequestData` object is a new reference every render, so depending on it
    // directly would re-run (and re-fetch) on every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    api?.url,
    getRequestData.data?.pages?.length,
    getRequestData.isFetching,
    getRequestData.isError,
    getRequestData.isFetchNextPageError,
    queryKey,
    showCardView,
  ]);

  useEffect(() => {
    if (api?.url && getRequestData.isSuccess && getRequestData.data?.pages) {
      const allPages = getRequestData.data.pages;

      let combinedResults = allPages.flatMap((page) => {
        const nestedData = getNestedValue(page, api.dataKey);
        if (nestedData !== undefined) {
          return nestedData;
        }
        // dataKey miss on a bare-array page: the endpoint served the legacy shape.
        return Array.isArray(page) ? page : [];
      });

      // Deduplicate across paginated pages. Microsoft Graph (and other
      // cursor-paginated APIs) can return the same record in adjacent pages
      // when ordering by a non-unique field (e.g. $orderby=displayName) or
      // when the underlying data shifts during pagination. Without this,
      // duplicates appear in both the card and table views.
      if (Array.isArray(combinedResults) && combinedResults.length > 1) {
        const seen = new Set();
        const deduped = [];
        let hadDuplicates = false;
        for (const item of combinedResults) {
          if (!item || typeof item !== "object") {
            deduped.push(item);
            continue;
          }
          const dedupKey = item.id ?? item.RowKey ?? null;
          if (dedupKey === null || dedupKey === undefined || dedupKey === "") {
            deduped.push(item);
            continue;
          }
          const compositeKey = `${typeof dedupKey}:${dedupKey}`;
          if (seen.has(compositeKey)) {
            hadDuplicates = true;
            continue;
          }
          seen.add(compositeKey);
          deduped.push(item);
        }
        if (hadDuplicates) {
          combinedResults = deduped;
        }
      }

      // Apply dataFilter if provided in api config
      if (api.dataFilter && typeof api.dataFilter === "function") {
        combinedResults = api.dataFilter(combinedResults);
      }

      const filtered = dataFilter ? combinedResults.filter(dataFilter) : combinedResults;
      const mapped =
        typeof dataMap === "function"
          ? filtered.map((row) => dataMap(row, { parentRow }))
          : filtered;
      const transformed =
        typeof dataTransform === "function" ? dataTransform(mapped) : mapped;

      // Only update state if data has actually changed to prevent infinite re-renders.
      // React Query returns a new object reference on every fetch even if data is identical,
      // so we must deep-compare before updating state.
      setUsedData((prevData) => {
        if (isEqual(prevData, transformed)) {
          return prevData;
        }
        return transformed;
      });
    }
    // Keyed to the specific api fields actually used (dataKey/dataFilter) plus the
    // request status. The `api` object itself is re-created every render by the parent,
    // so depending on it would re-run this dedupe pass needlessly each render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    api?.url,
    getRequestData.isSuccess,
    getRequestData.data,
    api.dataKey,
    api.dataFilter,
    getRequestData.isFetching,
    queryKey,
    dataFilter,
    dataMap,
    dataTransform,
    parentRow,
  ]);

  // Derive columns from data — only when the data schema actually changes.
  useEffect(() => {
    if (
      !Array.isArray(usedData) ||
      usedData.length === 0 ||
      typeof usedData[0] !== "object" ||
      usedData === null ||
      usedData === undefined
    ) {
      return;
    }

    const schemaKey = computeSchemaKey(usedData);
    if (schemaKey === prevSchemaKeyRef.current && usedColumns.length > 0) {
      return;
    }
    prevSchemaKeyRef.current = schemaKey;

    const apiColumns = utilColumnsFromAPI(usedData);

    // Apply custom filterFn to columns that have filterType === 'equal'
    const enhancedApiColumns = apiColumns.map((col) => {
      const colKey = getColumnKey(col);
      if (colKey && filterTypeMap[colKey] === "equal") {
        return {
          ...col,
          filterFn: "equals",
        };
      }
      return col;
    });

    let finalColumns = [];
    let newVisibility = { ...columnVisibility };

    // Check if we're in AllTenants mode and data has Tenant property
    const isAllTenants = settings?.currentTenant === "AllTenants";
    const hasTenantProperty = usedData.some(
      (row) => row && typeof row === "object" && "Tenant" in row,
    );
    const shouldShowTenant = isAllTenants && hasTenantProperty;

    if (columns.length === 0 && configuredSimpleColumns.length === 0) {
      finalColumns = enhancedApiColumns;
      enhancedApiColumns.forEach((col) => {
        const colKey = getColumnKey(col);
        if (colKey) {
          newVisibility[colKey] = true;
        }
      });
    } else if (configuredSimpleColumns.length > 0) {
      // Resolve any variables in the simple columns before checking visibility
      const resolvedSimpleColumns = resolveSubTableSimpleColumns(
        resolveSimpleColumnVariables(configuredSimpleColumns, usedData),
        subTables,
        usedData
      );

      // Add Tenant to resolved columns if in AllTenants mode and not already included
      let finalResolvedColumns = [...resolvedSimpleColumns];
      if (shouldShowTenant && !resolvedSimpleColumns.includes("Tenant")) {
        finalResolvedColumns = [...resolvedSimpleColumns, "Tenant"];
      }

      finalColumns = enhancedApiColumns;
      finalColumns.forEach((col) => {
        const colKey = getColumnKey(col);
        if (colKey) {
          newVisibility[colKey] = finalResolvedColumns.includes(colKey);
        }
      });
      // Selection order wins over data-key order — but only when the resolved selection
      // changed (including subTable cachedColumn swaps), so a data refetch doesn't
      // stomp a manual column reorder.
      const resolvedOrderKey = finalResolvedColumns.join("|");
      if (lastOrderedSelectionRef.current !== resolvedOrderKey) {
        lastOrderedSelectionRef.current = resolvedOrderKey;
        const subTableIds = getSubTableDisplayColumnIds(subTables, configuredSimpleColumns, usedData);
        const allIds = [
          ...new Set([...finalColumns.map((col) => col.id).filter(Boolean), ...subTableIds]),
        ];
        table.setColumnOrder(orderColumnsBySelection(allIds, finalResolvedColumns));
      }
    } else {
      const providedColumnKeys = new Set(
        columns.map((col) => getColumnKey(col) || col.header).filter(Boolean),
      );
      finalColumns = [
        ...columns,
        ...enhancedApiColumns.filter((col) => !providedColumnKeys.has(getColumnKey(col))),
      ];
      finalColumns.forEach((col) => {
        const colKey = getColumnKey(col);
        if (colKey) {
          newVisibility[colKey] = providedColumnKeys.has(colKey);
        }
      });

      // Handle Tenant column for custom columns case
      if (shouldShowTenant) {
        const tenantColumn = finalColumns.find((col) => col.id === "Tenant");
        if (tenantColumn) {
          // Make tenant visible
          newVisibility["Tenant"] = true;
        }
      }
    }
    // Saved preferred columns win over the defaults above. Fields the preference never
    // saw (a different tenant's schema) keep the default computed for this table.
    if (
      preferredColumnVisibility &&
      Object.keys(preferredColumnVisibility).length > 0
    ) {
      Object.assign(newVisibility, preferredColumnVisibility)
    }
    if (defaultSorting?.length > 0) {
      setSorting(defaultSorting);
    }
    setUsedColumns(finalColumns);
    setColumnVisibility(newVisibility);
    // Intentionally rebuilds columns only when the data schema/tenant/query changes
    // (guarded above by schemaKey). columnVisibility/columns/configuredSimpleColumns/
    // defaultSorting are read as the latest values but are deliberately not triggers:
    // this effect sets columnVisibility, so depending on it would risk a rebuild loop.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    columns.length,
    usedData,
    queryKey,
    settings?.currentTenant,
    filterTypeMap,
    subTables,
    preferredColumnVisibility,
  ]);

  // Previous-value refs for the guards below: CippDataTable is the single owner of this
  // state across both toolbar instances, so an effect can compare against the last value
  // it actually saw rather than firing unconditionally on every render.
  const prevTenantRef = useRef(settings?.currentTenant);
  const prevQueryKeyRef = useRef(queryKey || title);
  const prevPageNameRef = useRef(pageName);
  const appliedColumnDefaultsRef = useRef({});

  // if the currentTenant switches, remove graph filters and the active-filter highlight
  useEffect(() => {
    const currentTenant = settings?.currentTenant;
    if (prevTenantRef.current === currentTenant) {
      return;
    }
    prevTenantRef.current = currentTenant;
    if (currentTenant) {
      setGraphFilterData({});
      setActiveFilters({ graph: null, table: null });
      restoredFiltersRef.current.delete(`${pageName}-graph`);
    }
  }, [settings?.currentTenant, pageName]);

  // clear the active-filter highlight when the effective query key changes (tenant swap,
  // different queryKey/title)
  useEffect(() => {
    const effectiveKey = queryKey || title;
    if (prevQueryKeyRef.current === effectiveKey) {
      return;
    }
    prevQueryKeyRef.current = effectiveKey;
    setActiveFilters({ graph: null, table: null });
  }, [queryKey, title]);

  // clear persisted-filter restoration tracking only when the page actually changes
  useEffect(() => {
    if (prevPageNameRef.current === pageName) {
      return;
    }
    prevPageNameRef.current = pageName;
    restoredFiltersRef.current.clear();
  }, [pageName]);

  // apply preferred columns once per page, and again whenever the saved preference's
  // identity changes. Nested dialog tables must not read or write the parent page key.
  // Layered over the current state rather than replacing it: on a static-data table
  // this runs in the same commit as the column build above, and replacing would drop
  // the defaults just computed for every field the preference does not mention.
  useEffect(() => {
    if (!pageName) {
      return;
    }
    const preferred = preferredColumnVisibility;
    if (
      preferred &&
      Object.keys(preferred).length > 0 &&
      appliedColumnDefaultsRef.current[pageName] !== preferred
    ) {
      appliedColumnDefaultsRef.current[pageName] = preferred;
      setColumnVisibility((previous) => ({ ...previous, ...preferred }));
    }
  }, [preferredColumnVisibility, pageName]);

  const createDialog = useDialog();
  const hasActions = !!actions;
  const hasOffCanvas = !!offCanvas;
  const hasOnChange = !!onChange;

  const modeInfo = useMemo(
    () =>
      utilTableMode(
        columnVisibility,
        simple,
        actions,
        configuredSimpleColumns,
        offCanvas,
        onChange,
        maxHeightOffset,
        settings,
        effectiveViewMode,
        isNarrowViewport
      ),
    // Intentionally keyed to stable boolean proxies (hasActions/hasOffCanvas/hasOnChange)
    // and the page-size setting rather than the raw actions/offCanvas/onChange/settings
    // objects, which are re-created every render and would defeat this memo.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [
      simple,
      hasActions,
      hasOffCanvas,
      hasOnChange,
      maxHeightOffset,
      settings?.tablePageSize?.value,
      effectiveViewMode,
      isNarrowViewport,
    ]
  );

  const memoizedColumns = useMemo(() => usedColumns, [usedColumns]);
  // Include updateTrigger in data memo to force re-render when license backfill completes.
  // Also refresh data identity when derived columns change so TanStack re-runs filtering
  // for searches entered before columns are available.
  const memoizedData = useMemo(
    () => (Array.isArray(usedData) ? usedData.slice() : usedData),
    // updateTrigger and usedColumns are intentional cache-busters (license backfill
    // completion + derived-column changes) even though they aren't read in the callback.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [usedData, updateTrigger, usedColumns]
  );

  const sanitizedColumnVisibility = useMemo(() => {
    const result = {};
    for (const key of Object.keys(columnVisibility)) {
      if (key !== "undefined" && key !== undefined) {
        result[key] = columnVisibility[key];
      }
    }
    return result;
  }, [columnVisibility]);

  const displayColumns = useMemo(() => {
    if (!Array.isArray(subTables) || subTables.length === 0) {
      return usedColumns
    }
    const cachedHeaders = new Map()
    const injected = []
    for (const sub of subTables) {
      if (!subTableIsSelected(sub, configuredSimpleColumns)) {
        continue
      }
      if (subTableShowsCachedColumn(sub, usedData)) {
        cachedHeaders.set(sub.cachedColumn, sub.header ?? sub.id)
        continue
      }
      injected.push(buildSubTableColumn(sub))
    }
    const columns = cachedHeaders.size
      ? usedColumns.map((col) =>
          cachedHeaders.has(col.id)
            ? { ...col, header: cachedHeaders.get(col.id) }
            : col
        )
      : usedColumns
    const injectedById = new Map(injected.map((col) => [col.id, col]))
    const replaced = columns.map((col) => injectedById.get(col.id) ?? col)
    const existing = new Set(columns.map((col) => col.id))
    return [...replaced, ...injected.filter((col) => !existing.has(col.id))]
  }, [usedColumns, usedData, subTables, configuredSimpleColumns])

  useEffect(() => {
    if (!Array.isArray(subTables) || subTables.length === 0) {
      return
    }
    setColumnVisibility((prev) => {
      const next = { ...prev }
      let changed = false
      for (const sub of subTables) {
        if (!subTableIsSelected(sub, configuredSimpleColumns)) {
          continue
        }
        const columnId = subTableShowsCachedColumn(sub, usedData)
          ? sub.cachedColumn
          : sub.id
        if (next[columnId] === undefined) {
          next[columnId] = true
          changed = true
        }
      }
      return changed ? next : prev
    })
  }, [subTables, configuredSimpleColumns, usedData])

  const handleActionDisabled = useCallback((row, action) => {
    const actionRow = attachParentRow(row, parentRow)
    if (action?.condition) {
      return !action.condition(actionRow);
    }
    return false;
  }, [parentRow]);

  const getActionRow = useCallback(
    (rowOriginal) => attachParentRow(rowOriginal, parentRow),
    [parentRow]
  );

  const handleSortingChange = useCallback((newSorting) => {
    setSorting(newSorting ?? []);
  }, []);

  const muiTablePaperPropsCallback = useCallback(
    ({ table }) => ({
      sx: {
        ...(table.getState().isFullScreen && {
          position: "fixed !important",
          top: "64px !important",
          bottom: "0 !important",
          left: {
            xs: "0 !important",
            lg: settings?.sidebarCollapse ? "73px !important" : "270px !important",
          },
          right: "0 !important",
          zIndex: "1300 !important",
          m: "0 !important",
          p: "16px !important",
          overflow: "auto",
          bgcolor: "background.paper",
          maxWidth: "none !important",
          width: "auto !important",
          height: "auto !important",
        }),
      },
    }),
    [settings?.sidebarCollapse],
  );

  const queueMessage = getRequestData.data?.pages?.[0]?.Metadata?.QueueMessage;
  const renderEmptyRowsFallbackCallback = useCallback(
    () =>
      queueMessage ? (
        <Box sx={{ py: { xs: 2, md: 4 } }}>
          <center>
            <Info /> {queueMessage}
          </center>
        </Box>
      ) : undefined,
    [queueMessage],
  );

  const showSkeletons = getRequestData.isFetchingNextPage
    ? false
    : getRequestData.isFetching
      ? getRequestData.isFetching
      : isFetching;

  const tableState = useMemo(
    () => ({
      columnVisibility: sanitizedColumnVisibility,
      sorting,
      columnFilters,
      showSkeletons,
    }),
    [sanitizedColumnVisibility, sorting, columnFilters, showSkeletons],
  );

  // Single row-action dispatch used by BOTH the desktop row menu and the mobile action
  // sheet — the two presentations must not drift.
  // `table` is referenced via closure: it is declared below but initialized before any
  // handler can run (the same pattern the row menu has always relied on).
  const dispatchRowAction = useCallback(
    (action, rowOriginal, closeMenu = () => {}) => {
      const scopeToRowTenant = () => {
        const tenant = getRowTenant(getActionRow(rowOriginal), settings.currentTenant)
        if (settings.currentTenant === 'AllTenants' && tenant && tenant !== 'AllTenants') {
          settings.handleUpdate({
            currentTenant: tenant,
          })
        }
      }

      if (action.noConfirm && action.customFunction) {
        scopeToRowTenant()
        action.customFunction(getActionRow(rowOriginal), action, {})
        closeMenu()
        return
      }

      // Handle custom component differently
      if (typeof action.customComponent === 'function') {
        scopeToRowTenant()
        setCustomComponentData({ data: getActionRow(rowOriginal), action: action })
        setCustomComponentVisible(true)
        closeMenu()
        return
      }

      // Standard dialog flow
      setActionData({
        data: getActionRow(rowOriginal),
        action: action,
        ready: true,
      })
      createDialog.handleOpen()
      closeMenu()
    },
    [settings, createDialog, getActionRow]
  )

  // Open the extended-info offcanvas for a row, recording its position in the row model so
  // prev/next navigation works. Shared by the row menu, the mobile action sheet, and card
  // taps. The SORTED model is the one on screen — the filtered model is pre-sort, so a
  // position taken from it stops matching the list the moment a column is sorted.
  const openRowOffCanvas = useCallback((rowOriginal) => {
    setOffCanvasData(rowOriginal)
    const navigable = table.getSortedRowModel().rows
    const indexInList = navigable.findIndex((r) => r.original === rowOriginal)
    setOffCanvasRowIndex(indexInList >= 0 ? indexInList : 0)
    setOffcanvasVisible(true)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // the flipped table shows whatever columns are visible; horizontal scroll covers the width
  const cardViewSurfaceRef = useRef(null)
  const handleViewToggle = useCallback(() => {
    const nextView = effectiveViewMode === 'table' ? 'cards' : 'table'
    setViewOverride(nextView)
    if (nextView === 'table' && isNarrowViewport) {
      scrollNodeToScrollableAncestorTop(cardViewSurfaceRef.current)
    }
  }, [effectiveViewMode, isNarrowViewport])

  const table = useMaterialReactTable({
    layoutMode: "grid-no-grow",
    enableRowVirtualization: true,
    enableColumnVirtualization: true,
    enableColumnResizing: true,
    columnResizeMode: "onChange",
    rowVirtualizerOptions: {
      overscan: 5,
    },
    // Enable density toggle so users can switch to compact on mobile
    enableDensityToggle: true,
    muiTableBodyCellProps: {
      onCopy: (e) => {
        const sel = window.getSelection()?.toString() ?? "";
        if (sel) {
          e.preventDefault();
          e.stopPropagation();
          e.nativeEvent?.stopImmediatePropagation?.();
          e.clipboardData.setData("text/plain", sel);
          if (navigator.clipboard?.writeText) {
            navigator.clipboard.writeText(sel).catch(() => {});
          }
        }
      },
      sx: {
        // Better touch targets on mobile
        ...(isMobile && {
          padding: '12px 8px',
          fontSize: '0.875rem',
        }),
      },
    },
    mrtTheme: (theme) => ({
      baseBackgroundColor: theme.palette.background.paper,
    }),
    muiTablePaperProps: muiTablePaperPropsCallback,
    muiTableBodyRowProps:
      offCanvasOnRowClick && offCanvas
        ? ({ row }) => {
            const customSx =
              typeof rowSx === "function" ? rowSx(row.original) : rowSx ? rowSx : {};
            return {
              onClick: (event) => {
                if (
                  event.target?.closest?.(
                    'button, a, input, textarea, select, [role="button"], [role="menuitem"], [data-no-row-click="true"]',
                  )
                ) {
                  return;
                }
                setOffCanvasData(row.original);
                const filteredRowsArray = table.getFilteredRowModel().rows;
                const indexInFiltered = filteredRowsArray.findIndex(
                  (r) => r.original === row.original,
                );
                setOffCanvasRowIndex(indexInFiltered >= 0 ? indexInFiltered : 0);
                setOffcanvasVisible(true);
              },
              sx: {
                cursor: "pointer",
                "&:hover": {
                  backgroundColor: "action.hover",
                },
                ...customSx,
              },
            };
          }
        : rowSx
          ? ({ row }) => ({
              sx: typeof rowSx === "function" ? rowSx(row.original) : rowSx,
            })
          : undefined,
    // Add global styles to target the specific filter components
    enableColumnFilterModes: true,
    muiTableHeadCellProps: {
      sx: {
        // Target the filter row cells
        "& .MuiTableCell-root": {
          padding: "8px 16px",
        },
        // Target the Autocomplete component in filter cells
        "& .MuiAutocomplete-root": {
          width: "100%",
        },
        // Force the tags container to be single line with ellipsis
        "& .MuiAutocomplete-root .MuiInputBase-root": {
          height: "40px !important",
          overflow: "hidden",
          textOverflow: "ellipsis",
          whiteSpace: "nowrap",
          display: "flex",
          flexWrap: "nowrap",
        },
        // Target the tags container specifically
        "& .MuiAutocomplete-root .MuiInputBase-root .MuiInputBase-input": {
          height: "24px",
          minHeight: "24px",
          maxHeight: "24px",
        },
        // Target regular input fields (not in Autocomplete)
        "& .MuiInputBase-root": {
          height: "40px !important",
        },
        // Ensure all input fields have consistent styling
        "& .MuiInputBase-input": {
          height: "24px",
          minHeight: "24px",
          maxHeight: "24px",
        },
        // Target the specific chip class mentioned
        "& .MuiChip-label.MuiChip-labelMedium": {
          maxWidth: "80px",
          overflow: "hidden",
          textOverflow: "ellipsis",
          whiteSpace: "nowrap",
          padding: "0 4px",
        },
        // Make chips smaller overall and add title attribute for tooltip
        "& .MuiChip-root": {
          height: "24px",
          maxHeight: "24px",
          // This adds a tooltip effect using the browser's native tooltip
          "&::before": {
            content: "attr(data-label)",
            display: "none",
          },
          "&:hover::before": {
            display: "block",
            position: "absolute",
            top: "-25px",
            left: "0",
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            color: "white",
            padding: "4px 8px",
            borderRadius: "4px",
            fontSize: "12px",
            whiteSpace: "nowrap",
            zIndex: 9999,
          },
        },
      },
    },
    // Initialize the filter chips with data attributes for tooltips
    initialState: {
      columnFilters: columnFilters,
      columnVisibility: sanitizedColumnVisibility,
    },
    columns: displayColumns,
    data: memoizedData ?? EMPTY_ARRAY,
    state: tableState,
    onSortingChange: handleSortingChange,
    onColumnFiltersChange: setColumnFilters,
    renderEmptyRowsFallback: renderEmptyRowsFallbackCallback,
    onColumnVisibilityChange: setColumnVisibility,
    ...modeInfo,
    enableRowActions: showRowActionsMenu && (actions || offCanvas) ? true : false,
    renderRowActionMenuItems: actions && showRowActionsMenu
      ? ({ closeMenu, row }) => {
          // Group actions by category
          const groupedActions = actions.reduce((acc, action) => {
            const category =
              typeof action.category === "string" && action.category.trim().length > 0
                ? action.category.trim()
                : "Other";
            if (!acc[category]) {
              acc[category] = [];
            }
            acc[category].push(action);
            return acc;
          }, {});
          
          const categoryEntries = sortCategoryEntries(Object.entries(groupedActions));
          
          return [
            ...categoryEntries.flatMap(([category, categoryActions], groupIndex) => {
              const categoryColor = getCategoryColor(category);
              const headerBgColor = categoryColor === "text.secondary" 
                ? (theme) => alpha(theme.palette.grey[500], 0.08)
                : (theme) => alpha(resolvePaletteMainColor(theme, categoryColor), 0.08);
              const headerTextColor = categoryColor === "text.secondary"
                ? "text.secondary"
                : (theme) => resolvePaletteMainColor(theme, categoryColor);
              
              return [
                <ListSubheader
                  key={`category-header-${category}`}
                  disableSticky
                  sx={{
                    bgcolor: headerBgColor,
                    color: headerTextColor,
                    fontSize: "0.7rem",
                    fontWeight: 600,
                    lineHeight: "28px",
                    display: "flex",
                    alignItems: "center",
                    gap: 0.5,
                    textTransform: "uppercase",
                    letterSpacing: "0.5px",
                    py: 0.5,
                  }}
                >
                  {getCategoryIcon(category)}
                  {getCategoryLabel(category)}
                </ListSubheader>,
                ...categoryActions
                .filter(
                  (action) =>
                    typeof action.hideCondition !== "function" ||
                    !action.hideCondition(getActionRow(row.original))
                )
                .map((action, index) => {
                  const actionColor = action.color || categoryColor;
                  const iconSx =
                    actionColor === "text.secondary"
                      ? { minWidth: "30px", color: actionColor }
                      : { minWidth: "30px", color: (theme) => resolvePaletteMainColor(theme, actionColor) };
                  
                  return (
                    <MenuItem
                      key={`${category}-${index}`}
                      onClick={() => dispatchRowAction(action, row.original, closeMenu)}
                      disabled={handleActionDisabled(row.original, action)}
                    >
                      <SvgIcon fontSize="small" sx={iconSx}>
                        {action.icon}
                      </SvgIcon>
                      <ListItemText>{action.label}</ListItemText>
                    </MenuItem>
                  );
                }),
              ];
            }),
            offCanvas && (
              <MenuItem
                key={`actions-list-row-more`}
                onClick={() => {
                  closeMenu();
                  openRowOffCanvas(row.original);
                }}
              >
                <SvgIcon fontSize="small" sx={{ minWidth: "30px" }}>
                  <MoreHoriz />
                </SvgIcon>
                More Info
              </MenuItem>
            ),
          ];
        }
      : offCanvas
        ? ({ closeMenu, row }) => [
            <MenuItem
              key="offcanvas-more-info"
              onClick={() => {
                closeMenu();
                openRowOffCanvas(row.original);
              }}
            >
              <ListItemIcon>
                <More fontSize="small" />
              </ListItemIcon>
              More Info
            </MenuItem>,
          ]
        : undefined,
    renderTopToolbar: ({ table }) => {
      return (
        <>
          {!simple && (
            <CIPPTableToptoolbar
              table={table}
              api={api}
              queryKey={queryKey}
              simpleColumns={simpleColumns}
              data={data}
              columnVisibility={columnVisibility}
              getRequestData={getRequestData}
              usedColumns={displayColumns ?? memoizedColumns}
              usedData={memoizedData ?? EMPTY_ARRAY}
              title={title}
              actions={actions}
              exportEnabled={exportEnabled}
              refreshFunction={refreshFunction}
              setColumnVisibility={setColumnVisibility}
              filters={filters}
              queryKeys={queryKey ? queryKey : title}
              graphFilterData={graphFilterData}
              setGraphFilterData={setGraphFilterData}
              setConfiguredSimpleColumns={setConfiguredSimpleColumns}
              queueMetadata={getRequestData.data?.pages?.[0]?.Metadata}
              rowActionQueueIds={rowActionQueueIds}
              onRemoveRowActionQueueId={(id) =>
                setRowActionQueueIds((prev) => prev.filter((qid) => qid !== id))
              }
              isInDialog={isInDialog}
              showBulkExportAction={showBulkExportAction}
              viewMode={viewMode}
              onViewModeChange={handleViewModeChange}
              cardConfigAvailable={!!effectiveCardConfig}
              dataFreshnessField={dataFreshnessField}
              searchValue={searchValue || cardSearchInput}
              onSearchChange={setCardSearchInput}
              setSearchValue={setSearchValue}
              persistenceKey={persistenceKey}
              parentRow={parentRow}
              onViewToggle={toggleAllowed ? handleViewToggle : undefined}
              tableViewActive={toggleAllowed ? tableViewActive : undefined}
              showReturnToCards={showReturnToCards}
              bulkActionsSlot={isNarrowViewport && !isInDialog ? headerBulkSlot : null}
              dataSourceControls={dataSourceControls}
              activeFilters={activeFilters}
              setActiveFilters={setActiveFilters}
              restoredFiltersRef={restoredFiltersRef}
              searchFocusRef={searchFocusRef}
            />
          )}
        </>
      );
    },
    ...(isNarrowViewport &&
      effectiveViewMode === "table" && {
        muiTableContainerProps: {
          ...modeInfo.muiTableContainerProps,
          sx: {
            ...modeInfo.muiTableContainerProps?.sx,
            maxHeight: narrowTableMaxHeight ? `${narrowTableMaxHeight}px` : "none",
          },
        },
      }),
    sortingFns: SORTING_FNS,
    filterFns: FILTER_FNS,
    globalFilterFn: "contains",
    enableGlobalFilterModes: true,
    renderGlobalFilterModeMenuItems: ({ internalFilterOptions, onSelectFilterMode }) => {
      // add custom filter options
      const customFilterOptions = [
        {
          option: "regex",
          label: "Regex",
          symbol: "(.*)",
        },
      ];

      // add to the internalFilterOptions if not already present
      customFilterOptions.forEach((filterOption) => {
        if (!internalFilterOptions.some((option) => option.option === filterOption.option)) {
          internalFilterOptions.push(filterOption);
        }
      });

      return internalFilterOptions.map((filterOption) => (
        <MenuItem
          key={filterOption.option}
          onClick={() => onSelectFilterMode(filterOption.option)}
          sx={{
            display: "flex",
            alignItems: "center",
            gap: "0.5rem",
          }}
        >
          <span style={{ width: "20px", textAlign: "center" }}>{filterOption.symbol}</span>
          <ListItemText>{filterOption.label}</ListItemText>
        </MenuItem>
      ));
    },
    renderColumnFilterModeMenuItems: ({ internalFilterOptions, onSelectFilterMode }) => {
      // add custom filter options
      const customFilterOptions = [
        {
          option: "notContains",
          label: "Not Contains",
          symbol: "!*",
        },
        {
          option: "regex",
          label: "Regex",
          symbol: "(.*)",
        },
      ];

      // combine default and custom filter options
      const combinedFilterOptions = [...internalFilterOptions, ...customFilterOptions];

      return combinedFilterOptions.map((filterOption) => (
        <MenuItem
          key={filterOption.option}
          onClick={() => onSelectFilterMode(filterOption.option)}
          sx={{
            display: "flex",
            alignItems: "center",
            gap: "0.5rem",
          }}
        >
          <span style={{ width: "20px", textAlign: "center" }}>{filterOption.symbol}</span>
          <ListItemText>{filterOption.label}</ListItemText>
        </MenuItem>
      ));
    },
  });

  // Note: Filter application is handled by setTableFilter in CIPPTableToptoolbar when user selects a filter.
  // The `filters` prop contains filter OPTIONS for the dropdown menu, not active filters to apply.

  // deselect all rows when the underlying data set actually changes, guarded so a toolbar
  // remount (cards<->table flip) does not wipe an in-progress selection
  const prevUsedDataRef = useRef(memoizedData)
  useEffect(() => {
    if (prevUsedDataRef.current === memoizedData) {
      return
    }
    prevUsedDataRef.current = memoizedData
    table.toggleAllRowsSelected(false)
  }, [memoizedData])

  // utilTableMode seeds columnOrder from simpleColumns (e.g. "members"), but cached report
  // data shows membersCsv instead — MRT crashes if order references ids that are not in
  // displayColumns.
  useEffect(() => {
    if (!Array.isArray(subTables) || subTables.length === 0) {
      return
    }
    const displayIds = displayColumns.map((col) => col.id).filter(Boolean)
    if (displayIds.length === 0) {
      return
    }
    const currentOrder = table.getState().columnOrder ?? []
    if (!columnOrderHasStaleIds(currentOrder, displayIds)) {
      return
    }
    const selectedForOrder = resolveSubTableSimpleColumns(
      configuredSimpleColumns,
      subTables,
      usedData
    ).filter((id) => displayIds.includes(id))
    table.setColumnOrder(orderColumnsBySelection(displayIds, selectedForOrder))
  }, [configuredSimpleColumns, displayColumns, subTables, usedData, table])

  // size the narrow table's scroll viewport from where it actually sits: viewport height
  // minus the container's measured top, the real footer height and the chrome below the
  // paper. the desktop calc assumes chrome heights that phone layouts do not have.
  // deps include getRequestData.isSuccess so a cold load (table not yet mounted when the
  // toggle flips tableViewActive true) re-arms the measurement once MRT actually renders
  useEffect(() => {
    if (!(isNarrowViewport && tableViewActive)) {
      setNarrowTableMaxHeight(null)
      return undefined
    }
    const measure = () => {
      const container = table.refs.tableContainerRef?.current
      if (!container) {
        return
      }
      const footer = table.refs.bottomToolbarRef?.current?.offsetHeight ?? 0
      // chrome between the paper's bottom edge and the page bottom (CardContent padding + page gap)
      const BELOW_PAPER_PX = 40
      // viewport-relative, the toggle handler aligns the card surface with the scroll
      // viewport top first so this reads a deterministic position
      const top = container.getBoundingClientRect().top
      let next = Math.max(240, Math.floor(window.innerHeight - top - footer - BELOW_PAPER_PX))
      // 120 = minimal chrome allowance, keeps the table from claiming the full viewport
      next = Math.min(next, window.innerHeight - 120)
      setNarrowTableMaxHeight((prev) => {
        if (prev !== null && Math.abs(prev - next) <= 1) {
          return prev
        }
        return next
      })
    }
    const raf = requestAnimationFrame(() => requestAnimationFrame(measure))
    window.addEventListener('resize', measure)
    let observer
    // the paper mounts in the same commit as the container and the footer, so it is a
    // reliable observation target even on the pass where the footer ref is still null
    const paper = table.refs.tablePaperRef?.current
    if (typeof ResizeObserver !== 'undefined' && paper) {
      observer = new ResizeObserver(measure)
      observer.observe(paper)
    }
    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('resize', measure)
      observer?.disconnect()
    }
  }, [isNarrowViewport, tableViewActive, table, getRequestData.isSuccess])

  // A card shows at most a title, subtitle, three chips and three detail rows, so the rest
  // of the row has to live in the drawer. On a page with no offCanvas that means every
  // column the user has chosen to show; on a page that configured one, its curated fields
  // come first and the remaining visible columns are appended rather than dropped — on
  // desktop those columns are still on screen in the table, on mobile they are not.
  const cardInfoFields = useMemo(() => {
    if (!isCardView) return undefined
    // A page that renders its own drawer body (offCanvas.children — the test-detail pages)
    // is the authority on what the drawer shows; prepending the generic property list on
    // top of it repeated Risk/Status above a body that already presents them.
    if (offCanvas?.children) return undefined
    const visible = table
      .getVisibleLeafColumns()
      .map((column) => column.id)
      .filter((id) => !id.startsWith('mrt-'))
    const curated = offCanvas?.extendedInfoFields
    if (!curated?.length) return visible
    // Curated order wins; dedupe case-insensitively across both lists, and within the
    // curated list itself, so a field can't be shown twice.
    const seen = new Set()
    return [...curated, ...visible].filter((id) => {
      if (typeof id !== 'string') return false
      const key = id.toLowerCase()
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [offCanvas, isCardView, table, columnVisibility, usedColumns])

  // Applied after the {...offCanvas} spread below, which carries the page's own
  // extendedInfoFields and would otherwise overwrite the merged list. Card view renders
  // them the way the table cells do, since the appended entries are columns.
  const cardInfoOverride =
    isCardView && cardInfoFields?.length
      ? { extendedInfoFields: cardInfoFields, richFormatting: true }
      : {}

  // The rows the drawer's Prev/Next walks, in the order they are on screen. Read live from
  // the table on every render: this used to be mirrored into state by an effect keyed on
  // filters and sorting, so the copy was taken once at mount — before the rows had arrived
  // — and every table that loads its data asynchronously reported nothing to navigate.
  const navigationRows = table.getSortedRowModel().rows
  // Prefer the position of the row actually on show, so sorting or filtering while the
  // drawer is open carries the counter with it. The stored index covers the case where the
  // row has left the list entirely — a background refetch replaces every object, so
  // identity alone would strand the position — and is clamped so a list that shrank under
  // it can't report "6 of 2".
  const derivedRowIndex = offcanvasVisible
    ? navigationRows.findIndex((row) => row.original === offCanvasData)
    : -1
  const currentRowIndex =
    derivedRowIndex >= 0
      ? derivedRowIndex
      : Math.min(offCanvasRowIndex, Math.max(navigationRows.length - 1, 0))

  // Remove the useEffect that was resetting filters on table changes
  // The initial filter application is now handled by the columnFilters state
  // and the useEffect above that only triggers on actual filter prop changes

  // Exiting mobile select mode clears the selection — "Done" means done.
  const handleMobileSelectModeChange = useCallback(
    (on) => {
      setMobileSelectMode(on)
      if (!on) {
        table.toggleAllRowsSelected(false)
      }
    },
    [table]
  )

  // Empty-state "Clear filters" in the card list. The full reset (graph filters,
  // persisted slots) lives in the toolbar's filter sheet; this only clears what makes
  // the current list empty.
  const handleClearAllFilters = useCallback(() => {
    table.resetGlobalFilter()
    table.resetColumnFilters()
  }, [table])

  useEffect(() => {
    if (table?.setGlobalFilter) {
      table.setGlobalFilter(cardSearchInput);
    }
  }, [cardSearchInput, table]);

  // Extract the selected-row model so the dependency is statically analyzable.
  const selectedRowModelRows = table.getSelectedRowModel().rows;
  useEffect(() => {
    if (onChange && selectedRowModelRows) {
      onChange(selectedRowModelRows.map((row) => row.original));
    }
    // Intentionally keyed only to the selection. `onChange` is a caller-supplied prop
    // that is frequently re-created each render; including it would re-fire on every
    // parent render (and risk render loops) without changing the selection.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedRowModelRows]);

  // Extract table state slices to keep the dependency array statically analyzable.
  const { columnFilters: tableColumnFilters, globalFilter: tableGlobalFilter, sorting: tableSorting } =
    table.getState();
  useEffect(() => {
    // Update filtered rows whenever table filtering/sorting changes
    if (table && table.getFilteredRowModel) {
      const rows = table.getFilteredRowModel().rows;
      setFilteredRows(rows.map((row) => row.original));
    }
  }, [table, tableColumnFilters, tableGlobalFilter, tableSorting]);

  useEffect(() => {
    //check if the simplecolumns are an array,
    if (Array.isArray(simpleColumns) && simpleColumns.length > 0) {
      setConfiguredSimpleColumns(simpleColumns);
    }
  }, [simpleColumns]);

  // Render the standalone toolbar for card view (not embedded in table)
  const renderStandaloneToolbar = () => {
    if (simple) return null;
    return (
      <CIPPTableToptoolbar
        table={table}
        api={api}
        queryKey={queryKey}
        simpleColumns={simpleColumns}
        data={data}
        columnVisibility={columnVisibility}
        getRequestData={getRequestData}
        usedColumns={memoizedColumns}
        usedData={memoizedData ?? []}
        title={title}
        actions={actions}
        exportEnabled={exportEnabled}
        refreshFunction={refreshFunction}
        setColumnVisibility={setColumnVisibility}
        filters={filters}
        queryKeys={queryKey ? queryKey : title}
        graphFilterData={graphFilterData}
        setGraphFilterData={setGraphFilterData}
        setConfiguredSimpleColumns={setConfiguredSimpleColumns}
        queueMetadata={getRequestData.data?.pages?.[0]?.Metadata}
        rowActionQueueIds={rowActionQueueIds}
        onRemoveRowActionQueueId={(id) =>
          setRowActionQueueIds((prev) => prev.filter((qid) => qid !== id))
        }
        isInDialog={isInDialog}
        showBulkExportAction={showBulkExportAction}
        viewMode={viewMode}
        onViewModeChange={handleViewModeChange}
        cardConfigAvailable={!!effectiveCardConfig}
        isCardView={true}
        dataFreshnessField={dataFreshnessField}
        searchValue={searchValue || cardSearchInput}
        onSearchChange={setCardSearchInput}
        setSearchValue={setSearchValue}
        setColumnFilters={setColumnFilters}
        persistenceKey={persistenceKey}
        parentRow={parentRow}
        activeFilters={activeFilters}
        setActiveFilters={setActiveFilters}
        restoredFiltersRef={restoredFiltersRef}
        onViewToggle={toggleAllowed ? handleViewToggle : undefined}
        dataSourceControls={dataSourceControls}
      />
    );
  };

  const selectModeActive = hasOnChange ? true : mobileSelectMode

  const resolvedCardButton = cardButton ? (
    <CippTableCardButton cardButton={cardButton} row={parentRow} />
  ) : undefined

  // below md, table-in-Card branch: the actions FAB carries cardButton
  const headerAction = isNarrowViewport && !isInDialog ? undefined : resolvedCardButton

  return (
    <>
      {/* Card View (mobile or desktop when card mode selected) */}
      {showCardView ? (
        <Card style={{ width: "100%" }} {...props.cardProps}>
          {cardButton || !hideTitle ? (
            <>
              <CardHeader
                action={cardButton}
                title={hideTitle ? "" : title}
                {...props.cardHeaderProps}
              />
              <Divider />
            </>
          ) : null}
          {/* Standalone toolbar for card view on desktop */}
          {!isMobile && (
            <Box sx={{ px: 2, pt: 2 }}>
              {renderStandaloneToolbar()}
            </Box>
          )}
          {getRequestData.isError && !getRequestData.isFetchNextPageError ? (
            <CardContent>
              <ResourceError
                onReload={() => getRequestData.refetch()}
                message={`Error Loading data: ${getCippError(getRequestData.error)}`}
              />
            </CardContent>
          ) : (
            <CardView
              data={usedData}
              config={effectiveCardConfig}
              // Only show full-card skeletons for the initial load.
              // Background refetches should not hide already loaded cards.
              isLoading={(!Array.isArray(usedData) || usedData.length === 0) && (getRequestData.isLoading || isFetching)}
              searchTerm={debouncedCardSearchTerm}
              searchInput={cardSearchInput}
              onSearchChange={setCardSearchInput}
              onRefresh={refreshFunction || (api?.url ? () => getRequestData.refetch() : null)}
              title={title}
              isMobile={isMobile}
              actions={actions}
              tenant={settings?.currentTenant}
              showSearch={isMobile || simple}
              offCanvas={offCanvas}
              setOffCanvasData={setOffCanvasData}
              setOffCanvasRowIndex={setOffCanvasRowIndex}
              setOffcanvasVisible={setOffcanvasVisible}
              onCardClick={onCardClick}
              editApiUrl={effectiveCardConfig?.editApiUrl}
              queryKey={effectiveQueryKey}
              columnFilters={columnFilters}
              // Lazy loading props - only fetch more data when user navigates past loaded data
              hasNextPage={getRequestData.hasNextPage}
              onLoadMore={getRequestData.fetchNextPage}
              isFetchingNextPage={getRequestData.isFetchingNextPage}
            />
          )}
        </Card>
      ) : isCardView ? (
        // same paper surface as the table path; overflow visible keeps the controls bar sticky
        <CardViewSurface
          ref={cardViewSurfaceRef}
          data-testid="cipp-card-view"
          {...(noCard
            ? {}
            : { sx: { width: '100%', overflow: 'visible' }, ...props.cardProps })}
        >
          {!hideTitle && (
            <Box
              sx={{
                // Embedded in another card (noCard) or a dialog, the host already pays a
                // 16px gutter — the list's own 8px would double it, so the whole card
                // presentation (title, controls, cards) drops to the host's edge together.
                px: isInDialog || noCard ? 0 : 1,
                pt: 1,
                pb: 0.5,
                display: 'flex',
                alignItems: 'baseline',
                gap: 1,
                minWidth: 0,
              }}
            >
              <Typography variant="h6" noWrap sx={{ minWidth: 0 }}>
                {title}
              </Typography>
              {Array.isArray(usedData) && !showSkeletons && (
                <Typography
                  variant="caption"
                  color="text.secondary"
                  sx={{ flexShrink: 0 }}
                >
                  {table.getFilteredRowModel().rows.length} results
                </Typography>
              )}
            </Box>
          )}
          {!Array.isArray(usedData) && usedData ? (
            <ResourceUnavailable message={incorrectDataMessage} />
          ) : (
            <>
              <CIPPTableToptoolbar
                table={table}
                api={api}
                queryKey={queryKey}
                simpleColumns={simpleColumns}
                data={data}
                columnVisibility={columnVisibility}
                getRequestData={getRequestData}
                usedColumns={displayColumns}
                usedData={memoizedData ?? EMPTY_ARRAY}
                title={title}
                actions={actions}
                exportEnabled={exportEnabled}
                refreshFunction={refreshFunction}
                setColumnVisibility={setColumnVisibility}
                filters={filters}
                queryKeys={queryKey ? queryKey : title}
                graphFilterData={graphFilterData}
                setGraphFilterData={setGraphFilterData}
                setConfiguredSimpleColumns={setConfiguredSimpleColumns}
                queueMetadata={getRequestData.data?.pages?.[0]?.Metadata}
                persistenceKey={persistenceKey}
                parentRow={parentRow}
                isInDialog={isInDialog}
                embedded={isInDialog || noCard}
                showBulkExportAction={showBulkExportAction}
                viewMode="cards"
                selectMode={selectModeActive}
                onSelectModeChange={
                  hasOnChange ? undefined : handleMobileSelectModeChange
                }
                selectModeLocked={hasOnChange}
                onViewToggle={toggleAllowed ? handleViewToggle : undefined}
                tableViewActive={toggleAllowed ? tableViewActive : undefined}
                dataSourceControls={dataSourceControls}
                activeFilters={activeFilters}
                setActiveFilters={setActiveFilters}
                searchValue={searchValue}
                setSearchValue={setSearchValue}
                restoredFiltersRef={restoredFiltersRef}
              />
              <CippMobileCardList
                table={table}
                actions={actions}
                hasOffCanvas={!!offCanvas || Boolean(cardInfoFields?.length)}
                onRowAction={dispatchRowAction}
                onMoreInfo={openRowOffCanvas}
                isActionDisabled={handleActionDisabled}
                getActionRow={getActionRow}
                selectMode={selectModeActive}
                cardButton={resolvedCardButton}
                mobileCard={mobileCard}
                fixedChrome={!isInDialog && !noCard}
                onClearFilters={handleClearAllFilters}
                isStreaming={getRequestData.isFetching && !showSkeletons}
                queueMessage={queueMessage}
              />
            </>
          )}
          {getRequestData.isError && !getRequestData.isFetchNextPageError && (
            <ResourceError
              onReload={() => getRequestData.refetch()}
              message={`Error Loading data:  ${getCippError(getRequestData.error)}`}
            />
          )}
        </CardViewSurface>
      ) : noCard ? (
        <Scrollbar>
          {!Array.isArray(usedData) && usedData ? (
            <ResourceUnavailable message={incorrectDataMessage} />
          ) : (
            <>
              {(getRequestData.isSuccess || getRequestData.data?.pages?.length >= 0 || data) && (
                <MaterialReactTable table={table} />
              )}
            </>
          )}
          {getRequestData.isError && !getRequestData.isFetchNextPageError && (
            <ResourceError
              onReload={() => getRequestData.refetch()}
              message={`Error Loading data:  ${getCippError(getRequestData.error)}`}
            />
          )}
        </Scrollbar>
      ) : (
        // Render the table inside a Card
        <>
          <Card style={{ width: '100%' }} {...props.cardProps}>
            {cardButton || !hideTitle ? (
              <>
                <CardHeader
                  action={
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                      <Box
                        ref={setHeaderBulkSlot}
                        sx={{ display: 'flex', alignItems: 'center', gap: 1 }}
                      />
                      {/* narrow viewports carry these in the Table options sheet */}
                      {dataSourceControls && !isNarrowViewport ? (
                        <Stack direction='row' spacing={1} alignItems='center'>
                          {dataSourceControls}
                          {headerAction}
                        </Stack>
                      ) : (
                        headerAction
                      )}
                    </Box>
                  }
                  title={hideTitle ? '' : title}
                  {...props.cardHeaderProps}
                />
                <Divider />
              </>
            ) : null}
            <CardContent sx={{ padding: '1rem' }}>
              <Scrollbar>
                {!Array.isArray(usedData) && usedData ? (
                  <ResourceUnavailable message={incorrectDataMessage} />
                ) : (
                  <>
                    {(getRequestData.isSuccess ||
                      getRequestData.data?.pages.length >= 0 ||
                      (data && !getRequestData.isError)) && (
                      <MaterialReactTable table={table} />
                    )}
                  </>
                )}
                {getRequestData.isError &&
                  !getRequestData.isFetchNextPageError && (
                    <ResourceError
                      onReload={() => getRequestData.refetch()}
                      message={`Error Loading data:  ${getCippError(getRequestData.error)}`}
                    />
                  )}
              </Scrollbar>
            </CardContent>
          </Card>
          {isNarrowViewport && !isInDialog && resolvedCardButton && (
            <CippPageActionsFab title="Actions">{resolvedCardButton}</CippPageActionsFab>
          )}
        </>
      )}
      <CippOffCanvas
        isFetching={getRequestData.isFetching}
        visible={offcanvasVisible}
        onClose={() => setOffcanvasVisible(false)}
        extendedData={offCanvasData}
        extendedInfoFields={offCanvas?.extendedInfoFields}
        title={offCanvasData?.Name || offCanvas?.title || 'Extended Info'}
        aboveModal={isInDialog}
        children={
          offCanvas?.children
            ? (row) => offCanvas.children(row, currentRowIndex)
            : undefined
        }
        customComponent={offCanvas?.customComponent}
        onNavigateUp={() => {
          const newIndex = currentRowIndex - 1
          if (newIndex >= 0 && navigationRows[newIndex]) {
            setOffCanvasRowIndex(newIndex)
            setOffCanvasData(navigationRows[newIndex].original)
          }
        }}
        onNavigateDown={() => {
          const newIndex = currentRowIndex + 1
          if (navigationRows[newIndex]) {
            setOffCanvasRowIndex(newIndex)
            setOffCanvasData(navigationRows[newIndex].original)
          }
        }}
        canNavigateUp={currentRowIndex > 0}
        canNavigateDown={currentRowIndex < navigationRows.length - 1}
        navigationPosition={{
          index: currentRowIndex + 1,
          total: navigationRows.length,
        }}
        {...offCanvas}
        {...cardInfoOverride}
        // Retired: the drawer's action buttons never dispatched reliably, and the row menu
        // is the actions surface. Last so it beats page configs carrying offCanvas.actions.
        actions={undefined}
      />
      {/* Render custom component */}
      {customComponentVisible &&
        customComponentData?.action &&
        typeof customComponentData.action.customComponent === "function" &&
        customComponentData.action.customComponent(customComponentData.data, {
          drawerVisible: customComponentVisible,
          setDrawerVisible: setCustomComponentVisible,
          fromRowAction: true,
        })}

      {/* Render standard dialog */}
      {useMemo(() => {
        if (
          !actionData.ready ||
          (actionData.action && typeof actionData.action.customComponent === "function")
        )
          return null;
        return (
          <CippApiDialog
            createDialog={createDialog}
            title="Confirmation"
            fields={actionData.action?.fields}
            api={actionData.action}
            row={actionData.data}
            {...actionData.action}
            onActionSuccess={(response) => {
              if (response?.data?.Queued && response?.data?.QueueId) {
                setRowActionQueueIds((prev) => [...prev, response.data.QueueId]);
              }
            }}
            relatedQueryKeys={[
              ...(queryKey ? [queryKey] : title ? [title] : []),
              ...(Array.isArray(actionData.action?.relatedQueryKeys)
                ? actionData.action.relatedQueryKeys
                : actionData.action?.relatedQueryKeys
                  ? [actionData.action.relatedQueryKeys]
                  : []),
            ].filter(Boolean)}
          />
        );
      }, [actionData.ready, createDialog, actionData.action, actionData.data, queryKey, title])}
    </>
  );
};
