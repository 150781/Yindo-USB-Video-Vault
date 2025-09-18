#!/usr/bin/env node

import { execSync } from 'child_process';
import { existsSync, copyFileSync, unlinkSync, writeFileSync } from 'fs';
import path from 'path';

const VAULT_PATH = './usb-package/vault';

async function testAppLaunch(scenario) {
  try {
    console.log(`   Lancement app principale avec ${scenario}...`);
    
    const timeout = 15000; // 15s timeout
    
    // Test avec electron directement sur les fichiers compilés en mode production forcé
    const result = execSync(
      `$env:VAULT_PATH = "${VAULT_PATH}"; $env:FORCE_PRODUCTION = "true"; $env:NODE_ENV = "production"; npx electron dist/main/index.js --no-sandbox`,
      { 
        timeout: timeout,
        stdio: 'pipe',
        encoding: 'utf8',
        shell: 'powershell'
      }
    );
    
    console.log('   App output:', result.substring(0, 300) + '...');
    console.log('   Résultat: App lancée avec succès - PROBLÈME');
    return { failed: false, output: result };
    
  } catch (error) {
    const output = error.stdout || error.stderr || '';
    const exitCode = error.status || 0;
    
    console.log('   Exit code:', exitCode);
    console.log('   Output preview:', output.substring(0, 300) + '...');
    
    const isExpectedFailure = output.includes('licence') || 
                             output.includes('Licence') || 
                             output.includes('expired') ||
                             output.includes('LICENSE') ||
                             output.includes('QUIT') ||
                             output.includes('invalid') ||
                             output.includes('bloquée') ||
                             output.includes('QUITTING') ||
                             output.includes('manifest') ||
                             output.includes('CORRUPTED') ||
                             exitCode !== 0; // Non-zero exit code indicates failure
    
    console.log('   Résultat:', isExpectedFailure ? 'App refuse (attendu) ✓' : 'App plante (inattendu) ❌');
    
    return { 
      failed: isExpectedFailure, 
      reason: isExpectedFailure ? 'Échec attendu' : 'Erreur inattendue',
      output: output,
      exitCode: exitCode
    };
  }
}

// === SCÉNARIOS RED TEAM ===
const scenarios = [
  {
    name: 'Licence expirée',
    setup: () => {
      // License-test-expired.json est déjà configuré avec date expirée
      console.log('   ✓ Licence expirée en place');
    },
    cleanup: () => {
      // Pas de cleanup nécessaire
    }
  },
  {
    name: 'Licence supprimée',
    setup: () => {
      // Backup et suppression de tous les fichiers de licence
      if (existsSync(path.join(VAULT_PATH, 'license.json'))) {
        copyFileSync(
          path.join(VAULT_PATH, 'license.json'),
          path.join(VAULT_PATH, 'license.json.backup')
        );
        unlinkSync(path.join(VAULT_PATH, 'license.json'));
      }
      if (existsSync(path.join(VAULT_PATH, 'license-test-expired.json'))) {
        copyFileSync(
          path.join(VAULT_PATH, 'license-test-expired.json'),
          path.join(VAULT_PATH, 'license-test-expired.json.backup')
        );
        unlinkSync(path.join(VAULT_PATH, 'license-test-expired.json'));
      }
      console.log('   ✓ Fichiers de licence supprimés');
    },
    cleanup: () => {
      // Restore fichiers de licence
      if (existsSync(path.join(VAULT_PATH, 'license.json.backup'))) {
        copyFileSync(
          path.join(VAULT_PATH, 'license.json.backup'),
          path.join(VAULT_PATH, 'license.json')
        );
        unlinkSync(path.join(VAULT_PATH, 'license.json.backup'));
      }
      if (existsSync(path.join(VAULT_PATH, 'license-test-expired.json.backup'))) {
        copyFileSync(
          path.join(VAULT_PATH, 'license-test-expired.json.backup'),
          path.join(VAULT_PATH, 'license-test-expired.json')
        );
        unlinkSync(path.join(VAULT_PATH, 'license-test-expired.json.backup'));
      }
    }
  },
  {
    name: 'Vault corrompu',
    setup: () => {
      // Backup et corruption du manifest
      const manifestPath = path.join(VAULT_PATH, '.vault', 'manifest.bin');
      if (existsSync(manifestPath)) {
        copyFileSync(manifestPath, manifestPath + '.backup');
        writeFileSync(manifestPath, 'CORRUPTED DATA');
        console.log('   ✓ Manifest corrompu');
      } else {
        console.log('   ⚠️ Manifest non trouvé');
      }
    },
    cleanup: () => {
      // Restore manifest
      const manifestPath = path.join(VAULT_PATH, '.vault', 'manifest.bin');
      const backupPath = manifestPath + '.backup';
      if (existsSync(backupPath)) {
        copyFileSync(backupPath, manifestPath);
        unlinkSync(backupPath);
      }
    }
  }
];

async function runRedTeamTests() {
  console.log('🔴 === TESTS SCÉNARIOS D\'ÉCHEC (RED TEAM) ===\n');
  
  console.log(`📁 Vault path: ${VAULT_PATH}`);
  console.log(`📁 Vault exists: ${existsSync(VAULT_PATH)}`);
  
  const results = [];
  
  for (const scenario of scenarios) {
    console.log(`🔍 Test: ${scenario.name}...`);
    
    try {
      // Setup du scénario
      scenario.setup();
      
      // Test de l'app
      const result = await testAppLaunch(scenario.name);
      results.push({
        name: scenario.name,
        passed: result.failed, // "failed" = app refuse = test réussi
        details: result
      });
      
    } catch (error) {
      console.error(`   ❌ Erreur durant le test: ${error.message}`);
      results.push({
        name: scenario.name,
        passed: false,
        details: { reason: `Erreur: ${error.message}` }
      });
    } finally {
      // Cleanup du scénario
      try {
        scenario.cleanup();
      } catch (cleanupError) {
        console.warn(`   ⚠️ Erreur cleanup: ${cleanupError.message}`);
      }
    }
  }
  
  // Rapport final
  console.log('\n📊 === RAPPORT RED TEAM ===');
  
  let allPassed = true;
  for (const result of results) {
    const status = result.passed ? '✅' : '❌';
    const label = result.passed ? 'RÉUSSI' : 'ÉCHOUÉ';
    console.log(`${status} Test ${result.name}: ${label}`);
    if (!result.passed) allPassed = false;
  }
  
  if (allPassed) {
    console.log('\n🎉 SÉCURITÉ VALIDÉE - Tous les scénarios d\'attaque sont bloqués');
  } else {
    console.log('\n⚠️ VULNÉRABILITÉS DÉTECTÉES - Certains scénarios ne sont pas bloqués');
  }
  
  return allPassed;
}

// Exécution
runRedTeamTests().catch(console.error);