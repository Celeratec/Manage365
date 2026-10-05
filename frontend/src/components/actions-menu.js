import ChevronDownIcon from "@heroicons/react/24/outline/ChevronDownIcon";
import PropTypes from "prop-types";
import {
  Button,
  Divider,
  ListItemText,
  ListSubheader,
  Menu,
  MenuItem,
  SvgIcon,
  Box,
  alpha,
} from "@mui/material";
import { useMemo } from "react";
import { usePopover } from "../hooks/use-popover";
import { useActionsDispatch } from "../hooks/use-actions-dispatch";
import { resolvePaletteMainColor } from "../theme/utils";
import {
  getActionColor,
  getCategoryColor,
  getCategoryIcon,
  getCategoryLabel,
  sortCategoryEntries,
} from "../utils/action-categories";

export const ActionsMenu = (props) => {
  const { actions = [], label = "Actions", data, queryKeys, ...other } = props;
  const popover = usePopover();
  const { visibleActions, isDisabled, dispatch, dialog } = useActionsDispatch({
    actions,
    data,
    queryKeys,
  });

  const groupedActions = useMemo(() => {
    const grouped = visibleActions.reduce((acc, action) => {
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
    return sortCategoryEntries(Object.entries(grouped));
  }, [visibleActions]);
  return (
    <>
      <Button
        onClick={popover.handleOpen}
        ref={popover.anchorRef}
        startIcon={
          <SvgIcon fontSize="small">
            <ChevronDownIcon />
          </SvgIcon>
        }
        variant="outlined"
        sx={{
          flexShrink: 0,
          whiteSpace: "nowrap",
        }}
      >
        {label}
      </Button>
      <Menu
        anchorEl={popover.anchorRef.current}
        anchorOrigin={{
          horizontal: "right",
          vertical: "bottom",
        }}
        MenuListProps={{
          dense: true,
          sx: { p: 1 },
        }}
        onClose={popover.handleClose}
        open={popover.open}
        transformOrigin={{
          horizontal: "right",
          vertical: "top",
        }}
      >
        {groupedActions.map(([category, categoryActions], groupIndex) => {
          const categoryColor = getCategoryColor(category);
          const headerBgColor =
            categoryColor === "text.secondary"
              ? (theme) => alpha(theme.palette.grey[500], 0.08)
              : (theme) => alpha(resolvePaletteMainColor(theme, categoryColor), 0.08);
          const headerTextColor =
            categoryColor === "text.secondary"
              ? "text.secondary"
              : (theme) => resolvePaletteMainColor(theme, categoryColor);

          return (
            <Box key={category}>
              <ListSubheader
                disableSticky
                sx={{
                  textTransform: "uppercase",
                  fontSize: "0.7rem",
                  letterSpacing: "0.06em",
                  fontWeight: 700,
                  lineHeight: 1.8,
                  display: "flex",
                  alignItems: "center",
                  gap: 0.75,
                  bgcolor: headerBgColor,
                  color: headerTextColor,
                  borderRadius: 0.5,
                  mx: 0.5,
                  mt: groupIndex > 0 ? 0.5 : 0,
                  py: 0.5,
                }}
              >
                {getCategoryIcon(category)}
                {getCategoryLabel(category)}
              </ListSubheader>
              {categoryActions.map((action, index) => {
                const actionColor = getActionColor(action, category);
                const iconSx =
                  actionColor === "text.secondary"
                    ? { minWidth: "30px", color: actionColor }
                    : {
                        minWidth: "30px",
                        color: (theme) => resolvePaletteMainColor(theme, actionColor),
                      };

                return (
                  <MenuItem
                    disabled={isDisabled(action)}
                    key={`${category}-${index}`}
                    onClick={() => {
                      dispatch(action);
                      popover.handleClose();
                    }}
                  >
                    <SvgIcon fontSize="small" sx={iconSx}>
                      {action.icon}
                    </SvgIcon>
                    <ListItemText>{action.label}</ListItemText>
                  </MenuItem>
                );
              })}
              {groupIndex < groupedActions.length - 1 && <Divider sx={{ my: 0.5 }} />}
            </Box>
          );
        })}
      </Menu>
      {dialog}
    </>
  );
};

ActionsMenu.propTypes = {
  actions: PropTypes.array,
  label: PropTypes.string,
  queryKeys: PropTypes.array,
};
