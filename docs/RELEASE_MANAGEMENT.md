# Guide de gestion des versions - USB Video Vault

## 📋 Stratégie de versioning

### Semantic Versioning (SemVer)
Format : `MAJOR.MINOR.PATCH` (ex: `1.2.3`)

- **MAJOR** : Changements incompatibles avec les versions antérieures
- **MINOR** : Nouvelles fonctionnalités compatibles
- **PATCH** : Corrections de bugs compatibles

### Pre-release et metadata
- **Alpha** : `1.2.3-alpha.1` - Version de développement interne
- **Beta** : `1.2.3-beta.1` - Version de test public
- **RC** : `1.2.3-rc.1` - Release Candidate
- **Build metadata** : `1.2.3+20240110.abc123` - Informations de build

## 🚀 Processus de release

### 1. Préparation de la release

```powershell
# 1. Vérifier l'état du repository
git status
git pull origin main

# 2. Audit de sécurité complet
.\tools\security\security-audit.ps1 -Detailed -ExportReport ".\audit-pre-release.json"

# 3. Tests complets
npm test
npm run test:e2e
.\tools\support\troubleshoot.ps1 -Detailed

# 4. Build et packaging
npm run clean
npm run build
npm run electron:build

# 5. Vérification des artifacts
.\tools\verify-release.ps1
```

### 2. Bump de version

```powershell
# Version patch (1.0.0 -> 1.0.1)
npm version patch

# Version minor (1.0.1 -> 1.1.0)
npm version minor

# Version major (1.1.0 -> 2.0.0)
npm version major

# Pre-release
npm version prerelease --preid=beta  # 1.1.0 -> 1.1.1-beta.0
```

### 3. Release automatisée

```powershell
# Push avec tags pour déclencher la CI
git push origin main --tags

# La GitHub Action se charge de :
# - Build multi-plateforme
# - Tests automatisés
# - Génération des artifacts
# - Publication sur GitHub Releases
# - Notification des canaux
```

## 📊 Branches et workflow

### Structure des branches
```
main                    # Production stable
├── develop            # Intégration continue
├── feature/xyz        # Nouvelles fonctionnalités
├── hotfix/xyz         # Corrections urgentes
└── release/1.2.0      # Préparation de release
```

### Workflow GitFlow adapté

1. **Feature Development**
   ```bash
   git checkout -b feature/nouvelle-fonctionnalite develop
   # Développement...
   git checkout develop
   git merge --no-ff feature/nouvelle-fonctionnalite
   ```

2. **Release Preparation**
   ```bash
   git checkout -b release/1.2.0 develop
   # Finalisation, tests, documentation...
   git checkout main
   git merge --no-ff release/1.2.0
   git tag -a v1.2.0 -m "Release v1.2.0"
   ```

3. **Hotfix**
   ```bash
   git checkout -b hotfix/fix-critique main
   # Correction rapide...
   git checkout main
   git merge --no-ff hotfix/fix-critique
   git tag -a v1.2.1 -m "Hotfix v1.2.1"
   ```

## 🏷️ Gestion des tags

### Convention de nommage
- **Release stable** : `v1.2.3`
- **Pre-release** : `v1.2.3-beta.1`
- **Build interne** : `build-20240110-abc123`

### Scripts automatisés

```powershell
# Création de tag avec métadonnées
function New-ReleaseTag {
    param($Version)

    $buildHash = git rev-parse --short HEAD
    $buildDate = Get-Date -Format "yyyy-MM-dd"

    git tag -a "v$Version" -m @"
Release v$Version

Build: $buildHash
Date: $buildDate
Environment: Production
Approved-by: Release Manager
"@
}

# Usage
New-ReleaseTag "1.2.3"
```

## 📄 Changelog automatisé

### Format standard (Keep a Changelog)

