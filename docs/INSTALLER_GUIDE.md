# Guide des Installateurs USB Video Vault

## Types d'installateurs disponibles

### 1. 🚀 **Version Portable** (Recommandée)
- **Fichier** : `USB-Video-Vault-{version}-win-x64.exe`
- **Avantages** : Aucune installation requise, portable sur USB
- **Usage** : Exécution directe, idéal pour déploiement USB

### 2. 📦 **Installateur NSIS**
- **Fichier** : `USB-Video-Vault-{version}-win-x64.exe` (installateur)
- **Avantages** : Installation système complète, raccourcis automatiques
- **Post-install** : Script automatique pour création vault + licence

### 3. 🏢 **Installateur MSI**
- **Fichier** : `USB-Video-Vault-{version}-setup.msi`
- **Avantages** : Déploiement en entreprise via GPO
- **Compatibilité** : Windows Installer, gestion centralisée

### 4. ⚙️ **Installateur Inno Setup** (Optionnel)
- **Fichier** : Généré via script Inno Setup
- **Avantages** : Configuration avancée personnalisée
- **Prérequis** : Inno Setup Compiler installé

## Scripts post-install

### Script principal : `post-install-simple.ps1`
```powershell
# Usage de base
.\scripts\post-install-simple.ps1

# Avec licence personnalisée
.\scripts\post-install-simple.ps1 -LicenseSource "C:\path\to\license.bin"
```

**Fonctionnalités :**
- ✅ Détection automatique de `VAULT_PATH` ou utilisation du chemin par défaut
- ✅ Création de `%VAULT_PATH%\.vault\` si absent
- ✅ Copie automatique de `license.bin`
- ✅ Définition de la variable d'environnement `VAULT_PATH`
- ✅ Validation de l'installation

### Script avancé : `post-install-setup.ps1`
```powershell
# Usage avec options avancées
.\scripts\post-install-setup.ps1 -VaultPath "D:\MyVault" -Force -Verbose
```

**Fonctionnalités supplémentaires :**
- 🔧 Configuration personnalisée du chemin vault
- 🔄 Mode force pour écraser les installations existantes
- 📝 Logging détaillé et validation d'intégrité
- 🛡️ Gestion avancée des erreurs

## Commandes de build

### Build tous les installateurs
```bash
npm run build:installers
```

### Build individuels
```bash
# Version portable uniquement
npm run build:portable

# Installateur NSIS
npm run build:nsis

# Installateur MSI  
npm run build:msi
```

### Build avec script PowerShell
```powershell
# Tous les installateurs avec licence
.\scripts\build-installers.ps1 -LicensePath ".\license.bin"

# Portable uniquement
.\scripts\build-installers.ps1 -NSIS:$false -MSI:$false

# Avec nettoyage préalable
.\scripts\build-installers.ps1 -Clean
```

## Configuration vault automatique

### Variables d'environnement

**VAULT_PATH** : Chemin personnalisé du vault
```powershell
# Définir manuellement
$env:VAULT_PATH = "D:\MonVault"

# Ou via registre (persistant)
[Environment]::SetEnvironmentVariable("VAULT_PATH", "D:\MonVault", "User")
```

**Chemin par défaut** (si VAULT_PATH non défini) :
```
%USERPROFILE%\Documents\Yindo-USB-Video-Vault\vault-real
```

### Structure créée automatiquement
```
VAULT_PATH/
├── .vault/
│   ├── license.bin          # Licence d'utilisation
│   ├── device.tag           # Identification machine (généré)
│   └── manifest.json        # Métadonnées vault (généré)
└── media/                   # Contenu multimédia (ajouté par l'utilisateur)
```

## Déploiement en entreprise

### 1. Préparation
```powershell
# Générer licence pour le client
.\scripts\generate-client-license.ps1 -Owner "Entreprise XYZ" -Expiry "2025-12-31"

# Build avec licence intégrée
.\scripts\build-installers.ps1 -LicensePath ".\out\license.bin" -MSI
```

### 2. Déploiement MSI via GPO
```powershell
# Installation silencieuse
msiexec /i "USB-Video-Vault-1.0.3-setup.msi" /quiet /norestart

# Avec log
msiexec /i "USB-Video-Vault-1.0.3-setup.msi" /quiet /l*v install.log
```

### 3. Post-install automatique (GPO Startup Script)
```powershell
# Script à déployer via GPO Computer Startup Scripts
powershell.exe -ExecutionPolicy Bypass -File "\\server\share\post-install-simple.ps1" -LicenseSource "\\server\share\enterprise-license.bin"
```

## Validation de l'installation

### Test manuel
```powershell
# Vérifier la structure
Test-Path "$env:VAULT_PATH\.vault\license.bin"

# Test de l'application
& "C:\Program Files\USB Video Vault\USB Video Vault.exe" --verify-license
```

### Script de validation automatique
```powershell
# Validation complète
.\scripts\validate-installation.ps1 -VaultPath $env:VAULT_PATH
```

## Résolution de problèmes

### Problèmes courants

**1. VAULT_PATH non défini**
```powershell
# Solution
[Environment]::SetEnvironmentVariable("VAULT_PATH", "$env:USERPROFILE\Documents\Yindo-USB-Video-Vault\vault-real", "User")
```

**2. Licence non trouvée**
```powershell
# Vérification
ls "$env:VAULT_PATH\.vault\license.bin"

# Réinstallation
.\scripts\post-install-simple.ps1 -LicenseSource ".\license.bin"
```

**3. Permissions insuffisantes**
```powershell
# Exécution en administrateur (pour MSI)
Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File .\scripts\post-install-simple.ps1"
```

**4. Script bloqué par ExecutionPolicy**
```powershell
# Bypass temporaire
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Ou exécution directe avec bypass
powershell -ExecutionPolicy Bypass -File .\scripts\post-install-simple.ps1
```

## Workflow complet de déploiement

### Pour développeur/administrateur
1. **Préparation** : Générer licence client spécifique
2. **Build** : `npm run build:installers` avec licence intégrée
3. **Test** : Validation sur machine de test
4. **Distribution** : Déploiement via USB, réseau, ou GPO

### Pour utilisateur final
1. **Installation** : Exécuter l'installateur (portable/MSI/NSIS)
2. **Configuration** : Script post-install automatique ou manuel
3. **Validation** : Lancement de l'application et test de licence
4. **Utilisation** : Insertion de vault USB et lecture de médias

---

**Note** : Tous les scripts incluent une gestion d'erreurs robuste et des logs détaillés pour faciliter le debugging et le support utilisateur.