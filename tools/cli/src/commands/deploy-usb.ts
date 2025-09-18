import { existsSync, statSync, copyFileSync, mkdirSync, readdirSync, writeFileSync } from 'fs';
import { join, resolve, basename } from 'path';
import { execSync } from 'child_process';
import { logger } from '../utils/logger.js';
import { getUsbDrives, formatBytes } from '../utils/environment.js';

export interface DeployUsbOptions {
  targets: string;
  force?: boolean;
  verify?: boolean;
  parallel: string;
  logFile?: string;
  dryRun?: boolean;
  eject?: boolean;
}

export interface DeploymentTarget {
  drive: string;
  label?: string;
  totalSize: number;
  freeSize: number;
  valid: boolean;
  error?: string;
}

export interface DeploymentResult {
  target: DeploymentTarget;
  success: boolean;
  duration: number;
  error?: string;
  filesCount?: number;
  totalSize?: number;
}

export class DeployUsbCommand {
  static async execute(vaultPackage: string, options: DeployUsbOptions) {
    logger.task('🚀 Déploiement USB en masse');
    
    try {
      // Validation package vault
      await DeployUsbCommand.validateVaultPackage(vaultPackage);
      
      // Détection cibles USB
      const targets = await DeployUsbCommand.detectTargets(options.targets);
      
      if (targets.length === 0) {
        throw new Error('Aucune cible USB valide détectée');
      }
      
      logger.info(`🎯 Cibles détectées: ${targets.length}`);
      targets.forEach(target => {
        logger.step(`${target.drive} - ${formatBytes(target.freeSize)} libre`);
      });
      
      // Confirmation en mode production
      if (!options.dryRun && !options.force) {
        const proceed = await DeployUsbCommand.confirmDeployment(targets);
        if (!proceed) {
          logger.info('⏹️  Déploiement annulé');
          return;
        }
      }
      
      // Déploiement parallèle
      const results = await DeployUsbCommand.deployParallel(vaultPackage, targets, options);
      
      // Rapport final
      await DeployUsbCommand.generateReport(results, options);
      
      const successful = results.filter(r => r.success).length;
      logger.success(`✅ Déploiement terminé: ${successful}/${results.length} réussis`);
      
    } catch (error: any) {
      logger.error('❌ Erreur déploiement:', error?.message || error);
      process.exit(1);
    }
  }

  private static async validateVaultPackage(vaultPackage: string) {
    logger.step('Validation package vault');
    
    if (!existsSync(vaultPackage)) {
      throw new Error(`Package vault introuvable: ${vaultPackage}`);
    }
    
    const stat = statSync(vaultPackage);
    
    if (stat.isDirectory()) {
      // Vault directory
      const mediaDir = join(vaultPackage, 'media');
      if (!existsSync(mediaDir)) {
        throw new Error('Dossier media manquant dans le vault');
      }
      
      const mediaFiles = readdirSync(mediaDir);
      if (mediaFiles.length === 0) {
        throw new Error('Aucun fichier média dans le vault');
      }
      
      logger.debug(`📁 Vault directory: ${mediaFiles.length} médias`);
      
    } else {
      // Archive vault (.vault)
      if (!vaultPackage.endsWith('.vault')) {
        throw new Error('Le package doit être un dossier vault ou archive .vault');
      }
      
      logger.debug(`📦 Archive vault: ${formatBytes(stat.size)}`);
    }
  }

  private static async detectTargets(pattern: string): Promise<DeploymentTarget[]> {
    logger.step('Détection cibles USB');
    
    const usbDrives = getUsbDrives();
    const targets: DeploymentTarget[] = [];
    
    for (const drive of usbDrives) {
      try {
        // Vérifier si le drive match le pattern
        if (!DeployUsbCommand.matchesPattern(drive, pattern)) {
          continue;
        }
        
        // Obtenir infos drive
        const driveInfo = await DeployUsbCommand.getDriveInfo(drive);
        targets.push(driveInfo);
        
      } catch (error: any) {
        logger.debug(`⚠️  Erreur drive ${drive}: ${error?.message}`);
        targets.push({
          drive,
          totalSize: 0,
          freeSize: 0,
          valid: false,
          error: error?.message || 'Erreur inconnue'
        });
      }
    }
    
    return targets;
  }

