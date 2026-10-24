import React from 'react'
import { describe, it, expect, vi } from 'vitest'
import { act, screen, waitFor } from '@testing-library/react'
import { renderWithProviders, settingsWith } from '../test-utils'

const nav = vi.hoisted(() => ({ pathname: '/' }))
vi.mock('next/navigation', () => ({
  usePathname: () => nav.pathname,
  useRouter: () => ({ push: vi.fn() }),
  useSearchParams: () => new URLSearchParams(''),
}))

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
const Harness = () => {
  const [pathKey, setPathKey] = React.useState(nav.pathname)
  React.useEffect(() => {
    nav.rerender = () => setPathKey(nav.pathname)
  }, [])
  // SideNav is memoized on props; remount when the mocked pathname changes so usePathname() refreshes.
  return <SideNav items={items} pinned key={pathKey} />
}

const renderNav = () =>
  renderWithProviders(<Harness />, { settings: settingsWith({ bookmarkSidebar: false }) })

describe('SideNav', () => {
  it('expands parent sections for a deep-linked route on mount', async () => {
    nav.pathname = '/identity/administration/users'
    renderNav()
    await waitFor(() => expect(screen.getByText('Users')).toBeVisible())
  })

  it('expands parent sections when the pathname changes after mount', async () => {
    nav.pathname = '/'
    renderNav()
    expect(screen.queryByText('Users')).toBeNull()

    nav.pathname = '/identity/administration/users'
    act(() => nav.rerender())

    await waitFor(() => expect(screen.getByText('Users')).toBeVisible())
  })
})
