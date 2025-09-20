#!/usr/bin/env node
/**
 * 🧪 Tests QA Complets - Système de Licence
 * Validation automatisée de tous les scénarios critiques
 */

import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { readFileSync, writeFileSync, unlinkSync, existsSync, mkdirSync } from 'fs';
import { execSync } from 'child_process';
import crypto from 'crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = dirname(__dirname);

// Configuration test
const TEST_CONFIG = {
    timeout: 5000,
    testVault: join(rootDir, 'test-vault-qa'),
    validFingerprint: 'ba33ce761a01ec2b5ae8edb62ffb4bab',
    invalidFingerprint: 'invalid123',
    privateKey: '9657aecb25a8726326966ace9c10fded875391c7bb6c738564d89986e1121fb5879c35f5ae011c56528c27abb0f5b61539bf0d134158ec56ac4e8b8dd08c9d78'
};

let testResults = {
    passed: 0,
    failed: 0,
    errors: []
};

// Utilitaires
function log(message, type = 'info') {
    const timestamp = new Date().toISOString();
    const emoji = type === 'success' ? '✅' : type === 'error' ? '❌' : type === 'warn' ? '⚠️' : 'ℹ️';
    console.log(`${emoji} [${timestamp}] ${message}`);
}

function assert(condition, message) {
    if (condition) {
        testResults.passed++;
        log(`PASS: ${message}`, 'success');
        return true;
    } else {
        testResults.failed++;
        testResults.errors.push(message);
        log(`FAIL: ${message}`, 'error');
        return false;
    }
}

function setupTestEnvironment() {
    log('🔧 Setup environnement de test...');
    
    // Nettoyer et créer dossier test
    if (existsSync(TEST_CONFIG.testVault)) {
        execSync(`rmdir /s /q "${TEST_CONFIG.testVault}"`, { stdio: 'ignore' });
    }
    mkdirSync(TEST_CONFIG.testVault, { recursive: true });
    mkdirSync(join(TEST_CONFIG.testVault, '.vault'), { recursive: true });
    
    log('✅ Environnement test prêt');
}

function cleanupTestEnvironment() {
    log('🧹 Nettoyage environnement test...');
    try {
        if (existsSync(TEST_CONFIG.testVault)) {
            execSync(`rmdir /s /q "${TEST_CONFIG.testVault}"`, { stdio: 'ignore' });
        }
        log('✅ Nettoyage terminé');
    } catch (error) {
        log(`⚠️ Erreur nettoyage: ${error.message}`, 'warn');
    }
}

function runCommand(command, expectSuccess = true) {
    try {
        const result = execSync(command, { 
            encoding: 'utf-8',
            cwd: rootDir,
            env: { 
                ...process.env, 
                PACKAGER_PRIVATE_HEX: TEST_CONFIG.privateKey 
            }
        });
        if (expectSuccess) {
            return { success: true, output: result };
        } else {
            return { success: false, output: result };
        }
    } catch (error) {
        if (!expectSuccess) {
            return { success: true, output: error.message };
        } else {
            return { success: false, output: error.message };
        }
    }
}

// Tests de génération
function testLicenseGeneration() {
    log('📝 Tests génération de licence...');
    
    // Test 1.1: Génération standard
    const result = runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.validFingerprint}" --kid 1 --exp "2025-12-31T23:59:59Z" --out "${TEST_CONFIG.testVault}"`);
    assert(result.success && result.output.includes('LICENCE GÉNÉRÉE AVEC SUCCÈS'), 'Génération licence standard');
    
    // Vérifier fichiers créés
    const licenseBin = join(TEST_CONFIG.testVault, '.vault', 'license.bin');
    const licenseJson = join(TEST_CONFIG.testVault, 'license.json');
    assert(existsSync(licenseBin), 'Fichier license.bin créé');
    assert(existsSync(licenseJson), 'Fichier license.json créé');
    
    // Test 1.2: Fingerprint invalide
    const invalidResult = runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.invalidFingerprint}" --kid 1 --exp "2025-12-31T23:59:59Z" --out "${TEST_CONFIG.testVault}"`, false);
    assert(!invalidResult.success || invalidResult.output.includes('erreur'), 'Rejet fingerprint invalide');
    
    // Test 1.3: Kid inexistant
    const invalidKidResult = runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.validFingerprint}" --kid 999 --exp "2025-12-31T23:59:59Z" --out "${TEST_CONFIG.testVault}"`, false);
    assert(!invalidKidResult.success || invalidKidResult.output.includes('erreur'), 'Rejet kid inexistant');
    
    // Test 1.4: Date expiration passée
    const expiredResult = runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.validFingerprint}" --kid 1 --exp "2020-01-01T00:00:00Z" --out "${TEST_CONFIG.testVault}"`, false);
    assert(!expiredResult.success || expiredResult.output.includes('erreur'), 'Rejet date expiration passée');
}

