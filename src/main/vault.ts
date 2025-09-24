import { promises as fs } from 'fs';
import * as path from 'path';
import * as os from 'os';
import * as electron from 'electron';
const { app } = electron;
import { createReadStream, createWriteStream } from 'fs';
import { createDecipheriv, scryptSync, randomBytes, createCipheriv } from 'crypto';
import {
  encryptMediaFile,
  createDecryptionStream,
  deriveKey,
  readEncryptionHeader,
  verifyEncryptedFile,
  MAGIC_HEADER,
  VERSION
} from '../shared/crypto';

type SourceKind = 'asset' | 'vault';

export interface DeviceTag {
  version: 1;
  deviceId: string;
  saltHex: string;
  createdAt: string;
  tool: string;
}

export interface MediaMeta {
  id: string;               // "vault:<hash12>"
  title: string;
  artist?: string;
  genre?: string;
  year?: number;
  durationMs?: number | null;
  source: SourceKind;       // "vault"
  sha256: string;
  ext?: string;             // ex: "mp4"
}

export interface ManifestJson {
  version: 1;
  createdAt: string;
  items: MediaMeta[];
}

export class VaultManager {
  private vaultPath!: string;
  private tag!: DeviceTag;
  private key?: Buffer; // dérivée via scrypt
  private manifest?: ManifestJson;
  private byId = new Map<string, MediaMeta>();
  private tempDir!: string; // .../tmp/vault-<deviceId>
  private password?: string; // Stocké pour le streaming

  async init(vaultPath: string) {
    this.vaultPath = path.resolve(vaultPath);
    const tagPath = path.join(this.vaultPath, '.vault', 'device.tag');
    const raw = await fs.readFile(tagPath, 'utf8');
    this.tag = JSON.parse(raw) as DeviceTag;

    this.tempDir = path.join(os.tmpdir(), `vault-${this.tag.deviceId}`);
    await fs.mkdir(this.tempDir, { recursive: true });
  }

  async unlock(passphrase: string) {
    if (!this.tag) throw new Error('Vault non initialisé');
    const salt = Buffer.from(this.tag.saltHex, 'hex');
    this.key = await deriveKey(passphrase, salt);
    this.password = passphrase; // Garder pour streaming
    console.log('[CRYPTO] Vault déverrouillé avec nouvelle crypto GCM');
  }

  async loadManifest() {
    if (!this.key) throw new Error('Vault verrouillé (clé absente). Appelle vault:unlock d\'abord.');
    const manPath = path.join(this.vaultPath, '.vault', 'manifest.bin');

    try {
      // Essayer nouveau format GCM d'abord
      if (!this.password) throw new Error('Password requis pour nouveau format');
      const decryptedStream = await createDecryptionStream(manPath, this.password);

      const chunks: Buffer[] = [];
      for await (const chunk of decryptedStream) {
        chunks.push(chunk);
      }
      const plain = Buffer.concat(chunks);

      this.manifest = JSON.parse(plain.toString()) as ManifestJson;
      console.log('[CRYPTO] Manifest chargé avec nouveau format GCM');
    } catch (gcmError) {
      console.log('[CRYPTO] Tentative format GCM échoué, essai ancien format CBC...');

      // Fallback ancien format CBC
      const enc = await fs.readFile(manPath);
      if (enc.length < 12 + 16) throw new Error('manifest.bin corrompu');

      const iv = enc.subarray(0, 12);
      const tag = enc.subarray(enc.length - 16);
      const data = enc.subarray(12, enc.length - 16);

      const decipher = createDecipheriv('aes-256-gcm', this.key!, iv);
      decipher.setAuthTag(tag);
      const plain = Buffer.concat([decipher.update(data), decipher.final()]);

      this.manifest = JSON.parse(plain.toString()) as ManifestJson;
      console.log('[CRYPTO] Manifest chargé avec ancien format CBC (compatibility)');
    }

    this.byId.clear();
    for (const m of this.manifest.items) this.byId.set(m.id, m);
  }

  isUnlocked() { return !!this.key; }

  getCatalog(): MediaMeta[] {
    if (!this.manifest) return [];
    return this.manifest.items;
  }

  getMimeById(id: string): string {
    const ext = (this.byId.get(id)?.ext || '').toLowerCase();
    switch (ext) {
      case 'mp4': case 'm4v': return 'video/mp4';
      case 'webm': return 'video/webm';
      case 'ogg': return 'video/ogg';
      case 'mp3': return 'audio/mpeg';
      case 'm4a': return 'audio/mp4';
      default: return 'application/octet-stream';
    }
  }

  /** Crée un stream de déchiffrement pour un média (nouvelle méthode streaming) */
  async createDecryptionStreamForMedia(id: string): Promise<NodeJS.ReadableStream> {
    if (!this.password) throw new Error('Vault verrouillé - password requis pour streaming');

    const meta = this.byId.get(id);
    if (!meta) throw new Error(`Media inconnu: ${id}`);

    const inPath = path.join(this.vaultPath, 'media', `${id}.enc`);

    try {
      // Vérifier que le fichier utilise le nouveau format
      await readEncryptionHeader(inPath);
      return await createDecryptionStream(inPath, this.password);
    } catch (newFormatError) {
      console.log('[CRYPTO] Fallback ancien format pour', id);
      return this.createLegacyDecryptionStream(inPath);
    }
  }

