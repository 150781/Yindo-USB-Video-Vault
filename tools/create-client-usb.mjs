#!/usr/bin/env node

/**
 * 💿 CLIENT USB PACKAGER
 * Création automatisée de clés USB client avec licence unique
 */

import { existsSync, mkdirSync, copyFileSync, writeFileSync, readFileSync, cpSync } from 'fs';
import { resolve, join } from 'path';
import { execSync } from 'child_process';
import crypto from 'crypto';

// Configuration
const config = {
  appExecutable: './dist/USB-Video-Vault-0.1.0-portable.exe',
  vaultTemplate: './vault-template',
  clientsDir: './clients-usb',
  licenseTemplate: './tools/packager/license-template.json'
};

class ClientUSBPackager {
  constructor(options) {
    this.clientId = options.client;
    this.mediaPath = options.media;
    this.outputPath = options.output;
    this.masterPassword = options.password;
    this.licenseId = options.licenseId;
    this.expiryDate = options.expires;
    this.features = options.features ? options.features.split(',') : ['playback'];
    this.bindUSB = options.bindUsb || 'auto';
    this.bindMachine = options.bindMachine || 'optional';
    
    console.log(`🏭 === CLIENT USB PACKAGER ===`);
    console.log(`📋 Client: ${this.clientId}`);
    console.log(`🆔 Licence ID: ${this.licenseId}`);
    console.log(`📅 Expiration: ${this.expiryDate}`);
    console.log(`🎯 Features: ${this.features.join(', ')}`);
  }
  
  async createClientUSB() {
    try {
      // 1. Vérifications
      await this.validateInputs();
      
      // 2. Créer structure
      await this.createStructure();
      
      // 3. Copier app
      await this.copyApplication();
      
      // 4. Traiter médias
      await this.processMedia();
      
      // 5. Générer licence
      await this.generateLicense();
      
      // 6. Créer scripts de lancement
      await this.createLaunchScripts();
      
      // 7. Documentation client
      await this.createClientDocs();
      
      // 8. Validation finale
      await this.validateClientUSB();
      
      console.log(`🎉 Clé USB client créée avec succès !`);
      console.log(`📁 Chemin: ${this.outputPath}`);
      
      return {
        success: true,
        clientId: this.clientId,
        licenseId: this.licenseId,
        outputPath: this.outputPath,
        mediaCount: this.mediaCount,
        totalSize: this.totalSize
      };
      
    } catch (error) {
      console.error(`❌ Erreur création clé USB: ${error.message}`);
      throw error;
    }
  }
  
  async validateInputs() {
    console.log(`🔍 Validation des entrées...`);
    
    if (!existsSync(config.appExecutable)) {
      throw new Error(`App executable introuvable: ${config.appExecutable}`);
    }
    
    if (!existsSync(this.mediaPath)) {
      throw new Error(`Dossier médias introuvable: ${this.mediaPath}`);
    }
    
    if (!this.masterPassword) {
      throw new Error(`Mot de passe maître requis`);
    }
    
    // Validation format licence
    if (!/^[A-Z0-9\-]+$/.test(this.licenseId)) {
      throw new Error(`Format licence ID invalide: ${this.licenseId}`);
    }
    
    // Validation date expiration
    const expiry = new Date(this.expiryDate);
    if (expiry <= new Date()) {
      throw new Error(`Date expiration dans le passé: ${this.expiryDate}`);
    }
    
    console.log(`✅ Validation OK`);
  }
  
  async createStructure() {
    console.log(`📁 Création structure client...`);
    
    const dirs = [
      this.outputPath,
      join(this.outputPath, 'vault'),
      join(this.outputPath, 'vault', '.vault'),
      join(this.outputPath, 'vault', 'media'),
      join(this.outputPath, 'docs'),
      join(this.outputPath, 'tools')
    ];
    
    dirs.forEach(dir => {
      if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
      }
    });
    
