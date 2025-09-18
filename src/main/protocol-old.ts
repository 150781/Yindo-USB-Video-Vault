import { app, protocol } from 'electron';
import * as fs from 'fs';
import * as fsp from 'fs/promises';
import * as path from 'path';
import * as stream from 'stream';
import crypto from 'crypto';
import { unwrapCEK } from './license.js';
import { getVaultRoot, ensureVaultReadyOrThrow } from './vaultPath.js';

// Plaintext size = fileSize - 12 (IV) - 16 (TAG)
function plaintextSize(fileSize: number) { return Math.max(fileSize - 28, 0); }

function parseRange(rangeHeader: string | undefined, totalSize: number) {
  if (!rangeHeader) return null;
  const m = /bytes=(\d*)-(\d*)/.exec(rangeHeader);
  if (!m) return null;
  let start = m[1] ? parseInt(m[1], 10) : 0;
  let end = m[2] ? parseInt(m[2], 10) : (totalSize ? totalSize - 1 : 0);

  // suffix "bytes=-N"
  if (m[1] === '' && m[2] !== '') {
    const suffix = parseInt(m[2], 10);
    start = Math.max(totalSize - suffix, 0);
    end = totalSize - 1;
  }
  if (start < 0) start = 0;
  if (end >= totalSize) end = totalSize - 1;
  if (start > end) return { invalid: true } as const;
  return { start, end } as const;
}

/**
 * Transform qui lit un fichier .enc au format:
 * [IV(12)][CIPHERTEXT...][TAG(16)]
 * et pousse le FLUX PLAINTEXT.
 *
 * On bufferise les derniers 16 octets (TAG), qu'on passe à setAuthTag() en _flush().
 */
class DecryptEncTransform extends stream.Transform {
  private stage: 'iv'|'ct' = 'iv';
  private ivBuf = Buffer.alloc(0);
  private pending = Buffer.alloc(0); // buffer CT en conservant 16 octets de fin
  private decipher: crypto.DecipherGCM | null = null;
  private readonly cek: Buffer;

  constructor(cek: Buffer) {
    super();
    this.cek = cek;
  }

  _transform(chunk: Buffer, _enc: BufferEncoding, cb: stream.TransformCallback) {
    try {
      let buf = chunk;

      // Lire IV (12 octets)
      if (this.stage === 'iv') {
        const need = 12 - this.ivBuf.length;
        if (buf.length >= need) {
          this.ivBuf = Buffer.concat([this.ivBuf, buf.subarray(0, need)]);
          buf = buf.subarray(need);
          this.decipher = crypto.createDecipheriv('aes-256-gcm', this.cek, this.ivBuf);
          this.stage = 'ct';
        } else {
          this.ivBuf = Buffer.concat([this.ivBuf, buf]);
          return cb();
        }
      }

      // Bufferiser CT en conservant 16 octets finaux (TAG)
      if (buf.length > 0) {
        this.pending = Buffer.concat([this.pending, buf]);
        if (this.pending.length > 16) {
          const toDec = this.pending.subarray(0, this.pending.length - 16);
          this.pending = this.pending.subarray(this.pending.length - 16);
          const out = this.decipher!.update(toDec);
          if (out.length) this.push(out);
        }
      }

      cb();
    } catch (e) {
      cb(e as Error);
    }
  }

  _flush(cb: stream.TransformCallback) {
    try {
      // Il doit rester exactement le TAG (16o)
      const tag = this.pending;
      if (tag.length !== 16) {
        return cb(new Error('Fichier .enc invalide (TAG manquant)'));
      }
      this.decipher!.setAuthTag(tag);
      const final = this.decipher!.final();
      if (final.length) this.push(final);
      cb();
    } catch (e) {
      cb(e as Error);
    }
  }
}

/**
 * Transform qui applique un Range sur le plaintext.
 * (V1: on déchiffre depuis 0 puis on tronque; simple et suffisant pour la lecture/seek HTML5)
 */
class SliceRangeTransform extends stream.Transform {
  private readonly start: number;
  private readonly length: number;
  private skipped = 0;
  private sent = 0;

  constructor(start: number, end: number) {
    super();
    this.start = start;
    this.length = end - start + 1;
  }

