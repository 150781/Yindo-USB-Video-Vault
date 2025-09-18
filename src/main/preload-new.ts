/// <reference path="../types/electron-api.d.ts" />
import { contextBridge, ipcRenderer } from 'electron';

const api: any = {
  player: {
    open: (payload: any) => ipcRenderer.invoke('player:open', payload),
    control: (payload: any) => ipcRenderer.invoke('player:control', payload),
    play: () => ipcRenderer.invoke('player:control', { action: 'play' }),
    pause: () => ipcRenderer.invoke('player:control', { action: 'pause' }),
    stop: () => ipcRenderer.invoke('player:control', { action: 'stop' }),
    seek: (time: number) => ipcRenderer.invoke('player:control', { action: 'seek', seconds: time }),
    setVolume: (volume: number) => ipcRenderer.invoke('player:control', { action: 'volume', volume }),
    getStatus: () => ipcRenderer.invoke('player:status'),
  },

  queue: {
    get: () => ipcRenderer.invoke('queue:get'),
    add: (item: any) => ipcRenderer.invoke('queue:add', item),
    addMany: (items: any[]) => ipcRenderer.invoke('queue:addMany', items),
    removeAt: (index: number) => ipcRenderer.invoke('queue:removeAt', index),
    clear: () => ipcRenderer.invoke('queue:clear'),
    playAt: (index: number) => ipcRenderer.invoke('queue:playAt', index),
    playNow: (item: any) => ipcRenderer.invoke('queue:playNow', item),
    repeat: (mode: 'off'|'one'|'all') => ipcRenderer.invoke('queue:repeat', mode),
    next: () => ipcRenderer.invoke('queue:next'),
    prev: () => ipcRenderer.invoke('queue:prev'),
    onUpdate: (cb: (st:any)=>void) => {
      const fn = (_e: any, st: any) => cb(st);
      ipcRenderer.on('queue:update', fn);
      return () => ipcRenderer.removeListener('queue:update', fn);
    },
    play: (id: string) => ipcRenderer.invoke('queue:playById', id).catch(()=>false),
  },

  catalog: {
    list: () => ipcRenderer.invoke('catalog:list'),
  },

  license: {
    status: () => ipcRenderer.invoke('license:status'),
    unlock: () => ipcRenderer.invoke('license:unlock'),
    save: (bodyJson: string, sigB64: string) => ipcRenderer.invoke('license:save', { bodyJson, sigB64 }),
    enterPassphrase: (pass?: string) => ipcRenderer.invoke('license:unlock', { pass }),
  },

  ipc: {
    on: (channel: string, cb: (data:any)=>void) => {
      const fn = (_e:any, data:any)=>cb(data);
      ipcRenderer.on(channel, fn);
      return () => ipcRenderer.removeListener(channel, fn);
    },
  },
};

contextBridge.exposeInMainWorld('electron', api);
