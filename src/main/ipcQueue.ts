import * as electron from 'electron';
const { ipcMain } = electron;
import { createDisplayWindow, getDisplayWindow, getControlWindow } from './windows';

type QueueItem = {
  id: string;
  title: string;
  durationMs?: number | null;
  source: 'asset' | 'vault';
  src?: string;
  mediaId?: string;
  artist?: string;
};

export const queueState = {
  items: [] as QueueItem[],
  currentIndex: -1,
  repeatMode: 'none' as 'none' | 'one' | 'all',
  isPlaying: false,
  isPaused: false,
};

// File d'attente pour les messages en cas de fenêtre pas encore prête
const pendingMessages: Array<{ channel: string; payload: any }> = [];
let displayReady = false;

function sendToDisplay(channel: string, payload: any) {
  console.log('[QUEUE] sendToDisplay appelé:', channel, payload);
  const win = getDisplayWindow();
  if (!win || win.isDestroyed()) {
    console.warn('[QUEUE] Pas de fenêtre display ou détruite');
    return;
  }

  console.log('[QUEUE] Fenêtre display trouvée, displayReady =', displayReady);
  if (displayReady) {
    console.log('[QUEUE] Envoi immédiat du message');
    win.webContents.send(channel, payload);
  } else {
    console.log('[QUEUE] Display pas prête, ajout à la file d\'attente');
    pendingMessages.push({ channel, payload });
  }
}

// Écouter quand la fenêtre display est prête
ipcMain.on('display:ready', () => {
  console.log('[QUEUE] display:ready reçu, pendingMessages:', pendingMessages.length);
  displayReady = true;
  const win = getDisplayWindow();
  if (win && !win.isDestroyed()) {
    // Envoyer tous les messages en attente
    for (const m of pendingMessages) {
      console.log('[QUEUE] Envoi message en attente:', m.channel, m.payload);
      try { win.webContents.send(m.channel, m.payload); } catch { /* noop */ }
    }
    pendingMessages.length = 0;
    console.log('[QUEUE] Tous les messages en attente envoyés');
  }
});

function dedupePush(list: QueueItem[], add: QueueItem[]) {
  // Permettre les doublons - ajouter tous les items sans vérification d'ID
  for (const it of add) { list.push(it); }
  return list;
}

function toOpenPayload(it: QueueItem) {
  if (!it) return null;
  if (it.source === 'vault' && it.mediaId) {
    return { id: it.id, mediaId: it.mediaId, title: it.title, artist: it.artist };
  }
  if (it.src?.startsWith('asset://') || it.src?.startsWith('file://')) {
    return { id: it.id, src: it.src, title: it.title, artist: it.artist };
  }
  if (it.src) {
    return { id: it.id, src: `asset://media/${it.src}`, title: it.title, artist: it.artist };
  }
  return null;
}

async function ensureDisplayAndSend(payload: any) {
  console.log('[QUEUE] ensureDisplayAndSend appelé avec payload:', payload);
  try {
    console.log('[QUEUE] Création/focus fenêtre display...');
    await createDisplayWindow();
    console.log('[QUEUE] Fenêtre display prête, envoi message...');
    sendToDisplay('player:open', payload);
    console.log('[QUEUE] Message player:open envoyé');

    // Envoyer les informations de la prochaine chanson
    sendNextSongInfo();
  } catch (e) {
    console.error('[QUEUE] Erreur ensureDisplayAndSend:', e);
  }
}

function sendNextSongInfo() {
  const nextIndex = queueState.currentIndex + 1;
  let nextItem: QueueItem | null = null;

  if (queueState.repeatMode === 'all' && nextIndex >= queueState.items.length) {
    // En mode repeat all, revenir au début
    nextItem = queueState.items[0] || null;
  } else if (nextIndex < queueState.items.length) {
    // Chanson suivante normale
    nextItem = queueState.items[nextIndex];
  }

  if (nextItem) {
    console.log('[QUEUE] Envoi info prochaine chanson:', nextItem.title, '-', nextItem.artist);
    sendToDisplay('player:next-info', {
      title: nextItem.title,
      artist: nextItem.artist
    });
  } else {
    console.log('[QUEUE] Pas de prochaine chanson, nettoyage display');
    sendToDisplay('player:next-info', { title: '', artist: '' });
  }
}