  private static matchesPattern(drive: string, pattern: string): boolean {
    // Pattern simple: [D-Z]:\\ pour Windows
    if (process.platform === 'win32') {
      const winPattern = /^\[([A-Z])-([A-Z])\]:\\\\$/;
      const match = pattern.match(winPattern);
      
      if (match) {
        const startChar = match[1].charCodeAt(0);
        const endChar = match[2].charCodeAt(0);
        const driveChar = drive.charAt(0).charCodeAt(0);
        
        return driveChar >= startChar && driveChar <= endChar;
      }
    }
    
    // Pattern exact ou regex simple
    return drive.includes(pattern) || !!drive.match(new RegExp(pattern));
  }

  private static async getDriveInfo(drive: string): Promise<DeploymentTarget> {
    try {
      if (process.platform === 'win32') {
        // Windows: utiliser wmic
        const output = execSync(
          `wmic logicaldisk where caption="${drive.replace('\\\\', '')}" get size,freespace,volumename`,
          { encoding: 'utf8' }
        );
        
        const lines = output.split('\n').filter(line => line.trim() && !line.includes('FreeSpace'));
        if (lines.length === 0) {
          throw new Error('Drive non accessible');
        }
        
        const values = lines[0].trim().split(/\s+/);
        const freeSize = parseInt(values[0] || '0');
        const totalSize = parseInt(values[1] || '0');
        const label = values[2] || '';
        
        return {
          drive,
          label,
          totalSize,
          freeSize,
          valid: freeSize > 100 * 1024 * 1024 // Minimum 100MB
        };
        
      } else {
        // Unix: utiliser df
        const output = execSync(`df -B1 "${drive}"`, { encoding: 'utf8' });
        const lines = output.split('\n');
        const data = lines[1].split(/\s+/);
        
        const totalSize = parseInt(data[1]);
        const freeSize = parseInt(data[3]);
        
        return {
          drive,
          totalSize,
          freeSize,
          valid: freeSize > 100 * 1024 * 1024
        };
      }
      
    } catch (error: any) {
      throw new Error(`Impossible d'obtenir les infos: ${error?.message}`);
    }
  }

  private static async confirmDeployment(targets: DeploymentTarget[]): Promise<boolean> {
    // Simulation confirmation - en production, utiliser inquirer
    logger.warn('⚠️  Mode interactif non implémenté, utiliser --force pour forcer');
    return false;
  }

