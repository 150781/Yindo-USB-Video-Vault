# 🎮 USB Video Vault

> **Système de stockage et lecture vidéo sécurisé pour clés USB**
> 
> Application Electron avec chiffrement AES-256-GCM, gestion de licences, et interface intuitive.

## 📋 Vue d'ensemble

USB Video Vault est une solution complète pour créer des "vaults" vidéo chiffrés sur clés USB. L'application combine sécurité cryptographique de niveau professionnel avec une expérience utilisateur simple.

### ✨ Fonctionnalités principales

- 🔐 **Chiffrement AES-256-GCM** avec clés dérivées PBKDF2
- 🎫 **Système de licences** avec validation cryptographique
- 📱 **Interface utilisateur moderne** (Electron + Tailwind CSS)
- 🎬 **Lecteur vidéo intégré** avec contrôles avancés
- 📊 **Gestion des playlists** et métadonnées
- 🔧 **Outils de packaging** pour création de vaults
- 🛡️ **Tests de sécurité** automatisés

## 🚀 Démarrage rapide

### Prérequis
- Node.js 18+ 
- npm ou yarn
- Git

### Installation
```bash
# Cloner le projet
git clone <url-du-repo>
cd Yindo-USB-Video-Vault

# Installer les dépendances
npm install

# Construire l'application
npm run build

# Créer l'exécutable portable
npm run electron:build
```

### Premier test
```bash
# Smoke test rapide
.\scripts\smoke.ps1 -WaitSeconds 5

# Test complet avec vault
$env:VAULT_PATH = ".\usb-package\vault"
npm run electron
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

## 🛡️ Sécurité

### Architecture cryptographique
- **Chiffrement** : AES-256-GCM avec IV aléatoire
- **Dérivation de clés** : PBKDF2 avec 100,000 itérations
- **Authentification** : Tags GCM pour intégrité
- **Licences** : Signatures RSA avec validation temporelle

### Tests de sécurité
- Tests d'intrusion automatisés (red team)
- Validation cryptographique
- Audit des dépendances npm
- Scan des APIs dépréciées

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

## 🔄 Maintenance

### Opérations Day-2
```powershell
# Maintenance hebdomadaire complète
.\scripts\day2-ops\weekly-ops.ps1

# Sécurité uniquement
.\scripts\day2-ops\weekly-ops.ps1 -SecurityOnly

# Rapports uniquement  
.\scripts\day2-ops\weekly-ops.ps1 -ReportsOnly
```

### Surveillance
- Health checks automatiques
- Rapports système hebdomadaires  
- Alertes sécurité
- Métriques de performance

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

## 🆘 Support

- **Issues** : Utiliser GitHub Issues pour les bugs
- **Documentation** : Consulter le dossier `/docs`
- **Tests** : Lancer `.\scripts\smoke.ps1` pour diagnostic rapide

---

**Version** : 0.1.0  
**Dernière mise à jour** : Septembre 2025  
**Statut** : Production Ready 🚀