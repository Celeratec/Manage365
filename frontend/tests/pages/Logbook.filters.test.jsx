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

  it('scopes ListLogs to the active tenant from settings', () => {
    renderPage()
    expect(tableProps.current.apiData.Tenant).toBe('contoso.com')
    expect(tableProps.current.apiData.Filter).toBe(false)
  })

  it('applies username and severity filters to the ListLogs payload', async () => {
    const user = userEvent.setup()
    renderPage()

    await user.click(screen.getByText('Filters'))
    await user.type(screen.getByRole('textbox', { name: 'Filter by Username' }), 'tech@msp.com')
    await user.click(screen.getByRole('button', { name: /apply filters/i }))

    await waitFor(() => expect(tableProps.current.apiData.Filter).toBe(true))
    expect(tableProps.current.apiData.User).toBe('tech@msp.com')
    expect(tableProps.current.apiData.Tenant).toBe('contoso.com')
  })

  it('clears applied filters back to the default query', async () => {
    const user = userEvent.setup()
    renderPage()

    await user.click(screen.getByText('Filters'))
    await user.type(screen.getByRole('textbox', { name: 'Filter by Username' }), 'tech@msp.com')
    await user.click(screen.getByRole('button', { name: /apply filters/i }))
    await waitFor(() => expect(tableProps.current.apiData.Filter).toBe(true))

    await user.click(screen.getByText('Filters'))
    await user.click(screen.getByRole('button', { name: /clear filters/i }))
    await waitFor(() => expect(tableProps.current.apiData.Filter).toBe(false))
    expect(tableProps.current.apiData.User).toBeNull()
  })
})
