const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Utilise crypto.generateKeyPairSync pour Ed25519
const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519', {
  publicKeyEncoding: { type: 'spki', format: 'der' },
  privateKeyEncoding: { type: 'pkcs8', format: 'der' }
});

// Extraire les octets bruts (32 bytes pour Ed25519)
const pubRaw = publicKey.slice(-32);  // Derniers 32 bytes du DER
const privRaw = privateKey.slice(-32); // Derniers 32 bytes du DER

// Encoder en base64
const pubB64 = pubRaw.toString('base64');
const privB64 = privRaw.toString('base64');

console.log('Generated new Ed25519 keypair:');
console.log('Public key (32 bytes):', pubB64);
console.log('Private key (32 bytes):', privB64);

// Sauvegarder les clés
const toolsDir = path.join(__dirname, '..', 'tools', 'packager', 'keys');
fs.writeFileSync(path.join(toolsDir, 'public_key'), pubB64);
fs.writeFileSync(path.join(toolsDir, 'private_key'), privB64);

console.log('Keys saved to tools/packager/keys/');

// Mettre à jour packagerPublicKey.ts
const srcDir = path.join(__dirname, '..', 'src', 'shared', 'keys');
const keyCode = `export const packagerPublicKey = '${pubB64}';
`;

fs.writeFileSync(path.join(srcDir, 'packagerPublicKey.ts'), keyCode);
console.log('Updated src/shared/keys/packagerPublicKey.ts');
