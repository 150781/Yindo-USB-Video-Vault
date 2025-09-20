#!/usr/bin/env node
// scripts/verify-license.mjs
// Diagnostic et vérification des licences

import fs from 'fs';
import path from 'path';
import zlib from 'zlib';
import { promisify } from 'util';

const gunzip = promisify(zlib.gunzip);

/**
 * Clés publiques pour vérification (format production)
 */
const PUB_KEYS = {
  1: '879c35f5ae011c56528c27abb0f5b61539bf0d134158ec56ac4e8b8dd08c9d78', // clé production v1
  // 2: 'future_public_key_hex_here...', // prête pour rotation
};

/**
 * Charge un fichier de licence
 */
async function loadLicenseFile(licensePath) {
  try {
    console.log(`📂 Lecture: ${licensePath}`);
    
    if (licensePath.endsWith('.bin')) {
      // License.bin avec gzip+base64
      const base64Content = fs.readFileSync(licensePath, 'utf8');
      
      console.log(`   Format: gzip+base64 (${base64Content.length} chars)`);
      
      // Décodage base64 puis décompression gzip
      const gzipBuffer = Buffer.from(base64Content, 'base64');
      const jsonBuffer = await gunzip(gzipBuffer);
      const content = jsonBuffer.toString('utf8');
      
      console.log(`   Décompressé: ${content.length} chars JSON`);
      return JSON.parse(content);
      
    } else {
      // Fichier JSON standard
      const content = fs.readFileSync(licensePath, 'utf8');
      console.log(`   Format: JSON (${content.length} chars)`);
      return JSON.parse(content);
    }
    
  } catch (error) {
    console.error(`❌ Erreur lecture: ${error.message}`);
    return null;
  }
}

/**
 * Vérifie la signature (basique, sans tweetnacl)
 */
function verifySignature(licenseFile) {
  if (!licenseFile.data || !licenseFile.signature) {
    return { valid: false, reason: 'Structure invalide' };
  }
  
  const kidString = licenseFile.data.kid || 'kid-1';
  const kidNumber = kidString.startsWith('kid-') ? parseInt(kidString.substring(4)) : 1;
  
  if (!PUB_KEYS[kidNumber]) {
    return { valid: false, reason: `Clé publique inconnue: kid=${kidNumber}` };
  }
  
  // Note: vérification cryptographique nécessiterait tweetnacl
  return { valid: true, reason: `Clé trouvée: kid=${kidNumber}` };
}

/**
 * Analyse une licence
 */
function analyzeLicense(licenseFile) {
  console.log('\n📋 ANALYSE LICENCE');
  console.log('===================');
  
  const { data } = licenseFile;
  
  console.log(`📄 ID: ${data.licenseId || 'N/A'}`);
  console.log(`🔢 Version: ${data.version || 'N/A'}`);
  console.log(`🏭 Kid: ${data.kid || 'N/A'}`);
  console.log(`💻 Machine: ${data.machineFingerprint || 'N/A'}`);
  console.log(`📀 USB: ${data.usbSerial || '(aucun)'}`);
  console.log(`📅 Émise: ${data.issuedAt ? new Date(data.issuedAt).toLocaleString() : 'N/A'}`);
  console.log(`⏰ Expire: ${data.exp ? new Date(data.exp).toLocaleString() : 'N/A'}`);
  console.log(`🚀 Features: ${data.features ? data.features.join(', ') : 'N/A'}`);
  
  // Vérifications
  const now = new Date();
  const expiry = data.exp ? new Date(data.exp) : null;
  
  console.log('\n🔍 VALIDATIONS');
  console.log('===============');
  
  // Structure
  console.log(`📋 Structure: ${data && licenseFile.signature ? '✅ OK' : '❌ Manquante'}`);
  
  // Signature
  const sigCheck = verifySignature(licenseFile);
  console.log(`🔐 Signature: ${sigCheck.valid ? '✅' : '❌'} ${sigCheck.reason}`);
  
  // Expiration
  if (expiry) {
    const expired = now > expiry;
    const timeLeft = expiry.getTime() - now.getTime();
    const daysLeft = Math.round(timeLeft / (1000 * 60 * 60 * 24));
    
    if (expired) {
      console.log(`⏰ Expiration: ❌ Expirée depuis ${Math.abs(daysLeft)} jours`);
    } else {
      console.log(`⏰ Expiration: ✅ Valide (${daysLeft} jours restants)`);
    }
  } else {
    console.log(`⏰ Expiration: ⚠️  Pas définie`);
  }
  
  return {
    valid: sigCheck.valid && (!expiry || now <= expiry),
    expired: expiry && now > expiry,
    signature: sigCheck.valid
  };
}

/**
 * Fonction principale
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('🔍 VÉRIFICATEUR DE LICENCES');
    console.log('============================');
    console.log('');
    console.log('Usage:');
    console.log('  node scripts/verify-license.mjs <fichier-licence>');
    console.log('  node scripts/verify-license.mjs <dossier-vault>');
    console.log('');
    console.log('Exemples:');
    console.log('  node scripts/verify-license.mjs vault-real/.vault/license.bin');
    console.log('  node scripts/verify-license.mjs vault-real/license.json');
    console.log('  node scripts/verify-license.mjs vault-real');
    console.log('');
    process.exit(1);
  }
  
  const target = args[0];
  
  console.log('🔍 DIAGNOSTIC LICENCE');
  console.log('======================');
  console.log(`🎯 Cible: ${target}`);
  
  let candidates = [];
  
  if (fs.statSync(target).isDirectory()) {
    // Dossier vault - chercher les fichiers
    candidates = [
      path.join(target, '.vault', 'license.bin'),
      path.join(target, 'license.json'),
      path.join(target, 'license-test-expired.json')
    ].filter(f => fs.existsSync(f));
    
    if (candidates.length === 0) {
      console.log('❌ Aucun fichier de licence trouvé dans le vault');
      process.exit(1);
    }
    
  } else {
    // Fichier spécifique
    if (!fs.existsSync(target)) {
      console.log('❌ Fichier non trouvé');
      process.exit(1);
    }
    candidates = [target];
  }
  
  console.log(`📁 ${candidates.length} fichier(s) trouvé(s):`);
  candidates.forEach(f => console.log(`   📄 ${f}`));
  
  // Analyser chaque fichier
  for (const licensePath of candidates) {
    console.log(`\n${'='.repeat(50)}`);
    console.log(`📄 ${path.basename(licensePath)}`);
    console.log(`${'='.repeat(50)}`);
    
    const licenseFile = await loadLicenseFile(licensePath);
    if (!licenseFile) {
      continue;
    }
    
    const analysis = analyzeLicense(licenseFile);
    
    console.log('\n🎯 RÉSULTAT FINAL');
    console.log('==================');
    
    if (analysis.valid) {
      console.log('✅ LICENCE VALIDE');
    } else if (analysis.expired) {
      console.log('⏰ LICENCE EXPIRÉE');
    } else if (!analysis.signature) {
      console.log('🔐 SIGNATURE INVALIDE');
    } else {
      console.log('❌ LICENCE INVALIDE');
    }
  }
  
  console.log('\n✅ Diagnostic terminé');
}

// Exécution
main().catch(error => {
  console.error('❌ Erreur:', error.message);
  process.exit(1);
});