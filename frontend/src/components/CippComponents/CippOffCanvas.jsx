import { Drawer, Box, IconButton, Typography, Divider, useTheme } from "@mui/material";
import { CippPropertyListCard } from "../CippCards/CippPropertyListCard";
import { getCippTranslation } from "../../utils/get-cipp-translation";
import { getCippFormatting } from "../../utils/get-cipp-formatting";
import { useMediaQuery, Grid } from "@mui/system";
import CloseIcon from "@mui/icons-material/Close";
import KeyboardArrowUpIcon from "@mui/icons-material/KeyboardArrowUp";
import KeyboardArrowDownIcon from "@mui/icons-material/KeyboardArrowDown";

export const CippOffCanvas = (props) => {
  const {
    title = "Extended Info",
    visible,
    extendedInfoFields = [],
    extendedData,
    actions,
    onClose,
    isFetching,
    children,
    size = "sm",
    footer,
    onNavigateUp,
    onNavigateDown,
    canNavigateUp = false,
    canNavigateDown = false,
    contentPadding = 2,
    keepMounted = false,
  } = props;

  const theme = useTheme();
  const mdDown = useMediaQuery(theme.breakpoints.down("md"));
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  const extendedInfo = extendedInfoFields.map((field) => {
    const value = field.split(".").reduce((acc, part) => acc && acc[part], extendedData);
    if (value === undefined || value === null) {
      if (extendedData?.[field] !== undefined && extendedData?.[field] !== null) {
        return {
          label: getCippTranslation(field),
          value: getCippFormatting(extendedData[field], field, "text", "both"),
        };
      } else {
        return {
          label: getCippTranslation(field),
          value: "N/A",
        };
      }
    } else if (Array.isArray(value)) {
      return {
        label: getCippTranslation(field),
        value: getCippFormatting(value, field, "array", "both"),
      };
    } else {
      return {
        label: getCippTranslation(field),
        value: getCippFormatting(value, field, "text", "both"),
      };
    }
  });

  if (mdDown) {
    drawerWidth = "100%";
  } else {
    var drawerWidth = 400;
    switch (size) {
      case "sm":
        drawerWidth = 400;
        break;
      case "md":
        drawerWidth = 600;
        break;
      case "lg":
        drawerWidth = 800;
        break;
      case "xl":
        drawerWidth = 1000;
        break;
    }
  }

  return (
    <>
      <Drawer
        PaperProps={{
          sx: { width: drawerWidth },
        }}
        ModalProps={{
          keepMounted: keepMounted,
        }}
        anchor={"right"}
        open={visible}
        onClose={onClose}
      >
        <Box
          sx={{ 
            display: "flex", 
            justifyContent: "space-between", 
            alignItems: "center", 
            p: smDown ? 2 : 1.5,
            // Safe area for notched phones
            paddingTop: smDown ? 'max(16px, env(safe-area-inset-top))' : 1.5,
          }}
        >
          <Typography variant={smDown ? "h6" : "h5"} sx={{ pr: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {title}
          </Typography>
          <Box sx={{ display: "flex", gap: smDown ? 1 : 0.5, flexShrink: 0 }}>
            {(canNavigateUp || canNavigateDown) && (
              <>
                <IconButton
                  onClick={onNavigateUp}
                  disabled={!canNavigateUp}
                  size={smDown ? "medium" : "small"}
                  title="Previous row"
                  sx={{ 
                    // Minimum 44px touch target for mobile
                    minWidth: smDown ? 44 : 'auto',
                    minHeight: smDown ? 44 : 'auto',
                  }}
                >
                  <KeyboardArrowUpIcon />
                </IconButton>
                <IconButton
                  onClick={onNavigateDown}
                  disabled={!canNavigateDown}
                  size={smDown ? "medium" : "small"}
                  title="Next row"
                  sx={{ 
                    minWidth: smDown ? 44 : 'auto',
                    minHeight: smDown ? 44 : 'auto',
                  }}
                >
                  <KeyboardArrowDownIcon />
                </IconButton>
              </>
            )}
            <IconButton 
              onClick={onClose}
              size={smDown ? "medium" : "small"}
              sx={{ 
                minWidth: smDown ? 44 : 'auto',
                minHeight: smDown ? 44 : 'auto',
              }}
            >
              <CloseIcon />
            </IconButton>
          </Box>
        </Box>
        <Divider />
        <Box
          sx={{
            display: "flex",
            flexDirection: "column",
            height: "calc(100vh - 73px)", // Account for header + divider
            minHeight: 0,
          }}
        >
          <Box
            sx={{
              overflowY: "auto",
              flexGrow: 1,
              display: "flex",
              flexDirection: "column",
              minHeight: 0,
            }}
          >
            <Grid container spacing={1} sx={{ flexGrow: 1 }}>
              {extendedInfo.length > 0 && (
                <Grid size={{ xs: 12 }}>
                  <CippPropertyListCard
                    isFetching={isFetching}
                    align="vertical"
                    propertyItems={extendedInfo}
                    copyItems={true}
                    actionItems={actions}
                    data={extendedData}
                    actionsCollapsedByDefault={true}
                  />
                </Grid>
              )}
              <Grid
                size={{ xs: 12 }}
                sx={{ flexGrow: 1, display: "flex", flexDirection: "column" }}
              >
                <Box
                  sx={{
                    display: "flex",
                    flexDirection: "column",
                    flexGrow: 1,
                    minHeight: 0,
                    p: contentPadding,
                  }}
                >
                  {/* Render children if provided, otherwise render default content */}
                  {typeof children === "function" ? children(extendedData) : children}
                </Box>
              </Grid>
            </Grid>
          </Box>

          {/* Footer section */}
          {footer && (
            <Box
              sx={{
                borderTop: 1,
                borderColor: "divider",
                p: 2,
                flexShrink: 0,
                mt: "auto",
              }}
            >
              {footer}
            </Box>
          )}
        </Box>
      </Drawer>
    </>
  );
};