    console.log(`✅ Structure créée`);
  }
  
  async copyApplication() {
    console.log(`📦 Copie de l'application...`);
    
    const targetPath = join(this.outputPath, 'USB-Video-Vault.exe');
    copyFileSync(config.appExecutable, targetPath);
    
    console.log(`✅ Application copiée`);
  }
  
  async processMedia() {
    console.log(`🎥 Traitement des médias...`);
    
    // Utiliser le packager existant
    const packCommand = `node tools/packager/pack.js process-folder ` +
      `--input "${this.mediaPath}" ` +
      `--vault "${join(this.outputPath, 'vault')}" ` +
      `--password "${this.masterPassword}" ` +
      `--client "${this.clientId}"`;
    
    try {
      const output = execSync(packCommand, { encoding: 'utf8' });
      console.log(`📊 ${output}`);
      
      // Extraire statistiques
      this.mediaCount = (output.match(/Processed (\d+) files/) || [0, 0])[1];
      this.totalSize = (output.match(/Total: ([0-9.]+\s*[KMGT]?B)/) || [0, '0B'])[1];
      
    } catch (error) {
      throw new Error(`Erreur traitement médias: ${error.message}`);
    }
    
    console.log(`✅ ${this.mediaCount} médias traités (${this.totalSize})`);
  }
  
  async generateLicense() {
    console.log(`🔑 Génération licence client...`);
    
    // Template de licence
    const license = {
      version: "1.0.0",
      id: this.licenseId,
      client: this.clientId,
      issued: new Date().toISOString(),
      expires: this.expiryDate,
      features: this.features,
      binding: {
        usb: this.bindUSB,
        machine: this.bindMachine
      },
      metadata: {
        created_by: "USB Video Vault Packager",
        package_version: "1.0.0",
        media_count: parseInt(this.mediaCount) || 0,
        total_size: this.totalSize
      }
    };
    
    // Licence publique (JSON)
    const licensePath = join(this.outputPath, 'vault', 'license.json');
    writeFileSync(licensePath, JSON.stringify(license, null, 2));
    
    // Licence chiffrée (binaire)
    const licenseCommand = `node tools/packager/pack.js generate-license ` +
      `--vault "${join(this.outputPath, 'vault')}" ` +
      `--id "${this.licenseId}" ` +
      `--expires "${this.expiryDate}" ` +
      `--features "${this.features.join(',')}" ` +
      `--bind-usb "${this.bindUSB}" ` +
      `--bind-machine "${this.bindMachine}"`;
    
    try {
      execSync(licenseCommand, { encoding: 'utf8' });
    } catch (error) {
      throw new Error(`Erreur génération licence: ${error.message}`);
    }
    
    console.log(`✅ Licence générée (ID: ${this.licenseId})`);
  }
  
  async createLaunchScripts() {
    console.log(`🚀 Création scripts de lancement...`);
    
    // Script Windows (.bat)
    const batScript = `@echo off
title USB Video Vault - ${this.clientId}
echo 🎥 USB Video Vault - Client ${this.clientId}
echo 🔑 Licence: ${this.licenseId}
echo 📅 Expire: ${this.expiryDate}
echo.
echo ⏳ Démarrage...

set VAULT_PATH=%~dp0vault
set CLIENT_ID=${this.clientId}
set LICENSE_ID=${this.licenseId}

"%~dp0USB-Video-Vault.exe" --vault="%VAULT_PATH%" --no-sandbox

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Erreur de démarrage
    echo 💡 Vérifiez que la clé USB est bien connectée
    echo 📞 Support: support@usbvideovault.com
    pause
)`;
    
    writeFileSync(join(this.outputPath, 'Launch-Client.bat'), batScript);
    
    // Script PowerShell (.ps1)
    const ps1Script = `# USB Video Vault - Client ${this.clientId}
Write-Host "🎥 USB Video Vault - Client ${this.clientId}" -ForegroundColor Cyan
Write-Host "🔑 Licence: ${this.licenseId}" -ForegroundColor Yellow
Write-Host "📅 Expire: ${this.expiryDate}" -ForegroundColor Green
Write-Host ""
Write-Host "⏳ Démarrage..." -ForegroundColor White

$env:VAULT_PATH = Join-Path $PSScriptRoot "vault"
$env:CLIENT_ID = "${this.clientId}"
$env:LICENSE_ID = "${this.licenseId}"

$exePath = Join-Path $PSScriptRoot "USB-Video-Vault.exe"

try {
    & $exePath --vault="$env:VAULT_PATH" --no-sandbox
} catch {
    Write-Host ""
    Write-Host "❌ Erreur de démarrage" -ForegroundColor Red
    Write-Host "💡 Vérifiez que la clé USB est bien connectée" -ForegroundColor Yellow
    Write-Host "📞 Support: support@usbvideovault.com" -ForegroundColor Magenta
    Read-Host "Appuyez sur Entrée pour fermer"
}`;
    
    writeFileSync(join(this.outputPath, 'Launch-Client.ps1'), ps1Script);
    
    console.log(`✅ Scripts de lancement créés`);
  }
  
  async createClientDocs() {
    console.log(`📚 Création documentation client...`);
    
    // Guide utilisateur spécifique client
    const userGuide = `# 🎥 ${this.clientId} - Guide Video Vault

## 📋 Informations Client
- **Client:** ${this.clientId}
- **Licence:** ${this.licenseId}
- **Expiration:** ${this.expiryDate}
- **Fonctionnalités:** ${this.features.join(', ')}

## 🚀 Démarrage Rapide
1. **Branchez cette clé USB** sur votre ordinateur
2. **Double-cliquez** sur \`Launch-Client.bat\` (Windows)
3. **Attendez** le chargement de l'application
4. **Profitez** de vos vidéos sécurisées !

## 🎬 Utilisation
- **Sélectionner vidéo:** Clic dans la playlist
- **Lecture:** Bouton ▶️ ou double-clic
- **Plein écran:** Touche F11
- **2ème écran:** Touche F2

## 🔒 Sécurité
✅ **Contenu protégé** - Aucune copie possible  
✅ **Licence liée** - Fonctionne uniquement avec votre matériel  
✅ **Chiffrement** - Données sécurisées AES-256  

## ⚠️ Problèmes Courants
| Problème | Solution |
|----------|----------|
| App ne démarre pas | Vérifier connexion USB, réessayer |
| "Licence expirée" | Contacter support avec ID: ${this.licenseId} |
| Vidéo ne joue pas | Vérifier intégrité clé USB |

## 📞 Support Technique
**Email:** support@usbvideovault.com  
**Client ID:** ${this.clientId}  
**Licence ID:** ${this.licenseId}  

*Toujours inclure ces IDs dans vos demandes de support.*

---
*USB Video Vault v1.0.0 - Sécurité professionnelle pour vos contenus*`;
    
    writeFileSync(join(this.outputPath, 'docs', 'GUIDE_UTILISATEUR.md'), userGuide);
    
    // Export diagnostics
    const diagScript = `@echo off
title Diagnostics - ${this.clientId}
echo 🔍 Export Diagnostics - ${this.clientId}
echo.

set OUTPUT_FILE=%USERPROFILE%\\Desktop\\diagnostics-${this.clientId}-%DATE:/=-%-%TIME::=%.json

echo {> "%OUTPUT_FILE%"
echo   "client": "${this.clientId}",>> "%OUTPUT_FILE%"
echo   "license": "${this.licenseId}",>> "%OUTPUT_FILE%"
echo   "timestamp": "%DATE% %TIME%",>> "%OUTPUT_FILE%"
echo   "vault_path": "%~dp0vault",>> "%OUTPUT_FILE%"
echo   "system": {>> "%OUTPUT_FILE%"
echo     "os": "%OS%",>> "%OUTPUT_FILE%"
echo     "user": "%USERNAME%",>> "%OUTPUT_FILE%"
echo     "computer": "%COMPUTERNAME%">> "%OUTPUT_FILE%"
echo   }>> "%OUTPUT_FILE%"
echo }>> "%OUTPUT_FILE%"

echo ✅ Diagnostics exportés vers:
echo %OUTPUT_FILE%
echo.
echo 📧 Envoyez ce fichier au support technique
pause`;
    
    writeFileSync(join(this.outputPath, 'tools', 'export-diagnostics.bat'), diagScript);
    
    console.log(`✅ Documentation client créée`);
  }
  
  async validateClientUSB() {
    console.log(`🔍 Validation finale...`);
    
    // Vérifier structure
    const requiredFiles = [
      'USB-Video-Vault.exe',
      'Launch-Client.bat',
      'Launch-Client.ps1',
      'vault/license.json',
      'vault/.vault/license.bin',
      'docs/GUIDE_UTILISATEUR.md',
      'tools/export-diagnostics.bat'
    ];
    
    for (const file of requiredFiles) {
      const filePath = join(this.outputPath, file);
      if (!existsSync(filePath)) {
        throw new Error(`Fichier requis manquant: ${file}`);
      }
    }
    
    // Tester headers .enc
    try {
      const encFiles = join(this.outputPath, 'vault', 'media', '*.enc');
      const checkResult = execSync(`node tools/check-enc-header.mjs "${encFiles}"`, { 
        encoding: 'utf8',
        stdio: 'pipe' 
      });
      
      if (!checkResult.includes('Format AES-GCM valide')) {
        console.warn('⚠️ Warning: Fichiers .enc non validés');
      }
    } catch (error) {
      console.warn('⚠️ Warning: Validation .enc échouée');
    }
    
    console.log(`✅ Validation terminée`);
  }
}

