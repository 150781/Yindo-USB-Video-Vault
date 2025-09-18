// Script de test manuel pour la synchronisation des contrôles
// À exécuter dans la console DevTools de la fenêtre de contrôle

console.log('🎯 Test de synchronisation des contrôles - Version manuelle');

// Test 1: Vérifier l'état initial
console.log('📊 Test 1: État initial');
window.electron.queue.getState().then(state => {
  console.log('État initial:', state);
});

// Test 2: Fonction pour tester la synchronisation
window.testSynchronization = async function() {
  console.log('🔄 Début du test de synchronisation...');
  
  // Obtenir l'état actuel
  const initialState = await window.electron.queue.getState();
  console.log('État initial:', initialState);
  
  // Simuler un clic sur play
  console.log('🎵 Test: Clic sur play...');
  const playButtons = document.querySelectorAll('[data-testid="play-button"]');
  if (playButtons.length > 0) {
    playButtons[0].click();
    console.log('✅ Bouton play cliqué');
    
    // Attendre et vérifier l'état
    setTimeout(async () => {
      const newState = await window.electron.queue.getState();
      console.log('État après play:', newState);
      
      // Vérifier l'UI
      const topButton = document.querySelector('[data-testid="top-play-pause-button"]');
      console.log('Bouton du haut:', topButton ? topButton.textContent.trim() : 'non trouvé');
      
      const activeButtons = document.querySelectorAll('.bg-blue-500');
      console.log('Boutons actifs:', activeButtons.length);
      
    }, 1000);
  } else {
    console.log('❌ Aucun bouton play trouvé');
  }
};

// Test 3: Fonction pour tester les contrôles du haut
window.testTopControls = function() {
  console.log('⏯️ Test des contrôles du haut...');
  
  const pauseBtn = document.querySelector('[data-testid="top-pause-button"]');
  const playBtn = document.querySelector('[data-testid="top-play-button"]');
  const nextBtn = document.querySelector('[data-testid="top-next-button"]');
  const prevBtn = document.querySelector('[data-testid="top-prev-button"]');
  
  console.log('Boutons trouvés:', {
    pause: !!pauseBtn,
    play: !!playBtn,
    next: !!nextBtn,
    prev: !!prevBtn
  });
  
  if (nextBtn) {
    console.log('🔄 Test: Clic sur next...');
    nextBtn.click();
  }
};

// Test 4: Afficher l'état en temps réel
window.monitorState = function() {
  console.log('📺 Surveillance de l\'état en temps réel...');
  
  const monitor = setInterval(async () => {
    const state = await window.electron.queue.getState();
    const topButton = document.querySelector('[data-testid="top-play-pause-button"]');
    const activeButtons = document.querySelectorAll('.bg-blue-500');
    
    console.log('État temps réel:', {
      queue: state,
      topButtonText: topButton ? topButton.textContent.trim() : 'non trouvé',
      activeButtons: activeButtons.length
    });
  }, 2000);
  
  // Arrêter après 30 secondes
  setTimeout(() => {
    clearInterval(monitor);
    console.log('📺 Surveillance arrêtée');
  }, 30000);
  
  return monitor;
};

console.log('🚀 Fonctions de test disponibles:');
console.log('- testSynchronization() : Test de base');
console.log('- testTopControls() : Test contrôles du haut');
console.log('- monitorState() : Surveillance temps réel');
console.log('');
console.log('💡 Pour commencer, tapez: testSynchronization()');
