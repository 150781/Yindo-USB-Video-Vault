import { randomBytes, scrypt, createCipheriv, createDecipheriv } from 'crypto';
import { promisify } from 'util';
import { Transform, Readable } from 'stream';
import { createReadStream, createWriteStream, ReadStream } from 'fs';
import { promises as fs } from 'fs';

const scryptAsync = promisify(scrypt);

// Format fichier .enc : [MAGIC(4)="UVV1"][VER(1)=1][SALT(16)][NONCE(12)][CIPHERTEXT...][TAG(16)]
export const MAGIC_HEADER = Buffer.from('UVV1');
export const VERSION = 1;
export const SALT_SIZE = 16;
export const NONCE_SIZE = 12;
export const TAG_SIZE = 16;
export const HEADER_SIZE = 4 + 1 + SALT_SIZE + NONCE_SIZE; // 33 bytes

export interface EncryptionOptions {
  password: string;
  saltOverride?: Buffer; // Pour tests uniquement
  nonceOverride?: Buffer; // Pour tests uniquement
}

export interface DecryptionInfo {
  salt: Buffer;
  nonce: Buffer;
  key: Buffer;
  dataStart: number;
  dataEnd: number;
}

/**
 * Dérive une clé AES-256 depuis un mot de passe avec scrypt
 */
export async function deriveKey(password: string, salt: Buffer): Promise<Buffer> {
  if (salt.length !== SALT_SIZE) {
    throw new Error(`Salt doit faire ${SALT_SIZE} octets`);
  }
  
  // scrypt: 32 bytes pour AES-256, coût élevé mais pas excessif pour USB
  return await scryptAsync(password, salt, 32) as Buffer;
}

/**
 * Lit et valide l'en-tête d'un fichier .enc
 */
export async function readEncryptionHeader(filePath: string): Promise<DecryptionInfo> {
  const fd = await fs.open(filePath, 'r');
  try {
    const stat = await fd.stat();
    if (stat.size < HEADER_SIZE + TAG_SIZE) {
      throw new Error('Fichier .enc trop petit');
    }

    // Lire l'en-tête
    const headerBuffer = Buffer.alloc(HEADER_SIZE);
    await fd.read(headerBuffer, 0, HEADER_SIZE, 0);

    let offset = 0;
    const magic = headerBuffer.subarray(offset, offset + 4);
    offset += 4;
    
    if (!magic.equals(MAGIC_HEADER)) {
      throw new Error(`Magic header invalide. Attendu: ${MAGIC_HEADER.toString('hex')}, reçu: ${magic.toString('hex')}`);
    }

    const version = headerBuffer.readUInt8(offset);
    offset += 1;
    
    if (version !== VERSION) {
      throw new Error(`Version non supportée: ${version}`);
    }

    const salt = headerBuffer.subarray(offset, offset + SALT_SIZE);
    offset += SALT_SIZE;
    
    const nonce = headerBuffer.subarray(offset, offset + NONCE_SIZE);

    // Dériver la clé (sera fait par l'appelant avec le bon password)
    const dataStart = HEADER_SIZE;
    const dataEnd = stat.size - TAG_SIZE;

    return {
      salt,
      nonce,
      key: Buffer.alloc(0), // Sera rempli par l'appelant
      dataStart,
      dataEnd
    };
  } finally {
    await fd.close();
  }
}

/**
 * Chiffre un fichier vers un fichier .enc avec streaming
 */