  _transform(chunk: Buffer, _enc: BufferEncoding, cb: stream.TransformCallback) {
    try {
      if (this.sent >= this.length) return cb(); // ignore surplus
      let buf = chunk;

      // sauter le début
      if (this.skipped < this.start) {
        const need = this.start - this.skipped;
        if (buf.length <= need) {
          this.skipped += buf.length;
          return cb();
        } else {
          buf = buf.subarray(need);
          this.skipped += need;
        }
      }

      // envoyer jusqu'à length
      const remain = this.length - this.sent;
      if (buf.length > remain) {
        this.push(buf.subarray(0, remain));
        this.sent += remain;
      } else {
        this.push(buf);
        this.sent += buf.length;
      }
      cb();
    } catch (e) {
      cb(e as Error);
    }
  }
}

export function registerVaultProtocol() {
  app.whenReady().then(() => {
    protocol.registerStreamProtocol('vault', async (request, callback) => {
      try {
        ensureVaultReadyOrThrow();
        const vaultRoot = getVaultRoot();
        const url = new URL(request.url);
        console.log('[vault] URL =', url.href);

        // ROUTES:
        // vault://media/<id>  -> lit <VAULT>/media/<id>.enc déchiffré (mp4)
        // (on garde vault://demo ailleurs si tu l'utilises encore)
        if (url.hostname !== 'media') {
          console.warn('[vault] 404 hostname != media:', url.hostname);
          callback({ statusCode: 404, headers: { 'Content-Type': 'text/plain' }, data: Buffer.from('Not Found') });
          return;
        }

        const mediaId = url.pathname.replace(/^\//, '');
        console.log('[vault] mediaId =', mediaId);

        if (!mediaId) {
          callback({ statusCode: 400, headers: { 'Content-Type': 'text/plain' }, data: Buffer.from('Bad Request') });
          return;
        }

        // Vérifier licence + récupérer CEK
        const cek = unwrapCEK(mediaId);
        if (!cek) {
          console.warn('[vault] 403 — CEK introuvable (licence ? id ?):', mediaId);
          callback({ statusCode: 403, headers: { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' }, data: Buffer.from('Forbidden (licence / CEK)') });
          return;
        }

        const filePath = path.join(vaultRoot, 'media', `${mediaId}.enc`);
        console.log('[vault] filePath =', filePath);
        const stat = await fsp.stat(filePath).catch(() => null);
        if (!stat || !stat.isFile()) {
          console.warn('[vault] 404 Media not found:', filePath);
          callback({ statusCode: 404, headers: { 'Content-Type': 'text/plain' }, data: Buffer.from('Media not found') });
          return;
        }

        const totalPlain = plaintextSize(stat.size);
        console.log('[vault] Serving media:', mediaId, 'totalPlain:', totalPlain);
        const headersIn: any = request.headers || {};
        const rangeH = (headersIn.Range as string) || (headersIn.range as string) || undefined;
        const range = parseRange(rangeH, totalPlain);

        const fileStream = fs.createReadStream(filePath);
        const dec = new DecryptEncTransform(cek);

        let out: stream.Readable = stream.pipeline(fileStream, dec, (err) => {
          // Ignorer les erreurs PREMATURE_CLOSE (client ferme la connexion)
          if (err && err.code !== 'ERR_STREAM_PREMATURE_CLOSE') {
            console.error('[vault] pipeline error', err);
          }
        }) as unknown as stream.Readable;

        let statusCode = 200;
        const headers: Record<string, string> = {
          'Content-Type': 'video/mp4',
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'no-store',
        };

        if (range && !(range as any).invalid) {
          statusCode = 206;
          const { start, end } = range as { start: number; end: number };
          headers['Content-Range'] = `bytes ${start}-${end}/${totalPlain}`;
          headers['Content-Length'] = String(end - start + 1);
          const slicer = new SliceRangeTransform(start, end);
          out = stream.pipeline(out as any, slicer, (err) => {
            // Ignorer les erreurs PREMATURE_CLOSE (client ferme la connexion)
            if (err && err.code !== 'ERR_STREAM_PREMATURE_CLOSE') {
              console.error('[vault] slice error', err);
            }
          }) as unknown as stream.Readable;
        } else {
          headers['Content-Length'] = String(totalPlain);
        }

        callback({ statusCode, headers, data: out });
      } catch (e:any) {
        console.error('[vault] ERR', request.url, e);
        if (e?.code === 'ENOENT_VAULT') {
          callback({ statusCode: 500, headers:{'Content-Type':'text/plain'}, data: Buffer.from(e.message) });
        } else {
          callback({ statusCode: 500, headers:{'Content-Type':'text/plain'}, data: Buffer.from('Internal Error') });
        }
      }
    });
  });
}
