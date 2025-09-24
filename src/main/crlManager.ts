// CRL (Certificate Revocation List) Manager
// Système de révocation de licences USB Video Vault

import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

interface RevokedLicense {
  licenseId: string;
  kid: string;
  revokedAt: string;
  reason: 'suspected_compromise' | 'unauthorized_use' | 'license_abuse' | 'administrative' | 'superseded';
  serial?: string;
  description?: string;
}

interface CRL {
  version: string;
  issuer: string;
  issuedAt: string;
  nextUpdate: string;
  revokedLicenses: RevokedLicense[];
  signature?: string;
}

interface CRLConfig {
  crlPath: string;
  privateKeyPath?: string;
  publicKeyPath: string;
  updateIntervalHours: number;
  maxAge: number; // heures
}

export class CRLManager {
  private config: CRLConfig;
  private crlCache: CRL | null = null;
  private lastUpdate: number = 0;

  constructor(config: CRLConfig) {
    this.config = {
      ...config,
      updateIntervalHours: config.updateIntervalHours ?? 24,
      maxAge: config.maxAge ?? 72
    };
  }

  // Charger la CRL depuis le fichier local
  async loadCRL(): Promise<CRL | null> {
    try {
      if (!fs.existsSync(this.config.crlPath)) {
        console.log('📋 CRL: Aucun fichier CRL trouvé');
        return null;
      }

      const crlData = fs.readFileSync(this.config.crlPath, 'utf8');
      const crl: CRL = JSON.parse(crlData);

      // Vérifier la signature
      if (!(await this.verifyCRLSignature(crl))) {
        throw new Error('Signature CRL invalide');
      }

      // Vérifier la validité temporelle
      const now = new Date();
      const nextUpdate = new Date(crl.nextUpdate);
      
      if (now > nextUpdate) {
        console.warn(`⚠️ CRL: CRL expirée (prochaine mise à jour attendue: ${nextUpdate.toISOString()})`);
        // Continuer avec la CRL expirée mais avertir
      }

      this.crlCache = crl;
      this.lastUpdate = Date.now();
      
      console.log(`✅ CRL: Chargée avec ${crl.revokedLicenses.length} licence(s) révoquée(s)`);
      return crl;

    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.error('❌ CRL: Erreur chargement:', errorMessage);
      return null;
    }
  }

  // Vérifier si une licence est révoquée
  async isLicenseRevoked(licenseId: string, kid?: string): Promise<{
    revoked: boolean;
    reason?: string;
    revokedAt?: string;
    details?: RevokedLicense;
  }> {
    // Charger CRL si nécessaire
    if (!this.crlCache || this.shouldUpdateCRL()) {
      await this.loadCRL();
    }

    if (!this.crlCache) {
      // Pas de CRL disponible - continuer en mode dégradé
      console.warn('⚠️ CRL: Aucune CRL disponible, vérification ignorée');
      return { revoked: false };
    }

    // Chercher la licence dans la liste des révoquées
    const revokedLicense = this.crlCache.revokedLicenses.find(rl => {
      if (licenseId && rl.licenseId === licenseId) return true;
      if (kid && rl.kid === kid) return true;
      return false;
    });

    if (revokedLicense) {
      console.warn(`🚫 CRL: Licence révoquée détectée (ID: ${licenseId}, KID: ${kid})`);
      return {
        revoked: true,
        reason: revokedLicense.reason,
        revokedAt: revokedLicense.revokedAt,
        details: revokedLicense
      };
    }

    return { revoked: false };
  }

  // Ajouter une licence à la CRL (côté serveur/admin)
  async revokeLicense(
    licenseId: string,
    kid: string,
    reason: RevokedLicense['reason'],
    description?: string,
    serial?: string
  ): Promise<boolean> {
    try {
      // Charger CRL existante ou créer nouvelle
      let crl = this.crlCache || await this.loadCRL() || this.createEmptyCRL();

      // Vérifier si déjà révoquée
      const existing = crl.revokedLicenses.find(rl => 
        rl.licenseId === licenseId || rl.kid === kid
      );

      if (existing) {
        console.warn(`⚠️ CRL: Licence déjà révoquée (ID: ${licenseId}, KID: ${kid})`);
        return false;
      }

      // Ajouter la révocation
      const revokedLicense: RevokedLicense = {
        licenseId,
        kid,
        revokedAt: new Date().toISOString(),
        reason,
        description,
        serial
      };

      crl.revokedLicenses.push(revokedLicense);
      crl.issuedAt = new Date().toISOString();
      crl.nextUpdate = new Date(Date.now() + this.config.updateIntervalHours * 60 * 60 * 1000).toISOString();

      // Signer et sauvegarder
      await this.signAndSaveCRL(crl);

      console.log(`✅ CRL: Licence révoquée (ID: ${licenseId}, KID: ${kid}, Raison: ${reason})`);
      return true;

    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.error('❌ CRL: Erreur révocation licence:', errorMessage);
      return false;
    }
  }

