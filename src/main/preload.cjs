// src/main/preload.cjs
const { contextBridge, ipcRenderer } = require('electron');

const api = {
  // Fenêtres / écran
  openDisplayWindow: (displayId) => ipcRenderer.invoke('display:open', { displayId }),
  closeDisplayWindow: () => ipcRenderer.invoke('display:close'),
  getDisplays: () => ipcRenderer.invoke('display:getAll'),
  toggleFullscreen: () => ipcRenderer.invoke('display:toggleFullScreen'),
  switchDisplay: () => ipcRenderer.invoke('display:toggleScreen'),

  // Bus IPC générique
  ipc: {
    send: (channel, payload) => ipcRenderer.send(channel, payload),
    invoke: (channel, payload) => ipcRenderer.invoke(channel, payload),
    on: (channel, listener) => {
      const wrapped = (_ev, ...args) => listener(...args);
      ipcRenderer.on(channel, wrapped);
      return () => ipcRenderer.removeListener(channel, wrapped);
    }
  },

  // ⬇⬇⬇ IMPORTANT : API licence + manifest + stats
  license: {
    status: () => ipcRenderer.invoke('license:status'),
    unlock: () => ipcRenderer.invoke('license:unlock'),
    save:   (bodyJson, sigB64) => ipcRenderer.invoke('license:save', { bodyJson, sigB64 }),

    // 👇 Alias de compatibilité pour l'ancien écran "mot de passe"
    enterPassphrase: async (pass) => {
      // Validation du mot de passe - pour l'instant on accepte "test123"
      if (pass !== 'test123') {
        return { ok: false, error: 'Mot de passe incorrect' };
      }
      
      const st = await ipcRenderer.invoke('license:status');
      if (!(st?.files?.existsJson && st?.files?.existsSig)) {
        throw new Error('Aucune licence trouvée. Placez license.json et license.sig ou utilisez l\'écran de saisie.');
      }
      const { ok } = await ipcRenderer.invoke('license:unlock');
      return { ok };
    },
  },
  manifest: {
    list: () => ipcRenderer.invoke('manifest:list'),
  },
  catalog: {
    list: () => ipcRenderer.invoke('catalog:list'),
  },
  player: {
    open: (payload) => ipcRenderer.invoke('player:open', payload),
    control: (payload) => ipcRenderer.invoke('player:control', payload),
    play: () => ipcRenderer.invoke('player:control', { action: 'play' }),
    pause: () => ipcRenderer.invoke('player:control', { action: 'pause' }),
    stop: () => ipcRenderer.invoke('player:control', { action: 'stop' }),
    seek: (time) => ipcRenderer.invoke('player:control', { action: 'seek', seconds: time }),
    setVolume: (volume) => ipcRenderer.invoke('player:control', { action: 'volume', volume }),
    getStatus: () => ipcRenderer.invoke('player:getStatus'),
    ended: () => ipcRenderer.invoke('player:ended'),
  },
  stats: {
    get: () => ipcRenderer.invoke('stats:get'),
  },
  queue: {
    get: () => ipcRenderer.invoke('queue:get'),
    add: (item) => ipcRenderer.invoke('queue:add', item),
    addMany: (items) => ipcRenderer.invoke('queue:addMany', items),
    removeAt: (index) => ipcRenderer.invoke('queue:removeAt', index),
    clear: () => ipcRenderer.invoke('queue:clear'),
    playAt: (index) => ipcRenderer.invoke('queue:playAt', index),
    playNow: (item) => ipcRenderer.invoke('queue:playNow', item),
    next: () => ipcRenderer.invoke('queue:next'),
    prev: () => ipcRenderer.invoke('queue:prev'),
    setRepeat: (mode) => ipcRenderer.invoke('queue:setRepeat', mode),
    getRepeat: () => ipcRenderer.invoke('queue:getRepeat'),
    reorder: (fromIndex, toIndex) => ipcRenderer.invoke('queue:reorder', fromIndex, toIndex),
    onUpdate: (cb) => {
      const fn = (_e, st) => cb(st);
      ipcRenderer.on('queue:update', fn);
      return () => ipcRenderer.removeListener('queue:update', fn);
    },
    
    // Legacy queue APIs (compatibility)
    set: (ids, startId) => ipcRenderer.invoke('queue:set', { ids, startId }),
    repeat: (mode) => ipcRenderer.invoke('queue:repeat', mode),
    toggleShuffle: () => ipcRenderer.invoke('player:toggleShuffle'),
    play: (id) => ipcRenderer.invoke('player:play', { id }),
  },
  playlists: {
    list: () => ipcRenderer.invoke('playlists:list'),
    save: (name, itemIds) => ipcRenderer.invoke('playlists:save', { name, itemIds }),
    remove: (id) => ipcRenderer.invoke('playlists:remove', { id }),
    rename: (id, name) => ipcRenderer.invoke('playlists:rename', { id, name }),
    loadToQueue: (id) => ipcRenderer.invoke('playlists:loadToQueue', { id }),
  },
};

contextBridge.exposeInMainWorld('electron', api);
console.log('[preload.cjs] window.electron exposé:', Object.keys(api));
console.log('[preload.cjs] methods license:', Object.keys(api.license));
