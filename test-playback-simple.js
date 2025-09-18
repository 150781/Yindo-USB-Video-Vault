// Test simple de lecture avec une seule vidéo
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Test des médias disponibles
const mediaDir = path.join(__dirname, 'src', 'assets', 'media');
console.log('[TEST] Vérification médias dans:', mediaDir);

if (fs.existsSync(mediaDir)) {
  const files = fs.readdirSync(mediaDir).filter(f => f.endsWith('.mp4'));
  console.log('[TEST] Fichiers MP4 trouvés:', files.length);
  
  if (files.length > 0) {
    const firstFile = files[0];
    const fullPath = path.join(mediaDir, firstFile);
    const stats = fs.statSync(fullPath);
    
    console.log('[TEST] Premier fichier:', firstFile);
    console.log('[TEST] Taille:', (stats.size / 1024 / 1024).toFixed(2), 'MB');
    console.log('[TEST] URL asset:', `asset://media/${encodeURIComponent(firstFile)}`);
    
    // Simulation d'un item de queue
    const testItem = {
      id: 'test-item-' + Date.now(),
      title: firstFile.replace('.mp4', ''),
      artist: 'Test Artist',
      src: `asset://media/${encodeURIComponent(firstFile)}`,
      source: 'asset'
    };
    
    console.log('[TEST] Item de test:', JSON.stringify(testItem, null, 2));
    console.log('[TEST] Prêt pour test avec window.electron.queue.playNow()');
  } else {
    console.log('[TEST] ERREUR: Aucun fichier MP4 trouvé');
  }
} else {
  console.log('[TEST] ERREUR: Dossier média non trouvé');
}
