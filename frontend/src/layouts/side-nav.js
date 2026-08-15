import { useState, useCallback, useEffect, memo } from "react";
import { usePathname } from "next/navigation";
import PropTypes from "prop-types";
import {
  Box,
  Divider,
  Drawer,
  Stack,
} from "@mui/material";
import { Scrollbar } from "../components/scrollbar";
import { SideNavItem } from "./side-nav-item";
import { SideNavBookmarks } from "./side-nav-bookmarks";
import { useSettings } from "../hooks/use-settings";

const SIDE_NAV_WIDTH = 270;
const SIDE_NAV_COLLAPSED_WIDTH = 73; // icon size + padding + border right
const TOP_NAV_HEIGHT = 64;

// Find all parent menus that should be open based on current path
// Returns an array of menu titles that form the path to the active item
const findActiveMenuPath = (items, pathname, parentPath = []) => {
  if (!items || !pathname) return [];
  
  for (const item of items) {
    const hasChildren = item.items && item.items.length > 0;
    
    if (hasChildren) {
      // Recursively check children
      const childResult = findActiveMenuPath(item.items, pathname, [...parentPath, item.title]);
      // If we found a match in children, return it (includes this parent)
      if (childResult.length > 0) {
        return childResult;
      }
    } else if (item.path) {
      // This is a leaf item - check if it matches
      const exactMatch = pathname === item.path;
      // For partial match, ensure the path is followed by / or end of string
      // This prevents /identity matching /identity-other
      const partialMatch = item.path !== "/" && (
        pathname.startsWith(item.path + "/") || pathname === item.path
      );
      
      if (exactMatch || partialMatch) {
        // Found matching leaf - return the parent path (not including this leaf)
        return parentPath;
      }
    }
  }
  
  // No match found in this branch
  return [];
};

const renderItems = ({ collapse = false, depth = 0, items, pathname, openMenus, onMenuToggle }) =>
  items.reduce((acc, item) => reduceChildRoutes({ acc, collapse, depth, item, pathname, openMenus, onMenuToggle, siblings: items }), []);

const reduceChildRoutes = ({ acc, collapse, depth, item, pathname, openMenus, onMenuToggle, siblings = [] }) => {
  const hasChildren = item.items && item.items.length > 0;
  
  // Determine if this item is "active" (currently selected page)
  let isActive = false;
  if (item.path && pathname && !hasChildren) {
    const exactMatch = pathname === item.path;
    // More precise partial match - ensure path boundary
    let partialMatch = item.path !== "/" && (
      pathname.startsWith(item.path + "/") || pathname === item.path
    );
    // If partial match, check that no sibling has a longer/more-specific match
    // This prevents /teams-share/onedrive from highlighting when /teams-share/onedrive/file-browser is the actual match
    if (partialMatch && !exactMatch) {
      const allLeafPaths = [];
      const collectLeafPaths = (items) => {
        for (const sibling of items) {
          if (sibling.items && sibling.items.length > 0) {
            collectLeafPaths(sibling.items);
          } else if (sibling.path) {
            allLeafPaths.push(sibling.path);
          }
        }
      };
      collectLeafPaths(siblings);
      const hasMoreSpecificMatch = allLeafPaths.some(
        (p) => p !== item.path && p.length > item.path.length && (pathname === p || pathname.startsWith(p + "/"))
      );
      if (hasMoreSpecificMatch) {
        partialMatch = false;
      }
    }
    isActive = exactMatch || partialMatch;
  }
  
  // Check if this menu should be open (works for all depths)
  const isOpen = openMenus.includes(item.title);

  if (hasChildren) {
    acc.push(
      <SideNavItem
        active={isActive}
        collapse={collapse}
        depth={depth}
        external={item.external}
        icon={item.icon}
        key={item.title}
        open={isOpen}
        onToggle={() => onMenuToggle(item.title, depth)}
        path={item.path}
        scope={item.scope}
        title={item.title}
        type={item.type}
      >
        <Stack
          component="ul"
          spacing={0.5}
          sx={{
            listStyle: "none",
            m: 0,
            p: 0,
          }}
        >
          {renderItems({
            collapse,
            depth: depth + 1,
            items: item.items,
            pathname,
            openMenus,
            onMenuToggle,
          })}
        </Stack>
      </SideNavItem>,
    );
  } else {
    acc.push(
      <SideNavItem
        active={isActive}
        collapse={collapse}
        depth={depth}
        external={item.external}
        icon={item.icon}
        key={item.title}
        path={item.path}
        scope={item.scope}
        title={item.title}
      />,
    );
  }

  return acc;
};

export const SideNav = memo((props) => {
  const { items, onPin, pinned = false } = props;
  const pathname = usePathname();
  const [hovered, setHovered] = useState(false);
  const collapse = !(pinned || hovered);
  const settings = useSettings();
  const showSidebarBookmarks = settings.bookmarkSidebar !== false;

  // Track open menus - initialized empty, updated by effect when path changes
  const [openMenus, setOpenMenus] = useState([]);

  // Update open menus when pathname changes (e.g., navigating to Dashboard collapses all)
  useEffect(() => {
    const activeMenuPath = findActiveMenuPath(items, pathname);
    setOpenMenus(activeMenuPath);
  }, [pathname, items]);

  // Handle menu toggle
  // - Top-level (depth 0): accordion behavior - only one can be open, closes nested too
  // - Nested (depth > 0): independent toggle
  const handleMenuToggle = useCallback((title, depth) => {
    setOpenMenus((prev) => {
      if (depth === 0) {
        if (prev.includes(title)) {
          return [];
        }
        return [title];
      } else {
        if (prev.includes(title)) {
          return prev.filter((t) => t !== title);
        }
        return [...prev, title];
      }
    });
  }, []);

  return (
    <Drawer
      open
      variant="permanent"
      PaperProps={{
        onMouseEnter: () => {
          setHovered(true);
        },
        onMouseLeave: () => {
          setHovered(false);
        },
        sx: {
          backgroundColor: "background.default",
          height: `calc(100% - ${TOP_NAV_HEIGHT}px)`,
          overflowX: "hidden",
          top: TOP_NAV_HEIGHT,
          transition: "width 250ms ease-in-out",
          width: collapse ? SIDE_NAV_COLLAPSED_WIDTH : SIDE_NAV_WIDTH,
          zIndex: (theme) => theme.zIndex.appBar - 100,
        },
      }}
    >
      <Scrollbar
        sx={{
          height: "100%",
          overflowX: "hidden",
          "& .simplebar-content": {
            height: "100%",
          },
        }}
      >
        <Box
          component="nav"
          sx={{
            display: "flex",
            flexDirection: "column",
            height: "100%",
            p: 2,
          }}
        >
          <Box
            component="ul"
            sx={{
              flexGrow: 1,
              listStyle: "none",
              m: 0,
              p: 0,
            }}
          >
            {showSidebarBookmarks && (
              <>
                <SideNavBookmarks collapse={collapse} />
                <Divider sx={{ my: 1, transition: "opacity 250ms ease-in-out", ...(collapse && { opacity: 0 }) }} />
              </>
            )}
            {renderItems({
              collapse,
              depth: 0,
              items,
              pathname,
              openMenus,
              onMenuToggle: handleMenuToggle,
            })}
          </Box>
        </Box>
      </Scrollbar>
    </Drawer>
  );
});

SideNav.displayName = "SideNav";

SideNav.propTypes = {
  onPin: PropTypes.func,
  pinned: PropTypes.bool,
};
