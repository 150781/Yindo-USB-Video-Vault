// src/main/license.ts
import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import crypto from 'crypto';
import nacl from 'tweetnacl';
import { getVaultRoot } from './vaultPath.js';
import { getDeviceIds } from '../shared/device.js';
import { PACKAGER_PUBLIC_KEY_B64 } from '../shared/keys/packagerPublicKey.js';

type LicBody = {
  version: 1;
  owner?: string;
  device: string;          // attendu: SHA-256 hex du device
  notBefore?: string;      // ISO
  expiry?: string;         // ISO
  allow?: string[];        // optionnel
};

let UNLOCKED = false;

function licPaths() {
  const root = getVaultRoot();
  const dir = path.join(root, '.vault');
  return {
    dir,
    json: path.join(dir, 'license.json'),
    sig:  path.join(dir, 'license.sig'),
  };
}

export async function readLicense(): Promise<{ body?: LicBody; sig?: Buffer }> {
  const p = licPaths();
  const [jb, sb] = await Promise.all([
    fsp.readFile(p.json).catch(()=>null),
    fsp.readFile(p.sig).catch(()=>null),
  ]);
  const body = jb ? JSON.parse(jb.toString('utf8')) as LicBody : undefined;
  const sig  = sb ? Buffer.from(sb.toString('utf8').trim(), 'base64') : undefined;
  return { body, sig };
}

export function verifyLicense(body: LicBody, sig: Buffer) {
  // Vérifier signature Ed25519 sur les BYTES exacts de license.json
  const pub = Buffer.from(PACKAGER_PUBLIC_KEY_B64, 'base64');
  const bodyBytes = Buffer.from(JSON.stringify(body), 'utf8'); // JSON tel quel stocké
  const sigOK = nacl.sign.detached.verify(bodyBytes, sig, pub);

  console.log('[LIC] Verification licence...');
  console.log('[LIC] Signature valide:', sigOK);

  const now = Date.now();
  const nbOK = !body.notBefore || now >= Date.parse(body.notBefore);
  const expOK = !body.expiry || now <= Date.parse(body.expiry);

  if (body.expiry) {
    const expiryDate = new Date(body.expiry);
    const nowDate = new Date(now);
    console.log('[LIC] Expiration:', expiryDate.toLocaleDateString());
    console.log('[LIC] Maintenant:', nowDate.toLocaleDateString());
    console.log('[LIC] Licence expiree:', nowDate > expiryDate);
  }

  const dev = getDeviceIds();
  const devOK = !body.device || body.device === dev.hash;

  if (body.device) {
    console.log('[LIC] Device binding requis:', body.device);
    console.log('[LIC] Device actuel:', dev.hash);
    console.log('[LIC] Device match:', body.device === dev.hash);
  }

  return { sigOK, nbOK, expOK, devOK, device: dev, pubFp: crypto.createHash('sha256').update(pub).digest('hex').slice(0,16) };
}

export async function unlockLicense(): Promise<boolean> {
  try {
    const { body, sig } = await readLicense();
    if (!body || !sig) { UNLOCKED = false; return false; }
    const v = verifyLicense(body, sig);
    const ok = v.sigOK && v.nbOK && v.expOK && v.devOK;
    UNLOCKED = ok;
    console.log('[LIC]', { ok, sigOK: v.sigOK, nbOK: v.nbOK, expOK: v.expOK, devOK: v.devOK, pubFp: v.pubFp, device: v.device.hash, claim: body.device });
    return ok;
  } catch (e) {
    console.error('[LIC] unlock error', e);
    UNLOCKED = false;
    return false;
  }
}

export async function enterPassphrase(passphrase: string): Promise<{ ok: boolean; error?: string }> {
  try {
    const p = licPaths();
    const binPath = path.join(p.dir, 'license.bin');
    
    // Check if license.bin exists (new encrypted format)
    if (fs.existsSync(binPath)) {
      return await unlockWithEncryptedLicense(binPath, passphrase);
    }
    
    // Fallback to old license.json/sig format
    const hasOldFormat = fs.existsSync(p.json) && fs.existsSync(p.sig);
    if (hasOldFormat) {
      const success = await unlockLicense();
      return { ok: success, error: success ? undefined : 'Licence invalide ou expirée' };
    }
    
    return { ok: false, error: 'Aucune licence trouvée' };
  } catch (e: any) {
    console.error('[LIC] enterPassphrase error', e);
    return { ok: false, error: e?.message || 'Erreur de déchiffrement' };
  }
}

