import { randomBytes, scryptSync, createCipheriv, createDecipheriv, createHash } from 'crypto';

export function sha256Hex(buf: Buffer): string {
  return createHash('sha256').update(buf).digest('hex');
}

export function scryptKey(pass: string, saltHex: string) {
  const salt = Buffer.from(saltHex, 'hex');
  const key = scryptSync(pass, salt, 32); // AES-256
  return key;
}

export function aesGcmEncrypt(plain: Buffer, key: Buffer) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([cipher.update(plain), cipher.final()]);
  const tag = cipher.getAuthTag();
  // format fichier: [IV(12)] [ENC(..)] [TAG(16)]
  return Buffer.concat([iv, enc, tag]);
}

export function aesGcmDecrypt(file: Buffer, key: Buffer) {
  const iv = file.subarray(0, 12);
  const tag = file.subarray(file.length - 16);
  const enc = file.subarray(12, file.length - 16);
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  const plain = Buffer.concat([decipher.update(enc), decipher.final()]);
  return plain;
}
