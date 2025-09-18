/**
 * Système de sécurité avancé pour le lecteur détachable
 * Protection contre capture d'écran, watermark, mode kiosque
 */

import { BrowserWindow, screen, globalShortcut, systemPreferences } from 'electron';
import { 
  DisplaySecurity, 
  PlayerSecurityState, 
  SecurityViolation, 
  WatermarkConfig,
  KioskModeConfig 
} from '../types/security.js';

// Configuration par défaut de sécurité maximale
const DEFAULT_SECURITY: DisplaySecurity = {
  preventScreenCapture: true,
  watermark: {
    text: '© USB Video Vault - Lecture autorisée',
    position: 'bottom-right',
    opacity: 0.7,
    size: 14,
    color: '#ffffff',
    rotation: -25,
    frequency: 30 // Toutes les 30 secondes
  },
  kioskMode: true,
  antiDebug: true,
  hideTaskbar: false, // Peut causer des problèmes sur certains systèmes
  exclusiveFullscreen: true,
  displayControl: {
    allowedDisplays: [], // Vide = tous autorisés
    preventMirror: true,
    detectExternalCapture: true
  }
};

const DEFAULT_KIOSK: KioskModeConfig = {
  blockAltTab: true,
  blockWinKey: true,
  blockCtrlAltDel: false, // Sécurité système
  blockTaskManager: true,
  hideMouseCursor: false,
  preventWindowSwitch: true
};

class PlayerSecurity {
  private state: PlayerSecurityState;
  private window: BrowserWindow | null = null;
  private securityInterval: NodeJS.Timeout | null = null;
  private watermarkInterval: NodeJS.Timeout | null = null;
  private registeredShortcuts: string[] = [];

  constructor() {
    this.state = {
      isSecured: false,
      securityFeatures: { ...DEFAULT_SECURITY },
      violations: [],
      lastCheck: 0
    };
  }

  /**
   * Active la sécurité pour une fenêtre de lecteur
   */
  async enableSecurity(window: BrowserWindow, config?: Partial<DisplaySecurity>): Promise<void> {
    console.log('[SECURITY] Activation du mode sécurisé...');
    
    this.window = window;
    this.state.securityFeatures = { ...DEFAULT_SECURITY, ...config };
    this.state.isSecured = true;

    try {
      // 1. Protection contre capture d'écran
      if (this.state.securityFeatures.preventScreenCapture) {
        await this.enableScreenCaptureProtection();
      }

      // 2. Mode kiosque
      if (this.state.securityFeatures.kioskMode) {
        await this.enableKioskMode();
      }

      // 3. Watermark
      await this.enableWatermark();

      // 4. Anti-debug
      if (this.state.securityFeatures.antiDebug) {
        await this.enableAntiDebug();
      }

      // 5. Contrôle d'affichage
      await this.enableDisplayControl();

      // 6. Surveillance continue
      this.startSecurityMonitoring();

      console.log('[SECURITY] ✅ Mode sécurisé activé');
      
    } catch (error) {
      console.error('[SECURITY] ❌ Erreur activation sécurité:', error);
      this.addViolation('external_app', `Erreur activation sécurité: ${error}`, 'high', 'warn');
    }
  }

  /**
   * Désactive la sécurité
   */
  async disableSecurity(): Promise<void> {
    console.log('[SECURITY] Désactivation du mode sécurisé...');

    try {
      // Arrêter la surveillance
      if (this.securityInterval) {
        clearInterval(this.securityInterval);
        this.securityInterval = null;
      }

      if (this.watermarkInterval) {
        clearInterval(this.watermarkInterval);
        this.watermarkInterval = null;
      }

      // Désactiver le mode kiosque
      await this.disableKioskMode();

      // Retirer protection capture d'écran
      await this.disableScreenCaptureProtection();

      this.state.isSecured = false;
      this.window = null;

      console.log('[SECURITY] ✅ Mode sécurisé désactivé');

    } catch (error) {
      console.error('[SECURITY] ❌ Erreur désactivation sécurité:', error);
    }
  }

