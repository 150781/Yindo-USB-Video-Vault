#!/usr/bin/env node
/**
 * Script de validation de l'architecture IPC
 * Vérifie que les handlers ne sont pas en conflit
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log('🔍 Validation de l\'architecture IPC...\n');

// 1. Vérifier que ipcQueueStats n'est pas importé dans index.ts
const indexPath = path.join(__dirname, '..', 'src', 'main', 'index.ts');
const indexContent = fs.readFileSync(indexPath, 'utf8');

if (indexContent.includes('ipcQueueStats')) {
  console.error('❌ ERREUR: ipcQueueStats est importé dans index.ts');
  console.error('   Supprimer cette ligne pour éviter les conflits de handlers');
  process.exit(1);
}
console.log('✅ index.ts n\'importe pas ipcQueueStats');

// 2. Vérifier que ipcQueue.ts contient le handler setRepeat
const ipcQueuePath = path.join(__dirname, '..', 'src', 'main', 'ipcQueue.ts');
const ipcQueueContent = fs.readFileSync(ipcQueuePath, 'utf8');

if (!ipcQueueContent.includes('queue:setRepeat')) {
  console.error('❌ ERREUR: Handler queue:setRepeat manquant dans ipcQueue.ts');
  process.exit(1);
}
console.log('✅ ipcQueue.ts contient le handler queue:setRepeat');

// 3. Vérifier le format du preload
const preloadPath = path.join(__dirname, '..', 'src', 'main', 'preload.cjs');
const preloadContent = fs.readFileSync(preloadPath, 'utf8');

if (preloadContent.includes('{ mode }')) {
  console.error('❌ ERREUR: preload.cjs envoie { mode } au lieu de mode');
  console.error('   Corriger: setRepeat: (mode) => invoke("queue:setRepeat", mode)');
  process.exit(1);
}
console.log('✅ preload.cjs envoie mode directement');

// 4. Vérifier les String() dans ControlWindowClean.tsx
const controlPath = path.join(__dirname, '..', 'src', 'renderer', 'modules', 'ControlWindowClean.tsx');
const controlContent = fs.readFileSync(controlPath, 'utf8');

if (controlContent.includes('queue.repeatMode.toUpperCase')) {
  console.error('❌ ERREUR: Usage direct de queue.repeatMode.toUpperCase détecté');
  console.error('   Utiliser String(queue.repeatMode).toUpperCase()');
  process.exit(1);
}
console.log('✅ ControlWindowClean.tsx utilise String() défensif');

// 5. Compter les handlers queue:setRepeat
const srcPath = path.join(__dirname, '..', 'src');
let setRepeatHandlers = 0;

function scanForHandlers(dir) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    
    if (stat.isDirectory()) {
      scanForHandlers(fullPath);
    } else if (file.endsWith('.ts') || file.endsWith('.js')) {
      const content = fs.readFileSync(fullPath, 'utf8');
      const matches = content.match(/ipcMain\.handle\(['"]\s*queue:setRepeat/g);
      if (matches) {
        setRepeatHandlers += matches.length;
        console.log(`   Handler trouvé dans: ${fullPath}`);
      }
    }
  }
}

scanForHandlers(srcPath);

if (setRepeatHandlers !== 1) {
  console.error(`❌ ERREUR: ${setRepeatHandlers} handlers queue:setRepeat trouvés (doit être 1)`);
  process.exit(1);
}
console.log('✅ Un seul handler queue:setRepeat trouvé');

console.log('\n🎯 Architecture IPC validée avec succès !');
console.log('   Tous les handlers sont corrects et sans conflit.');
