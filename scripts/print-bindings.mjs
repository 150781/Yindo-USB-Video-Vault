#!/usr/bin/env node
// scripts/print-bindings.mjs
// Obtient l'empreinte machine pour génération de licence (VERSION PRODUCTION)

/**
 * Version simplifiée qui utilise les mêmes algorithmes que l'app
 */

import os from 'os';
import crypto from 'crypto';

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
 * Détecte le numéro de série USB (simulation)
 */
function detectUSBSerial() {
  // En production, ceci utiliserait les APIs système appropriées
  // Pour le moment, on simule ou on retourne null si pas USB
  return null; // ou une vraie détection selon l'OS
}

/**
 * Affiche les informations de binding
 */
async function printBindings() {
  try {
    console.log('');
    console.log('🔍 INFORMATIONS DE BINDING LICENCE');
    console.log('===================================');
    console.log('');
    
    // Empreinte machine
    console.log('📋 Génération de l\'empreinte machine...');
    const machineFingerprint = getMachineFingerprint();
    
    console.log('');
    console.log('💻 EMPREINTE MACHINE:');
    console.log(`    ${machineFingerprint}`);
    console.log('');
    
    // USB (si disponible)
    const usbSerial = detectUSBSerial();
    if (usbSerial) {
      console.log('📀 NUMÉRO DE SÉRIE USB:');
      console.log(`    ${usbSerial}`);
      console.log('');
      console.log('🎯 COMMANDE GÉNÉRATION (avec USB):');
      console.log(`    $env:PACKAGER_PRIVATE_HEX = "9657aecb25..."; node scripts/make-license.mjs "${machineFingerprint}" "${usbSerial}"`);
    } else {
      console.log('📀 USB: Aucune clé USB détectée (ou mode desktop)');
      console.log('');
      console.log('🎯 COMMANDE GÉNÉRATION:');
      console.log(`    $env:PACKAGER_PRIVATE_HEX = "9657aecb25..."; node scripts/make-license.mjs "${machineFingerprint}"`);
    }
    
    console.log('');
    console.log('📋 INFORMATIONS SYSTÈME:');
    console.log(`    OS: ${os.platform()} ${os.arch()}`);
    console.log(`    Hostname: ${os.hostname()}`);
    console.log(`    CPU: ${os.cpus()[0]?.model || 'Unknown'} (${os.cpus().length} cores)`);
    console.log(`    RAM: ${Math.floor(os.totalmem() / (1024 * 1024 * 1024))} GB`);
    console.log(`    Date: ${new Date().toISOString()}`);
    console.log('');
    
    // Format pour copier-coller opérateur
    console.log('📝 COPIER-COLLER OPÉRATEUR:');
    console.log('============================');
    console.log(`Machine: ${machineFingerprint}`);
    if (usbSerial) {
      console.log(`USB: ${usbSerial}`);
    }
    console.log(`OS: ${os.platform()}`);
    console.log(`Date: ${new Date().toLocaleDateString()}`);
    console.log('============================');
    console.log('');
    
    // Instructions suivantes
    console.log('📌 ÉTAPES SUIVANTES:');
    console.log('1. Copier l\'empreinte machine ci-dessus');
    console.log('2. Sur le serveur de génération:');
    console.log('   $env:PACKAGER_PRIVATE_HEX = "<clé_privée_sécurisée>"');
    console.log(`   node scripts/make-license.mjs "${machineFingerprint}"`);
    console.log('3. Livrer license.bin au client');
    console.log('4. Client: copier dans .vault/license.bin');
    console.log('');
    
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    console.error('');
    console.error('💡 Solutions:');
    console.error('   - Vérifier les permissions système');
    console.error('   - Relancer en tant qu\'administrateur');
    process.exit(1);
  }
}

// Aide
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log('');
  console.log('🔍 PRINT-BINDINGS - Outil de binding licence');
  console.log('==============================================');
  console.log('');
  console.log('Génère l\'empreinte machine unique nécessaire pour');
  console.log('créer une licence liée à cette machine.');
  console.log('');
  console.log('Usage:');
  console.log('  node scripts/print-bindings.mjs');
  console.log('  node scripts/print-bindings.mjs --help');
  console.log('');
  console.log('Sorties:');
  console.log('  - Empreinte machine (32 chars hex)');
  console.log('  - Numéro série USB (si applicable)');
  console.log('  - Commande génération de licence');
  console.log('  - Informations système');
  console.log('');
  console.log('Note: Cette empreinte doit être identique à celle');
  console.log('générée par l\'application sur la même machine.');
  console.log('');
  process.exit(0);
}

// Exécution
printBindings();