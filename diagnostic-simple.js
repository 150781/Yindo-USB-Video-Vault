// Script de diagnostic simple - à coller dans la console DevTools
console.log('=== DIAGNOSTIC YINDO ===');

// 1. Vérifier window.electron
if (typeof window.electron === 'undefined') {
  console.error('❌ window.electron non disponible');
} else {
  console.log('✅ window.electron disponible');
  console.log('API disponibles:', Object.keys(window.electron));
}

// 2. Test basique de queue
async function testQueue() {
  try {
    if (!window.electron?.queue) {
      console.error('❌ window.electron.queue non disponible');
      return;
    }
    
    console.log('--- Test Queue Get ---');
    const queueState = await window.electron.queue.get();
    console.log('Queue actuelle:', queueState);
    
    console.log('--- Test Queue SetRepeat ---');
    const repeatResult = await window.electron.queue.setRepeat({ mode: 'one' });
    console.log('Résultat setRepeat:', repeatResult);
    
  } catch (error) {
    console.error('❌ Erreur test queue:', error);
  }
}

// 3. Test basique de catalogue
async function testCatalog() {
  try {
    if (!window.electron?.catalog) {
      console.error('❌ window.electron.catalog non disponible');
      return;
    }
    
    console.log('--- Test Catalog List ---');
    const catalogResult = await window.electron.catalog.list();
    console.log('Catalogue:', catalogResult);
    
  } catch (error) {
    console.error('❌ Erreur test catalogue:', error);
  }
}

// 4. Test de lecture simple
async function testPlayNow() {
  try {
    if (!window.electron?.queue) {
      console.error('❌ window.electron.queue non disponible');
      return;
    }
    
    console.log('--- Test PlayNow ---');
    const testVideo = {
      id: 'asset:test',
      title: 'Test Video',
      source: 'asset',
      src: 'asset://media/Odogwu.mp4'
    };
    
    const playResult = await window.electron.queue.playNow(testVideo);
    console.log('Résultat playNow:', playResult);
    
  } catch (error) {
    console.error('❌ Erreur test playNow:', error);
  }
}

// Exécuter tous les tests
async function runAllTests() {
  await testQueue();
  await testCatalog();
  await testPlayNow();
  console.log('=== FIN DIAGNOSTIC ===');
}

// Auto-exécution
runAllTests();
