import React, { useState } from "react";
import PropTypes from "prop-types";
import {
  Chip,
  Stack,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  Button,
  CircularProgress,
  Alert,
  Tooltip,
  Typography,
  Box,
} from "@mui/material";
import { Close, Business } from "@mui/icons-material";
import { alpha, useTheme } from "@mui/material/styles";
import { ApiPostCall } from "../../api/ApiCall";
import { useQueryClient } from "@tanstack/react-query";

/**
 * Component that displays tenants as chips with an X button to remove them.
 * Used for managing tenants in templates (both included and excluded tenants).
 */
export const CippRemovableTenantChips = ({
  tenants,
  templateId,
  templateName,
  templateData,
  fieldName, // 'tenantFilter' or 'excludedTenants'
  queryKey,
  maxDisplay = 5,
  emptyMessage = "None",
}) => {
  const theme = useTheme();
  const queryClient = useQueryClient();
  const [removeDialog, setRemoveDialog] = useState({
    open: false,
    tenant: null,
  });
  const [isRemoving, setIsRemoving] = useState(false);
  const [error, setError] = useState(null);
  const [showAll, setShowAll] = useState(false);

  const updateTemplateMutation = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: [queryKey],
  });

  // Normalize tenants to array
  const tenantList = React.useMemo(() => {
    if (!tenants) return [];
    if (Array.isArray(tenants)) return tenants;
    if (typeof tenants === "string") {
      // Could be a single tenant or comma-separated list
      if (tenants === "AllTenants") return ["AllTenants"];
      return [tenants];
    }
    return [];
  }, [tenants]);

  const handleRemoveClick = (tenant, e) => {
    e.stopPropagation();
    setRemoveDialog({ open: true, tenant });
    setError(null);
  };

  const handleDialogClose = () => {
    setRemoveDialog({ open: false, tenant: null });
    setError(null);
  };

  // Helper to filter out corrupted/invalid tenant entries
  const cleanTenantArray = (tenants, tenantToRemove) => {
    if (!tenants) return [];
    const arr = Array.isArray(tenants) ? tenants : [tenants];
    return arr.filter((t) => {
      // Filter out the tenant being removed
      if (t === tenantToRemove || t?.value === tenantToRemove) return false;
      // Filter out corrupted data (field names stored as values)
      if (t === "excludedTenants" || t === "tenantFilter") return false;
      // Filter out empty/null values
      if (!t) return false;
      return true;
    });
  };

  const handleRemoveTenant = async () => {
    const { tenant } = removeDialog;
    setIsRemoving(true);
    setError(null);

    try {
      // Create updated template data
      const updatedTemplate = { ...templateData };

      if (fieldName === "tenantFilter") {
        updatedTemplate.tenantFilter = cleanTenantArray(updatedTemplate.tenantFilter, tenant);
      } else if (fieldName === "excludedTenants") {
        updatedTemplate.excludedTenants = cleanTenantArray(updatedTemplate.excludedTenants, tenant);
      }

      // Also clean the other field to remove any corrupted data
      if (updatedTemplate.excludedTenants) {
        updatedTemplate.excludedTenants = cleanTenantArray(updatedTemplate.excludedTenants, null);
      }

      await updateTemplateMutation.mutateAsync({
        url: "/api/AddStandardsTemplate",
        data: updatedTemplate,
      });

      // Invalidate queries to refresh data
      queryClient.invalidateQueries({ queryKey: [queryKey] });

      handleDialogClose();
    } catch (err) {
      console.error("Failed to remove tenant:", err);
      setError(err.message || "Failed to remove tenant from template");
    } finally {
      setIsRemoving(false);
    }
  };

  // Get display name for tenant
  const getTenantDisplayName = (tenant) => {
    if (typeof tenant === "object" && tenant !== null) {
      return tenant.label || tenant.value || tenant.displayName || "Unknown";
    }
    return tenant || "Unknown";
  };

  // Get tenant value for comparison
  const getTenantValue = (tenant) => {
    if (typeof tenant === "object" && tenant !== null) {
      return tenant.value || tenant.label || tenant.displayName;
    }
    return tenant;
  };

  if (tenantList.length === 0) {
    return (
      <Typography variant="body2" color="text.secondary">
        {emptyMessage}
      </Typography>
    );
  }

  const displayTenants = showAll ? tenantList : tenantList.slice(0, maxDisplay);
  const hiddenCount = tenantList.length - maxDisplay;
  const isExcludedField = fieldName === "excludedTenants";

  return (
    <>
      <Stack
        direction="row"
        spacing={0.5}
        flexWrap="wrap"
        useFlexGap
        sx={{ maxWidth: "100%" }}
      >
        {displayTenants.map((tenant, index) => {
          const displayName = getTenantDisplayName(tenant);
          const isAllTenants = displayName === "AllTenants";

          return (
            <Tooltip
              key={index}
              title={
                isAllTenants
                  ? "All Tenants - Cannot be removed"
                  : `Click X to remove ${displayName} from ${isExcludedField ? "exclusions" : "this template"}`
              }
            >
              <Chip
                size="small"
                icon={<Business sx={{ fontSize: 14 }} />}
                label={isAllTenants ? "All Tenants" : displayName}
                variant="outlined"
                color={isExcludedField ? "warning" : "default"}
                onDelete={isAllTenants ? undefined : (e) => handleRemoveClick(tenant, e)}
                deleteIcon={
                  <Close
                    sx={{
                      fontSize: 14,
                      "&:hover": {
                        color: theme.palette.error.main,
                      },
                    }}
                  />
                }
                sx={{
                  maxWidth: 200,
                  "& .MuiChip-label": {
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                    whiteSpace: "nowrap",
                  },
                  ...(isAllTenants && {
                    bgcolor: alpha(theme.palette.info.main, 0.1),
                    borderColor: alpha(theme.palette.info.main, 0.3),
                  }),
                }}
              />
            </Tooltip>
          );
        })}
        {!showAll && hiddenCount > 0 && (
          <Chip
            size="small"
            label={`+${hiddenCount} more`}
            variant="outlined"
            onClick={() => setShowAll(true)}
            sx={{
              cursor: "pointer",
              "&:hover": {
                bgcolor: alpha(theme.palette.primary.main, 0.1),
              },
            }}
          />
        )}
        {showAll && tenantList.length > maxDisplay && (
          <Chip
            size="small"
            label="Show less"
            variant="outlined"
            onClick={() => setShowAll(false)}
            sx={{
              cursor: "pointer",
              "&:hover": {
                bgcolor: alpha(theme.palette.primary.main, 0.1),
              },
            }}
          />
        )}
      </Stack>

      {/* Remove Tenant Confirmation Dialog */}
      <Dialog
        open={removeDialog.open}
        onClose={handleDialogClose}
        maxWidth="sm"
        fullWidth
        disableRestoreFocus
        onClick={(e) => e.stopPropagation()}
      >
        <DialogTitle>
          Remove Tenant from {isExcludedField ? "Exclusions" : "Template"}?
        </DialogTitle>
        <DialogContent>
          <DialogContentText component="div">
            Are you sure you want to remove{" "}
            <strong>{getTenantDisplayName(removeDialog.tenant)}</strong> from{" "}
            {isExcludedField ? (
              <>
                the excluded tenants list of template{" "}
                <strong>{templateName}</strong>?
                <Alert severity="info" sx={{ mt: 2 }}>
                  This tenant will now be included when the template is applied to "All Tenants".
                </Alert>
              </>
            ) : (
              <>
                template <strong>{templateName}</strong>?
                <Alert severity="warning" sx={{ mt: 2 }}>
                  This template will no longer apply to this tenant. Make sure this is intentional.
                </Alert>
              </>
            )}
          </DialogContentText>

          {error && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {error}
            </Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleDialogClose} disabled={isRemoving}>
            Cancel
          </Button>
          <Button
            onClick={handleRemoveTenant}
            color={isExcludedField ? "primary" : "error"}
            variant="contained"
            disabled={isRemoving}
            startIcon={
              isRemoving ? <CircularProgress size={16} color="inherit" /> : <Close />
            }
          >
            {isRemoving ? "Removing..." : "Remove Tenant"}
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
};

CippRemovableTenantChips.propTypes = {
  tenants: PropTypes.oneOfType([
    PropTypes.array,
    PropTypes.string,
  ]),
  templateId: PropTypes.string.isRequired,
  templateName: PropTypes.string,
  templateData: PropTypes.object.isRequired,
  fieldName: PropTypes.oneOf(["tenantFilter", "excludedTenants"]).isRequired,
  queryKey: PropTypes.string.isRequired,
  maxDisplay: PropTypes.number,
  emptyMessage: PropTypes.string,
};

export default CippRemovableTenantChips;
