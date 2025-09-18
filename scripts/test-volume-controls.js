#!/usr/bin/env node
/**
 * Script de test des contrôles de volume
 * Guide l'utilisateur pour tester toutes les fonctionnalités
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log('🔊 Test des Contrôles de Volume - Yindo USB Video Vault\n');

// Vérifier que l'application est buildée
const distPath = path.join(__dirname, '..', 'dist', 'main', 'index.js');

if (!fs.existsSync(distPath)) {
  console.error('❌ Application non buildée. Exécutez d\'abord:');
  console.error('   npm run build');
  process.exit(1);
}

console.log('✅ Application buildée trouvée');
console.log('📋 Plan de test des contrôles de volume:');
console.log('');

console.log('1. 🎚️ Test du Slider de Volume');
console.log('   - Jouer une chanson');
console.log('   - Déplacer le slider de volume de gauche à droite');
console.log('   - Vérifier que le volume de la vidéo change');
console.log('   - Observer l\'affichage du pourcentage en temps réel');
console.log('');

console.log('2. ➕➖ Test des Boutons +/-');
console.log('   - Cliquer sur le bouton "+" plusieurs fois');
console.log('   - Vérifier que le volume augmente par incréments');
console.log('   - Cliquer sur le bouton "-" plusieurs fois');
console.log('   - Vérifier que le volume diminue par incréments');
console.log('   - Tester les limites 0% et 100%');
console.log('');

console.log('3. 🔇 Test du Mute/Unmute');
console.log('   - Régler le volume à 50%');
console.log('   - Cliquer sur le bouton mute (🔊 → 🔇)');
console.log('   - Vérifier que le son est complètement coupé');
console.log('   - Cliquer à nouveau pour unmute (🔇 → 🔊)');
console.log('   - Vérifier que le volume revient à 50%');
console.log('');

console.log('4. 🎭 Test des Icônes Dynamiques');
console.log('   - Volume 0% → doit afficher 🔇');
console.log('   - Volume 1-50% → doit afficher 🔈');
console.log('   - Volume 51-99% → doit afficher 🔉');
console.log('   - Volume 100% → doit afficher 🔊');
console.log('');

console.log('5. 💾 Test de Persistence');
console.log('   - Régler le volume à 75%');
console.log('   - Fermer complètement l\'application');
console.log('   - Relancer l\'application');
console.log('   - Vérifier que le volume est toujours à 75%');
console.log('');

console.log('6. 🎵 Test Pendant la Lecture');
console.log('   - Jouer une chanson');
console.log('   - Ajuster le volume pendant la lecture');
console.log('   - Vérifier que le changement est immédiat');
console.log('   - Tester mute/unmute pendant la lecture');
console.log('');

// Logs à surveiller
console.log('🔍 Logs importants à surveiller:');
console.log('');
console.log('✅ Contrôle volume:');
console.log('   [control] Volume défini: 0.5');
console.log('   [control] Volume défini: 0.8');
console.log('');
console.log('✅ Persistence:');
console.log('   Aucune erreur localStorage');
console.log('   Volume restauré au démarrage');
console.log('');
console.log('✅ Interface:');
console.log('   Slider réactif et fluide');
console.log('   Icônes qui changent selon le niveau');
console.log('   Pourcentage affiché correctement');
console.log('');

console.log('🚀 Lancement de l\'application...');
console.log('   (Fermer avec Ctrl+C ou fermer l\'app)\n');

// Lancer l'application
const electronProcess = spawn('npx', ['electron', distPath, '--enable-logging'], {
  cwd: path.join(__dirname, '..'),
  stdio: 'inherit',
  shell: true
});

electronProcess.on('close', (code) => {
  console.log('\n📊 Test terminé');
  console.log(`   Code de sortie: ${code}`);
  
  if (code === 0) {
    console.log('✅ Application fermée proprement');
  } else {
    console.log('⚠️  Application fermée avec erreur');
  }
  
  console.log('\n📝 Checklist de validation:');
  console.log('□ Slider de volume fonctionne et est fluide');
  console.log('□ Boutons +/- ajustent le volume par incréments');
  console.log('□ Bouton mute coupe le son instantanément');
  console.log('□ Unmute restaure le volume précédent');
  console.log('□ Icônes changent selon le niveau de volume');
  console.log('□ Pourcentage affiché correspond au slider');
  console.log('□ Volume persiste après redémarrage');
  console.log('□ Contrôles fonctionnent pendant la lecture');
  console.log('□ Aucune erreur dans la console');
  
  console.log('\n🎯 Si tous les points sont validés:');
  console.log('✅ Contrôles de volume entièrement fonctionnels !');
});

electronProcess.on('error', (err) => {
  console.error('❌ Erreur de lancement:', err.message);
  process.exit(1);
});

// Gérer Ctrl+C
process.on('SIGINT', () => {
  console.log('\n⏹️  Arrêt du test...');
  electronProcess.kill();
  process.exit(0);
});