async function unlockWithEncryptedLicense(binPath: string, passphrase: string): Promise<{ ok: boolean; error?: string }> {
  try {
    const data = await fsp.readFile(binPath);
    
    // Parse binary format (from pack.js)
    const MAGIC_LICENSE = Buffer.from([0x4C, 0x49, 0x43, 0x45]); // "LICE"
    const VERSION = 1;
    const SIG_ED25519 = 0x01;
    
    if (data.length < 4 || !data.subarray(0, 4).equals(MAGIC_LICENSE)) {
      return { ok: false, error: 'Format de licence invalide' };
    }
    
    let offset = 4;
    const version = data[offset++];
    if (version !== VERSION) {
      return { ok: false, error: 'Version de licence non supportée' };
    }
    
    // Read nonce
    const nonceLen = data.readUInt32LE(offset); offset += 4;
    const nonce = data.subarray(offset, offset + nonceLen); offset += nonceLen;
    
    // Read ciphertext
    const ciphertextLen = data.readUInt32LE(offset); offset += 4;
    const ciphertext = data.subarray(offset, offset + ciphertextLen); offset += ciphertextLen;
    
    // Read auth tag
    const tagLen = data.readUInt32LE(offset); offset += 4;
    const tag = data.subarray(offset, offset + tagLen); offset += tagLen;
    
    // Derive decryption key from passphrase
    const dev = getDeviceIds();
    const machineId = Buffer.from(dev.original, 'utf8');
    const deviceTag = await fsp.readFile(path.join(licPaths().dir, 'device.tag'));
    
    // masterKey = scrypt(passphrase, salt = machineId)
    const masterKey = crypto.scryptSync(passphrase, machineId, 32, {N:1<<15,r:8,p:1,maxmem:256*1024*1024});
    
    // derive license decryption key
    const encLicKey = hkdf(masterKey, deviceTag, 'license-json');
    
    // Decrypt
    const decipher = crypto.createDecipheriv('aes-256-gcm', encLicKey, nonce);
    decipher.setAuthTag(tag);
    
    let plaintext;
    try {
      plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    } catch (e) {
      return { ok: false, error: 'Mot de passe incorrect' };
    }
    
    const payload = JSON.parse(plaintext.toString('utf8'));
    
    // Verify device match
    if (payload.machineHash !== dev.hash) {
      return { ok: false, error: 'Licence non autorisée pour cette machine' };
    }
    
    // Check expiry
    if (payload.expiryUtc && new Date() > new Date(payload.expiryUtc)) {
      return { ok: false, error: 'Licence expirée' };
    }
    
    // Check validity period
    if (payload.rules?.validFrom && new Date() < new Date(payload.rules.validFrom)) {
      return { ok: false, error: 'Licence pas encore valide' };
    }
    if (payload.rules?.validUntil && new Date() > new Date(payload.rules.validUntil)) {
      return { ok: false, error: 'Licence expirée' };
    }
    
    // Store decrypted license data globally for other functions
    (global as any).licensePayload = payload;
    UNLOCKED = true;
    
    console.log('[LIC] Successfully unlocked with passphrase for owner:', payload.owner);
    return { ok: true };
    
  } catch (e: any) {
    console.error('[LIC] unlockWithEncryptedLicense error', e);
    return { ok: false, error: e?.message || 'Erreur de déchiffrement' };
  }
}

// HKDF helper function (from pack.js)
function hkdf(ikm: Buffer, salt: Buffer, info: string) {
  const prk = crypto.createHmac('sha256', salt).update(ikm).digest();
  const okm = crypto.createHmac('sha256', prk).update(Buffer.from(info, 'utf8')).update(Buffer.from([0x01])).digest();
  return okm;
}

