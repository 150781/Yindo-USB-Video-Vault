// Test direct de la queue et lecture
console.log('[TEST QUEUE] Début du test...');

// Item de test avec les bonnes données
const testItem = {
  id: 'asset:0e487acaa1760f895085ea84d05a5adb58f88a37',
  title: 'Aamron Feat Toofan   Adjinon',
  artist: 'Aamron Feat Toofan',
  year: 2023,
  genre: 'Afrobeat',
  durationMs: null,
  source: 'asset',
  src: 'asset://media/Aamron%20Feat%20Toofan%20-%20Adjinon.mp4'
};

console.log('[TEST QUEUE] Item de test:', JSON.stringify(testItem, null, 2));

// Dans le navigateur, exécute:
// window.electron.queue.playNow(testItem)
// Puis vérifie les logs Electron

console.log('[TEST QUEUE] Instructions:');
console.log('1. Ouvre la console DevTools dans l\'app');
console.log('2. Exécute: window.electron.queue.playNow(' + JSON.stringify(testItem) + ')');
console.log('3. Vérifie les logs pour voir si DisplayApp reçoit player:open');
console.log('4. Vérifie si la vidéo se charge et démarre');
