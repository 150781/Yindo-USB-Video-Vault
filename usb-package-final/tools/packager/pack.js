// tools/packager/pack.js
import { Command } from 'commander';
import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import crypto from 'crypto';
import * as fse from 'fs-extra';
import nacl from 'tweetnacl';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// --- Helpers pour extraction métadonnées ---
function ffprobeMeta(file) {
  try {
    const cmd = `ffprobe -v error -show_entries format=duration:format_tags=title,artist,album,date,year,genre,creation_time -of json "${file}"`;
    const out = execSync(cmd, { stdio: ['ignore','pipe','ignore'] });
    const json = JSON.parse(out.toString('utf8'));
    const fmt = json.format || {};
    const tags = fmt.tags || {};
    const durationSec = fmt.duration ? Math.round(Number(fmt.duration)) : undefined;
    const year = parseYearFromTags(tags);
    const genre = parseGenreFromTags(tags);
    return { durationSec, year, genre, tags };
  } catch {
    return { durationSec: undefined, year: undefined, genre: undefined, tags: {} };
  }
}

function parseYearFromTags(tags = {}) {
  const raw = tags.year || tags.date || tags.creation_time || '';
  const m = /(\d{4})/.exec(String(raw));
  return m ? Number(m[1]) : undefined;
}

function parseGenreFromTags(tags = {}) {
  const g = (tags.genre || '').toString().trim();
  return g || undefined;
}

// Fallback très simple : chercher un [Genre] ou (Genre) dans le nom du fichier
function parseGenreFromFilename(fp) {
  const base = path.basename(fp, path.extname(fp));
  let candidate;
  for (const m of base.matchAll(/[\[(]([A-Za-z][\w +/&-]{2,})[\])]/g)) {
    candidate = m[1].trim();
  }
  // Filtrer quelques faux positifs fréquents
  if (candidate && /^(1080p|720p|4k|x264|x265|h\.?264|h\.?265)$/i.test(candidate)) {
    return undefined;
  }
  return candidate;
}

// --- Constantes formats binaires ---
const MAGIC_MANIFEST = Buffer.from([0x4d, 0x56, 0x4c, 0x54]); // 'MVLT'
const MAGIC_LICENSE  = Buffer.from([0x4c, 0x56, 0x4c, 0x54]); // 'LVLT'
const VERSION = 1;
const SIG_ED25519 = 1;

function u16(n){const b=Buffer.alloc(2);b.writeUInt16LE(n,0);return b;}
function u32(n){const b=Buffer.alloc(4);b.writeUInt32LE(n,0);return b;}

function hkdf(key, salt, info, len=32){
  return crypto.hkdfSync('sha256', key, salt, Buffer.from(info,'utf8'), len);
}
function sha256(buf){ return crypto.createHash('sha256').update(buf).digest(); }
async function sha256File(fp){
  const h=crypto.createHash('sha256');
  await new Promise((res,rej)=>fs.createReadStream(fp).on('data',d=>h.update(d)).on('end',res).on('error',rej));
  return h.digest('hex');
}
async function ensureDirs(vault){ await fse.ensureDir(path.join(vault,'.vault')); await fse.ensureDir(path.join(vault,'media')); }

function workspaceDir(){ return path.resolve(__dirname,'workspace'); }
function keysDir(){ return path.resolve(__dirname,'keys'); }
async function loadJSON(fp, def){ try{ return JSON.parse(await fsp.readFile(fp,'utf8')); }catch{ return def; } }
async function saveJSON(fp, obj){ await fse.ensureDir(path.dirname(fp)); await fsp.writeFile(fp, JSON.stringify(obj,null,2),'utf8'); }

