/**
 * Test isolé de la validation de licence sans Electron
 */

import { loadAndValidateLicense } from './dist/main/licenseSecure.js';
import path from 'path';

async function testLicenseValidation() {
  console.log('🔍 Test isolé de validation de licence...');
  
  const vaultPath = path.resolve('./usb-package/vault');
  console.log('📁 Vault path:', vaultPath);
  
  try {
    console.log('🚀 Appel loadAndValidateLicense...');
    const result = await loadAndValidateLicense(vaultPath);
    
    console.log('📊 Résultat:', result);
    
    if (result.isValid) {
      console.log('✅ Licence VALIDE - PROBLÈME car elle devrait être expirée!');
    } else {
      console.log('❌ Licence INVALIDE - ATTENDU car licence expirée');
      console.log('📝 Raison:', result.reason);
    }
    
  } catch (error) {
    console.error('💥 Erreur:', error);
    console.error('📚 Stack:', error.stack);
  }
}

testLicenseValidation().catch(console.error);