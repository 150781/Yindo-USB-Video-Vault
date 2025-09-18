// Test de la fonction repeat
console.log('=== TEST DE LA FONCTION REPEAT ===');

// 1. Tester le mode repeat "one"
window.electron.catalog.list().then(catalog => {
  console.log('Catalogue disponible:', catalog.length, 'items');
  
  // Configurer le mode repeat à "one" et jouer une chanson courte
  return window.electron.queue.addMany(catalog.slice(0, 3)).then(() => {
    console.log('3 chansons ajoutées à la queue');
    return window.electron.queue.get();
  }).then(queue => {
    console.log('Queue actuelle:', queue);
    
    // Test 1: Mode "one" - doit répéter la même chanson
    console.log('\n🔄 TEST 1: Mode repeat "one"');
    
    // Pour tester rapidement, nous allons jouer et simuler la fin
    return window.electron.queue.playAt(0);
  });
}).then(() => {
  setTimeout(() => {
    console.log('Changement du mode repeat à "one"...');
    
    // Simuler le changement de mode dans l'interface
    const modeButton = document.querySelector('[title*="Répétition"]');
    if (modeButton) {
      console.log('Bouton repeat trouvé, simulation du clic...');
      modeButton.click();
    }
    
    // Vérifier l'état après 1 seconde
    setTimeout(() => {
      window.electron.queue.get().then(queue => {
        console.log('Mode repeat actuel:', queue.repeatMode);
        console.log('Index actuel:', queue.currentIndex);
        
        // Simuler un événement ended pour tester
        console.log('Simulation de la fin de lecture...');
        window.electron.ipc?.send?.('player:event', { type: 'ended' });
      });
    }, 1000);
  }, 2000);
}).catch(err => {
  console.error('Erreur lors du test:', err);
});

console.log('Test initialisé. Observez les logs pour voir le comportement du repeat.');
