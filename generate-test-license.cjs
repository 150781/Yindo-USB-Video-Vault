#!/usr/bin/env node

/**
 * Générateur de licence de test pour USB Video Vault
 */

const fs = require('fs').promises;
const crypto = require('crypto');
const path = require('path');
const nacl = require('tweetnacl');

// Clé de test pour le développement
const keyPair = nacl.sign.keyPair.fromSeed(crypto.randomBytes(32));
const PRIVATE_KEY = keyPair.secretKey;
const PUBLIC_KEY = keyPair.publicKey;
const PUBLIC_KEY_HEX = Buffer.from(PUBLIC_KEY).toString('hex');

async function generateTestLicense(outputDir = '.') {
  console.log('[GENERATOR] Génération d\'une licence de test...');
  
  // Simuler une empreinte machine et USB
  const machineComponents = [
    require('node-machine-id').machineIdSync(true),
    process.platform,
    process.arch,
    'TEST-USB-SERIAL',
    '00:11:22:33:44:55'
  ];
  
  const machineFingerprint = crypto.createHash('sha256')
    .update(machineComponents.join('|'), 'utf8')
    .digest('hex');

  const licenseData = {
    licenseId: `lic_${crypto.randomBytes(8).toString('hex')}`,
    exp: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(), // 1 an
    usbSerial: 'TEST-USB-SERIAL',
    machineFingerprint: machineFingerprint,
    features: ['play', 'queue', 'display', 'fullscreen', 'secondary_display'],
    maxPlaybackPerDay: 1000,
    issuer: 'USB Video Vault Test Generator',
    issuedAt: new Date().toISOString(),
    version: 1
  };
  
  // Signer la licence
  const dataToSign = JSON.stringify(licenseData, null, 2);
  const signature = nacl.sign.detached(
    new Uint8Array(Buffer.from(dataToSign, 'utf8')),
    PRIVATE_KEY
  );
  
  const licenseFile = {
    data: licenseData,
    signature: Buffer.from(signature).toString('base64')
  };
  
  // Sauvegarder
  const licensePath = path.join(outputDir, 'license.json');
  await fs.writeFile(licensePath, JSON.stringify(licenseFile, null, 2));
  
  console.log('[GENERATOR] ✅ Licence générée:', licensePath);
  console.log('[GENERATOR] ID:', licenseData.licenseId);
  console.log('[GENERATOR] Expire:', new Date(licenseData.exp).toLocaleDateString());
  console.log('[GENERATOR] Features:', licenseData.features.join(', '));
  console.log('[GENERATOR] Machine fingerprint:', machineFingerprint.substring(0, 16) + '...');
  
  // Mettre à jour la clé publique dans le code (pour les tests)
  console.log('\n[GENERATOR] Clé publique à utiliser dans licenseSecure.ts:');
  console.log(`const PACKAGER_PUBLIC_KEY_HEX = '${PUBLIC_KEY_HEX}';`);
  
  return { licenseFile, publicKeyHex: PUBLIC_KEY_HEX };
}

async function main() {
  const outputDir = process.argv[2] || './test-vault';
  
  try {
    // Créer le dossier de test si nécessaire
    await fs.mkdir(outputDir, { recursive: true });
    
    const result = await generateTestLicense(outputDir);
    
    console.log('\n[GENERATOR] 🎉 Licence de test générée avec succès !');
    console.log('[GENERATOR] Utilisez cette licence pour tester le système sécurisé.');
    
  } catch (error) {
    console.error('[GENERATOR] ❌ Erreur:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { generateTestLicense };
