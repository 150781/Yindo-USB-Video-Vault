import * as electron from 'electron';
import type { BrowserWindow } from 'electron';
const { ipcMain, BrowserWindow: BrowserWindowImpl } = electron;
import {
  createDisplayWindow,
  closeDisplayWindowIfAny,
  getAllDisplays,
  toggleDisplayBetweenScreens,
  toggleDisplayFullscreen,
  getDisplayWindow,
  getControlWindow
} from './windows';
import { getManifestEntries, getCatalogEntries } from './manifest';
// License imports will be added later
import { licenseStatus, unlockLicense, saveLicense, enterPassphrase } from './license';
import { authorizeAndCount } from './playbackAuth';
import { touchActivity } from './activity';
import { unlockSession } from './index';
import {
  setQueue, addToQueue, clearQueue, getQueueState, playAt, playById,
  next as qNext, prev as qPrev, setRepeat as qSetRepeat, toggleShuffle as qToggleShuffle,
  removeFromQueue, removeFromQueueById, removeAt as qRemoveAt
} from './queue';
import { vaultManager, statsManager } from './index';
import { listPlaylists, savePlaylist, removePlaylist, renamePlaylist, getPlaylistItems } from './playlists';
import { PlayerQueue } from './playerQueue';
import type { QueueItem, QueueState } from '../types/shared';
import { whenDisplayReady } from './windows';

// Initialize PlayerQueue
const queue = new PlayerQueue(getControlWindow, getDisplayWindow);

ipcMain.handle('display:open', async (_e, { displayId }: { displayId?: number }) => {
  await createDisplayWindow(displayId);
});

ipcMain.handle('display:close', async () => {
  closeDisplayWindowIfAny();
});

ipcMain.handle('display:getAll', async () => {
  return getAllDisplays();
});

ipcMain.handle('display:toggleFullScreen', async () => {
  toggleDisplayFullscreen();
});

ipcMain.handle('display:toggleScreen', async () => {
  toggleDisplayBetweenScreens();
});

