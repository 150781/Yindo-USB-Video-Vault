/**
 * Système de licence Ed25519 sécurisé avec binding USB/machine
 * Remplace l'ancien système license.ts
 */

import { promises as fs } from 'fs';
import path from 'path';
import crypto from 'crypto';
import nacl from 'tweetnacl';
import { app } from 'electron';
import zlib from 'zlib';
import { promisify } from 'util';

const gunzip = promisify(zlib.gunzip);
import { 
  LicenseData, 
  LicenseFile, 
  LicenseValidationResult, 
  TimeValidation,
  LicenseError,
  LICENSE_VERSION,
  MAX_CLOCK_DRIFT_MS
} from '../types/license.js';
import { 
  generateStableDeviceId, 
  validateDeviceBinding, 
  getMachineFingerprint, 
  detectUSBSerial 
} from '../shared/device.js';
import { LicenseExpirationManager } from './licenseExpirationAlert.js';
import { getCRLManager } from './crlManager.js';

// Clés publiques Ed25519 du packager - FIGÉES DANS LE BINAIRE (sécurité production)
// Ces clés sont les SEULES autorisées pour valider les licences
// Modification nécessite recompilation et redistribution de l'application
const PUB_KEYS: Readonly<Record<number, string>> = Object.freeze({
  1: '879c35f5ae011c56528c27abb0f5b61539bf0d134158ec56ac4e8b8dd08c9d78', // clé production v1 (active)
  // 2: 'future_public_key_hex_here...', // prête pour rotation future
  // 3: 'emergency_key_hex_here...', // clé d'urgence (si compromise)
} as const);

// État global
let currentLicense: LicenseData | null = null;
let licenseValidated = false;
let persistentData: { maxSeenTime: number } = { maxSeenTime: 0 };

/**
 * Vérifie l'intégrité de la table des clés publiques
 * Protection contre les modifications runtime de PUB_KEYS
 */
function validateKeyTableIntegrity(): boolean {
  try {
    // Vérifier que PUB_KEYS est bien figé
    if (!Object.isFrozen(PUB_KEYS)) {
      console.error('[LICENSE-SECURITY] ⚠️ Table des clés publiques non figée !');
      return false;
    }
    
    // Vérifier que la clé active (kid=1) est présente
    if (!PUB_KEYS[1] || PUB_KEYS[1].length !== 64) {
      console.error('[LICENSE-SECURITY] ⚠️ Clé publique principale manquante ou invalide !');
      return false;
    }
    
    // Vérifier format hexadécimal des clés
    for (const [kid, pubKey] of Object.entries(PUB_KEYS)) {
      if (!/^[0-9a-f]{64}$/i.test(pubKey)) {
        console.error(`[LICENSE-SECURITY] ⚠️ Clé publique kid=${kid} format invalide !`);
        return false;
      }
    }
    
    return true;
  } catch (error) {
    console.error('[LICENSE-SECURITY] ⚠️ Erreur validation intégrité clés:', error);
    return false;
  }
}

/**
 * Charge et valide la licence au démarrage
 */
