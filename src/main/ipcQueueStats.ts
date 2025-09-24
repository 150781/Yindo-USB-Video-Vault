import { BrowserWindow, ipcMain } from "electron";
import { getDisplayWindow, createDisplayWindow } from './windows';

console.log('[QUEUE_STATS] Module ipcQueueStats chargé - enregistrement des handlers...');

// 🔍 Handler pour les logs de debug depuis les renderer processes
ipcMain.on("debug-log", (_e, message: string) => {
  console.log(`[DEBUG-RENDERER] ${message}`);
});

type Source = "asset" | "vault";
type QueueItem = {
  id: string;
  title: string;
  durationMs?: number | null;
  source: Source;
  src?: string;
  mediaId?: string;
  artist?: string;
  genre?: string;
  year?: number;
};
type QueueState = {
  items: QueueItem[];
  currentIndex: number;
  isPlaying: boolean;
  isPaused: boolean;
  repeatMode: "none" | "one" | "all";
  shuffleMode: boolean;
};

// ---- ÉTAT EN MÉMOIRE (remplace ou connecte à ton store existant si tu en as un) ----
const state: QueueState = {
  items: [],
  currentIndex: -1,
    isPlaying: false,
    isPaused: false,
    repeatMode: "none",
    shuffleMode: false,
  };
  const statsById: Record<string, number> = {};

  // Idempotence d'ouverture : évite de renvoyer un "open" pour la même source
  let currentMediaKey: string | null = null;
  const computeKey = (it?: QueueItem | null): string | null =>
    !it ? null : it.mediaId ? `vault:${it.mediaId}` : it.src ? `file:${it.src}` : null;

  // Système de messages en attente pour la fenêtre d'affichage
  const pendingMessages: Array<{ channel: string; payload: any }> = [];
  let displayReady = false;

  const send = (ch: string, payload?: any) => {
    console.log('[QUEUE_STATS] send appelé:', ch, payload);
    const w = getDisplayWindow();
    if (!w || w.isDestroyed()) {
      console.warn('[QUEUE_STATS] Pas de fenêtre display ou détruite');
      return;
    }
    
    console.log('[QUEUE_STATS] Fenêtre display trouvée, displayReady =', displayReady);
    if (displayReady) {
      console.log('[QUEUE_STATS] Envoi immédiat du message');
      w.webContents.send(ch, payload);
    } else {
      console.log('[QUEUE_STATS] Display pas prête, ajout à la file d\'attente');
      pendingMessages.push({ channel: ch, payload });
    }
  };

  // Résolution de la source vidéo (payload envoyé à l'affichage)
  const toOpenPayload = (it: QueueItem) => {
    // DisplayApp.tsx accepte soit { mediaId } (vault://media/ID) soit { src } (asset://...)
    if (it.source === 'vault' && it.mediaId) {
      return { id: it.id, mediaId: it.mediaId, title: it.title, artist: it.artist };
    }
    // Asset : si src commence déjà par asset:// ou file:// on le passe tel quel
    if (it.src?.startsWith('asset://') || it.src?.startsWith('file://')) {
      return { id: it.id, src: it.src, title: it.title, artist: it.artist };
    }
    // Sinon, construire un chemin asset://media/<nom> (laisser tomber si on n'a rien)
    if (it.src) return { id: it.id, src: `asset://media/${it.src}`, title: it.title, artist: it.artist };
    // fallback : pas de lecture possible sans source
    return null;
  };

  const openAndPlay = (item: QueueItem) => {
    const payload = toOpenPayload(item);
    if (!payload) return; // pas de source → rien à ouvrir
    
    const key = computeKey(item);
    if (key && key === currentMediaKey) {
      // même média → ne pas recharger la source
    } else {
      currentMediaKey = key;
      send("player:open", payload);
    }
    send("player:control", { action: "play" });
  };

  // ---- HELPERS ----
  const dedupePush = (items: QueueItem[], toAdd: QueueItem[]): QueueItem[] => {
    // Permettre les doublons - ajouter tous les items sans vérification d'ID
    const out = items.slice();
    for (const it of toAdd) {
      out.push(it);
    }
    return out;
  };

  // ---- QUEUE HANDLERS ----
  ipcMain.handle("queue:get", async () => ({
    ...state,
    repeatMode: typeof state.repeatMode === 'string' ? state.repeatMode : 'none'
  }));

  // Alias rétrocompatible : queue:add (un seul item)
  ipcMain.handle("queue:add", async (_e, item: QueueItem) => {
    console.log('[ipc] queue:add reçu:', item);
    const arr = Array.isArray(item) ? item : [item];
    console.log('[ipc] avant dedupePush - state.items:', state.items.map(i => i.title || i.id));
    console.log('[ipc] avant dedupePush - nouveaux items:', arr.map(i => i.title || i.id));
    state.items = dedupePush(state.items, arr); // évite les doublons par id
    console.log('[ipc] après dedupePush - state.items:', state.items.map(i => i.title || i.id));
    return state;
  });

  // addMany (si pas déjà présent, garde-le aussi)
  ipcMain.handle("queue:addMany", async (_e, items: QueueItem[] | QueueItem) => {
    console.log('[ipc] queue:addMany reçu:', items);
    const arr = Array.isArray(items) ? items : [items];
    console.log('[ipc] avant dedupePush - state.items:', state.items.map(i => i.title || i.id));
    console.log('[ipc] avant dedupePush - nouveaux items:', arr.map(i => i.title || i.id));
    state.items = dedupePush(state.items, arr);
    console.log('[ipc] après dedupePush - state.items:', state.items.map(i => i.title || i.id));
    return state;
  });

  ipcMain.handle("queue:clear", async () => {
    state.items = [];
    state.currentIndex = -1;
    state.isPlaying = false;
    state.isPaused = false;
    currentMediaKey = null;
    return state;
  });

  // queue:playNow (clé pour la lecture immédiate)
  ipcMain.handle("queue:playNow", async (_e, item: QueueItem) => {
    const arr = Array.isArray(item) ? item : [item];
    state.items = dedupePush(state.items, arr);
    const id = arr[0].id;
    const idx = state.items.findIndex(x => x.id === id);
    state.currentIndex = idx >= 0 ? idx : state.items.length - 1;
    const current = state.items[state.currentIndex];
    const payload = toOpenPayload(current);
    if (!payload) return { ...state, repeatMode: typeof state.repeatMode === 'string' ? state.repeatMode : 'none' }; // pas de src → rien à ouvrir
    
    console.log('[QUEUE] playNow - ouverture de la fenêtre d\'affichage...');
    
    // Créer ou récupérer la fenêtre d'affichage
    let w = getDisplayWindow();
    console.log('[QUEUE] getDisplayWindow() retourne:', w ? 'fenêtre existante' : 'null');
    
    if (w) {
      console.log('[QUEUE] Fenêtre existante - isDestroyed():', w.isDestroyed());
    }
    
    if (!w || w.isDestroyed()) {
      console.log('[QUEUE] Création d\'une nouvelle fenêtre d\'affichage...');
      displayReady = false; // Réinitialiser l'état lors de la création d'une nouvelle fenêtre
      w = await createDisplayWindow();
    } else {
      console.log('[QUEUE] Réutilisation de la fenêtre existante');
    }
    
    if (w && !w.isDestroyed()) {
      console.log('[QUEUE] Envoi de player:open vers la fenêtre d\'affichage:', payload);
      // Utiliser la fonction send qui gère les messages en attente
      send('player:open', payload);
      w.show();
      w.focus();
    } else {
      console.error('[QUEUE] Impossible de créer la fenêtre d\'affichage');
    }
    
    state.isPaused = false;
    state.isPlaying = true;
    // IMPORTANT: s'assurer que repeatMode est une chaîne
    return {
      ...state,
      repeatMode: typeof state.repeatMode === 'string' ? state.repeatMode : 'none'
    };
  });

  ipcMain.handle("queue:removeAt", async (_e, index: number) => {
    if (index < 0 || index >= state.items.length) return state;
    state.items.splice(index, 1);
    if (state.currentIndex >= state.items.length) state.currentIndex = state.items.length - 1;
    return state;
  });

  ipcMain.handle("queue:next", async () => {
    if (state.items.length === 0) return state;
    const next = Math.min(state.currentIndex + 1, state.items.length - 1);
    state.currentIndex = next;
    const it = state.items[next];
    const p = toOpenPayload(it);
    if (p) send('player:open', p);
    return state;
  });

  ipcMain.handle("queue:prev", async () => {
    if (state.items.length === 0) return state;
    const prev = Math.max(state.currentIndex - 1, 0);
    state.currentIndex = prev;
    const it = state.items[prev];
    const p = toOpenPayload(it);
    if (p) send('player:open', p);
    return state;
  });

  ipcMain.handle("queue:playAt", async (_e, index: number) => {
    if (index < 0 || index >= state.items.length) return state;
    state.currentIndex = index;
    const it = state.items[index];
    const p = toOpenPayload(it);
    if (!p) return state;
    send('player:open', p);
    return state;
  });

  // ---- STATS HANDLERS ----
  ipcMain.handle("stats:get", async () => {
    return { byId: { ...statsById } }; // la UI sait normaliser plusieurs formats
  });

  ipcMain.handle("stats:played", async (_e, payload: { id: string; playedMs?: number }) => {
    const id = payload?.id;
    if (id) statsById[id] = (statsById[id] || 0) + 1;
    return { ok: true, playsCount: statsById[id] || 0 };
  });

  // Quand l'afficheur se (re)prépare
  ipcMain.on("display:ready", () => {
    console.log('[QUEUE_STATS] display:ready reçu, pendingMessages:', pendingMessages.length);
    displayReady = true;
    currentMediaKey = null;
    
    const win = getDisplayWindow();
    if (win && !win.isDestroyed()) {
      // Envoyer tous les messages en attente
      for (const m of pendingMessages) {
        console.log('[QUEUE_STATS] Envoi message en attente:', m.channel, m.payload);
        try { 
          win.webContents.send(m.channel, m.payload); 
        } catch (err) { 
          console.error('[QUEUE_STATS] Erreur envoi message:', err);
        }
      }
      pendingMessages.length = 0;
      console.log('[QUEUE_STATS] Tous les messages en attente envoyés');
    }
  });