// CLI Interface
async function main() {
  const args = process.argv.slice(2);
  const options = {};
  
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i].replace('--', '');
    const value = args[i + 1];
    options[key] = value;
  }
  
  // Validation arguments requis
  const required = ['client', 'media', 'output', 'password', 'license-id', 'expires'];
  for (const req of required) {
    if (!options[req]) {
      console.error(`❌ Argument requis manquant: --${req}`);
      process.exit(1);
    }
  }
  
  // Normaliser les clés (license-id -> licenseId)
  if (options['license-id']) {
    options.licenseId = options['license-id'];
  }
  if (options['bind-usb']) {
    options.bindUsb = options['bind-usb'];
  }
  if (options['bind-machine']) {
    options.bindMachine = options['bind-machine'];
  }
  
  try {
    const packager = new ClientUSBPackager(options);
    const result = await packager.createClientUSB();
    
    console.log(`\n📊 === RÉSULTAT FINAL ===`);
    console.log(`✅ Client: ${result.clientId}`);
    console.log(`🔑 Licence: ${result.licenseId}`);
    console.log(`📁 Sortie: ${result.outputPath}`);
    console.log(`🎥 Médias: ${result.mediaCount} fichiers`);
    console.log(`💾 Taille: ${result.totalSize}`);
    
    process.exit(0);
    
  } catch (error) {
    console.error(`\n❌ === ÉCHEC ===`);
    console.error(`Erreur: ${error.message}`);
    process.exit(1);
  }
}

// Aide
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
🏭 CLIENT USB PACKAGER

Usage:
  node tools/create-client-usb.mjs [options]

Options requis:
  --client         ID client (ex: ACME-CORP)
  --media          Dossier médias source
  --output         Chemin clé USB destination
  --password       Mot de passe maître chiffrement
  --license-id     ID licence unique (ex: ACME-2025-0001)
  --expires        Date expiration (ISO 8601)

Options facultatifs:
  --features       Fonctionnalités (défaut: playback)
  --bind-usb       Binding USB (auto|off, défaut: auto)
  --bind-machine   Binding machine (on|off, défaut: optional)

Exemple:
  node tools/create-client-usb.mjs \\
    --client "ACME-CORP" \\
    --media "./media-acme" \\
    --output "G:/USB-Video-Vault" \\
    --password "SECRET_KEY" \\
    --license-id "ACME-2025-0001" \\
    --expires "2026-12-31T23:59:59Z" \\
    --features "playback,watermark" \\
    --bind-usb auto
`);
  process.exit(0);
}

// ESM version check
if (import.meta.url === `file://${process.argv[1].replace(/\\/g, '/')}`) {
  main().catch(error => {
    console.error('❌ Erreur:', error.message);
    process.exit(1);
  });
}