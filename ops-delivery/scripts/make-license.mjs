#!/usr/bin/env node
// scripts/make-license.mjs
// Crée une license signée pour une machine/USB donnée

import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import zlib from 'zlib';
import { promisify } from 'util';

const gzip = promisify(zlib.gzip);
const gunzip = promisify(zlib.gunzip);

/**
 * Charge la clé privée depuis l'environnement
 */
function getPrivateKey() {
  const privateHex = process.env.PACKAGER_PRIVATE_HEX;
  if (!privateHex) {
    throw new Error('PACKAGER_PRIVATE_HEX non défini dans l\'environnement');
  }
  
  if (privateHex.length !== 128) { // 64 bytes * 2 chars hex
    throw new Error(`PACKAGER_PRIVATE_HEX invalide: ${privateHex.length} chars (attendu: 128)`);
  }
  
  return Buffer.from(privateHex, 'hex');
}

/**
 * Signe les données de license avec tweetnacl
 */
async function signLicense(licenseData, privateKey) {
  try {
    // Import dynamique de tweetnacl
    const nacl = await import('tweetnacl');
    
    // Sérialiser les données
    const dataString = JSON.stringify(licenseData, null, 2);
    const dataBuffer = Buffer.from(dataString, 'utf8');
    
    // Signature Ed25519
    const signature = nacl.default.sign.detached(dataBuffer, privateKey);
    
    return signature;
  } catch (error) {
    throw new Error(`Échec signature: ${error.message}`);
  }
}

/**
 * Crée le fichier license.bin
 */
async function createLicense(machineFingerprint, usbSerial = '', kid = 1, expirationDate = null, outputDir = 'vault-real') {
  try {
    console.log('🔐 CRÉATION LICENSE...');
    console.log('======================');
    console.log('');
    
    // 1. Données de license
    const licenseData = {
      version: '1.0',
      kid: `kid-${kid}`, // Format kid-1, kid-2, etc.
      machineFingerprint: machineFingerprint,
      usbSerial: usbSerial || '',
      issuedAt: new Date().toISOString(),
      expiresAt: expirationDate, // null = permanent, ou date ISO
      features: ['video-playback', 'playlist-management', 'vault-access'],
      issuer: 'USB-Video-Vault-Packager'
    };
    
    console.log('📋 Données license:');
    console.log(`    Machine: ${licenseData.machineFingerprint}`);
    console.log(`    USB: ${licenseData.usbSerial || '(aucun)'}`);
    console.log(`    Kid: ${licenseData.kid}`);
    console.log(`    Émission: ${licenseData.issuedAt}`);
    console.log(`    Expiration: ${licenseData.expiresAt || '(permanente)'}`);
    console.log('');
    
    // 2. Signature
    console.log('✍️  Signature...');
    const privateKey = getPrivateKey();
    const signature = await signLicense(licenseData, privateKey);
    console.log(`    Signature: ${signature.length} bytes`);
    console.log('');
    
    // 3. Format binaire final avec compression gzip+base64
    const licenseStructure = {
      data: licenseData,
      signature: Buffer.from(signature).toString('base64')
    };
    
    const licenseJson = JSON.stringify(licenseStructure, null, 2);
    const licenseBuffer = Buffer.from(licenseJson, 'utf8');
    
    // Compression gzip puis encodage base64
    const gzipBuffer = await gzip(licenseBuffer);
    const finalBuffer = gzipBuffer.toString('base64');
    
    console.log(`📦 Compression: ${licenseBuffer.length} → ${gzipBuffer.length} bytes (${Math.round(gzipBuffer.length/licenseBuffer.length*100)}%)`);
    console.log(`🔐 Encodage base64: ${finalBuffer.length} chars`);
    console.log('');
    
    // 4. Sauvegarde license.bin (format gzip+base64)
    const binOutputPath = path.join(outputDir, '.vault', 'license.bin');
    
    // Créer le dossier .vault si nécessaire
    const vaultDir = path.dirname(binOutputPath);
    if (!fs.existsSync(vaultDir)) {
      fs.mkdirSync(vaultDir, { recursive: true });
    }
    
    fs.writeFileSync(binOutputPath, finalBuffer, 'utf8');
    
    console.log('💾 Sauvegarde license.bin:');
    console.log(`    Fichier: ${binOutputPath}`);
    console.log(`    Taille: ${finalBuffer.length} chars (base64)`);
    console.log(`    Format: gzip+base64`);
    console.log('');
    
    // 5. Résumé
    console.log('✅ LICENSE BINAIRE CRÉÉE AVEC SUCCÈS !');
    console.log('');
    console.log('📁 Pour l\'utiliser:');
    console.log(`    1. Le fichier est déjà dans ${binOutputPath}`);
    console.log(`    2. S'assurer que device.tag contient le bon fingerprint`);
    console.log('');
    
    return binOutputPath;
    
  } catch (error) {
    console.error('❌ Erreur création license:', error.message);
    process.exit(1);
  }
}

