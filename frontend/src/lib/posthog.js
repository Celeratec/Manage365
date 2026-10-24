import posthog from 'posthog-js'

let posthogInitialized = false

export function initPostHog() {
  if (
    typeof window === 'undefined' ||
    posthogInitialized ||
    !process.env.NEXT_PUBLIC_POSTHOG_KEY ||
    !process.env.NEXT_PUBLIC_POSTHOG_HOST
  ) {
    return
  }

  posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY, {
    api_host: process.env.NEXT_PUBLIC_POSTHOG_HOST,
    
    person_profiles: 'identified_only',
    
    autocapture: false,
    
    capture_pageview: true,
    capture_pageleave: true,
    
    disable_session_recording: true,
    
    session_recording: {
      maskAllInputs: true,
      maskTextSelector: '*',
    },
    
    mask_all_text: true,
    mask_all_element_attributes: true,
    
    sanitize_properties: function (properties, event) {
      const sensitiveKeys = [
        'email',
        'name',
        'username',
        'tenant',
        'tenantid',
        'tenant_id',
        'password',
        'token',
        'auth',
        'secret',
        'api_key',
        'apikey',
      ]
      
      if (properties) {
        Object.keys(properties).forEach((key) => {
          const lowerKey = key.toLowerCase()
          if (sensitiveKeys.some((sensitive) => lowerKey.includes(sensitive))) {
            delete properties[key]
          }
        })
      }
      
      return properties
    },
    
    loaded: function (posthog) {
      if (process.env.NODE_ENV === 'development') {
        posthog.opt_out_capturing()
      }
    },
  })

  posthogInitialized = true
}

export { posthog }
