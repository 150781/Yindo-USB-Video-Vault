// Test avancé de la fonction repeat
console.log('🔧 DIAGNOSTIC AVANCÉ DE LA FONCTION REPEAT');

// 1. Vérifier les APIs disponibles
console.log('📋 APIs disponibles:');
console.log('  - window.electron.queue:', typeof window.electron?.queue);
console.log('  - window.electron.catalog:', typeof window.electron?.catalog);
console.log('  - window.electron.ipc:', typeof window.electron?.ipc);

// 2. Vérifier l'état initial de la queue
window.electron.queue.get().then(queueState => {
  console.log('🎵 État initial de la queue:', queueState);
  console.log('  - repeatMode:', queueState.repeatMode);
  console.log('  - current:', queueState.current);
  console.log('  - items.length:', queueState.items.length);
  
  // 3. Tester l'écoute des événements player:event
  console.log('👂 Test de l\'écoute des événements...');
  
  let eventCount = 0;
  const unsubscribe = window.electron.ipc.on('player:event', (data) => {
    eventCount++;
    console.log(`🎧 Événement ${eventCount} reçu:`, data);
    
    if (data.type === 'ended') {
      console.log('🔚 Événement "ended" détecté !');
      // Vérifier l'état de la queue après l'événement ended
      setTimeout(() => {
        window.electron.queue.get().then(state => {
          console.log('📊 État queue après ended:', state);
        });
      }, 100);
    }
  });
  
  // 4. Charger le catalogue et démarrer un test
  return window.electron.catalog.list();
}).then(catalog => {
  console.log('📚 Catalogue chargé:', catalog.length, 'items');
  
  if (catalog.length === 0) {
    console.log('❌ Aucun item dans le catalogue pour tester');
    return;
  }
  
  // 5. Définir le mode repeat sur "one"
  return window.electron.queue.setRepeat('one').then(() => {
    console.log('🔁 Mode repeat "one" défini');
    
    // 6. Jouer le premier item
    return window.electron.queue.playNow(catalog[0]);
  }).then(() => {
    console.log('▶️ Lecture démarrée du premier item');
    console.log('⏱️ Attendez que la vidéo se termine pour voir si elle redémarre...');
    
    // 7. Programmer une vérification après 30 secondes
    setTimeout(() => {
      window.electron.queue.get().then(state => {
        console.log('📈 État final après 30s:', state);
        console.log('🎯 Test terminé - vérifiez si la vidéo a redémarré');
      });
    }, 30000);
  });
}).catch(error => {
  console.error('❌ Erreur pendant le test:', error);
});

// 8. Script de nettoyage (à exécuter manuellement si besoin)
console.log(`
🧹 Pour nettoyer après le test, exécutez:
window.electron.queue.setRepeat('none');
`);
