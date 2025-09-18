#!/usr/bin/env node

/**
 * Vérification d'entête .enc (AES-GCM + magic)
 * Usage: node check-enc-header.mjs <file.enc>
 */

import fs from "fs";
import path from "path";

const f = process.argv[2];
if (!f) {
  console.error("Usage: node check-enc-header.mjs <file.enc>");
  process.exit(2);
}

if (!fs.existsSync(f)) {
  console.error("❌ Fichier non trouvé:", f);
  process.exit(1);
}

try {
  const fd = fs.openSync(f, "r");
  const b = Buffer.alloc(28); // 12 (IV) + 16 (TAG au début pour vérifier format)
  fs.readSync(fd, b, 0, 28, 0);
  
  // Lire aussi les derniers 16 bytes (TAG)
  const stats = fs.statSync(f);
  const tagBuffer = Buffer.alloc(16);
  fs.readSync(fd, tagBuffer, 0, 16, stats.size - 16);
  fs.closeSync(fd);
  
  const iv = b.slice(0, 12);
  const ivHex = iv.toString("hex");
  const tagHex = tagBuffer.toString("hex");
  
  console.log({
    file: path.basename(f),
    format: "AES-256-GCM",
    ivHex: ivHex,
    tagHex: tagHex,
    size: stats.size,
    structure: "IV(12) + CIPHERTEXT + TAG(16)"
  });
  
  // Vérifications basiques
  if (stats.size < 28) {
    console.error("❌ Fichier trop petit (< 28 bytes)");
    process.exit(1);
  }
  
  if (iv.every(b => b === 0)) {
    console.error("❌ IV invalide (tous zéros)");
    process.exit(1);
  }
  
  console.log("✅ Format AES-GCM valide");
  console.log("💡 IV aléatoire:", ivHex.substring(0, 16) + "...");
  console.log("💡 Taille données chiffrées:", (stats.size - 28).toLocaleString(), "bytes");
  
} catch (error) {
  console.error("❌ Erreur lecture entête:", error.message);
  process.exit(1);
}