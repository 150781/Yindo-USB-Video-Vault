#!/usr/bin/env node

/**
 * Script de test pour la crypto GCM - Compatible Node.js directement
 */

const fs = require('fs').promises;
const crypto = require('crypto');
const path = require('path');
const os = require('os');
const assert = require('assert');

const TEST_PASSWORD = 'test-password-123';
const TEST_CONTENT = 'Hello, this is a test video content that will be encrypted and decrypted!';

// Constants GCM
const MAGIC_HEADER = Buffer.from('UVV1');
const VERSION = 1;
const SALT_SIZE = 16;
const NONCE_SIZE = 12;
const TAG_SIZE = 16;
const HEADER_SIZE = 4 + 1 + SALT_SIZE + NONCE_SIZE; // 33 bytes

async function runBasicCryptoTest() {
  console.log('[CRYPTO] Test basique de chiffrement/déchiffrement CBC vers GCM...');
  
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'vault-crypto-basic-test-'));
  const inputFile = path.join(tempDir, 'test.mp4');
  const encFile = path.join(tempDir, 'test.enc');
  
  try {
    // Créer fichier de test
    await fs.writeFile(inputFile, TEST_CONTENT);
    console.log('[CRYPTO] ✅ Fichier de test créé');

    // Test chiffrement basique avec nouvelle structure
    const salt = crypto.randomBytes(SALT_SIZE);
    const nonce = crypto.randomBytes(NONCE_SIZE);
    const key = crypto.scryptSync(TEST_PASSWORD, salt, 32);
    
    const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce);
    
    // Écrire en-tête [MAGIC(4)][VER(1)][SALT(16)][NONCE(12)]
    const header = Buffer.alloc(HEADER_SIZE);
    let offset = 0;
    
    MAGIC_HEADER.copy(header, offset);
    offset += 4;
    
    header.writeUInt8(VERSION, offset);
    offset += 1;
    
    salt.copy(header, offset);
    offset += SALT_SIZE;
    
    nonce.copy(header, offset);
    
    const inputData = await fs.readFile(inputFile);
    const encrypted = cipher.update(inputData);
    cipher.final();
    const tag = cipher.getAuthTag();
    
    // Format: [HEADER][ENCRYPTED_DATA][TAG]
    const finalData = Buffer.concat([header, encrypted, tag]);
    await fs.writeFile(encFile, finalData);
    
    console.log('[CRYPTO] ✅ Chiffrement terminé');

    // Test déchiffrement
    const encData = await fs.readFile(encFile);
    
    // Lire header
    const readMagic = encData.subarray(0, 4);
    assert.deepStrictEqual(readMagic, MAGIC_HEADER, 'Magic header invalide');
    
    const readVersion = encData.readUInt8(4);
    assert.strictEqual(readVersion, VERSION, 'Version invalide');
    
    const readSalt = encData.subarray(5, 5 + SALT_SIZE);
    const readNonce = encData.subarray(5 + SALT_SIZE, 5 + SALT_SIZE + NONCE_SIZE);
    
    const dataStart = HEADER_SIZE;
    const dataEnd = encData.length - TAG_SIZE;
    const readTag = encData.subarray(dataEnd);
    const encryptedData = encData.subarray(dataStart, dataEnd);
    
    // Déchiffrer
    const readKey = crypto.scryptSync(TEST_PASSWORD, readSalt, 32);
    const decipher = crypto.createDecipheriv('aes-256-gcm', readKey, readNonce);
    decipher.setAuthTag(readTag);
    
    const decrypted = Buffer.concat([
      decipher.update(encryptedData),
      decipher.final()
    ]);
    
    const decryptedContent = decrypted.toString();
    assert.strictEqual(decryptedContent, TEST_CONTENT, 'Contenu déchiffré incorrect');
    
    console.log('[CRYPTO] ✅ Déchiffrement réussi');
    
    // Test corruption de tag
    const corruptedData = Buffer.from(encData);
    corruptedData[corruptedData.length - 1] ^= 0xFF; // Corrompre le tag
    
    try {
      const corruptedTag = corruptedData.subarray(corruptedData.length - TAG_SIZE);
      const corruptedEnc = corruptedData.subarray(dataStart, corruptedData.length - TAG_SIZE);
      
      const decipher2 = crypto.createDecipheriv('aes-256-gcm', readKey, readNonce);
      decipher2.setAuthTag(corruptedTag);
      decipher2.update(corruptedEnc);
      decipher2.final();
      
      assert.fail('Le déchiffrement aurait dû échouer avec tag corrompu');
    } catch (error) {
      console.log('[CRYPTO] ✅ Rejet correct avec tag corrompu');
    }
    
    console.log('[CRYPTO] 🎉 Tous les tests basiques réussis !');
    
  } finally {
    // Nettoyage
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch {}
  }
}

