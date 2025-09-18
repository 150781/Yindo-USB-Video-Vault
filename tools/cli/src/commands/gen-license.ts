import { writeFileSync, existsSync, readFileSync, mkdirSync } from 'fs';
import { join, resolve } from 'path';
import crypto from 'crypto';
import { logger } from '../utils/logger.js';

// Import tweetnacl pour Ed25519 (remplacer par votre implémentation)
// const nacl = require('tweetnacl');

export interface GenLicenseOptions {
  output: string;
  count: string;
  device?: string;
  expires?: string;
  features: string;
  template?: string;
  batch?: string;
  testMode?: boolean;
}

export interface LicenseTemplate {
  version: string;
  features: string[];
  expiresInDays?: number;
  deviceBinding?: {
    required: boolean;
    deviceId?: string;
  };
  metadata?: {
    issuer?: string;
    purpose?: string;
  };
}

export interface LicenseData {
  id: string;
  version: string;
  createdAt: string;
  expires: string;
  features: string[];
  deviceBinding?: {
    required: boolean;
    deviceId?: string;
    hardwareHash?: string;
  };
  signature: string;
  publicKey: string;
  metadata?: any;
}

export class GenLicenseCommand {
  static async execute(options: GenLicenseOptions) {
    logger.task('🔑 Génération de licenses Ed25519');
    
    try {
      // Validation options
      await GenLicenseCommand.validateOptions(options);
      
      // Préparation dossier sortie
      const outputDir = await GenLicenseCommand.prepareOutputDir(options.output);
      
      // Chargement template si spécifié
      const template = await GenLicenseCommand.loadTemplate(options.template);
      
      // Génération licenses
      if (options.batch) {
        await GenLicenseCommand.generateBatchLicenses(options, template, outputDir);
      } else {
        await GenLicenseCommand.generateSingleLicenses(options, template, outputDir);
      }
      
      logger.success(`✅ Licenses générées dans: ${outputDir}`);
      
    } catch (error: any) {
      logger.error('❌ Erreur génération licenses:', error?.message || error);
      process.exit(1);
    }
  }

  private static async validateOptions(options: GenLicenseOptions) {
    logger.step('Validation des options');
    
    const count = parseInt(options.count);
    if (isNaN(count) || count < 1) {
      throw new Error(`Nombre de licenses invalide: ${options.count}`);
    }
    
    if (count > 1000) {
      throw new Error('Maximum 1000 licenses par batch pour éviter les problèmes de performance');
    }
    
    // Validation date expiration
    if (options.expires) {
      const expiryDate = new Date(options.expires);
      if (isNaN(expiryDate.getTime())) {
        throw new Error(`Date d'expiration invalide: ${options.expires}`);
      }
      
      if (expiryDate <= new Date()) {
        throw new Error('La date d\'expiration doit être dans le futur');
      }
    }
    
    // Validation features
    const features = options.features.split(',').map(f => f.trim());
    const validFeatures = ['play', 'queue', 'display', 'fullscreen', 'secondary_display', 'export', 'admin'];
    
    for (const feature of features) {
      if (!validFeatures.includes(feature)) {
        throw new Error(`Feature invalide: ${feature}. Valides: ${validFeatures.join(', ')}`);
      }
    }
    
    // Validation fichier batch
    if (options.batch && !existsSync(options.batch)) {
      throw new Error(`Fichier batch introuvable: ${options.batch}`);
    }
    
    logger.debug(`📊 Génération: ${count} licenses, Features: ${features.join(', ')}`);
  }

  private static async prepareOutputDir(output: string) {
    logger.step('Préparation dossier sortie');
    
    const outputDir = resolve(output);
    
    if (!existsSync(outputDir)) {
      mkdirSync(outputDir, { recursive: true });
      logger.debug(`📁 Créé: ${outputDir}`);
    }
    
    return outputDir;
  }

  private static async loadTemplate(templatePath?: string): Promise<LicenseTemplate | null> {
    if (!templatePath) {
      logger.debug('⚠️  Aucun template spécifié, utilisation par défaut');
      return null;
    }
    
    logger.step('Chargement template');
    
    if (!existsSync(templatePath)) {
      throw new Error(`Template introuvable: ${templatePath}`);
    }
    
    try {
      const template = JSON.parse(readFileSync(templatePath, 'utf8'));
      logger.debug(`📄 Template chargé: ${templatePath}`);
      return template;
    } catch (error) {
      throw new Error(`Template invalide: ${templatePath}`);
    }
  }

  private static async generateSingleLicenses(
    options: GenLicenseOptions, 
    template: LicenseTemplate | null, 
    outputDir: string
  ) {
    const count = parseInt(options.count);
    const features = options.features.split(',').map(f => f.trim());
    
    logger.step(`Génération de ${count} license(s)`);
    
    for (let i = 0; i < count; i++) {
      const deviceId = options.device || (count > 1 ? `device-${i + 1}` : undefined);
      
      const license = await GenLicenseCommand.createLicense({
        features,
        deviceId,
        expires: options.expires,
        testMode: options.testMode,
        template
      });
      
      const filename = count > 1 ? `license-${i + 1}.json` : 'license.json';
      const filepath = join(outputDir, filename);
      
      writeFileSync(filepath, JSON.stringify(license, null, 2));
      
      logger.step(`Générée: ${filename} (ID: ${license.id})`, count, i + 1);
    }
  }

