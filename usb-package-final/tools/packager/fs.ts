import { promises as fs } from 'fs';
import * as path from 'path';

export async function ensureDir(p: string) {
  await fs.mkdir(p, { recursive: true });
}

export async function writeJsonPretty(p: string, obj: any) {
  const s = JSON.stringify(obj, null, 2);
  await fs.writeFile(p, s, 'utf8');
}

export async function readFileSafe(p: string): Promise<Buffer | null> {
  try { return await fs.readFile(p); } catch { return null; }
}

export async function exists(p: string) {
  try { await fs.access(p); return true; } catch { return false; }
}

export function mediaPath(vaultPath: string, id: string) {
  return path.join(vaultPath, 'media', `${id}.bin`);
}

export function deviceTagPath(vaultPath: string) {
  return path.join(vaultPath, '.vault', 'device.tag');
}

export function manifestBinPath(vaultPath: string) {
  return path.join(vaultPath, '.vault', 'manifest.bin');
}
