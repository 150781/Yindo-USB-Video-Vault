/**
 * Script de diagnostic pour tester le clic sur playlist
 * À exécuter dans la console DevTools de l'application
 */

console.log('=== DIAGNOSTIC PLAYLIST CLICK ===');

// 1. Vérifier que l'API electron est disponible
if (!window.electron) {
  console.error('❌ window.electron n\'est pas disponible');
} else {
  console.log('✅ window.electron est disponible');
  console.log('Queue API:', window.electron.queue);
  console.log('Catalog API:', window.electron.catalog);
}

// 2. Test de récupération du catalogue
async function testCatalog() {
  try {
    console.log('\n--- Test Catalog ---');
    const catalogResult = await window.electron.catalog.list();
    console.log('Résultat catalog.list():', catalogResult);
    
    if (catalogResult && catalogResult.ok && Array.isArray(catalogResult.list)) {
      console.log(`✅ Catalogue récupéré: ${catalogResult.list.length} éléments`);
      if (catalogResult.list.length > 0) {
        console.log('Premier élément:', catalogResult.list[0]);
      }
    } else {
      console.error('❌ Format de catalogue invalide');
    }
  } catch (error) {
    console.error('❌ Erreur lors de la récupération du catalogue:', error);
  }
}

// 3. Test de récupération de la queue
async function testQueue() {
  try {
    console.log('\n--- Test Queue ---');
    const queueResult = await window.electron.queue.get();
    console.log('Résultat queue.get():', queueResult);
    
    if (queueResult && typeof queueResult === 'object') {
      console.log(`✅ Queue récupérée: ${queueResult.items?.length || 0} éléments`);
      console.log('État de lecture:', {
        currentIndex: queueResult.currentIndex,
        isPlaying: queueResult.isPlaying,
        isPaused: queueResult.isPaused,
        repeatMode: queueResult.repeatMode
      });
    } else {
      console.error('❌ Format de queue invalide');
    }
  } catch (error) {
    console.error('❌ Erreur lors de la récupération de la queue:', error);
  }
}

// 4. Test d'ajout et de lecture d'un élément
async function testPlayNow() {
  try {
    console.log('\n--- Test PlayNow ---');
    
    // D'abord récupérer le catalogue
    const catalogResult = await window.electron.catalog.list();
    if (!catalogResult?.ok || !catalogResult.list?.length) {
      console.error('❌ Aucun élément dans le catalogue pour tester');
      return;
    }
    
    const firstItem = catalogResult.list[0];
    console.log('Test avec l\'élément:', firstItem);
    
    // Convertir au format QueueItem attendu
    const queueItem = {
      id: firstItem.id,
      title: firstItem.title || 'Sans titre',
      source: firstItem.source,
      mediaId: firstItem.mediaId,
      src: firstItem.src,
      artist: firstItem.artist,
      genre: firstItem.genre,
      year: firstItem.year
    };
    
    // Tester playNow
    const playResult = await window.electron.queue.playNow(queueItem);
    console.log('Résultat playNow:', playResult);
    
    if (playResult && typeof playResult === 'object') {
      console.log('✅ PlayNow exécuté avec succès');
      console.log('Nouvel état de la queue:', {
        items: playResult.items?.length || 0,
        currentIndex: playResult.currentIndex,
        isPlaying: playResult.isPlaying
      });
    }
  } catch (error) {
    console.error('❌ Erreur lors du test playNow:', error);
  }
}

// 5. Exécuter tous les tests
async function runAllTests() {
  await testCatalog();
  await testQueue();
  await testPlayNow();
  
  console.log('\n=== FIN DU DIAGNOSTIC ===');
  console.log('Pour tester le repeat mode:');
  console.log('await window.electron.queue.setRepeat({ mode: "one" })');
}

// Exécuter automatiquement
runAllTests();