/**
 * Crée aussi le JSON de fallback pour le vault
 */
async function createFallbackJSON(machineFingerprint, usbSerial = '', kid = 1, expirationDate = null, outputDir = 'vault-real') {
  try {
    console.log('📄 CRÉATION JSON FALLBACK...');
    console.log('=============================');
    console.log('');
    
    // 1. Structure JSON de fallback
    const data = {
      licenseId: "fallback-" + Date.now().toString(36),
      version: 1, // LICENSE_VERSION
      kid: `kid-${kid}`, // Identifiant clé pour rotation
      exp: expirationDate || "2099-12-31T23:59:59.000Z", // Expiration ou défaut lointain
      machineFingerprint: machineFingerprint,
      features: ["playback", "secure-vault"]
    };
    
    console.log('📋 Données JSON fallback:');
    console.log(`    License ID: ${data.licenseId}`);
    console.log(`    Version: ${data.version}`);
    console.log(`    Kid: ${data.kid}`);
    console.log(`    Expiration: ${data.exp}`);
    console.log(`    Machine: ${data.machineFingerprint}`);
    console.log(`    Features: ${data.features.join(', ')}`);
    console.log('');
    
    // 2. Signature des données
    console.log('✍️  Signature JSON...');
    const privateKey = getPrivateKey();
    
    // Signer exactement comme attendu par l'app
    const nacl = await import('tweetnacl');
    const dataString = JSON.stringify(data, null, 2);
    const dataBuffer = Buffer.from(dataString, 'utf8');
    const signature = nacl.default.sign.detached(dataBuffer, privateKey);
    const signatureBase64 = Buffer.from(signature).toString('base64');
    
    console.log(`    Signature: ${signatureBase64.substring(0, 20)}...`);
    console.log('');
    
    // 3. Structure finale
    const licenseStructure = {
      data: data,
      signature: signatureBase64
    };
    
    const finalJson = JSON.stringify(licenseStructure, null, 2);
    
    // 4. Sauvegarde
    const jsonPath = path.join(outputDir, 'license.json');
    fs.writeFileSync(jsonPath, finalJson, 'utf8');
    
    console.log('💾 JSON fallback sauvegardé:');
    console.log(`    Fichier: ${jsonPath}`);
    console.log(`    Taille: ${finalJson.length} chars`);
    console.log('');
    
    console.log('✅ JSON FALLBACK CRÉÉ !');
    console.log('');
    
    return jsonPath;
    
  } catch (error) {
    console.error('❌ Erreur création JSON fallback:', error.message);
    throw error;
  }
}

// === MAIN ===
const args = process.argv.slice(2);

