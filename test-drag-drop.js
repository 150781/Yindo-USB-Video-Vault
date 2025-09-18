// Script de test pour le drag-and-drop
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log('[TEST] Démarrage du test drag-and-drop...');

// Construire l'application
console.log('[TEST] Construction de l\'application...');
const buildProcess = spawn('npm', ['run', 'build'], {
  cwd: __dirname,
  stdio: 'inherit',
  shell: true
});

buildProcess.on('close', (code) => {
  if (code !== 0) {
    console.error('[TEST] Erreur de construction, code:', code);
    return;
  }
  
  console.log('[TEST] Construction réussie. Lancement de l\'application...');
  
  // Lancer l'application
  const electronPath = path.join(__dirname, 'node_modules', '.bin', 'electron');
  const mainPath = path.join(__dirname, 'dist', 'main', 'index.js');
  
  const electronProcess = spawn(electronPath, [mainPath], {
    cwd: __dirname,
    stdio: 'inherit',
    shell: true
  });
  
  electronProcess.on('close', (code) => {
    console.log('[TEST] Application fermée, code:', code);
  });
  
  // Instructions pour l'utilisateur
  console.log(`
[TEST] Application lancée ! Instructions de test :

1. Ajoutez plusieurs chansons à la playlist en cliquant sur "Lire" 
2. Dans la playlist (panneau de droite), essayez de :
   - Cliquer et maintenir une chanson
   - La faire glisser vers une autre position
   - Relâcher pour déposer

3. Vérifiez que :
   - L'ordre des chansons change visuellement
   - La chanson prend bien la nouvelle position
   - Les logs montrent "[QUEUE] reorder appelé"

4. Fermez l'application quand terminé.
`);
});
