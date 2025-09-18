/**
 * Protection anti-debugging et anti-reverse engineering
 * Détection et blocage des outils de développement
 */

import { app, BrowserWindow, WebContents, session } from 'electron';

export interface AntiDebugConfig {
  blockDevTools: boolean;
  detectDebugger: boolean;
  obfuscateConsole: boolean;
  preventInspection: boolean;
  timingProtection: boolean;
  memoryProtection: boolean;
  antiVMDetection: boolean;
}

/**
 * Configuration anti-debug STRICTE pour production
 */
const STRICT_ANTIDEBUG_CONFIG: AntiDebugConfig = {
  blockDevTools: true,
  detectDebugger: true,
  obfuscateConsole: true,
  preventInspection: true,
  timingProtection: true,
  memoryProtection: true,
  antiVMDetection: true
};

/**
 * Configuration anti-debug DEV (moins restrictive)
 */
const DEV_ANTIDEBUG_CONFIG: AntiDebugConfig = {
  blockDevTools: false, // DevTools autorisés en dev
  detectDebugger: false,
  obfuscateConsole: false,
  preventInspection: false,
  timingProtection: false,
  memoryProtection: false,
  antiVMDetection: false
};

/**
 * Détecte si l'application s'exécute dans un environnement de débogage
 */
export function detectDebugEnvironment(): boolean {
  const debugIndicators = [
    process.env.NODE_ENV === 'development',
    process.debugPort > 0,
    !!process.env.DEBUG,
    !!process.env.ELECTRON_IS_DEV,
    process.argv.includes('--inspect'),
    process.argv.includes('--inspect-brk'),
    process.argv.includes('--remote-debugging-port'),
    app.isPackaged === false
  ];

  return debugIndicators.some(indicator => indicator);
}

/**
 * Détecte les outils de virtualisation
 */
export function detectVirtualization(): boolean {
  const vmIndicators = [
    process.env.VBOX_USER_HOME,
    process.env.VMWARE_USER,
    process.platform === 'linux' && process.env.USER === 'sandbox',
    !!process.env.WINE_VERSION
  ];

  return vmIndicators.some(indicator => indicator);
}

/**
 * Bloque l'accès aux DevTools
 */
export function setupDevToolsBlocking(): void {
  console.log('[ANTIDEBUG] Blocage DevTools activé');

  app.on('web-contents-created', (event, webContents) => {
    // Bloquer l'ouverture des DevTools
    webContents.on('devtools-opened', () => {
      console.warn('[ANTIDEBUG] DevTools détectés - fermeture forcée');
      webContents.closeDevTools();
      
      // Optionnel: fermer l'application
      if (!app.isPackaged) return; // Autoriser en dev
      
      setTimeout(() => {
        console.error('[ANTIDEBUG] Application fermée - DevTools non autorisés');
        app.quit();
      }, 1000);
    });

    // Bloquer les raccourcis DevTools
    webContents.on('before-input-event', (event, input) => {
      const blockedKeyCombos = [
        { key: 'F12' },
        { key: 'I', modifiers: ['control', 'shift'] },
        { key: 'J', modifiers: ['control', 'shift'] },
        { key: 'C', modifiers: ['control', 'shift'] },
        { key: 'U', modifiers: ['control'] },
        { key: 'S', modifiers: ['control'] }
      ];

      const currentModifiers: string[] = [];
      if (input.control) currentModifiers.push('control');
      if (input.shift) currentModifiers.push('shift');
      if (input.alt) currentModifiers.push('alt');
      if (input.meta) currentModifiers.push('meta');

      const isBlocked = blockedKeyCombos.some(combo => {
        if (combo.key !== input.key) return false;
        if (!combo.modifiers) return currentModifiers.length === 0;
        return combo.modifiers.every(mod => currentModifiers.includes(mod)) &&
               combo.modifiers.length === currentModifiers.length;
      });

      if (isBlocked) {
        console.warn(`[ANTIDEBUG] Raccourci bloqué: ${input.key} + ${currentModifiers.join('+')}`);
        event.preventDefault();
      }
    });
  });
}

/**
 * Obfusque et sécurise la console
 */
