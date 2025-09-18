console.log('=== TEST DE LECTURE VIDÉO ===');

// Test avec le catalogue complet
window.electron.catalog.list().then(catalog => {
  console.log('Catalogue trouvé:', catalog.length, 'items');
  
  if (catalog.length > 0) {
    const firstItem = catalog[0];
    console.log('Premier item:', firstItem);
    console.log('Tentative de lecture avec queue.playNow()...');
    
    // Test de lecture
    window.electron.queue.playNow(firstItem).then(() => {
      console.log('✅ playNow() réussi');
    }).catch(err => {
      console.error('❌ playNow() échec:', err);
    });
  } else {
    console.error('❌ Aucun item dans le catalogue');
  }
}).catch(err => {
  console.error('❌ Erreur catalogue:', err);
});

console.log('Test lancé, vérifiez les logs de l\'application Electron...');