// Stats
const statsById: Record<string, number> = {};

// Queue handlers
ipcMain.handle('queue:get', async () => queueState);

ipcMain.handle('queue:add', async (_e, item: QueueItem) => {
  console.log('[QUEUE] ⚠️ queue:add appelé avec item:', item.title || item.id);
  const arr = Array.isArray(item) ? item : [item];
  console.log('[QUEUE] ⚠️ queue:add - avant ajout, queue actuelle:', queueState.items.length, 'items');
  queueState.items = dedupePush(queueState.items, arr);
  console.log('[QUEUE] ⚠️ queue:add - après ajout, queue nouvelle:', queueState.items.length, 'items');
  sendNextSongInfo(); // Mettre à jour l'affichage de la prochaine chanson
  return queueState;
});

ipcMain.handle('queue:addMany', async (_e, items: QueueItem[] | QueueItem) => {
  console.log('[QUEUE] ⚠️ queue:addMany appelé avec:', Array.isArray(items) ? items.length : 1, 'items');
  if (Array.isArray(items)) {
    console.log('[QUEUE] ⚠️ queue:addMany - titres:', items.map(i => i.title || i.id));
  } else {
    console.log('[QUEUE] ⚠️ queue:addMany - titre unique:', items.title || items.id);
  }
  const arr = Array.isArray(items) ? items : [items];
  console.log('[QUEUE] ⚠️ queue:addMany - avant ajout, queue actuelle:', queueState.items.length, 'items');
  queueState.items = dedupePush(queueState.items, arr);
  console.log('[QUEUE] ⚠️ queue:addMany - après ajout, queue nouvelle:', queueState.items.length, 'items');
  sendNextSongInfo(); // Mettre à jour l'affichage de la prochaine chanson
  return queueState;
});

ipcMain.handle('queue:removeAt', async (_e, index: number) => {
  if (index >= 0 && index < queueState.items.length) {
    queueState.items.splice(index, 1);
    if (queueState.currentIndex >= queueState.items.length) {
      queueState.currentIndex = queueState.items.length - 1;
    }
  }
  sendNextSongInfo(); // Mettre à jour l'affichage de la prochaine chanson
  return queueState;
});

ipcMain.handle('queue:playAt', async (_e, index: number) => {
  if (index < 0 || index >= queueState.items.length) return queueState;
  queueState.currentIndex = index;
  const it = queueState.items[index];
  const payload = toOpenPayload(it);
  if (!payload) return queueState;
  await ensureDisplayAndSend(payload);
  return queueState;
});

ipcMain.handle('queue:next', async () => {
  if (queueState.items.length === 0) return queueState;
  const next = Math.min(queueState.currentIndex + 1, queueState.items.length - 1);
  queueState.currentIndex = next;
  queueState.isPlaying = true;  // ← Mise à jour état isPlaying
  queueState.isPaused = false;
  const it = queueState.items[next];
  const payload = toOpenPayload(it);
  if (payload) {
    console.log('[QUEUE] next - passage à la chanson suivante:', payload.title);
    await ensureDisplayAndSend(payload);
  }
  return queueState;
});

ipcMain.handle('queue:prev', async () => {
  if (queueState.items.length === 0) return queueState;
  const prev = Math.max(queueState.currentIndex - 1, 0);
  queueState.currentIndex = prev;
  queueState.isPlaying = true;  // ← Mise à jour état isPlaying
  queueState.isPaused = false;
  const it = queueState.items[prev];
  const payload = toOpenPayload(it);
  if (payload) {
    console.log('[QUEUE] prev - passage à la chanson précédente:', payload.title);
    await ensureDisplayAndSend(payload);
  }
  return queueState;
});