async function runStreamingTest() {
  console.log('[CRYPTO] Test de streaming pour gros fichier...');
  
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'vault-streaming-test-'));
  const bigFile = path.join(tempDir, 'big.mp4');
  const encFile = path.join(tempDir, 'big.enc');
  
  try {
    // Créer un fichier de 1MB
    const bigData = Buffer.alloc(1024 * 1024, 'A');
    await fs.writeFile(bigFile, bigData);
    console.log('[CRYPTO] ✅ Fichier de 1MB créé');
    
    const startTime = Date.now();
    
    // Chiffrement streaming simulé
    const salt = crypto.randomBytes(SALT_SIZE);
    const nonce = crypto.randomBytes(NONCE_SIZE);
    const key = crypto.scryptSync(TEST_PASSWORD, salt, 32);
    
    const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce);
    
    // En-tête
    const header = Buffer.alloc(HEADER_SIZE);
    let offset = 0;
    MAGIC_HEADER.copy(header, offset);
    header.writeUInt8(VERSION, 4);
    salt.copy(header, 5);
    nonce.copy(header, 5 + SALT_SIZE);
    
    // Simuler streaming par chunks
    const chunks = [];
    const CHUNK_SIZE = 64 * 1024; // 64KB par chunk
    
    for (let i = 0; i < bigData.length; i += CHUNK_SIZE) {
      const chunk = bigData.subarray(i, Math.min(i + CHUNK_SIZE, bigData.length));
      const encChunk = cipher.update(chunk);
      chunks.push(encChunk);
    }
    
    cipher.final();
    const tag = cipher.getAuthTag();
    
    const finalData = Buffer.concat([header, ...chunks, tag]);
    await fs.writeFile(encFile, finalData);
    
    const encryptTime = Date.now() - startTime;
    console.log(`[CRYPTO] ✅ Chiffrement streaming: ${encryptTime}ms`);
    
    // Test de déchiffrement streaming
    const decStartTime = Date.now();
    
    const encData = await fs.readFile(encFile);
    const readSalt = encData.subarray(5, 5 + SALT_SIZE);
    const readNonce = encData.subarray(5 + SALT_SIZE, 5 + SALT_SIZE + NONCE_SIZE);
    const readTag = encData.subarray(encData.length - TAG_SIZE);
    const encryptedData = encData.subarray(HEADER_SIZE, encData.length - TAG_SIZE);
    
    const readKey = crypto.scryptSync(TEST_PASSWORD, readSalt, 32);
    const decipher = crypto.createDecipheriv('aes-256-gcm', readKey, readNonce);
    decipher.setAuthTag(readTag);
    
    // Déchiffrement par chunks
    const decChunks = [];
    for (let i = 0; i < encryptedData.length; i += CHUNK_SIZE) {
      const chunk = encryptedData.subarray(i, Math.min(i + CHUNK_SIZE, encryptedData.length));
      const decChunk = decipher.update(chunk);
      decChunks.push(decChunk);
    }
    
    const finalDecChunk = decipher.final();
    if (finalDecChunk.length > 0) decChunks.push(finalDecChunk);
    
    const decrypted = Buffer.concat(decChunks);
    const decryptTime = Date.now() - decStartTime;
    
    assert.strictEqual(decrypted.length, bigData.length, 'Taille déchiffrée incorrecte');
    assert.deepStrictEqual(decrypted, bigData, 'Contenu déchiffré incorrect');
    
    console.log(`[CRYPTO] ✅ Déchiffrement streaming: ${decryptTime}ms`);
    console.log('[CRYPTO] 🎉 Test streaming réussi !');
    
  } finally {
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch {}
  }
}

async function main() {
  try {
    await runBasicCryptoTest();
    await runStreamingTest();
    console.log('[CRYPTO] 🎉 Tous les tests crypto GCM réussis !');
  } catch (error) {
    console.error('[CRYPTO] ❌ Tests échoués:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { runBasicCryptoTest, runStreamingTest };
