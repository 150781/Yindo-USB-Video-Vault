#!/usr/bin/env node

/**
 * Corrompre un .enc pour tester l'auth-fail
 * Usage: node corrupt-file.mjs <file.enc>
 */

import fs from "fs";
import path from "path";

const f = process.argv[2];
if (!f) {
  console.error("Usage: node corrupt-file.mjs <file.enc>");
  process.exit(2);
}

if (!fs.existsSync(f)) {
  console.error("❌ Fichier non trouvé:", f);
  process.exit(1);
}

try {
  const buf = fs.readFileSync(f);
  const header = 33; // MAGIC+VER+SALT+NONCE
  
  if (buf.length <= header + 1024) {
    console.error("❌ Fichier trop petit pour corruption sécurisée");
    process.exit(1);
  }
  
  // Corruption dans les données chiffrées, pas l'entête
  const i = Math.max(header + 1024, header);
  const originalByte = buf[i];
  
  buf[i] = (buf[i] ^ 0xFF) & 0xFF; // Flip tous les bits
  
  const corruptFile = f + ".corrupt";
  fs.writeFileSync(corruptFile, buf);
  
  console.log("✅ Fichier corrompu écrit:", corruptFile);
  console.log("📍 Position corrompue:", i);
  console.log("🔀 Byte original:", originalByte.toString(16), "→ nouveau:", buf[i].toString(16));
  console.log("💡 Test: tenter de lire", corruptFile, "→ devrait échouer avec auth/tag fail");
  
} catch (error) {
  console.error("❌ Erreur corruption:", error.message);
  process.exit(1);
}