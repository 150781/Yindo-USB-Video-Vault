// src/renderer/utils/assetsCatalog.ts
// Utilitaires: scan des assets + hydrater la durée avec un <video> offscreen

export type SourceKind = 'asset' | 'vault';

export interface MediaEntry {
  id: string;
  title: string;
  artist?: string;
  genre?: string;
  year?: number;
  durationMs?: number | null;
  source: SourceKind;
  src?: string;       // pour assets
  mediaId?: string;   // pour vault, si jamais
}

// Scan des assets via Vite (URL prêtes à l'emploi)
export function scanAssets(): MediaEntry[] {
  // Ajuste l'extension si tu veux en inclure plus/moins
  const files = import.meta.glob(
    ['../assets/**/*.{mp4,webm,ogg,m4v,mkv,mp3,m4a,ogg}'],
    { eager: true, as: 'url' }
  ) as Record<string, string>;

  const items: MediaEntry[] = [];
  for (const [path, url] of Object.entries(files)) {
    const filename = path.split('/').pop() || 'media';
    const meta = parseFromFilename(filename);
    items.push({
      id: 'asset:' + hash(path),
      title: meta.title || filename.replace(/\.[^.]+$/, ''),
      artist: meta.artist,
      genre: meta.genre,
      year: meta.year,
      source: 'asset',
      src: url,
      durationMs: null,
    });
  }
  return items;
}

// Parse des métadonnées depuis le nom de fichier :
// "Artiste - Titre (2022) [Afro]" → { artist, title, year:2022, genre:"Afro" }
function parseFromFilename(name: string) {
  const base = name.replace(/\.[^.]+$/, '');

  const yearMatch = base.match(/\((\d{4})\)/);
  const year = yearMatch ? Number(yearMatch[1]) : undefined;

  const genreMatch = base.match(/\[([^\]]+)\]/);
  const genre = genreMatch ? genreMatch[1].trim() : undefined;

  // retire (YYYY) et [Genre] pour isoler "Artiste - Titre"
  const main = base
    .replace(/\s*\(\d{4}\)\s*/g, ' ')
    .replace(/\s*\[[^\]]+\]\s*/g, ' ')
    .trim();

  let artist: string | undefined;
  let title = main;
  const split = main.split(' - ');
  if (split.length >= 2) {
    artist = split[0].trim();
    title = split.slice(1).join(' - ').trim();
  }
  return { artist, title, year, genre };
}

// Durée via <video preload="metadata"> ; retourne ms ou null
export async function probeDurationMs(url: string): Promise<number | null> {
  return new Promise((resolve) => {
    const v = document.createElement('video');
    v.preload = 'metadata';
    v.src = url;
    v.onloadedmetadata = () => {
      const d = Number.isFinite(v.duration) ? Math.round(v.duration * 1000) : null;
      // libère la ressource
      v.src = '';
      resolve(d);
    };
    v.onerror = () => resolve(null);
  });
}

// Hydrater les durées des assets (séquentiel pour la simplicité/stabilité)
export async function hydrateDurations(entries: MediaEntry[]): Promise<MediaEntry[]> {
  const out: MediaEntry[] = [];
  for (const e of entries) {
    if (e.source === 'asset' && e.src && e.durationMs == null) {
      const d = await probeDurationMs(e.src);
      out.push({ ...e, durationMs: d });
    } else {
      out.push(e);
    }
  }
  return out;
}

// Hash simple et stable pour générer un ID court
function hash(s: string): string {
  // djb2 variation
  let h = 5381;
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) + h) ^ s.charCodeAt(i);
  }
  return (h >>> 0).toString(16);
}
