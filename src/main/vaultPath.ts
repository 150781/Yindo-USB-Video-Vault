import * as electron from 'electron';
const { app } = electron;
import path from 'path';
import fs from 'fs';

let cached: string | null = null;

function hasVaultRoot(p: string) {
  try { return fs.existsSync(path.join(p, '.vault', 'device.tag')); } catch { return false; }
}

export function getVaultRoot(): string {
  if (cached) return cached;

  const cliArg = (process.argv.find(a => a.startsWith('--vault=')) || '').split('=').slice(1).join('=').replace(/^"|"$/g, '');
  const env = (process.env.VAULT_PATH || '').replace(/^"|"$/g, '');

  const candidates = [
    cliArg,
    env,
    path.join(process.cwd(), 'vault'),
    path.join(app.getAppPath(), 'vault'),
    path.join(process.resourcesPath || '', 'vault'),
    path.join(path.dirname(process.execPath), 'vault'),
  ].filter(Boolean) as string[];

  const found = candidates.find(hasVaultRoot);
  if (!found) {
    console.error('[VAULT] introuvable. Candidats testés :\n - ' + candidates.join('\n - '));
    // on retourne quand même un chemin par défaut pour éviter un crash
    cached = path.join(process.cwd(), 'vault');
  } else {
    cached = found;
  }
  console.log('[VAULT_PATH]', cached);
  return cached!;
}

export function ensureVaultReadyOrThrow() {
  const root = getVaultRoot();
  const tag = path.join(root, '.vault', 'device.tag');
  if (!fs.existsSync(root) || !fs.existsSync(tag)) {
    const hint = `VAULT introuvable ou incomplet.\nAttendu: ${root}\\.vault\\device.tag\n` +
      `Astuce: pose le dossier "vault" à côté du .exe portable (ou passe --vault="X:\\mon_vault").\n` +
      `Si c'est une nouvelle clé: exécute "packager init --vault <chemin>" pour créer .vault/device.tag.`;
    const err: any = new Error(hint);
    err.code = 'ENOENT_VAULT';
    throw err;
  }
}