export async function loadAndValidateLicense(vaultPath: string): Promise<LicenseValidationResult> {
  console.log('[LICENSE] Chargement et validation...');
  
  // SÉCURITÉ: Vérifier l'intégrité de la table des clés avant toute validation
  if (!validateKeyTableIntegrity()) {
    return {
      isValid: false,
      reason: 'Intégrité du système de licence compromise. Veuillez réinstaller l\'application.'
    };
  }
  
  try {
    // Charger les données persistantes (maxSeenTime) depuis userData
    await loadPersistentData();
    
    // Vérifier l'horloge avant tout
    const timeCheck = validateSystemTime();
    if (!timeCheck.isValid) {
      const minutesBack = Math.round((timeCheck.maxSeenTime - timeCheck.currentTime) / 1000 / 60);
      return {
        isValid: false,
        reason: `L'horloge système a été modifiée (${minutesBack} minutes en arrière). Ceci pourrait indiquer une tentative de contournement de sécurité.`
      };
    }
    
    // Charger le fichier de licence
    const licenseFile = await loadLicenseFile(vaultPath);
    if (!licenseFile) {
      return { 
        isValid: false, 
        reason: 'Aucun fichier de licence valide trouvé. Veuillez contacter le support pour obtenir une licence.' 
      };
    }
    
    // Vérifier la signature Ed25519
    const signatureValid = await verifyLicenseSignature(licenseFile);
    if (!signatureValid) {
      return { 
        isValid: false, 
        reason: 'La licence n\'est pas authentique. Elle a peut-être été modifiée ou corrompue.' 
      };
    }
    
    // Vérifier la révocation CRL
    const crlManager = getCRLManager();
    if (crlManager) {
      const crlCheck = await crlManager.isLicenseRevoked(licenseFile.data.licenseId, licenseFile.data.kid);
      if (crlCheck.revoked) {
        return { 
          isValid: false, 
          reason: `Cette licence a été révoquée (raison: ${crlCheck.reason}). Contactez le support.` 
        };
      }
    }
    
    // Vérifier l'expiration
    const now = new Date();
    const expiry = new Date(licenseFile.data.exp);
    if (now > expiry) {
      return { 
        isValid: false, 
        reason: `Votre licence a expiré le ${expiry.toLocaleDateString()}. Veuillez contacter le support pour la renouveler.` 
      };
    }
    
    // Vérifier le binding USB
    const usbSerial = await detectUSBSerial();
    if (usbSerial && licenseFile.data.usbSerial !== usbSerial) {
      return { 
        isValid: false, 
        reason: 'Cette licence n\'est pas valide pour cette clé USB. Utilisez la clé USB d\'origine.' 
      };
    }
    
    // Vérifier le binding machine
    const deviceValid = await validateDeviceBinding(licenseFile.data.machineFingerprint);
    if (!deviceValid) {
      return { 
        isValid: false, 
        reason: 'Cette licence n\'est pas valide pour cet ordinateur. Contactez le support si vous avez changé de machine.' 
      };
    }
    
    // Tout est bon !
    currentLicense = licenseFile.data;
    licenseValidated = true;
    
    // Mettre à jour maxSeenTime dans userData
    persistentData.maxSeenTime = Math.max(persistentData.maxSeenTime, Date.now());
    await savePersistentData();
    
    // Vérifier alerte renouvellement avec nouveau système
    const expirationManager = LicenseExpirationManager.getInstance();
    await expirationManager.checkAndShowExpirationAlert(licenseFile.data);
    
    console.log('[LICENSE] ✅ Licence validée avec succès');
    console.log('[LICENSE] ID:', licenseFile.data.licenseId);
    console.log('[LICENSE] Expire:', expiry.toLocaleDateString());
    console.log('[LICENSE] Features:', licenseFile.data.features.join(', '));
    
    return { 
      isValid: true, 
      data: licenseFile.data 
    };
    
  } catch (error) {
    console.error('[LICENSE] Erreur validation:', error);
    return { 
      isValid: false, 
      reason: 'Erreur lors de la vérification de la licence. Veuillez redémarrer l\'application ou contacter le support.' 
    };
  }
}

/**
 * Charge le fichier de licence depuis le vault
 */
async function loadLicenseFile(vaultPath: string): Promise<LicenseFile | null> {
  const IS_DEV = process.env.NODE_ENV !== 'production';
  
  const candidates = [
    path.join(vaultPath, '.vault', 'license.bin'),     // format "prod"
    path.join(vaultPath, 'license.json'),              // fallback "prod"
    ...(IS_DEV ? [path.join(vaultPath, 'license-test-expired.json')] : []), // legacy/dev seulement
  ];
  
  for (const licensePath of candidates) {
    try {
      console.log(`[LICENSE] Tentative: ${licensePath}`);
      
      if (licensePath.endsWith('.bin')) {
        // Lecture license.bin avec décompression gzip+base64
        const base64Content = await fs.readFile(licensePath, 'utf8');
        
        // Décodage base64 puis décompression gzip
        const gzipBuffer = Buffer.from(base64Content, 'base64');
        const jsonBuffer = await gunzip(gzipBuffer);
        const content = jsonBuffer.toString('utf8');
        
        const licenseFile: LicenseFile = JSON.parse(content);
        
        // Validation de base de la structure
        if (!licenseFile.data || !licenseFile.signature) {
          throw new Error('Structure de licence invalide');
        }
        
        if (licenseFile.data.version !== LICENSE_VERSION) {
          throw new Error(`Version de licence non supportée: ${licenseFile.data.version}`);
        }
        
        console.log('[LICENSE] license.bin trouvé et décompressé');
        return licenseFile;
        
      } else {
        // Fichiers JSON
        const content = await fs.readFile(licensePath, 'utf8');
        const licenseFile: LicenseFile = JSON.parse(content);
        
        // Validation de base de la structure
        if (!licenseFile.data || !licenseFile.signature) {
          throw new Error('Structure de licence invalide');
        }
        
        if (licenseFile.data.version !== LICENSE_VERSION) {
          throw new Error(`Version de licence non supportée: ${licenseFile.data.version}`);
        }
        
        console.log(`[LICENSE] ${path.basename(licensePath)} trouvé et validé`);
        return licenseFile;
      }
      
    } catch (error) {
      console.log(`[LICENSE] Erreur ${path.basename(licensePath)}:`, error instanceof Error ? error.message : error);
      continue;
    }
  }
  
  console.log('[LICENSE] Aucun fichier de licence valide trouvé');
  return null;
}

