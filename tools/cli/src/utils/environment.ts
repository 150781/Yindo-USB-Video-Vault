import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { logger } from './logger.js';

export interface EnvironmentInfo {
  nodeVersion: string;
  platform: string;
  arch: string;
  hasGit: boolean;
  hasElectron: boolean;
  workingDir: string;
}

export async function validateEnvironment(): Promise<EnvironmentInfo> {
  logger.debug('🔍 Validation de l\'environnement...');

  const info: EnvironmentInfo = {
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    hasGit: false,
    hasElectron: false,
    workingDir: process.cwd()
  };

  // Vérifier Node.js version
  const nodeVersion = parseInt(process.version.slice(1).split('.')[0]);
  if (nodeVersion < 18) {
    throw new Error(`Node.js >= 18 requis, version actuelle: ${process.version}`);
  }

  // Vérifier Git
  try {
    execSync('git --version', { stdio: 'ignore' });
    info.hasGit = true;
    logger.debug('✅ Git disponible');
  } catch {
    logger.debug('⚠️  Git non disponible');
  }

  // Vérifier Electron
  try {
    execSync('npx electron --version', { stdio: 'ignore' });
    info.hasElectron = true;
    logger.debug('✅ Electron disponible');
  } catch {
    logger.debug('⚠️  Electron non disponible');
  }

  // Vérifier permissions écriture
  try {
    const testFile = `${process.cwd()}/.vault-cli-test-${Date.now()}`;
    require('fs').writeFileSync(testFile, 'test');
    require('fs').unlinkSync(testFile);
    logger.debug('✅ Permissions écriture OK');
  } catch (error: any) {
    logger.warn('⚠️  Permissions d\'écriture limitées:', error?.message);
    // Ne pas faire échouer la validation pour les permissions
  }

  logger.debug('🎯 Environnement validé:', info);
  return info;
}

export function getUsbDrives(): string[] {
  const drives: string[] = [];
  
  if (process.platform === 'win32') {
    try {
      // Windows: lister les lecteurs amovibles
      const output = execSync('wmic logicaldisk where drivetype=2 get size,freespace,caption', { encoding: 'utf8' });
      const lines = output.split('\n').filter(line => line.trim() && !line.includes('Caption'));
      
      for (const line of lines) {
        const match = line.match(/([A-Z]:)/);
        if (match) {
          drives.push(match[1] + '\\\\');
        }
      }
    } catch (error: any) {
      logger.debug('Erreur détection USB Windows:', error?.message || error);
    }
  } else {
    // Linux/Mac: parcourir /media et /mnt
    try {
      const mediaDirs = ['/media', '/mnt', '/Volumes'];
      for (const dir of mediaDirs) {
        if (existsSync(dir)) {
          const mounts = require('fs').readdirSync(dir) as string[];
          drives.push(...mounts.map((mount: string) => `${dir}/${mount}`));
        }
      }
    } catch (error: any) {
      logger.debug('Erreur détection USB Unix:', error?.message || error);
    }
  }

  logger.debug(`🔍 Lecteurs USB détectés: ${drives.length}`);
  return drives;
}

export function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}
