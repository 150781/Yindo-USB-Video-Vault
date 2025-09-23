// Garantit que package.json est en UTF-8 sans BOM, sans U+FEFF parasite,
// et sans espaces avant la première accolade.

const fs = require('fs');

const path = './package.json';
let raw = fs.readFileSync(path);

console.log('[sanitize-package-json] Nettoyage de package.json...');
console.log('[sanitize-package-json] Taille originale:', raw.length, 'bytes');

// strip BOM UTF-8 si présent
if (raw[0] === 0xEF && raw[1] === 0xBB && raw[2] === 0xBF) {
  console.log('[sanitize-package-json] BOM UTF-8 détecté et supprimé');
  raw = raw.slice(3);
}

// texte en utf8
let text = raw.toString('utf8');

// enlève TOUT U+FEFF et les espaces avant la 1ère "{"
const originalLength = text.length;
text = text.replace(/\uFEFF/g, '').replace(/^\s*(?=\{)/, '');
if (text.length !== originalLength) {
  console.log('[sanitize-package-json] Caractères U+FEFF ou espaces parasites supprimés');
}

let obj;
try {
  obj = JSON.parse(text);
  console.log('[sanitize-package-json] JSON parsé avec succès');
} catch (e) {
  console.error('[sanitize-package-json] JSON invalide. Erreur:', e.message);
  process.exit(1);
}

// réécrit joliment en UTF-8 **sans BOM**
const cleanJson = JSON.stringify(obj, null, 2) + '\r\n';
fs.writeFileSync(path, cleanJson, { encoding: 'utf8' });

// contrôle rapide (doit commencer par "{")
const b = fs.readFileSync(path);
console.log('[sanitize-package-json] First3Bytes =', b[0], b[1], b[2]); // 123,13,10 sur Windows
console.log('[sanitize-package-json] Nouvelle taille:', b.length, 'bytes');
console.log('[sanitize-package-json] ✅ package.json nettoyé et réécrit sans BOM');
