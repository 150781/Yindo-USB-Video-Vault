// Script de debug pour résoudre le problème 404 vault://
const fs = require('fs');
const path = require('path');

const VAULT_PATH = process.env.VAULT_PATH || 'usb-package\\vault';
const MEDIA_DIR = path.join(VAULT_PATH, 'media');

async function main() {
  console.log('=== DEBUG VAULT 404 ===');
  console.log('Vault path:', VAULT_PATH);
  console.log('Media dir:', MEDIA_DIR);
  
  // 1. Vérifier que le dossier existe
  if (!fs.existsSync(MEDIA_DIR)) {
    console.error('❌ Dossier media/ introuvable:', MEDIA_DIR);
    return;
  }
  
  // 2. Lister tous les fichiers
  const files = fs.readdirSync(MEDIA_DIR);
  console.log('\n📁 Fichiers présents dans media/ (' + files.length + '):');
  files.forEach((f, i) => {
    const fullPath = path.join(MEDIA_DIR, f);
    const stats = fs.statSync(fullPath);
    console.log(`  ${i+1}. ${f} (${Math.round(stats.size / 1024)} KB)`);
  });
  
  // 3. Charger le manifest
  try {
    const { getManifestEntries } = require('./dist/main/manifest.js');
    const manifestEntries = await getManifestEntries();
    
    console.log('\n📋 Entries dans le manifest (' + manifestEntries.length + '):');
    manifestEntries.forEach((media, i) => {
      console.log(`  ${i+1}. ID: ${media.id}`);
      console.log(`     Titre: ${media.title}`);
      console.log(`     SHA256Enc: ${media.sha256Enc || 'non défini'}`);
    });
    
    // 4. Analyser les correspondances
    console.log('\n🔍 ANALYSE CORRESPONDANCES:');
    let hasMatches = false;
    
    manifestEntries.forEach((media, i) => {
      const byId = files.filter(f => f.startsWith(media.id + '.'));
      const bySha = media.sha256Enc ? files.filter(f => f.startsWith(media.sha256Enc + '.')) : [];
      const totalMatches = [...new Set([...byId, ...bySha])];
      
      console.log(`\n  ${i+1}. ${media.title}:`);
      console.log(`     ID: ${media.id}`);
      
      if (byId.length > 0) {
        console.log(`     ✅ Fichiers par ID: ${byId.join(', ')}`);
        hasMatches = true;
      } else {
        console.log(`     ❌ Aucun fichier par ID`);
      }
      
      if (media.sha256Enc) {
        if (bySha.length > 0) {
          console.log(`     ✅ Fichiers par SHA256: ${bySha.join(', ')}`);
          hasMatches = true;
        } else {
          console.log(`     ❌ Aucun fichier par SHA256`);
        }
      }
      
      if (totalMatches.length === 0) {
        console.log(`     ⚠️  PROBLÈME: Aucune correspondance trouvée !`);
      }
    });
    
    if (!hasMatches) {
      console.log('\n🔧 SOLUTION SUGGÉRÉE:');
      console.log('Les noms de fichiers ne correspondent pas aux ID/SHA256 du manifest.');
      console.log('Options:');
      console.log('1. Renommer les fichiers pour qu\'ils commencent par l\'ID du manifest');
      console.log('2. Recréer le manifest à partir des fichiers présents');
      console.log('3. Vérifier si les médias ont été ajoutés correctement au vault');
      
      // Suggestion de renommage
      if (files.length === manifestEntries.length) {
        console.log('\n💡 RENOMMAGE AUTOMATIQUE POSSIBLE:');
        console.log('Nombre de fichiers = nombre d\'entries manifest');
        manifestEntries.forEach((media, i) => {
          if (files[i]) {
            const oldName = files[i];
            const ext = path.extname(oldName);
            const newName = media.id + ext;
            console.log(`  ${oldName} → ${newName}`);
          }
        });
      }
    }
    
  } catch (e) {
    console.error('❌ Erreur manifest:', e.message);
  }
}

main().catch(console.error);
