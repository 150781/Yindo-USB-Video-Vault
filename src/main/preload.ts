/// <reference path="../types/electron-api.d.ts" />
import { contextBridge, ipcRenderer } from 'electron';
import type { ElectronAPI } from '../types/electron-api';

const api: Partial<ElectronAPI> = {
  ipc: {
    on: (ch, fn) => { 
      const handler = (_e: any, ...a: any[]) => fn(...a);
      ipcRenderer.on(ch, handler); 
      return () => ipcRenderer.removeListener(ch, handler); 
    },
    send: (ch, payload) => ipcRenderer.send(ch, payload),
  },

  openDisplayWindow: (p?: any) => ipcRenderer.invoke('display:open', { displayId: p?.displayId }),
  closeDisplayWindow: () => ipcRenderer.invoke('display:close'),
  toggleFullscreen: () => ipcRenderer.invoke('window:display:toggleFullscreen'),

  license: {
    enter: (pass: string) => ipcRenderer.invoke('license:enter', pass),
    enterPassphrase: (pass: string) => ipcRenderer.invoke('license:enter', pass), // Alias pour compatibilité
  },

  session: {
    activity: () => ipcRenderer.invoke('session:activity'),
    status: () => ipcRenderer.invoke('session:status'),
    onLocked: (fn: (p: any)=>void) => {
      const ch = 'session:locked';
      const handler = (_e: any, p: any) => fn?.(p);
      ipcRenderer.on(ch, handler);
      return () => ipcRenderer.removeListener(ch, handler);
    },
    onUnlocked: (fn: ()=>void) => {
      const ch = 'session:unlocked';
      const handler = () => fn?.();
      ipcRenderer.on(ch, handler);
      return () => ipcRenderer.removeListener(ch, handler);
    },
  },

  catalog: { list: () => ipcRenderer.invoke('catalog:list') },

  player: {
    open: (payload) => ipcRenderer.invoke('player:open', payload),
    control: (payload) => ipcRenderer.invoke('player:control', payload),
    play: () => ipcRenderer.invoke('player:control', { action: 'play' }),
    pause: () => ipcRenderer.invoke('player:control', { action: 'pause' }),
    stop: () => ipcRenderer.invoke('player:control', { action: 'stop' }),
    seek: (t: number) => ipcRenderer.invoke('player:control', { action: 'seek', value: t }),
    setVolume: (v: number) => ipcRenderer.invoke('player:control', { action: 'setVolume', value: v }),
    getStatus: () => ipcRenderer.invoke('player:status'),
    ended: () => ipcRenderer.send('player:ended'),
  },

  queue: {
    get: () => ipcRenderer.invoke('queue:get'),
    add: (item) => ipcRenderer.invoke('queue:add', item),
    addMany: (items) => ipcRenderer.invoke('queue:addMany', items),
    removeAt: (i) => ipcRenderer.invoke('queue:removeAt', i),
    clear: () => ipcRenderer.invoke('queue:clear'),
    next: () => ipcRenderer.invoke('queue:next'),
    prev: () => ipcRenderer.invoke('queue:prev'),
    playNow: (item) => ipcRenderer.invoke('queue:playNow', item),
    playAt: (i) => ipcRenderer.invoke('queue:playAt', i),
    status: () => ipcRenderer.invoke('queue:status'),
    setRepeat: (mode) => ipcRenderer.invoke('queue:setRepeat', mode),
    getRepeat: () => ipcRenderer.invoke('queue:getRepeat'),
    reorder: (fromIndex, toIndex) => ipcRenderer.invoke('queue:reorder', fromIndex, toIndex),
  },

  stats: {
    get: (limit?: number) => ipcRenderer.invoke('stats:get', limit),
    getOne: (id: string) => ipcRenderer.invoke('stats:getOne', id),
    played: (...args: any[]) => {
      const payload = (args.length === 1 && typeof args[0] === 'object')
        ? args[0]
        : { id: args[0], playedMs: args[1] };
      return ipcRenderer.invoke('stats:played', payload);
    },
    
    // Analytics étendus
    getAnalytics: (id: string) => ipcRenderer.invoke('stats:getAnalytics', id),
    getGlobalMetrics: () => ipcRenderer.invoke('stats:getGlobalMetrics'),
    getAnomalies: (limit?: number) => ipcRenderer.invoke('stats:getAnomalies', limit),
    validateIntegrity: () => ipcRenderer.invoke('stats:validateIntegrity'),
    exportSecure: (options?: { includeTimechain?: boolean; includeAnomalies?: boolean }) => 
      ipcRenderer.invoke('stats:exportSecure', options),
    findPatterns: (timeRange?: 'day' | 'week' | 'month') => 
      ipcRenderer.invoke('stats:findPatterns', timeRange),
  },

  security: {
    getState: () => ipcRenderer.invoke('security:getState'),
    getViolations: (since?: number) => ipcRenderer.invoke('security:getViolations', since),
    configure: (config: any) => ipcRenderer.invoke('security:configure', config),
    enableFullscreen: () => ipcRenderer.invoke('security:enableFullscreen'),
    disable: () => ipcRenderer.invoke('security:disable'),
    testViolation: (type: string, message: string) => ipcRenderer.invoke('security:testViolation', type, message),
  },
};

contextBridge.exposeInMainWorld('electron', api as ElectronAPI);
