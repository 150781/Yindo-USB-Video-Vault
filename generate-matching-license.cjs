#!/usr/bin/env node

/**
 * Générateur de licence correspondant exactement à la machine actuelle
 */

const fs = require('fs').promises;
const crypto = require('crypto');
const path = require('path');
const os = require('os');
const nacl = require('tweetnacl');

// Clé de test pour le développement (même que licenseSecure.ts)
const PUBLIC_KEY_HEX = 'f689c830abf8f7911dc8d1ca3904cffc46c987abfb5e6b8b9b4ebef4632fd2d0';

// Recréer la paire de clés depuis la clé publique connue
// Pour les tests, on va générer une nouvelle paire et mettre à jour licenseSecure.ts
const keyPair = nacl.sign.keyPair.fromSeed(Buffer.from('test-seed-for-usb-video-vault-license-system', 'utf8').subarray(0, 32));
const PRIVATE_KEY = keyPair.secretKey;
const PUBLIC_KEY = keyPair.publicKey;
const REAL_PUBLIC_KEY_HEX = Buffer.from(PUBLIC_KEY).toString('hex');

function getCurrentMachineFingerprint() {
  const machineId = require('node-machine-id').machineIdSync(true);
  const platform = os.platform();
  const arch = os.arch();
  
  // Utiliser EXACTEMENT la même logique que device.ts
  let usbSerial = 'no-usb';
  if (platform === 'win32') {
    try {
      // Même logique que detectUSBSerialWindows
      const appPath = process.execPath;
      const driveLetter = appPath.substring(0, 2); // Ex: "C:"
      
      const { execSync } = require('child_process');
      const output = execSync(`powershell -Command "Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq '${driveLetter}'} | Select-Object VolumeSerialNumber"`, 
        { encoding: 'utf8', timeout: 5000 }
      );
      
      const lines = output.split('\n');
      for (const line of lines) {
        const match = line.match(/([A-F0-9]{8})/);
        if (match) {
          usbSerial = match[1];
          console.log('[GENERATOR] USB Serial détecté (comme device.ts):', usbSerial);
          break;
        }
      }
    } catch (error) {
      console.log('[GENERATOR] Erreur détection USB:', error.message);
    }
  }
  
  // Obtenir MAC principale (même logique que device.ts)
  let networkMac = 'no-mac';
  const networkInterfaces = os.networkInterfaces();
  for (const [name, interfaces] of Object.entries(networkInterfaces)) {
    if (interfaces && name !== 'lo' && !name.includes('virtual')) {
      const physicalInterface = interfaces.find(iface => 
        !iface.internal && iface.mac !== '00:00:00:00:00:00'
      );
      if (physicalInterface) {
        networkMac = physicalInterface.mac;
        break;
      }
    }
  }
  
  const components = [
    machineId,
    platform,
    arch,
    usbSerial,
    networkMac
  ];
  
  const combined = components.join('|');
  const hash = crypto.createHash('sha256').update(combined, 'utf8').digest('hex');
  
  return { hash, usbSerial, machineId, networkMac };
}

async function generateMatchingLicense(outputDir = '.') {
  console.log('[GENERATOR] Génération d\'une licence correspondant à cette machine...');
  
  const fingerprint = getCurrentMachineFingerprint();
  const machineFingerprint = fingerprint.hash;
  const usbSerial = fingerprint.usbSerial;
  
  console.log('[GENERATOR] Machine fingerprint:', machineFingerprint);
  console.log('[GENERATOR] USB Serial:', usbSerial);
  console.log('[GENERATOR] Machine ID:', fingerprint.machineId);
  console.log('[GENERATOR] Network MAC:', fingerprint.networkMac);

  const licenseData = {
    licenseId: `lic_${crypto.randomBytes(8).toString('hex')}`,
    exp: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(), // 1 an
    usbSerial: usbSerial, // Utiliser l'USB détecté
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
  
  console.log('\n[GENERATOR] Clé publique à utiliser dans licenseSecure.ts:');
  console.log(`const PACKAGER_PUBLIC_KEY_HEX = '${REAL_PUBLIC_KEY_HEX}';`);
  
  return { licenseFile, publicKeyHex: REAL_PUBLIC_KEY_HEX };
}

async function main() {
  const outputDir = process.argv[2] || './test-vault';
  
  try {
    // Créer le dossier de test si nécessaire
    await fs.mkdir(outputDir, { recursive: true });
    
    const result = await generateMatchingLicense(outputDir);
    
    console.log('\n[GENERATOR] 🎉 Licence correspondante générée avec succès !');
    
  } catch (error) {
    console.error('[GENERATOR] ❌ Erreur:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { generateMatchingLicense };
