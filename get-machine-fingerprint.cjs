#!/usr/bin/env node

/**
 * Affiche l'empreinte de la machine actuelle
 */

const crypto = require('crypto');
const os = require('os');

function getCurrentMachineFingerprint() {
  const machineId = require('node-machine-id').machineIdSync(true);
  const platform = os.platform();
  const arch = os.arch();
  
  // Simuler USB série (pour test)
  const usbSerial = 'no-usb';
  
  // Obtenir MAC principale
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
  
  console.log('[MACHINE] Composants de l\'empreinte:');
  console.log('  Machine ID:', machineId.substring(0, 8) + '...');
  console.log('  Platform:', platform);
  console.log('  Arch:', arch);
  console.log('  USB Serial:', usbSerial);
  console.log('  Network MAC:', networkMac);
  console.log('  Combined:', combined);
  console.log('[MACHINE] Empreinte finale:', hash);
  
  return hash;
}

getCurrentMachineFingerprint();