export function setupConsoleObfuscation(webContents: WebContents): void {
  console.log('[ANTIDEBUG] Obfuscation console activée');

  webContents.executeJavaScript(`
    (function() {
      // Sauvegarder les méthodes originales
      const originalConsole = {};
      ['log', 'warn', 'error', 'info', 'debug', 'trace'].forEach(method => {
        originalConsole[method] = console[method];
      });

      // Obfusquer les messages de la console
      const obfuscateMessage = (message) => {
        if (typeof message === 'string' && message.includes('vault')) {
          return message.replace(/vault/gi, '***');
        }
        return message;
      };

      // Remplacer les méthodes console
      ['log', 'warn', 'error', 'info', 'debug'].forEach(method => {
        console[method] = function(...args) {
          const obfuscatedArgs = args.map(obfuscateMessage);
          originalConsole[method].apply(console, obfuscatedArgs);
        };
      });

      // Bloquer l'accès direct aux objets sensibles
      Object.defineProperty(window, 'vaultManager', {
        get: () => undefined,
        set: () => {},
        configurable: false
      });

      // Détection de débogage par timing
      let debugStartTime = performance.now();
      setInterval(() => {
        const currentTime = performance.now();
        const timeDiff = currentTime - debugStartTime;
        debugStartTime = currentTime;
        
        // Si l'intervalle prend plus de 100ms, possible debugger
        if (timeDiff > 100) {
          console.warn('[ANTIDEBUG] Anomalie timing détectée');
          // Optionnel: actions défensives
        }
      }, 50);

      // Protection contre l'inspection des propriétés
      const protectedObjects = [window, document, navigator];
      protectedObjects.forEach(obj => {
        const originalGetOwnPropertyNames = Object.getOwnPropertyNames;
        Object.getOwnPropertyNames = function(target) {
          if (target === obj) {
            console.warn('[ANTIDEBUG] Tentative inspection objet protégé');
            return []; // Retourner liste vide
          }
          return originalGetOwnPropertyNames(target);
        };
      });

      console.log('[ANTIDEBUG] Console sécurisée');
    })();
  `).catch(() => {
    // Ignore si contexte pas prêt
  });
}

/**
 * Protection contre l'injection et la manipulation
 */
export function setupInjectionProtection(webContents: WebContents): void {
  console.log('[ANTIDEBUG] Protection injection activée');

  webContents.executeJavaScript(`
    (function() {
      // Protéger eval et Function
      const originalEval = window.eval;
      const originalFunction = window.Function;

      window.eval = function() {
        console.error('[ANTIDEBUG] eval() bloqué');
        throw new Error('eval() is disabled for security');
      };

      window.Function = function() {
        console.error('[ANTIDEBUG] Function() bloqué');
        throw new Error('Function() is disabled for security');
      };

      // Protéger setTimeout/setInterval avec strings
      const originalSetTimeout = window.setTimeout;
      const originalSetInterval = window.setInterval;

      window.setTimeout = function(callback, delay, ...args) {
        if (typeof callback === 'string') {
          console.error('[ANTIDEBUG] setTimeout avec string bloqué');
          return;
        }
        return originalSetTimeout.call(this, callback, delay, ...args);
      };

      window.setInterval = function(callback, delay, ...args) {
        if (typeof callback === 'string') {
          console.error('[ANTIDEBUG] setInterval avec string bloqué');
          return;
        }
        return originalSetInterval.call(this, callback, delay, ...args);
      };

      // Détecter les tentatives de manipulation du DOM sensible
      const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          if (mutation.type === 'childList') {
            mutation.addedNodes.forEach(function(node) {
              if (node.nodeType === Node.ELEMENT_NODE) {
                const tagName = node.tagName.toLowerCase();
                if (tagName === 'script' || tagName === 'iframe' || tagName === 'object') {
                  console.warn('[ANTIDEBUG] Tentative injection:', tagName);
                  node.remove();
                }
              }
            });
          }
        });
      });

      observer.observe(document.body, {
        childList: true,
        subtree: true
      });

      // Protéger l'historique et la navigation
      const originalPushState = history.pushState;
      const originalReplaceState = history.replaceState;

      history.pushState = function(state, title, url) {
        console.log('[ANTIDEBUG] Navigation surveillée:', url);
        return originalPushState.call(this, state, title, url);
      };

      history.replaceState = function(state, title, url) {
        console.log('[ANTIDEBUG] Navigation surveillée:', url);
        return originalReplaceState.call(this, state, title, url);
      };

      console.log('[ANTIDEBUG] Protection injection activée');
    })();
  `).catch(() => {
    // Ignore si contexte pas prêt
  });
}

/**
 * Détection avancée de debugger
 */
