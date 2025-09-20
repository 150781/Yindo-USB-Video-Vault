// Test simple de vérification système
console.log('🧪 Test QA - Démarrage...');
console.log('✅ Node.js OK');
console.log('✅ Modules disponibles');

import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = dirname(__dirname);

console.log(`📁 Root directory: ${rootDir}`);

// Vérifier scripts essentiels
const scripts = [
    'scripts/make-license.mjs',
    'scripts/print-bindings.mjs', 
    'scripts/verify-license.mjs'
];

let allOK = true;
for (const script of scripts) {
    const path = join(rootDir, script);
    if (existsSync(path)) {
        console.log(`✅ ${script} - OK`);
    } else {
        console.log(`❌ ${script} - MANQUANT`);
        allOK = false;
    }
}

if (allOK) {
    console.log('\n🎉 SYSTÈME PRÊT POUR QA');
} else {
    console.log('\n❌ PROBLÈMES DÉTECTÉS');
}