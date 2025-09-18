// tools/packager/issue-license.cjs
const fs = require('fs');
const path = require('path');
const nacl = require('tweetnacl');

function usage() {
  console.log('Usage: node tools/packager/issue-license.cjs --vault "<VAULT_PATH>" --device <SHA256HEX> --owner "Nom" --expiry 2027-12-31');
  process.exit(1);
}

// Parse arguments more robustly
const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg.startsWith('--')) {
    const key = arg;
    const value = process.argv[i + 1] || '';
    args[key] = value;
    i++; // skip next arg as it's the value
  }
}

const vault = (args['--vault'] || '').replace(/^"|"$/g,'');
const device = (args['--device'] || '').toLowerCase();
const owner = (args['--owner'] || '');
const expiry = (args['--expiry'] || '');

console.log('Arguments parsed:', { vault, device, owner, expiry });

if (!vault || !device) {
  console.error('Missing required arguments: --vault and --device');
  usage();
}

const privPath = process.env.PACKAGER_PRIV || path.resolve('tools/packager/keys/private_key'); // base64 Ed25519 seed or 64-bytes key?
const privB64 = fs.readFileSync(privPath,'utf8').trim();
const priv = Buffer.from(privB64, 'base64');
const key = priv.length === 64 ? priv : nacl.sign.keyPair.fromSeed(priv).secretKey;

const body = {
  version: 1,
  owner,
  device,                     // SHA-256 hex du poste cible
  notBefore: new Date().toISOString(),
  expiry: expiry ? new Date(expiry).toISOString() : undefined,
  allow: ['*'],
};
const bytes = Buffer.from(JSON.stringify(body), 'utf8');
const sig = nacl.sign.detached(bytes, key);
const sigB64 = Buffer.from(sig).toString('base64');

const dir = path.join(vault, '.vault');
fs.mkdirSync(dir, { recursive: true });
const bodyCompact = JSON.stringify(body); // format compact pour signature
fs.writeFileSync(path.join(dir, 'license.json'), bodyCompact, 'utf8');
fs.writeFileSync(path.join(dir, 'license.sig'), sigB64, 'utf8');

console.log('✔ Licence émise pour device=', device);
console.log('Files:\n ', path.join(dir,'license.json'), '\n ', path.join(dir,'license.sig'));
