# Corrections de conformité PowerShell Script Analyzer

## Résumé des corrections appliquées

Ce document détaille les corrections apportées aux scripts PowerShell pour respecter les bonnes pratiques et les règles de PSScriptAnalyzer.

## Scripts corrigés

### 🔧 `scripts/create-release.ps1`

#### Corrections appliquées

| Règle | Problème | Solution appliquée |
|-------|----------|-------------------|
| `PSAvoidUsingPlainTextForPassword` | Paramètre `[string]$CertPassword` | ✅ Changé en `[SecureString]$CertPassword` |
| `PSAvoidDefaultValueSwitchParameter` | Switch `$TestMode = $true` | ✅ Supprimé la valeur par défaut |
| `PSUseApprovedVerbs` | Fonction `Build-Application` | ✅ Renommé en `Invoke-ApplicationBuild` |
| `PSUseApprovedVerbs` | Fonction `Generate-SBOM` | ✅ Renommé en `New-SBOM` |
| `PSUseApprovedVerbs` | Fonction `Calculate-Hashes` | ✅ Renommé en `Get-FileHashes` |
| `PSUseApprovedVerbs` | Fonction `Sign-Executables` | ✅ Renommé en `Set-ExecutableSignatures` |
| `PSUseApprovedVerbs` | Fonction `Create-ReleasePackage` | ✅ Renommé en `New-ReleasePackage` |
| `PSUseApprovedVerbs` | Fonction `Generate-ReleaseReport` | ✅ Renommé en `New-ReleaseReport` |

## Verbes PowerShell approuvés utilisés

### Mapping des corrections

```powershell
# AVANT (Non-conformes)
Build-Application     # Build n'est pas un verbe approuvé
Generate-SBOM         # Generate n'est pas un verbe approuvé  
Calculate-Hashes      # Calculate n'est pas un verbe approuvé
Sign-Executables      # Sign n'est pas un verbe approuvé
Create-ReleasePackage # Create n'est pas un verbe approuvé

# APRÈS (Conformes)
Invoke-ApplicationBuild  # Invoke = exécuter une action complexe
New-SBOM                # New = créer quelque chose
Get-FileHashes          # Get = récupérer des informations
Set-ExecutableSignatures # Set = configurer/appliquer une propriété
New-ReleasePackage      # New = créer quelque chose
New-ReleaseReport       # New = créer quelque chose
```

## Gestion sécurisée des mots de passe

### Script helper créé : `helper-secure-password.ps1`

Ce script fournit des fonctions pour la gestion sécurisée des mots de passe :

- **`New-SecurePassword`** : Création interactive de mots de passe sécurisés
- **`Export-SecurePassword`** : Sauvegarde cryptée des mots de passe
- **`Import-SecurePassword`** : Chargement des mots de passe sauvegardés

### Exemples d'utilisation

```powershell
# 1. Utilisation interactive
$securePassword = Read-Host -AsSecureString -Prompt "Mot de passe certificat"
.\create-release.ps1 -CertPath "certificate.p12" -CertPassword $securePassword

# 2. Avec helper
.\helper-secure-password.ps1  # Interface interactive
$securePassword = New-SecurePassword

# 3. Sauvegarde pour réutilisation
Export-SecurePassword -SecurePassword $securePassword -FilePath "cert.secure"
$securePassword = Import-SecurePassword -FilePath "cert.secure"
```

## Validation des scripts

### Script de validation amélioré : `check-psscriptanalyzer.ps1`

```powershell
# Validation complète du projet
.\scripts\check-psscriptanalyzer.ps1 -Detailed

# Validation d'un répertoire spécifique
.\scripts\check-psscriptanalyzer.ps1 -Path "scripts" -Detailed

# Exclusion de certaines règles
.\scripts\check-psscriptanalyzer.ps1 -ExcludeRule @("PSAvoidUsingWriteHost")
```

## État de conformité

### ✅ Scripts entièrement conformes

- `scripts/create-release.ps1` - Script de release automatisé
- `scripts/helper-secure-password.ps1` - Helper pour mots de passe sécurisés
- `scripts/check-psscriptanalyzer.ps1` - Validation PSScriptAnalyzer

### ⚠️ Règles intentionnellement ignorées

Certaines règles peuvent être ignorées selon le contexte :

- **`PSAvoidUsingWriteHost`** : Pour les scripts avec output console nécessaire
- **`PSUseShouldProcessForStateChangingFunctions`** : Pour les scripts simples sans `-WhatIf`

## Bonnes pratiques appliquées

### 1. Sécurité des paramètres
```powershell
# ❌ Éviter
param([string]$Password)

# ✅ Recommandé  
param([SecureString]$Password)
```

### 2. Verbes approuvés
```powershell
# ❌ Éviter
function Create-Something {}
function Build-Something {}
function Calculate-Something {}

# ✅ Recommandé
function New-Something {}      # Créer
function Invoke-Something {}   # Exécuter
function Get-Something {}      # Récupérer
function Set-Something {}      # Configurer
```

### 3. Paramètres switch
```powershell
# ❌ Éviter
param([switch]$TestMode = $true)

# ✅ Recommandé
param([switch]$TestMode)
```

## Tests de validation

### Commande de validation globale

```powershell
# Valider tous les scripts du projet
.\scripts\check-psscriptanalyzer.ps1 -Path "." -Detailed

# Résultat attendu : 0 problèmes détectés
```

### Intégration continue

Pour intégrer la validation dans le processus de build :

```powershell
# Dans le pipeline CI/CD
$result = .\scripts\check-psscriptanalyzer.ps1
if (-not $result) {
    throw "Scripts non conformes aux bonnes pratiques PowerShell"
}
```

## Outils et ressources

- **PSScriptAnalyzer** : [GitHub](https://github.com/PowerShell/PSScriptAnalyzer)
- **Verbes approuvés** : `Get-Verb` ou [Documentation](https://docs.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- **Bonnes pratiques** : [PowerShell Practice and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/)

---

*Documentation générée le 2025-01-19 - Release v1.0.3*