ipcMain.handle('queue:playNow', async (_e, item: QueueItem) => {
  const arr = Array.isArray(item) ? item : [item];
  const targetId = arr[0]?.id;

  // Vérifier si l'élément existe déjà dans la queue
  const existingIdx = queueState.items.findIndex(x => x.id === targetId);

  if (existingIdx >= 0) {
    // L'élément existe déjà, juste le jouer sans l'ajouter
    queueState.currentIndex = existingIdx;
    console.log('[QUEUE] playNow - élément existant trouvé à l\'index:', existingIdx);
  } else {
    // L'élément n'existe pas, l'ajouter puis le jouer
    queueState.items = dedupePush(queueState.items, arr);
    const idx = queueState.items.findIndex(x => x.id === targetId);
    queueState.currentIndex = idx >= 0 ? idx : queueState.items.length - 1;
    console.log('[QUEUE] playNow - nouvel élément ajouté à l\'index:', queueState.currentIndex);
  }

  // Mise à jour état de lecture
  queueState.isPlaying = true;
  queueState.isPaused = false;

  const current = queueState.items[queueState.currentIndex];
  const payload = toOpenPayload(current);
  if (!payload) return queueState;

  console.log('[QUEUE] playNow - démarrage lecture:', payload.title);
  await ensureDisplayAndSend(payload);
  return queueState;
});

ipcMain.handle('queue:setRepeat', async (_e, mode: 'none' | 'one' | 'all') => {
  console.log('[QUEUE] setRepeat appelé:', mode, 'typeof:', typeof mode);
  queueState.repeatMode = mode;
  console.log('[QUEUE] queueState.repeatMode après assignation:', queueState.repeatMode, 'typeof:', typeof queueState.repeatMode);
  sendNextSongInfo(); // Mettre à jour l'affichage (change la logique de la prochaine chanson)
  return queueState;
});

ipcMain.handle('queue:getRepeat', async () => {
  return queueState.repeatMode;
});

ipcMain.handle('queue:reorder', async (_e, fromIndex: number, toIndex: number) => {
  console.log('[QUEUE] reorder appelé: fromIndex =', fromIndex, ', toIndex =', toIndex);

  if (fromIndex < 0 || fromIndex >= queueState.items.length ||
    toIndex < 0 || toIndex >= queueState.items.length ||
    fromIndex === toIndex) {
    console.warn('[QUEUE] reorder - indices invalides');
    return queueState;
  }

  // Réorganiser les items
  const items = [...queueState.items];
  const [movedItem] = items.splice(fromIndex, 1);
  items.splice(toIndex, 0, movedItem);
  queueState.items = items;

  // Ajuster currentIndex si nécessaire
  if (queueState.currentIndex === fromIndex) {
    // L'élément en cours de lecture a été déplacé
    queueState.currentIndex = toIndex;
  } else if (fromIndex < queueState.currentIndex && toIndex >= queueState.currentIndex) {
    // Élément déplacé d'avant vers après l'index courant
    queueState.currentIndex--;
  } else if (fromIndex > queueState.currentIndex && toIndex <= queueState.currentIndex) {
    // Élément déplacé d'après vers avant l'index courant
    queueState.currentIndex++;
  }

  console.log('[QUEUE] reorder terminé - nouvel ordre, currentIndex =', queueState.currentIndex);
  sendNextSongInfo(); // Mettre à jour l'affichage de la prochaine chanson
  return queueState;
});

// Stats handlers
ipcMain.handle('stats:get', async () => {
  return { byId: { ...statsById } };
});

ipcMain.handle('stats:played', async (_e, payload: { id: string; playedMs?: number }) => {
  const id = payload?.id;
  if (id) statsById[id] = (statsById[id] || 0) + 1;
  return { ok: true, playsCount: statsById[id] || 0 };
});

