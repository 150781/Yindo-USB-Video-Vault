# Tests Automatiques CI - USB Video Vault
# Pipeline de tests pour les trois cas bloquants critiques

## Vue d'ensemble

Suite de tests automatisés pour valider les trois scénarios critiques de sécurité licence :
1. **Licence valide (kid actif)** → Application fonctionne
2. **Signature invalide** → Application refuse  
3. **Licence expirée / horloge reculée** → Application refuse

## Configuration CI

### GitHub Actions Workflow
```yaml
# .github/workflows/license-security-tests.yml
name: License Security Tests

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  schedule:
    # Tests quotidiens à 2h du matin
    - cron: '0 2 * * *'

jobs:
  license-security-tests:
    runs-on: windows-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        
    - name: Install dependencies
      run: npm ci
      
    - name: Build application
      run: npm run build
      
    - name: Setup test environment
      run: |
        # Créer environnement de test isolé
        New-Item -Path "test-vault" -ItemType Directory -Force
        $env:VAULT_PATH = "$PWD\test-vault"
        New-Item -Path "$env:VAULT_PATH\.vault" -ItemType Directory -Force
        
    - name: Run license security tests
      run: npm run test:license-security
      env:
        CI: true
        VAULT_PATH: test-vault
        
    - name: Upload test results
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: license-test-results
        path: |
          test-results/
          test-vault/
```

## Scripts de Test

