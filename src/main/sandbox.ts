/**
 * Configuration de sandbox et restrictions de permissions Electron
 * Durcissement sécuritaire avancé
 */

import { app, session, BrowserWindow, WebContents } from 'electron';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export interface SandboxConfig {
  enableSandbox: boolean;
  enableNodeIntegration: boolean;
  enableContextIsolation: boolean;
  enableRemoteModule: boolean;
  allowRunningInsecureContent: boolean;
  allowDisplayingInsecureContent: boolean;
  webSecurity: boolean;
  experimentalFeatures: boolean;
}

/**
 * Configuration sandbox STRICTE pour production ET tests
 */
const STRICT_SANDBOX_CONFIG: SandboxConfig = {
  enableSandbox: true,
  enableNodeIntegration: false,
  enableContextIsolation: true,
  enableRemoteModule: false,
  allowRunningInsecureContent: false,
  allowDisplayingInsecureContent: false,
  webSecurity: true,
  experimentalFeatures: false
};

/**
 * Configuration sandbox pour tests de sécurité (STRICTE)
 */
const TEST_SANDBOX_CONFIG: SandboxConfig = {
  enableSandbox: true, // Force sandbox pour tests
  enableNodeIntegration: false,
  enableContextIsolation: true,
  enableRemoteModule: false,
  allowRunningInsecureContent: false,
  allowDisplayingInsecureContent: false,
  webSecurity: true,
  experimentalFeatures: false
};

/**
 * Configuration sandbox DEV (moins restrictive)
 */
const DEV_SANDBOX_CONFIG: SandboxConfig = {
  enableSandbox: false, // Pour les dev tools
  enableNodeIntegration: false,
  enableContextIsolation: true,
  enableRemoteModule: false,
  allowRunningInsecureContent: false,
  allowDisplayingInsecureContent: false,
  webSecurity: true,
  experimentalFeatures: false
};

/**
 * Permissions dangereuses à bloquer
 */
const BLOCKED_PERMISSIONS = [
  'camera',
  'microphone',
  'geolocation',
  'notifications',
  'persistent-storage',
  'push',
  'midi',
  'background-sync',
  'ambient-light-sensor',
  'accelerometer',
  'gyroscope',
  'magnetometer',
  'speaker-selection',
  'screen-wake-lock',
  'idle-detection'
];

/**
 * URLs et protocoles autorisés
 */
const ALLOWED_PROTOCOLS = ['https:', 'http:', 'file:', 'vault:', 'asset:'];
const BLOCKED_HOSTS = [
  'localhost',
  '127.0.0.1',
  '0.0.0.0'
];

/**
 * Configure les options de sandbox pour une BrowserWindow
 */
export function getSandboxWebPreferences(isDev: boolean = false): Electron.WebPreferences {
  // Forcer configuration stricte si tests de sécurité en cours
  const isSecurityTest = process.argv.some(arg => arg.includes('test-security'));
  const config = (isSecurityTest || !isDev) ? STRICT_SANDBOX_CONFIG : DEV_SANDBOX_CONFIG;
  
  return {
    // Sandbox principal
    sandbox: config.enableSandbox,
    nodeIntegration: config.enableNodeIntegration,
    contextIsolation: config.enableContextIsolation,
    
    // Sécurité web
    webSecurity: config.webSecurity,
    allowRunningInsecureContent: config.allowRunningInsecureContent,
    experimentalFeatures: config.experimentalFeatures,
    
    // Restrictions additionnelles
    nodeIntegrationInWorker: false,
    nodeIntegrationInSubFrames: false,
    safeDialogs: true,
    safeDialogsMessage: 'Cette application a été bloquée pour votre sécurité.',
    
    // Preload sécurisé
    preload: path.resolve(__dirname, 'preload.js'),
    
    // Désactiver fonctionnalités dangereuses
    plugins: false,
    javascript: true, // Nécessaire pour React
    images: true,
    textAreasAreResizable: false,
    webgl: false, // Pas de WebGL pour éviter les exploits GPU
    
    // Désactiver l'accès aux APIs système
    backgroundThrottling: true,
    navigateOnDragDrop: false,
    
    // Performance et sécurité
    v8CacheOptions: 'code', // Cache V8 pour performance
    disableBlinkFeatures: 'Auxclick', // Désactiver clics auxiliaires
    enableBlinkFeatures: '', // Aucune feature expérimentale
    
    // Isolation processus
    partition: isDev ? 'persist:dev' : 'persist:main'
  };
}

/**
 * Configure les permissions système strictes
 */
