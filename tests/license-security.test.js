// Tests automatiques CI - USB Video Vault
// Pipeline de tests pour les trois cas bloquants critiques

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const crypto = require('crypto');

// Configuration test
const TEST_CONFIG = {
  vaultPath: process.env.VAULT_PATH || './test-vault',
  appExecutable: process.env.APP_EXECUTABLE || './dist/win-unpacked/USB Video Vault.exe',
  timeout: 30000, // 30 secondes
  retries: 3,
  verbose: process.argv.includes('--verbose')
};

class LicenseSecurityTests {
  constructor() {
    this.results = {
      validLicense: { passed: false, error: null, duration: 0 },
      invalidSignature: { passed: false, error: null, duration: 0 },
      expiredLicense: { passed: false, error: null, duration: 0 }
    };
    
    this.startTime = Date.now();
  }

  log(message, level = 'info') {
    const timestamp = new Date().toISOString().substring(11, 19);
    const prefix = {
      'info': '🔧',
      'success': '✅',
      'error': '❌',
      'warning': '⚠️',
      'test': '🧪'
    }[level] || 'ℹ️';
    
    console.log(`[${timestamp}] ${prefix} ${message}`);
  }

  // Préparer environnement de test
  async setupTestEnvironment() {
    this.log('Configuration environnement de test...');
    
    try {
      // Créer structure vault
      const vaultDir = path.join(TEST_CONFIG.vaultPath, '.vault');
      if (!fs.existsSync(vaultDir)) {
        fs.mkdirSync(vaultDir, { recursive: true });
      }
      
      // Créer dossier résultats
      const resultsDir = './test-results';
      if (!fs.existsSync(resultsDir)) {
        fs.mkdirSync(resultsDir, { recursive: true });
      }
      
      // Nettoyer anciens fichiers de test
      const licenseFile = path.join(vaultDir, 'license.bin');
      if (fs.existsSync(licenseFile)) {
        fs.unlinkSync(licenseFile);
      }
      
      // Nettoyer anciens résultats de licence
      const outDir = './out';
      if (fs.existsSync(outDir)) {
        const files = fs.readdirSync(outDir);
        files.forEach(file => {
          if (file.endsWith('.bin')) {
            fs.unlinkSync(path.join(outDir, file));
          }
        });
      }
      
      this.log(`Environnement préparé: ${TEST_CONFIG.vaultPath}`, 'success');
      
    } catch (error) {
      this.log(`Erreur configuration environnement: ${error.message}`, 'error');
      throw error;
    }
  }

  // Vérifier prérequis
  async checkPrerequisites() {
    this.log('Vérification prérequis...');
    
    const checks = [
      { file: 'scripts/make-license.mjs', name: 'Script génération licence' },
      { file: 'scripts/verify-license.mjs', name: 'Script vérification licence' },
      { file: 'package.json', name: 'Package.json' }
    ];
    
    for (const check of checks) {
      if (!fs.existsSync(check.file)) {
        throw new Error(`Prérequis manquant: ${check.name} (${check.file})`);
      }
    }
    
    // Vérifier que l'app est buildée
    if (!fs.existsSync(TEST_CONFIG.appExecutable)) {
      this.log(`Application non trouvée: ${TEST_CONFIG.appExecutable}`, 'warning');
      this.log('Tentative de build...', 'info');
      
      try {
        execSync('npm run build', { stdio: 'inherit' });
        
        if (!fs.existsSync(TEST_CONFIG.appExecutable)) {
          throw new Error(`Application toujours non trouvée après build: ${TEST_CONFIG.appExecutable}`);
        }
        
      } catch (buildError) {
        throw new Error(`Échec build application: ${buildError.message}`);
      }
    }
    
    this.log('Prérequis validés', 'success');
  }

