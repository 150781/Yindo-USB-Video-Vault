// Script de reconstruction du vault pour corriger l'erreur cryptographique
import { execSync } from 'child_process';
import fs from 'fs-extra';

console.log('🔧 Reconstruction du vault pour corriger l erreur cryptographique...\n');

try {
  // 1. Supprimer l'ancien vault
  console.log('1. Suppression du vault existant...');
  await fs.remove('usb-package/vault');
  console.log('   ✅ Vault supprimé');

  // 2. Initialiser un nouveau vault
  console.log('2. Initialisation du nouveau vault...');
  execSync('node tools/packager/pack.js init --vault usb-package/vault', { stdio: 'inherit' });
  console.log('   ✅ Vault initialisé');

  // 3. Ajouter les médias
  console.log('3. Ajout des médias...');
  execSync('node tools/packager/pack.js add-media --vault usb-package/vault --file "src/assets/demo.mp4" --title "Demo Video" --artist "Test Artist"', { stdio: 'inherit' });
  execSync('node tools/packager/pack.js add-media --vault usb-package/vault --file "src/assets/Odogwu.mp4" --title "Odogwu" --artist "Burna Boy"', { stdio: 'inherit' });
  console.log('   ✅ Médias ajoutés');

  // 4. Construire le manifest
  console.log('4. Construction du manifest...');
  execSync('node tools/packager/pack.js build-manifest --vault usb-package/vault', { stdio: 'inherit' });
  console.log('   ✅ Manifest construit');

  // 5. Sceller le manifest
  console.log('5. Scellement du manifest...');
  execSync('node tools/packager/pack.js seal-manifest --vault usb-package/vault', { stdio: 'inherit' });
  console.log('   ✅ Manifest scellé');

  // 6. Générer la licence
  console.log('6. Génération de la licence...');
  const machineId = '928fb2e42e9de3a9e7305842ef114ae7ef35cb2e7e8003a37da07fd410e45bc5';
  execSync(`node tools/packager/pack.js issue-license --vault usb-package/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "${machineId}" --all`, { stdio: 'inherit' });
  console.log('   ✅ Licence générée');

  console.log('\n✨ Vault reconstruit avec succès !');
  console.log('📝 Vous pouvez maintenant tester avec le mot de passe: test123');

} catch (error) {
  console.error('❌ Erreur lors de la reconstruction:', error.message);
  process.exit(1);
}