export function isLicenseUnlocked() { return UNLOCKED; }

export function lockLicense() {
  UNLOCKED = false;
  console.log('[LIC] Licence verrouillée');
}

export async function licenseStatus() {
  const p = licPaths();
  const binPath = path.join(p.dir, 'license.bin');
  
  let existsJson = false, existsSig = false, existsBin = false, body: LicBody|undefined, sig: Buffer|undefined, err='';
  try {
    existsJson = fs.existsSync(p.json);
    existsSig = fs.existsSync(p.sig);
    existsBin = fs.existsSync(binPath);
    
    if (!existsBin) {
      const r = await readLicense();
      body = r.body; sig = r.sig;
    }
  } catch(e:any) { err = e?.message || String(e); }

  const pubFp = (()=> {
    try { return crypto.createHash('sha256').update(Buffer.from(PACKAGER_PUBLIC_KEY_B64,'base64')).digest('hex').slice(0,16); } catch { return 'n/a'; }
  })();

  let ver:any = {};
  if (body && sig && !existsBin) {
    const v = verifyLicense(body, sig);
    ver = { sigOK: v.sigOK, notBeforeOK: v.nbOK, expiryOK: v.expOK, deviceOK: v.devOK, pubFp: v.pubFp, appDevice: v.device };
  }

  return {
    vaultRoot: getVaultRoot(),
    files: { 
      json: p.json, 
      sig: p.sig, 
      existsJson, 
      existsSig, 
      exists: existsBin || (existsJson && existsSig)
    },
    pubFp,
    body: body || null,
    verify: Object.keys(ver).length ? ver : null,
    unlocked: UNLOCKED,
    error: err || null,
  };
}

export async function saveLicense(bodyJson: string, sigB64: string) {
  const p = licPaths();
  await fsp.mkdir(p.dir, { recursive: true });
  // valider JSON
  const obj = JSON.parse(bodyJson) as LicBody;
  if (!obj || obj.version !== 1 || !obj.device) throw new Error('license.json invalide');
  // valider base64
  const sig = Buffer.from(sigB64.trim(), 'base64');
  if (sig.length !== 64) throw new Error('license.sig invalide (ed25519 signature attendue)');
  // écrire
  await fsp.writeFile(p.json, JSON.stringify(obj), 'utf8');
  await fsp.writeFile(p.sig, sigB64.trim(), 'utf8');
  // tenter unlock
  return await unlockLicense();
}

// ===== FONCTIONS DE COMPATIBILITÉ =====
// Pour compatibilité avec les anciens modules

export function isLicenseLoaded() { 
  return isLicenseUnlocked(); 
}

export function getLicenseStatus() {
  // Version synchrone pour compatibilité avec playbackAuth
  return { 
    ok: UNLOCKED, 
    error: UNLOCKED ? null : 'Licence non déverrouillée',
    info: UNLOCKED ? {
      owner: 'User', // À améliorer si on a accès aux données de licence en mémoire
      expiryUtc: '2027-12-31T00:00:00.000Z', // À améliorer
      validFrom: null,
      validUntil: '2027-12-31T00:00:00.000Z'
    } : undefined
  };
}

export function getRules() {
  // Pour compatibilité avec playbackAuth - retourner des règles par défaut étendues
  return { 
    maxPlaysGlobal: Infinity, 
    maxPlaysPerMedia: Infinity,
    validFrom: null,
    validUntil: null
  };
}

export function getManifestKey() {
  // Pour compatibilité avec manifest - retourner une clé par défaut si déverrouillé
  if (!UNLOCKED) throw new Error('Licence non déverrouillée');
  // Retourner une clé fixe pour le moment (à améliorer selon vos besoins)
  return Buffer.alloc(32, 'manifest-key');
}

export function unwrapCEK(mediaId: string) {
  // Pour compatibilité avec protocol - retourner une CEK par défaut si déverrouillé
  if (!UNLOCKED) throw new Error('Licence non déverrouillée');
  // Générer une clé basée sur l'ID du média (à améliorer selon vos besoins)
  return crypto.createHash('sha256').update('cek-' + mediaId).digest();
}