// Event depuis Display (ex: ended) - gestion repeat/next automatique
ipcMain.on('player:event', async (_e, payload) => {

  // 🔥 DEBUG - Afficher tous les événements reçus
  console.log('[QUEUE] player:event reçu:', payload);

  if (payload?.type === 'test-onended') {
    console.log('[QUEUE] 🔥🔥🔥 TEST-ONENDED reçu ! La fonction onEnded fonctionne !', payload.message);
    return;
  }

  if (payload?.type === 'ended') {
    console.log('[QUEUE] player:event ended reçu - gestion du repeat/next');
    console.log('[QUEUE] État actuel:', {
      repeatMode: queueState.repeatMode,
      currentIndex: queueState.currentIndex,
      itemsLength: queueState.items.length
    });

    // 🔥 AUTO-INCREMENT DES VUES 🔥
    const currentItem = queueState.items[queueState.currentIndex];
    if (currentItem?.id) {
      console.log('[QUEUE] 📊 Auto-incrémentation des vues pour:', currentItem.title || currentItem.id);
      if (!statsById[currentItem.id]) {
        statsById[currentItem.id] = 0;
      }
      statsById[currentItem.id]++;
      console.log('[QUEUE] 📊 Nouvelles vues pour', currentItem.title || currentItem.id, ':', statsById[currentItem.id]);

      // Notifier le renderer que les stats ont été mises à jour
      try {
        const controlWindow = getControlWindow();
        if (controlWindow && !controlWindow.isDestroyed()) {
          controlWindow.webContents.send('stats:updated', { id: currentItem.id, views: statsById[currentItem.id] });
          console.log('[QUEUE] 📊 Notification stats:updated envoyée au renderer');
        } else {
          console.log('[QUEUE] 📊 Fenêtre de contrôle non disponible pour notification stats');
        }
      } catch (e) {
        console.error('[QUEUE] 📊 Erreur lors de la notification stats:', e);
      }
    }

    if (queueState.repeatMode === 'one') {
      // Répéter la chanson actuelle - relancer la lecture
      console.log('[QUEUE] Mode repeat "one" - relance de la chanson actuelle');
      const current = queueState.items[queueState.currentIndex];
      if (current) {
        const payload = toOpenPayload(current);
        if (payload) {
          console.log('[QUEUE] Relance de la chanson en repeat "one":', payload);
          await ensureDisplayAndSend(payload);
        }
      }
    } else if (queueState.repeatMode === 'all') {
      // Passer à la suivante, ou retour au début si fin de liste
      console.log('[QUEUE] Mode repeat "all" - passage à la suivante');
      if (queueState.currentIndex < queueState.items.length - 1) {
        // Il y a une chanson suivante
        queueState.currentIndex++;
      } else {
        // Retour au début de la liste
        queueState.currentIndex = 0;
      }
      const next = queueState.items[queueState.currentIndex];
      if (next) {
        const payload = toOpenPayload(next);
        if (payload) {
          console.log('[QUEUE] Passage à la suivante en repeat "all":', payload);
          await ensureDisplayAndSend(payload);
        }
      }
    } else {
      // Mode 'none' - lecture séquentielle normale, s'arrêter seulement à la fin de la playlist
      console.log('[QUEUE] Mode repeat "none" - lecture séquentielle');
      if (queueState.currentIndex < queueState.items.length - 1) {
        // Il y a une chanson suivante - passer à la suivante
        console.log('[QUEUE] Passage à la chanson suivante (mode none)');
        queueState.currentIndex++;
        const next = queueState.items[queueState.currentIndex];
        if (next) {
          const payload = toOpenPayload(next);
          if (payload) {
            console.log('[QUEUE] Lecture de la chanson suivante:', payload);
            await ensureDisplayAndSend(payload);
          }
        }
      } else {
        // Fin de la playlist - arrêter
        console.log('[QUEUE] Fin de playlist - arrêt de la lecture');
        // Ne rien faire, laisser la vidéo s'arrêter
      }
    }
  }
});
