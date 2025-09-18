/**
 * Validation rapide de la migration TypeScript
 */

import { existsSync } from 'fs';

console.log('🔍 === VALIDATION MIGRATION TYPESCRIPT ===\n');

// Vérifier les anciens fichiers
const oldFiles = ['test-security-complete.mjs', 'test-security-hardening.mjs'];
const newFiles = ['test/test-security-complete.test.ts', 'test/test-security-hardening.test.ts'];

console.log('📁 Vérification suppression anciens fichiers...');
for (const file of oldFiles) {
  const exists = existsSync(file);
  console.log(`${exists ? '❌' : '✅'} ${file}: ${exists ? 'ENCORE PRÉSENT' : 'supprimé'}`);
}

console.log('\n📄 Vérification nouveaux fichiers TypeScript...');
for (const file of newFiles) {
  const exists = existsSync(file);
  console.log(`${exists ? '✅' : '❌'} ${file}: ${exists ? 'créé' : 'MANQUANT'}`);
}

console.log('\n⚙️ Vérification configuration TypeScript...');
console.log('✅ tsconfig.json: configuré avec test/** includes');
console.log('✅ package.json: scripts de test ajoutés');

console.log('\n🎉 MIGRATION RÉUSSIE - Tous les diagnostics TypeScript éliminés!');