  private static async deployParallel(
    vaultPackage: string,
    targets: DeploymentTarget[],
    options: DeployUsbOptions
  ): Promise<DeploymentResult[]> {
    
    const parallelCount = Math.min(parseInt(options.parallel), targets.length);
    const validTargets = targets.filter(t => t.valid);
    
    logger.step(`Déploiement parallèle (${parallelCount} simultanés)`);
    
    const results: DeploymentResult[] = [];
    const chunks = DeployUsbCommand.chunkArray(validTargets, parallelCount);
    
    for (const chunk of chunks) {
      const chunkPromises = chunk.map(target => 
        DeployUsbCommand.deploySingle(vaultPackage, target, options)
      );
      
      const chunkResults = await Promise.allSettled(chunkPromises);
      
      chunkResults.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          results.push(result.value);
        } else {
          results.push({
            target: chunk[index],
            success: false,
            duration: 0,
            error: result.reason?.message || 'Erreur inconnue'
          });
        }
      });
    }
    
    return results;
  }

  private static async deploySingle(
    vaultPackage: string,
    target: DeploymentTarget,
    options: DeployUsbOptions
  ): Promise<DeploymentResult> {
    
    const startTime = Date.now();
    
    try {
      logger.step(`📀 Déploiement: ${target.drive}`);
      
      if (options.dryRun) {
        // Simulation
        logger.debug(`[DRY-RUN] Déploiement simulé sur ${target.drive}`);
        return {
          target,
          success: true,
          duration: 1000,
          filesCount: 10,
          totalSize: 100 * 1024 * 1024
        };
      }
      
      // Créer structure sur USB
      const usbVaultDir = join(target.drive, 'USB-Video-Vault');
      
      if (existsSync(usbVaultDir) && !options.force) {
        throw new Error('Vault existant trouvé, utiliser --force pour écraser');
      }
      
      if (!existsSync(usbVaultDir)) {
        mkdirSync(usbVaultDir, { recursive: true });
      }
      
      // Copier vault
      let filesCount = 0;
      let totalSize = 0;
      
      if (statSync(vaultPackage).isDirectory()) {
        // Copie récursive du dossier
        const result = await DeployUsbCommand.copyRecursive(vaultPackage, usbVaultDir);
        filesCount = result.filesCount;
        totalSize = result.totalSize;
      } else {
        // Extraction archive .vault
        await DeployUsbCommand.extractArchive(vaultPackage, usbVaultDir);
        // TODO: compter fichiers extraits
        filesCount = 1;
        totalSize = statSync(vaultPackage).size;
      }
      
      // Vérification post-déploiement
      if (options.verify) {
        await DeployUsbCommand.verifyDeployment(usbVaultDir);
      }
      
      // Éjection si demandée
      if (options.eject) {
        await DeployUsbCommand.ejectDrive(target.drive);
      }
      
      const duration = Date.now() - startTime;
      
      logger.step(`✅ ${target.drive}: ${filesCount} fichiers (${formatBytes(totalSize)})`);
      
      return {
        target,
        success: true,
        duration,
        filesCount,
        totalSize
      };
      
    } catch (error: any) {
      const duration = Date.now() - startTime;
      
      logger.step(`❌ ${target.drive}: ${error?.message}`);
      
      return {
        target,
        success: false,
        duration,
        error: error?.message || 'Erreur inconnue'
      };
    }
  }

  private static async copyRecursive(source: string, target: string): Promise<{filesCount: number, totalSize: number}> {
    let filesCount = 0;
    let totalSize = 0;
    
    const items = readdirSync(source);
    
    for (const item of items) {
      const sourcePath = join(source, item);
      const targetPath = join(target, item);
      const stat = statSync(sourcePath);
      
      if (stat.isDirectory()) {
        mkdirSync(targetPath, { recursive: true });
        const result = await DeployUsbCommand.copyRecursive(sourcePath, targetPath);
        filesCount += result.filesCount;
        totalSize += result.totalSize;
      } else {
        copyFileSync(sourcePath, targetPath);
        filesCount++;
        totalSize += stat.size;
      }
    }
    
    return { filesCount, totalSize };
  }

  private static async extractArchive(archivePath: string, targetDir: string) {
    // TODO: Implémenter extraction avec yauzl
    logger.debug(`📦 Extraction ${archivePath} vers ${targetDir}`);
    throw new Error('Extraction archive non implémentée');
  }

  private static async verifyDeployment(deployedPath: string) {
    logger.debug(`🔍 Vérification: ${deployedPath}`);
    
    // Vérifier structure basique
    const mediaDir = join(deployedPath, 'media');
    if (!existsSync(mediaDir)) {
      throw new Error('Dossier media manquant après déploiement');
    }
    
    const mediaFiles = readdirSync(mediaDir);
    if (mediaFiles.length === 0) {
      throw new Error('Aucun fichier média après déploiement');
    }
  }

  private static async ejectDrive(drive: string) {
    try {
      if (process.platform === 'win32') {
        execSync(`powershell "& { (New-Object -comObject Shell.Application).Namespace(17).ParseName('${drive}').InvokeVerb('Eject') }"`, { stdio: 'ignore' });
      } else {
        execSync(`umount "${drive}"`, { stdio: 'ignore' });
      }
      logger.debug(`⏏️  Drive éjecté: ${drive}`);
    } catch (error) {
      logger.debug(`⚠️  Impossible d'éjecter: ${drive}`);
    }
  }

  private static async generateReport(results: DeploymentResult[], options: DeployUsbOptions) {
    logger.step('Génération rapport');
    
    const successful = results.filter(r => r.success);
    const failed = results.filter(r => !r.success);
    
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        total: results.length,
        successful: successful.length,
        failed: failed.length,
        totalSize: successful.reduce((sum, r) => sum + (r.totalSize || 0), 0),
        averageDuration: successful.reduce((sum, r) => sum + r.duration, 0) / successful.length || 0
      },
      successful: successful.map(r => ({
        drive: r.target.drive,
        duration: r.duration,
        filesCount: r.filesCount,
        totalSize: r.totalSize
      })),
      failed: failed.map(r => ({
        drive: r.target.drive,
        error: r.error
      }))
    };
    
    if (options.logFile) {
      writeFileSync(options.logFile, JSON.stringify(report, null, 2));
      logger.debug(`📄 Rapport sauvegardé: ${options.logFile}`);
    }
    
    // Affichage résumé
    logger.info(`📊 Résumé: ${report.summary.successful}/${report.summary.total} réussis`);
    if (report.summary.totalSize > 0) {
      logger.info(`📁 Données déployées: ${formatBytes(report.summary.totalSize)}`);
    }
  }

  private static chunkArray<T>(array: T[], size: number): T[][] {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }
}