  // Restaurer une licence (annuler révocation)
  async restoreLicense(licenseId: string, kid?: string): Promise<boolean> {
    try {
      let crl = this.crlCache || await this.loadCRL();
      
      if (!crl) {
        console.error('❌ CRL: Aucune CRL disponible pour restauration');
        return false;
      }

      const initialCount = crl.revokedLicenses.length;
      crl.revokedLicenses = crl.revokedLicenses.filter(rl => {
        if (licenseId && rl.licenseId === licenseId) return false;
        if (kid && rl.kid === kid) return false;
        return true;
      });

      if (crl.revokedLicenses.length === initialCount) {
        console.warn(`⚠️ CRL: Licence non trouvée dans CRL (ID: ${licenseId}, KID: ${kid})`);
        return false;
      }

      crl.issuedAt = new Date().toISOString();
      crl.nextUpdate = new Date(Date.now() + this.config.updateIntervalHours * 60 * 60 * 1000).toISOString();

      await this.signAndSaveCRL(crl);

      console.log(`✅ CRL: Licence restaurée (ID: ${licenseId}, KID: ${kid})`);
      return true;

    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.error('❌ CRL: Erreur restauration licence:', errorMessage);
      return false;
    }
  }

  // Vérifier si la CRL doit être mise à jour
  private shouldUpdateCRL(): boolean {
    if (!this.crlCache) return true;
    
    const ageHours = (Date.now() - this.lastUpdate) / (1000 * 60 * 60);
    return ageHours > this.config.updateIntervalHours;
  }

  // Créer une CRL vide
  private createEmptyCRL(): CRL {
    return {
      version: "1.0",
      issuer: "USB Video Vault CRL Authority",
      issuedAt: new Date().toISOString(),
      nextUpdate: new Date(Date.now() + this.config.updateIntervalHours * 60 * 60 * 1000).toISOString(),
      revokedLicenses: []
    };
  }

  // Vérifier la signature de la CRL
  private async verifyCRLSignature(crl: CRL): Promise<boolean> {
    try {
      if (!crl.signature) {
        console.warn('⚠️ CRL: Aucune signature présente');
        return false;
      }

      if (!fs.existsSync(this.config.publicKeyPath)) {
        console.warn('⚠️ CRL: Clé publique non trouvée');
        return false;
      }

      const publicKey = fs.readFileSync(this.config.publicKeyPath, 'utf8');
      
      // Créer les données à vérifier (sans la signature)
      const dataToVerify = { ...crl };
      delete dataToVerify.signature;
      const dataString = JSON.stringify(dataToVerify, null, 0);

      // Vérifier la signature
      const verifier = crypto.createVerify('SHA256');
      verifier.update(dataString);
      
      const isValid = verifier.verify(publicKey, crl.signature, 'base64');
      
      if (!isValid) {
        console.error('❌ CRL: Signature invalide');
      }
      
      return isValid;

    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.error('❌ CRL: Erreur vérification signature:', errorMessage);
      return false;
    }
  }

  // Signer et sauvegarder la CRL
  private async signAndSaveCRL(crl: CRL): Promise<void> {
    try {
      // Signer si clé privée disponible
      if (this.config.privateKeyPath && fs.existsSync(this.config.privateKeyPath)) {
        const privateKey = fs.readFileSync(this.config.privateKeyPath, 'utf8');
        
        // Créer les données à signer
        const dataToSign = { ...crl };
        delete dataToSign.signature;
        const dataString = JSON.stringify(dataToSign, null, 0);

        // Signer
        const signer = crypto.createSign('SHA256');
        signer.update(dataString);
        crl.signature = signer.sign(privateKey, 'base64');
      }

      // Sauvegarder
      const crlData = JSON.stringify(crl, null, 2);
      fs.writeFileSync(this.config.crlPath, crlData, 'utf8');

      // Mettre à jour le cache
      this.crlCache = crl;
      this.lastUpdate = Date.now();

    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.error('❌ CRL: Erreur sauvegarde:', errorMessage);
      throw error;
    }
  }

  // Obtenir les statistiques CRL
  getStats(): {
    loaded: boolean;
    revokedCount: number;
    lastUpdate: string | null;
    nextUpdate: string | null;
    expired: boolean;
  } {
    if (!this.crlCache) {
      return {
        loaded: false,
        revokedCount: 0,
        lastUpdate: null,
        nextUpdate: null,
        expired: false
      };
    }

    const now = new Date();
    const nextUpdate = new Date(this.crlCache.nextUpdate);

    return {
      loaded: true,
      revokedCount: this.crlCache.revokedLicenses.length,
      lastUpdate: this.crlCache.issuedAt,
      nextUpdate: this.crlCache.nextUpdate,
      expired: now > nextUpdate
    };
  }

  // Lister les licences révoquées
  listRevokedLicenses(): RevokedLicense[] {
    return this.crlCache?.revokedLicenses || [];
  }
}

// Instance globale pour l'application
let globalCRLManager: CRLManager | null = null;

export function initializeCRL(config: CRLConfig): CRLManager {
  globalCRLManager = new CRLManager(config);
  return globalCRLManager;
}

export function getCRLManager(): CRLManager | null {
  return globalCRLManager;
}

export default CRLManager;
