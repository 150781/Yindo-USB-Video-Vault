// Test du système de comptage automatique des vues
const { app, BrowserWindow } = require('electron');
const path = require('path');

async function testViewCounting() {
  console.log('🎬 Test du système de comptage automatique des vues');
  
  // Attendre que l'app soit prête
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  const windows = BrowserWindow.getAllWindows();
  const controlWindow = windows.find(w => w.webContents.getURL().includes('index.html'));
  
  if (!controlWindow) {
    console.error('❌ Fenêtre de contrôle non trouvée');
    return;
  }
  
  console.log('📋 Récupération du catalogue...');
  
  // Exécuter du code dans la fenêtre de contrôle
  const result = await controlWindow.webContents.executeJavaScript(`
    new Promise(async (resolve) => {
      try {
        console.log('🔍 Test: récupération du catalogue');
        const catalog = await window.electron.catalog.list();
        console.log('📚 Catalogue:', catalog.length, 'items');
        
        if (catalog.length === 0) {
          resolve({ error: 'Aucun média dans le catalogue' });
          return;
        }
        
        console.log('📊 Récupération des stats initiales...');
        const initialStats = await window.electron.stats.get();
        console.log('📈 Stats initiales:', initialStats);
        
        const firstMedia = catalog[0];
        const initialViews = initialStats.byId[firstMedia.id] || 0;
        console.log('🎯 Média sélectionné:', firstMedia.title, '- Vues initiales:', initialViews);
        
        console.log('▶️ Lancement de la lecture...');
        await window.electron.queue.playNow(firstMedia);
        
        // Attendre un peu pour que la lecture démarre et les vues s'incrémentent
        await new Promise(r => setTimeout(r, 2000));
        
        console.log('📊 Récupération des stats après lecture...');
        const finalStats = await window.electron.stats.get();
        const finalViews = finalStats.byId[firstMedia.id] || 0;
        
        console.log('📈 Stats finales:', finalStats);
        console.log('🔢 Vues avant:', initialViews, '→ après:', finalViews);
        
        resolve({
          success: true,
          mediaId: firstMedia.id,
          mediaTitle: firstMedia.title,
          initialViews,
          finalViews,
          viewsIncremented: finalViews > initialViews
        });
      } catch (error) {
        console.error('❌ Erreur:', error);
        resolve({ error: error.message });
      }
    })
  `);
  
  console.log('🎯 Résultat du test:', result);
  
  if (result.error) {
    console.log('❌ Échec:', result.error);
  } else if (result.viewsIncremented) {
    console.log('✅ SUCCÈS: Les vues se sont automatiquement incrémentées !');
    console.log(`   📺 "${result.mediaTitle}": ${result.initialViews} → ${result.finalViews} vues`);
  } else {
    console.log('⚠️ ATTENTION: Les vues ne se sont pas incrémentées automatiquement');
    console.log(`   📺 "${result.mediaTitle}": ${result.initialViews} → ${result.finalViews} vues`);
  }
}

// Démarrer le test après un délai
if (app.isReady()) {
  testViewCounting();
} else {
  app.on('ready', () => {
    setTimeout(testViewCounting, 2000);
  });
}
