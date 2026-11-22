import React from 'react'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderWithProviders, settingsWith } from '../test-utils'
import { api, getResult } from '../mocks/api-call'
import { StorageReportButton } from '../../src/components/CippPdf/StorageReportButton'

vi.mock('../../src/api/ApiCall', async () =>
  (await import('../mocks/api-call')).apiCallMock()
)

const TENANT = 'contoso.onmicrosoft.com'
const defaults = {
  storage: 'preset-storage',
}
let fetchMock

beforeEach(() => {
  api.get = (opts) =>
    opts.url === '/api/ListBrandingSettings'
      ? getResult({ data: { reportDefaults: defaults } })
      : getResult()
  fetchMock = vi.fn(() =>
    Promise.resolve({
      ok: true,
      blob: () =>
        Promise.resolve(new Blob(['%PDF-'], { type: 'application/pdf' })),
    })
  )
  vi.stubGlobal('fetch', fetchMock)
  URL.createObjectURL = vi.fn(() => 'blob:report')
  URL.revokeObjectURL = vi.fn()
})

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe('Per-report PDF branding defaults', () => {
  it('Storage forwards its configured preset to the PDF endpoint', async () => {
    renderWithProviders(<StorageReportButton tenantName="Contoso" />, {
      settings: settingsWith({ currentTenant: TENANT }),
    })
    await userEvent.click(screen.getByRole('button', { name: /export report/i }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalled())

    const [url] = fetchMock.mock.calls.at(-1)
    expect(url).toContain('ExecGetStorageReportPdf')
    const params = new URL(url, 'https://example.com').searchParams
    expect(params.get('tenantFilter')).toBe(TENANT)
    expect(params.get('brandingPresetId')).toBe(defaults.storage)
  })
})
