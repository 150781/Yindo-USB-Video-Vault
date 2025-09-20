# Changelog

## [1.0.3] - 2025-01-19 - Release Candidate Production

### ✨ Fonctionnalités ajoutées
- **Système de licence sécurisé** : Intégration complète avec binding machine, anti-rollback et expiration
- **Vault de médias USB** : Support complet pour contenus vidéo cryptés avec métadonnées
- **Interface moderne** : Player vidéo Tailwind/TypeScript avec contrôles avancés
- **Gestion de playlist** : Fonctionnalités complètes de playlist avec mémorisation d'état

### 🔒 Sécurité
- **Anti-rollback** : Protection contre la manipulation d'horloge système et downgrade
- **Binding machine** : Licence liée à l'empreinte matérielle unique
- **État persistant** : Tracking sécurisé des sessions et de l'usage
- **Cryptage des médias** : Contenus protégés avec clés dérivées

### 🛠️ Outils opérationnels
- **Scripts d'installation** : Déploiement automatisé onsite avec vérifications
- **Scripts de diagnostic** : Résolution d'incidents et debugging système
- **Scripts d'urgence** : Reset et récupération pour situations critiques
- **Guide opérateur** : Documentation complète pour administration

### 📦 Packaging & Distribution
- **Package portable** : Exécutable autonome pour déploiement USB
- **SBOM inclus** : Bill of Materials CycloneDX pour audit de sécurité
- **Empreintes SHA256** : Vérification d'intégrité des binaires
- **Signature Authenticode** : Certification Microsoft avec horodatage

### 🔧 Corrections techniques
- **IPC Architecture** : Communication sécurisée entre main et renderer
- **Gestion mémoire** : Optimisations pour lecture/décodage vidéo
- **Robustesse réseau** : Gestion d'erreurs et reconnexion automatique
- **Compatibilité** : Support Windows 10/11 avec lecteurs USB

### 📚 Documentation
- **Guide client** : Installation et utilisation pour utilisateurs finaux  
- **Runbook opérateur** : Procédures d'administration et maintenance
- **Procédures incident** : Réponse aux problèmes critiques et récupération
- **Architecture système** : Documentation technique détaillée

---

### Notes de déploiement

**Pré-requis système :**
- Windows 10/11 (x64)
- 4GB RAM minimum
- 1GB espace disque libre
- Lecteur USB pour vault

**Vérification post-installation :**
```powershell
# Vérifier signature exécutable
Get-AuthenticodeSignature .\USB-Video-Vault-1.0.3-portable.exe

# Vérifier empreinte SHA256  
CertUtil -hashfile .\USB-Video-Vault-1.0.3-portable.exe SHA256

# Test licence (avec vault USB inséré)
.\USB-Video-Vault-1.0.3-portable.exe --verify-license
```

**Support et maintenance :**
- Guide opérateur : `docs/OPERATOR_RUNBOOK.md`
- Diagnostic : `scripts/diagnose-binding.ps1`
- Urgence : `scripts/emergency-reset.ps1`