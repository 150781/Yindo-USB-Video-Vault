#!/usr/bin/env node
// scripts/print-bindings.mjs
// Collecte empreinte machine pour génération de licence (VERSION OPERATIONNELLE)

import os from 'os';
import crypto from 'crypto';
import { execSync } from 'child_process';

/**
 * Génère l'empreinte machine (identique à src/shared/device.ts)
 */
function getMachineFingerprint() {
  try {
    const platform = os.platform();
    const arch = os.arch();
    const hostname = os.hostname();
    const cpus = os.cpus();
    const totalMem = os.totalmem();
    
    // Caractéristiques CPU (premier processeur)
    const cpuModel = cpus[0]?.model || 'unknown';
    const cpuCount = cpus.length;
    
    // Combinaison des données machine
    const machineData = [
      platform,
      arch, 
      hostname,
      cpuModel,
      cpuCount.toString(),
      Math.floor(totalMem / (1024 * 1024 * 1024)).toString() // GB de RAM
    ].join('|');
    
    // Hash SHA-256
    const hash = crypto.createHash('sha256');
    hash.update(machineData);
    return hash.digest('hex').substring(0, 32); // 32 premiers caractères
    
  } catch (error) {
    console.error('Erreur génération empreinte:', error.message);
    return 'fallback-' + Date.now().toString(36);
  }
}

/**
 * Détecte les périphériques USB avec numéros de série
 */
function detectUSBDevices() {
  try {
    const platform = os.platform();
    let usbDevices = [];
    
    if (platform === 'win32') {
      // Windows : utiliser wmic ou PowerShell
      try {
        const cmd = 'wmic path win32_volume get DeviceID,Label,SerialNumber /format:csv';
        const output = execSync(cmd, { encoding: 'utf8', timeout: 10000 });
        
        const lines = output.split('\n');
        for (const line of lines) {
          const parts = line.split(',');
          if (parts.length >= 4 && parts[1] && parts[2] && parts[3]) {
            const deviceId = parts[1].trim();
            const label = parts[2].trim();
            const serial = parts[3].trim();
            
            if (deviceId.includes('USB') && serial && serial !== 'NULL') {
              usbDevices.push({
                deviceId,
                label: label || 'USB Device',
                serial,
                type: 'USB'
              });
            }
          }
        }
      } catch (wmicError) {
        // Fallback PowerShell
        try {
          const psCmd = 'Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 2} | Select-Object DeviceID,VolumeName,VolumeSerialNumber | ConvertTo-Json';
          const psOutput = execSync(`powershell -Command "${psCmd}"`, { encoding: 'utf8', timeout: 10000 });
          const drives = JSON.parse(psOutput);
          
          if (Array.isArray(drives)) {
            drives.forEach(drive => {
              if (drive.VolumeSerialNumber) {
                usbDevices.push({
                  deviceId: drive.DeviceID,
                  label: drive.VolumeName || 'USB Drive',
                  serial: drive.VolumeSerialNumber,
                  type: 'USB'
                });
              }
            });
          } else if (drives.VolumeSerialNumber) {
            usbDevices.push({
              deviceId: drives.DeviceID,
              label: drives.VolumeName || 'USB Drive', 
              serial: drives.VolumeSerialNumber,
              type: 'USB'
            });
          }
        } catch (psError) {
          console.warn('Impossible de détecter les périphériques USB:', psError.message);
        }
      }
      
    } else if (platform === 'linux') {
      // Linux : utiliser lsusb et /sys
      try {
        const output = execSync('lsusb -v 2>/dev/null | grep -E "(idVendor|idProduct|iSerial)" || true', { encoding: 'utf8', timeout: 10000 });
        // Parsing basique pour démonstration
        console.warn('Détection USB Linux non implémentée complètement');
      } catch (error) {
        console.warn('Impossible de détecter USB sur Linux:', error.message);
      }
      
    } else if (platform === 'darwin') {
      // macOS : utiliser system_profiler
      try {
        const output = execSync('system_profiler SPUSBDataType -json', { encoding: 'utf8', timeout: 10000 });
        const data = JSON.parse(output);
        // Parsing des données macOS USB
        console.warn('Détection USB macOS non implémentée complètement');
      } catch (error) {
        console.warn('Impossible de détecter USB sur macOS:', error.message);
      }
    }
    
    return usbDevices;
    
  } catch (error) {
    console.warn('Erreur détection USB:', error.message);
    return [];
  }
}

/**
 * Obtient les informations système détaillées
 */
