# 📦 Scripts Post-Installation Client

## 🎯 Objectif

Automatiser le déploiement et la validation des licences USB Video Vault chez le client avec vérification automatique des logs.

## 🚀 Scripts Disponibles

### 1. **Script Simple** (`install-license-simple.ps1`)

**Usage rapide :**
```powershell
# Installation standard
.\scripts\install-license-simple.ps1 -LicenseSource ".\license.bin"

# Installation personnalisée
.\scripts\install-license-simple.ps1 -VaultPath "C:\MonVault" -LicenseSource ".\license.bin" -Exe "C:\MonApp\app.exe"
```

**Fonctionnalités :**
- ✅ Copie license.bin vers `.vault/license.bin`
- ✅ Démarre l'application (si trouvée)
- ✅ Attend 5 secondes pour les logs
- ✅ Vérifie validation dans les logs
- ✅ Diagnostic erreurs courantes

### 2. **Script Avancé** (`post-install-client.ps1`)

**Usage avancé :**
```powershell
# Installation avec monitoring détaillé
.\scripts\post-install-client.ps1 -Verbose -TimeoutSeconds 15

# Installation avec attente fermeture app
.\scripts\post-install-client.ps1 -WaitForExit
```

**Fonctionnalités avancées :**
- ✅ Vérifications prérequis
- ✅ Validation taille fichier licence
- ✅ Logs détaillés avec timestamps
- ✅ Diagnostic multi-chemins logs
- ✅ Rapport final complet
- ✅ Codes de sortie précis

## 📋 Paramètres

| Paramètre | Description | Défaut |
|-----------|-------------|---------|
| `VaultPath` | Dossier vault cible | `$env:USERPROFILE\Documents\Yindo-USB-Video-Vault\vault-real` |
| `LicenseSource` | Fichier licence source | `.\out\license.bin` |
| `Exe` | Exécutable application | `C:\Program Files\USB Video Vault\USB Video Vault.exe` |
| `Verbose` | Logs détaillés | `$false` |
| `TimeoutSeconds` | Attente logs | `10` |
| `WaitForExit` | Attendre fermeture app | `$false` |

## 🔍 Codes de Sortie

| Code | Signification | Action |
|------|---------------|---------|
| `0` | ✅ Licence validée avec succès | Installation réussie |
| `1` | ❌ Erreur prérequis ou logs non trouvés | Vérifier installation |
| `2` | ❌ Licence invalide (signature/binding/expiration) | Régénérer licence |

## 🧪 Tests et Validation

### Test Rapide
```powershell
# 1. Créer logs de test
.\test\test-post-install.ps1

# 2. Tester installation
.\scripts\install-license-simple.ps1 -LicenseSource "vault-real\.vault\license.bin" -VaultPath "test-install"

# 3. Vérifier résultat
echo $LASTEXITCODE  # Doit être 0
```

### Test Complet
```powershell
# Test tous les scénarios
.\test\test-all-post-install-scenarios.ps1
```

## 🔧 Diagnostic Automatique

### Erreurs Détectées
- **`Invalid signature`** → Licence corrompue ou falsifiée
- **`Machine binding failed`** → Machine différente, nouvelle empreinte requise
- **`License expired`** → Licence expirée, renouvellement requis
- **`Rollback attempt`** → Tentative de rollback détectée

### Actions Automatiques
- Copie sécurisée licence
- Validation taille fichier
- Recherche logs multiples chemins
- Diagnostic erreurs spécifiques
- Instructions de récupération

## 📁 Structure Déploiement

### Chez l'Opérateur
```
delivery-package/
├── license.bin                    # Licence générée
├── install-license-simple.ps1     # Script installation
├── README-CLIENT.md               # Guide client
└── support-info.txt               # Infos support
```

### Chez le Client
```
# Exécution
PS> .\install-license-simple.ps1

# Résultat attendu
Post-Install Client USB Video Vault
====================================
Installation licence...
OK Licence copiee vers: vault\.vault\license.bin
Demarrage application...
OK Application demarree (PID: 1234)
Attente validation (5 secondes)...
Verification logs...
Log: C:\Users\...\USB Video Vault\logs\main.log
SUCCESS LICENCE VALIDEE AVEC SUCCES
Installation terminee
```

## 🛠️ Workflow Opérateur

### 1. Génération Package Client
```powershell
# 1. Obtenir empreinte
node scripts/print-bindings.mjs

# 2. Générer licence
$env:PACKAGER_PRIVATE_HEX = "[SECRET]"
node scripts/make-license.mjs "FINGERPRINT" --kid 1 --exp "2025-12-31"

# 3. Préparer package
mkdir delivery-package
copy vault-real\.vault\license.bin delivery-package\
copy scripts\install-license-simple.ps1 delivery-package\
copy docs\CLIENT_LICENSE_GUIDE.md delivery-package\README-CLIENT.md
```

### 2. Instructions Client
```
Copier-coller pour le client:
=============================
1. Extraire le package reçu
2. Ouvrir PowerShell en administrateur
3. Exécuter: .\install-license-simple.ps1
4. Vérifier message "SUCCESS LICENCE VALIDEE"
5. Si erreur, envoyer capture d'écran au support
```

### 3. Support à Distance
```powershell
# Diagnostic à distance (client exécute)
.\install-license-simple.ps1 -Verbose

# Récupération logs pour support
Get-Content "$env:APPDATA\USB Video Vault\logs\main.log" -Tail 50
```

## 🔐 Sécurité

### Vérifications Intégrées
- ✅ Validation taille licence (détection corruption)
- ✅ Vérification chemins sécurisés
- ✅ Pas de données sensibles dans logs script
- ✅ Échecs sécurisés (pas de révélation info)

### Bonnes Pratiques
- 🔄 Toujours utiliser scripts officiels
- 📁 Vérifier intégrité package livré
- 🔍 Valider logs application après installation
- 📞 Escalader support si codes erreur persistants

## 📊 Métriques Succès

```
✅ Installation réussie: Code 0 + "SUCCESS LICENCE VALIDEE"
✅ Temps installation: < 30 secondes
✅ Aucune intervention manuelle requise
✅ Diagnostic automatique des erreurs
✅ Instructions de récupération claires
```

---
**Scripts prêts pour déploiement production** 🎯