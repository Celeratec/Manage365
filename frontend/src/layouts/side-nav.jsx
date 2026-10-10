import { useState, useRef, useEffect, useCallback, memo } from 'react'
import { usePathname } from 'next/navigation'
import PropTypes from 'prop-types'
import { Box, Divider, Drawer, Stack } from '@mui/material'
import { SideNavItem } from './side-nav-item'
import { SideNavBookmarks } from './side-nav-bookmarks'
import { ApiGetCall } from '../api/ApiCall.jsx'
import { CippSponsor } from '../components/CippComponents/CippSponsor'
import { useSettings } from '../hooks/use-settings'

import {
  CHROME_TOP_OFFSET,
  SIDE_NAV_COLLAPSED_WIDTH,
  SIDE_NAV_WIDTH,
} from './constants'

const isPathPrefix = (pathname, itemPath) => {
  if (!pathname || !itemPath) return false
  if (pathname === itemPath) return true
  // Root "/" maps to /dashboardv2 under the hood
  if (itemPath === '/') return pathname.startsWith('/dashboardv2')
  return pathname.startsWith(itemPath + '/') || pathname.startsWith(itemPath + '?')
}

// Parent menu titles that lead to the active leaf. Used by the controlled accordion.
const findActiveMenuPath = (items, pathname, parentPath = []) => {
  if (!items || !pathname) return []

  for (const item of items) {
    const hasChildren = item.items && item.items.length > 0

    if (hasChildren) {
      const childResult = findActiveMenuPath(item.items, pathname, [...parentPath, item.title])
      if (childResult.length > 0) {
        return childResult
      }
    } else if (item.path && (pathname === item.path || isPathPrefix(pathname, item.path))) {
      return parentPath
    }
  }

  return []
}

const renderItems = ({
  collapse = false,
  depth = 0,
  items,
  pathname,
  category = '',
  openMenus,
  onMenuToggle,
}) =>
  items.reduce(
    (acc, item) =>
      reduceChildRoutes({
        acc,
        collapse,
        depth,
        item,
        pathname,
        category,
        openMenus,
        onMenuToggle,
        siblings: items,
      }),
    []
  )

const reduceChildRoutes = ({
  acc,
  collapse,
  depth,
  item,
  pathname,
  category,
  openMenus,
  onMenuToggle,
  siblings = [],
}) => {
  const checkPath = !!(item.path && pathname)
  const exactMatch = checkPath && pathname === item.path
  let partialMatch = checkPath ? isPathPrefix(pathname, item.path) : false

  const hasChildren = item.items && item.items.length > 0
  const currentCategory = depth === 0 && item.type === 'header' ? item.title : category

  // A longer sibling path wins, so /teams-share/onedrive does not stay active on
  // /teams-share/onedrive/file-browser.
  if (partialMatch && !exactMatch && !hasChildren) {
    const allLeafPaths = []
    const collectLeafPaths = (nodes) => {
      for (const sibling of nodes) {
        if (sibling.items && sibling.items.length > 0) {
          collectLeafPaths(sibling.items)
        } else if (sibling.path) {
          allLeafPaths.push(sibling.path)
        }
      }
    }
    collectLeafPaths(siblings)
    const hasMoreSpecificMatch = allLeafPaths.some(
      (p) =>
        p !== item.path &&
        p.length > item.path.length &&
        (pathname === p || isPathPrefix(pathname, p))
    )
    if (hasMoreSpecificMatch) {
      partialMatch = false
    }
  }

  const isActive = exactMatch || (partialMatch && !hasChildren)
  const isOpen = openMenus.includes(item.title)

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
        category={currentCategory}
      >
        <Stack
          component="ul"
          spacing={0.5}
          sx={{
            listStyle: 'none',
            m: 0,
            p: 0,
          }}
        >
          {renderItems({
            collapse,
            depth: depth + 1,
            items: item.items,
            pathname,
            category: currentCategory,
            openMenus,
            onMenuToggle,
          })}
        </Stack>
      </SideNavItem>
    )
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
        category={currentCategory}
      />
    )
  }

  return acc
}