  // Générer licence de test valide
  async generateValidLicense() {
    this.log('Génération licence valide...');
    
    const fingerprint = 'test-ci-machine-fingerprint-valid-12345';
    const expiration = new Date();
    expiration.setFullYear(expiration.getFullYear() + 1); // +1 an
    
    try {
      // Créer dossier out si nécessaire
      if (!fs.existsSync('./out')) {
        fs.mkdirSync('./out');
      }
      
      // Générer licence avec clé de test
      const cmd = `node scripts/make-license.mjs "${fingerprint}" --out "./out/license-valid.bin"`;
      
      if (TEST_CONFIG.verbose) {
        this.log(`Commande: ${cmd}`);
      }
      
      const output = execSync(cmd, { 
        cwd: process.cwd(),
        encoding: 'utf8',
        env: { 
          ...process.env,
          // Utiliser clé de test prédéfinie
          PACKAGER_PRIVATE_HEX: "a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a"
        }
      });
      
      if (TEST_CONFIG.verbose) {
        this.log(`Sortie génération: ${output}`);
      }
      
      // Copier vers vault de test
      const sourceLicense = './out/license-valid.bin';
      const targetLicense = path.join(TEST_CONFIG.vaultPath, '.vault', 'license.bin');
      
      if (fs.existsSync(sourceLicense)) {
        fs.copyFileSync(sourceLicense, targetLicense);
        this.log('Licence valide générée et copiée', 'success');
        return true;
      } else {
        throw new Error('Fichier licence valide non généré');
      }
      
    } catch (error) {
      this.log(`Erreur génération licence valide: ${error.message}`, 'error');
      throw error;
    }
  }

  // Générer licence avec signature invalide
  async generateInvalidSignatureLicense() {
    this.log('Génération licence signature invalide...');
    
    try {
      // Générer licence normale d'abord
      await this.generateValidLicense();
      
      // Corrompre la signature (derniers 64 bytes)
      const licenseFile = path.join(TEST_CONFIG.vaultPath, '.vault', 'license.bin');
      const licenseData = fs.readFileSync(licenseFile);
      
      if (licenseData.length < 64) {
        throw new Error('Fichier licence trop petit pour corruption signature');
      }
      
      // Modifier les derniers bytes (signature)
      const corruptedData = Buffer.from(licenseData);
      for (let i = Math.max(0, corruptedData.length - 64); i < corruptedData.length; i++) {
        corruptedData[i] = corruptedData[i] ^ 0xFF; // Inverser tous les bits
      }
      
      fs.writeFileSync(licenseFile, corruptedData);
      this.log('Licence signature invalide générée', 'success');
      return true;
      
    } catch (error) {
      this.log(`Erreur génération licence signature invalide: ${error.message}`, 'error');
      throw error;
    }
  }

  // Générer licence expirée
  async generateExpiredLicense() {
    this.log('Génération licence expirée...');
    
    const fingerprint = 'test-ci-machine-fingerprint-expired-12345';
    const expiration = new Date();
    expiration.setFullYear(expiration.getFullYear() - 1); // -1 an (expirée)
    
    try {
      const cmd = `node scripts/make-license.mjs "${fingerprint}" --out "./out/license-expired.bin"`;
      
      if (TEST_CONFIG.verbose) {
        this.log(`Commande: ${cmd}`);
      }
      
      const output = execSync(cmd, { 
        cwd: process.cwd(),
        encoding: 'utf8',
        env: { 
          ...process.env,
          PACKAGER_PRIVATE_HEX: "a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789a",
          LICENSE_EXPIRATION: expiration.toISOString()
        }
      });
      
      if (TEST_CONFIG.verbose) {
        this.log(`Sortie génération: ${output}`);
      }
      
      // Copier vers vault de test
      const sourceLicense = './out/license-expired.bin';
      const targetLicense = path.join(TEST_CONFIG.vaultPath, '.vault', 'license.bin');
      
      if (fs.existsSync(sourceLicense)) {
        fs.copyFileSync(sourceLicense, targetLicense);
        this.log('Licence expirée générée et copiée', 'success');
        return true;
      } else {
        throw new Error('Fichier licence expirée non généré');
      }
      
    } catch (error) {
      this.log(`Erreur génération licence expirée: ${error.message}`, 'error');
      throw error;
    }
  }

