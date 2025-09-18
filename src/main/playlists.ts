import path from 'path';
import fs from 'fs';
import fsp from 'fs/promises';
import crypto from 'crypto';
import { getVaultRoot } from './vaultPath.js';

let key: Buffer | null = null;
export function setPlaylistsKey(k: Buffer) { key = k; }

export type Playlist = { id: string; name: string; itemIds: string[]; updatedUtc: string };
export type PlaylistStore = { playlists: Playlist[] };

function filePath() { return path.join(getVaultRoot(), '.vault', 'playlists.bin'); }
function ensureKey() { if (!key) throw new Error('playlists key missing'); }

async function load(): Promise<PlaylistStore> {
  try {
    ensureKey();
    const fp = filePath();
    const bin = await fsp.readFile(fp);
    const iv = bin.subarray(0,12);
    const tag = bin.subarray(bin.length-16);
    const ct = bin.subarray(12,bin.length-16);
    const d = crypto.createDecipheriv('aes-256-gcm', key!, iv);
    d.setAuthTag(tag);
    const plain = Buffer.concat([d.update(ct), d.final()]);
    return JSON.parse(plain.toString('utf8'));
  } catch {
    return { playlists: [] };
  }
}
async function save(store: PlaylistStore) {
  ensureKey();
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', key!, iv);
  const ct = Buffer.concat([c.update(JSON.stringify(store),'utf8'), c.final()]);
  const tag = c.getAuthTag();
  await fsp.writeFile(filePath(), Buffer.concat([iv, ct, tag]));
}

export async function listPlaylists() { return await load(); }

export async function savePlaylist(name: string, itemIds: string[]) {
  const st = await load();
  const id = crypto.randomBytes(8).toString('hex');
  const p: Playlist = { id, name, itemIds, updatedUtc: new Date().toISOString() };
  st.playlists = st.playlists.filter(x => x.name !== name).concat([p]);
  await save(st);
  return st;
}
export async function removePlaylist(id: string) {
  const st = await load();
  st.playlists = st.playlists.filter(x => x.id !== id);
  await save(st);
  return st;
}
export async function renamePlaylist(id: string, name: string) {
  const st = await load();
  const p = st.playlists.find(x => x.id === id); if (!p) return st;
  p.name = name; p.updatedUtc = new Date().toISOString();
  await save(st);
  return st;
}
export async function getPlaylistItems(id: string) {
  const st = await load();
  const p = st.playlists.find(x => x.id === id);
  return p?.itemIds || [];
}
