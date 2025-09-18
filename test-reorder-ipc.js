// Test de diagnostic pour l'IPC reorder
console.log('=== TEST DIAGNOSTIC IPC REORDER ===');

// Simuler l'environnement de test
async function testReorderIPC() {
  try {
    // Vérifier si window.electron existe
    console.log('1. Vérification window.electron:', typeof window?.electron);
    
    if (!window?.electron) {
      console.error('❌ window.electron non disponible');
      return;
    }
    
    // Vérifier si queue existe
    console.log('2. Vérification electron.queue:', typeof window.electron.queue);
    
    if (!window.electron.queue) {
      console.error('❌ electron.queue non disponible');
      return;
    }
    
    // Lister toutes les méthodes queue disponibles
    console.log('3. Méthodes queue disponibles:', Object.keys(window.electron.queue));
    
    // Vérifier spécifiquement reorder
    console.log('4. Vérification electron.queue.reorder:', typeof window.electron.queue.reorder);
    
    if (typeof window.electron.queue.reorder !== 'function') {
      console.error('❌ electron.queue.reorder n\'est pas une fonction');
      return;
    }
    
    // Test simple de l'appel reorder
    console.log('5. Test appel reorder(0, 1)...');
    const result = await window.electron.queue.reorder(0, 1);
    console.log('6. Résultat reorder:', result);
    
    if (result) {
      console.log('✅ IPC reorder fonctionne!');
    } else {
      console.log('⚠️ IPC reorder retourne null/undefined');
    }
    
  } catch (error) {
    console.error('❌ Erreur lors du test reorder:', error);
  }
}

// Attendre que l'environnement soit prêt
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', testReorderIPC);
} else {
  testReorderIPC();
}