### Test Principal
```javascript
// tests/license-security.test.js
const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const crypto = require('crypto');

// Configuration test
const TEST_CONFIG = {
  vaultPath: process.env.VAULT_PATH || './test-vault',
  appExecutable: './dist/win-unpacked/USB Video Vault.exe',
  timeout: 30000, // 30 secondes
  retries: 3
};

class LicenseTestSuite {
  constructor() {
    this.results = {
      validLicense: { passed: false, error: null },
      invalidSignature: { passed: false, error: null },
      expiredLicense: { passed: false, error: null }
    };
  }

  // Préparer environnement de test
  async setupTestEnvironment() {
    console.log('🔧 Configuration environnement de test...');
    
    // Créer structure vault
    const vaultDir = path.join(TEST_CONFIG.vaultPath, '.vault');
    if (!fs.existsSync(vaultDir)) {
      fs.mkdirSync(vaultDir, { recursive: true });
    }
    
    // Nettoyer anciens fichiers de test
    const licenseFile = path.join(vaultDir, 'license.bin');
    if (fs.existsSync(licenseFile)) {
      fs.unlinkSync(licenseFile);
    }
    
    console.log(`✅ Environnement préparé: ${TEST_CONFIG.vaultPath}`);
  }

  // Générer licence de test valide
  async generateValidLicense() {
    console.log('🔑 Génération licence valide...');
    
    // Utiliser le script de génération existant
    const fingerprint = 'test-machine-fingerprint-12345678';
    const expiration = new Date();
    expiration.setFullYear(expiration.getFullYear() + 1); // +1 an
    
    try {
      // Générer licence avec kid=999 (clé de test)
      const cmd = `node scripts/make-license.mjs "${fingerprint}" --kid 999 --exp "${expiration.toISOString()}"`;
      execSync(cmd, { 
        cwd: process.cwd(),
        env: { 
          ...process.env, 
          PACKAGER_PRIVATE_HEX: "test-private-key-for-ci-testing-only-999"
        }
      });
      
      // Copier vers vault de test
      const sourceLicense = './out/license.bin';
      const targetLicense = path.join(TEST_CONFIG.vaultPath, '.vault', 'license.bin');
      
      if (fs.existsSync(sourceLicense)) {
        fs.copyFileSync(sourceLicense, targetLicense);
        console.log('✅ Licence valide générée');
        return true;
      } else {
        throw new Error('Fichier licence non généré');
      }
      
    } catch (error) {
      console.error('❌ Erreur génération licence valide:', error.message);
      throw error;
    }
  }

  // Générer licence avec signature invalide
  async generateInvalidSignatureLicense() {
    console.log('⚠️ Génération licence signature invalide...');
    
    try {
      // Générer licence normale d'abord
      await this.generateValidLicense();
      
      // Corrompre la signature (derniers 64 bytes)
      const licenseFile = path.join(TEST_CONFIG.vaultPath, '.vault', 'license.bin');
      const licenseData = fs.readFileSync(licenseFile);
      
      // Modifier les derniers bytes (signature)
      const corruptedData = Buffer.from(licenseData);
      for (let i = corruptedData.length - 64; i < corruptedData.length; i++) {
        corruptedData[i] = corruptedData[i] ^ 0xFF; // Inverser bits
      }
      
      fs.writeFileSync(licenseFile, corruptedData);
      console.log('✅ Licence signature invalide générée');
      return true;
      
    } catch (error) {
      console.error('❌ Erreur génération licence signature invalide:', error.message);
      throw error;
    }
  }

  // Générer licence expirée
  async generateExpiredLicense() {
    console.log('⏰ Génération licence expirée...');
    
    const fingerprint = 'test-machine-fingerprint-12345678';
    const expiration = new Date();
    expiration.setFullYear(expiration.getFullYear() - 1); // -1 an (expirée)
    
    try {
      const cmd = `node scripts/make-license.mjs "${fingerprint}" --kid 999 --exp "${expiration.toISOString()}"`;
      execSync(cmd, { 
        cwd: process.cwd(),
        env: { 
          ...process.env, 
          PACKAGER_PRIVATE_HEX: "test-private-key-for-ci-testing-only-999"
        }
      });
      
      // Copier vers vault de test
      const sourceLicense = './out/license.bin';
      const targetLicense = path.join(TEST_CONFIG.vaultPath, '.vault', 'license.bin');
      
      if (fs.existsSync(sourceLicense)) {
        fs.copyFileSync(sourceLicense, targetLicense);
        console.log('✅ Licence expirée générée');
        return true;
      } else {
        throw new Error('Fichier licence expirée non généré');
      }
      
    } catch (error) {
      console.error('❌ Erreur génération licence expirée:', error.message);
      throw error;
    }
  }

  // Tester lancement application
  async testApplicationLaunch(testName, expectedOutcome) {
    console.log(`🧪 Test: ${testName}`);
    
    return new Promise((resolve) => {
      const startTime = Date.now();
      let appOutput = '';
      let appError = '';
      
      // Lancer application en mode test
      const app = spawn(TEST_CONFIG.appExecutable, ['--test-mode'], {
        cwd: process.cwd(),
        env: {
          ...process.env,
          VAULT_PATH: TEST_CONFIG.vaultPath,
          NODE_ENV: 'test'
        }
      });
      
      app.stdout.on('data', (data) => {
        appOutput += data.toString();
      });
      
      app.stderr.on('data', (data) => {
        appError += data.toString();
      });
      
      app.on('close', (code) => {
        const duration = Date.now() - startTime;
        
        const result = {
          testName,
          exitCode: code,
          duration,
          output: appOutput,
          error: appError,
          expectedOutcome,
          passed: false
        };
        
        // Analyser résultat selon attente
        switch (expectedOutcome) {
          case 'success':
            // Application doit démarrer sans erreur
            result.passed = (code === 0) && !appError.includes('licence') && !appError.includes('signature');
            break;
            
          case 'signature_rejected':
            // Application doit rejeter et mentionner signature
            result.passed = (code !== 0) && (
              appError.includes('signature invalide') || 
              appError.includes('invalid signature') ||
              appOutput.includes('signature invalide')
            );
            break;
            
          case 'expired_rejected':
            // Application doit rejeter et mentionner expiration
            result.passed = (code !== 0) && (
              appError.includes('expirée') || 
              appError.includes('expired') ||
              appError.includes('horloge') ||
              appOutput.includes('expirée')
            );
            break;
        }
        
        console.log(`${result.passed ? '✅' : '❌'} ${testName}: ${result.passed ? 'RÉUSSI' : 'ÉCHEC'} (${duration}ms)`);
        
        if (!result.passed) {
          console.log(`   Code de sortie: ${code}`);
          console.log(`   Sortie: ${appOutput.substring(0, 200)}...`);
          console.log(`   Erreur: ${appError.substring(0, 200)}...`);
        }
        
        resolve(result);
      });
      
      // Timeout de sécurité
      setTimeout(() => {
        app.kill('SIGTERM');
        resolve({
          testName,
          exitCode: -1,
          duration: TEST_CONFIG.timeout,
          output: appOutput,
          error: 'TIMEOUT',
          expectedOutcome,
          passed: false
        });
      }, TEST_CONFIG.timeout);
    });
  }

  // Exécuter suite complète de tests
  async runTestSuite() {
    console.log('🚀 DÉBUT TESTS SÉCURITÉ LICENCE');
    console.log('==============================');
    
    try {
      await this.setupTestEnvironment();
      
      // Test 1: Licence valide
      console.log('\n📋 TEST 1: LICENCE VALIDE');
      await this.generateValidLicense();
      this.results.validLicense = await this.testApplicationLaunch(
        'Licence valide (kid actif)',
        'success'
      );
      
      // Test 2: Signature invalide
      console.log('\n📋 TEST 2: SIGNATURE INVALIDE');
      await this.generateInvalidSignatureLicense();
      this.results.invalidSignature = await this.testApplicationLaunch(
        'Signature invalide',
        'signature_rejected'
      );
      
      // Test 3: Licence expirée
      console.log('\n📋 TEST 3: LICENCE EXPIRÉE');
      await this.generateExpiredLicense();
      this.results.expiredLicense = await this.testApplicationLaunch(
        'Licence expirée',
        'expired_rejected'
      );
      
      // Résumé final
      this.printTestResults();
      
      // Retourner code de sortie approprié
      const allPassed = Object.values(this.results).every(r => r.passed);
      process.exit(allPassed ? 0 : 1);
      
    } catch (error) {
      console.error('❌ ERREUR CRITIQUE TESTS:', error.message);
      process.exit(1);
    }
  }

  // Afficher résultats
  printTestResults() {
    console.log('\n📊 RÉSULTATS TESTS SÉCURITÉ LICENCE');
    console.log('===================================');
    
    const tests = [
      { name: 'Licence valide (kid actif)', result: this.results.validLicense },
      { name: 'Signature invalide rejetée', result: this.results.invalidSignature },
      { name: 'Licence expirée rejetée', result: this.results.expiredLicense }
    ];
    
    tests.forEach((test, index) => {
      const status = test.result.passed ? '✅ RÉUSSI' : '❌ ÉCHEC';
      const duration = test.result.duration ? `(${test.result.duration}ms)` : '';
      console.log(`${index + 1}. ${test.name}: ${status} ${duration}`);
      
      if (!test.result.passed && test.result.error) {
        console.log(`   Erreur: ${test.result.error}`);
      }
    });
    
    const passedCount = tests.filter(t => t.result.passed).length;
    const totalCount = tests.length;
    
    console.log(`\n🎯 RÉSULTAT GLOBAL: ${passedCount}/${totalCount} tests réussis`);
    
    if (passedCount === totalCount) {
      console.log('🎉 TOUS LES TESTS DE SÉCURITÉ PASSENT');
    } else {
      console.log('⚠️ CERTAINS TESTS DE SÉCURITÉ ÉCHOUENT - REVIEW NÉCESSAIRE');
    }
    
    // Sauvegarder résultats pour CI
    const resultsFile = './test-results/license-security-results.json';
    const resultsDir = path.dirname(resultsFile);
    if (!fs.existsSync(resultsDir)) {
      fs.mkdirSync(resultsDir, { recursive: true });
    }
    
    const fullResults = {
      timestamp: new Date().toISOString(),
      environment: 'CI',
      totalTests: totalCount,
      passedTests: passedCount,
      failedTests: totalCount - passedCount,
      tests: this.results
    };
    
    fs.writeFileSync(resultsFile, JSON.stringify(fullResults, null, 2));
    console.log(`📁 Résultats sauvegardés: ${resultsFile}`);
  }
}

// Exécution si script principal
if (require.main === module) {
  const testSuite = new LicenseTestSuite();
  testSuite.runTestSuite();
}

module.exports = LicenseTestSuite;
```

### Script NPM
```json
{
  "scripts": {
    "test:license-security": "node tests/license-security.test.js",
    "test:license-security:verbose": "node tests/license-security.test.js --verbose",
    "test:ci": "npm run build && npm run test:license-security"
  }
}
```

## Intégration Continue

### Tests Locaux
```bash
# Tests complets
npm run test:license-security

# Avec sortie détaillée
npm run test:license-security:verbose

# Tests CI complets
npm run test:ci
```

### Monitoring CI
- **Tests quotidiens** automatiques
- **Alertes** en cas d'échec
- **Rapports** détaillés avec logs
- **Historique** des résultats

Cette suite de tests garantit que les mécanismes de sécurité licence fonctionnent correctement et détecte toute régression dans la validation des licences.