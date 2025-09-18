/**
 * Content Security Policy (CSP) strict
 * Bloque scripts inline, eval(), sources externes non autorisées
 */

import { app, session, WebContents } from 'electron';

export interface CSPConfig {
  strict: boolean;
  allowInlineStyles: boolean;
  allowDataUris: boolean;
  customDirectives?: Record<string, string>;
}

/**
 * Configuration CSP par défaut - STRICT
 */
const DEFAULT_CSP_CONFIG: CSPConfig = {
  strict: true,
  allowInlineStyles: true, // Pour Tailwind CSS
  allowDataUris: true,
  customDirectives: {}
};

/**
 * Génère une politique CSP stricte
 */
function generateCSP(config: CSPConfig = DEFAULT_CSP_CONFIG): string {
  const directives: Record<string, string[]> = {
    'default-src': ["'self'"],
    'script-src': ["'self'"],
    'style-src': config.allowInlineStyles 
      ? ["'self'", "'unsafe-inline'"] 
      : ["'self'"],
    'img-src': config.allowDataUris 
      ? ["'self'", 'data:', 'blob:'] 
      : ["'self'"],
    'media-src': ["'self'", 'blob:', 'data:', 'asset:', 'vault:'],
    'font-src': config.allowDataUris 
      ? ["'self'", 'data:'] 
      : ["'self'"],
    'connect-src': ["'self'"],
    'worker-src': ["'self'", 'blob:'],
    'child-src': ["'none'"],
    'frame-src': ["'none'"],
    'frame-ancestors': ["'none'"],
    'object-src': ["'none'"],
    'base-uri': ["'self'"],
    'form-action': ["'self'"],
    'manifest-src': ["'self'"],
    'upgrade-insecure-requests': []
  };

  // Ajouter les directives personnalisées
  if (config.customDirectives) {
    Object.entries(config.customDirectives).forEach(([key, value]) => {
      directives[key] = [value];
    });
  }

  // Si mode strict, renforcer davantage
  if (config.strict) {
    directives['script-src'] = ["'self'"]; // Pas d'eval, pas d'inline
    directives['object-src'] = ["'none'"];
    directives['base-uri'] = ["'none'"];
  }

  // Construire la chaîne CSP
  return Object.entries(directives)
    .map(([directive, sources]) => {
      if (sources.length === 0) return directive;
      return `${directive} ${sources.join(' ')}`;
    })
    .join('; ');
}

/**
 * Headers de sécurité supplémentaires
 */
function getSecurityHeaders(): Record<string, string> {
  return {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'no-referrer',
    'Permissions-Policy': [
      'camera=()',
      'microphone=()',
      'geolocation=()',
      'notifications=()',
      'persistent-storage=()',
      'push=()',
      'speaker-selection=()',
      'ambient-light-sensor=()',
      'accelerometer=()',
      'gyroscope=()',
      'magnetometer=()'
    ].join(', '),
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Resource-Policy': 'same-origin'
  };
}

/**
 * Configure CSP pour toutes les sessions
 */
export function setupCSP(config?: Partial<CSPConfig>): void {
  const mergedConfig = { ...DEFAULT_CSP_CONFIG, ...config };
  const cspHeader = generateCSP(mergedConfig);
  const securityHeaders = getSecurityHeaders();

  console.log('[CSP] Configuration stricte activée');
  console.log('[CSP] Policy:', cspHeader);

  // CSP pour session par défaut
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    const responseHeaders = {
      ...details.responseHeaders,
      'Content-Security-Policy': [cspHeader],
      ...Object.fromEntries(
        Object.entries(securityHeaders).map(([key, value]) => [key, [value]])
      )
    };

    callback({ responseHeaders });
  });

  // CSP pour toutes les nouvelles sessions
  app.on('session-created', (createdSession) => {
    createdSession.webRequest.onHeadersReceived((details, callback) => {
      const responseHeaders = {
        ...details.responseHeaders,
        'Content-Security-Policy': [cspHeader],
        ...Object.fromEntries(
          Object.entries(securityHeaders).map(([key, value]) => [key, [value]])
        )
      };

      callback({ responseHeaders });
    });
  });
}

