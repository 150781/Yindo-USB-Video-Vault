#!/usr/bin/env node

import { execSync } from 'child_process';
import { existsSync } from 'fs';
import path from 'path';

const BUILD_PATH = './usb-package/USB-Video-Vault-0.1.0-portable.exe';
const VAULT_PATH = './usb-package/vault';

async function testPortableBuild() {
  console.log('🚀 === VALIDATION BUILD PORTABLE RC ===\n');
  
  // Vérifications préliminaires
  console.log('📋 Vérifications initiales...');
  console.log(`   📦 Build portable: ${existsSync(BUILD_PATH) ? '✅' : '❌'}`);
  console.log(`   📁 Vault présent: ${existsSync(VAULT_PATH) ? '✅' : '❌'}`);
  console.log(`   📄 Licence: ${existsSync(path.join(VAULT_PATH, 'license.json')) ? '✅' : '❌'}`);
  console.log(`   📊 Manifest: ${existsSync(path.join(VAULT_PATH, '.vault', 'manifest.bin')) ? '✅' : '❌'}`);
  console.log(`   🎥 Médias: ${existsSync(path.join(VAULT_PATH, 'media')) ? '✅' : '❌'}`);
  
  const tests = [
    {
      name: 'Lancement build portable',
      test: async () => {
        console.log('   🎯 Test de lancement avec licence valide...');
        
        try {
          const result = execSync(
            `cd usb-package; $env:VAULT_PATH = ".\\vault"; $env:FORCE_PRODUCTION = "true"; .\\USB-Video-Vault-0.1.0-portable.exe --no-sandbox`,
            { 
              timeout: 8000,
              stdio: 'pipe',
              encoding: 'utf8',
              shell: 'powershell'
            }
          );
          
          console.log('   ❌ App ne devrait pas se lancer sans quit (timeout attendu)');
          return false;
          
        } catch (error) {
          const output = error.stdout || error.stderr || '';
          const isTimeout = error.message.includes('ETIMEDOUT');
          
          if (isTimeout) {
            console.log('   ✅ App se lance et reste active (timeout = succès)');
            return true;
          }
          
          const hasValidStartup = output.includes('[LICENSE]') && 
                                  output.includes('✅ Licence sécurisée valide') ||
                                  output.includes('[vault] ready');
          
          if (hasValidStartup) {
            console.log('   ✅ App démarre correctement avec licence valide');
            return true;
          }
          
          console.log('   ❌ Erreur inattendue:', error.message);
          console.log('   Output:', output.substring(0, 200) + '...');
          return false;
        }
      }
    },
    
    {
      name: 'Sécurité licence expirée',
      test: async () => {
        console.log('   🛡️ Test sécurité avec licence expirée...');
        
        try {
          // D'abord copier la licence expirée
          execSync('Copy-Item "usb-package\\vault\\license-test-expired.json" "usb-package\\vault\\license.json" -Force', { shell: 'powershell' });
          
          // Puis tester l'app
          const result = execSync(
            `cd usb-package; $env:VAULT_PATH = ".\\vault"; $env:FORCE_PRODUCTION = "true"; .\\USB-Video-Vault-0.1.0-portable.exe --no-sandbox`,
            { 
              timeout: 8000,
              stdio: 'pipe',
              encoding: 'utf8',
              shell: 'powershell'
            }
          );
          
          console.log('   ❌ App ne devrait pas accepter licence expirée');
          return false;
          
        } catch (error) {
          const output = error.stdout || error.stderr || '';
          const exitCode = error.status || 0;
          
          const isBlocked = output.includes('Licence expirée') || 
                           output.includes('QUITTING') || 
                           output.includes('bloquée') ||
                           exitCode !== 0;
          
          if (isBlocked) {
            console.log('   ✅ App refuse licence expirée et quit');
            return true;
          }
          
          console.log('   ❌ App n\'a pas bloqué licence expirée');
          console.log('   Exit code:', exitCode);
          console.log('   Full output:', output);
          return false;
        } finally {
          // Restaurer la licence valide
          try {
            execSync('Copy-Item "usb-package\\vault\\license.json.backup" "usb-package\\vault\\license.json" -Force', { shell: 'powershell' });
          } catch (e) {
            console.warn('   ⚠️ Erreur restauration licence:', e.message);
          }
        }
      }
    }
  ];
  
  const results = [];
  
  for (const test of tests) {
    console.log(`\\n🔍 Test: ${test.name}...`);
    try {
      const passed = await test.test();
      results.push({ name: test.name, passed });
    } catch (error) {
      console.error(`   ❌ Erreur: ${error.message}`);
      results.push({ name: test.name, passed: false });
    }
  }
  
  // Rapport final
  console.log('\\n📊 === RAPPORT FINAL ===');
  
  let allPassed = true;
  for (const result of results) {
    const status = result.passed ? '✅' : '❌';
    const label = result.passed ? 'RÉUSSI' : 'ÉCHOUÉ';
    console.log(`${status} ${result.name}: ${label}`);
    if (!result.passed) allPassed = false;
  }
  
  if (allPassed) {
    console.log('\\n🎉 BUILD RC VALIDÉ - Prêt pour déploiement !');
  } else {
    console.log('\\n⚠️ PROBLÈMES DÉTECTÉS - Build nécessite corrections');
  }
  
  return allPassed;
}

// Exécution
testPortableBuild().catch(console.error);