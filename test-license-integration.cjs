#!/usr/bin/env node

/**
 * Test d'intégration de la licence avec l'application
 */

const { loadAndValidateLicense } = require('./dist/main/licenseSecure.js');
const path = require('path');

async function testLicenseIntegration() {
  console.log('[TEST INTEGRATION] Test de chargement de licence réelle...');
  
  const vaultPath = path.resolve('./test-vault');
  
  try {
    console.log('[TEST INTEGRATION] Vault path:', vaultPath);
    
    // Tester le chargement et validation
    const result = await loadAndValidateLicense(vaultPath);
    
    console.log('[TEST INTEGRATION] Résultat validation:', result);
    
    if (result.valid) {
      console.log('[TEST INTEGRATION] ✅ Licence valide !');
      console.log('[TEST INTEGRATION] License ID:', result.license?.licenseId);
      console.log('[TEST INTEGRATION] Features:', result.license?.features);
      console.log('[TEST INTEGRATION] Expire:', new Date(result.license?.exp || '').toLocaleDateString());
    } else {
      console.log('[TEST INTEGRATION] ❌ Licence invalide:', result.error);
    }
    
  } catch (error) {
    console.error('[TEST INTEGRATION] ❌ Erreur:', error);
  }
}

if (require.main === module) {
  testLicenseIntegration();
}

module.exports = { testLicenseIntegration };