// DÉSACTIVÉ : player : Control => Display
// Remplacé par src/main/ipcPlayer.ts pour l'idempotence
/*
ipcMain.handle('player:open', async (_e, payload: { mediaId?: string, src?: string, title?: string, artist?: string }) => {
  console.log(`[IPC] player:open requested with payload:`, payload);

  // Si c'est un asset, pas besoin d'autorisation
  if (payload.src) {
    let dw = getDisplayWindow();
    if (!dw || dw.isDestroyed()) {
      console.log('[IPC] No valid display window found, creating one...');
      await createDisplayWindow();
      dw = getDisplayWindow();
    }
    if (!dw || dw.isDestroyed()) {
      console.log('[IPC] Failed to create display window');
      return { ok: false, error: 'DisplayWindow non ouverte' };
    }

    console.log('[IPC] Sending asset player:open to display window');
    console.log('[main] send player:open', payload.src ? `file:${payload.src}` : 'unknown');
    dw.webContents.send('player:open', {
      src: payload.src,
      title: payload.title || '',
      artist: payload.artist || ''
    });
    return { ok: true };
  }

  // Si c'est un vault mediaId, autorisation requise
  if (!payload.mediaId) {
    return { ok: false, error: 'mediaId ou src requis' };
  }

  const auth = await authorizeAndCount(payload.mediaId);
  if (!auth.ok) return auth;

  let dw = getDisplayWindow();
  if (!dw || dw.isDestroyed()) {
    console.log('[IPC] No valid display window found, creating one...');
    // Ouvre automatiquement la fenêtre d'affichage si elle n'existe pas
    await createDisplayWindow();
    dw = getDisplayWindow();
  }
  if (!dw || dw.isDestroyed()) {
    console.log('[IPC] Failed to create display window');
    return { ok:false, error: 'DisplayWindow non ouverte' };
  }

  // Récupérer métadonnées depuis le manifest
  try {
    const manifestResult = await getManifestEntries();
    const meta = manifestResult.find((m: any) => m.id === payload.mediaId);
    console.log('[IPC] Sending vault player:open to display window with metadata');
    console.log('[main] send player:open', `vault:${payload.mediaId}`);
    dw.webContents.send('player:open', {
      mediaId: payload.mediaId,
      title: meta?.title || '',
      artist: meta?.artist || ''
    });
  } catch (e) {
    console.log('[IPC] Failed to get metadata, sending without:', e);
    console.log('[main] send player:open', `vault:${payload.mediaId}`);
    dw.webContents.send('player:open', { mediaId: payload.mediaId });
  }

  return { ok:true };
});

// Display => Control (statut)
ipcMain.on('player:status:update', (event, status) => {
  for (const w of BrowserWindowImpl.getAllWindows()) {
    if (w.webContents.id !== event.sender.id) {
      w.webContents.send('player:status:update', status);
    }
  }
});

ipcMain.handle('manifest:list', async () => {
  try {
    const list = await getManifestEntries();
    return { ok: true, list };
  } catch (e: any) {
    return { ok: false, error: e?.message || 'Erreur manifest' };
  }
});

// ================================
// Stats IPC handlers
// ================================

ipcMain.handle('stats:get', async (_e, limit?: number) => {
  try {
    return { ok: true, items: statsManager.getAll(limit ?? 100) };
  } catch (e: any) {
    return { ok: false, error: e?.message || String(e), items: [] };
  }
});

ipcMain.handle('stats:getOne', async (_e, id: string) => {
  try {
    return { ok: true, item: statsManager.getOne(id) };
  } catch (e: any) {
    return { ok: false, error: e?.message || String(e), item: null };
  }
});

ipcMain.handle('stats:played', async (_e, payload: { id: string; playedMs: number; sessionId?: string }) => {
  try {
    // Mettre à jour l'activité pour empêcher l'auto-lock pendant la lecture
    touchActivity();
    const res = await statsManager.markPlayed(payload.id, payload.playedMs || 0, payload.sessionId);
    if (res) {
      console.log(`[stats] ✅ Lecture enregistrée: ${payload.id} (${payload.playedMs}ms) -> ${res.playsCount} lectures`);
      return { ok: true, item: res };
    } else {
      console.warn(`[stats] ⚠️ Lecture refusée pour ${payload.id} (sécurité)`);
      return { ok: false, error: 'Lecture refusée pour raisons de sécurité' };
    }
  } catch (e: any) {
    console.error('[stats] ❌ Erreur markPlayed:', e?.message);
    return { ok: false, error: e?.message || String(e) };
  }
});

// License handlers
ipcMain.handle('license:status', async () => licenseStatus());

// Main license:enter handler - always allows unlock attempts
ipcMain.handle('license:enter', async (_e, passphrase: string) => {
  const DEV_PASSPHRASE = process.env.VAULT_DEV_PASSPHRASE || 'test123';

  try {
    // Allow unlock attempt even if already unlocked
    console.log('[license:enter] tentative de déverrouillage...');

    if ((passphrase || '').trim() !== DEV_PASSPHRASE) {
      console.log('[license:enter] mot de passe incorrect');
      return { ok: false, error: 'Mot de passe invalide' };
    }

    // Try to unlock both legacy license and vault
    await unlockLicense();

    if (vaultManager) {
      try {
        vaultManager.unlock(passphrase);
        await vaultManager.loadManifest();
        console.log('[license:enter] vault déverrouillé');
      } catch (e) {
        console.warn('[license:enter] vault unlock failed:', e);
      }
    }

    // Unlock session and restart timer
    unlockSession();

    console.log('[license:enter] déverrouillage réussi');
    return { ok: true };
  } catch (e: any) {
    console.error('[license:enter] erreur:', e);
    return { ok: false, error: e?.message || 'Erreur de déverrouillage' };
  }
});

ipcMain.handle('license:unlock', async (_e, { pass }: { pass?: string } = {}) => {
  // 1) Unlock legacy license
  const legacyOk = await unlockLicense();

  // 2) Si pass fourni, tentative de déverrouillage vault aussi
  if (pass && vaultManager) {
    try {
      vaultManager.unlock(pass);
      await vaultManager.loadManifest();
      touchActivity(); // Update activity on successful vault unlock
      console.log('[license:unlock] vault déverrouillé également - activité mise à jour');
    } catch (e) {
      console.warn('[license:unlock] vault unlock failed:', e);
      // Pas d'erreur fatale : on continue avec le legacy
    }
  }

  // Update activity on any unlock attempt
  touchActivity();
  console.log('[license:unlock] activité mise à jour après déverrouillage');

  return { ok: legacyOk };
});
ipcMain.handle('license:save', async (_e, { bodyJson, sigB64 }) => {
  const ok = await saveLicense(bodyJson, sigB64);
  return { ok };
});

// Queue - using legacy handlers for compatibility only
// (New queue handlers are defined below)
ipcMain.handle('player:next', async () => qNext());
ipcMain.handle('player:prev', async () => qPrev());
// queue:setRepeat handler moved to ipcQueueStats.ts
ipcMain.handle('player:toggleShuffle', async () => qToggleShuffle());

// Debug logs depuis le renderer
ipcMain.on('debug-log', (_e, message) => {
  console.log(`[DEBUG] ${message}`);
});

// Playlists persistées
ipcMain.handle('playlists:list', async () => listPlaylists());
ipcMain.handle('playlists:save', async (_e, { name, itemIds }) => savePlaylist(name, itemIds || []));
ipcMain.handle('playlists:remove', async (_e, { id }) => removePlaylist(id));
ipcMain.handle('playlists:rename', async (_e, { id, name }) => renamePlaylist(id, name));
ipcMain.handle('playlists:loadToQueue', async (_e, { id }) => {
  const ids = await getPlaylistItems(id);
  setQueue(ids);
  return getQueueState();
});

// —— Queue handlers moved to ipcQueueStats.ts
/*
ipcMain.handle('queue:get', async () => queue.getState());
ipcMain.handle('queue:add', async (_e, item: QueueItem) => queue.add(item));
ipcMain.handle('queue:addMany', async (_e, items: QueueItem[]) => queue.addMany(items));
ipcMain.handle('queue:removeAt', async (_e, index: number) => queue.removeAt(index));
ipcMain.handle('queue:clear', async () => queue.clear());
ipcMain.handle('queue:playAt', async (_e, index: number) => queue.playAt(index));
ipcMain.handle('queue:playNow', async (_e, item: QueueItem) => queue.playNow(item));
ipcMain.handle('queue:repeat', async (_e, mode: QueueState['repeat']) => {
  console.log('[IPC] queue:repeat called with mode:', mode);
  queue.setRepeat(mode);
  const state = queue.getState();
  console.log('[IPC] queue:repeat returning state:', state);
  return state;
});
ipcMain.handle('queue:next', async () => queue.next());
ipcMain.handle('queue:prev', async () => queue.prev());
ipcMain.handle('player:ended', async () => queue.onEnded());
*/