  /**
   * Protection contre capture d'écran
   */
  private async enableScreenCaptureProtection(): Promise<void> {
    if (!this.window) return;

    try {
      // Electron: setContentProtection (Windows/macOS)
      this.window.setContentProtection(true);
      
      // Masquer la fenêtre dans les captures d'écran
      if (process.platform === 'win32') {
        // Windows: WDA_EXCLUDEFROMCAPTURE
        this.window.setSkipTaskbar(false); // Garder dans taskbar mais protéger
        
        // Injecter du code natif pour WDA_EXCLUDEFROMCAPTURE si possible
        this.window.webContents.executeJavaScript(`
          // Protection côté renderer
          document.addEventListener('keydown', (e) => {
            // Bloquer PrintScreen
            if (e.key === 'PrintScreen') {
              e.preventDefault();
              e.stopPropagation();
              console.warn('[SECURITY] Capture d\\'écran bloquée');
              return false;
            }
            // Bloquer Ctrl+Shift+I (DevTools)
            if (e.ctrlKey && e.shiftKey && e.key === 'I') {
              e.preventDefault();
              e.stopPropagation();
              return false;
            }
          });
          
          // Protection contre right-click
          document.addEventListener('contextmenu', (e) => e.preventDefault());
          
          // Protection contre sélection de texte
          document.addEventListener('selectstart', (e) => e.preventDefault());
        `);
      }

      console.log('[SECURITY] ✅ Protection capture d\'écran activée');

    } catch (error) {
      console.error('[SECURITY] ❌ Erreur protection capture:', error);
      this.addViolation('screen_capture', `Protection capture échouée: ${error}`, 'medium', 'warn');
    }
  }

  /**
   * Désactive protection capture d'écran
   */
  private async disableScreenCaptureProtection(): Promise<void> {
    if (!this.window) return;
    
    try {
      this.window.setContentProtection(false);
      console.log('[SECURITY] ✅ Protection capture d\'écran désactivée');
    } catch (error) {
      console.error('[SECURITY] ❌ Erreur désactivation protection capture:', error);
    }
  }

  /**
   * Mode kiosque - bloque les raccourcis système
   */
  private async enableKioskMode(): Promise<void> {
    const config = DEFAULT_KIOSK;
    
    try {
      // Désactiver les raccourcis globaux dangereux
      const shortcuts: string[] = [];
      
      if (config.blockAltTab) {
        shortcuts.push('Alt+Tab', 'Alt+Shift+Tab');
      }
      
      if (config.blockWinKey) {
        shortcuts.push('CommandOrControl+Escape', 'CommandOrControl+Shift+Escape');
      }
      
      if (config.blockTaskManager) {
        shortcuts.push('Control+Shift+Escape', 'Control+Alt+Delete');
      }

      // Raccourcis de développement
      shortcuts.push(
        'F12', 'CommandOrControl+Shift+I', 'CommandOrControl+Shift+J',
        'CommandOrControl+U', 'CommandOrControl+Shift+C'
      );

      // Enregistrer les raccourcis
      for (const shortcut of shortcuts) {
        try {
          globalShortcut.register(shortcut, () => {
            console.log(`[SECURITY] Raccourci bloqué: ${shortcut}`);
            this.addViolation('external_app', `Tentative raccourci: ${shortcut}`, 'low', 'warn');
          });
          this.registeredShortcuts.push(shortcut);
        } catch (err) {
          console.warn(`[SECURITY] Impossible de bloquer raccourci ${shortcut}:`, err);
        }
      }

      // Plein écran exclusif
      if (this.state.securityFeatures.exclusiveFullscreen && this.window) {
        this.window.setFullScreen(true);
        this.window.setAlwaysOnTop(true);
        this.window.setSkipTaskbar(false); // Garder accessible via taskbar
      }

      console.log(`[SECURITY] ✅ Mode kiosque activé (${shortcuts.length} raccourcis bloqués)`);

    } catch (error) {
      console.error('[SECURITY] ❌ Erreur mode kiosque:', error);
      this.addViolation('external_app', `Mode kiosque échoué: ${error}`, 'medium', 'warn');
    }
  }

  /**
   * Désactive le mode kiosque
   */
  private async disableKioskMode(): Promise<void> {
    try {
      // Supprimer tous les raccourcis enregistrés
      for (const shortcut of this.registeredShortcuts) {
        try {
          globalShortcut.unregister(shortcut);
        } catch (err) {
          console.warn(`[SECURITY] Impossible de supprimer raccourci ${shortcut}:`, err);
        }
      }
      this.registeredShortcuts = [];

      // Restaurer fenêtre normale
      if (this.window && !this.window.isDestroyed()) {
        this.window.setAlwaysOnTop(false);
      }

      console.log('[SECURITY] ✅ Mode kiosque désactivé');

    } catch (error) {
      console.error('[SECURITY] ❌ Erreur désactivation mode kiosque:', error);
    }
  }

