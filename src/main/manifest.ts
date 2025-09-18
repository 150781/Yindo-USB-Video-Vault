import path from 'path';
import fs from 'fs';
import fsp from 'fs/promises';
import crypto from 'crypto';
import nacl from 'tweetnacl';
import { PACKAGER_PUBLIC_KEY_B64 } from '../shared/keys/packagerPublicKey.js';
import { getManifestKey } from './license.js';
import { getVaultRoot } from './vaultPath.js';
import { scanDevAssets, CatalogEntry } from './devAssets.js';

type MediaEntry = { id:string; title:string; artist?:string; durationSec?:number; sha256Enc:string };
type Manifest = { version:number; media: MediaEntry[] };

const MAGIC = Buffer.from([0x4d,0x56,0x4c,0x54]); // 'MVLT'
const SIG_ED25519 = 1;

let manifestCache: Manifest | null = null;

export async function getManifestEntries(): Promise<MediaEntry[]> {
  if (!manifestCache) await loadManifest();
  return manifestCache?.media ?? [];
}

async function loadManifest(){
  const mk = getManifestKey();
  if (!mk) throw new Error('Licence non chargée (manifestKey manquante).');

  const vault = getVaultRoot();
  const bin = await fsp.readFile(path.join(vault,'.vault','manifest.bin'));

  let off=0;
  const magic = bin.subarray(off,off+4); off+=4;
  if (!magic.equals(MAGIC)) throw new Error('MAGIC manifest invalide');
  const ver = bin.readUInt16LE(off); off+=2;
  const kdfId = bin.readUInt16LE(off); off+=2;
  const saltLen = bin.readUInt32LE(off); off+=4;
  const salt = bin.subarray(off,off+saltLen); off+=saltLen;
  const nonceLen = bin.readUInt32LE(off); off+=4;
  const nonce = bin.subarray(off,off+nonceLen); off+=nonceLen;
  const ctLen = bin.readUInt32LE(off); off+=4;
  const ct = bin.subarray(off,off+ctLen); off+=ctLen;
  const tagLen = bin.readUInt32LE(off); off+=4;
  const tag = bin.subarray(off,off+tagLen); off+=tagLen;
  const sigAlgo = bin.readUInt16LE(off); off+=2;
  const sigLen = bin.readUInt32LE(off); off+=4;
  const sig = bin.subarray(off,off+sigLen); off+=sigLen;

  if (sigAlgo !== SIG_ED25519) throw new Error('SIG algo inconnu');
  const body = bin.subarray(4, bin.length - (2+4+sigLen));
  const pub = Buffer.from(PACKAGER_PUBLIC_KEY_B64 || '', 'base64');
  if (pub.length!==32) throw new Error('Clé publique packager manquante');
  const ok = nacl.sign.detached.verify(body, sig, pub);
  if (!ok) throw new Error('Signature manifest invalide');

  // KDF_ID = 0 : clé directe -> mk
  const decipher = crypto.createDecipheriv('aes-256-gcm', mk, nonce);
  decipher.setAuthTag(tag);
  const plain = Buffer.concat([decipher.update(ct), decipher.final()]);
  manifestCache = JSON.parse(plain.toString('utf8'));
}

// Nouvelle fonction pour le catalogue unifié
export async function getCatalogEntries(): Promise<CatalogEntry[]> {
  const fromAssets = await scanDevAssets();      // entries source=asset
  let fromVault: CatalogEntry[] = [];
  
  try {
    const vaultList = await getManifestEntries(); // [{id,title,artist,durationSec,...}]
    fromVault = vaultList.map((v: any) => ({
      id: v.id,
      title: v.title || v.name || v.id,
      artist: v.artist,
      year: v.year,
      genre: v.genre,
      durationMs: v.durationSec ? v.durationSec * 1000 : null,
      source: 'vault' as const,
      // pas de src (Display utilisera mediaId -> vault://)
    }));
    console.log('[catalog] Vault entries:', fromVault.length);
  } catch (e) {
    console.log('[catalog] Pas de vault ou erreur vault:', e instanceof Error ? e.message : e);
  }
  
  // Fusion (assets d'abord pour le dev)
  const combined = [...fromAssets, ...fromVault];
  console.log('[catalog] Catalogue total:', combined.length, 'entries');
  return combined;
}