/* Legacy handlers commentés - remplacés par ipcPlayer.ts
// —— Contrôles player relayés vers DisplayWindow
ipcMain.handle('player:control', async (_e, payload) => {
  const dw = getDisplayWindow(); if (!dw) return false;
  dw.webContents.send('player:control', payload);
  return true;
});

// Handlers player manquants
ipcMain.handle('player:play', async () => {
  touchActivity();
  const dw = getDisplayWindow(); if (!dw) return;
  dw.webContents.send('player:control', { action: 'play' });
});

ipcMain.handle('player:pause', async () => {
  touchActivity();
  const dw = getDisplayWindow(); if (!dw) return;
  dw.webContents.send('player:control', { action: 'pause' });
});

ipcMain.handle('player:stop', async () => {
  touchActivity();
  const dw = getDisplayWindow(); if (!dw) return;
  dw.webContents.send('player:control', { action: 'stop' });
});

ipcMain.handle('player:seek', async (_e, time: number) => {
  console.log('[main] SEEK only (no open/stop)', time);
  const dw = getDisplayWindow(); if (!dw) return;
  dw.webContents.send('player:control', { action: 'seek', time });
});

ipcMain.handle('player:setVolume', async (_e, volume: number) => {
  const dw = getDisplayWindow(); if (!dw) return;
  dw.webContents.send('player:control', { action: 'setVolume', volume });
});
*/

// Handler pour obtenir le statut du player
ipcMain.handle('player:getStatus', async () => {
  const state = queue.getState();
  return {
    isPlaying: state.currentIndex >= 0,
    isPaused: false,
    currentItem: state.currentIndex >= 0 ? state.items[state.currentIndex] : null,
    position: 0,
    duration: 0,
    volume: 1.0
  };
});

// ================================
// Vault IPC handlers
// ================================

ipcMain.handle('vault:unlock', async (_e, pass: string) => {
  try {
    if (!vaultManager) return { ok: false, error: 'VaultManager non initialisé' };
    vaultManager.unlock(pass);
    await vaultManager.loadManifest();

    // Dériver la clé stats avec le même salt que le vault
    const tag = (vaultManager as any)['tag'];
    if (tag && statsManager) {
      statsManager.deriveKey(pass, tag.saltHex);
      await statsManager.loadOrCreate();
      console.log('[stats] Clé dérivée et stats chargées');
    }

    touchActivity(); // Update activity on successful unlock
    console.log('[vault] déverrouillé avec succès - activité mise à jour');
    return { ok: true };
  } catch (e: any) {
    console.warn('[vault] erreur déverrouillage:', e?.message);
    return { ok: false, error: e?.message || String(e) };
  }
});

ipcMain.handle('catalog:list', async () => {
  try {
    // Combinaison : catalogue legacy + vault (si déverrouillé)
    const legacyCatalog = await getCatalogEntries();
    const vaultCatalog = (vaultManager && vaultManager.isUnlocked()) ? vaultManager.getCatalog() : [];

    const combined = [...legacyCatalog, ...vaultCatalog];
    console.log(`[catalog] retour: ${legacyCatalog.length} legacy + ${vaultCatalog.length} vault = ${combined.length} total`);

    return { ok: true, list: combined };
  } catch (e) {
    console.warn('[catalog] erreur:', e);
    const fallback = await getCatalogEntries();
    return { ok: true, list: fallback }; // fallback sur legacy uniquement
  }
});