/**
 * Vérifie la signature Ed25519 de la licence
 */
async function verifyLicenseSignature(licenseFile: LicenseFile): Promise<boolean> {
  try {
    // SÉCURITÉ: Double vérification de l'intégrité des clés
    if (!validateKeyTableIntegrity()) {
      console.error('[LICENSE-SECURITY] ⚠️ Table des clés compromise pendant la validation !');
      return false;
    }
    
    // Vérifier si kid est défini et clé publique disponible
    const kidString = licenseFile.data.kid || 'kid-1'; // default à kid-1
    const kidNumber = kidString.startsWith('kid-') ? parseInt(kidString.substring(4)) : 1;
    const publicKeyHex = PUB_KEYS[kidNumber];
    
    if (!publicKeyHex) {
      console.error(`[LICENSE] Clé publique inconnue pour kid=${kidNumber}`);
      return false;
    }
    
    const publicKey = Buffer.from(publicKeyHex, 'hex');
    
    // Reconstituer les données exactes qui ont été signées
    const dataToVerify = JSON.stringify(licenseFile.data, null, 2);
    const dataBytes = Buffer.from(dataToVerify, 'utf8');
    
    // Décoder la signature base64
    const signature = Buffer.from(licenseFile.signature, 'base64');
    if (signature.length !== 64) {
      console.error('[LICENSE] Signature invalide: longueur', signature.length);
      return false;
    }
    
    // Vérification Ed25519 avec tweetnacl
    const isValid = nacl.sign.detached.verify(
      new Uint8Array(dataBytes),
      new Uint8Array(signature),
      new Uint8Array(publicKey)
    );
    
    console.log(`[LICENSE] Vérification signature (kid=${kidNumber}):`, isValid ? '✅' : '❌');
    return isValid;
    
  } catch (error) {
    console.error('[LICENSE] Erreur vérification signature:', error);
    return false;
  }
}

/**
 * Vérifie et alerte si la licence expire dans 30 jours ou moins
 */
function checkLicenseExpiryAlert(licenseData: LicenseData): void {
  const now = Date.now();
  const expiry = new Date(licenseData.exp).getTime();
  const daysUntilExpiry = Math.floor((expiry - now) / (24 * 60 * 60 * 1000));
  
  if (daysUntilExpiry <= 30 && daysUntilExpiry > 0) {
    console.warn(`[LICENSE] ⚠️ ALERTE: Licence expire dans ${daysUntilExpiry} jours (${new Date(expiry).toLocaleDateString()})`);
    console.warn('[LICENSE] ⚠️ Contacter l\'administrateur pour renouvellement');
  } else if (daysUntilExpiry <= 0) {
    console.error(`[LICENSE] ❌ CRITIQUE: Licence expirée depuis ${Math.abs(daysUntilExpiry)} jours`);
  } else {
    console.log(`[LICENSE] ✅ Licence valide pour ${daysUntilExpiry} jours`);
  }
}

/**
 * Valide que l'horloge système n'a pas reculé
 */
