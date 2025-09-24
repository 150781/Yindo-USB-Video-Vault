import path from 'path';
import fs from 'fs';
import fsp from 'fs/promises';
import * as electron from 'electron';
const { protocol } = electron;
import { Readable } from 'stream';
import crypto from 'crypto';
import mime from 'mime-types';
import { getVaultRoot } from './vaultPath';
import { isLicenseLoaded, unwrapCEK } from './licenseSecure'; // Nouveau système
import { getManifestEntries } from './manifest';
import { createDecryptionStream, toWebStream, verifyEncryptedFile } from '../shared/crypto';

function toWeb(stream: Readable): ReadableStream {
  return toWebStream(stream);
}
async function exists(p: string) { try { await fsp.access(p, fs.constants.R_OK); return true; } catch { return false; } }

async function decryptBufferOrStream(encPath: string, key: Buffer): Promise<{ isStream: boolean; data?: Buffer; stream?: Readable }> {
  try {
    // Essayer d'abord de détecter le nouveau format GCM
    const password = process.env.VAULT_PASSWORD || 'default-vault-password'; // TODO: récupérer depuis vault manager

    // Vérification rapide du nouveau format (magic header)
    const fd = await fsp.open(encPath, 'r');
    const magic = Buffer.alloc(4);
    await fd.read(magic, 0, 4, 0);
    await fd.close();

    if (magic.toString() === 'UVV1') {
      console.log('[CRYPTO] Utilisation nouveau format GCM pour streaming');
      const stream = await createDecryptionStream(encPath, password);
      return { isStream: true, stream };
    } else {
      console.log('[CRYPTO] Fallback ancien format CBC');
      const data = decryptBufferLegacy(encPath, key);
      return { isStream: false, data };
    }
  } catch (error) {
    console.log('[CRYPTO] Erreur nouveau format, essai ancien:', error);
    const data = decryptBufferLegacy(encPath, key);
    return { isStream: false, data };
  }
}

function decryptBufferLegacy(encPath: string, key: Buffer): Buffer {
  const bin = fs.readFileSync(encPath);
  if (bin.length < 12 + 16) throw new Error('enc too small');
  const iv = bin.subarray(0, 12);
  const tag = bin.subarray(bin.length - 16);
  const ct = bin.subarray(12, bin.length - 16);
  const d = crypto.createDecipheriv('aes-256-gcm', key, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(ct), d.final()]);
}

async function resolveById(id: string) {
  const root = getVaultRoot();
  const mediaDir = path.join(root, 'media');
  const files = await fsp.readdir(mediaDir).catch(() => []);
  const manifest = await getManifestEntries().catch(() => []);
  const entry = manifest.find((m: any) => m.id === id);

  const bases = new Set<string>([id]);
  if (entry?.sha256Enc) bases.add(entry.sha256Enc);

  const RX = /\.(enc|mp4|m4v|webm|mov|mkv)$/i;
  let encPath: string | null = null;
  let plainPath: string | null = null;

  for (const name of files) {
    if (!RX.test(name)) continue;
    for (const base of bases) {
      if (name.startsWith(base + '.')) {
        if (name.toLowerCase().endsWith('.enc')) encPath = path.join(mediaDir, name);
        else plainPath = path.join(mediaDir, name);
      }
    }
  }

  return encPath
    ? { kind: 'enc' as const, path: encPath, mime: 'video/mp4' }
    : (plainPath ? { kind: 'plain' as const, path: plainPath, mime: mime.lookup(plainPath) || 'video/mp4' } : null);
}

export function setupVaultProtocol() {
  protocol.handle('vault', async (req) => {
    try {
      const url = new URL(req.url);            // vault://media/<id>
      const host = url.hostname;
      const id = url.pathname.replace(/^\/+/, '');

      if (host !== 'media' || !id) {
        console.error('[vault] BAD URL', req.url);
        return new Response('', { status: 400 });
      }
      if (!isLicenseLoaded()) {
        console.error('[vault] 401 licence verrouillée pour', id);
        return new Response('', { status: 401 });
      }

      console.log('[vault] resolve id =', id);
      const info = await resolveById(id);
      if (!info) {
        // logs de debug utiles
        const root = getVaultRoot();
        console.error('[vault] 404 introuvable pour id =', id, 'media dir =', path.join(root, 'media'));
        return new Response('', { status: 404 });
      }

      console.log('[vault] serve', info.kind, '→', info.path);

      if (info.kind === 'plain') {
        const s = fs.createReadStream(info.path);
        return new Response(toWeb(s), { headers: { 'Content-Type': info.mime } });
      }

      const key = unwrapCEK(id);
      if (!key || key.length !== 32) {
        console.error('[vault] 403 pas de clé pour', id);
        return new Response('', { status: 403 });
      }

      // Utiliser la nouvelle crypto GCM avec streaming
      const result = await decryptBufferOrStream(info.path, key);

      if (result.isStream && result.stream) {
        console.log('[CRYPTO] Streaming GCM pour', id);
        return new Response(toWeb(result.stream), {
          headers: { 'Content-Type': info.mime }
        });
      } else if (result.data) {
        console.log('[CRYPTO] Buffer legacy pour', id);
        return new Response(new Uint8Array(result.data), {
          headers: { 'Content-Type': info.mime }
        });
      } else {
        throw new Error('Aucune donnée retournée par le déchiffreur');
      }
    } catch (e) {
      console.error('[vault] ERR', req.url, e);
      return new Response('', { status: 500 });
    }
  });
}
