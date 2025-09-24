# USB Video Vault v0.1.4

🎉 **Première release de production** - Application complètement stabilisée et prête pour déploiement professionnel.

## ✨ Nouveautés

### 🖼️ **Identité visuelle**
- **Nouveau logo Yindo** intégré dans l'application et l'installateur
- **Icône Windows (.ico)** professionnelle pour l'exécutable
- **Interface utilisateur** cohérente avec la charte graphique

### 📦 **Distribution professionnelle**
- **Installateur NSIS** (`USB Video Vault Setup 0.1.4.exe`)
  - Installation/désinstallation propre
  - Support installation silencieuse (`/S`)
  - Entrées dans Programs & Features
- **Version portable** (`USB Video Vault 0.1.4.exe`)
  - Aucune installation requise
  - Fonctionne depuis n'importe quel dossier
  - Idéale pour clés USB ou environnements restreints

### 🔐 **Sécurité et fiabilité**
- **Signature de code** Windows (certificat valide)
- **Vérification d'intégrité** (SHA256SUMS fourni)
- **Protection anti-manipulation** des binaires
- **Scripts de validation** automatisés lors du build

## 🔧 Correctifs majeurs

### ⚡ **Stabilité du processus principal**
- **RÉSOLU**: Erreur critique "A JavaScript error occurred in the main process"
- **Migration CommonJS** complète du processus principal Electron
- **Compatibilité garantie** avec toutes les versions d'Electron
- **Scripts de protection** contre les régressions futures

### 🏗️ **Architecture de build**
- **Pipeline CI/CD** robuste avec GitHub Actions
- **Build multi-plateformes** (Windows, macOS, Linux)
- **Tests automatisés** de validation avant release
- **Garde-fous** pour éviter les erreurs de configuration

## 📋 Installation

### Installation classique (recommandée)
```powershell
# Télécharger et exécuter
.\USB Video Vault Setup 0.1.4.exe

# Installation silencieuse
.\USB Video Vault Setup 0.1.4.exe /S
```

### Version portable
```powershell
# Simplement extraire et lancer
.\USB Video Vault 0.1.4.exe
```

## 🔍 Vérification d'intégrité

Utilisez le script fourni pour vérifier l'authenticité :
```powershell
.\tools\verify-release.ps1 -Path "C:\Downloads"
```

Ou vérifiez manuellement :
```powershell
# Vérifier la signature
Get-AuthenticodeSignature ".\USB Video Vault Setup 0.1.4.exe"

# Vérifier l'empreinte SHA256
Get-FileHash ".\USB Video Vault Setup 0.1.4.exe" -Algorithm SHA256
```

## ⚠️ Notes importantes

### Windows SmartScreen
Lors du premier lancement, Windows SmartScreen peut afficher un avertissement. Ceci est normal pour une nouvelle application signée - la réputation se construit avec le temps et les téléchargements.

**Solution** : Cliquez sur "Plus d'infos" puis "Exécuter quand même".

### Configuration requise
- **OS** : Windows 10 version 1903 ou supérieure
- **Architecture** : x64 uniquement
- **RAM** : 4 GB minimum, 8 GB recommandé
- **Espace disque** : 200 MB pour l'application + espace pour les médias

## 🚀 Prochaines étapes

- Support macOS et Linux natif
- Interface de gestion avancée des licences
- Intégration cloud pour synchronisation
- API REST pour intégration entreprise

## 🐛 Problèmes connus

Aucun problème bloquant identifié. Pour signaler un bug : [GitHub Issues](https://github.com/150781/Yindo-USB-Video-Vault/issues)

---

**Téléchargements** : [Release GitHub](https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/v0.1.4)
**Documentation** : [Wiki du projet](https://github.com/150781/Yindo-USB-Video-Vault/wiki)
**Support** : [Discussions GitHub](https://github.com/150781/Yindo-USB-Video-Vault/discussions)
