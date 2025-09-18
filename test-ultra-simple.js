// SCRIPT DE TEST ULTRA SIMPLE
// Copiez-collez cette ligne dans la console DevTools de l'application

console.log('🔍 Test de base Yindo');

// Test 1: Vérifier window.electron
if (typeof window.electron !== 'undefined') {
  console.log('✅ window.electron disponible');
  console.log('APIs:', Object.keys(window.electron));
} else {
  console.log('❌ window.electron introuvable');
}

// Test 2: Test mode repeat (le plus simple)
if (window.electron?.queue?.setRepeat) {
  window.electron.queue.setRepeat({ mode: 'one' })
    .then(result => console.log('✅ Repeat mode activé:', result.repeatMode))
    .catch(err => console.log('❌ Erreur repeat:', err));
} else {
  console.log('❌ queue.setRepeat introuvable');
}

// Test 3: Test lecture basique
if (window.electron?.queue?.playNow) {
  const testVideo = {
    id: 'asset:test-simple',
    title: 'Test Simple',
    source: 'asset',
    src: 'asset://media/Odogwu.mp4'
  };
  
  window.electron.queue.playNow(testVideo)
    .then(result => console.log('✅ PlayNow fonctionne:', result))
    .catch(err => console.log('❌ Erreur playNow:', err));
} else {
  console.log('❌ queue.playNow introuvable');
}

console.log('🏁 Fin des tests');
