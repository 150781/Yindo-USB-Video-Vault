#!/usr/bin/env node
import fg from 'fast-glob';
import * as path from 'path';
import { promises as fs } from 'fs';
import { hideBin } from 'yargs/helpers';
import yargs from 'yargs';
import { randomUUID } from 'crypto';
import { aesGcmEncrypt, scryptKey, sha256Hex } from './crypto';
import { ensureDir, writeJsonPretty, mediaPath, deviceTagPath, manifestBinPath, readFileSafe, exists } from './fs';
import { probeDurationMs } from './duration';
import type { DeviceTag, ManifestJson, MediaMeta } from './types';

type Args = {
  vault: string;
  src?: string | string[];
  pass?: string;
};

function nowIso() { return new Date().toISOString(); }

async function cmdInit({ vault }: Args) {
  const dot = path.join(vault, '.vault');
  const med = path.join(vault, 'media');
  await ensureDir(dot);
  await ensureDir(med);

  const tagPath = deviceTagPath(vault);
  if (await exists(tagPath)) {
    console.log('[packager] .vault/device.tag existe déjà → OK');
    return;
  }

  const tag: DeviceTag = {
    version: 1,
    deviceId: randomUUID(),
    saltHex: Buffer.from(randomUUID()).toString('hex').slice(0, 32), // petit sel random
    createdAt: nowIso(),
    tool: 'packager/1.0'
  };
  await writeJsonPretty(tagPath, tag);
  console.log('[packager] INIT OK →', tagPath);
}

async function cmdImport({ vault, src, pass }: Args) {
  if (!src) throw new Error('--src pattern requis');
  if (!pass) console.warn('[packager] ⚠️ Aucun --pass fourni → les fichiers seront chiffrés avec une clé dérivée plus tard lors du seal.');

  const tagRaw = await readFileSafe(deviceTagPath(vault));
  if (!tagRaw) throw new Error(`VAULT introuvable: ${deviceTagPath(vault)} manquant. Lance d\'abord: packager:init`);

  const patterns = Array.isArray(src) ? src : [src];
  const files = await fg(patterns, { dot: false, onlyFiles: true });
  if (!files.length) {
    console.log('[packager] Aucun fichier à importer pour', patterns);
    return;
  }

  // On construit un manifest JSON en clair (temporaire)
  const items: MediaMeta[] = [];
  for (const file of files) {
    const buf = await fs.readFile(file);
    const hash = sha256Hex(buf);
    const ext = path.extname(file).slice(1).toLowerCase() || undefined;
    const id = `vault:${hash.slice(0, 12)}`; // id stable court basé sur hash
    const title = path.basename(file).replace(/\.[^.]+$/, '');
    const durationMs = await probeDurationMs(file); // peut renvoyer null

    // On chiffre DÈS maintenant le contenu pour le poser en .bin
    // Clé de travail : si pass absent, on utilise une clé éphémère (sera re-chiffré au seal)
    const tagObj = JSON.parse(tagRaw.toString()) as DeviceTag;
    const tempKey = scryptKey(pass || 'temporary-local-key', tagObj.saltHex);

    const enc = aesGcmEncrypt(buf, tempKey);
    const outPath = mediaPath(vault, id);
    await fs.writeFile(outPath, enc);

    items.push({
      id,
      title,
      artist: undefined,
      genre: undefined,
      year: undefined,
      durationMs: durationMs ?? null,
      source: 'vault',
      sha256: hash,
      ext
    });

    console.log(`[packager] + ${file} → ${outPath} (${durationMs ?? '??'} ms)`);
  }

  const tmpManifestJson: ManifestJson = {
    version: 1,
    createdAt: nowIso(),
    items
  };
  const tmpPath = path.join(vault, '.vault', 'manifest.json'); // clair provisoire
  await writeJsonPretty(tmpPath, tmpManifestJson);
  console.log('[packager] manifest.json (clair) écrit →', tmpPath);
}

async function cmdSeal({ vault, pass }: Args) {
  if (!pass) throw new Error('--pass requis pour sceller le manifest');

  const tagRaw = await readFileSafe(deviceTagPath(vault));
  if (!tagRaw) throw new Error('device.tag manquant. Lance d\'abord: packager:init');

  const tagObj = JSON.parse(tagRaw.toString()) as DeviceTag;
  const key = scryptKey(pass, tagObj.saltHex);

  // 1) relire le manifest clair
  const tmpPath = path.join(vault, '.vault', 'manifest.json');
  const plain = await readFileSafe(tmpPath);
  if (!plain) throw new Error('manifest.json (clair) introuvable. Lance packager:import d\'abord.');

  // 2) chiffrer le manifest
  const enc = aesGcmEncrypt(plain, key);
  const outPath = manifestBinPath(vault);
  await fs.writeFile(outPath, enc);

  // 3) nettoyer le manifest clair
  await fs.rm(tmpPath, { force: true });

  console.log('[packager] manifest.bin scellé →', outPath);
  console.log('[packager] OK');
}

async function cmdList({ vault, pass }: Args) {
  const tagRaw = await readFileSafe(deviceTagPath(vault));
  if (!tagRaw) throw new Error('device.tag manquant');
  const tagObj = JSON.parse(tagRaw.toString()) as any;
  console.log('--- VAULT ---');
  console.log('Path   :', vault);
  console.log('Device :', tagObj.deviceId);
  console.log('Created:', tagObj.createdAt);

  const manEnc = await readFileSafe(manifestBinPath(vault));
  if (!manEnc) {
    console.log('manifest.bin: MISSING (avez-vous scellé ? packager:seal)');
    return;
  }
  if (!pass) {
    console.log('manifest.bin: PRESENT (pass manquant pour lecture)');
    return;
  }
  const key = scryptKey(pass, tagObj.saltHex);
  try {
    const { aesGcmDecrypt } = await import('./crypto');
    const plain = aesGcmDecrypt(manEnc, key);
    const json = JSON.parse(plain.toString()) as any;
    console.log(`manifest.bin: ${json.items?.length ?? 0} item(s)`);
  } catch (e) {
    console.log('manifest.bin: illisible (mauvais pass ?)');
  }
}

yargs(hideBin(process.argv))
  .command('init', 'Initialiser un vault (.vault/device.tag)', (y) => y
    .option('vault', { type: 'string', demandOption: true })
  , (argv) => cmdInit(argv as any))
  .command('import', 'Importer et chiffrer des médias', (y) => y
    .option('vault', { type: 'string', demandOption: true })
    .option('src', { type: 'string', demandOption: true })
    .option('pass', { type: 'string' })
  , (argv) => cmdImport(argv as any))
  .command('seal', 'Sceller manifest.json → manifest.bin (AES-256-GCM)', (y) => y
    .option('vault', { type: 'string', demandOption: true })
    .option('pass', { type: 'string', demandOption: true })
  , (argv) => cmdSeal(argv as any))
  .command('list', 'Lister état du vault', (y) => y
    .option('vault', { type: 'string', demandOption: true })
    .option('pass', { type: 'string' })
  , (argv) => cmdList(argv as any))
  .demandCommand(1)
  .strict()
  .help()
  .parse();