  private static async generateBatchLicenses(
    options: GenLicenseOptions,
    template: LicenseTemplate | null,
    outputDir: string
  ) {
    logger.step('Génération batch depuis CSV');
    
    const csvData = readFileSync(options.batch!, 'utf8');
    const lines = csvData.split('\n').filter(line => line.trim());
    const headers = lines[0].split(',').map(h => h.trim());
    
    if (!headers.includes('deviceId')) {
      throw new Error('Le fichier CSV doit contenir une colonne "deviceId"');
    }
    
    for (let i = 1; i < lines.length; i++) {
      const values = lines[i].split(',').map(v => v.trim());
      const rowData: any = {};
      
      headers.forEach((header, index) => {
        rowData[header] = values[index];
      });
      
      const license = await GenLicenseCommand.createLicense({
        features: rowData.features?.split(';') || options.features.split(','),
        deviceId: rowData.deviceId,
        expires: rowData.expires || options.expires,
        testMode: options.testMode,
        template,
        metadata: {
          batchRow: i,
          customData: rowData
        }
      });
      
      const filename = `license-${rowData.deviceId || i}.json`;
      const filepath = join(outputDir, filename);
      
      writeFileSync(filepath, JSON.stringify(license, null, 2));
      
      logger.step(`Batch: ${filename}`, lines.length - 1, i);
    }
  }

  private static async createLicense(params: {
    features: string[];
    deviceId?: string;
    expires?: string;
    testMode?: boolean;
    template?: LicenseTemplate | null;
    metadata?: any;
  }): Promise<LicenseData> {
    
    // Génération clés Ed25519 (simulation - remplacer par vraie implémentation)
    const keyPair = GenLicenseCommand.generateEd25519KeyPair();
    
    // ID unique de license
    const licenseId = `lic_${crypto.randomBytes(12).toString('hex')}`;
    
    // Date d'expiration
    let expiryDate: Date;
    if (params.expires) {
      expiryDate = new Date(params.expires);
    } else if (params.testMode) {
      expiryDate = new Date();
      expiryDate.setHours(expiryDate.getHours() + 24); // 24h pour test
    } else if (params.template?.expiresInDays) {
      expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + params.template.expiresInDays);
    } else {
      expiryDate = new Date();
      expiryDate.setFullYear(expiryDate.getFullYear() + 1); // 1 an par défaut
    }
    
    // Device binding
    let deviceBinding: any = undefined;
    if (params.deviceId || params.template?.deviceBinding?.required) {
      deviceBinding = {
        required: true,
        deviceId: params.deviceId,
        hardwareHash: params.deviceId ? GenLicenseCommand.generateHardwareHash(params.deviceId) : undefined
      };
    }
    
    // Données license
    const licenseData: Omit<LicenseData, 'signature'> = {
      id: licenseId,
      version: '2.0.0',
      createdAt: new Date().toISOString(),
      expires: expiryDate.toISOString(),
      features: params.features,
      deviceBinding,
      publicKey: keyPair.publicKey,
      metadata: {
        issuer: 'USB-Video-Vault CLI',
        purpose: params.testMode ? 'testing' : 'production',
        ...params.template?.metadata,
        ...params.metadata
      }
    };
    
    // Signature
    const dataToSign = JSON.stringify(licenseData);
    const signature = GenLicenseCommand.signData(dataToSign, keyPair.privateKey);
    
    return {
      ...licenseData,
      signature
    };
  }

  // Simulation Ed25519 - remplacer par vraie implémentation
  private static generateEd25519KeyPair() {
    // const keyPair = nacl.sign.keyPair();
    // return {
    //   publicKey: Buffer.from(keyPair.publicKey).toString('hex'),
    //   privateKey: Buffer.from(keyPair.secretKey).toString('hex')
    // };
    
    // Simulation pour développement
    const publicKey = crypto.randomBytes(32).toString('hex');
    const privateKey = crypto.randomBytes(64).toString('hex');
    
    return { publicKey, privateKey };
  }
  
  private static signData(data: string, privateKey: string): string {
    // const signature = nacl.sign.detached(Buffer.from(data), Buffer.from(privateKey, 'hex'));
    // return Buffer.from(signature).toString('hex');
    
    // Simulation pour développement
    return crypto.createHash('sha256').update(data + privateKey).digest('hex');
  }
  
  private static generateHardwareHash(deviceId: string): string {
    return crypto.createHash('sha256').update(`hardware-${deviceId}`).digest('hex').substring(0, 16);
  }
}
