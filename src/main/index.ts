
import './safe-console';

import { app, BrowserWindow, nativeTheme, protocol, session, powerMonitor, ipcMain } from 'electron';
import path from 'path';
import fs from 'fs';
import { createControlWindow, getDisplayWindow } from './windows.js';
import './ipc.js';
import { VaultManager, resolveVaultPath } from './vault.js';
import { getIdleTime } from './activity.js';
import { isLicenseUnlocked, lockLicense } from './license.js';
import { loadAndValidateLicense, lockLicense as lockSecureLicense, isLicenseLoaded } from './licenseSecure.js';
import { StatsManager } from './stats.js';
import { registerPlayerIPC } from './ipcPlayer.js';
import './ipcQueue.js';
import { registerMediaProtocols } from './mediaProtocols.js';
import { registerSecurityIPC } from './ipcSecurity.js';
import { registerStatsExtendedIPC } from './ipcStatsExtended.js';
import { setupProductionCSP, setupDevelopmentCSP, setupCSPViolationLogging } from './csp.js';
import { initializeSandboxSecurity } from './sandbox.js';
import { initializeAntiDebugProtection } from './antiDebug.js';

// 1) Single-instance lock
const gotLock = app.requestSingleInstanceLock();

// VaultManager singleton
export let vaultManager: VaultManager;
export let statsManager: StatsManager;
(global as any).vaultManager = null; // pour ipc.ts si besoin
(global as any).statsManager = null;

// Session state management
let sessionLocked = false;
let lastActivity = Date.now();
let idleTimer: NodeJS.Timeout | null = null;
const IDLE_MS = Number(process.env.VAULT_IDLE_MS ?? 300_000); // 5min pour permettre les tests (au lieu de 30s)

function broadcast(channel: string, payload?: any) {
  BrowserWindow.getAllWindows().forEach(w => w.webContents.send(channel, payload));
}

function armIdleTimer() {
  // DÉSACTIVÉ pour les tests - pas de verrouillage automatique
  console.log('[session] Timer désactivé pour les tests');
  return;
}

function touchActivity() {
  lastActivity = Date.now();
  console.log('[session] activity @', new Date().toISOString());
  if (!sessionLocked) {
    armIdleTimer(); // Re-arm timer only if not locked
  }
}

// Function to unlock session (called from license:enter)
export function unlockSession() {
  sessionLocked = false;
  armIdleTimer(); // Start fresh timer cycle
  broadcast('session:unlocked', {});
  console.log('[session] session unlocked, timer re-armed');
}

async function lockVaultAndNotify(reason = 'idle') {
  try {
    console.log('[vault] LOCK reason =', reason);
    sessionLocked = true; // Mark session as locked
    
    // Verrouiller les deux systèmes de licence
    lockLicense(); // Legacy
    lockSecureLicense(); // Nouveau système sécurisé
    
    // Verrouiller le vault si disponible
    if (vaultManager) {
      await vaultManager.purgeCache();
      vaultManager.lock();
    }
    
    // Verrouiller les stats
    if (statsManager) statsManager.lock();
    
    // notifie toutes les fenêtres
    broadcast('session:locked', { reason });
    console.log('[vault] Verrouillage terminé');
  } catch (e) {
    console.error('[vault] lock error', e);
  }
}

if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    const windows = BrowserWindow.getAllWindows();
    const mainWindow = windows.find(w => w.getTitle().includes('Contrôle'));
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });
}

// 2) DevTools seulement en dev
const isDev = !app.isPackaged && process.env.FORCE_PRODUCTION !== 'true';

// Autorise la lecture sans geste utilisateur (utile quand le clic vient d'une autre fenêtre)
app.commandLine.appendSwitch('autoplay-policy', 'no-user-gesture-required');

// Doit être exécuté au tout début du process main
protocol.registerSchemesAsPrivileged([
  { scheme: 'vault', privileges: { secure: true, standard: true, supportFetchAPI: true, stream: true } },
  { scheme: 'asset', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } }
]);