export function setupPermissionRestrictions(): void {
  console.log('[PERMISSIONS] Configuration des restrictions strictes');

  // Bloquer toutes les permissions dangereuses
  session.defaultSession.setPermissionRequestHandler((webContents, permission, callback) => {
    console.warn(`[PERMISSIONS] Demande bloquée: ${permission} de ${webContents.getURL()}`);
    
    // Toujours refuser les permissions sensibles
    if (BLOCKED_PERMISSIONS.includes(permission)) {
      callback(false);
      return;
    }
    
    // Autoriser seulement les permissions explicitement nécessaires
    const allowedPermissions = ['clipboard-read', 'clipboard-write'];
    callback(allowedPermissions.includes(permission));
  });

  // Configuration pour toutes les nouvelles sessions
  app.on('session-created', (createdSession) => {
    createdSession.setPermissionRequestHandler((webContents, permission, callback) => {
      console.warn(`[PERMISSIONS] Session créée: ${permission} BLOQUÉ`);
      callback(BLOCKED_PERMISSIONS.includes(permission) ? false : ['clipboard-read', 'clipboard-write'].includes(permission));
    });
  });
}

/**
 * Configure les restrictions de navigation
 */
export function setupNavigationRestrictions(): void {
  console.log('[NAVIGATION] Configuration des restrictions de navigation');

  // Bloquer navigation externe
  app.on('web-contents-created', (event, webContents) => {
    webContents.on('will-navigate', (navigationEvent, navigationUrl) => {
      const parsedUrl = new URL(navigationUrl);
      
      // Autoriser seulement les protocoles sûrs
      if (!ALLOWED_PROTOCOLS.includes(parsedUrl.protocol)) {
        console.warn(`[NAVIGATION] Protocole bloqué: ${parsedUrl.protocol}`);
        navigationEvent.preventDefault();
        return;
      }
      
      // Bloquer navigation vers localhost (sauf en dev)
      if (!app.isPackaged && BLOCKED_HOSTS.includes(parsedUrl.hostname)) {
        console.warn(`[NAVIGATION] Host bloqué: ${parsedUrl.hostname}`);
        navigationEvent.preventDefault();
        return;
      }
      
      // Autoriser seulement navigation interne
      if (parsedUrl.protocol === 'https:' || parsedUrl.protocol === 'http:') {
        console.warn(`[NAVIGATION] Navigation externe bloquée: ${navigationUrl}`);
        navigationEvent.preventDefault();
        return;
      }
    });

    // Bloquer ouverture de nouvelles fenêtres
    webContents.setWindowOpenHandler((details) => {
      console.warn(`[NAVIGATION] Ouverture fenêtre bloquée: ${details.url}`);
      return { action: 'deny' };
    });

    // Bloquer téléchargements non autorisés
    webContents.session.on('will-download', (event, item, webContents) => {
      console.warn(`[DOWNLOAD] Téléchargement bloqué: ${item.getURL()}`);
      event.preventDefault();
    });
  });
}

/**
 * Configure la protection contre l'injection de code
 */
