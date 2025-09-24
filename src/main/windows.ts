import { app, BrowserWindow, screen } from 'electron';
import * as path from 'path';
import * as fs from 'fs';
import { playerSecurity } from './playerSecurity';
import { getSandboxWebPreferences, setupKioskProtection, validateSandboxConfig } from './sandbox';
import { setupWebContentsCSP } from './csp';
import { setupWebContentsAntiDebug } from './antiDebug';

// __filename et __dirname sont automatiquement disponibles en CommonJS

let controlWindow: BrowserWindow | null = null;
let displayWindow: BrowserWindow | null = null;

const isDev = process.env.NODE_ENV === 'development'; // Utiliser la variable d'environnement

function preloadPath() {
  if (isDev) {
    return path.resolve(process.cwd(), 'src/main/preload.cjs');           // DEV: charge direct le .cjs source
  }
  // PROD: Dans une app packagée, __dirname pointe vers dist/main
  const preloadPath = path.join(__dirname, 'preload.cjs');
  console.log(`[preloadPath] Using: ${preloadPath}`);
  console.log(`[preloadPath] __dirname is: ${__dirname}`);
  return preloadPath;
}

function loadURL(win: BrowserWindow, page: 'index' | 'display') {
  if (isDev) {
    const base = process.env.VITE_DEV_SERVER_URL!;
    console.log(`[loadURL DEV] Loading ${base}/${page}.html`);
    win.loadURL(`${base}/${page}.html`);
  } else {
    // PROD: Dans une app packagée, __dirname pointe vers dist/main
    // donc les fichiers HTML sont dans ../renderer
    const filePath = path.join(__dirname, '..', 'renderer', `${page}.html`);
    console.log(`[loadURL PROD] Loading: ${filePath}`);
    console.log(`[loadURL PROD] __dirname is: ${__dirname}`);
    console.log(`[loadURL PROD] app.getAppPath() is: ${app.getAppPath()}`);
    console.log(`[loadURL PROD] process.resourcesPath is: ${process.resourcesPath}`);

    win.loadFile(filePath).catch(err => {
      console.error(`[loadURL PROD] Failed to load ${filePath}:`, err);
    });
  }
}

export async function createControlWindow() {
  if (controlWindow && !controlWindow.isDestroyed()) {
    controlWindow.focus();
    return controlWindow;
  }
  controlWindow = new BrowserWindow({
    width: 1100,
    height: 720,
    x: 100,
    y: 100,
    backgroundColor: '#0b0f14',
    minWidth: 900,
    minHeight: 600,
    show: true,  // Afficher immédiatement
    center: true,
    focusable: true,
    alwaysOnTop: true,  // Toujours au-dessus au début
    webPreferences: {
      ...getSandboxWebPreferences(isDev),
      devTools: isDev  // DevTools seulement en dev, pas en prod/tests
    }
  });

  // Logs de débogage pour le chargement
  controlWindow.webContents.on('did-fail-load', (_e, code, desc, url) => {
    console.error('[Control did-fail-load]', code, desc, url);
  });
  controlWindow.webContents.on('did-finish-load', () => {
    console.log('[Control did-finish-load]');

    // === SÉCURITÉ ===
    // Validation sandbox et CSP
    if (controlWindow) {
      validateSandboxConfig(controlWindow.webContents);
      setupWebContentsCSP(controlWindow.webContents);
      setupKioskProtection(controlWindow);

      // Protection anti-debug (seulement en production)
      if (!isDev) {
        setupWebContentsAntiDebug(controlWindow.webContents);
      }
    }

    // Forcer l'affichage de la fenêtre après le chargement
    if (controlWindow && !controlWindow.isDestroyed()) {
      console.log('[Control] Affichage forcé de la fenêtre de contrôle');
      controlWindow.show();
      controlWindow.focus();
      controlWindow.setAlwaysOnTop(true);
      controlWindow.center();
      controlWindow.moveTop();
      setTimeout(() => {
        if (controlWindow && !controlWindow.isDestroyed()) {
          controlWindow.setAlwaysOnTop(false);
          console.log('[Control] Fenêtre de contrôle visible et centrée');
        }
      }, 2000);
    }
  });
  controlWindow.webContents.on('dom-ready', () => {
    console.log('[Control dom-ready]');
  });

  // DevTools temporaires pour debug
  console.log('[DEBUG] Opening DevTools for testing');
  controlWindow.webContents.openDevTools({ mode: 'detach' });

  controlWindow.on('closed', () => (controlWindow = null));

  // Bloquer les ouvertures externes
  controlWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));

  loadURL(controlWindow, 'index');
  return controlWindow;
}

export function getControlWindow() {
  return controlWindow;
}

export function getDisplayWindow() {
  return displayWindow;
}