// === Crypto fichiers .enc : [IV(12)][CIPHERTEXT][TAG(16)] ===
async function encryptFileToEnc(srcFile, outFile, cek){
  const iv = crypto.randomBytes(12);
  await fse.ensureDir(path.dirname(outFile));
  const cipher = crypto.createCipheriv('aes-256-gcm', cek, iv);
  const out = fs.createWriteStream(outFile);
  out.write(iv);
  await new Promise((res,rej)=>{
    fs.createReadStream(srcFile).pipe(cipher).pipe(out).on('finish',res).on('error',rej);
  });
  const tag = cipher.getAuthTag();
  await fsp.appendFile(outFile, tag);
}

// --- CLI ---
const program = new Command();
program.name('packager').description('USB Video Vault - packager CLI');

// INIT : clé Ed25519 + device.tag
program.command('init')
  .requiredOption('--vault <path>')
  .action(async ({vault})=>{
    vault = path.resolve(vault);
    await ensureDirs(vault);

    await fse.ensureDir(keysDir());
    const kp = nacl.sign.keyPair();
    const privB64 = Buffer.from(kp.secretKey).toString('base64');
    const pubB64  = Buffer.from(kp.publicKey).toString('base64');
    await fsp.writeFile(path.join(keysDir(),'private_key'), privB64,'utf8');
    await fsp.writeFile(path.join(keysDir(),'public_key'),  pubB64,'utf8');

    const sharedKeyTs = path.resolve(process.cwd(),'src','shared','keys','packagerPublicKey.ts');
    await fse.ensureDir(path.dirname(sharedKeyTs));
    await fsp.writeFile(sharedKeyTs, `export const PACKAGER_PUBLIC_KEY_B64='${pubB64}';\n`,'utf8');

    // device.tag: 16o aléatoires spécifiques à CETTE clé
    const deviceTagPath = path.join(vault,'.vault','device.tag');
    if (!(await fse.pathExists(deviceTagPath))){
      await fsp.writeFile(deviceTagPath, crypto.randomBytes(16));
    }

    console.log('✔ Clés Ed25519 générées, device.tag créé.');
  });

// ADD MEDIA : chiffrer une vidéo
program.command('add-media')
  .requiredOption('--vault <path>')
  .requiredOption('--file <mp4>')
  .requiredOption('--title <title>')
  .option('--artist <artist>')
  .action(async (opts)=>{
    const vault = path.resolve(opts.vault);
    await ensureDirs(vault);

    const absInputFile = path.resolve(opts.file);
    const id = uuidv4();
    const mediaOut = path.join(vault,'media',`${id}.enc`);
    const cek = crypto.randomBytes(32);
    await encryptFileToEnc(absInputFile, mediaOut, cek);
    const sha256Enc = await sha256File(mediaOut);

    // Extraction des métadonnées avec ffprobe
    const meta = ffprobeMeta(absInputFile);
    const year = meta.year;
    const genre = meta.genre ?? parseGenreFromFilename(absInputFile);

    // workspace manifest + keybank (LOCAL, ne pas copier)
    const ws = workspaceDir();
    const manifestDev = path.join(ws,'manifest.dev.json');
    const keybank = path.join(ws,'keybank.dev.json');

    const manifest = await loadJSON(manifestDev, []);
    const entry = { 
      id, 
      title: opts.title, 
      artist: opts.artist || '', 
      sha256Enc 
    };
    
    // Ajouter les métadonnées si disponibles
    if (typeof meta.durationSec === 'number') entry.durationSec = meta.durationSec;
    if (typeof year === 'number') entry.year = year;
    if (genre) entry.genre = genre;
    
    manifest.push(entry);
    await saveJSON(manifestDev, manifest);

    const kb = await loadJSON(keybank, {});
    kb[id] = Buffer.from(cek).toString('base64');
    await saveJSON(keybank, kb);

    console.log(`✔ Ajouté: ${opts.title} (${id})${year ? ` [${year}]` : ''}${genre ? ` {${genre}}` : ''}`);
  });

