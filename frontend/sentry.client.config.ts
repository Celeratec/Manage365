import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  
  environment: process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT || process.env.NODE_ENV,
  
  tracesSampleRate: 0.1,
  
  replaysSessionSampleRate: 0.01,
  replaysOnErrorSampleRate: 0.1,
  
  sendDefaultPii: false,
  
  beforeSend(event, hint) {
    if (event.request) {
      if (event.request.headers) {
        delete event.request.headers['authorization'];
        delete event.request.headers['cookie'];
        delete event.request.headers['x-api-key'];
        delete event.request.headers['x-auth-token'];
      }
      
      if (event.request.cookies) {
        event.request.cookies = {};
      }
    }
    
    if (event.user) {
      if (event.user.email) {
        event.user.email = '[REDACTED]';
      }
      if (event.user.username && event.user.username.includes('@')) {
        event.user.username = '[REDACTED]';
      }
    }
    
    if (event.extra) {
      const sensitiveKeys = ['token', 'auth', 'password', 'secret', 'api_key', 'apikey', 'tenant_id', 'tenantid'];
      Object.keys(event.extra).forEach((key) => {
        const lowerKey = key.toLowerCase();
        if (sensitiveKeys.some((sensitive) => lowerKey.includes(sensitive))) {
          event.extra![key] = '[REDACTED]';
        }
      });
    }
    
    if (event.breadcrumbs) {
      event.breadcrumbs = event.breadcrumbs.map((breadcrumb) => {
        if (breadcrumb.data) {
          const sensitiveKeys = ['token', 'auth', 'password', 'secret', 'api_key', 'apikey', 'tenant_id', 'tenantid'];
          Object.keys(breadcrumb.data).forEach((key) => {
            const lowerKey = key.toLowerCase();
            if (sensitiveKeys.some((sensitive) => lowerKey.includes(sensitive))) {
              breadcrumb.data![key] = '[REDACTED]';
            }
          });
        }
        return breadcrumb;
      });
    }
    
    return event;
  },
  
  integrations: [
    Sentry.replayIntegration({
      maskAllText: true,
      blockAllMedia: true,
    }),
  ],
});