export const SideNav = memo((props) => {
  const { items, onPin, pinned = false } = props
  const pathname = usePathname()
  const [hovered, setHovered] = useState(false)
  const collapse = !(pinned || hovered)
  const { data: profile } = ApiGetCall({ url: '/api/me', queryKey: 'authmecipp' })
  const settings = useSettings()
  const showSidebarBookmarks = settings.bookmarkSidebar !== false
  const paperRef = useRef(null)
  const [openMenus, setOpenMenus] = useState([])

  useEffect(() => {
    setOpenMenus(findActiveMenuPath(items, pathname))
  }, [pathname, items])

  // Top-level menus accordion; nested menus toggle independently.
  const handleMenuToggle = useCallback((title, depth) => {
    setOpenMenus((prev) => {
      if (depth === 0) {
        if (prev.includes(title)) {
          return []
        }
        return [title]
      }
      if (prev.includes(title)) {
        return prev.filter((t) => t !== title)
      }
      return [...prev, title]
    })
  }, [])

  // Intercept wheel events on the side nav to fully isolate scroll.
  // preventDefault stops wheel events from reaching the main content,
  // and manual scrollTop has no momentum so it stops instantly when the cursor leaves.
  // Uses RAF-based easing to smooth out discrete mouse wheel jumps.
  useEffect(() => {
    const el = paperRef.current
    if (!el) return

    let targetScrollTop = el.scrollTop
    let animating = false
    let lastWrite = null

    const animate = () => {
      if (!animating) {
        return
      }
      const diff = targetScrollTop - el.scrollTop

      // browsers can round to device pixels
      if (Math.abs(diff) < 1) {
        animating = false
        return
      }
      const before = el.scrollTop
      lastWrite = before + diff * 0.25
      el.scrollTop = lastWrite
      if (el.scrollTop === before) {
        // write clamped or rounded to a no-op, stop instead of spinning the raf loop
        targetScrollTop = before
        animating = false
        return
      }
      requestAnimationFrame(animate)
    }

    const handleWheel = (e) => {
      e.preventDefault()
      const maxScroll = el.scrollHeight - el.clientHeight
      targetScrollTop = Math.max(0, Math.min(maxScroll, targetScrollTop + e.deltaY))
      if (!animating) {
        animating = true
        requestAnimationFrame(animate)
      }
    }

    // scrollbar drags, keyboard and touch move scrollTop outside the wheel path,
    // resync the target so the easing loop doesn't fight them for the thumb.
    // mid-animation, events matching our own write are the loop's echo, skip those
    const handleScroll = () => {
      if (animating && lastWrite !== null && Math.abs(el.scrollTop - lastWrite) < 1) {
        return
      }
      targetScrollTop = el.scrollTop
      animating = false
    }

    el.addEventListener('wheel', handleWheel, { passive: false })
    el.addEventListener('scroll', handleScroll, { passive: true })
    return () => {
      // queued animate() exits on guard, stopping RAF chain
      animating = false
      el.removeEventListener('wheel', handleWheel)
      el.removeEventListener('scroll', handleScroll)
    }
  }, [profile?.clientPrincipal])

  return (
    <>
      {profile?.clientPrincipal && profile?.clientPrincipal?.userRoles?.length > 2 && (
        <Drawer
          open
          variant="permanent"
          data-tutorial="side-nav"
          slotProps={{
            paper: {
              ref: paperRef,
              onMouseEnter: () => setHovered(true),
              onMouseLeave: () => setHovered(false),
              sx: {
                backgroundColor: 'background.default',
                height: `calc(100% - (${CHROME_TOP_OFFSET}))`,
                overflowX: 'hidden',
                overflowY: 'auto',
                scrollbarGutter: 'stable',
                top: CHROME_TOP_OFFSET,
                transition: 'width 250ms ease-in-out',
                width: collapse ? SIDE_NAV_COLLAPSED_WIDTH : SIDE_NAV_WIDTH,
                zIndex: (theme) => theme.zIndex.appBar - 100,
              },
            },
          }}
        >
          <Box
            component="nav"
            sx={{
              display: 'flex',
              flexDirection: 'column',
              height: '100%',
              p: 2,
              // The breadcrumb rail across the seam starts 10px under the top nav; starting
              // the Bookmarks header at the same offset lets the two rows share a line.
              pt: '10px',
            }}
          >
            <Box
              component="ul"
              sx={{
                flexGrow: 1,
                listStyle: 'none',
                m: 0,
                p: 0,
              }}
            >
              {showSidebarBookmarks && (
                <>
                  <SideNavBookmarks collapse={collapse} alignWithRail />
                  <Divider sx={{ mt: 1, mb: 1 }} />
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
            {profile?.clientPrincipal && (
              <Box
                sx={{ position: 'sticky', bottom: 0, backgroundColor: 'background.default', pt: 1 }}
              >
                <CippSponsor />
              </Box>
            )}
          </Box>
        </Drawer>
      )}
    </>
  )
})

SideNav.displayName = 'SideNav'

SideNav.propTypes = {
  onPin: PropTypes.func,
  pinned: PropTypes.bool,
}
