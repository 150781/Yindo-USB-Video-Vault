#!/usr/bin/env node
/**
 * Script de test des modes repeat
 * Lance l'application et guide l'utilisateur pour tester les modes
 */

const { spawn } = require('child_process');
const path = require('path');

console.log('🎵 Test des Modes Repeat - Yindo USB Video Vault\n');

// Vérifier que l'application est buildée
const distPath = path.join(__dirname, '..', 'dist', 'main', 'index.js');
const fs = require('fs');

if (!fs.existsSync(distPath)) {
  console.error('❌ Application non buildée. Exécutez d\'abord:');
  console.error('   npm run build');
  process.exit(1);
}

console.log('✅ Application buildée trouvée');
console.log('📋 Plan de test:');
console.log('');
console.log('1. 🔂 Mode Repeat "ONE"');
console.log('   - Jouer une chanson');
console.log('   - Activer repeat "one"');
console.log('   - Attendre la fin → doit rejouer la même chanson');
console.log('');
console.log('2. 🔁 Mode Repeat "ALL"');
console.log('   - Ajouter plusieurs chansons');
console.log('   - Activer repeat "all"');
console.log('   - Attendre la fin de liste → doit reprendre au début');
console.log('');
console.log('3. ↩️ Mode Repeat "NONE"');
console.log('   - Mode par défaut');
console.log('   - Attendre la fin → doit s\'arrêter');
console.log('');
console.log('4. 🔄 Relecture même fichier');
console.log('   - Cliquer "Lire" sur la même chanson');
console.log('   - Doit redémarrer à 0:00');
console.log('');

// Logs à surveiller
console.log('🔍 Logs importants à surveiller:');
console.log('');
console.log('✅ Mode repeat défini:');
console.log('   [QUEUE] setRepeat appelé: one typeof: string');
console.log('');
console.log('✅ Logique repeat/next:');
console.log('   [QUEUE] player:event ended reçu - gestion du repeat/next');
console.log('   [QUEUE] Mode repeat "one" - relancement fichier actuel');
console.log('');
console.log('✅ Pas d\'erreur UI:');
console.log('   Aucune erreur "repeatMode.toUpperCase is not a function"');
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
  
  console.log('\n📝 Résultats attendus:');
  console.log('✅ Repeat "one" rejoue la même chanson');
  console.log('✅ Repeat "all" passe à la suivante/reprend au début');
  console.log('✅ Repeat "none" s\'arrête');
  console.log('✅ Relecture du même fichier fonctionne');
  console.log('✅ Aucune erreur dans la console');
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
