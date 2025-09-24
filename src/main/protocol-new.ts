import path from 'path';
import fs from 'fs';
import fsp from 'fs/promises';
import * as electron from 'electron';
const { protocol, app } = electron;
import { Readable } from 'stream';
import crypto from 'crypto';
import mime from 'mime-types';

import { getVaultRoot } from './vaultPath';
import { isLicenseLoaded, unwrapCEK } from './license';

// Convertit un Readable Node en ReadableStream Web (pour Response)
function toWeb(stream: Readable): ReadableStream {
  // @ts-ignore
  return Readable.toWeb(stream);
}

async function exists(p: string) {
  try { await fsp.access(p, fs.constants.R_OK); return true; } catch { return false; }
}

// Déchiffrement streaming AES-256-GCM (fichier .enc = [IV(12)][cipher...][TAG(16)])
function createDecryptStream(encPath: string, key: Buffer) {
  const file = fs.createReadStream(encPath);
  let header: Buffer[] = [];
  let iv: Buffer | null = null;
  let tag: Buffer | null = null;

  // On lit tout le fichier mais on sépare IV et TAG (12/16)
  const pass = new Readable({
    read() { /* push via events */ }
  });

  let decipher: crypto.DecipherGCM | null = null;
  let started = false;
  let total = 0;

  file.on('data', (chunk: string | Buffer) => {
    const buf = chunk instanceof Buffer ? chunk : Buffer.from(chunk);
    total += buf.length;
    header.push(buf);
  });
  file.on('end', () => {
    const buf = Buffer.concat(header);
    if (buf.length < 12 + 16) { pass.emit('error', new Error('enc too small')); return; }
    iv = buf.subarray(0, 12);
    tag = buf.subarray(buf.length - 16);
    const ct = buf.subarray(12, buf.length - 16);

    decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);

    try {
      const dec = Buffer.concat([decipher.update(ct), decipher.final()]);
      pass.push(dec);
      pass.push(null);
    } catch (e) {
      pass.emit('error', e);
    }
  });
  file.on('error', (e) => pass.emit('error', e));
  return pass;
}

// Résolution du chemin et du mime
async function resolveMedia(id: string) {
  const root = getVaultRoot();
  const enc = path.join(root, 'media', `${id}.enc`);
  const plain = path.join(root, 'media', `${id}.mp4`); // fallback dev

  if (await exists(enc)) {
    // essaie de déterminer le mime depuis manifest si tu l'as, sinon mp4
    return { path: enc, kind: 'enc' as const, mime: 'video/mp4' };
  }
  if (await exists(plain)) {
    return { path: plain, kind: 'plain' as const, mime: mime.lookup(plain) || 'video/mp4' };
  }
  return null;
}

export function registerVaultProtocol() {
  protocol.handle('vault', async (req) => {
    try {
      const url = new URL(req.url);
      const host = url.hostname;          // "media"
      const id = url.pathname.replace(/^\/+/, ''); // "<uuid>"

      if (host !== 'media' || !id) {
        console.error('[vault] BAD URL', req.url);
        return new Response('', { status: 400 });
      }

      // Optionnel: bloque si licence non déverrouillée
      if (!isLicenseLoaded()) {
        console.error('[vault] 401 locked, url=', req.url);
        return new Response('', { status: 401 });
      }

      const info = await resolveMedia(id);
      if (!info) {
        console.error('[vault] 404', id);
        return new Response('', { status: 404 });
      }

      console.log('[vault] serve', info.kind, id, '->', info.path);

      if (info.kind === 'plain') {
        const stream = fs.createReadStream(info.path);
        const mimeType = typeof info.mime === 'string' ? info.mime : 'video/mp4';
        return new Response(toWeb(stream), { headers: { 'Content-Type': mimeType } });
      }

      // .enc : récupère la clé de lecture
      let key: Buffer | undefined;
      try {
        key = unwrapCEK(id);
        if (!key || !(key instanceof Buffer) || key.length !== 32) {
          console.error('[vault] 403 invalid key for', id);
          return new Response('', { status: 403 });
        }
      } catch (e) {
        console.error('[vault] 403 no key for', id, e);
        // DEV fallback si pas de clé/licence
        console.log('[vault] trying plain fallback for', id);
        const maybePlain = info.path.replace(/\.enc$/, '.mp4');
        if (await exists(maybePlain)) {
          const stream = fs.createReadStream(maybePlain);
          return new Response(toWeb(stream), { headers: { 'Content-Type': 'video/mp4' } });
        }
        return new Response('', { status: 403 });
      }

      const stream = createDecryptStream(info.path, key);
      const mimeType = typeof info.mime === 'string' ? info.mime : 'video/mp4';
      return new Response(toWeb(stream as unknown as Readable), { headers: { 'Content-Type': mimeType } });
    } catch (e) {
      console.error('[vault] ERR', req.url, e);
      return new Response('', { status: 500 });
    }
  });
}
