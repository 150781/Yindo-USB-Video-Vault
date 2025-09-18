#!/usr/bin/env node

/**
 * Test de validation des corrections VAULT_PATH et messages d'erreur
 */

import { getVaultRoot, ensureVaultReadyOrThrow } from '../dist/main/vaultPath.js';
import fs from 'fs';
import path from 'path';

console.log('=== Test de validation VAULT_PATH ===\n');

// Test 1: Vault existant
console.log('📁 Test 1: Vault existant');
process.env.VAULT_PATH = 'usb-package/vault';
try {
  const vault = getVaultRoot();
  console.log('✓ getVaultRoot():', vault);
  ensureVaultReadyOrThrow();
  console.log('✓ ensureVaultReadyOrThrow(): OK\n');
} catch (e) {
  console.log('✗ Erreur inattendue:', e.message, '\n');
}

// Test 2: Vault inexistant 
console.log('📁 Test 2: Vault inexistant');
process.env.VAULT_PATH = 'vault-inexistant';
try {
  const vault = getVaultRoot();
  console.log('✓ getVaultRoot():', vault);
  ensureVaultReadyOrThrow();
  console.log('✗ Aucune erreur (inattendu)\n');
} catch (e) {
  console.log('✓ Erreur attendue détectée');
  console.log('✓ Code:', e.code);
  console.log('✓ Message:');
  console.log(e.message);
  console.log('');
}

// Test 3: Auto-détection depuis working directory
console.log('📁 Test 3: Auto-détection');
delete process.env.VAULT_PATH;
process.chdir('usb-package');
try {
  const vault = getVaultRoot();
  console.log('✓ getVaultRoot():', vault);
  ensureVaultReadyOrThrow();
  console.log('✓ Auto-détection: OK\n');
} catch (e) {
  console.log('✗ Erreur auto-détection:', e.message, '\n');
}

console.log('🎉 Tests terminés');
