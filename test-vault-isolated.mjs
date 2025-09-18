/**
 * Test isolé de VaultManager.init()
 */

import { VaultManager } from './dist/main/vault.js';
import path from 'path';

async function testVaultInit() {
  console.log('🔍 Test isolé de VaultManager.init()...');
  
  const vaultPath = path.resolve('./usb-package/vault');
  console.log('📁 Vault path:', vaultPath);
  
  try {
    console.log('🚀 Création VaultManager...');
    const vaultManager = new VaultManager();
    
    console.log('🔧 Appel init()...');
    await vaultManager.init(vaultPath);
    
    console.log('✅ VaultManager.init() réussi !');
    console.log('📊 Vault initialisé pour device:', vaultManager.tag?.deviceId);
    
  } catch (error) {
    console.error('💥 Erreur VaultManager.init():', error);
    console.error('📚 Stack:', error.stack);
  }
}

testVaultInit().catch(console.error);