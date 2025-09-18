import { app, protocol, session } from 'electron';
import path from 'path';
import fs from 'fs';
import { VaultManager } from './vault.js';

export function registerMediaProtocols(vaultManager: VaultManager) {
  // En développement, utilisez le chemin source réel
  const isDev = process.env.NODE_ENV !== 'production';
  let ASSETS_DIR: string;
  
  if (isDev) {
    // Mode dev : remonte depuis dist/main vers src/assets/media  
    ASSETS_DIR = path.join(app.getAppPath(), '..', '..', 'src', 'assets', 'media');
  } else {
    // Mode production : assets probablement dans resources/
    ASSETS_DIR = path.join(app.getAppPath(), 'src', 'assets', 'media');
  }
  
  console.log('[main] Début d\'enregistrement des protocoles médias');
  console.log('[main] ASSETS_DIR =', ASSETS_DIR);

  try {
    // asset://media/xxx.ext -> fichier statique
    protocol.registerFileProtocol('asset', (req, cb) => {
      try {
        const url = decodeURIComponent(req.url.replace('asset://', '')); // "media/xxx.ext"
        let filePath: string;
        
        // Retirer le préfixe "media/" de l'URL car ASSETS_DIR pointe déjà vers le bon dossier
        const fileName = url.replace(/^media\//, '');
        filePath = path.join(ASSETS_DIR, fileName);
        
        console.log('[protocol asset] résolution:', url, '->', filePath);
        cb({ path: filePath });
      } catch (e) {
        console.error('[protocol asset] error:', e);
        cb({ error: -2 }); // FILE_NOT_FOUND
      }
    });
    console.log('[main] protocole asset:// enregistré');
  } catch (e: any) {
    console.warn('[main] erreur protocole asset://:', e.message);
  }

  try {
    // vault://media/<id> -> à adapter avec ta logique (stream/buffer)
    protocol.registerStreamProtocol('vault', (req, cb) => {
      try {
        const url = decodeURIComponent(req.url.replace('vault://', '')); // "media/<id>"
        const [, id] = url.split('/'); // media/<id>
        // TODO: remplace par ta vraie résolution de fichier depuis l'ID
        const filePath = resolveVaultPathFromId(id, ASSETS_DIR); 
        console.log('[protocol vault] résolution:', url, '->', filePath);
        const stream = fs.createReadStream(filePath);
        cb({ data: stream, statusCode: 200, headers: { 'Content-Type': 'video/mp4' } });
      } catch (e) {
        console.error('[protocol vault] error:', e);
        cb({ statusCode: 404 });
      }
    });
    console.log('[main] protocole vault:// enregistré');
  } catch (e: any) {
    console.warn('[main] erreur protocole vault://:', e.message);
  }
}

// Stub de démo (remplace par ta vraie résolution d'ID)
function resolveVaultPathFromId(id: string, assetsDir: string) {
  // Exemple: retour d'un chemin absolu vers un mp4
  return path.join(assetsDir, `${id}.mp4`);
}
