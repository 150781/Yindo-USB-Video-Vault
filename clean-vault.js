import fs from 'fs';
import path from 'path';

console.log('=== NETTOYAGE ET RECONSTRUCTION VAULT ===\n');

const vaultDir = 'usb-package/vault';
const mediaDir = path.join(vaultDir, 'media');
const vaultConfigDir = path.join(vaultDir, '.vault');

// 1. Sauvegarde de la config actuelle
console.log('1. Sauvegarde device.tag...');
const deviceTag = fs.readFileSync(path.join(vaultConfigDir, 'device.tag'), 'utf8');
console.log('   Device tag:', deviceTag.trim());

// 2. Nettoyage des médias et manifest
console.log('\n2. Nettoyage médias...');
const mediaFiles = fs.readdirSync(mediaDir);
mediaFiles.forEach(file => {
  const fullPath = path.join(mediaDir, file);
  fs.unlinkSync(fullPath);
  console.log('   ✅ Supprimé:', file);
});

console.log('\n3. Nettoyage manifest...');
const manifestFiles = ['manifest.bin', 'manifest.dev.json', 'license.bin', 'stats.bin'];
manifestFiles.forEach(file => {
  const fullPath = path.join(vaultConfigDir, file);
  if (fs.existsSync(fullPath)) {
    fs.unlinkSync(fullPath);
    console.log('   ✅ Supprimé:', file);
  }
});

// 3. Copie des médias de test
console.log('\n4. Copie médias de test...');
const testFiles = [
  'src/assets/demo.mp4',
  'src/assets/Odogwu.mp4'
];

testFiles.forEach(srcFile => {
  if (fs.existsSync(srcFile)) {
    const fileName = path.basename(srcFile);
    const destFile = path.join(mediaDir, fileName);
    fs.copyFileSync(srcFile, destFile);
    console.log('   ✅ Copié:', fileName);
  } else {
    console.log('   ⚠️  Fichier source introuvable:', srcFile);
  }
});

console.log('\n5. Validation...');
const finalMediaFiles = fs.readdirSync(mediaDir);
console.log('   Fichiers médias présents:', finalMediaFiles.length);
finalMediaFiles.forEach(file => {
  const fullPath = path.join(mediaDir, file);
  const stat = fs.statSync(fullPath);
  const sizeMB = (stat.size / (1024*1024)).toFixed(2);
  console.log('   📁', file, `(${sizeMB} MB)`);
});

console.log('\n✅ Vault nettoyé. Prêt pour la reconstruction du manifest.');
console.log('➡️  Exécutez maintenant:');
console.log('    node tools/packager/pack.js init --vault usb-package/vault');
console.log('    node tools/packager/pack.js add-media --vault usb-package/vault --auto');
console.log('    node tools/packager/pack.js issue-license --vault usb-package/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "' + deviceTag.trim() + '" --all');