function getSystemInfo() {
  return {
    hostname: os.hostname(),
    platform: os.platform(),
    arch: os.arch(),
    release: os.release(),
    version: os.version ? os.version() : 'N/A',
    totalMemory: Math.floor(os.totalmem() / (1024 * 1024 * 1024)), // GB
    cpuCount: os.cpus().length,
    cpuModel: os.cpus()[0]?.model || 'unknown',
    uptime: Math.floor(os.uptime() / 60), // minutes
    loadAverage: os.loadavg(),
    networkInterfaces: Object.keys(os.networkInterfaces()),
    userInfo: os.userInfo()
  };
}

/**
 * Affiche les informations de binding dans un format standardisé pour opérateurs
 */
async function printBindings() {
  try {
    console.log('');
    console.log('🔍 USB VIDEO VAULT - COLLECTE EMPREINTE CLIENT');
    console.log('==============================================');
    console.log('');
    
    // Informations système
    const systemInfo = getSystemInfo();
    const machineFingerprint = getMachineFingerprint();
    const usbDevices = detectUSBDevices();
    const timestamp = new Date().toISOString();
    
    console.log('📋 INFORMATIONS SYSTÈME:');
    console.log(`    Hostname: ${systemInfo.hostname}`);
    console.log(`    OS: ${systemInfo.platform} ${systemInfo.arch} (${systemInfo.release})`);
    console.log(`    CPU: ${systemInfo.cpuModel} (${systemInfo.cpuCount} cores)`);
    console.log(`    RAM: ${systemInfo.totalMemory} GB`);
    console.log(`    Utilisateur: ${systemInfo.userInfo.username}`);
    console.log('');
    
    // Empreinte machine
    console.log('💻 EMPREINTE MACHINE:');
    console.log(`    ${machineFingerprint}`);
    console.log('');
    
    // Périphériques USB
    console.log('📀 PÉRIPHÉRIQUES USB DÉTECTÉS:');
    if (usbDevices.length > 0) {
      usbDevices.forEach((device, index) => {
        console.log(`    [${index + 1}] ${device.label} (${device.deviceId})`);
        console.log(`        Serial: ${device.serial}`);
      });
      
      // USB principal pour licence
      const primaryUSB = usbDevices[0];
      console.log('');
      console.log('🎯 USB PRINCIPAL POUR LICENCE:');
      console.log(`    Serial: ${primaryUSB.serial}`);
      console.log(`    Label: ${primaryUSB.label}`);
    } else {
      console.log('    Aucun périphérique USB détecté');
      console.log('    Mode installation fixe (sans USB)');
    }
    console.log('');
    
    // Commandes génération licence
    console.log('⚙️ COMMANDES GÉNÉRATION LICENCE:');
    console.log('');
    
    if (usbDevices.length > 0) {
      const primaryUSB = usbDevices[0];
      console.log('  🔹 Licence avec USB spécifique:');
      console.log(`    node scripts/make-license.mjs "${machineFingerprint}" "${primaryUSB.serial}" --kid 1 --exp "2026-12-31T23:59:59Z"`);
      console.log('');
    }
    
    console.log('  🔹 Licence machine uniquement:');
    console.log(`    node scripts/make-license.mjs "${machineFingerprint}" --kid 1 --exp "2026-12-31T23:59:59Z"`);
    console.log('');
    
    console.log('  🔹 Licence avec fonctionnalités avancées:');
    console.log(`    node scripts/make-license.mjs "${machineFingerprint}" --kid 1 --exp "2026-12-31T23:59:59Z" --features "premium,analytics"`);
    console.log('');
    
    // Format JSON pour workflow automatisé
    const bindingData = {
      timestamp,
      client: {
        hostname: systemInfo.hostname,
        platform: systemInfo.platform,
        arch: systemInfo.arch,
        username: systemInfo.userInfo.username
      },
      machineFingerprint,
      usbDevices: usbDevices.map(d => ({
        label: d.label,
        serial: d.serial,
        deviceId: d.deviceId
      })),
      systemInfo: {
        cpuModel: systemInfo.cpuModel,
        cpuCount: systemInfo.cpuCount,
        totalMemory: systemInfo.totalMemory,
        release: systemInfo.release
      }
    };
    
    // Sauvegarde JSON pour audit
    const jsonFileName = `client-binding-${systemInfo.hostname}-${new Date().toISOString().split('T')[0]}.json`;
    try {
      const fs = await import('fs');
      fs.writeFileSync(jsonFileName, JSON.stringify(bindingData, null, 2));
      console.log('💾 SAUVEGARDE AUTOMATIQUE:');
      console.log(`    Fichier: ${jsonFileName}`);
      console.log('    (À transmettre avec la demande de licence)');
      console.log('');
    } catch (saveError) {
      console.warn('⚠️ Impossible de sauvegarder le fichier JSON:', saveError.message);
    }
    
    // Résumé pour opérateur
    console.log('📋 RÉSUMÉ POUR OPÉRATEUR:');
    console.log('========================');
    console.log(`Client: ${systemInfo.hostname} (${systemInfo.userInfo.username})`);
    console.log(`Machine: ${machineFingerprint}`);
    if (usbDevices.length > 0) {
      console.log(`USB Principal: ${usbDevices[0].serial}`);
    } else {
      console.log('USB: Aucun (installation fixe)');
    }
    console.log(`OS: ${systemInfo.platform} ${systemInfo.arch}`);
    console.log(`Date: ${new Date().toLocaleDateString('fr-FR')}`);
    console.log('========================');
    console.log('');
    
    // Étapes suivantes
    console.log('📌 PROCESSUS ÉMISSION LICENCE:');
    console.log('');
    console.log('1. 📧 TRANSMISSION CLIENT → OPÉRATEUR:');
    console.log(`   - Empreinte: ${machineFingerprint}`);
    if (usbDevices.length > 0) {
      console.log(`   - USB Serial: ${usbDevices[0].serial}`);
    }
    console.log(`   - Fichier JSON: ${jsonFileName}`);
    console.log('   - Informations client (nom, expiration souhaitée)');
    console.log('');
    
    console.log('2. 🔧 GÉNÉRATION CÔTÉ OPÉRATEUR:');
    console.log('   - Validation identité client');
    console.log('   - Génération licence avec scripts/make-license.mjs');
    console.log('   - Vérification avec scripts/verify-license.mjs');
    console.log('   - Packaging sécurisé 7z avec mot de passe');
    console.log('');
    
    console.log('3. 📦 LIVRAISON CLIENT:');
    console.log('   - Archive chiffrée par email/download');
    console.log('   - Mot de passe par canal séparé (SMS/téléphone)');
    console.log('   - Instructions installation');
    console.log('');
    
    console.log('4. ✅ INSTALLATION CLIENT:');
    console.log('   - Extraction archive avec mot de passe');
    console.log('   - Copie license.bin vers %VAULT_PATH%\\.vault\\');
    console.log('   - Redémarrage application');
    console.log('   - Vérification activation');
    console.log('');
    
  } catch (error) {
    console.error('❌ Erreur collecte empreinte:', error.message);
    console.error('');
    console.error('💡 Solutions:');
    console.error('   - Vérifier les permissions système');
    console.error('   - Relancer en tant qu\'administrateur');
    console.error('   - Vérifier que Node.js est installé');
    console.error('');
    process.exit(1);
  }
}

