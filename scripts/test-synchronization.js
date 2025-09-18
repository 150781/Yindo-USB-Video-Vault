// Test de synchronisation des contrôles de lecture
import { app, BrowserWindow } from 'electron';

async function testSynchronization() {
  console.log('[TEST] 🎯 Test de synchronisation des contrôles');
  
  await app.whenReady();
  
  // Attendre que les fenêtres soient prêtes
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  const allWindows = BrowserWindow.getAllWindows();
  const controlWindow = allWindows.find(w => w.webContents.getURL().includes('index.html'));
  const displayWindow = allWindows.find(w => w.webContents.getURL().includes('display.html'));
  
  if (!controlWindow) {
    console.log('[TEST] ❌ Fenêtre de contrôle non trouvée');
    return;
  }
  
  if (!displayWindow) {
    console.log('[TEST] ❌ Fenêtre display non trouvée');
    return;
  }
  
  console.log('[TEST] ✅ Fenêtres trouvées');
  
  // Test 1: Vérifier l'état initial
  console.log('[TEST] 📊 Test 1: État initial');
  const initialState = await controlWindow.webContents.executeJavaScript(`
    window.electron.queue.getState()
  `);
  console.log('[TEST] État initial:', initialState);
  
  // Test 2: Cliquer sur play depuis un bouton de chanson
  console.log('[TEST] 🎵 Test 2: Play depuis bouton de chanson');
  await controlWindow.webContents.executeJavaScript(`
    // Simuler un clic sur le premier bouton "Lire"
    const firstPlayButton = document.querySelector('[data-testid="play-button"]');
    if (firstPlayButton) {
      firstPlayButton.click();
      console.log('[TEST] Bouton "Lire" cliqué');
    } else {
      console.log('[TEST] Bouton "Lire" non trouvé');
    }
  `);
  
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Vérifier l'état après play
  const stateAfterPlay = await controlWindow.webContents.executeJavaScript(`
    window.electron.queue.getState()
  `);
  console.log('[TEST] État après play:', stateAfterPlay);
  
  // Test 3: Utiliser les contrôles de la barre du haut
  console.log('[TEST] ⏸️ Test 3: Pause depuis barre du haut');
  await controlWindow.webContents.executeJavaScript(`
    const pauseButton = document.querySelector('[data-testid="top-pause-button"]');
    if (pauseButton) {
      pauseButton.click();
      console.log('[TEST] Bouton pause du haut cliqué');
    } else {
      console.log('[TEST] Bouton pause du haut non trouvé');
    }
  `);
  
  await new Promise(resolve => setTimeout(resolve, 500));
  
  const stateAfterPause = await controlWindow.webContents.executeJavaScript(`
    window.electron.queue.getState()
  `);
  console.log('[TEST] État après pause:', stateAfterPause);
  
  // Test 4: Next depuis barre du haut
  console.log('[TEST] ⏭️ Test 4: Next depuis barre du haut');
  await controlWindow.webContents.executeJavaScript(`
    const nextButton = document.querySelector('[data-testid="top-next-button"]');
    if (nextButton) {
      nextButton.click();
      console.log('[TEST] Bouton next du haut cliqué');
    } else {
      console.log('[TEST] Bouton next du haut non trouvé');
    }
  `);
  
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  const stateAfterNext = await controlWindow.webContents.executeJavaScript(`
    window.electron.queue.getState()
  `);
  console.log('[TEST] État après next:', stateAfterNext);
  
  // Test 5: Vérifier que l'UI reflète l'état
  console.log('[TEST] 🎨 Test 5: Synchronisation UI');
  const uiState = await controlWindow.webContents.executeJavaScript(`
    const topPlayPause = document.querySelector('[data-testid="top-play-pause-button"]');
    const currentSongButton = document.querySelector('.bg-blue-500[data-testid="play-button"]');
    
    return {
      topButtonText: topPlayPause ? topPlayPause.textContent.trim() : 'non trouvé',
      currentSongButtonStyle: currentSongButton ? 'actif' : 'inactif',
      hasActiveButton: !!document.querySelector('.bg-blue-500')
    };
  `);
  console.log('[TEST] État UI:', uiState);
  
  console.log('[TEST] 🏁 Test de synchronisation terminé');
}

// Lancer le test
if (import.meta.url === `file://${process.argv[1]}`) {
  testSynchronization().catch(console.error);
}

export { testSynchronization };
