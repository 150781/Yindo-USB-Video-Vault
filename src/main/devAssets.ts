// src/main/devAssets.ts
import path from 'path';
import fs from 'fs';
import fsp from 'fs/promises';
import crypto from 'crypto';
import { app } from 'electron';

export type CatalogEntry = {
  id: string;              // ID interne unique
  title: string;
  artist?: string;
  year?: number;
  genre?: string;
  durationMs?: number | null; // optionnel (peut être null en dev)
  source: 'asset' | 'vault';
  src?: string;            // asset://... quand source=asset
  // pour vault, on laisse mediaId=id et pas de src
};

const VIDEO_RX = /\.(mp4|m4v|webm|mov|mkv)$/i;

function assetsMediaDirCandidates(): string[] {
  const appPath = app.getAppPath();
  return [
    path.join(appPath, 'src', 'assets', 'media'),
    path.join(process.cwd(), 'src', 'assets', 'media'),
    path.join(process.resourcesPath || '', 'assets', 'media'),
  ];
}

async function pickAssetsDir(): Promise<string | null> {
  for (const p of assetsMediaDirCandidates()) {
    try { 
      const s = await fsp.stat(p); 
      if (s.isDirectory()) return p; 
    } catch {}
  }
  return null;
}

function hash(s: string) { 
  return crypto.createHash('sha1').update(s).digest('hex'); 
}

function titleFromFile(name: string) {
  return name.replace(VIDEO_RX, '').replace(/[_-]+/g, ' ').trim();
}

export async function scanDevAssets(): Promise<CatalogEntry[]> {
  const root = await pickAssetsDir();
  if (!root) {
    console.log('[assets] Aucun dossier assets/media trouvé. Candidats:', assetsMediaDirCandidates());
    return [];
  }

  console.log('[assets] Scan de:', root);

  async function walk(dir: string): Promise<string[]> {
    const out: string[] = [];
    try {
      const items = await fsp.readdir(dir, { withFileTypes: true });
      for (const it of items) {
        const p = path.join(dir, it.name);
        if (it.isDirectory()) {
          out.push(...await walk(p));
        } else if (VIDEO_RX.test(it.name)) {
          out.push(p);
        }
      }
    } catch (e) {
      console.warn('[assets] Erreur scan dir:', dir, e);
    }
    return out;
  }

  const files = await walk(root);
  console.log('[assets] Fichiers trouvés:', files.length);
  
  const entries: CatalogEntry[] = [];
  for (const abs of files) {
    const rel = abs.substring(root.length + 1).replace(/\\/g, '/');
    const base = path.basename(abs);
    const id = `asset:${hash(rel)}`; // id stable
    
    // sidecar meta optionnel: même nom + .meta.json
    let artist = undefined, year = undefined as any, genre = undefined as any;
    try {
      const metaPath = abs.replace(VIDEO_RX, '.meta.json');
      const meta = JSON.parse(await fsp.readFile(metaPath, 'utf8'));
      artist = meta.artist || artist;
      year = Number(meta.year) || year;
      genre = meta.genre || genre;
      console.log('[assets] Métadonnées trouvées pour', base, ':', meta);
    } catch {}
    
    const entry: CatalogEntry = {
      id,
      title: titleFromFile(base),
      artist,
      year,
      genre,
      durationMs: null,   // on pourra remplir côté renderer (lazy)
      source: 'asset',
      src: `asset://media/${encodeURIComponent(rel)}`,
    };
    
    console.log('[assets] Entrée:', entry);
    entries.push(entry);
  }
  
  console.log('[assets] Total entries:', entries.length);
  return entries;
}
