# 🎮 USB Video Vault

[![Version](https://img.shields.io/badge/version-0.1.5-blue.svg)](https://github.com/150781/Yindo-USB-Video-Vault/releases)
[![Security](https://img.shields.io/badge/security-AES--256--GCM-green.svg)](#-sécurité)
[![Platform](https://img.shields.io/badge/platform-Windows-lightgray.svg)](#installation)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE.md)

> **🏆 Solution professionnelle de stockage vidéo chiffré pour clés USB**
>
> Application Electron avec chiffrement AES-256-GCM, signatures numériques, et interface utilisateur moderne. **Production-ready** avec monitoring SmartScreen et déploiement automatisé.

## 🚀 Installation rapide

### Option 1 : Téléchargement direct
```powershell
# Télécharger depuis GitHub Releases
https://github.com/150781/Yindo-USB-Video-Vault/releases/latest

# Vérifier intégrité
certutil -hashfile "USB Video Vault Setup 0.1.5.exe" SHA256
# Comparer avec SHA256SUMS du release
```

### Option 2 : Gestionnaires de packages
```powershell
# Winget (Windows Package Manager)
winget install Yindo.USBVideoVault

# Chocolatey
choco install usbvideovault
```

### Option 3 : Installation silencieuse
```powershell
# Installation automatique (IT/entreprise)
.\USB_Video_Vault_Setup_0.1.5.exe /S

# Vérification post-installation
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
    Where-Object { $_.DisplayName -like "*USB Video Vault*" }
```

## 📋 Vue d'ensemble

USB Video Vault est une **solution de niveau entreprise** pour créer des vaults vidéo chiffrés sur clés USB. Combine sécurité cryptographique militaire avec expérience utilisateur consumer-grade.

### ✨ Fonctionnalités principales

- 🔐 **Chiffrement militaire** : AES-256-GCM + PBKDF2 (100k itérations)
- 🎫 **Licences cryptographiques** : RSA-2048 avec validation temporelle
- 📱 **Interface moderne** : Electron + Tailwind CSS responsive
- 🎬 **Lecteur vidéo Pro** : MP4/AVI/MKV avec contrôles avancés
- 📊 **Playlists intelligentes** : Shuffle, repeat, métadonnées enrichies
- 🔧 **Suite packaging** : Création vaults automatisée
- 🛡️ **Sécurité renforcée** : Tests red-team, audit npm, SmartScreen
- 📦 **Déploiement enterprise** : Installation silencieuse, Winget/Chocolatey
- 🔄 **Monitoring 24/7** : Health checks, alertes sécurité

## ⚡ Démarrage ultra-rapide

### 🎯 Usage immédiat (utilisateurs finaux)
```powershell
# 1. Télécharger et installer
winget install Yindo.USBVideoVault

# 2. Lancer l'application
"USB Video Vault"  # depuis menu Démarrer

# 3. Créer votre premier vault chiffré
# Interface graphique guidée en 3 clics
```

### 🛠️ Développement (contributeurs)

#### Prérequis
- **Node.js 18+** (LTS recommandé)
- **Windows 10/11** (signatures Authenticode)
- **PowerShell 5.1+** (scripts d'automatisation)
- **Git** (avec LFS pour assets)

#### Installation dev
```powershell
# Clone avec submodules
git clone --recursive https://github.com/150781/Yindo-USB-Video-Vault.git
cd Yindo-USB-Video-Vault

# Installation dépendances (2-3 minutes)
npm install

# Build complet + tests (5-7 minutes)
npm run build
npm run test

# Lancement développement
npm run dev  # Hot reload activé
```

#### Validation rapide
```powershell
# Test fonctionnel 30 secondes
.\tools\quick-smoke-test.ps1

# Test sécurité complet (2 minutes)
.\tools\test-electron-security.ps1 -TestMode

# Simulation release (sans publish)
.\tools\preflight-final.ps1 -TestMode
```

## 📁 Structure du projet

```
├── src/                          # Code source principal
│   ├── main/                     # Processus principal Electron
│   ├── renderer/                 # Interface utilisateur
│   ├── shared/                   # Code partagé
│   └── types/                    # Définitions TypeScript
├── tools/
│   ├── packager/                 # Outils de création de vaults
│   └── license-management/       # Gestion des licences
├── scripts/                      # Scripts d'automatisation
│   ├── smoke.ps1                 # Test de démarrage rapide
│   └── day2-ops/                 # Scripts de maintenance
├── docs/                         # Documentation technique
├── usb-package/                  # Package USB de démonstration
└── vault*/                       # Vaults de test
```

## 🔧 Scripts disponibles

### Développement
```bash
npm run dev          # Mode développement avec hot reload
npm run build        # Build de production
npm run electron     # Lancer l'application
```

### Tests et validation
```bash
.\scripts\smoke.ps1                    # Test de démarrage
node test-red-team.mjs                 # Tests de sécurité
.\scripts\day2-ops\weekly-ops.ps1      # Maintenance hebdomadaire
```

### Packaging
```bash
npm run electron:build                 # Créer .exe portable
node tools/packager/pack.js --help     # Outils vault
```

## 🛡️ Sécurité de niveau entreprise

### 🔒 Architecture cryptographique
| Composant | Spécification | Validation |
|-----------|---------------|-------------|
| **Chiffrement** | AES-256-GCM + IV aléatoire | ✅ FIPS 140-2 Level 1 |
| **Dérivation** | PBKDF2 (100k itérations) | ✅ NIST SP 800-132 |
| **Intégrité** | Tags GCM authentifiés | ✅ Résistant altération |
| **Licences** | RSA-2048 + horodatage | ✅ PKI enterprise |
| **Transport** | TLS 1.3 (si réseau) | ✅ Zero Trust ready |

### 🔍 Batterie de tests sécurité
```powershell
# Suite complète (15 minutes)
.\tools\test-electron-security.ps1       # Runtime Electron
.\tools\verify-all-signatures.ps1        # Signatures Authenticode
.\tools\test-real-download.ps1          # SmartScreen/MOTW
node test-red-team.mjs                   # Tests intrusion
npm audit                                # Dépendances vulnérables
```

### 🔐 Conformité & certifications
- **Windows SmartScreen** : Réputation établie
- **Authenticode** : Signatures timestampées
- **SBOM** : Software Bill of Materials
- **CVE** : Monitoring vulnérabilités
- **Portable** : Aucune élévation privilèges

## 📊 Fonctionnalités techniques

### Lecteur vidéo
- Support formats : MP4, AVI, MKV
- Contrôles : lecture/pause, volume, plein écran
- Playlists avec shuffle et repeat
- Métadonnées enrichies

### Gestion des licences
- Validation cryptographique en temps réel
- Expiration et révocation
- Mode gracieux en cas d'expiration
- Logs d'audit complets

### Interface utilisateur
- Design responsive avec Tailwind CSS
- Drag & drop pour import de médias
- Thème sombre/clair
- Notifications système

## 🔄 Opérations & maintenance

### 🚨 Support utilisateur
```powershell
# Diagnostic automatique
.\tools\diagnose-user-issue.ps1

# Réinstallation propre
.\tools\test-uninstall-silent.ps1    # Désinstallation complète
winget install Yindo.USBVideoVault   # Réinstallation fraîche

# Test upgrade in-place
.\tools\test-upgrade-inplace.ps1 -FromVersion "0.1.4" -ToVersion "0.1.5"
```

### 📊 Monitoring production
```powershell
# Surveillance post-release (24/48h)
.\tools\monitor-release.ps1 -Version "0.1.5"

# Health checks système
.\tools\preflight-final.ps1 -TestMode     # Pré-déploiement
.\tools\check-go-nogo.ps1                 # Go/NoGo release

# Rollback d'urgence
.\tools\emergency-rollback.ps1 -WhatIf    # Simulation
.\tools\emergency-rollback.ps1            # Exécution réelle
```

### 🔧 Day-2 operations
```powershell
# Maintenance programmée
.\scripts\day2-ops\weekly-ops.ps1            # Hebdomadaire complet
.\scripts\day2-ops\weekly-ops.ps1 -SecurityOnly  # Sécurité uniquement
.\scripts\day2-ops\monthly-rotation.ps1      # Rotation certificats
```

### 📈 Métriques & alertes
- **SmartScreen** : Réputation temps réel
- **Install success** : Taux de réussite installation
- **GitHub Issues** : Monitoring automatique
- **CVE Database** : Veille vulnérabilités
- **Certificate expiry** : Alertes 30/7 jours

## 📖 Documentation

- **[Architecture complète](docs/COMPLETE_SYSTEM_OVERVIEW.md)** - Vue technique détaillée
- **[Guide de debug](docs/DEBUG_GUIDE.md)** - Résolution de problèmes
- **[Tests manuels](docs/MANUAL_TESTS.md)** - Procédures de validation
- **[Drag & Drop](docs/DRAG_DROP_GUIDE.md)** - Guide d'utilisation

## 🏗️ Build et déploiement

### Configuration build
```json
{
  "build": {
    "appId": "com.yindo.usbvideovault",
    "productName": "USB-Video-Vault",
    "win": {
      "target": "portable",
      "artifactName": "${productName}-${version}-portable.exe"
    }
  }
}
```

### Déploiement USB
1. Build l'exécutable : `npm run electron:build`
2. Créer vault : `node tools/packager/pack.js create-vault`
3. Ajouter médias : `node tools/packager/pack.js add-media`
4. Copier sur USB avec structure recommandée

## 🤝 Contribution

### Standards de code
- TypeScript strict mode
- ESLint + Prettier
- Tests automatisés requis
- Documentation inline

### Workflow
1. Fork du projet
2. Branche feature (`git checkout -b feature/ma-fonctionnalite`)
3. Commit avec convention (`feat: ajouter nouvelle fonctionnalité`)
4. Tests passants (`npm test`)
5. Pull Request avec description détaillée

## 📄 Licence

Ce projet est sous licence propriétaire. Voir [LICENSE.md](LICENSE.md) pour les détails.

## 🆘 Support & dépannage

### 🚀 Problèmes fréquents
| Problème | Solution rapide | Script diagnostic |
|----------|-----------------|-------------------|
| **App ne démarre pas** | Réinstaller avec `/S` | `.\tools\test-electron-security.ps1` |
| **Vault corrompu** | Vérifier intégrité | `.\diagnostic-vault.js` |
| **SmartScreen bloque** | Télécharger depuis GitHub | `.\tools\test-real-download.ps1` |
| **Installation échoue** | Droits admin + antivirus | `.\tools\test-uninstall-silent.ps1` |
| **Lecteur vidéo bug** | Mettre à jour codecs | `.\test-playback-simple.js` |

### 📞 Canaux de support
- **🐛 Bugs** : [GitHub Issues](https://github.com/150781/Yindo-USB-Video-Vault/issues)
- **📚 Docs** : [Documentation complète](/docs)
- **🔧 Diagnostic** : `.\tools\diagnose-user-issue.ps1`
- **💬 Discussions** : GitHub Discussions
- **🚨 Sécurité** : security@yindo.com (PGP/S-MIME)

### ⚡ Diagnostic express
```powershell
# Test complet 60 secondes
.\tools\preflight-final.ps1 -TestMode

# Vérification intégrité
.\tools\generate-release-assets.ps1 -TestMode

# État système
Get-ComputerInfo | Select-Object WindowsProductName, TotalPhysicalMemory
```

---

### 📊 Informations release

**Version courante** : `0.1.5` 🎯
**Release date** : 24 septembre 2025
**Statut** : **Production Ready** ✅
**Prochaine release** : `0.1.6` (Q4 2025)

**Compatibilité** :
- ✅ Windows 10 (1909+) / Windows 11
- ✅ x64 uniquement (ARM64 : roadmap Q1 2026)
- ✅ .NET Framework 4.8+ (auto-installé)

**Signatures & intégrité** :
- 🔐 Authenticode signé (Yindo Code Signing CA)
- 🕐 Timestamp RFC3161 (validité long terme)
- 📦 SHA256SUMS pour tous binaires
- 🔍 SBOM (Software Bill of Materials)
- 🛡️ Windows SmartScreen : réputation établie

---

� **Tip** : Utilisez `winget upgrade Yindo.USBVideoVault` pour rester à jour automatiquement.
