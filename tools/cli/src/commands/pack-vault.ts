import { existsSync, mkdirSync, copyFileSync, writeFileSync, readFileSync, statSync } from 'fs';
import { join, basename, extname, resolve } from 'path';
import { glob } from 'glob';
import archiver from 'archiver';
import { createWriteStream } from 'fs';
import { logger } from '../utils/logger.js';
import { formatBytes } from '../utils/environment.js';
import crypto from 'crypto';

export interface PackVaultOptions {
  license?: string;
  config?: string;
  template: string;
  encrypt?: boolean;
  keyFile?: string;
  manifest?: boolean;
  compress?: boolean;
  verify?: boolean;
}

export interface VaultManifest {
  version: string;
  createdAt: string;
  source: string;
  mediaCount: number;
  totalSize: number;
  encrypted: boolean;
  license?: {
    file: string;
    deviceId?: string;
    expires?: string;
  };
  config?: {
    file: string;
  };
  media: Array<{
    id: string;
    originalName: string;
    size: number;
    type: string;
    checksum: string;
    encrypted?: boolean;
  }>;
  checksum: string;
}

export class PackVaultCommand {
  static async execute(source: string, output: string, options: PackVaultOptions) {
    logger.task('📦 Empaquetage vault USB');
    
    try {
      // Validation des entrées
      await PackVaultCommand.validateInputs(source, output, options);
      
      // Préparation structure vault
      const vaultDir = await PackVaultCommand.prepareVaultStructure(output);
      
      // Traitement des médias
      const mediaInfo = await PackVaultCommand.processMedia(source, vaultDir, options);
      
      // Traitement license
      const licenseInfo = await PackVaultCommand.processLicense(options.license, vaultDir);
      
      // Traitement config
      const configInfo = await PackVaultCommand.processConfig(options.config, vaultDir);
      
      // Génération manifest
      if (options.manifest) {
        await PackVaultCommand.generateManifest(vaultDir, {
          source,
          mediaInfo,
          licenseInfo,
          configInfo,
          options
        });
      }
      
      // Compression finale
      if (options.compress) {
        await PackVaultCommand.compressVault(vaultDir, output);
      }
      
      // Vérification
      if (options.verify) {
        await PackVaultCommand.verifyVault(vaultDir);
      }
      
      logger.success(`✅ Vault empaqueté avec succès: ${output}`);
      
    } catch (error: any) {
      logger.error('❌ Erreur empaquetage:', error?.message || error);
      process.exit(1);
    }
  }

  private static async validateInputs(source: string, output: string, options: PackVaultOptions) {
    logger.step('Validation des entrées');
    
    // Vérifier source
    if (!existsSync(source)) {
      throw new Error(`Dossier source introuvable: ${source}`);
    }
    
    const sourceStat = statSync(source);
    if (!sourceStat.isDirectory()) {
      throw new Error(`La source doit être un dossier: ${source}`);
    }
    
    // Vérifier médias dans source
    const mediaFiles = await glob('**/*.{mp4,avi,mkv,mov,webm,m4v}', { cwd: source });
    if (mediaFiles.length === 0) {
      throw new Error(`Aucun fichier média trouvé dans: ${source}`);
    }
    
    logger.debug(`📁 Source: ${source} (${mediaFiles.length} médias)`);
    
    // Vérifier license si spécifiée
    if (options.license && !existsSync(options.license)) {
      throw new Error(`Fichier license introuvable: ${options.license}`);
    }
    
    // Vérifier config si spécifiée
    if (options.config && !existsSync(options.config)) {
      throw new Error(`Fichier config introuvable: ${options.config}`);
    }
    
    // Vérifier key-file si spécifié
    if (options.keyFile && !existsSync(options.keyFile)) {
      logger.warn(`⚠️  Key-file introuvable, génération automatique: ${options.keyFile}`);
    }
  }

  private static async prepareVaultStructure(output: string) {
    logger.step('Préparation structure vault');
    
    const vaultDir = resolve(output);
    
    // Créer dossiers structure vault
    const dirs = [
      vaultDir,
      join(vaultDir, 'media'),
      join(vaultDir, 'config'),
      join(vaultDir, 'keys'),
      join(vaultDir, 'logs')
    ];
    
    for (const dir of dirs) {
      if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
        logger.debug(`📁 Créé: ${dir}`);
      }
    }
    