export async function createDisplayWindow(targetDisplayId?: number) {
  if (displayWindow && !displayWindow.isDestroyed()) {
    displayWindow.focus();
    return displayWindow;
  }

  const displays = screen.getAllDisplays();
  const target = (targetDisplayId && displays.find(d => d.id === targetDisplayId)) || displays[1] || displays[0];

  // 👉 Fenêtré (réduit) par défaut : 1280x720, centré sur l'écran cible
  const width = Math.min(1280, target.workArea.width);
  const height = Math.min(720, target.workArea.height);
  const x = Math.round(target.workArea.x + (target.workArea.width - width) / 2);
  const y = Math.round(target.workArea.y + (target.workArea.height - height) / 2);

  displayWindow = new BrowserWindow({
    x, y, width, height,
    backgroundColor: '#000000',
    frame: false,
    show: true,
    fullscreen: false, // ← démarre en fenêtré
    autoHideMenuBar: true, // 💄 masque la barre de menu si elle apparaît
    webPreferences: {
      ...getSandboxWebPreferences(isDev)
    }
  });

  displayWindow.on('closed', async () => {
    console.log('[Display] Fermeture, désactivation sécurité...');
    try {
      await playerSecurity.disableSecurity();
      console.log('[SECURITY] ✅ Sécurité désactivée');
    } catch (error) {
      console.error('[SECURITY] ❌ Erreur désactivation sécurité:', error);
    }
    displayWindow = null;
  });

  // Bloquer les ouvertures externes
  displayWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));

  displayWindow.webContents.on('did-fail-load', (_e, code, desc, url) => {
    console.error('[Display did-fail-load]', code, desc, url);
  });
  displayWindow.webContents.on('did-finish-load', async () => {
    console.log('[Display did-finish-load]');

    // === SÉCURITÉ ===
    // Validation sandbox et CSP
    if (displayWindow) {
      validateSandboxConfig(displayWindow.webContents);
      setupWebContentsCSP(displayWindow.webContents);
      setupKioskProtection(displayWindow);

      // Protection anti-debug (seulement en production)
      if (!isDev) {
        setupWebContentsAntiDebug(displayWindow.webContents);
      }
    }

    // Activer la sécurité du lecteur si la fenêtre display est créée
    if (displayWindow) {
      try {
        console.log('[SECURITY] Activation sécurité DisplayWindow...');
        await playerSecurity.enableSecurity(displayWindow, {
          preventScreenCapture: true,
          kioskMode: true,
          watermark: {
            text: `© USB Video Vault - ${new Date().getFullYear()}`,
            position: 'bottom-right',
            opacity: 0.6,
            size: 12,
            color: '#ffffff',
            rotation: -15,
            frequency: 45
          },
          antiDebug: true,
          exclusiveFullscreen: false, // Démarrer en fenêtré
          displayControl: {
            allowedDisplays: [], // Tous autorisés
            preventMirror: true,
            detectExternalCapture: true
          }
        });
        console.log('[SECURITY] ✅ Sécurité DisplayWindow activée');
      } catch (error) {
        console.error('[SECURITY] ❌ Erreur activation sécurité DisplayWindow:', error);
      }
    }

    // Notifier le module IPC Player que la fenêtre display est prête
    displayWindow?.webContents.send('display:ready');
  });

  loadURL(displayWindow, 'display');
  return displayWindow;
}

export async function closeDisplayWindowIfAny() {
  if (displayWindow && !displayWindow.isDestroyed()) {
    // Désactiver la sécurité avant fermeture
    try {
      await playerSecurity.disableSecurity();
    } catch (error) {
      console.warn('[SECURITY] Erreur désactivation sécurité avant fermeture:', error);
    }
    displayWindow.close();
    displayWindow = null;
  }
}

export function moveDisplayToSecondScreen() {
  const dw = displayWindow;
  if (!dw) return;
  const displays = screen.getAllDisplays();
  if (displays.length < 2) return;

  const second = displays[1];
  dw.setBounds(second.workArea);
  dw.setFullScreen(true);
  dw.focus();
}

export async function whenDisplayReady(): Promise<BrowserWindow> {
  let dw = getDisplayWindow();
  if (!dw || dw.isDestroyed()) {
    dw = await createDisplayWindow();
  }
  if (dw.webContents.isLoading()) {
    await new Promise<void>(resolve => {
      const done = () => resolve();
      dw!.webContents.once('did-finish-load', done);
      // garde-fou si déjà prêt :
      setTimeout(() => { if (!dw!.webContents.isLoading()) resolve(); }, 100);
    });
  }
  return dw;
}

export function toggleDisplayFullscreen() {
  const dw = displayWindow;
  if (!dw) return;
  dw.setFullScreen(!dw.isFullScreen());
}

export function toggleDisplayBetweenScreens() {
  const dw = displayWindow;
  if (!dw) return;
  const displays = screen.getAllDisplays();
  if (displays.length < 2) return;
  const currentBounds = dw.getBounds();
  const onSecond = currentBounds.x === displays[1].workArea.x && currentBounds.y === displays[1].workArea.y;
  const target = onSecond ? displays[0] : displays[1];
  dw.setBounds(target.workArea);
  dw.setFullScreen(true);
}

export function getAllDisplays() {
  return screen.getAllDisplays().map(d => ({
    id: d.id,
    bounds: d.bounds
  }));
}