  // Tester lancement application
  async testApplicationLaunch(testName, expectedOutcome) {
    this.log(`Test: ${testName}`, 'test');
    
    return new Promise((resolve) => {
      const startTime = Date.now();
      let appOutput = '';
      let appError = '';
      let resolved = false;
      
      // Lancer application en mode test
      const appArgs = ['--test-mode', '--no-gui'];
      const app = spawn(TEST_CONFIG.appExecutable, appArgs, {
        cwd: process.cwd(),
        env: {
          ...process.env,
          VAULT_PATH: TEST_CONFIG.vaultPath,
          NODE_ENV: 'test',
          ELECTRON_IS_DEV: '0'
        }
      });
      
      app.stdout.on('data', (data) => {
        const text = data.toString();
        appOutput += text;
        if (TEST_CONFIG.verbose) {
          console.log(`[APP OUT] ${text.trim()}`);
        }
      });
      
      app.stderr.on('data', (data) => {
        const text = data.toString();
        appError += text;
        if (TEST_CONFIG.verbose) {
          console.log(`[APP ERR] ${text.trim()}`);
        }
      });
      
      app.on('close', (code) => {
        if (resolved) return;
        resolved = true;
        
        const duration = Date.now() - startTime;
        
        const result = {
          testName,
          exitCode: code,
          duration,
          output: appOutput,
          error: appError,
          expectedOutcome,
          passed: false,
          timestamp: new Date().toISOString()
        };
        
        // Analyser résultat selon attente
        switch (expectedOutcome) {
          case 'success':
            // Application doit démarrer sans erreur licence
            result.passed = (code === 0) && 
              !appError.toLowerCase().includes('licence') && 
              !appError.toLowerCase().includes('license') &&
              !appError.toLowerCase().includes('signature') &&
              !appError.toLowerCase().includes('expired');
            break;
            
          case 'signature_rejected':
            // Application doit rejeter et mentionner signature
            const sigErrorFound = appError.toLowerCase().includes('signature') || 
              appOutput.toLowerCase().includes('signature') ||
              appError.toLowerCase().includes('invalide') ||
              appOutput.toLowerCase().includes('invalid');
            result.passed = (code !== 0) && sigErrorFound;
            break;
            
          case 'expired_rejected':
            // Application doit rejeter et mentionner expiration
            const expErrorFound = appError.toLowerCase().includes('expir') || 
              appOutput.toLowerCase().includes('expir') ||
              appError.toLowerCase().includes('horloge') ||
              appOutput.toLowerCase().includes('clock');
            result.passed = (code !== 0) && expErrorFound;
            break;
        }
        
        const status = result.passed ? 'RÉUSSI' : 'ÉCHEC';
        const level = result.passed ? 'success' : 'error';
        this.log(`${testName}: ${status} (${duration}ms, code: ${code})`, level);
        
        if (!result.passed && TEST_CONFIG.verbose) {
          this.log(`Sortie application: ${appOutput.substring(0, 300)}...`);
          this.log(`Erreur application: ${appError.substring(0, 300)}...`);
        }
        
        resolve(result);
      });
      
      app.on('error', (error) => {
        if (resolved) return;
        resolved = true;
        
        const result = {
          testName,
          exitCode: -2,
          duration: Date.now() - startTime,
          output: '',
          error: `Erreur spawn: ${error.message}`,
          expectedOutcome,
          passed: false,
          timestamp: new Date().toISOString()
        };
        
        this.log(`${testName}: ERREUR SPAWN (${error.message})`, 'error');
        resolve(result);
      });
      
      // Timeout de sécurité
      setTimeout(() => {
        if (resolved) return;
        resolved = true;
        
        app.kill('SIGTERM');
        
        // Force kill après 5 secondes
        setTimeout(() => {
          try {
            app.kill('SIGKILL');
          } catch (e) {}
        }, 5000);
        
        const result = {
          testName,
          exitCode: -1,
          duration: TEST_CONFIG.timeout,
          output: appOutput,
          error: 'TIMEOUT',
          expectedOutcome,
          passed: false,
          timestamp: new Date().toISOString()
        };
        
        this.log(`${testName}: TIMEOUT (${TEST_CONFIG.timeout}ms)`, 'error');
        resolve(result);
      }, TEST_CONFIG.timeout);
    });
  }

