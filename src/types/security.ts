/**
 * Types pour le système de sécurité du lecteur détachable
 */

export interface WatermarkConfig {
  text: string;
  position: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right' | 'center';
  opacity: number; // 0.0 à 1.0
  size: number; // Taille en px
  color: string; // Couleur CSS
  rotation: number; // Rotation en degrés
  frequency: number; // Fréquence d'affichage en secondes
}

export interface DisplaySecurity {
  // Protection contre capture d'écran
  preventScreenCapture: boolean;
  // Watermark anti-piratage
  watermark: WatermarkConfig;
  // Mode kiosque (empêche Alt+Tab, etc.)
  kioskMode: boolean;
  // Détection de debugger/outils dev
  antiDebug: boolean;
  // Masquer la barre de tâches Windows
  hideTaskbar: boolean;
  // Forcer plein écran exclusif
  exclusiveFullscreen: boolean;
  // Contrôle d'affichage strict
  displayControl: {
    allowedDisplays: number[]; // IDs des écrans autorisés
    preventMirror: boolean; // Empêcher duplication d'écran
    detectExternalCapture: boolean; // Détecter capture externe
  };
}

export interface PlayerSecurityState {
  isSecured: boolean;
  securityFeatures: DisplaySecurity;
  violations: SecurityViolation[];
  lastCheck: number;
}

export interface SecurityViolation {
  type: 'screen_capture' | 'debug_detected' | 'unauthorized_display' | 'mirror_detected' | 'external_app';
  message: string;
  timestamp: number;
  severity: 'low' | 'medium' | 'high' | 'critical';
  action: 'warn' | 'pause' | 'stop' | 'close';
}

export interface KioskModeConfig {
  blockAltTab: boolean;
  blockWinKey: boolean;
  blockCtrlAltDel: boolean;
  blockTaskManager: boolean;
  hideMouseCursor: boolean;
  preventWindowSwitch: boolean;
}