function validateSystemTime(): TimeValidation {
  const currentTime = Date.now();
  const maxSeenTime = persistentData.maxSeenTime;
  const tolerance = MAX_CLOCK_DRIFT_MS;
  
  const isValid = (currentTime >= maxSeenTime - tolerance);
  
  return {
    maxSeenTime,
    currentTime,
    isValid,
    tolerance
  };
}

/**
 * Charge les données persistantes (maxSeenTime, etc.) depuis userData
 */
async function loadPersistentData(): Promise<void> {
  const dataPath = path.join(app.getPath('userData'), '.license_state.json');
  
  try {
    const content = await fs.readFile(dataPath, 'utf8');
    const data = JSON.parse(content);
    persistentData = { maxSeenTime: data.maxSeenTime || 0 };
    console.log('[LICENSE] Données persistantes chargées, maxSeenTime:', new Date(persistentData.maxSeenTime).toISOString());
  } catch {
    // Première exécution, initialiser
    persistentData = { maxSeenTime: Date.now() };
    console.log('[LICENSE] Données persistantes initialisées');
  }
}

/**
 * Sauvegarde les données persistantes dans userData
 */
async function savePersistentData(): Promise<void> {
  const dataPath = path.join(app.getPath('userData'), '.license_state.json');
  
  try {
    await fs.writeFile(dataPath, JSON.stringify(persistentData, null, 2));
  } catch (error) {
    console.error('[LICENSE] Erreur sauvegarde données persistantes:', error);
  }
}

/**
 * Vérifie qu'une fonctionnalité est autorisée par la licence
 */
export function isFeatureAllowed(feature: string): boolean {
  if (!licenseValidated || !currentLicense) {
    return false;
  }
  
  return currentLicense.features.includes(feature);
}

/**
 * Obtient les informations de la licence actuelle
 */
export function getCurrentLicense(): LicenseData | null {
  return licenseValidated ? currentLicense : null;
}

/**
 * Vérifie si la licence est chargée et valide
 */
export function isLicenseLoaded(): boolean {
  return licenseValidated && currentLicense !== null;
}

/**
 * Bloque l'accès en cas de licence invalide
 */
export function requireValidLicense(): void {
  if (!isLicenseLoaded()) {
    throw new Error('Licence requise mais non valide');
  }
}

/**
 * ⚠️ SÉCURITÉ: Informations système pour audit (lecture seule)
 * Ces données NE DOIVENT JAMAIS permettre de modifier les clés publiques
 */
export function getSecurityInfo(): Readonly<{
  keysCount: number;
  activeKids: readonly number[];
  tableIntegrityOK: boolean;
  tableFrozen: boolean;
}> {
  return Object.freeze({
    keysCount: Object.keys(PUB_KEYS).length,
    activeKids: Object.keys(PUB_KEYS).map(Number).sort() as readonly number[],
    tableIntegrityOK: validateKeyTableIntegrity(),
    tableFrozen: Object.isFrozen(PUB_KEYS)
  });
}

/**
 * Génère une empreinte pour une nouvelle licence (usage packager)
 */
export async function generateLicenseFingerprint(): Promise<string> {
  return await generateStableDeviceId();
}

/**
 * Génère un ID de licence unique
 */
export function generateLicenseId(): string {
  return `lic_${crypto.randomBytes(16).toString('hex')}`;
}

/**
 * Verrouille la licence (logout)
 */
export function lockLicense(): void {
  currentLicense = null;
  licenseValidated = false;
  console.log('[LICENSE] Licence verrouillée');
}

// TODO: Implémentation des quotas de lecture
export function trackPlayback(mediaId: string): void {
  // Sera implémenté dans la tâche 4 (stats)
  console.log('[LICENSE] Lecture trackée:', mediaId);
}

// Export pour compatibility avec ancien système
export function unwrapCEK(mediaId: string): Buffer | null {
  if (!isLicenseLoaded()) {
    console.error('[LICENSE] Tentative unwrapCEK sans licence valide');
    return null;
  }
  
  // Pour l'instant, retourner une clé dérivée simple
  // TODO: Implémenter le vrai système de clés par média
  const key = crypto.scryptSync('vault-key', mediaId, 32);
  return key;
}

// ⚠️ SÉCURITÉ: Protection finale - Figer le module entier contre modifications
Object.freeze(module);
Object.freeze(exports);