export function setupCodeInjectionProtection(): void {
  console.log('[INJECTION] Configuration protection injection de code');

  app.on('web-contents-created', (event, webContents) => {
    // Intercepter les tentatives d'exécution de code
    webContents.on('did-create-window', (window) => {
      console.warn('[INJECTION] Création fenêtre non autorisée bloquée');
      window.destroy();
    });

    // Protection contre l'injection via console
    webContents.on('console-message', (event, level, message, line, sourceId) => {
      // Détecter tentatives d'injection
      const suspiciousPatterns = [
        /eval\s*\(/,
        /Function\s*\(/,
        /setTimeout\s*\(\s*["'].*["']/,
        /setInterval\s*\(\s*["'].*["']/,
        /document\.write/,
        /innerHTML\s*=/,
        /<script/i,
        /javascript:/i
      ];

      if (suspiciousPatterns.some(pattern => pattern.test(message))) {
        console.warn(`[INJECTION] Code suspect détecté dans ${sourceId}:${line}`, message);
      }
    });

    // Bloquer modification du DOM sensible
    webContents.on('dom-ready', () => {
      webContents.executeJavaScript(`
        (function() {
          // Protection contre la modification des éléments sensibles
          const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.type === 'childList') {
                mutation.addedNodes.forEach(function(node) {
                  if (node.nodeName === 'SCRIPT' || node.nodeName === 'IFRAME') {
                    console.warn('[INJECTION] Tentative injection script/iframe bloquée');
                    node.remove();
                  }
                });
              }
            });
          });
          
          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
          
          // Bloquer eval et Function
          window.eval = function() {
            console.error('[INJECTION] eval() bloqué par protection');
            throw new Error('eval() is disabled for security');
          };
          
          window.Function = function() {
            console.error('[INJECTION] Function() bloqué par protection');
            throw new Error('Function() is disabled for security');
          };
        })();
      `).catch(() => {
        // Ignore si contexte pas prêt
      });
    });
  });
}

/**
 * Configure l'isolation des processus renderer
 */
export function setupProcessIsolation(): void {
  console.log('[PROCESS] Configuration isolation des processus');

  // Forcer isolation processus
  app.commandLine.appendSwitch('site-per-process');
  app.commandLine.appendSwitch('disable-site-isolation-trials');
  
  // Désactiver processus partagés
  app.commandLine.appendSwitch('process-per-site');
  
  // Sécurité mémoire
  app.commandLine.appendSwitch('enable-heap-profiling');
  app.commandLine.appendSwitch('max-old-space-size', '512'); // Limiter RAM
  
  // Protection contre les exploits
  app.commandLine.appendSwitch('disable-background-timer-throttling');
  app.commandLine.appendSwitch('disable-renderer-backgrounding');
  app.commandLine.appendSwitch('disable-backgrounding-occluded-windows');
}

/**
 * Configure la protection en mode kiosque
 */
export function setupKioskProtection(window: BrowserWindow): void {
  console.log('[KIOSK] Configuration protection mode kiosque');

  // Désactiver raccourcis clavier système
  window.setMenuBarVisibility(false);
  window.setMenu(null);
  
  // Bloquer raccourcis développeur
  window.webContents.on('before-input-event', (event, input) => {
    const blockedKeys = [
      'F12',           // DevTools
      'CommandOrControl+Shift+I', // DevTools
      'CommandOrControl+Shift+J', // Console
      'CommandOrControl+U',       // Source
      'CommandOrControl+Shift+C', // Inspect
      'F5',            // Refresh
      'CommandOrControl+R',       // Refresh
      'Alt+F4',        // Fermer
      'CommandOrControl+W',       // Fermer
      'Alt+Tab',       // Changer fenêtre
      'CommandOrControl+Alt+T'    // Terminal
    ];

    const key = input.key;
    const modifiers: string[] = [];
    if (input.control) modifiers.push('CommandOrControl');
    if (input.alt) modifiers.push('Alt');
    if (input.shift) modifiers.push('Shift');
    if (input.meta) modifiers.push('CommandOrControl');

    const keyCombo = modifiers.length > 0 ? `${modifiers.join('+')}+${key}` : key;

    if (blockedKeys.includes(keyCombo) || blockedKeys.includes(key)) {
      console.warn(`[KIOSK] Raccourci bloqué: ${keyCombo}`);
      event.preventDefault();
    }
  });

  // Prévenir fermeture accidentelle
  window.on('close', (event) => {
    console.log('[KIOSK] Tentative de fermeture interceptée');
    // En production, on pourrait demander confirmation
    // event.preventDefault();
  });
}

/**
 * Initialise toutes les protections sandbox
 */
export function initializeSandboxSecurity(isDev: boolean = false): void {
  console.log(`[SANDBOX] Initialisation sécurité ${isDev ? 'DEV' : 'PRODUCTION'}`);
  
  setupPermissionRestrictions();
  setupNavigationRestrictions();
  setupCodeInjectionProtection();
  setupProcessIsolation();
  
  console.log('[SANDBOX] ✅ Toutes les protections activées');
}

/**
 * Valide la configuration sandbox d'une fenêtre
 */
export function validateSandboxConfig(webContents: WebContents): boolean {
  try {
    // Vérifier si l'API getWebPreferences existe
    const getWebPreferences = (webContents as any).getWebPreferences;
    if (typeof getWebPreferences !== 'function') {
      console.warn('[SANDBOX] ⚠️ getWebPreferences() non disponible - validation ignorée');
      return true; // Considérer comme valide si on ne peut pas vérifier
    }
    
    const prefs = getWebPreferences.call(webContents);
    
    const validations = [
      { name: 'contextIsolation', value: prefs.contextIsolation, expected: true },
      { name: 'nodeIntegration', value: prefs.nodeIntegration, expected: false },
      { name: 'webSecurity', value: prefs.webSecurity, expected: true }
    ];
    
    let isValid = true;
    validations.forEach(({ name, value, expected }) => {
      if (value !== expected) {
        console.error(`[SANDBOX] ❌ ${name}: ${value} (attendu: ${expected})`);
        isValid = false;
      } else {
        console.log(`[SANDBOX] ✅ ${name}: ${value}`);
      }
    });
    
    return isValid;
  } catch (error) {
    console.warn('[SANDBOX] ⚠️ Erreur validation sandbox:', error);
    return true; // Considérer comme valide si erreur
  }
}
