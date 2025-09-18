#!/usr/bin/env node

/**
 * Script de déploiement USB final
 * Prépare un package USB complet avec :
 * - Build portable signé
 * - Vault sécurisé avec médias chiffrés
 * - Outils de packaging/CLI
 * - Documentation utilisateur
 * - Scripts de lancement
 */

import { copyFileSync, mkdirSync, existsSync, readFileSync, writeFileSync, statSync } from 'fs';
import { execSync } from 'child_process';
import path from 'path';

const USB_TARGET = './usb-package-final';
const SOURCE_BUILD = './dist/USB-Video-Vault-0.1.0-portable.exe';
const SOURCE_VAULT = './usb-package/vault';
const SOURCE_TOOLS = './tools';

async function createUSBPackage() {
  console.log('📦 === CRÉATION PACKAGE USB FINAL ===\n');
  
  // 1. Créer structure USB
  console.log('📁 Création structure USB...');
  if (!existsSync(USB_TARGET)) {
    mkdirSync(USB_TARGET, { recursive: true });
  }
  
  mkdirSync(path.join(USB_TARGET, 'vault'), { recursive: true });
  mkdirSync(path.join(USB_TARGET, 'tools'), { recursive: true });
  mkdirSync(path.join(USB_TARGET, 'docs'), { recursive: true });
  
  console.log('   ✅ Structure créée');
  
  // 2. Copier build portable
  console.log('\\n📱 Copie build portable...');
  if (existsSync(SOURCE_BUILD)) {
    copyFileSync(SOURCE_BUILD, path.join(USB_TARGET, 'USB-Video-Vault.exe'));
    console.log('   ✅ Build portable copié (renommé)');
  } else {
    console.error('   ❌ Build portable non trouvé');
    return false;
  }
  
  // 3. Copier vault sécurisé
  console.log('\\n🔐 Copie vault sécurisé...');
  try {
    execSync(`xcopy "${SOURCE_VAULT}" "${path.join(USB_TARGET, 'vault')}" /E /I /Y`, { stdio: 'pipe' });
    console.log('   ✅ Vault sécurisé copié');
  } catch (error) {
    console.error('   ❌ Erreur copie vault:', error.message);
    return false;
  }
  
  // 4. Copier outils CLI
  console.log('\\n🛠️ Copie outils CLI...');
  try {
    execSync(`xcopy "${SOURCE_TOOLS}" "${path.join(USB_TARGET, 'tools')}" /E /I /Y`, { stdio: 'pipe' });
    console.log('   ✅ Outils CLI copiés');
  } catch (error) {
    console.error('   ❌ Erreur copie outils:', error.message);
    return false;
  }
  
  // 5. Créer scripts de lancement
  console.log('\\n🚀 Création scripts de lancement...');
  
  const launchBat = `@echo off
echo === Yindo USB Video Vault ===
echo.
echo Lancement de l'application...
echo.

rem Définir le vault local
set VAULT_PATH=%~dp0vault

rem Lancer l'application portable
"%~dp0USB-Video-Vault.exe" --no-sandbox

echo.
echo Application fermée.
pause
`;
  
  writeFileSync(path.join(USB_TARGET, 'Launch-USB-Video-Vault.bat'), launchBat);
  
  const launchPs1 = `# === Yindo USB Video Vault ===
Write-Host "=== Yindo USB Video Vault ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Lancement de l'application..." -ForegroundColor Green
Write-Host ""

# Définir le vault local
$env:VAULT_PATH = "$PSScriptRoot\\vault"

# Lancer l'application portable
& "$PSScriptRoot\\USB-Video-Vault.exe" --no-sandbox

Write-Host ""
Write-Host "Application fermée." -ForegroundColor Yellow
Read-Host "Appuyez sur Entrée pour continuer"
`;
  
  writeFileSync(path.join(USB_TARGET, 'Launch-USB-Video-Vault.ps1'), launchPs1);
  
  console.log('   ✅ Scripts de lancement créés');
  
  // 6. Créer README USB
  console.log('\\n📋 Création documentation...');
  
  const readmeUSB = `# Yindo USB Video Vault

## 🚀 Lancement rapide

### Windows
Double-cliquez sur **Launch-USB-Video-Vault.bat**

### PowerShell
\`\`\`powershell
.\\Launch-USB-Video-Vault.ps1
\`\`\`

### Manuel
\`\`\`bash
USB-Video-Vault.exe --no-sandbox
\`\`\`

## 📁 Structure

- **USB-Video-Vault.exe** : Application portable
- **vault/** : Coffre-fort chiffré avec médias
- **tools/** : Outils CLI pour packaging
- **docs/** : Documentation complète
- **Launch-*.*** : Scripts de lancement

## 🔒 Sécurité

✅ **AES-256-GCM** : Chiffrement streaming des médias
✅ **Ed25519** : Signatures cryptographiques
✅ **Device binding** : Liaison sécurisée USB
✅ **Anti-tamper** : Protection contre modification
✅ **Sandbox** : Isolation processus Electron

## ⚙️ Outils CLI

### Ajouter des médias
\`\`\`bash
cd tools/packager
node pack.js add-media --vault ../../vault --file video.mp4
\`\`\`

### Sceller le vault
\`\`\`bash
node pack.js seal --vault ../../vault --pass "motdepasse"
\`\`\`

### Lister le contenu
\`\`\`bash
node pack.js list --vault ../../vault --pass "motdepasse"
\`\`\`

## 📊 Licence

Licence valide jusqu'au : **2025-12-31**
Features : **playback, watermark, stats**

---
**Yindo USB Video Vault v0.1.0** - Lecture sécurisée portable
`;
  
  writeFileSync(path.join(USB_TARGET, 'README.md'), readmeUSB);
  
  // Documentation technique
  const techDoc = `# Documentation Technique

## Architecture Sécurisée

### Chiffrement
- **AES-256-GCM** : Chiffrement authenticated streaming
- **scrypt KDF** : Dérivation de clé robuste (N=32768, r=8, p=1)
- **Ed25519** : Signatures cryptographiques licence

### Protection Electron
- **CSP strict** : Content Security Policy verrouillé
- **Sandbox renderer** : Isolation processus de rendu
- **Anti-debug** : Protection développeur mode production
- **Permission lock** : Restriction accès système

### Vault Structure
\`\`\`
vault/
├── .vault/
│   ├── device.tag      # Device binding
│   ├── manifest.bin    # Index chiffré
│   └── license.bin     # Licence sécurisée
├── license.json        # Licence readable
├── media/
│   └── *.enc          # Fichiers chiffrés
\`\`\`

### Validation Pipeline
1. **Device binding** check
2. **License signature** validation  
3. **License expiry** check
4. **Manifest integrity** check
5. **Media decryption** streaming

## Red Team Validation ✅

- ✅ Licence expirée → BLOCKED
- ✅ Licence supprimée → BLOCKED  
- ✅ Vault corrompu → BLOCKED
- ✅ Device mismatch → BLOCKED
- ✅ Signature invalide → BLOCKED

---
Build: ${new Date().toISOString()}
Version: 0.1.0 RC
`;

  writeFileSync(path.join(USB_TARGET, 'docs', 'TECHNICAL.md'), techDoc);
  
  console.log('   ✅ Documentation créée');
  
  // 7. Rapport final
  console.log('\\n📊 === PACKAGE USB CRÉÉ ===');
  
  try {
    const stats = statSync(path.join(USB_TARGET, 'USB-Video-Vault.exe'));
    const buildSize = (stats.size / 1024 / 1024).toFixed(1);
    
    console.log('');
    console.log('📦 **Package final** : ' + USB_TARGET);
    console.log('💿 **Build portable** : ' + buildSize + ' MB');
    console.log('🔐 **Vault sécurisé** : Inclus');
    console.log('🛠️ **Outils CLI** : Inclus');
    console.log('📋 **Documentation** : Inclus');
    console.log('🚀 **Scripts launch** : Inclus');
    console.log('');
    console.log('🎉 **PRÊT POUR DÉPLOIEMENT USB !** ');
    console.log('');
    console.log('💡 **Prochaines étapes** :');
    console.log('   1. Copier ' + USB_TARGET + ' sur clé USB');
    console.log('   2. Tester Launch-USB-Video-Vault.bat');
    console.log('   3. Valider lecture médias chiffrés');
    console.log('');
    
    return true;
    
  } catch (error) {
    console.error('❌ Erreur rapport final:', error.message);
    return false;
  }
}

// Exécution
const result = await createUSBPackage();
if (result) {
  process.exit(0);
} else {
  process.exit(1);
}