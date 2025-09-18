// Test complet : comptage des vues + auto-next
console.log('🎬 Test complet: vues + auto-next');

// Attendre que l'application soit prête
setTimeout(async () => {
  try {
    console.log('📋 1. Récupération du catalogue...');
    const catalog = await window.electron.catalog.list();
    console.log('📚 Catalogue:', catalog.length, 'items');
    
    if (catalog.length < 2) {
      console.error('❌ Besoin d\'au moins 2 médias pour tester l\'auto-next');
      return;
    }
    
    console.log('📊 2. Stats initiales...');
    const initialStats = await window.electron.stats.get();
    console.log('📈 Stats initiales:', initialStats);
    
    console.log('🎯 3. Ajout de plusieurs chansons à la queue...');
    await window.electron.queue.addMany([catalog[0], catalog[1]]);
    
    const queue = await window.electron.queue.get();
    console.log('📋 Queue:', queue);
    
    console.log('▶️ 4. Démarrage de la première chanson...');
    await window.electron.queue.playAt(0);
    
    console.log('⏰ En attente de la fin de la première chanson...');
    console.log('   📝 Vérifiez les logs de la console pour voir:');
    console.log('   - "[display] ✅ Incrémentation des vues..."');
    console.log('   - "[display] ✅ Chanson suivante demandée"');
    console.log('   - Puis la deuxième chanson devrait se lancer automatiquement');
    
  } catch (error) {
    console.error('❌ Erreur:', error);
  }
}, 2000);
