import { getDisplayWindow, createDisplayWindow, whenDisplayReady } from './windows.js';
import { authorizeAndCount } from './playbackAuth.js';
import { getManifestEntries } from './manifest.js';

export type RepeatMode = 'off'|'one'|'all';
export type QueueState = { queue: string[]; index: number; currentId?: string; shuffle: boolean; repeat: RepeatMode };

let queue: string[] = [];
let index = -1;
let shuffle = false;
let repeat: RepeatMode = 'off';

function state(): QueueState {
  return { queue: [...queue], index, currentId: queue[index], shuffle, repeat };
}

export async function playAt(i: number) {
  if (i < 0 || i >= queue.length) return state();
  index = i;
  const id = queue[index];

  const auth = await authorizeAndCount(id);
  if (!auth.ok) {
    console.warn('[player] authorizeAndCount NOK:', auth.error);
    return state();
  }

  const dw = await whenDisplayReady(); // 👈 attend l'écran prêt

  // métadonnées (overlay)
  let meta: { title?: string; artist?: string } = {};
  try {
    const list = await getManifestEntries();
    const m = list.find((x: any) => x.id === id);
    meta = { title: m?.title, artist: m?.artist };
  } catch {}

  console.log('[player] opening media on display:', id);
  dw.webContents.send('player:open', { mediaId: id, ...meta });

  // petit coup de "play" pour lever un blocage éventuel
  dw.webContents.send('player:control', { action: 'play' });

  return state();
}

export async function playById(id: string) {
  const i = queue.indexOf(id);
  if (i >= 0) return await playAt(i);
  queue = [id]; index = 0;
  return await playAt(0);
}

export function setQueue(ids: string[], startId?: string) {
  queue = [...ids];
  index = startId ? Math.max(0, queue.indexOf(startId)) : (queue.length ? 0 : -1);
  return state();
}

export function addToQueue(ids: string[]) {
  console.log('[queue] addToQueue appelé avec:', ids);
  console.log('[queue] Queue avant ajout:', queue);
  queue.push(...ids);
  if (index < 0 && queue.length) index = 0;
  console.log('[queue] Queue après ajout:', queue);
  const newState = state();
  console.log('[queue] État retourné:', newState);
  return newState;
}

export function clearQueue() {
  queue = []; index = -1;
  return state();
}

export async function next() {
  if (queue.length === 0) return state();
  if (repeat === 'one') return playAt(index); // rejoue le même
  if (shuffle) {
    let n; do { n = Math.floor(Math.random() * queue.length); } while (queue.length > 1 && n === index);
    index = n;
    return playAt(index);
  }
  if (index + 1 < queue.length) {
    return playAt(++index);
  } else if (repeat === 'all') {
    index = 0;
    return playAt(index);
  } else {
    return state(); // fin
  }
}

export async function prev() {
  if (queue.length === 0) return state();
  if (shuffle) {
    let n; do { n = Math.floor(Math.random() * queue.length); } while (queue.length > 1 && n === index);
    index = n;
    return playAt(index);
  }
  if (index - 1 >= 0) {
    return playAt(--index);
  } else if (repeat === 'all') {
    index = queue.length - 1;
    return playAt(index);
  } else {
    return state();
  }
}

export function setRepeat(mode: RepeatMode) { repeat = mode; return state(); }
export function toggleShuffle() { shuffle = !shuffle; return state(); }

export async function removeAt(i: number) {
  if (i < 0 || i >= queue.length) return state();
  const removingCurrent = (i === index);
  queue.splice(i, 1);

  if (queue.length === 0) {
    index = -1;
    return state();
  }

  if (i < index) {
    index--;                        // l'index recule si on retire avant l'élément courant
    return state();
  }

  if (removingCurrent) {
    // si on supprime l'élément en cours : lire le suivant (ou le précédent si on était en fin)
    if (index >= queue.length) index = queue.length - 1;
    return await playAt(index);     // déclenche l'ouverture du nouveau média courant
  }

  return state();
}

export function removeFromQueue(indexToRemove: number) {
  if (indexToRemove < 0 || indexToRemove >= queue.length) return state();
  
  queue.splice(indexToRemove, 1);
  
  // Ajuster l'index si nécessaire
  if (indexToRemove < index) {
    // L'élément retiré était avant l'élément actuel
    index--;
  } else if (indexToRemove === index) {
    // L'élément retiré était l'élément actuel
    if (index >= queue.length) {
      index = queue.length - 1;
    }
    // Si la queue est vide, reset
    if (queue.length === 0) {
      index = -1;
    }
  }
  // Si indexToRemove > index, pas besoin d'ajuster
  
  return state();
}

export function removeFromQueueById(id: string) {
  const indexToRemove = queue.indexOf(id);
  if (indexToRemove >= 0) {
    return removeFromQueue(indexToRemove);
  }
  return state();
}

export function getQueueState() { return state(); }