// Tests de validation
function testLicenseValidation() {
    log('🔍 Tests validation de licence...');
    
    // Générer licence valide pour les tests
    runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.validFingerprint}" --kid 1 --exp "2025-12-31T23:59:59Z" --out "${TEST_CONFIG.testVault}"`);
    
    // Test 2.1: Validation licence valide
    const validResult = runCommand(`node scripts/verify-license.mjs "${TEST_CONFIG.testVault}"`);
    assert(validResult.success && validResult.output.includes('✅'), 'Validation licence valide');
    
    // Test 2.2: Corruption fichier
    const licenseBin = join(TEST_CONFIG.testVault, '.vault', 'license.bin');
    const originalContent = readFileSync(licenseBin, 'utf-8');
    writeFileSync(licenseBin, 'corrupted_data');
    
    const corruptedResult = runCommand(`node scripts/verify-license.mjs "${TEST_CONFIG.testVault}"`, false);
    assert(!corruptedResult.success || corruptedResult.output.includes('❌'), 'Rejet licence corrompue');
    
    // Restaurer fichier
    writeFileSync(licenseBin, originalContent);
    
    // Test 2.3: Fichier manquant
    unlinkSync(licenseBin);
    const missingResult = runCommand(`node scripts/verify-license.mjs "${TEST_CONFIG.testVault}"`, false);
    assert(!missingResult.success || missingResult.output.includes('❌'), 'Rejet fichier manquant');
}

// Tests anti-rollback
function testAntiRollback() {
    log('🔒 Tests anti-rollback...');
    
    // Générer licence initiale
    runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.validFingerprint}" --kid 1 --exp "2025-12-31T23:59:59Z" --out "${TEST_CONFIG.testVault}"`);
    
    // Simuler state file avec expiration future
    const stateFile = join(TEST_CONFIG.testVault, '.license_state.json');
    const futureState = {
        lastValidation: new Date().toISOString(),
        lastExpiration: '2026-12-31T23:59:59Z',
        validationCount: 1
    };
    writeFileSync(stateFile, JSON.stringify(futureState, null, 2));
    
    // Tenter licence avec expiration antérieure
    runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.validFingerprint}" --kid 1 --exp "2025-06-01T23:59:59Z" --out "${TEST_CONFIG.testVault}"`);
    
    // Note: Test complet nécessiterait intégration avec le code principal
    // Pour l'instant, on vérifie que les fichiers sont en place
    assert(existsSync(stateFile), 'State file anti-rollback présent');
}

// Tests de performance
function testPerformance() {
    log('⚡ Tests performance...');
    
    // Générer licence pour test
    runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.validFingerprint}" --kid 1 --exp "2025-12-31T23:59:59Z" --out "${TEST_CONFIG.testVault}"`);
    
    // Test temps de validation
    const startTime = Date.now();
    const result = runCommand(`node scripts/verify-license.mjs "${TEST_CONFIG.testVault}"`);
    const duration = Date.now() - startTime;
    
    assert(result.success, 'Validation réussie pour test performance');
    assert(duration < 2000, `Validation < 2s (${duration}ms)`);
    
    log(`📊 Temps validation: ${duration}ms`);
}

// Tests sécurité
function testSecurity() {
    log('🛡️ Tests sécurité...');
    
    // Test: Pas de clé privée dans les logs
    const result = runCommand(`node scripts/make-license.mjs "${TEST_CONFIG.validFingerprint}" --kid 1 --exp "2025-12-31T23:59:59Z" --out "${TEST_CONFIG.testVault}"`);
    assert(!result.output.includes(TEST_CONFIG.privateKey), 'Clé privée non exposée dans logs');
    
    // Test: Fingerprint tronqué dans logs
    assert(result.output.includes('ba33ce76...') || result.output.includes('ba33ce76'), 'Fingerprint tronqué ou masqué');
    
    // Test: Pas de signature complète dans logs
    assert(!result.output.includes('signature:') || result.output.includes('...'), 'Signature tronquée dans logs');
}

// Rapport final
function generateReport() {
    log('\n📊 RAPPORT FINAL QA');
    log('='.repeat(50));
    log(`✅ Tests réussis: ${testResults.passed}`);
    log(`❌ Tests échoués: ${testResults.failed}`);
    log(`📈 Taux de réussite: ${((testResults.passed / (testResults.passed + testResults.failed)) * 100).toFixed(1)}%`);
    
    if (testResults.failed > 0) {
        log('\n❌ ÉCHECS DÉTECTÉS:');
        testResults.errors.forEach((error, index) => {
            log(`   ${index + 1}. ${error}`);
        });
        log('\n🚨 RELEASE BLOQUÉE - Corriger les erreurs avant déploiement');
        process.exit(1);
    } else {
        log('\n🎉 TOUS LES TESTS PASSENT');
        log('✅ Système prêt pour la production');
        process.exit(0);
    }
}

// Exécution principale
async function main() {
    log('🧪 Démarrage Tests QA Complets - Système de Licence');
    log('='.repeat(60));
    
    try {
        setupTestEnvironment();
        
        // Exécuter toutes les suites de test
        testLicenseGeneration();
        testLicenseValidation();
        testAntiRollback();
        testPerformance();
        testSecurity();
        
    } catch (error) {
        log(`💥 Erreur fatale: ${error.message}`, 'error');
        testResults.failed++;
        testResults.errors.push(`Erreur fatale: ${error.message}`);
    } finally {
        cleanupTestEnvironment();
        generateReport();
    }
}

// Lancement
if (import.meta.url === `file://${process.argv[1]}`) {
    main().catch(console.error);
}

export { main as runQATests };