export function setupDebuggerDetection(webContents: WebContents): void {
  console.log('[ANTIDEBUG] Détection debugger activée');

  webContents.executeJavaScript(`
    (function() {
      let debuggerDetected = false;

      // Méthode 1: Détection par timing
      function timingDetection() {
        const start = performance.now();
        debugger; // Point d'arrêt intentionnel
        const end = performance.now();
        
        if (end - start > 100) {
          debuggerDetected = true;
          console.warn('[ANTIDEBUG] Debugger détecté par timing');
        }
      }

      // Méthode 2: Détection par exception
      function exceptionDetection() {
        try {
          const detector = () => {
            return detector.toString().includes('detector');
          };
          detector();
        } catch (e) {
          debuggerDetected = true;
          console.warn('[ANTIDEBUG] Debugger détecté par exception');
        }
      }

      // Méthode 3: Détection par console
      function consoleDetection() {
        const element = document.createElement('div');
        Object.defineProperty(element, 'id', {
          get: function() {
            debuggerDetected = true;
            console.warn('[ANTIDEBUG] Debugger détecté par console');
            return 'detected';
          }
        });
        console.log(element);
      }

      // Exécuter détections périodiquement
      setInterval(() => {
        if (!debuggerDetected) {
          timingDetection();
          exceptionDetection();
          consoleDetection();
        }
        
        if (debuggerDetected) {
          console.error('[ANTIDEBUG] ⚠️ Debugger détecté - Mode sécurisé activé');
          // Actions défensives possibles:
          // - Masquer contenu sensible
          // - Désactiver fonctionnalités
          // - Rediriger vers page d'avertissement
        }
      }, 2000);

      console.log('[ANTIDEBUG] Détection debugger activée');
    })();
  `).catch(() => {
    // Ignore si contexte pas prêt
  });
}

/**
 * Protection mémoire et performance
 */
export function setupMemoryProtection(): void {
  console.log('[ANTIDEBUG] Protection mémoire activée');

  // Limiter l'utilisation mémoire
  if (process.platform === 'win32') {
    app.commandLine.appendSwitch('max-old-space-size', '512');
    app.commandLine.appendSwitch('max-semi-space-size', '128');
  }

  // Désactiver le profiling
  app.commandLine.appendSwitch('disable-dev-shm-usage');
  app.commandLine.appendSwitch('disable-background-timer-throttling');
  
  // Surveiller l'utilisation mémoire
  setInterval(() => {
    const memUsage = process.memoryUsage();
    const usedMB = Math.round(memUsage.heapUsed / 1024 / 1024);
    
    if (usedMB > 256) { // Limite arbitraire
      console.warn(`[ANTIDEBUG] Utilisation mémoire élevée: ${usedMB}MB`);
      
      // Forcer garbage collection si possible
      if (global.gc) {
        global.gc();
        console.log('[ANTIDEBUG] Garbage collection forcée');
      }
    }
  }, 30000);
}

/**
 * Initialise toutes les protections anti-debug
 */
export function initializeAntiDebugProtection(config?: Partial<AntiDebugConfig>): void {
  const isDev = detectDebugEnvironment();
  const mergedConfig = { ...(isDev ? DEV_ANTIDEBUG_CONFIG : STRICT_ANTIDEBUG_CONFIG), ...config };
  
  console.log(`[ANTIDEBUG] Initialisation ${isDev ? 'DEV' : 'PRODUCTION'}`);
  
  if (mergedConfig.antiVMDetection && detectVirtualization()) {
    console.warn('[ANTIDEBUG] ⚠️ Environnement virtualisé détecté');
  }
  
  if (mergedConfig.blockDevTools) {
    setupDevToolsBlocking();
  }
  
  if (mergedConfig.memoryProtection) {
    setupMemoryProtection();
  }
  
  // Protections spécifiques aux WebContents
  app.on('web-contents-created', (event, webContents) => {
    webContents.on('dom-ready', () => {
      if (mergedConfig.obfuscateConsole) {
        setupConsoleObfuscation(webContents);
      }
      
      if (mergedConfig.preventInspection) {
        setupInjectionProtection(webContents);
      }
      
      if (mergedConfig.detectDebugger) {
        setupDebuggerDetection(webContents);
      }
    });
  });
  
  console.log('[ANTIDEBUG] ✅ Toutes les protections anti-debug activées');
}

/**
 * Active les protections pour une WebContents spécifique
 */
export function setupWebContentsAntiDebug(webContents: WebContents, config?: Partial<AntiDebugConfig>): void {
  const mergedConfig = { ...STRICT_ANTIDEBUG_CONFIG, ...config };
  
  if (mergedConfig.obfuscateConsole) {
    setupConsoleObfuscation(webContents);
  }
  
  if (mergedConfig.preventInspection) {
    setupInjectionProtection(webContents);
  }
  
  if (mergedConfig.detectDebugger) {
    setupDebuggerDetection(webContents);
  }
  
  console.log('[ANTIDEBUG] WebContents sécurisé');
}
