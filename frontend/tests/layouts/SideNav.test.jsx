import React from 'react'
import { describe, it, expect, vi } from 'vitest'
import { screen, waitFor } from '@testing-library/react'
import { renderWithProviders, settingsWith } from '../test-utils'

const nav = vi.hoisted(() => {
  const state = { pathname: '/', listeners: new Set() }
  return {
    get: () => state.pathname,
    set: (pathname) => {
      state.pathname = pathname
      state.listeners.forEach((listener) => listener())
    },
    subscribe: (listener) => {
      state.listeners.add(listener)
      return () => state.listeners.delete(listener)
    },
  }
})
vi.mock('next/navigation', async () => {
  const React = await import('react')
  return {
    usePathname: () => React.useSyncExternalStore(nav.subscribe, nav.get, nav.get),
    useRouter: () => ({ push: vi.fn() }),
    useSearchParams: () => new URLSearchParams(''),
  }
})

const idle = vi.hoisted(() => ({
  isSuccess: false,
  isFetching: false,
  isPending: false,
  isError: false,
  data: undefined,
  mutate: () => {},
  reset: () => {},
  refetch: () => {},
}))
// SideNav only renders for users with more than two roles
const me = vi.hoisted(() => ({
  isSuccess: true,
  data: { clientPrincipal: { userRoles: ['anonymous', 'authenticated', 'admin'] } },
}))
vi.mock('../../src/api/ApiCall', () => ({
  ApiGetCall: ({ url }) => (url === '/api/me' ? { ...idle, ...me } : idle),
  ApiPostCall: () => idle,
  ApiGetCallWithPagination: () => ({ ...idle, fetchNextPage: () => {} }),
}))
vi.mock('../../src/components/CippComponents/CippSponsor', () => ({ CippSponsor: () => null }))

import { SideNav } from '../../src/layouts/side-nav'

const items = [
  { title: 'Dashboard', path: '/' },
  {
    title: 'Identity',
    type: 'header',
    items: [
      {
        title: 'Administration',
        path: '/identity/administration',
        items: [{ title: 'Users', path: '/identity/administration/users' }],
      },
    ],
  },
]

// rerender() would drop renderWithProviders' wrappers, so drive the re-render from inside
const Harness = () => <SideNav items={items} pinned />

const renderNav = () =>
  renderWithProviders(<Harness />, { settings: settingsWith({ bookmarkSidebar: false }) })

describe('SideNav', () => {
  // Ctrl+K navigates with router.push, the nav stays mounted and only the pathname changes
  it('expands the parent sections when the route moves into them after mount', async () => {
    nav.set('/')
    renderNav()
    expect(screen.queryByText('Users')).toBeNull()

    nav.set('/identity/administration/users')

    await waitFor(() => expect(screen.getByText('Users')).toBeVisible())
  })
})