// Aide
if (args.includes('--help') || args.includes('-h')) {
  console.error('');
  console.error('🔐 MAKE-LICENSE - Générateur de licence sécurisé');
  console.error('===================================================');
  console.error('');
  console.error('Usage:');
  console.error('  node scripts/make-license.mjs <machineFingerprint> [usbSerial] [options]');
  console.error('');
  console.error('Arguments:');
  console.error('  machineFingerprint    Empreinte machine unique (obligatoire)');
  console.error('  usbSerial            Numéro série USB (optionnel)');
  console.error('');
  console.error('Options:');
  console.error('  --kid <number>       Key ID pour rotation (défaut: 1)');
  console.error('  --exp <date>         Date expiration ISO 8601 (défaut: aucune)');
  console.error('  --out <directory>    Dossier de sortie (défaut: vault-real)');
  console.error('  --help, -h           Affiche cette aide');
  console.error('');
  console.error('Exemples:');
  console.error('  node scripts/make-license.mjs "abc123def456"');
  console.error('  node scripts/make-license.mjs "abc123def456" "USB-789" --kid 1 --exp "2026-09-19T23:59:59Z"');
  console.error('  node scripts/make-license.mjs "abc123def456" --out "./output"');
  console.error('');
  console.error('Variables d\'environnement:');
  console.error('  PACKAGER_PRIVATE_HEX   Clé privée Ed25519 (64 bytes hex, obligatoire)');
  console.error('');
  console.error('💡 Pour obtenir le fingerprint:');
  console.error('   node scripts/print-bindings.mjs');
  process.exit(1);
}

// Parse des arguments
if (args.length < 1) {
  console.error('❌ Usage: node scripts/make-license.mjs <machineFingerprint> [usbSerial] [options]');
  console.error('💡 Utilisez --help pour plus d\'informations');
  process.exit(1);
}

// Extraction des arguments
const machineFingerprint = args[0];
let usbSerial = '';
let kid = 1;
let expirationDate = null;
let outputDir = 'vault-real';

// Parse des options
for (let i = 1; i < args.length; i++) {
  const arg = args[i];
  
  if (arg === '--kid' && args[i + 1]) {
    kid = parseInt(args[i + 1]);
    i++; // skip next arg
  } else if (arg === '--exp' && args[i + 1]) {
    expirationDate = args[i + 1];
    i++; // skip next arg
  } else if (arg === '--out' && args[i + 1]) {
    outputDir = args[i + 1];
    i++; // skip next arg
  } else if (!arg.startsWith('--') && i === 1) {
    // Deuxième argument positional = usbSerial
    usbSerial = arg;
  }
}

// Validation du fingerprint
if (!machineFingerprint || machineFingerprint.length < 8) {
  console.error('❌ Machine fingerprint trop court (min 8 chars)');
  process.exit(1);
}

console.log('');

(async () => {
  try {
    // Validation
    if (!machineFingerprint || machineFingerprint.length < 8) {
      console.error('❌ Machine fingerprint invalide (min 8 chars)');
      process.exit(1);
    }
    
    if (expirationDate && isNaN(Date.parse(expirationDate))) {
      console.error('❌ Date d\'expiration invalide (format ISO 8601 requis)');
      console.error('   Exemple valide: 2026-09-19T23:59:59Z');
      process.exit(1);
    }
    
    console.log('');
    console.log(`📋 Configuration:`);
    console.log(`   Machine: ${machineFingerprint.substring(0, 8)}...`);
    console.log(`   USB: ${usbSerial || '(aucun)'}`);
    console.log(`   Kid: ${kid}`);
    console.log(`   Expiration: ${expirationDate || '(permanente)'}`);
    console.log(`   Sortie: ${outputDir}`);
    console.log('');
    
    // Créer license.bin
    const binPath = await createLicense(machineFingerprint, usbSerial, kid, expirationDate, outputDir);
    console.log(`✅ License binaire: ${binPath}`);
    
    // Créer JSON fallback
    const jsonPath = await createFallbackJSON(machineFingerprint, usbSerial, kid, expirationDate, outputDir);
    console.log(`✅ JSON fallback: ${jsonPath}`);
    
    console.log('');
    console.log('🎯 LICENCE GÉNÉRÉE AVEC SUCCÈS !');
    console.log('=================================');
    console.log('');
    console.log('📁 Fichiers créés:');
    console.log(`   ✅ ${outputDir}/.vault/license.bin (format production)`);
    console.log(`   ✅ ${outputDir}/license.json (fallback)`);
    console.log('');
    console.log('📋 Installation chez le client:');
    console.log(`   1. Copier license.bin → %VAULT_PATH%\\.vault\\license.bin`);
    console.log(`   2. Démarrer l'application`);
    console.log(`   3. Vérifier "Licence validée" dans les logs`);
    console.log('');
    
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    process.exit(1);
  }
})();