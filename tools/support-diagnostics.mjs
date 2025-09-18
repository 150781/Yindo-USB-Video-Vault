#!/usr/bin/env node

/**
 * 🛠️ SUPPORT DIAGNOSTICS EXPORTER
 * Export automatique des logs et informations système
 */

import { existsSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';
import { execSync } from 'child_process';
import os from 'os';

class DiagnosticsExporter {
  constructor() {
    this.appDataPath = this.getAppDataPath();
    this.vaultPath = process.env.VAULT_PATH || './vault';
    this.timestamp = new Date().toISOString();
  }
  
  getAppDataPath() {
    const platform = os.platform();
    switch (platform) {
      case 'win32':
        return join(os.homedir(), 'AppData', 'Roaming', 'usb-video-vault');
      case 'darwin':
        return join(os.homedir(), 'Library', 'Application Support', 'usb-video-vault');
      default:
        return join(os.homedir(), '.config', 'usb-video-vault');
    }
  }
  
  async collectSystemInfo() {
    console.log('💻 Collecte informations système...');
    
    const info = {
      timestamp: this.timestamp,
      platform: os.platform(),
      arch: os.arch(),
      release: os.release(),
      version: os.version?.() || 'unknown',
      memory: {
        total: Math.round(os.totalmem() / 1024 / 1024 / 1024 * 100) / 100 + ' GB',
        free: Math.round(os.freemem() / 1024 / 1024 / 1024 * 100) / 100 + ' GB'
      },
      cpu: {
        model: os.cpus()[0]?.model || 'unknown',
        cores: os.cpus().length
      },
      hostname: os.hostname(),
      user: os.userInfo().username
    };
    
    // GPU info (Windows)
    if (os.platform() === 'win32') {
      try {
        const gpuInfo = execSync('wmic path win32_VideoController get name', { encoding: 'utf8' });
        info.gpu = gpuInfo.split('\\n')[1]?.trim() || 'unknown';
      } catch {
        info.gpu = 'unknown';
      }
    }
    
    return info;
  }
  
  async collectLicenseInfo() {
    console.log('🔑 Collecte informations licence...');
    
    const licenseInfo = {
      public_license: null,
      binary_license_exists: false,
      vault_path: this.vaultPath,
      license_status: 'unknown'
    };
    
    try {
      // Licence publique JSON
      const publicLicensePath = join(this.vaultPath, 'license.json');
      if (existsSync(publicLicensePath)) {
        const license = JSON.parse(readFileSync(publicLicensePath, 'utf8'));
        licenseInfo.public_license = {
          id: license.id,
          client: license.client,
          expires: license.expires,
          features: license.features,
          issued: license.issued
        };
        
        // Vérifier expiration
        const expiry = new Date(license.expires);
        const now = new Date();
        licenseInfo.license_status = expiry > now ? 'valid' : 'expired';
      }
      
      // Licence binaire
      const binaryLicensePath = join(this.vaultPath, '.vault', 'license.bin');
      licenseInfo.binary_license_exists = existsSync(binaryLicensePath);
      
    } catch (error) {
      licenseInfo.error = error.message;
    }
    
    return licenseInfo;
  }
  
  async collectVaultInfo() {
    console.log('🗄️ Collecte informations vault...');
    
    const vaultInfo = {
      vault_path: this.vaultPath,
      vault_exists: false,
      manifest_exists: false,
      media_count: 0,
      media_files: [],
      total_size: 0
    };
    
    try {
      vaultInfo.vault_exists = existsSync(this.vaultPath);
      
      if (vaultInfo.vault_exists) {
        // Manifest
        const manifestPath = join(this.vaultPath, '.vault', 'manifest.bin');
        vaultInfo.manifest_exists = existsSync(manifestPath);
        
        // Médias
        const mediaPath = join(this.vaultPath, 'media');
        if (existsSync(mediaPath)) {
          try {
            const files = execSync(`dir "${mediaPath}\\*.enc" /b`, { encoding: 'utf8' }).split('\\n').filter(f => f.trim());
            vaultInfo.media_count = files.length;
            vaultInfo.media_files = files.slice(0, 10); // Premiers 10 fichiers
            
            // Taille totale
            const sizeOutput = execSync(`dir "${mediaPath}\\*.enc" /-c`, { encoding: 'utf8' });
            const sizeMatch = sizeOutput.match(/(\\d+) octets/);
            if (sizeMatch) {
              vaultInfo.total_size = parseInt(sizeMatch[1]);
            }
          } catch (error) {
            vaultInfo.media_error = error.message;
          }
        }
      }
    } catch (error) {
      vaultInfo.error = error.message;
    }
    
    return vaultInfo;
  }
  
  async collectAppLogs() {
    console.log('📝 Collecte logs application...');
    
    const logs = {
      app_data_path: this.appDataPath,
      logs_found: false,
      recent_logs: [],
      error_logs: [],
      stats: null
    };
    
    try {
      if (existsSync(this.appDataPath)) {
        logs.logs_found = true;
        
        // Stats.json
        const statsPath = join(this.appDataPath, 'stats.json');
        if (existsSync(statsPath)) {
          logs.stats = JSON.parse(readFileSync(statsPath, 'utf8'));
        }
        
        // Logs récents (simulation - adapter selon votre système de logs)
        const logsPath = join(this.appDataPath, 'logs');
        if (existsSync(logsPath)) {
          // Chercher les derniers logs
          try {
            const logFiles = execSync(`dir "${logsPath}\\*.log" /b /od`, { encoding: 'utf8' }).split('\\n').filter(f => f.trim());
            if (logFiles.length > 0) {
              const latestLog = logFiles[logFiles.length - 1];
              const logContent = readFileSync(join(logsPath, latestLog), 'utf8');
              logs.recent_logs = logContent.split('\\n').slice(-50); // 50 dernières lignes
              logs.error_logs = logs.recent_logs.filter(line => 
                line.includes('ERROR') || line.includes('FATAL') || line.includes('exception')
              );
            }
          } catch (error) {
            logs.log_error = error.message;
          }
        }
      }
    } catch (error) {
      logs.error = error.message;
    }
    
    return logs;
  }
  
  async generateDiagnostics() {
    console.log('🔍 === EXPORT DIAGNOSTICS ===');
    
    const diagnostics = {
      version: "1.0.0",
      export_timestamp: this.timestamp,
      system: await this.collectSystemInfo(),
      license: await this.collectLicenseInfo(),
      vault: await this.collectVaultInfo(),
      logs: await this.collectAppLogs()
    };
    
    // Calculer hash anonyme pour support
    const hashData = `${diagnostics.system.platform}-${diagnostics.license.public_license?.id || 'none'}-${diagnostics.system.user}`;
    diagnostics.support_hash = require('crypto').createHash('sha256').update(hashData).digest('hex').substring(0, 16);
    
    // Anonymiser données sensibles
    if (diagnostics.system.user) {
      diagnostics.system.user = diagnostics.system.user.substring(0, 3) + '***';
    }
    if (diagnostics.system.hostname) {
      diagnostics.system.hostname = diagnostics.system.hostname.substring(0, 5) + '***';
    }
    
    return diagnostics;
  }
  
  async exportToFile(outputPath = null) {
    if (!outputPath) {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      outputPath = join(os.homedir(), 'Desktop', `usb-video-vault-diagnostics-${timestamp}.json`);
    }
    
    const diagnostics = await this.generateDiagnostics();
    writeFileSync(outputPath, JSON.stringify(diagnostics, null, 2));
    
    console.log(`✅ Diagnostics exportés vers: ${outputPath}`);
    console.log(`🔢 Hash support: ${diagnostics.support_hash}`);
    console.log(`📧 Envoyer ce fichier au support technique`);
    
    return outputPath;
  }
  
  async printSummary() {
    const diagnostics = await this.generateDiagnostics();
    
    console.log(`\\n📊 === RÉSUMÉ DIAGNOSTICS ===`);
    console.log(`🔢 Hash support: ${diagnostics.support_hash}`);
    console.log(`💻 Système: ${diagnostics.system.platform} ${diagnostics.system.arch}`);
    console.log(`🔑 Licence: ${diagnostics.license.public_license?.id || 'Aucune'} (${diagnostics.license.license_status})`);
    console.log(`🗄️ Vault: ${diagnostics.vault.media_count} médias (${Math.round(diagnostics.vault.total_size / 1024 / 1024)} MB)`);
    console.log(`📝 Logs: ${diagnostics.logs.error_logs?.length || 0} erreurs récentes`);
    
    // Alertes
    if (diagnostics.license.license_status === 'expired') {
      console.log(`⚠️ ALERTE: Licence expirée`);
    }
    if (diagnostics.logs.error_logs?.length > 0) {
      console.log(`⚠️ ALERTE: ${diagnostics.logs.error_logs.length} erreurs détectées`);
    }
    if (!diagnostics.vault.vault_exists) {
      console.log(`⚠️ ALERTE: Vault introuvable`);
    }
  }
}

// CLI Interface
async function main() {
  const [command, ...args] = process.argv.slice(2);
  const exporter = new DiagnosticsExporter();
  
  try {
    switch (command) {
      case 'export':
        const outputPath = args[0];
        await exporter.exportToFile(outputPath);
        break;
        
      case 'summary':
        await exporter.printSummary();
        break;
        
      case 'system':
        const systemInfo = await exporter.collectSystemInfo();
        console.log(JSON.stringify(systemInfo, null, 2));
        break;
        
      default:
        console.log(`
🛠️ SUPPORT DIAGNOSTICS EXPORTER

Commands:
  export [output_path]    Exporter diagnostics complets
  summary                 Résumé diagnostics
  system                  Informations système seulement

Examples:
  node support-diagnostics.mjs export
  node support-diagnostics.mjs summary
  node support-diagnostics.mjs export "C:\\temp\\diagnostics.json"
`);
        break;
    }
  } catch (error) {
    console.error(`❌ Erreur: ${error.message}`);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

export { DiagnosticsExporter };