  /** Fallback pour ancien format (méthode privée) */
  private async createLegacyDecryptionStream(inPath: string): Promise<NodeJS.ReadableStream> {
    if (!this.key) throw new Error('Vault verrouillé');

    const stat = await fs.stat(inPath);
    if (stat.size < 12 + 16) throw new Error('Fichier chiffré invalide');

    // Lire IV (12) et TAG (16)
    const fd = await fs.open(inPath, 'r');
    const iv = Buffer.alloc(12);
    await fd.read(iv, 0, 12, 0);
    const tag = Buffer.alloc(16);
    await fd.read(tag, 0, 16, stat.size - 16);
    await fd.close();

    const decipher = createDecipheriv('aes-256-gcm', this.key!, iv);
    decipher.setAuthTag(tag);

    // Flux chiffré = tranche [12, size-16)
    const rs = createReadStream(inPath, { start: 12, end: stat.size - 1 - 16 });
    return rs.pipe(decipher);
  }

  /** Déchiffre media/<id>.bin vers un fichier temp (id.ext) et renvoie son chemin */
  async ensureDecryptedFile(id: string): Promise<string> {
    if (!this.key) throw new Error('Vault verrouillé');

    const meta = this.byId.get(id);
    if (!meta) throw new Error(`Media inconnu: ${id}`);

    const ext = meta.ext ? `.${meta.ext}` : '';
    const outPath = path.join(this.tempDir, `${id}${ext}`);

    // Si déjà présent, on réutilise (évite de re-décrypter à chaque lecture)
    try {
      await fs.access(outPath);
      return outPath;
    } catch { }

    // Essayer nouveau format en premier
    const inPath = path.join(this.vaultPath, 'media', `${id}.enc`);

    try {
      if (!this.password) throw new Error('Password requis pour nouveau format');

      // Utiliser le streaming pour économiser la mémoire
      const decryptStream = await createDecryptionStream(inPath, this.password);
      const writeStream = createWriteStream(outPath);

      await new Promise<void>((resolve, reject) => {
        decryptStream.pipe(writeStream)
          .on('finish', resolve)
          .on('error', reject);
      });

      console.log('[CRYPTO] Fichier déchiffré avec nouveau format GCM:', outPath);
      return outPath;
    } catch (newFormatError) {
      console.log('[CRYPTO] Essai ancien format CBC pour', id);

      // Fallback ancien format
      const stat = await fs.stat(inPath);
      if (stat.size < 12 + 16) throw new Error('Fichier chiffré invalide');

      // Lire IV (12) et TAG (16)
      const fd = await fs.open(inPath, 'r');
      try {
        const iv = Buffer.alloc(12);
        await fd.read(iv, 0, 12, 0);
        const tag = Buffer.alloc(16);
        await fd.read(tag, 0, 16, stat.size - 16);

        const decipher = createDecipheriv('aes-256-gcm', this.key!, iv);
        decipher.setAuthTag(tag);

        // Flux chiffré = tranche [12, size-16)
        const rs = createReadStream(inPath, { start: 12, end: stat.size - 1 - 16 });
        const ws = createWriteStream(outPath);

        await new Promise<void>((resolve, reject) => {
          rs.pipe(decipher).pipe(ws)
            .on('finish', resolve)
            .on('error', reject);
        });

        return outPath;
      } finally {
        await fd.close();
      }
    }
  }

  async cleanupTemp() {
    try {
      await fs.rm(this.tempDir, { recursive: true, force: true });
    } catch { }
  }

  async purgeCache() {
    // supprime et recrée le dossier temp
    await this.cleanupTemp();
    const fs = await import('fs/promises');
    await fs.mkdir(this.tempDir, { recursive: true });
  }

  lock() {
    // oublie la clé et le manifest en mémoire
    this.key = undefined;
    this.password = undefined;
    this.manifest = undefined;
    this.byId.clear();
  }

  /** Nouvelle méthode pour chiffrer un fichier média avec le format GCM */
  async encryptMediaToVault(inputPath: string, mediaId: string, password: string): Promise<void> {
    const outputPath = path.join(this.vaultPath, 'media', `${mediaId}.enc`);
    await encryptMediaFile(inputPath, outputPath, { password });
    console.log('[CRYPTO] Média chiffré vers', outputPath);
  }

  /** Vérifier l'intégrité d'un média chiffré */
  async verifyMediaIntegrity(mediaId: string): Promise<boolean> {
    if (!this.password) return false;

    const encPath = path.join(this.vaultPath, 'media', `${mediaId}.enc`);
    try {
      return await verifyEncryptedFile(encPath, this.password);
    } catch {
      return false;
    }
  }
}

// Helpers de résolution du chemin vault (argument --vault=, env VAULT_PATH, à côté de l'exe)
export function resolveVaultPath(): string {
  const fromArg = process.argv.find(a => a.startsWith('--vault='));
  if (fromArg) return fromArg.split('=')[1];

  if (process.env.VAULT_PATH) return process.env.VAULT_PATH;

  // par défaut : dossier "vault" à côté de l'exécutable
  const exeDir = path.dirname(process.execPath);
  return path.join(exeDir, 'vault');
}
