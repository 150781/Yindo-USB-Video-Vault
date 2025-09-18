// tools/packager/verify-license.cjs
const fs = require('fs');
const path = require('path');
const nacl = require('tweetnacl');

function u16le(b,o){ return b.readUInt16LE(o); }
function u32le(b,o){ return b.readUInt32LE(o); }

function verify(vaultPath, packagerPubB64){
  const p = path.join(vaultPath, '.vault', 'license.bin');
  const bin = fs.readFileSync(p);
  let off = 0;
  const magic = bin.subarray(off, off+4); off+=4;
  if (!magic.equals(Buffer.from([0x4c,0x56,0x4c,0x54]))) throw new Error('MAGIC invalide');
  // body = tout entre magic et bloc signature
  const version = bin.readUInt8(off); off+=1;
  const nlen = u32le(bin, off); off+=4; off+=nlen; // nonce
  const ctlen = u32le(bin, off); off+=4; off+=ctlen; // ct
  const taglen = u32le(bin, off); off+=4; off+=taglen; // tag
  const sigAlgo = u16le(bin, off); off+=2;
  const sigLen = u32le(bin, off); off+=4;
  const signature = bin.subarray(off, off+sigLen);
  const body = bin.subarray(4, bin.length - (2+4+sigLen));
  if (sigAlgo !== 1) throw new Error('Algo signature inconnu (attendu: 1=Ed25519)');
  const pub = Buffer.from(packagerPubB64, 'base64');
  const ok = nacl.sign.detached.verify(body, signature, pub);
  return ok;
}

const vault = process.argv[2]; // chemin du vault
const pubB64 = (process.argv[3] || '').trim(); // optionnel, sinon lit le fichier public_key
if (!vault) {
  console.error('Usage: node verify-license.cjs <VAULT_PATH> [PACKAGER_PUBLIC_KEY_B64]');
  process.exit(1);
}
let keyB64 = pubB64;
if (!keyB64) {
  const f = process.env.PACKAGER_PUB || path.resolve('tools/packager/keys/public_key');
  keyB64 = fs.readFileSync(f,'utf8').trim();
}

console.log('Vérification licence.bin …');
const ok = verify(vault, keyB64);
console.log(ok ? '✔ Signature VALIDE' : '✖ Signature INVALIDE');
process.exit(ok ? 0 : 2);