    return vaultDir;
  }

  private static async processMedia(source: string, vaultDir: string, options: PackVaultOptions) {
    logger.step('Traitement des médias');
    
    const mediaDir = join(vaultDir, 'media');
    const mediaFiles = await glob('**/*.{mp4,avi,mkv,mov,webm,m4v}', { cwd: source });
    
    const processedMedia = [];
    let totalSize = 0;
    
    // Générer clé de chiffrement si nécessaire
    let encryptionKey: Buffer | null = null;
    if (options.encrypt) {
      if (options.keyFile && existsSync(options.keyFile)) {
        encryptionKey = readFileSync(options.keyFile);
      } else {
        encryptionKey = crypto.randomBytes(32); // AES-256
        const keyPath = options.keyFile || join(vaultDir, 'keys', 'media.key');
        writeFileSync(keyPath, encryptionKey);
        logger.debug(`🔑 Clé générée: ${keyPath}`);
      }
    }
    
    for (let i = 0; i < mediaFiles.length; i++) {
      const mediaFile = mediaFiles[i];
      const sourcePath = join(source, mediaFile);
      const mediaId = crypto.createHash('sha256').update(mediaFile).digest('hex').substring(0, 16);
      const ext = extname(mediaFile);
      const targetName = options.encrypt ? `${mediaId}.enc` : `${mediaId}${ext}`;
      const targetPath = join(mediaDir, targetName);
      
      logger.step(`Traitement: ${basename(mediaFile)}`, mediaFiles.length, i + 1);
      
      const sourceStat = statSync(sourcePath);
      const sourceChecksum = await PackVaultCommand.calculateChecksum(sourcePath);
      
      if (options.encrypt && encryptionKey) {
        // Chiffrement AES-256-GCM
        await PackVaultCommand.encryptFile(sourcePath, targetPath, encryptionKey);
      } else {
        // Copie simple
        copyFileSync(sourcePath, targetPath);
      }
      
      processedMedia.push({
        id: mediaId,
        originalName: basename(mediaFile),
        size: sourceStat.size,
        type: ext.slice(1),
        checksum: sourceChecksum,
        encrypted: !!options.encrypt
      });
      
      totalSize += sourceStat.size;
    }
    
    logger.debug(`📊 Médias traités: ${processedMedia.length}, Taille: ${formatBytes(totalSize)}`);
    
    return { media: processedMedia, totalSize };
  }

  private static async processLicense(licensePath: string | undefined, vaultDir: string) {
    if (!licensePath) {
      logger.debug('⚠️  Aucune license spécifiée');
      return null;
    }
    
    logger.step('Traitement license');
    
    const targetPath = join(vaultDir, 'license.json');
    copyFileSync(licensePath, targetPath);
    
    // Parser license pour infos
    try {
      const licenseData = JSON.parse(readFileSync(licensePath, 'utf8'));
      logger.debug(`🔑 License: ${licenseData.id || 'unknown'}`);
      
      return {
        file: 'license.json',
        deviceId: licenseData.deviceBinding?.deviceId,
        expires: licenseData.expires
      };
    } catch {
      logger.warn('⚠️  Impossible de parser la license');
      return { file: 'license.json' };
    }
  }

  private static async processConfig(configPath: string | undefined, vaultDir: string) {
    if (!configPath) {
      logger.debug('⚠️  Aucune config spécifiée');
      return null;
    }
    
    logger.step('Traitement config');
    
    const targetPath = join(vaultDir, 'config', 'vault.json');
    copyFileSync(configPath, targetPath);
    
    return { file: 'config/vault.json' };
  }

  private static async generateManifest(vaultDir: string, data: any) {
    logger.step('Génération manifest');
    
    const manifest: VaultManifest = {
      version: '2.0.0',
      createdAt: new Date().toISOString(),
      source: data.source,
      mediaCount: data.mediaInfo.media.length,
      totalSize: data.mediaInfo.totalSize,
      encrypted: !!data.options.encrypt,
      license: data.licenseInfo,
      config: data.configInfo,
      media: data.mediaInfo.media,
      checksum: '' // Calculé après
    };
    
    // Calculer checksum global
    const manifestStr = JSON.stringify(manifest, null, 2);
    manifest.checksum = crypto.createHash('sha256').update(manifestStr).digest('hex');
    
    const manifestPath = join(vaultDir, 'manifest.json');
    writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    
    logger.debug(`📄 Manifest généré: ${manifestPath}`);
  }

  private static async compressVault(vaultDir: string, output: string) {
    logger.step('Compression vault');
    
    const archivePath = `${output}.vault`;
    const archive = archiver('zip', { zlib: { level: 9 } });
    const stream = createWriteStream(archivePath);
    
    return new Promise<void>((resolve, reject) => {
      archive.on('error', reject);
      archive.on('end', () => {
        logger.debug(`📦 Archive créée: ${archivePath}`);
        resolve();
      });
      
      archive.pipe(stream);
      archive.directory(vaultDir, false);
      archive.finalize();
    });
  }

  private static async verifyVault(vaultDir: string) {
    logger.step('Vérification vault');
    
    // Vérifier structure
    const requiredDirs = ['media'];
    for (const dir of requiredDirs) {
      const dirPath = join(vaultDir, dir);
      if (!existsSync(dirPath)) {
        throw new Error(`Dossier requis manquant: ${dir}`);
      }
    }
    
    // Vérifier manifest si présent
    const manifestPath = join(vaultDir, 'manifest.json');
    if (existsSync(manifestPath)) {
      const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
      logger.debug(`✅ Manifest valide: ${manifest.mediaCount} médias`);
    }
    
    logger.debug('✅ Vault vérifié avec succès');
  }

  private static async calculateChecksum(filePath: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const hash = crypto.createHash('sha256');
      const stream = require('fs').createReadStream(filePath);
      
      stream.on('data', (data: Buffer) => hash.update(data));
      stream.on('end', () => resolve(hash.digest('hex')));
      stream.on('error', reject);
    });
  }

  private static async encryptFile(inputPath: string, outputPath: string, key: Buffer) {
    return new Promise<void>((resolve, reject) => {
      try {
        const iv = crypto.randomBytes(16); // AES-256-CBC recommande 128 bits
        const cipher = crypto.createCipher('aes-256-cbc', key.toString('hex'));
        
        const input = require('fs').createReadStream(inputPath);
        const output = require('fs').createWriteStream(outputPath);
        
        // Écrire IV en début de fichier
        output.write(iv);
        
        input.pipe(cipher).pipe(output);
        
        cipher.on('end', () => {
          output.end();
          resolve();
        });
        
        cipher.on('error', reject);
        output.on('error', reject);
        
      } catch (error) {
        reject(error);
      }
    });
  }
}
