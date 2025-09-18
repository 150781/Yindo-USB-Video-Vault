// Test corrigé de la fonction repeat
console.log('🔧 TEST CORRIGÉ DE LA FONCTION REPEAT');

// Test des APIs disponibles
console.log('📋 APIs disponibles:');
console.log('  - window.electron.queue:', typeof window.electron?.queue);
console.log('  - window.electron.catalog:', typeof window.electron?.catalog);

// Test avec la bonne séquence d'appels
async function testRepeat() {
  try {
    // 1. Récupérer le catalogue
    console.log('🔍 Récupération du catalogue...');
    const catalog = await window.electron.catalog.list();
    console.log('📚 Catalogue reçu:', catalog);
    
    if (!Array.isArray(catalog) || catalog.length === 0) {
      console.error('❌ Catalogue vide ou invalide');
      return;
    }
    
    console.log('✅ Catalogue valide:', catalog.length, 'items');
    
    // 2. Définir le mode repeat
    console.log('🔁 Définition du mode repeat "one"...');
    const queueState = await window.electron.queue.setRepeat('one');
    console.log('✅ Mode repeat défini:', queueState?.repeatMode);
    
    // 3. Jouer le premier item
    console.log('▶️ Démarrage lecture du premier item:', catalog[0].title);
    await window.electron.queue.playNow(catalog[0]);
    console.log('✅ Lecture démarrée');
    
    console.log('🎯 Test lancé avec succès !');
    console.log('⏱️ Laissez la vidéo se terminer pour voir si elle redémarre automatiquement');
    console.log('🔍 Surveillez les logs dans la console Electron pour les événements player:event');
    
  } catch (error) {
    console.error('❌ Erreur pendant le test:', error);
  }
}

// Lancer le test
testRepeat();
