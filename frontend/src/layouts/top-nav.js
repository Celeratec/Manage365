import { useCallback, useEffect, useRef, memo, useState } from "react";
import NextLink from "next/link";
import PropTypes from "prop-types";
import Bars3Icon from "@heroicons/react/24/outline/Bars3Icon";
import MoonIcon from "@heroicons/react/24/outline/MoonIcon";
import SunIcon from "@heroicons/react/24/outline/SunIcon";
import TravelExploreIcon from "@mui/icons-material/TravelExplore";
import {
  Box,
  Dialog,
  DialogContent,
  DialogTitle,
  Divider,
  IconButton,
  Stack,
  SvgIcon,
  Tooltip,
  Typography,
  useMediaQuery,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Logo } from "../components/logo";
import { useSettings } from "../hooks/use-settings";
import { paths } from "../paths";
import { AccountPopover } from "./account-popover";
import { CippTenantSelector } from "../components/CippComponents/CippTenantSelector";
import { NotificationsPopover } from "./notifications-popover";
import { useDialog } from "../hooks/use-dialog";
import { MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { CippUniversalSearchV2 } from "../components/CippCards/CippUniversalSearchV2";
import { CippOffCanvas } from "../components/CippComponents/CippOffCanvas";
import { CippLicenseDetailsDrawer } from "../components/CippComponents/CippLicenseDetailsDrawer";

const TOP_NAV_HEIGHT = 64;

export const TopNav = memo((props) => {
  const universalSearchDialog = useDialog();
  const { onNavOpen } = props;
  const settings = useSettings();
  const mdDown = useMediaQuery((theme) => theme.breakpoints.down("md"));
  const [universalSearchKey, setUniversalSearchKey] = useState(0);
  const [universalSearchDefaultType, setUniversalSearchDefaultType] = useState("Pages");
  const [licenseDrawerVisible, setLicenseDrawerVisible] = useState(false);
  const [licenseDrawerData, setLicenseDrawerData] = useState(null);

  const handleThemeSwitch = useCallback(() => {
    const themeName = settings.currentTheme?.value === "light" ? "dark" : "light";
    settings.handleUpdate({
      currentTheme: { value: themeName, label: themeName },
      paletteMode: themeName,
    });
  }, [settings]);

  const tenantSelectorRef = useRef(null);

  const openUniversalSearch = useCallback(
    (defaultType = "Pages") => {
      setUniversalSearchDefaultType(defaultType);
      universalSearchDialog.handleOpen();
    },
    [universalSearchDialog.handleOpen],
  );

  const closeUniversalSearch = useCallback(() => {
    universalSearchDialog.handleClose();
    setUniversalSearchKey((prev) => prev + 1);
  }, [universalSearchDialog.handleClose]);

  useEffect(() => {
    const handleKeyDown = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.altKey && event.key === "k") {
        event.preventDefault();
        tenantSelectorRef.current?.focus();
      } else if ((event.metaKey || event.ctrlKey) && event.shiftKey && event.key === "F") {
        event.preventDefault();
        openUniversalSearch("Users");
      } else if ((event.metaKey || event.ctrlKey) && event.key === "k") {
        event.preventDefault();
        openUniversalSearch("Pages");
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [openUniversalSearch]);

  return (
    <Box
      component="header"
      sx={{
        // Frosted glass effect like Apple
        backgroundColor: (theme) =>
          theme.palette.mode === "dark"
            ? "rgba(30, 30, 30, 0.3)"
            : "rgba(255, 255, 255, 0.3)",
        backdropFilter: "saturate(180%) blur(16px)",
        WebkitBackdropFilter: "saturate(180%) blur(16px)",
        borderBottom: (theme) =>
          `1px solid ${
            theme.palette.mode === "dark"
              ? "rgba(255, 255, 255, 0.1)"
              : "rgba(0, 0, 0, 0.1)"
          }`,
        color: (theme) => theme.palette.text.primary,
        position: "fixed",
        width: "100%",
        zIndex: (theme) => theme.zIndex.appBar,
      }}
    >
      <Stack
        direction="row"
        justifyContent="space-between"
        sx={{
          minHeight: TOP_NAV_HEIGHT,
          px: mdDown ? 1.5 : 3,
        }}
      >
        <Stack
          alignItems="center"
          direction="row"
          spacing={3}
          divider={
            <Divider
              orientation="vertical"
              sx={{
                borderColor: (theme) =>
                  theme.palette.mode === "dark"
                    ? alpha(theme.palette.common.white, 0.2)
                    : alpha(theme.palette.common.black, 0.2),
                height: 36,
              }}
            />
          }
        >
          <Box
            component={NextLink}
            href={paths.index}
            sx={{
              display: "inline-flex",
              alignItems: "center",
              height: 48,
              width: "auto",
            }}
          >
            <Logo height={48} />
          </Box>
          {!mdDown && (
            <CippTenantSelector ref={tenantSelectorRef} refreshButton={true} tenantButton={true} />
          )}
          {mdDown && (
            <IconButton
              onClick={onNavOpen}
              sx={{
                color: "text.primary",
                minWidth: 44,
                minHeight: 44,
              }}
            >
              <SvgIcon fontSize="medium">
                <Bars3Icon />
              </SvgIcon>
            </IconButton>
          )}
        </Stack>
        <Stack alignItems="center" direction="row" spacing={mdDown ? 0.5 : 1.5}>
          {!mdDown && (
            <Tooltip title="Universal search — users, groups, apps (Ctrl/Cmd+Shift+F)">
              <IconButton
                onClick={() => openUniversalSearch("Users")}
                aria-label="Open universal search (Ctrl/Cmd+Shift+F)"
                sx={{ color: "text.secondary" }}
              >
                <TravelExploreIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
          {!mdDown && (
            <IconButton onClick={handleThemeSwitch} sx={{ color: "text.secondary" }}>
              <SvgIcon fontSize="small">
                {settings?.currentTheme?.value === "dark" ? <SunIcon /> : <MoonIcon />}
              </SvgIcon>
            </IconButton>
          )}
          <Tooltip title="Page search (Ctrl/Cmd+K)">
            <IconButton
              onClick={() => openUniversalSearch("Pages")}
              aria-label="Open page search (Ctrl/Cmd+K)"
              sx={{
                color: "text.secondary",
                ...(mdDown && { minWidth: 44, minHeight: 44 }),
              }}
            >
              <SvgIcon fontSize={mdDown ? "medium" : "small"}>
                <MagnifyingGlassIcon />
              </SvgIcon>
            </IconButton>
          </Tooltip>
          <Dialog
            open={universalSearchDialog.open}
            onClose={closeUniversalSearch}
            fullWidth
            maxWidth="md"
            sx={{
              "& .MuiDialog-container": {
                alignItems: "flex-start",
              },
              "& .MuiDialog-paper": {
                mt: 8,
              },
            }}
          >
            <DialogTitle sx={{ px: 3, pt: 2, pb: 1 }}>
              <Stack
                direction="row"
                alignItems="center"
                justifyContent="space-between"
                flexWrap="wrap"
                useFlexGap
                spacing={1}
              >
                <span>Manage365 Search</span>
                <Typography variant="caption" color="text.secondary">
                  Pages: Ctrl/Cmd+K · Users: Ctrl/Cmd+Shift+F
                </Typography>
              </Stack>
            </DialogTitle>
            <DialogContent sx={{ px: 3, pt: 1, pb: 3 }}>
              <Box>
                <CippUniversalSearchV2
                  key={universalSearchKey}
                  maxResults={12}
                  autoFocus={true}
                  defaultSearchType={universalSearchDefaultType}
                  onConfirm={closeUniversalSearch}
                  onLicenseSelect={(licenseData) => {
                    setLicenseDrawerData(licenseData);
                    setLicenseDrawerVisible(true);
                  }}
                />
              </Box>
            </DialogContent>
          </Dialog>
          <CippOffCanvas
            title="License Details"
            visible={licenseDrawerVisible}
            onClose={() => setLicenseDrawerVisible(false)}
            size="xl"
            contentPadding={0}
          >
            <CippLicenseDetailsDrawer data={licenseDrawerData} />
          </CippOffCanvas>
          <NotificationsPopover />
          <AccountPopover
            onThemeSwitch={handleThemeSwitch}
            paletteMode={settings.currentTheme?.value === "light" ? "dark" : "light"}
          />
        </Stack>
      </Stack>
    </Box>
  );
});

TopNav.displayName = "TopNav";

TopNav.propTypes = {
  onNavOpen: PropTypes.func,
  openNav: PropTypes.bool,
};
