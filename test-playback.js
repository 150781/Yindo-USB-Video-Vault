// test-playback.js - Script de test de lecture
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Test simple pour vérifier si les fichiers médias existent
const mediaDir = path.join(__dirname, 'src', 'assets', 'media');
console.log('Vérification du dossier média:', mediaDir);

if (fs.existsSync(mediaDir)) {
  const files = fs.readdirSync(mediaDir);
  console.log('Fichiers trouvés:', files);
  
  // Test d'un fichier
  if (files.length > 0) {
    const testFile = files[0];
    const fullPath = path.join(mediaDir, testFile);
    const stats = fs.statSync(fullPath);
    console.log(`Test fichier: ${testFile}`);
    console.log(`Taille: ${stats.size} bytes`);
    console.log(`URL asset correspondante: asset://media/${encodeURIComponent(testFile)}`);
  }
} else {
  console.log('❌ Dossier média non trouvé !');
}
