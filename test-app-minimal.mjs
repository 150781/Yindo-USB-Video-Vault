/**
 * Version minimale de l'app pour isoler le problème de plantage
 */

import { app } from 'electron';
import { VaultManager, resolveVaultPath } from './dist/main/vault.js';
import { loadAndValidateLicense } from './dist/main/licenseSecure.js';

// Forcer mode production
const isDev = !app.isPackaged && process.env.FORCE_PRODUCTION !== 'true';

console.log('🚀 App minimale - isDev:', isDev);

app.whenReady().then(async () => {
  console.log('[MINIMAL] App ready');
  
  // Test vault manager
  console.log('[MINIMAL] Test VaultManager...');
  const vaultManager = new VaultManager();
  try {
    await vaultManager.init(resolveVaultPath());
    console.log('[MINIMAL] ✅ VaultManager init OK');
  } catch (err) {
    console.error('[MINIMAL] ❌ VaultManager init failed:', err);
    return;
  }
  
  // Test licence
  console.log('[MINIMAL] Test Licence...');
  try {
    const licenseResult = await loadAndValidateLicense(resolveVaultPath());
    console.log('[MINIMAL] Résultat licence:', licenseResult);
    
    if (!licenseResult.isValid && !isDev) {
      console.error('[MINIMAL] 🛑 Licence invalide en mode production - QUIT');
      app.quit();
      return;
    } else {
      console.log('[MINIMAL] ✅ Licence OK ou mode DEV');
    }
  } catch (err) {
    console.error('[MINIMAL] ❌ Erreur licence:', err);
    if (!isDev) {
      console.error('[MINIMAL] 🛑 Erreur licence en mode production - QUIT');
      app.quit();
      return;
    }
  }
  
  console.log('[MINIMAL] 🎉 App minimale terminée avec succès');
  setTimeout(() => app.quit(), 1000);
});

if (!app.requestSingleInstanceLock()) {
  app.quit();
}