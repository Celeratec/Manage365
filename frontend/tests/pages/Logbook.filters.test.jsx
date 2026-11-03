import React from 'react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderWithProviders } from '../test-utils'
import router from 'next/router'
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider'
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns'

// Capture what the page asks ListLogs for; the table itself is not under test.
const tableProps = vi.hoisted(() => ({ current: null }))
vi.mock('../../src/components/CippComponents/CippTablePage.jsx', () => ({
  CippTablePage: (props) => {
    tableProps.current = props
    return <div>{props.tableFilter}</div>
  },
}))
const settingsState = vi.hoisted(() => ({ currentTenant: 'contoso.com' }))
vi.mock('../../src/hooks/use-settings.js', () => ({ useSettings: () => settingsState }))

import Page from '../../src/pages/cipp/logs/index.jsx'

const renderPage = () =>
  renderWithProviders(
    <LocalizationProvider dateAdapter={AdapterDateFns}>
      <Page />
    </LocalizationProvider>
  )

describe('Logbook filters', () => {
  beforeEach(() => {
    tableProps.current = null
    settingsState.currentTenant = 'contoso.com'
    router.query = {}
  })

  it('scopes the logbook to the tenant selected in the app', () => {
    renderPage()
    expect(tableProps.current.apiData.Tenant).toBe('contoso.com')
    expect(tableProps.current.apiData.Filter).toBe(false)
  })

  it('keeps All Tenants when that is the selected tenant', () => {
    settingsState.currentTenant = 'AllTenants'
    renderPage()
    expect(tableProps.current.apiData.Tenant).toBe('AllTenants')
    expect(tableProps.current.apiData.tenantFilter).toBeNull()
  })

  it('applies a username and clears it without changing the tenant', async () => {
    const user = userEvent.setup()
    renderPage()

    await user.click(screen.getByText('Filters'))
    await user.type(screen.getByRole('textbox', { name: 'Filter by Username' }), 'tech@msp.com')
    await user.click(screen.getByRole('button', { name: /apply filters/i }))
    await waitFor(() =>
      expect(tableProps.current.apiData).toMatchObject({
        User: 'tech@msp.com',
        Filter: true,
        Tenant: 'contoso.com',
      })
    )

    await user.click(screen.getByText('Filters'))
    await user.click(screen.getByRole('button', { name: /clear filters/i }))
    await waitFor(() =>
      expect(tableProps.current.apiData).toMatchObject({
        User: null,
        Filter: false,
        Tenant: 'contoso.com',
      })
    )
  }, 30000)

  it('applies the last 7 days preset', async () => {
    const user = userEvent.setup()
    renderPage()
    await user.click(screen.getByText('Filters'))
    await user.click(screen.getByText('Last 7 Days'))
    await user.click(screen.getByRole('button', { name: /apply filters/i }))
    await waitFor(() => expect(tableProps.current.apiData.Filter).toBe(true))
    expect(tableProps.current.apiData.StartDate).toMatch(/^\d{8}$/)
    expect(tableProps.current.apiData.EndDate).toMatch(/^\d{8}$/)
    expect(tableProps.current.apiData.Tenant).toBe('contoso.com')
  }, 30000)
})