export async function encryptMediaFile(
  inputPath: string, 
  outputPath: string, 
  options: EncryptionOptions
): Promise<void> {
  console.log('[CRYPTO] Chiffrement de', inputPath, '->', outputPath);
  
  const salt = options.saltOverride || randomBytes(SALT_SIZE);
  const nonce = options.nonceOverride || randomBytes(NONCE_SIZE);
  const key = await deriveKey(options.password, salt);

  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  
  // Écrire l'en-tête
  const outputStream = createWriteStream(outputPath);
  
  // [MAGIC(4)][VER(1)][SALT(16)][NONCE(12)]
  const header = Buffer.alloc(HEADER_SIZE);
  let offset = 0;
  
  MAGIC_HEADER.copy(header, offset);
  offset += 4;
  
  header.writeUInt8(VERSION, offset);
  offset += 1;
  
  salt.copy(header, offset);
  offset += SALT_SIZE;
  
  nonce.copy(header, offset);
  
  outputStream.write(header);

  const inputStream = createReadStream(inputPath);
  
  return new Promise<void>((resolve, reject) => {
    const handleError = (error: Error) => {
      outputStream.destroy();
      reject(error);
    };

    inputStream.on('error', handleError);
    cipher.on('error', handleError);
    outputStream.on('error', handleError);

    outputStream.on('finish', () => {
      // Écrire le tag GCM à la fin
      const tag = cipher.getAuthTag();
      if (tag.length !== TAG_SIZE) {
        reject(new Error(`Tag GCM invalide: ${tag.length} octets au lieu de ${TAG_SIZE}`));
        return;
      }
      
      // Append le tag à la fin du fichier
      const tagStream = createWriteStream(outputPath, { flags: 'a' });
      tagStream.write(tag);
      tagStream.end();
      tagStream.on('finish', resolve);
      tagStream.on('error', reject);
    });

    // Pipeline de chiffrement
    inputStream.pipe(cipher).pipe(outputStream);
  });
}

/**
 * Crée un stream de déchiffrement depuis un fichier .enc
 */
export async function createDecryptionStream(
  encryptedPath: string, 
  password: string
): Promise<Readable> {
  console.log('[CRYPTO] Création stream déchiffrement pour', encryptedPath);
  
  const info = await readEncryptionHeader(encryptedPath);
  const key = await deriveKey(password, info.salt);
  
  // Lire le tag GCM depuis la fin du fichier
  const fd = await fs.open(encryptedPath, 'r');
  const tag = Buffer.alloc(TAG_SIZE);
  await fd.read(tag, 0, TAG_SIZE, info.dataEnd);
  await fd.close();

  const decipher = createDecipheriv('aes-256-gcm', key, info.nonce);
  decipher.setAuthTag(tag);

  // Stream des données chiffrées (sans header ni tag)
  const encryptedDataStream = createReadStream(encryptedPath, {
    start: info.dataStart,
    end: info.dataEnd - 1
  });

  // Pipe le stream chiffré vers le déchiffreur
  return encryptedDataStream.pipe(decipher);
}

/**
 * Transforme un Node.js Readable en Web ReadableStream
 */
export function toWebStream(nodeStream: Readable): ReadableStream<Uint8Array> {
  return new ReadableStream({
    start(controller) {
      nodeStream.on('data', (chunk: Buffer) => {
        controller.enqueue(new Uint8Array(chunk));
      });
      
      nodeStream.on('end', () => {
        controller.close();
      });
      
      nodeStream.on('error', (error) => {
        controller.error(error);
      });
    },
    
    cancel() {
      nodeStream.destroy();
    }
  });
}

/**
 * Vérifie l'intégrité d'un fichier .enc sans le déchiffrer complètement
 */
export async function verifyEncryptedFile(encryptedPath: string, password: string): Promise<boolean> {
  try {
    const info = await readEncryptionHeader(encryptedPath);
    const key = await deriveKey(password, info.salt);
    
    // Lire juste les premiers et derniers octets pour validation rapide
    const fd = await fs.open(encryptedPath, 'r');
    try {
      const tag = Buffer.alloc(TAG_SIZE);
      await fd.read(tag, 0, TAG_SIZE, info.dataEnd);
      
      const decipher = createDecipheriv('aes-256-gcm', key, info.nonce);
      decipher.setAuthTag(tag);
      
      // Essayer de déchiffrer juste un petit bloc
      const testSize = Math.min(1024, info.dataEnd - info.dataStart);
      const testData = Buffer.alloc(testSize);
      await fd.read(testData, 0, testSize, info.dataStart);
      
      decipher.update(testData);
      decipher.final(); // Ceci validera le tag
      
      return true;
    } finally {
      await fd.close();
    }
  } catch (error) {
    console.log('[CRYPTO] Vérification échoué:', error);
    return false;
  }
}
