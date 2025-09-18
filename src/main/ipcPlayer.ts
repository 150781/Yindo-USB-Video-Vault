import { BrowserWindow, ipcMain } from "electron";
import { queueState } from "./ipcQueue.js";

export function registerPlayerIPC(getDisplayWin: () => BrowserWindow | null) {
  let currentMediaKey: string | null = null;

  const computeKey = (p: any): string | null =>
    p?.mediaId ? `vault:${p.mediaId}` : p?.src ? `file:${p.src}` : null;

  const send = (channel: string, payload?: any) => {
    const w = getDisplayWin();
    if (w && !w.isDestroyed()) {
      w.webContents.send(channel, payload);
      return true;
    }
    return false;
  };

  // --- OUVERTURE : idempotente (ne renvoie pas "open" si la source n'a pas changé)
  ipcMain.handle("player:open", async (_e, payload) => {
    const key = computeKey(payload);
    console.log('[main] player:open key=', key, 'current=', currentMediaKey);
    if (key && key === currentMediaKey) {
      console.log('[main] player:open SKIPPED (même source)');
      return { ok: true, skipped: true }; // même média → pas de reload
    }
    currentMediaKey = key;
    console.log('[main] player:open FORWARDED, new key=', key);
    send("player:open", payload);
    return { ok: true };
  });

  // --- CONTRÔLES : relayés strictement → JAMAIS traduits en "open"
  ipcMain.handle("player:control", async (_e, payload) => {
    // Mettre à jour le queueState selon l'action
    if (payload.action === 'play') {
      queueState.isPlaying = true;
      queueState.isPaused = false;
      console.log('[main] player:control - État mis à jour: isPlaying=true');
    } else if (payload.action === 'pause') {
      queueState.isPlaying = false;
      queueState.isPaused = true;
      console.log('[main] player:control - État mis à jour: isPlaying=false, isPaused=true');
    } else if (payload.action === 'stop') {
      queueState.isPlaying = false;
      queueState.isPaused = false;
      console.log('[main] player:control - État mis à jour: stopped');
    }
    
    // Remarque : si payload.action === "seek", on ne touche pas à currentMediaKey
    if (payload.action === 'seek') {
      console.log('[main] player:control SEEK only (no media change), time=', payload.value);
    }
    send("player:control", payload);
    return { ok: true };
  });

  // (facultatif) prise en charge fire-and-forget via .on
  ipcMain.on("player:open", (_e, payload) => {
    const key = computeKey(payload);
    if (key && key === currentMediaKey) return;
    currentMediaKey = key;
    send("player:open", payload);
  });

  ipcMain.on("player:control", (_e, payload) => {
    // Mettre à jour le queueState pour les appels fire-and-forget aussi
    if (payload.action === 'play') {
      queueState.isPlaying = true;
      queueState.isPaused = false;
    } else if (payload.action === 'pause') {
      queueState.isPlaying = false;
      queueState.isPaused = true;
    } else if (payload.action === 'stop') {
      queueState.isPlaying = false;
      queueState.isPaused = false;
    }
    
    send("player:control", payload);
  });

  // Quand la fenêtre display est recréée, on réinitialise la clé
  ipcMain.on("display:ready", () => {
    console.log('[main] display:ready - reset currentMediaKey');
    currentMediaKey = null;
  });
}
