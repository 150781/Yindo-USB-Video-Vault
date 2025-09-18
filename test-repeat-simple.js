// Test simple de la fonction repeat
console.log('=== DIAGNOSTIC DE LA FONCTION REPEAT ===');

// Test immédiat de la connexion IPC
console.log('1. Test de la connexion Electron API...');
if (!window.electron) {
  console.error('❌ window.electron non disponible');
} else {
  console.log('✅ window.electron disponible');
}

if (!window.electron?.ipc) {
  console.error('❌ window.electron.ipc non disponible');
} else {
  console.log('✅ window.electron.ipc disponible');
}

if (!window.electron?.queue) {
  console.error('❌ window.electron.queue non disponible');
} else {
  console.log('✅ window.electron.queue disponible');
}

// Test de base de l'état de la queue
console.log('2. Test de l\'état initial de la queue...');
window.electron.queue.get().then(queue => {
  console.log('Queue actuelle:', queue);
  console.log('Mode repeat actuel:', queue.repeatMode);
  console.log('Index actuel:', queue.currentIndex);
  console.log('Nombre d\'items:', queue.items?.length || 0);
  
  // Test de simulation d'un événement ended
  console.log('3. Simulation d\'un événement ended...');
  console.log('Envoi de player:event avec type "ended"...');
  
  // Ajout d'un listener pour voir si l'événement est reçu
  const unsubscribe = window.electron.ipc.on('player:event', (data) => {
    console.log('🔥 ÉVÉNEMENT REÇU :', data);
  });
  
  // Envoi de l'événement
  window.electron.ipc.send('player:event', { type: 'ended' });
  
  // Nettoyage après 2 secondes
  setTimeout(() => {
    unsubscribe();
    console.log('✅ Test terminé');
  }, 2000);
  
}).catch(err => {
  console.error('❌ Erreur lors du test de la queue:', err);
});
