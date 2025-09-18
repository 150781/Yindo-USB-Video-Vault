// src/main/playerQueue.ts
import { BrowserWindow } from 'electron';
import { QueueItem, QueueState } from '../types/shared.js';
import { createDisplayWindow } from './windows.js';

export class PlayerQueue {
  private state: QueueState = { items: [], currentIndex: -1, repeat: 'off' };
  constructor(
    private getControlWin: () => BrowserWindow | null,
    private getDisplayWin: () => BrowserWindow | null,
  ) {}

  getState() { return this.state; }
  private emitQueueUpdate() {
    const cw = this.getControlWin(); if (cw) cw.webContents.send('queue:update', this.state);
  }

  setRepeat(mode: QueueState['repeat']) { 
    console.log('[PlayerQueue] setRepeat called with mode:', mode);
    console.log('[PlayerQueue] Previous repeat mode:', this.state.repeat);
    this.state.repeat = mode; 
    console.log('[PlayerQueue] New repeat mode:', this.state.repeat);
    this.emitQueueUpdate(); 
  }

  add(item: QueueItem) {
    this.state.items.push(item);
    this.emitQueueUpdate();
    return this.state;
  }
  addMany(items: QueueItem[]) {
    this.state.items.push(...items);
    this.emitQueueUpdate();
    return this.state;
  }
  removeAt(index: number) {
    if (index >= 0 && index < this.state.items.length) {
      const wasCurrent = index === this.state.currentIndex;
      this.state.items.splice(index, 1);
      if (wasCurrent) this.state.currentIndex = -1;
      if (this.state.currentIndex > index) this.state.currentIndex--;
      this.emitQueueUpdate();
    }
    return this.state;
  }
  clear() {
    this.state = { items: [], currentIndex: -1, repeat: 'off' };
    this.emitQueueUpdate();
    return this.state;
  }

  async playAt(index: number) {
    if (index < 0 || index >= this.state.items.length) return false;
    this.state.currentIndex = index;
    this.emitQueueUpdate();
    const it = this.state.items[index];
    
    // Créer la fenêtre d'affichage si elle n'existe pas
    let dw = this.getDisplayWin();
    if (!dw || dw.isDestroyed()) {
      console.log('[PlayerQueue] No valid display window found, creating one...');
      await createDisplayWindow();
      dw = this.getDisplayWin();
    }
    if (!dw || dw.isDestroyed()) {
      console.error('[PlayerQueue] Failed to create display window');
      return false;
    }
    
    console.log('[PlayerQueue] Playing item:', JSON.stringify(it, null, 2));
    
    // Pour les assets, utiliser src; pour vault utiliser mediaId 
    const payload = {
      title: it.title, 
      artist: it.artist,
      id: it.id  // Ajouter l'ID pour les stats
    } as any;
    
    if (it.source === 'asset' && it.src) {
      payload.src = it.src;
    } else if (it.source === 'vault') {
      payload.mediaId = it.id; // Pour vault, mediaId = id de l'item
    } else {
      console.error('[PlayerQueue] Invalid item source or missing src/id:', it);
      return false;
    }
    
    console.log('[PlayerQueue] Sending payload:', JSON.stringify(payload, null, 2));
    
    dw.webContents.send('player:open', payload);
    // auto play
    dw.webContents.send('player:control', { action: 'play' });
    return true;
  }
  async playNow(item: QueueItem) {
    console.log('[PlayerQueue] playNow called with:', JSON.stringify(item, null, 2));
    const index = this.state.items.push(item) - 1;
    this.emitQueueUpdate();
    return this.playAt(index);
  }
  async onEnded() {
    // Appelé quand la vidéo se termine côté Display
    if (this.state.currentIndex < 0 || !this.state.items.length) return false;

    if (this.state.repeat === 'one') {
      // répéter la même piste
      return this.playAt(this.state.currentIndex);
    }

    let i = this.state.currentIndex + 1;
    if (i >= this.state.items.length) {
      if (this.state.repeat === 'all') {
        i = 0; // boucle playlist
      } else {
        // mode off : fin de playlist, on n'avance plus
        this.emitQueueUpdate();
        return false;
      }
    }
    return this.playAt(i);
  }

  async next() {
    if (!this.state.items.length) return false;
    let i = this.state.currentIndex + 1;
    if (i >= this.state.items.length) {
      if (this.state.repeat === 'all') i = 0;
      else return false;
    }
    return this.playAt(i);
  }
  async prev() {
    if (!this.state.items.length) return false;
    let i = this.state.currentIndex - 1;
    if (i < 0) {
      if (this.state.repeat === 'all') i = this.state.items.length - 1;
      else return false;
    }
    return this.playAt(i);
  }
}
