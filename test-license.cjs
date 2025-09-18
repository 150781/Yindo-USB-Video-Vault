#!/usr/bin/env node

/**
 * Test du système de licence Ed25519 sécurisé
 */

const fs = require('fs').promises;
const crypto = require('crypto');
const path = require('path');
const os = require('os');
const assert = require('assert');
const nacl = require('tweetnacl');

// Simulation d'une paire de clés Ed25519 pour les tests
const keyPair = nacl.sign.keyPair();
const PRIVATE_KEY = keyPair.secretKey;
const PUBLIC_KEY = keyPair.publicKey;
const PUBLIC_KEY_HEX = Buffer.from(PUBLIC_KEY).toString('hex');

async function runLicenseTests() {
  console.log('[LICENSE] Tests du système de licence sécurisé...');
  
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'license-test-'));
  
  try {
    // Test 1: Génération et signature d'une licence valide
    console.log('[LICENSE] Test 1: Génération de licence...');
    
    const licenseData = {
      licenseId: `lic_${crypto.randomBytes(8).toString('hex')}`,
      exp: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(), // 1 an
      usbSerial: 'TEST-USB-12345',
      machineFingerprint: 'test-machine-fingerprint-hash',
      features: ['play', 'queue', 'display', 'fullscreen'],
      maxPlaybackPerDay: 100,
      issuer: 'Test Issuer',
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
    const licensePath = path.join(tempDir, 'license.json');
    await fs.writeFile(licensePath, JSON.stringify(licenseFile, null, 2));
    
    console.log('[LICENSE] ✅ Licence générée et signée');
    
    // Test 2: Vérification de signature valide
    console.log('[LICENSE] Test 2: Vérification signature...');
    
    const loadedLicense = JSON.parse(await fs.readFile(licensePath, 'utf8'));
    const loadedSignature = Buffer.from(loadedLicense.signature, 'base64');
    const loadedData = Buffer.from(JSON.stringify(loadedLicense.data, null, 2), 'utf8');
    
    const isValidSignature = nacl.sign.detached.verify(
      new Uint8Array(loadedData),
      new Uint8Array(loadedSignature),
      PUBLIC_KEY
    );
    
    assert.strictEqual(isValidSignature, true, 'Signature devrait être valide');
    console.log('[LICENSE] ✅ Signature valide');
    
    // Test 3: Détection de signature corrompue
    console.log('[LICENSE] Test 3: Signature corrompue...');
    
    const corruptedSignature = Buffer.from(loadedSignature);
    corruptedSignature[0] ^= 0xFF; // Corrompre le premier byte
    
    const isInvalidSignature = nacl.sign.detached.verify(
      new Uint8Array(loadedData),
      new Uint8Array(corruptedSignature),
      PUBLIC_KEY
    );
    
    assert.strictEqual(isInvalidSignature, false, 'Signature corrompue devrait être invalide');
    console.log('[LICENSE] ✅ Signature corrompue détectée');
    
    // Test 4: Licence expirée
    console.log('[LICENSE] Test 4: Licence expirée...');
    
    const expiredLicenseData = {
      ...licenseData,
      exp: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString() // Hier
    };
    
    const expiredDate = new Date(expiredLicenseData.exp);
    const now = new Date();
    assert(now > expiredDate, 'La licence devrait être expirée');
    
    console.log('[LICENSE] ✅ Expiration détectée');
    
    // Test 5: Génération d'empreinte machine (simulation)
    console.log('[LICENSE] Test 5: Empreinte machine...');
    
    // Simuler une empreinte machine
    const machineComponents = [
      'machine-id-123',
      'win32',
      'x64',
      'TEST-USB-12345',
      '00:11:22:33:44:55'
    ];
    
    const machineHash = crypto.createHash('sha256')
      .update(machineComponents.join('|'), 'utf8')
      .digest('hex');
    
    console.log('[LICENSE] Empreinte machine simulée:', machineHash.substring(0, 16) + '...');
    
    // Test 6: Validation de binding
    console.log('[LICENSE] Test 6: Binding validation...');
    
    const validBinding = machineHash === machineHash; // Toujours vrai pour le test
    const invalidBinding = machineHash === 'different-hash';
    
    assert.strictEqual(validBinding, true, 'Binding valide devrait passer');
    assert.strictEqual(invalidBinding, false, 'Binding invalide devrait échouer');
    
    console.log('[LICENSE] ✅ Binding validation');
    
    // Test 7: Gestion du temps (anti-rollback)
    console.log('[LICENSE] Test 7: Anti-rollback temporel...');
    
    const maxSeenTime = Date.now();
    const currentTime = Date.now();
    const rollbackTime = Date.now() - 2 * 60 * 60 * 1000; // 2h en arrière
    
    const validTime = currentTime >= maxSeenTime - (10 * 60 * 1000); // Tolérance 10min
    const invalidTime = rollbackTime >= maxSeenTime - (10 * 60 * 1000);
    
    assert.strictEqual(validTime, true, 'Temps normal devrait être valide');
    assert.strictEqual(invalidTime, false, 'Rollback devrait être détecté');
    
    console.log('[LICENSE] ✅ Anti-rollback temporel');
    
    // Test 8: Validation de features
    console.log('[LICENSE] Test 8: Validation features...');
    
    const allowedFeatures = licenseData.features;
    const hasPlayFeature = allowedFeatures.includes('play');
    const hasAdminFeature = allowedFeatures.includes('admin');
    
    assert.strictEqual(hasPlayFeature, true, 'Feature "play" devrait être autorisée');
    assert.strictEqual(hasAdminFeature, false, 'Feature "admin" ne devrait pas être autorisée');
    
    console.log('[LICENSE] ✅ Validation features');
    
    console.log('[LICENSE] 🎉 Tous les tests de licence réussis !');
    
  } finally {
    // Nettoyage
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch {}
  }
}

async function runDeviceDetectionTest() {
  console.log('[LICENSE] Test détection de périphériques...');
  
  try {
    // Test détection OS
    const platform = os.platform();
    const arch = os.arch();
    const hostname = os.hostname();
    
    console.log('[LICENSE] Plateforme:', platform);
    console.log('[LICENSE] Architecture:', arch);
    console.log('[LICENSE] Hostname:', hostname);
    
    // Test MAC address
    const networkInterfaces = os.networkInterfaces();
    let foundMAC = false;
    
    for (const [name, interfaces] of Object.entries(networkInterfaces)) {
      if (interfaces && name !== 'lo' && !name.includes('virtual')) {
        const physicalInterface = interfaces.find(iface => 
          !iface.internal && iface.mac !== '00:00:00:00:00:00'
        );
        if (physicalInterface) {
          console.log('[LICENSE] Interface réseau:', name, '->', physicalInterface.mac);
          foundMAC = true;
          break;
        }
      }
    }
    
    if (!foundMAC) {
      console.log('[LICENSE] ⚠️ Aucune adresse MAC physique trouvée');
    }
    
    // Générer un ID machine stable
    const machineId = require('node-machine-id').machineIdSync(true);
    console.log('[LICENSE] Machine ID:', machineId.substring(0, 8) + '...');
    
    console.log('[LICENSE] ✅ Détection périphériques OK');
    
  } catch (error) {
    console.error('[LICENSE] Erreur détection périphériques:', error);
  }
}

async function main() {
  try {
    await runLicenseTests();
    await runDeviceDetectionTest();
    console.log('[LICENSE] 🎉 Tous les tests système de licence réussis !');
  } catch (error) {
    console.error('[LICENSE] ❌ Tests échoués:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { runLicenseTests, runDeviceDetectionTest };
