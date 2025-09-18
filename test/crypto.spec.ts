import { promises as fs } from 'fs';
import { randomBytes } from 'crypto';
import path from 'path';
import os from 'os';
import assert from 'assert';

const TEST_PASSWORD = 'test-password-123';
const TEST_CONTENT = 'Hello, this is a test video content that will be encrypted and decrypted!';

async function runTests() {
  console.log('[CRYPTO] Début des tests crypto GCM...');
  
  // Import dynamique pour éviter les erreurs de résolution
  const crypto = await import('../src/shared/crypto.js');
  
  const {
    encryptMediaFile,
    createDecryptionStream,
    deriveKey,
    readEncryptionHeader,
    verifyEncryptedFile,
    MAGIC_HEADER,
    VERSION,
    SALT_SIZE,
    NONCE_SIZE,
    TAG_SIZE,
    HEADER_SIZE
  } = crypto;

  let tempDir: string;

  const setupTest = async () => {
    const newTempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'vault-crypto-test-'));
    tempDir = newTempDir; // Assigner à la variable de scope
    const testInputFile = path.join(newTempDir, 'test-input.mp4');
    await fs.writeFile(testInputFile, TEST_CONTENT);
    return { 
      testInputFile, 
      testOutputFile: path.join(newTempDir, 'test-output.enc'),
      tempDir: newTempDir
    };
  };

  const cleanupTest = async () => {
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch {}
  };

  // Test 1: Dérivation de clé
  console.log('[CRYPTO] Test 1: Dérivation de clé avec scrypt');
  try {
    const salt = randomBytes(SALT_SIZE);
    const key1 = await deriveKey(TEST_PASSWORD, salt);
    const key2 = await deriveKey(TEST_PASSWORD, salt);
    
    assert.strictEqual(key1.length, 32, 'La clé doit faire 32 octets');
    assert.deepStrictEqual(key1, key2, 'Dérivation déterministe');
    
    const differentSalt = randomBytes(SALT_SIZE);
    const key3 = await deriveKey(TEST_PASSWORD, differentSalt);
    assert.notDeepStrictEqual(key1, key3, 'Clés différentes avec sels différents');
    
    console.log('[CRYPTO] ✅ Test 1 réussi');
  } catch (error) {
    console.error('[CRYPTO] ❌ Test 1 échoué:', error);
    throw error;
  }

  // Test 2: Chiffrement/déchiffrement basique
  console.log('[CRYPTO] Test 2: Chiffrement/déchiffrement basique');
  try {
    const { testInputFile, testOutputFile } = await setupTest();
    
    // Chiffrer
    await encryptMediaFile(testInputFile, testOutputFile, {
      password: TEST_PASSWORD
    });

    // Vérifier structure
    const encryptedData = await fs.readFile(testOutputFile);
    assert(encryptedData.length > HEADER_SIZE + TAG_SIZE, 'Fichier chiffré trop petit');
    
    // Vérifier magic header
    const magic = encryptedData.subarray(0, 4);
    assert.deepStrictEqual(magic, MAGIC_HEADER, 'Magic header incorrect');
    
    // Vérifier version
    const version = encryptedData.readUInt8(4);
    assert.strictEqual(version, VERSION, 'Version incorrecte');

    // Déchiffrer via stream
    const decryptStream = await createDecryptionStream(testOutputFile, TEST_PASSWORD);
    
    const chunks: Buffer[] = [];
    for await (const chunk of decryptStream) {
      chunks.push(chunk);
    }
    const decryptedContent = Buffer.concat(chunks).toString();
    
    assert.strictEqual(decryptedContent, TEST_CONTENT, 'Contenu déchiffré incorrect');
    
    console.log('[CRYPTO] ✅ Test 2 réussi');
  } catch (error) {
    console.error('[CRYPTO] ❌ Test 2 échoué:', error);
    throw error;
  } finally {
    await cleanupTest();
  }

  // Test 3: Tag corrompu
  console.log('[CRYPTO] Test 3: Vérification avec tag corrompu');
  try {
    const { testInputFile, testOutputFile } = await setupTest();
    
    await encryptMediaFile(testInputFile, testOutputFile, {
      password: TEST_PASSWORD
    });

    // Corrompre le tag GCM (derniers 16 octets)
    const data = await fs.readFile(testOutputFile);
    data[data.length - 1] ^= 0xFF;
    await fs.writeFile(testOutputFile, data);

    // La vérification doit échouer
    const isValid = await verifyEncryptedFile(testOutputFile, TEST_PASSWORD);
    assert.strictEqual(isValid, false, 'La vérification devrait échouer avec tag corrompu');
    
    console.log('[CRYPTO] ✅ Test 3 réussi');
  } catch (error) {
    console.error('[CRYPTO] ❌ Test 3 échoué:', error);
    throw error;
  } finally {
    await cleanupTest();
  }

  // Test 4: Mauvais mot de passe
  console.log('[CRYPTO] Test 4: Mauvais mot de passe');
  try {
    const { testInputFile, testOutputFile } = await setupTest();
    
    await encryptMediaFile(testInputFile, testOutputFile, {
      password: TEST_PASSWORD
    });

    // Essayer avec un mauvais mot de passe
    try {
      await createDecryptionStream(testOutputFile, 'wrong-password');
      assert.fail('Devrait échouer avec mauvais mot de passe');
    } catch {
      // Attendu
    }
    
    const isValid = await verifyEncryptedFile(testOutputFile, 'wrong-password');
    assert.strictEqual(isValid, false, 'Vérification devrait échouer avec mauvais mot de passe');
    
    console.log('[CRYPTO] ✅ Test 4 réussi');
  } catch (error) {
    console.error('[CRYPTO] ❌ Test 4 échoué:', error);
    throw error;
  } finally {
    await cleanupTest();
  }

  // Test 5: Unicité des nonces
  console.log('[CRYPTO] Test 5: Unicité des nonces');
  try {
    const { testInputFile, tempDir: currentTempDir } = await setupTest();
    const file1 = path.join(currentTempDir, 'test1.enc');
    const file2 = path.join(currentTempDir, 'test2.enc');
    
    await encryptMediaFile(testInputFile, file1, { password: TEST_PASSWORD });
    await encryptMediaFile(testInputFile, file2, { password: TEST_PASSWORD });
    
    const header1 = await readEncryptionHeader(file1);
    const header2 = await readEncryptionHeader(file2);
    
    // Les nonces doivent être différents
    assert.notDeepStrictEqual(header1.nonce, header2.nonce, 'Les nonces doivent être uniques');
    
    console.log('[CRYPTO] ✅ Test 5 réussi');
  } catch (error) {
    console.error('[CRYPTO] ❌ Test 5 échoué:', error);
    throw error;
  } finally {
    await cleanupTest();
  }

  // Test 6: Performance 1MB
  console.log('[CRYPTO] Test 6: Performance avec 1MB');
  try {
    const { testOutputFile, tempDir: currentTempDir } = await setupTest();
    const bigFile = path.join(currentTempDir, 'big.mp4');
    
    // 1MB de données
    const data = Buffer.alloc(1024 * 1024, 'A');
    await fs.writeFile(bigFile, data);
    
    const startTime = Date.now();
    await encryptMediaFile(bigFile, testOutputFile, { password: TEST_PASSWORD });
    const encryptTime = Date.now() - startTime;
    
    const startDecrypt = Date.now();
    const stream = await createDecryptionStream(testOutputFile, TEST_PASSWORD);
    
    let totalSize = 0;
    for await (const chunk of stream) {
      totalSize += chunk.length;
    }
    const decryptTime = Date.now() - startDecrypt;
    
    assert.strictEqual(totalSize, data.length, 'Taille déchiffrée incorrecte');
    
    console.log(`[CRYPTO] Performance 1MB: chiffrement ${encryptTime}ms, déchiffrement ${decryptTime}ms`);
    console.log('[CRYPTO] ✅ Test 6 réussi');
  } catch (error) {
    console.error('[CRYPTO] ❌ Test 6 échoué:', error);
    throw error;
  } finally {
    await cleanupTest();
  }

  console.log('[CRYPTO] 🎉 Tous les tests crypto GCM réussis !');
}

// Exporter pour utilisation via require()
export { runTests };

// Si exécuté directement
if (process.argv[1]?.endsWith('crypto.spec.ts') || process.argv[1]?.endsWith('crypto.spec.js')) {
  runTests().catch(error => {
    console.error('[CRYPTO] Tests échoués:', error);
    process.exit(1);
  });
}
