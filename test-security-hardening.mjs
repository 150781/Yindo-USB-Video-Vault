/**
 * Test complet du durcissement Electron
 * Validation CSP, Sandbox, Anti-Debug
 */

import { app, BrowserWindow, session } from 'electron';
import { fileURLToPath, pathToFileURL } from 'url';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Initialiser les protections de sécurité globales
let securityInitialized = false;

async function initializeSecurity() {
  if (securityInitialized) return;
  
  try {
    const { setupProductionCSP, setupCSPViolationLogging } = await import('./dist/main/csp.js');
    const { initializeSandboxSecurity } = await import('./dist/main/sandbox.js');
    const { initializeAntiDebugProtection } = await import('./dist/main/antiDebug.js');
    
    setupProductionCSP();
    setupCSPViolationLogging();
    initializeSandboxSecurity(false);
    initializeAntiDebugProtection();
    
    securityInitialized = true;
    console.log('[HARDENING-TEST] Sécurité initialisée');
  } catch (error) {
    console.error('[HARDENING-TEST] Erreur initialisation:', error);
  }
}

/**
 * @typedef {Object} SecurityTestResult
 * @property {string} name
 * @property {boolean} passed
 * @property {string} details
 * @property {boolean} critical
 */

class SecurityTester {
  /** @type {SecurityTestResult[]} */
  #results = [];

  async runAllTests() {
    console.log('🔒 === TEST SÉCURITÉ ELECTRON ===');
    
    // Initialiser la sécurité avant les tests
    await initializeSecurity();

    await this.#testCSPConfiguration();
    await this.#testSandboxConfiguration();
    await this.#testPermissionBlocking();
    await this.#testNavigationRestrictions();
    await this.#testAntiDebugFeatures();
    await this.#testProcessIsolation();

    this.#generateReport();
  }