// Support arguments ligne de commande
const args = process.argv.slice(2);
const options = {
  help: args.includes('--help') || args.includes('-h'),
  verbose: args.includes('--verbose') || args.includes('-v'),
  json: args.includes('--json'),
  output: args.find(arg => arg.startsWith('--output='))?.split('=')[1]
};

// Aide
if (options.help) {
  console.log('');
  console.log('🔍 PRINT-BINDINGS - Collecte Empreinte Client');
  console.log('==============================================');
  console.log('');
  console.log('Collecte toutes les informations nécessaires pour générer');
  console.log('une licence liée à cette machine spécifique.');
  console.log('');
  console.log('Usage:');
  console.log('  node scripts/print-bindings.mjs [options]');
  console.log('');
  console.log('Options:');
  console.log('  --help, -h     Afficher cette aide');
  console.log('  --verbose, -v  Mode verbeux avec détails techniques');
  console.log('  --json         Sortie format JSON uniquement');
  console.log('  --output=FILE  Sauvegarder dans un fichier spécifique');
  console.log('');
  console.log('Sorties:');
  console.log('  - Empreinte machine unique (32 caractères hex)');
  console.log('  - Numéros de série USB détectés');
  console.log('  - Informations système complètes');
  console.log('  - Commandes de génération de licence');
  console.log('  - Fichier JSON pour audit et workflow');
  console.log('');
  console.log('Workflow:');
  console.log('  Client → Collecte empreinte → Opérateur → Génération licence');
  console.log('  → Livraison sécurisée → Installation client');
  console.log('');
  process.exit(0);
}

// Mode JSON uniquement
if (options.json) {
  const systemInfo = getSystemInfo();
  const machineFingerprint = getMachineFingerprint();
  const usbDevices = detectUSBDevices();
  
  const result = {
    timestamp: new Date().toISOString(),
    machineFingerprint,
    usbDevices: usbDevices.map(d => ({ label: d.label, serial: d.serial })),
    systemInfo: {
      hostname: systemInfo.hostname,
      platform: systemInfo.platform,
      arch: systemInfo.arch,
      username: systemInfo.userInfo.username
    }
  };
  
  console.log(JSON.stringify(result, null, 2));
  process.exit(0);
}

// Exécution normale
printBindings();