  /**
   * Watermark anti-piratage
   */
  private async enableWatermark(): Promise<void> {
    if (!this.window) return;

    const config = this.state.securityFeatures.watermark;
    
    try {
      // Injecter le watermark dans la page
      await this.window.webContents.executeJavaScript(`
        (() => {
          // Supprimer watermark existant
          const existing = document.getElementById('security-watermark');
          if (existing) existing.remove();

          // Créer le watermark
          const watermark = document.createElement('div');
          watermark.id = 'security-watermark';
          watermark.textContent = '${config.text}';
          
          // Style du watermark
          Object.assign(watermark.style, {
            position: 'fixed',
            zIndex: '999999',
            pointerEvents: 'none',
            userSelect: 'none',
            fontFamily: 'Arial, sans-serif',
            fontSize: '${config.size}px',
            color: '${config.color}',
            opacity: '${config.opacity}',
            transform: 'rotate(${config.rotation}deg)',
            textShadow: '1px 1px 2px rgba(0,0,0,0.8)',
            whiteSpace: 'nowrap'
          });

          // Position selon config
          switch ('${config.position}') {
            case 'top-left':
              watermark.style.top = '20px';
              watermark.style.left = '20px';
              break;
            case 'top-right':
              watermark.style.top = '20px';
              watermark.style.right = '20px';
              break;
            case 'bottom-left':
              watermark.style.bottom = '20px';
              watermark.style.left = '20px';
              break;
            case 'bottom-right':
              watermark.style.bottom = '20px';
              watermark.style.right = '20px';
              break;
            case 'center':
              watermark.style.top = '50%';
              watermark.style.left = '50%';
              watermark.style.transform += ' translate(-50%, -50%)';
              break;
          }

          document.body.appendChild(watermark);
          
          return 'Watermark ajouté';
        })();
      `);

      // Renouveler le watermark périodiquement
      this.watermarkInterval = setInterval(async () => {
        if (this.window && !this.window.isDestroyed()) {
          try {
            await this.enableWatermark();
          } catch (err) {
            console.warn('[SECURITY] Erreur renouvellement watermark:', err);
          }
        }
      }, config.frequency * 1000);

      console.log('[SECURITY] ✅ Watermark activé');

    } catch (error) {
      console.error('[SECURITY] ❌ Erreur watermark:', error);
      this.addViolation('external_app', `Watermark échoué: ${error}`, 'low', 'warn');
    }
  }

  /**
   * Anti-debug - détection d'outils de développement
   */
  private async enableAntiDebug(): Promise<void> {
    if (!this.window) return;

    try {
      // Injecter code anti-debug dans la page
      await this.window.webContents.executeJavaScript(`
        (() => {
          // Détection DevTools ouvert (timing)
          let devtools = { open: false };
          const element = new Image();
          element.__defineGetter__('id', function() {
            devtools.open = true;
            console.warn('[SECURITY] DevTools détectés !');
          });
          
          setInterval(() => {
            devtools.open = false;
            console.clear();
            console.log(element);
            if (devtools.open) {
              // DevTools détectés
              window.electronAPI?.security?.violation?.('debug_detected', 'DevTools ouvert détecté');
            }
          }, 1000);

          // Détection debugger
          setInterval(() => {
            const start = performance.now();
            debugger; // Va pausr si debugger actif
            const end = performance.now();
            if (end - start > 100) {
              window.electronAPI?.security?.violation?.('debug_detected', 'Debugger actif détecté');
            }
          }, 2000);

          // Protection contre modification du DOM
          const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
              if (mutation.type === 'childList') {
                mutation.addedNodes.forEach((node) => {
                  if (node.nodeType === 1 && (node.tagName === 'SCRIPT' || node.tagName === 'STYLE')) {
                    console.warn('[SECURITY] Injection de script/style détectée');
                    node.remove();
                  }
                });
              }
            });
          });
          
          observer.observe(document, { childList: true, subtree: true });

          return 'Anti-debug activé';
        })();
      `);

      console.log('[SECURITY] ✅ Anti-debug activé');

    } catch (error) {
      console.error('[SECURITY] ❌ Erreur anti-debug:', error);
      this.addViolation('debug_detected', `Anti-debug échoué: ${error}`, 'medium', 'warn');
    }
  }