  // Exécuter suite complète de tests
  async runTestSuite() {
    this.log('DÉBUT TESTS SÉCURITÉ LICENCE USB VIDEO VAULT');
    this.log('=============================================');
    
    try {
      await this.checkPrerequisites();
      await this.setupTestEnvironment();
      
      // Test 1: Licence valide
      this.log('\n📋 TEST 1: LICENCE VALIDE');
      await this.generateValidLicense();
      this.results.validLicense = await this.testApplicationLaunch(
        'Licence valide (kid actif)',
        'success'
      );
      
      // Test 2: Signature invalide
      this.log('\n📋 TEST 2: SIGNATURE INVALIDE');
      await this.generateInvalidSignatureLicense();
      this.results.invalidSignature = await this.testApplicationLaunch(
        'Signature invalide',
        'signature_rejected'
      );
      
      // Test 3: Licence expirée
      this.log('\n📋 TEST 3: LICENCE EXPIRÉE');
      await this.generateExpiredLicense();
      this.results.expiredLicense = await this.testApplicationLaunch(
        'Licence expirée',
        'expired_rejected'
      );
      
      // Résumé final
      this.generateTestReport();
      
      // Retourner code de sortie approprié
      const allPassed = Object.values(this.results).every(r => r.passed);
      
      if (allPassed) {
        this.log('TOUS LES TESTS DE SÉCURITÉ PASSENT', 'success');
        process.exit(0);
      } else {
        this.log('CERTAINS TESTS DE SÉCURITÉ ÉCHOUENT', 'error');
        process.exit(1);
      }
      
    } catch (error) {
      this.log(`ERREUR CRITIQUE TESTS: ${error.message}`, 'error');
      if (TEST_CONFIG.verbose) {
        console.error(error.stack);
      }
      process.exit(2);
    }
  }

  // Générer rapport de test
  generateTestReport() {
    this.log('\n📊 RÉSULTATS TESTS SÉCURITÉ LICENCE');
    this.log('===================================');
    
    const tests = [
      { name: 'Licence valide (kid actif)', result: this.results.validLicense },
      { name: 'Signature invalide rejetée', result: this.results.invalidSignature },
      { name: 'Licence expirée rejetée', result: this.results.expiredLicense }
    ];
    
    tests.forEach((test, index) => {
      const status = test.result.passed ? '✅ RÉUSSI' : '❌ ÉCHEC';
      const duration = test.result.duration ? `(${test.result.duration}ms)` : '';
      console.log(`${index + 1}. ${test.name}: ${status} ${duration}`);
      
      if (!test.result.passed) {
        if (test.result.error && test.result.error !== 'TIMEOUT') {
          console.log(`   Erreur: ${test.result.error.substring(0, 100)}...`);
        }
        console.log(`   Code sortie: ${test.result.exitCode}`);
      }
    });
    
    const passedCount = tests.filter(t => t.result.passed).length;
    const totalCount = tests.length;
    const totalDuration = Date.now() - this.startTime;
    
    console.log(`\n🎯 RÉSULTAT GLOBAL: ${passedCount}/${totalCount} tests réussis`);
    console.log(`⏱️ DURÉE TOTALE: ${totalDuration}ms`);
    
    // Sauvegarder résultats pour CI
    this.saveTestResults(passedCount, totalCount, totalDuration);
  }

  // Sauvegarder résultats
  saveTestResults(passedCount, totalCount, totalDuration) {
    try {
      const resultsFile = './test-results/license-security-results.json';
      
      const fullResults = {
        timestamp: new Date().toISOString(),
        environment: process.env.CI ? 'CI' : 'local',
        node_version: process.version,
        platform: process.platform,
        totalDuration: totalDuration,
        summary: {
          totalTests: totalCount,
          passedTests: passedCount,
          failedTests: totalCount - passedCount,
          successRate: Math.round((passedCount / totalCount) * 100)
        },
        tests: this.results,
        config: {
          vaultPath: TEST_CONFIG.vaultPath,
          appExecutable: TEST_CONFIG.appExecutable,
          timeout: TEST_CONFIG.timeout
        }
      };
      
      fs.writeFileSync(resultsFile, JSON.stringify(fullResults, null, 2));
      this.log(`Résultats sauvegardés: ${resultsFile}`, 'success');
      
      // Créer aussi un résumé court pour CI
      const summaryFile = './test-results/license-security-summary.txt';
      const summary = `LICENSE SECURITY TESTS: ${passedCount}/${totalCount} PASSED (${Math.round((passedCount / totalCount) * 100)}%)
Duration: ${totalDuration}ms
Timestamp: ${new Date().toISOString()}
Status: ${passedCount === totalCount ? 'SUCCESS' : 'FAILURE'}`;
      
      fs.writeFileSync(summaryFile, summary);
      
    } catch (error) {
      this.log(`Erreur sauvegarde résultats: ${error.message}`, 'error');
    }
  }
}

// Exécution si script principal
if (require.main === module) {
  const testSuite = new LicenseSecurityTests();
  testSuite.runTestSuite();
}

module.exports = LicenseSecurityTests;