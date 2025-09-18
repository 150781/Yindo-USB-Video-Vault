import { BrowserWindow, app } from 'electron';
import * as path from 'path';

let displayWin: BrowserWindow | null = null;
let ready = false;
const pendingMessages: Array<{ channel: string; payload: any }> = [];

export function getDisplayWindow() { return displayWin; }

export async function ensureDisplayWindow(): Promise<BrowserWindow> {
  if (displayWin && !displayWin.isDestroyed()) {
    if (!displayWin.isVisible()) displayWin.show();
    displayWin.focus();
    return displayWin;
  }

  displayWin = new BrowserWindow({
    width: 1280,
    height: 720,
    show: true,
    backgroundColor: '#000000',
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  ready = false;
  displayWin.on('closed', () => { displayWin = null; ready = false; });

  // Charge la page display
  await displayWin.loadFile(path.join(__dirname, '../../renderer/display.html'));

  // Quand la page est prête, vider la file
  displayWin.webContents.once('did-finish-load', () => {
    ready = true;
    for (const m of pendingMessages) {
      try { displayWin?.webContents.send(m.channel, m.payload); } catch { /* noop */ }
    }
    pendingMessages.length = 0;
  });

  return displayWin;
}

export function sendToDisplay(channel: string, payload: any) {
  if (!displayWin || displayWin.isDestroyed()) return;
  if (ready) {
    displayWin.webContents.send(channel, payload);
  } else {
    pendingMessages.push({ channel, payload });
  }
}

export async function openDisplayWindow() {
  const win = await ensureDisplayWindow();
  win.show(); win.focus();
}

export function closeDisplayWindow() {
  if (displayWin && !displayWin.isDestroyed()) {
    displayWin.close(); // 'closed' remettra displayWin = null
  }
}