// BUILD MANIFEST (clair de debug)
program.command('build-manifest')
  .requiredOption('--vault <path>')
  .action(async ({vault})=>{
    vault = path.resolve(vault);
    const wsManifest = path.join(workspaceDir(),'manifest.dev.json');
    const list = await loadJSON(wsManifest, []);
    list.sort((a,b)=>a.title.localeCompare(b.title));
    const manifestJson = { version: 1, media: list };
    await saveJSON(path.join(vault,'.vault','manifest.dev.json'), manifestJson);
    console.log('✔ manifest.dev.json écrit (debug).');
  });

// SEAL MANIFEST (clé aléatoire) + signature
program.command('seal-manifest')
  .requiredOption('--vault <path>')
  .option('--random-key', 'utiliser une clé aléatoire pour le manifest', true)
  .action(async ({vault, random_key})=>{
    vault = path.resolve(vault);
    const dev = await loadJSON(path.join(vault,'.vault','manifest.dev.json'), null);
    if (!dev) throw new Error('manifest.dev.json introuvable. Lance build-manifest.');

    // clé manifest : aléatoire recommandée
    const manifestKey = crypto.randomBytes(32);
    const nonce = crypto.randomBytes(12);

    const plain = Buffer.from(JSON.stringify(dev),'utf8');
    const cipher = crypto.createCipheriv('aes-256-gcm', manifestKey, nonce);
    const ciphertext = Buffer.concat([cipher.update(plain), cipher.final()]);
    const tag = cipher.getAuthTag();

    const body = Buffer.concat([
      u16(VERSION),
      u16(0),                  // KDF_ID = 0 (clé directe)
      u32(0),                  // SALT_LEN = 0
      u32(nonce.length), nonce,
      u32(ciphertext.length), ciphertext,
      u32(tag.length), tag
    ]);

    const privB64 = await fsp.readFile(path.join(keysDir(),'private_key'),'utf8');
    const priv = Buffer.from(privB64.trim(),'base64');
    const signature = Buffer.from(nacl.sign.detached(body, priv));

    const bin = Buffer.concat([
      MAGIC_MANIFEST,
      body,
      u16(SIG_ED25519),
      u32(signature.length),
      signature
    ]);

    await fse.ensureDir(path.join(vault,'.vault'));
    await fsp.writeFile(path.join(vault,'.vault','manifest.bin'), bin);

    // stocker la clé manifest côté workspace pour lier à la licence
    await saveJSON(path.join(workspaceDir(),'manifest.key.json'), { manifestKeyB64: manifestKey.toString('base64') });

    console.log('✔ manifest.bin scellé (clé aléatoire + signé). Clé sauvegardée dans workspace/manifest.key.json');
  });

