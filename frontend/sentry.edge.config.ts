import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  
  environment: process.env.SENTRY_ENVIRONMENT || process.env.NODE_ENV,
  
  tracesSampleRate: 0.1,
  
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
      const sensitiveKeys = [
        'token',
        'auth',
        'password',
        'secret',
        'api_key',
        'apikey',
        'tenant_id',
        'tenantid',
        'access_token',
        'refresh_token',
        'client_secret',
        'graph_token',
        'microsoft_token',
      ];
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
          const sensitiveKeys = [
            'token',
            'auth',
            'password',
            'secret',
            'api_key',
            'apikey',
            'tenant_id',
            'tenantid',
            'access_token',
            'refresh_token',
            'client_secret',
            'graph_token',
            'microsoft_token',
          ];
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
});
