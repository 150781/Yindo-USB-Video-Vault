// Système de diagnostic et support utilisateur
// À intégrer dans le processus principal Electron

import { app, shell, dialog } from 'electron';
import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';

export class DiagnosticSystem {
  private static logDir = path.join(app.getPath('userData'), 'logs');
  
  static async initializeLogging() {
    // Créer le dossier de logs s'il n'existe pas
    if (!fs.existsSync(this.logDir)) {
      fs.mkdirSync(this.logDir, { recursive: true });
    }
    
    // Configurer la rotation des logs
    this.setupLogRotation();
  }
  
  static openLogsFolder() {
    shell.openPath(this.logDir);
  }
  
  static getSystemInfo() {
    const packageJson = require('../../package.json');
    
    return {
      application: {
        name: packageJson.name,
        version: packageJson.version,
        buildHash: process.env.BUILD_HASH || 'unknown',
        electron: process.versions.electron,
        chrome: process.versions.chrome,
        node: process.versions.node
      },
      system: {
        platform: os.platform(),
        release: os.release(),
        arch: os.arch(),
        cpus: os.cpus().length,
        memory: Math.round(os.totalmem() / 1024 / 1024 / 1024) + 'GB',
        uptime: Math.round(os.uptime() / 3600) + 'h'
      },
      process: {
        pid: process.pid,
        uptime: Math.round(process.uptime()) + 's',
        memoryUsage: process.memoryUsage(),
        argv: process.argv
      }
    };
  }
  
  static async copySystemInfoToClipboard() {
    const { clipboard } = require('electron');
    const info = this.getSystemInfo();
    
    const text = [
      '=== USB Video Vault - System Information ===',
      `Application: ${info.application.name} v${info.application.version}`,
      `Build Hash: ${info.application.buildHash}`,
      `Electron: ${info.application.electron}`,
      `Chrome: ${info.application.chrome}`,
      `Node: ${info.application.node}`,
      '',
      `Platform: ${info.system.platform} ${info.system.release} (${info.system.arch})`,
      `CPU Cores: ${info.system.cpus}`,
      `Memory: ${info.system.memory}`,
      `System Uptime: ${info.system.uptime}`,
      '',
      `Process ID: ${info.process.pid}`,
      `App Uptime: ${info.process.uptime}`,
      `Memory Usage: ${Math.round(info.process.memoryUsage.rss / 1024 / 1024)}MB RSS`,
      '',
      `Logs Directory: ${this.logDir}`
    ].join('\n');
    
    clipboard.writeText(text);
    
    dialog.showMessageBox({
      type: 'info',
      title: 'Informations système copiées',
      message: 'Les informations système ont été copiées dans le presse-papiers.',
      detail: 'Vous pouvez maintenant les coller dans un ticket de support.'
    });
  }
  
  static startSafeMode() {
    // Redémarrer l'application en mode sans échec
    app.relaunch({ args: [...process.argv.slice(1), '--safe-mode'] });
    app.exit(0);
  }
  
  static isSafeMode(): boolean {
    return process.argv.includes('--safe-mode');
  }
  
  private static setupLogRotation() {
    // Rotation simple des logs - garder les 7 derniers jours
    const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 jours en ms
    const now = Date.now();
    
    try {
      const files = fs.readdirSync(this.logDir);
      files.forEach(file => {
        const filePath = path.join(this.logDir, file);
        const stats = fs.statSync(filePath);
        if (now - stats.mtime.getTime() > maxAge) {
          fs.unlinkSync(filePath);
        }
      });
    } catch (error) {
      console.error('Erreur lors de la rotation des logs:', error);
    }
  }
  
  static logError(error: Error, context?: string) {
    const timestamp = new Date().toISOString();
    const logFile = path.join(this.logDir, `error-${new Date().toISOString().split('T')[0]}.log`);
    
    const logEntry = [
      `[${timestamp}] ERROR${context ? ` (${context})` : ''}`,
      `Message: ${error.message}`,
      `Stack: ${error.stack}`,
      '---'
    ].join('\n');
    
    fs.appendFileSync(logFile, logEntry + '\n');
  }
}

// Menu items à ajouter dans le processus principal
export const diagnosticMenuItems = [
  {
    label: 'Aide',
    submenu: [
      {
        label: 'Ouvrir le dossier des logs',
        click: () => DiagnosticSystem.openLogsFolder()
      },
      {
        label: 'Copier les informations système',
        click: () => DiagnosticSystem.copySystemInfoToClipboard()
      },
      { type: 'separator' },
      {
        label: 'Redémarrer en mode sans échec',
        click: () => {
          const response = dialog.showMessageBoxSync({
            type: 'warning',
            title: 'Mode sans échec',
            message: 'Redémarrer en mode sans échec ?',
            detail: 'Le mode sans échec désactive les modules optionnels et peut aider au diagnostic.',
            buttons: ['Annuler', 'Redémarrer'],
            defaultId: 0
          });
          
          if (response === 1) {
            DiagnosticSystem.startSafeMode();
          }
        }
      }
    ]
  }
];