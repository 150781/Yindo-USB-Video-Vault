import { execSync } from 'child_process';

console.log('🔍 Test direct de validation de licence...');

const VAULT_PATH = './usb-package/vault';

try {
  console.log('📁 Vault path:', VAULT_PATH);
  
  // Test 1: Lancer l'app et capturer toute la sortie
  console.log('\n1️⃣ Test de lancement complet...');
  
  const result = execSync(
    `$env:VAULT_PATH = "${VAULT_PATH}"; $env:FORCE_PRODUCTION = "true"; npx electron . --no-sandbox`,
    { 
      timeout: 15000,
      stdio: 'pipe',
      encoding: 'utf8',
      shell: 'powershell'
    }
  );
  
  console.log('✅ App lancée avec succès - PROBLEME: devrait échouer avec licence expirée!');
  console.log('Sortie complète:');
  console.log(result);
  
} catch (error) {
  console.log('❌ App a échoué - ATTENDU si licence expirée');
  
  const output = error.stdout || error.stderr || '';
  const isExpectedFailure = output.includes('licence') || 
                           output.includes('Licence') || 
                           output.includes('expired') ||
                           output.includes('LICENSE') ||
                           output.includes('invalid');
  
  if (isExpectedFailure) {
    console.log('✅ Échec lié à la licence détecté!');
  } else {
    console.log('⚠️ Échec pour une autre raison:');
  }
  
  console.log('Sortie d\'erreur:');
  console.log(output.substring(0, 500) + '...');
}