```markdown
# Changelog

## [1.2.3] - 2024-01-10

### Added
- Nouvelle interface de gestion des playlists
- Support du drag & drop multi-fichiers

### Changed
- Amélioration des performances de lecture
- Interface utilisateur modernisée

### Fixed
- Correction du bug de synchronisation vault
- Résolution des problèmes de mémoire

### Security
- Mise à jour des dépendances de sécurité
- Renforcement du chiffrement des données
```

### Génération automatique

```powershell
# Script de génération de changelog
.\tools\release\generate-changelog.ps1 -FromTag "v1.2.0" -ToTag "v1.2.3"

# Intégration dans le processus de release
npm run release:changelog
```

## 🔐 Signing et authentification

### Code Signing
```powershell
# Configuration du certificat de signature
$certPath = "C:\Certificates\usb-video-vault.p12"
$timestamp = "http://timestamp.digicert.com"

# Signature automatique dans electron-builder
# (voir electron-builder.yml)
```

### Checksum et vérification
```powershell
# Génération des checksums
Get-FileHash "dist\USB Video Vault Setup 1.2.3.exe" -Algorithm SHA256 > SHA256SUMS
Get-FileHash "dist\USB Video Vault Setup 1.2.3.exe" -Algorithm SHA512 > SHA512SUMS

# Signature GPG des checksums
gpg --detach-sign --armor SHA256SUMS
```

## 📈 Métriques et monitoring

### KPIs de release
- **Time to Market** : Temps entre merge et release
- **Bug Escape Rate** : Bugs découverts post-release
- **Rollback Rate** : Pourcentage de releases nécessitant un rollback
- **Adoption Rate** : Vitesse d'adoption des nouvelles versions

### Monitoring post-release
```powershell
# Script de monitoring des 48h post-release
.\tools\monitoring\post-release-watch.ps1 -Version "1.2.3" -Duration 48
```

## 🔄 Rollback et recovery

### Procédure de rollback
1. **Assessment** : Évaluation de la criticité
2. **Communication** : Notification des utilisateurs
3. **Rollback** : Retour à la version précédente
4. **Investigation** : Analyse post-mortem

```powershell
# Script de rollback automatisé
.\tools\release\rollback.ps1 -FromVersion "1.2.3" -ToVersion "1.2.2" -Reason "Critical bug in video playback"
```

## 📋 Checklist de release

### Pre-release
- [ ] Audit de sécurité complet
- [ ] Tests automatisés passent
- [ ] Tests manuels validés
- [ ] Documentation mise à jour
- [ ] Changelog rédigé
- [ ] Version bumpée
- [ ] Build artifacts générés
- [ ] Code signing effectué

### Release
- [ ] Tag créé et poussé
- [ ] Release GitHub publiée
- [ ] Artifacts téléchargés et vérifiés
- [ ] Checksums et signatures publiées
- [ ] Communication utilisateurs
- [ ] Monitoring activé

### Post-release
- [ ] Adoption monitoring (24h)
- [ ] Error tracking (48h)
- [ ] Feedback utilisateurs collecté
- [ ] Métriques de performance validées
- [ ] Planning next release mis à jour

## 🛠️ Scripts d'automatisation

### Commandes principales
```powershell
# Release complète
.\tools\release\full-release.ps1 -Version "1.2.3" -Type "minor"

# Pre-release / Beta
.\tools\release\pre-release.ps1 -Version "1.3.0-beta.1"

# Hotfix urgent
.\tools\release\hotfix.ps1 -Version "1.2.4" -Issue "CVE-2024-XXXX"

# Rollback
.\tools\release\rollback.ps1 -FromVersion "1.2.3" -ToVersion "1.2.2"
```

### Configuration

```json
// release.config.json
{
  "branches": ["main", "develop"],
  "signing": {
    "certificate": "certificates/usb-video-vault.p12",
    "timestampServer": "http://timestamp.digicert.com"
  },
  "distribution": {
    "github": true,
    "winget": true,
    "chocolatey": true,
    "autoUpdate": true
  },
  "monitoring": {
    "webhook": "https://hooks.slack.com/...",
    "errorTracking": "sentry",
    "analytics": "google-analytics"
  }
}
```
