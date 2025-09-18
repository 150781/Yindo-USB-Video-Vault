// Test final de validation des contrôles synchronisés
// Pour valider rapidement la synchronisation

console.log('🔍 VALIDATION DES CORRECTIONS DE SYNCHRONISATION');
console.log('================================================');

// Vérification 1: État backend est-il mis à jour ?
console.log('\n📊 1. Vérification état backend:');
window.electron.queue.getState().then(state => {
  console.log('✅ État queue actuel:', state);
  
  if (state.hasOwnProperty('isPlaying') && state.hasOwnProperty('isPaused')) {
    console.log('✅ Backend contient isPlaying/isPaused');
  } else {
    console.log('❌ Backend manque isPlaying/isPaused');
  }
});

// Vérification 2: Les boutons top bar utilisent-ils les bonnes méthodes ?
console.log('\n🔄 2. Vérification boutons top bar:');

// Chercher le bouton next du top
const nextBtn = document.querySelector('button[title="Suivant"]');
const prevBtn = document.querySelector('button[title="Précédent"]');
const playPauseBtn = document.querySelector('button[title*="Lecture"], button[title*="Pause"]');

console.log('Boutons trouvés:', {
  next: !!nextBtn,
  prev: !!prevBtn,
  playPause: !!playPauseBtn
});

// Vérification 3: Test de synchronisation en action
console.log('\n🎯 3. Test de synchronisation:');

window.testSync = async function() {
  console.log('🚀 Démarrage test synchronisation...');
  
  // Obtenir l'état initial
  const before = await window.electron.queue.getState();
  console.log('État avant:', { 
    isPlaying: before.isPlaying, 
    isPaused: before.isPaused, 
    currentIndex: before.currentIndex 
  });
  
  // Simuler navigation
  if (nextBtn) {
    console.log('📦 Clic sur Next...');
    nextBtn.click();
    
    // Vérifier après 1 seconde
    setTimeout(async () => {
      const after = await window.electron.queue.getState();
      console.log('État après navigation:', { 
        isPlaying: after.isPlaying, 
        isPaused: after.isPaused, 
        currentIndex: after.currentIndex 
      });
      
      // Vérifier l'UI
      const currentButtons = document.querySelectorAll('.bg-blue-500');
      console.log('✅ Boutons actifs dans UI:', currentButtons.length);
      
      if (playPauseBtn) {
        console.log('✅ Bouton play/pause:', playPauseBtn.textContent.trim());
      }
      
      console.log('🏁 Test synchronisation terminé');
    }, 1500);
  } else {
    console.log('❌ Bouton next non trouvé');
  }
};

// Vérification 4: Écouter les changements d'état
console.log('\n📡 4. Surveillance changements état:');

let lastState = null;
window.monitorChanges = function() {
  const interval = setInterval(async () => {
    const currentState = await window.electron.queue.getState();
    
    if (!lastState || 
        lastState.isPlaying !== currentState.isPlaying || 
        lastState.currentIndex !== currentState.currentIndex) {
      
      console.log('🔄 Changement détecté:', {
        from: lastState ? { isPlaying: lastState.isPlaying, index: lastState.currentIndex } : 'initial',
        to: { isPlaying: currentState.isPlaying, index: currentState.currentIndex }
      });
      
      lastState = currentState;
    }
  }, 1000);
  
  console.log('📡 Surveillance démarrée (tapez clearInterval(' + interval + ') pour arrêter)');
  return interval;
};

console.log('\n🎮 COMMANDES DISPONIBLES:');
console.log('- testSync() : Tester la synchronisation');
console.log('- monitorChanges() : Surveiller les changements');
console.log('');
console.log('💡 Testez maintenant les boutons et vérifiez que tout est synchronisé !');
