#!/usr/bin/env node

/**
 * Script pour vérifier l'état exact de la machine et USB
 */

const os = require('os');
const { execSync } = require('child_process');

console.log('[VERIFICATION] État de détection machine/USB...');

// 1. Machine ID
const machineId = require('node-machine-id').machineIdSync(true);
console.log('[VERIFICATION] Machine ID:', machineId);

// 2. Platform/Arch
console.log('[VERIFICATION] Platform:', os.platform());
console.log('[VERIFICATION] Arch:', os.arch());

// 3. Détection USB - méthode 1 (comme dans device.ts)
console.log('\n[VERIFICATION] Détection USB méthode 1 (device.ts):');
try {
  if (os.platform() === 'win32') {
    const output = execSync('wmic diskdrive where "interfacetype=\'USB\'" get serialnumber /format:list', 
      { encoding: 'utf8', timeout: 5000 }
    );
    console.log('[VERIFICATION] Sortie WMIC brute:', JSON.stringify(output));
    
    const match = output.match(/SerialNumber=([^\r\n]+)/);
    if (match && match[1] && match[1].trim()) {
      console.log('[VERIFICATION] USB Serial trouvé:', match[1].trim());
    } else {
      console.log('[VERIFICATION] Aucun USB Serial trouvé');
    }
  }
} catch (error) {
  console.log('[VERIFICATION] Erreur WMIC 1:', error.message);
}

// 4. Détection USB - méthode 2 (alternative)
console.log('\n[VERIFICATION] Détection USB méthode 2 (alternative):');
try {
  if (os.platform() === 'win32') {
    const output = execSync('wmic diskdrive get serialnumber,interfacetype /format:list', 
      { encoding: 'utf8', timeout: 5000 }
    );
    console.log('[VERIFICATION] Sortie WMIC alternative:', JSON.stringify(output));
  }
} catch (error) {
  console.log('[VERIFICATION] Erreur WMIC 2:', error.message);
}

// 5. Network MAC
console.log('\n[VERIFICATION] Interfaces réseau:');
const networkInterfaces = os.networkInterfaces();
for (const [name, interfaces] of Object.entries(networkInterfaces)) {
  if (interfaces && name !== 'lo' && !name.includes('virtual')) {
    const physicalInterface = interfaces.find(iface => 
      !iface.internal && iface.mac !== '00:00:00:00:00:00'
    );
    if (physicalInterface) {
      console.log('[VERIFICATION] Interface:', name, '->', physicalInterface.mac);
    }
  }
}

// 6. Test import device.ts
console.log('\n[VERIFICATION] Test module device.ts:');
try {
  const { detectUSBSerial } = require('./dist/shared/device.js');
  detectUSBSerial().then(serial => {
    console.log('[VERIFICATION] USB Serial via device.ts:', serial);
  }).catch(err => {
    console.log('[VERIFICATION] Erreur device.ts:', err.message);
  });
} catch (error) {
  console.log('[VERIFICATION] Erreur import device.ts:', error.message);
}