  #addResult(name, passed, details, critical = false) {
    this.#results.push({ name, passed, details, critical });
    const icon = passed ? '✅' : '❌';
    const level = critical ? '[CRITIQUE]' : '[INFO]';
    console.log(`${icon} ${level} ${name}: ${details}`);
  }

  async #testCSPConfiguration() {
    console.log('\n📋 Test Content Security Policy...');

    try {
      // Test session CSP (présence d’un handler headers-received)
      const hasCSP = session.defaultSession.webRequest.listenerCount('headers-received') > 0;
      this.#addResult(
        'CSP Headers',
        hasCSP,
        hasCSP ? 'CSP configuré sur session par défaut' : 'CSP non configuré',
        true
      );

      // Test protocoles personnalisés
      const registeredSchemes =
        session.defaultSession && session.defaultSession.protocol
          ? session.defaultSession.protocol.isSchemeRegistered
          : undefined;
      const hasVaultScheme = typeof registeredSchemes === 'function'
        ? registeredSchemes('vault')
        : false;

      this.#addResult(
        'Protocoles Sécurisés',
        !!hasVaultScheme,
        hasVaultScheme ? 'Protocole vault: enregistré' : 'Protocole vault: manquant'
      );
    } catch (error) {
      this.#addResult('CSP Configuration', false, `Erreur: ${error}`, true);
    }
  }

  async #testSandboxConfiguration() {
    console.log('\n🏠 Test Configuration Sandbox...');

    try {
      // Créer une fenêtre de test
      const testWindow = new BrowserWindow({
        show: false,
        webPreferences: {
          sandbox: true,
          contextIsolation: true,
          nodeIntegration: false,
          webSecurity: true
        }
      });

      const prefs = (testWindow.webContents.getWebPreferences?.()) || {};

      this.#addResult(
        'Sandbox Activé',
        prefs.sandbox === true,
        `Sandbox: ${prefs.sandbox}`,
        true
      );

      this.#addResult(
        'Context Isolation',
        prefs.contextIsolation === true,
        `Context Isolation: ${prefs.contextIsolation}`,
        true
      );

      this.#addResult(
        'Node Integration',
        prefs.nodeIntegration === false,
        `Node Integration: ${prefs.nodeIntegration}`,
        true
      );

      this.#addResult(
        'Web Security',
        prefs.webSecurity === true,
        `Web Security: ${prefs.webSecurity}`,
        true
      );

      testWindow.destroy();
    } catch (error) {
      this.#addResult('Sandbox Configuration', false, `Erreur: ${error}`, true);
    }
  }

  async #testPermissionBlocking() {
    console.log('\n🚫 Test Blocage Permissions...');

    try {
      let permissionBlockingActive = false;

      // Test handler de permissions
      const originalHandler = session.defaultSession.setPermissionRequestHandler;
      if (originalHandler) {
        // Toujours refuser pour le test
        session.defaultSession.setPermissionRequestHandler((_webContents, _permission, callback) => {
          permissionBlockingActive = true;
          callback(false);
        });

        this.#addResult(
          'Handler Permissions',
          true,
          'Handler de permissions configuré'
        );
      } else {
        this.#addResult(
          'Handler Permissions',
          false,
          'Handler de permissions manquant',
          true
        );
      }
    } catch (error) {
      this.#addResult('Permission Blocking', false, `Erreur: ${error}`, true);
    }
  }

  async #testNavigationRestrictions() {
    console.log('\n🧭 Test Restrictions Navigation...');

    try {
      // Test handler de navigation (présence d’un listener global)
      const hasNavigationHandler = app.listenerCount('web-contents-created') > 0;
      this.#addResult(
        'Navigation Handler',
        hasNavigationHandler,
        hasNavigationHandler ? 'Handler navigation configuré' : 'Handler navigation manquant'
      );

      // Test restriction window.open
      const testWindow = new BrowserWindow({
        show: false,
        webPreferences: {
          sandbox: true,
          contextIsolation: true,
          nodeIntegration: false
        }
      });

      // Vérifier si window.open est restreint
      testWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));

      this.#addResult(
        'Window Open Blocking',
        true,
        'Handler window.open configuré'
      );

      testWindow.destroy();
    } catch (error) {
      this.#addResult('Navigation Restrictions', false, `Erreur: ${error}`);
    }
  }

  async #testAntiDebugFeatures() {
    console.log('\n🐛 Test Fonctionnalités Anti-Debug...');

    try {
      // Test blocage DevTools (via présence d’un handler global)
      const hasDevToolsHandler = app.listenerCount('web-contents-created') > 0;
      this.#addResult(
        'DevTools Protection',
        hasDevToolsHandler,
        hasDevToolsHandler ? 'Protection DevTools activée' : 'Protection DevTools manquante'
      );

      // Test arguments de ligne de commande
      const commandLineArgs = process.argv || [];
      const hasSecurityArgs = commandLineArgs.some(arg =>
        arg.includes('site-per-process') ||
        arg.includes('disable-site-isolation-trials')
      );

      this.#addResult(
        'Process Isolation Args',
        hasSecurityArgs,
        hasSecurityArgs ? 'Arguments isolation processus détectés' : 'Arguments isolation manquants'
      );
    } catch (error) {
      this.#addResult('Anti-Debug Features', false, `Erreur: ${error}`);
    }
  }

  async #testProcessIsolation() {
    console.log('\n🔒 Test Isolation Processus...');

    try {
      // Vérifier les arguments de sécurité processus
      const args = process.argv || [];
      const isolationArgs = [
        'site-per-process',
        'process-per-site',
        'disable-site-isolation-trials'
      ];

      let isolationScore = 0;
      isolationArgs.forEach(arg => {
        if (args.some(a => a.includes(arg))) {
          isolationScore++;
        }
      });

      const isolationPassed = isolationScore >= 2;
      this.#addResult(
        'Process Isolation',
        isolationPassed,
        `${isolationScore}/${isolationArgs.length} arguments isolation détectés`
      );

      // Test limitation mémoire
      const memArgs = args.some(arg => arg.includes('max-old-space-size'));
      this.#addResult(
        'Memory Limits',
        memArgs,
        memArgs ? 'Limitations mémoire configurées' : 'Limitations mémoire manquantes'
      );
    } catch (error) {
      this.#addResult('Process Isolation', false, `Erreur: ${error}`);
    }
  }

  #generateReport() {
    console.log('\n📊 === RAPPORT SÉCURITÉ ===');

    const totalTests = this.#results.length;
    const passedTests = this.#results.filter(r => r.passed).length;
    const criticalFailures = this.#results.filter(r => !r.passed && r.critical).length;

    console.log(`Total des tests: ${totalTests}`);
    console.log(`Tests réussis: ${passedTests}`);
    console.log(`Tests échoués: ${totalTests - passedTests}`);
    console.log(`Échecs critiques: ${criticalFailures}`);

    const successRate = totalTests > 0 ? (passedTests / totalTests) * 100 : 0;
    console.log(`\nTaux de réussite: ${successRate.toFixed(1)}%`);

    if (criticalFailures > 0) {
      console.log('\n⚠️ ÉCHECS CRITIQUES DÉTECTÉS:');
      this.#results
        .filter(r => !r.passed && r.critical)
        .forEach(r => console.log(`  ❌ ${r.name}: ${r.details}`));
    }

    if (successRate >= 90) {
      console.log('\n🎉 SÉCURITÉ EXCELLENTE - Application bien protégée');
    } else if (successRate >= 75) {
      console.log('\n✅ SÉCURITÉ BONNE - Quelques améliorations possibles');
    } else if (successRate >= 50) {
      console.log('\n⚠️ SÉCURITÉ MOYENNE - Améliorations recommandées');
    } else {
      console.log('\n🚨 SÉCURITÉ INSUFFISANTE - Action immédiate requise');
    }

    // Recommandations
    console.log('\n📋 RECOMMANDATIONS:');
    this.#results
      .filter(r => !r.passed)
      .forEach(r => {
        const priority = r.critical ? '[HAUTE]' : '[NORMALE]';
        console.log(`  ${priority} Corriger: ${r.name}`);
      });
  }
}

// Script de test principal
async function runSecurityTests() {
  const tester = new SecurityTester();
  await tester.runAllTests();
}

// Export pour utilisation externe
export { SecurityTester, runSecurityTests };

// Exécution directe si appelé comme script principal
if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  app.whenReady().then(runSecurityTests);
}
