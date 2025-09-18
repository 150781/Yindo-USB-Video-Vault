/**
 * Types pour le système de licence Ed25519 sécurisé
 */

export interface LicenseData {
  licenseId: string;                // Identifiant unique de la licence
  exp: string;                      // Date d'expiration ISO 8601
  usbSerial: string;                // Numéro de série de la clé USB
  machineFingerprint: string;       // Empreinte de la machine
  features: string[];               // Fonctionnalités autorisées
  maxPlaybackPerDay?: number;       // Limite de lectures par jour
  issuer: string;                   // Émetteur de la licence
  issuedAt: string;                 // Date d'émission ISO 8601
  version: number;                  // Version du format de licence
}

export interface LicenseFile {
  data: LicenseData;
  signature: string;                // Signature Ed25519 en base64
}

export interface LicenseValidationResult {
  isValid: boolean;
  reason?: string;
  data?: LicenseData;
}

export interface DeviceFingerprint {
  machineId: string;                // ID machine principal
  platform: string;                // OS: 'win32' | 'darwin' | 'linux'
  arch: string;                     // Architecture CPU
  usbSerial?: string;               // Série USB si détectée
  networkMac?: string;              // Adresse MAC principale
  hostname?: string;                // Nom de l'hôte
}

export interface USBDeviceInfo {
  serial: string;                   // Numéro de série
  vendorId?: string;                // ID vendeur
  productId?: string;               // ID produit
  label?: string;                   // Label du volume
  mountPath?: string;               // Point de montage
}

export interface TimeValidation {
  maxSeenTime: number;              // Timestamp max observé
  currentTime: number;              // Timestamp actuel
  isValid: boolean;                 // Temps cohérent
  tolerance: number;                // Tolérance en ms (défaut: 10 min)
}

// Constantes pour la validation
export const LICENSE_VERSION = 1;
export const MAX_CLOCK_DRIFT_MS = 10 * 60 * 1000; // 10 minutes
export const DEFAULT_FEATURES = ['play', 'queue', 'display'];
export const PREMIUM_FEATURES = ['fullscreen', 'secondary_display', 'batch_export'];

// Types d'erreurs de licence
export enum LicenseError {
  SIGNATURE_INVALID = 'signature_invalid',
  EXPIRED = 'expired',
  NOT_YET_VALID = 'not_yet_valid',
  USB_MISMATCH = 'usb_mismatch',
  MACHINE_MISMATCH = 'machine_mismatch',
  CLOCK_TAMPERED = 'clock_tampered',
  FEATURE_NOT_ALLOWED = 'feature_not_allowed',
  QUOTA_EXCEEDED = 'quota_exceeded',
  FILE_NOT_FOUND = 'file_not_found',
  PARSE_ERROR = 'parse_error'
}