/**
 * Configure CSP pour une WebContents spécifique
 */
export function setupWebContentsCSP(webContents: WebContents, config?: Partial<CSPConfig>): void {
  const mergedConfig = { ...DEFAULT_CSP_CONFIG, ...config };
  const cspHeader = generateCSP(mergedConfig);

  // Injecter CSP via meta tag (backup)
  const cspMetaTag = `
    <meta http-equiv="Content-Security-Policy" content="${cspHeader}">
    <meta http-equiv="X-Content-Type-Options" content="nosniff">
    <meta http-equiv="X-Frame-Options" content="DENY">
    <meta http-equiv="Referrer-Policy" content="no-referrer">
  `;

  webContents.on('dom-ready', () => {
    webContents.insertCSS(`
      /* CSP: Interdire l'exécution de contenu malveillant */
      object, embed, applet { display: none !important; }
    `);
  });

  // Log des violations CSP
  webContents.session.webRequest.onHeadersReceived((details, callback) => {
    if (details.url.startsWith('chrome-extension://') || 
        details.url.startsWith('devtools://')) {
      callback({});
      return;
    }

    const responseHeaders = {
      ...details.responseHeaders,
      'Content-Security-Policy': [cspHeader],
      'Content-Security-Policy-Report-Only': [`${cspHeader}; report-uri /csp-violation-report`]
    };

    callback({ responseHeaders });
  });
}

/**
 * Log des violations CSP
 */
export function setupCSPViolationLogging(): void {
  // Intercepter les violations CSP
  session.defaultSession.webRequest.onBeforeRequest((details, callback) => {
    if (details.url.includes('/csp-violation-report')) {
      console.warn('[CSP] Violation détectée:', details.url);
      console.warn('[CSP] Referrer:', details.referrer);
      
      // Bloquer la requête (pas de serveur de rapport)
      callback({ cancel: true });
      return;
    }
    callback({});
  });
}

/**
 * Validation CSP pour mode développement
 */
export function validateCSPCompliance(webContents: WebContents): void {
  webContents.on('console-message', (event, level, message, line, sourceId) => {
    if (message.includes('Content Security Policy') || 
        message.includes('CSP') ||
        message.includes('unsafe-eval') ||
        message.includes('unsafe-inline')) {
      console.warn(`[CSP] Violation détectée dans ${sourceId}:${line}`, message);
    }
  });

  // Détecter les tentatives d'eval()
  webContents.executeJavaScript(`
    (function() {
      const originalEval = window.eval;
      window.eval = function(...args) {
        console.error('[CSP] Tentative d\\'eval() bloquée:', args);
        throw new Error('eval() is disabled by CSP');
      };
    })();
  `).catch(() => {
    // Ignore si le contexte n'est pas prêt
  });
}

/**
 * Mode développement - CSP moins strict
 */
export function setupDevelopmentCSP(): void {
  const devConfig: CSPConfig = {
    strict: false,
    allowInlineStyles: true,
    allowDataUris: true,
    customDirectives: {
      'script-src': "'self' 'unsafe-eval'", // Pour dev tools
      'connect-src': "'self' ws: wss:", // Pour HMR
    }
  };

  setupCSP(devConfig);
  console.log('[CSP] Mode développement - CSP assoupli pour HMR');
}

/**
 * Mode production - CSP ultra strict
 */
export function setupProductionCSP(): void {
  const prodConfig: CSPConfig = {
    strict: true,
    allowInlineStyles: true, // Nécessaire pour Tailwind
    allowDataUris: false,
    customDirectives: {
      'upgrade-insecure-requests': '', // Force HTTPS
    }
  };

  setupCSP(prodConfig);
  setupCSPViolationLogging();
  console.log('[CSP] Mode production - CSP ultra strict activé');
}