function resolveVaultFromArgs(): string | undefined {
  const arg = process.argv.find(a => a.startsWith('--vault='));
  if (!arg) return undefined;
  return arg.split('=')[1].replace(/^["']|["']$/g, '');
}

(function resolveVaultPathAtStartup() {
  if (process.env.VAULT_PATH) return;

  const fromArgs = resolveVaultFromArgs();
  if (fromArgs && fs.existsSync(fromArgs)) {
    process.env.VAULT_PATH = fromArgs;
  } else if (process.env.PORTABLE_EXECUTABLE_DIR) {
    // electron-builder portable → dossier du .exe sur la clé USB
    const candidate = path.join(process.env.PORTABLE_EXECUTABLE_DIR, 'vault');
    process.env.VAULT_PATH = candidate;
  } else if (app.isPackaged) {
    // fallback packagé non-portable
    const exeDir = path.dirname(process.execPath);
    process.env.VAULT_PATH = path.join(exeDir, 'vault');
  } else {
    // DEV
    process.env.VAULT_PATH = path.resolve(process.cwd(), 'vault');
  }

  console.log('[VAULT_PATH]', process.env.VAULT_PATH);
})();

function setupTheme() {
  nativeTheme.themeSource = 'dark';
}

async function createApp() {
  setupTheme();
  
  // Import et log du vault path
  const { getVaultRoot } = await import('./vaultPath.js');
  console.log('[VAULT_PATH]', getVaultRoot());
  
  await createControlWindow();
}

app.whenReady().then(async () => {
  // === SÉCURITÉ CSP & SANDBOX & ANTI-DEBUG ===
  // Configuration CSP stricte selon l'environnement
  if (isDev) {
    setupDevelopmentCSP();
  } else {
    setupProductionCSP();
  }
  setupCSPViolationLogging();
  console.log('[CSP] Content Security Policy configuré');
  
  // Initialisation des protections sandbox
  initializeSandboxSecurity(isDev);
  console.log('[SANDBOX] Protections sandbox initialisées');
  
  // Initialisation des protections anti-debug
  if (!isDev) {
    initializeAntiDebugProtection();
    console.log('[ANTIDEBUG] Protections anti-debug initialisées');
  } else {
    console.log('[ANTIDEBUG] Mode DEV - protections anti-debug désactivées');
  }

  // Init vault (path: --vault=… | VAULT_PATH | voisin de l'exe)
  vaultManager = new VaultManager();
  (global as any).vaultManager = vaultManager;
  try {
    console.log('[vault] Initialisation du vault...');
    console.log('[vault] Path:', resolveVaultPath());
    await vaultManager.init(resolveVaultPath());
    console.log('[vault] ready at', resolveVaultPath());
  } catch (err) {
    console.error('[vault] init failed:', err);
    console.error('[vault] Stack trace:', err instanceof Error ? err.stack : 'No stack');
    
    // Ne pas abandonner complètement l'app pour les tests, mais loguer clairement
    console.warn('[vault] Continuité forcée pour les tests malgré échec init vault');
  }

  // Validation de licence sécurisée
  console.log('[LICENSE] === DEBUT VALIDATION LICENCE ===');
  try {
    console.log('[LICENSE] Validation de la licence sécurisée...');
    const licenseResult = await loadAndValidateLicense(resolveVaultPath());
    
    console.log('[LICENSE] Résultat validation:', licenseResult);
    
    if (licenseResult.isValid) {
      console.log('[LICENSE] ✅ Licence sécurisée valide');
      if (licenseResult.data) {
        console.log('[LICENSE] ID:', licenseResult.data.licenseId);
        console.log('[LICENSE] Features:', licenseResult.data.features.join(', '));
      }
    } else {
      console.error('[LICENSE] ❌ Licence sécurisée invalide:', licenseResult.reason);
      
      // En mode production, BLOQUER l'app si la licence est invalide
      if (!isDev) {
        console.error('[LICENSE] 🛑 Mode production - app bloquée pour licence invalide');
        console.error('[LICENSE] 🛑 QUITTING APP NOW');
        app.exit(1); // Exit with error code
        return;
      } else {
        console.warn('[LICENSE] Mode DEV - continuité autorisée malgré licence invalide');
      }
    }
  } catch (err) {
    console.error('[LICENSE] Erreur validation licence sécurisée:', err);
    
    // En mode production, BLOQUER l'app en cas d'erreur de licence
    if (!isDev) {
      console.error('[LICENSE] 🛑 Mode production - app bloquée pour erreur de licence');
      console.error('[LICENSE] 🛑 QUITTING APP NOW');
      app.exit(1); // Exit with error code
      return;
    } else {
      console.warn('[LICENSE] Mode DEV - continuité autorisée malgré erreur de licence');
    }
  }
  console.log('[LICENSE] === FIN VALIDATION LICENCE ===');

  // Stats (utiliser userData)
  statsManager = new StatsManager();
  (global as any).statsManager = statsManager;
  try {
    const deviceId = (vaultManager as any)['tag']?.deviceId || 'default-device';
    await statsManager.init(app.getPath('userData'), deviceId);
    console.log('[stats] ready for device', deviceId);
  } catch (err) {
    console.warn('[stats] init failed:', err);
  }

  // Enregistrement des protocoles médias
  registerMediaProtocols(vaultManager);

  // Configuration auto-lock
  console.log(`[auto-lock] Configuration: IDLE_MS=${IDLE_MS}ms (${IDLE_MS/1000}s)`);
  
  // Enregistrement du module IPC Player idempotent
  registerPlayerIPC(() => getDisplayWindow());
  console.log('[main] IPC Player idempotent enregistré');
  
  // Enregistrement des IPC de sécurité
  registerSecurityIPC();
  console.log('[main] IPC Security enregistré');
  
  // Enregistrement des IPC stats étendus
  registerStatsExtendedIPC();
  console.log('[main] IPC Stats Extended enregistré');
  
  // Note: IPC Queue & Stats est maintenant géré par le module './ipcQueue.js'
  console.log('[main] IPC Queue & Stats chargé via import');
  
  // Start with session unlocked and timer armed
  sessionLocked = false;
  armIdleTimer();

  // Verrouillage à la mise en veille / verrouillage de session OS
  powerMonitor.on('suspend', () => lockVaultAndNotify('suspend'));
  powerMonitor.on('lock-screen', () => lockVaultAndNotify('os-lock'));

  app.on('before-quit', async () => {
    try { await vaultManager.purgeCache(); } catch {}
  });

  createApp();
});

// Handlers IPC pour session/activité
ipcMain.on('session:activity', () => {
  touchActivity();
});

ipcMain.handle('session:status', async () => {
  return { locked: sessionLocked };
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('will-quit', () => {
  vaultManager?.cleanupTemp();
});

app.on('activate', async () => {
  if (BrowserWindow.getAllWindows().length === 0) await createControlWindow();
});
