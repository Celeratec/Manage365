import { useEffect } from 'react'
import { initPostHog } from '../lib/posthog'

export function PostHogProvider({ children }) {
  useEffect(() => {
    initPostHog()
  }, [])

  return children
}
