# USB Video Vault - Installateurs et Post-Install

## 🚀 Démarrage rapide

### 1. Génération des installateurs
```bash
# Tous les installateurs (recommandé)
npm run build:installers

# Ou individuellement
npm run build:portable   # Version portable
npm run build:nsis      # Installateur NSIS  
npm run build:msi       # Installateur MSI
```

### 2. Installation post-déploiement
```powershell
# Installation automatique de la licence
npm run post-install

# Ou avec script direct
.\scripts\post-install-simple.ps1 -LicenseSource "path\to\license.bin"
```

## 📦 Types d'installateurs

| Type | Fichier | Usage | Avantages |
|------|---------|-------|-----------|
| **Portable** | `USB-Video-Vault-{version}-win-x64.exe` | Déploiement USB | Aucune installation, portable |
| **NSIS** | `USB-Video-Vault-{version}-win-x64.exe` | Installation desktop | Raccourcis automatiques, post-install |
| **MSI** | `USB-Video-Vault-{version}-setup.msi` | Déploiement entreprise | Compatible GPO, gestion centralisée |

## ⚙️ Configuration vault automatique

### Script post-install (`post-install-simple.ps1`)

**Fonctionnement :**
1. Détecte `$env:VAULT_PATH` ou utilise le chemin par défaut
2. Crée `%VAULT_PATH%\.vault\` si absent
3. Copie `license.bin` vers le vault
4. Définit la variable d'environnement `VAULT_PATH`

**Chemins par défaut :**
```
VAULT_PATH = %USERPROFILE%\Documents\Yindo-USB-Video-Vault\vault-real
Structure créée :
├── vault-real\
│   └── .vault\
│       └── license.bin
```

### Variables d'environnement

```powershell
# Définir un chemin personnalisé
$env:VAULT_PATH = "D:\MonVault"
[Environment]::SetEnvironmentVariable("VAULT_PATH", "D:\MonVault", "User")

# Vérifier la configuration
echo $env:VAULT_PATH
Test-Path "$env:VAULT_PATH\.vault\license.bin"
```

## 🏢 Déploiement en entreprise

### Préparation
```powershell
# 1. Générer licence spécifique client
.\scripts\generate-client-license.ps1 -Owner "Entreprise XYZ"

# 2. Build avec licence intégrée
.\scripts\build-installers.ps1 -LicensePath ".\out\license.bin" -MSI

# 3. Déploiement MSI
msiexec /i "USB-Video-Vault-1.0.3-setup.msi" /quiet
```

### GPO Deployment
```powershell
# Computer Startup Script
powershell.exe -ExecutionPolicy Bypass -File "\\server\share\post-install-simple.ps1" -LicenseSource "\\server\share\enterprise-license.bin"
```

## 🔧 Développement et tests

### Structure des fichiers
```
scripts/
├── build-installers.ps1     # Build tous les installateurs
├── post-install-simple.ps1  # Post-install basique
├── post-install-setup.ps1   # Post-install avancé
└── validate-installation.ps1 # Tests de validation

installer/
├── nsis-installer.nsh       # Configuration NSIS
└── inno-setup.iss          # Configuration Inno Setup

electron-builder.yml         # Config electron-builder
```

### Tests de validation
```powershell
# Test installation locale
.\scripts\post-install-simple.ps1 -LicenseSource "test-license.bin"

# Validation complète
.\scripts\validate-installation.ps1

# Test build sans installation
.\scripts\build-installers.ps1 -SkipBuild
```

## 🛠️ Résolution de problèmes

### Problèmes courants

**Script bloqué par ExecutionPolicy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
# ou
powershell -ExecutionPolicy Bypass -File .\scripts\post-install-simple.ps1
```

**VAULT_PATH non défini après installation**
```powershell
# Redémarrer le terminal ou définir manuellement
$env:VAULT_PATH = "$env:USERPROFILE\Documents\Yindo-USB-Video-Vault\vault-real"
```

**Licence non trouvée**
```powershell
# Vérifier l'emplacement
ls "$env:VAULT_PATH\.vault\license.bin"

# Réinstaller
.\scripts\post-install-simple.ps1 -LicenseSource "path\to\license.bin"
```

### Logs et debugging
```powershell
# Script avec verbose
.\scripts\post-install-setup.ps1 -Verbose

# Validation manuelle
Test-Path "$env:VAULT_PATH\.vault"
Get-ChildItem "$env:VAULT_PATH\.vault"
```

## 📋 Checklist de déploiement

### Avant le build
- [ ] Licence client générée et testée
- [ ] Version mise à jour dans `package.json`
- [ ] Tests de l'application en local

### Build des installateurs
- [ ] `npm run build:installers` sans erreurs
- [ ] Validation des fichiers dans `release/`
- [ ] Test installation sur machine propre

### Post-installation
- [ ] Script post-install testé avec licence
- [ ] Variable `VAULT_PATH` correctement définie
- [ ] Application lance et détecte la licence
- [ ] Lecture de médias fonctionnelle

### Distribution
- [ ] Documentation utilisateur fournie
- [ ] Instructions d'installation claires
- [ ] Support technique informé des procédures

---

**Support :** Pour toute question, consultez la documentation complète dans `docs/INSTALLER_GUIDE.md`