  /**
   * Contrôle d'affichage - surveillance des écrans
   */
  private async enableDisplayControl(): Promise<void> {
    const config = this.state.securityFeatures.displayControl;
    
    try {
      // Surveiller les changements d'affichage
      screen.on('display-added', () => {
        console.log('[SECURITY] Nouvel écran détecté');
        this.addViolation('unauthorized_display', 'Nouvel écran connecté', 'medium', 'warn');
      });

      screen.on('display-removed', () => {
        console.log('[SECURITY] Écran déconnecté');
        this.addViolation('unauthorized_display', 'Écran déconnecté', 'medium', 'warn');
      });

      // Vérifier affichage autorisé
      if (config.allowedDisplays.length > 0 && this.window) {
        const currentDisplay = screen.getDisplayNearestPoint(this.window.getBounds());
        if (!config.allowedDisplays.includes(currentDisplay.id)) {
          this.addViolation('unauthorized_display', `Affichage non autorisé: ${currentDisplay.id}`, 'high', 'pause');
        }
      }

      console.log('[SECURITY] ✅ Contrôle d\'affichage activé');

    } catch (error) {
      console.error('[SECURITY] ❌ Erreur contrôle affichage:', error);
    }
  }

  /**
   * Surveillance continue de sécurité
   */
  private startSecurityMonitoring(): void {
    this.securityInterval = setInterval(async () => {
      if (!this.window || this.window.isDestroyed()) return;

      try {
        // Vérifier DevTools
        if (this.window.webContents.isDevToolsOpened()) {
          this.addViolation('debug_detected', 'DevTools ouvert détecté', 'high', 'pause');
          this.window.webContents.closeDevTools();
        }

        // Vérifier si toujours en plein écran
        if (this.state.securityFeatures.exclusiveFullscreen && !this.window.isFullScreen()) {
          console.log('[SECURITY] Forçage retour plein écran');
          this.window.setFullScreen(true);
          this.addViolation('external_app', 'Sortie de plein écran détectée', 'medium', 'warn');
        }

        // Vérifier si toujours au premier plan
        if (this.state.securityFeatures.kioskMode && !this.window.isFocused()) {
          this.window.focus();
          this.addViolation('external_app', 'Perte de focus détectée', 'low', 'warn');
        }

        this.state.lastCheck = Date.now();

      } catch (error) {
        console.error('[SECURITY] ❌ Erreur surveillance:', error);
      }
    }, 1000); // Vérification chaque seconde
  }

  /**
   * Ajouter une violation de sécurité
   */
  private addViolation(
    type: SecurityViolation['type'], 
    message: string, 
    severity: SecurityViolation['severity'], 
    action: SecurityViolation['action']
  ): void {
    const violation: SecurityViolation = {
      type,
      message,
      timestamp: Date.now(),
      severity,
      action
    };

    this.state.violations.push(violation);
    
    // Garder seulement les 100 dernières violations
    if (this.state.violations.length > 100) {
      this.state.violations = this.state.violations.slice(-100);
    }

    console.warn(`[SECURITY] Violation ${severity}: ${message}`);

    // Exécuter l'action
    this.executeSecurityAction(violation);
  }

  /**
   * Exécuter action de sécurité
   */
  private executeSecurityAction(violation: SecurityViolation): void {
    if (!this.window) return;

    switch (violation.action) {
      case 'warn':
        // Juste un log, pas d'action disruptive
        break;
        
      case 'pause':
        // Pauser la lecture
        this.window.webContents.send('player:control', { action: 'pause' });
        break;
        
      case 'stop':
        // Arrêter la lecture
        this.window.webContents.send('player:control', { action: 'stop' });
        break;
        
      case 'close':
        // Fermer l'application (cas critique)
        if (violation.severity === 'critical') {
          this.window.close();
        }
        break;
    }
  }

  /**
   * Obtenir l'état de sécurité
   */
  getSecurityState(): PlayerSecurityState {
    return { ...this.state };
  }

  /**
   * Obtenir les violations récentes
   */
  getRecentViolations(since?: number): SecurityViolation[] {
    const cutoff = since || Date.now() - 60000; // Dernière minute
    return this.state.violations.filter(v => v.timestamp > cutoff);
  }
}

// Instance singleton
export const playerSecurity = new PlayerSecurity();

// Export pour tests
export { PlayerSecurity };
