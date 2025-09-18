#!/usr/bin/env node

/**
 * TESTS ROUGES - Scénarios d'échec complets
 * Valide que tous les cas d'attaque/corruption échouent proprement
 */

import { execSync } from 'child_process';
import { existsSync, copyFileSync, unlinkSync, writeFileSync, readFileSync } from 'fs';
import path from 'path';

const VAULT_PATH = './usb-package/vault';

console.log('🔴 === TESTS ROUGES (SCÉNARIOS D\'ÉCHEC) ===\n');

const redTeamTests = [
  {
    name: 'Licence expirée',
    setup: () => {
      // Utiliser la licence expirée
      copyFileSync(
        path.join(VAULT_PATH, 'license-test-expired.json'),
        path.join(VAULT_PATH, 'license.json')
      );
      console.log('   🕒 Licence expirée activée');
    },
    expectedError: /licence.*expir|LICENSE.*expir|invalid|QUITTING/i,
    cleanup: () => {
      if (existsSync(path.join(VAULT_PATH, 'license.json.backup'))) {
        copyFileSync(
          path.join(VAULT_PATH, 'license.json.backup'),
          path.join(VAULT_PATH, 'license.json')
        );
      }
    }
  },
  
  {
    name: 'Licence supprimée',
    setup: () => {
      // Backup et suppression
      copyFileSync(
        path.join(VAULT_PATH, 'license.json'),
        path.join(VAULT_PATH, 'license.json.backup2')
      );
      unlinkSync(path.join(VAULT_PATH, 'license.json'));
      console.log('   🗑️ Licence supprimée');
    },
    expectedError: /license.*not found|ENOENT|invalid|QUITTING/i,
    cleanup: () => {
      if (existsSync(path.join(VAULT_PATH, 'license.json.backup2'))) {
        copyFileSync(
          path.join(VAULT_PATH, 'license.json.backup2'),
          path.join(VAULT_PATH, 'license.json')
        );
        unlinkSync(path.join(VAULT_PATH, 'license.json.backup2'));
      }
    }
  },
  
  {
    name: 'Manifest corrompu',
    setup: () => {
      const manifestPath = path.join(VAULT_PATH, '.vault', 'manifest.bin');
      if (existsSync(manifestPath)) {
        copyFileSync(manifestPath, manifestPath + '.backup');
        writeFileSync(manifestPath, 'CORRUPTED_MANIFEST_DATA');
        console.log('   💀 Manifest corrompu');
      }
    },
    expectedError: /manifest.*corrupt|vault.*error|invalid|QUITTING/i,
    cleanup: () => {
      const manifestPath = path.join(VAULT_PATH, '.vault', 'manifest.bin');
      const backupPath = manifestPath + '.backup';
      if (existsSync(backupPath)) {
        copyFileSync(backupPath, manifestPath);
        unlinkSync(backupPath);
      }
    }
  },
  
  {
    name: 'Fichier média corrompu',
    setup: () => {
      // Corrompre le fichier .enc
      execSync(`node tools/corrupt-file.mjs "${VAULT_PATH}/media/ab2e3722-c60b-4d1c-b9a1-5ef9ddc6d612.enc"`, { stdio: 'pipe' });
      
      // Remplacer l'original par la version corrompue
      copyFileSync(
        path.join(VAULT_PATH, 'media', 'ab2e3722-c60b-4d1c-b9a1-5ef9ddc6d612.enc'),
        path.join(VAULT_PATH, 'media', 'ab2e3722-c60b-4d1c-b9a1-5ef9ddc6d612.enc.original')
      );
      copyFileSync(
        path.join(VAULT_PATH, 'media', 'ab2e3722-c60b-4d1c-b9a1-5ef9ddc6d612.enc.corrupt'),
        path.join(VAULT_PATH, 'media', 'ab2e3722-c60b-4d1c-b9a1-5ef9ddc6d612.enc')
      );
      console.log('   🔐 Fichier média corrompu (auth fail attendu)');
    },
    expectedError: /auth.*fail|tag.*fail|decrypt.*error|GCM.*error/i,
    cleanup: () => {
      const originalPath = path.join(VAULT_PATH, 'media', 'ab2e3722-c60b-4d1c-b9a1-5ef9ddc6d612.enc.original');
      const currentPath = path.join(VAULT_PATH, 'media', 'ab2e3722-c60b-4d1c-b9a1-5ef9ddc6d612.enc');
      const corruptPath = path.join(VAULT_PATH, 'media', 'ab2e3722-c60b-4d1c-b9a1-5ef9ddc6d612.enc.corrupt');
      
      if (existsSync(originalPath)) {
        copyFileSync(originalPath, currentPath);
        unlinkSync(originalPath);
      }
      if (existsSync(corruptPath)) {
        unlinkSync(corruptPath);
      }
    }
  }
];

async function testFailureScenario(scenario) {
  console.log(`🔍 Test: ${scenario.name}...`);
  
  try {
    // Setup
    scenario.setup();
    
    // Test de l'app (doit échouer)
    const result = execSync(
      `$env:VAULT_PATH = "${VAULT_PATH}"; $env:FORCE_PRODUCTION = "true"; npx electron dist/main/index.js --no-sandbox`,
      { 
        timeout: 8000,
        stdio: 'pipe',
        encoding: 'utf8',
        shell: 'powershell'
      }
    );
    
    console.log('   ❌ PROBLÈME: App ne devrait pas se lancer');
    return false;
    
  } catch (error) {
    const output = error.stdout || error.stderr || '';
    const exitCode = error.status || 0;
    
    const hasExpectedError = scenario.expectedError.test(output) || exitCode !== 0;
    
    if (hasExpectedError) {
      console.log('   ✅ Échec attendu détecté');
      console.log('   💡 Erreur:', output.match(scenario.expectedError)?.[0] || 'Exit code non-zéro');
      return true;
    } else {
      console.log('   ❌ Échec inattendu:', error.message);
      console.log('   📋 Output:', output.substring(0, 200) + '...');
      return false;
    }
  } finally {
    // Cleanup
    try {
      scenario.cleanup();
    } catch (e) {
      console.warn('   ⚠️ Erreur cleanup:', e.message);
    }
  }
}

async function runRedTeamTests() {
  const results = [];
  
  for (const test of redTeamTests) {
    try {
      const passed = await testFailureScenario(test);
      results.push({ name: test.name, passed });
    } catch (error) {
      console.error(`   ❌ Erreur test: ${error.message}`);
      results.push({ name: test.name, passed: false });
    }
  }
  
  // Rapport final
  console.log('\n📊 === RAPPORT TESTS ROUGES ===');
  
  let allPassed = true;
  for (const result of results) {
    const status = result.passed ? '✅' : '❌';
    const label = result.passed ? 'BLOQUÉ' : 'ÉCHEC';
    console.log(`${status} ${result.name}: ${label}`);
    if (!result.passed) allPassed = false;
  }
  
  if (allPassed) {
    console.log('\n🛡️ SÉCURITÉ VALIDÉE - Tous les scénarios d\'attaque sont bloqués');
  } else {
    console.log('\n⚠️ VULNÉRABILITÉS DÉTECTÉES - Certains scénarios passent');
  }
  
  return allPassed;
}

// Exécution
runRedTeamTests().catch(console.error);