// ISSUE LICENSE : crée license.bin pour machine + clé USB
// kek/enc dérivés de: passphrase (optionnelle) + machineId + device.tag
program.command('issue-license')
  .requiredOption('--vault <path>')
  .requiredOption('--machine <machineId>', 'machine id cible')
  .requiredOption('--expiry <yyyy-mm-dd>', 'date limite (UTC)')
  .option('--owner <name>', 'nom client/utilisateur', '')
  .option('--passphrase <pass>', 'passphrase licence (optionnelle)', '')
  .option('--all', 'inclure tous les médias', false)
  .option('--media <ids...>', 'liste d\'IDs si --all pas utilisé')
  .option('--valid-from <yyyy-mm-dd>', 'début de validité (UTC)', '')
  .option('--max-plays-global <n>', 'quota total de lectures', '')
  .option('--max-plays-per-media <n>', 'quota par média', '')
  .action(async (opts)=>{
    const vault = path.resolve(opts.vault);
    const deviceTag = await fsp.readFile(path.join(vault,'.vault','device.tag'));
    const deviceIdHex = deviceTag.toString('hex');
    const machineId = Buffer.from(opts.machine, 'utf8');
    const machineHash = sha256(machineId).toString('hex');

    // clé manifest depuis workspace
    const mk = await loadJSON(path.join(workspaceDir(),'manifest.key.json'), null);
    if (!mk) throw new Error('manifest.key.json manquant (lance seal-manifest).');
    const manifestKey = Buffer.from(mk.manifestKeyB64, 'base64');

    // CEK bank locale
    const kb = await loadJSON(path.join(workspaceDir(),'keybank.dev.json'), {});
    let mediaIds = [];
    if (opts.all) mediaIds = Object.keys(kb);
    else mediaIds = (opts.media || []).filter(id => kb[id]);

    // masterKey = scrypt(passphrase || "", salt = machineId) (32o)
    const masterKey = crypto.scryptSync(opts.passphrase || '', machineId, 32, {N:1<<15,r:8,p:1,maxmem:256*1024*1024});
    // dérivations
    const kekWrap   = hkdf(masterKey, deviceTag, 'wrap-cek');     // pour CEK wraps
    const encLicKey = hkdf(masterKey, deviceTag, 'license-json'); // pour chiffrer la licence
    const encManKey = hkdf(masterKey, deviceTag, 'manifest-key'); // wrap manifestKey

    // Wrap manifestKey
    const mkIv  = crypto.randomBytes(12);
    const mkC   = crypto.createCipheriv('aes-256-gcm', encManKey, mkIv);
    const mkCt  = Buffer.concat([mkC.update(manifestKey), mkC.final()]);
    const mkTag = mkC.getAuthTag();

    // Wrap CEKs
    const wraps = {};
    for (const id of mediaIds){
      const cek = Buffer.from(kb[id], 'base64');
      const iv  = crypto.randomBytes(12);
      const c   = crypto.createCipheriv('aes-256-gcm', kekWrap, iv);
      const ct  = Buffer.concat([c.update(cek), c.final()]);
      const tag = c.getAuthTag();
      wraps[id] = { iv: iv.toString('base64'), ct: ct.toString('base64'), tag: tag.toString('base64') };
    }

    const expiryIso = new Date(opts.expiry+'T23:59:59Z').toISOString();
    const validFromIso = opts.validFrom ? new Date(opts.validFrom+'T00:00:00Z').toISOString() : undefined;

    const rules = {
      validFrom: validFromIso,
      validUntil: expiryIso,
      maxPlaysGlobal: opts.maxPlaysGlobal ? Number(opts.maxPlaysGlobal) : undefined,
      maxPlaysPerMedia: opts.maxPlaysPerMedia ? Number(opts.maxPlaysPerMedia) : undefined,
    };

    const payload = {
      version: 1,
      owner: opts.owner || '',
      deviceIdHex,
      machineHash,
      expiryUtc: expiryIso,        // legacy (toujours mis pour compat)
      rules,
      manifestKeyWrap: { iv: mkIv.toString('base64'), ct: mkCt.toString('base64'), tag: mkTag.toString('base64') },
      wraps
    };

    // chiffrer payload (AES-GCM)
    const nonce = crypto.randomBytes(12);
    const plain = Buffer.from(JSON.stringify(payload),'utf8');
    const cipher = crypto.createCipheriv('aes-256-gcm', encLicKey, nonce);
    const ciphertext = Buffer.concat([cipher.update(plain), cipher.final()]);
    const tag = cipher.getAuthTag();

    const body = Buffer.concat([
      Buffer.from([VERSION]),
      u32(nonce.length), nonce,
      u32(ciphertext.length), ciphertext,
      u32(tag.length), tag
    ]);

    // signer licence (Ed25519)
    const privB64 = await fsp.readFile(path.join(keysDir(),'private_key'),'utf8');
    const priv = Buffer.from(privB64.trim(),'base64');
    const signature = Buffer.from(nacl.sign.detached(body, priv));

    const bin = Buffer.concat([
      MAGIC_LICENSE,
      body,
      u16(SIG_ED25519),
      u32(signature.length),
      signature
    ]);

    await fsp.writeFile(path.join(vault,'.vault','license.bin'), bin);
    console.log(`✔ license.bin émise (medias: ${mediaIds.length}) avec rules=`, rules);
  });

program.parseAsync();
