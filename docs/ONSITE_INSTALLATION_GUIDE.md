# 🎯 Guide Installation Site Client - USB Video Vault

## 📋 Vue d'Ensemble

**Objectif**: Installer une licence validée sur le site client  
**Durée**: 5-10 minutes  
**Prérequis**: Licence `.bin` générée par l'administrateur

## 🛠️ Installation Manuelle

### 1. **Localiser le Vault**
```powershell
# Méthode 1: Variable d'environnement (si définie)
$vaultPath = $env:VAULT_PATH
if ($vaultPath) {
    Write-Host "Vault trouvé: $vaultPath"
} else {
    Write-Host "Variable VAULT_PATH non définie"
}

# Méthode 2: Emplacements standards
$possiblePaths = @(
    "$env:USERPROFILE\Documents\vault",
    "C:\vault", 
    "D:\vault",
    ".\vault"
)

foreach ($path in $possiblePaths) {
    if (Test-Path "$path\.vault") {
        Write-Host "Vault trouvé: $path"
        $vaultPath = $path
        break
    }
}
```

### 2. **Copier la Licence**
```powershell
# Chemin destination
$licenseDest = "$vaultPath\.vault\license.bin"

# Créer dossier .vault si nécessaire
$vaultDir = "$vaultPath\.vault"
if (-not (Test-Path $vaultDir)) {
    New-Item $vaultDir -ItemType Directory -Force
    Write-Host "Dossier .vault créé: $vaultDir"
}

# Copier licence
Copy-Item "chemin\vers\votre\license.bin" $licenseDest -Force
Write-Host "Licence installée: $licenseDest"
```

### 3. **Vérifier Installation**
```powershell
# Vérifier fichier présent
if (Test-Path $licenseDest) {
    $size = (Get-Item $licenseDest).Length
    Write-Host "✅ Licence présente ($size bytes)"
} else {
    Write-Host "❌ Licence manquante"
}

# Tester avec script de vérification (si disponible)
if (Test-Path "scripts\verify-license.mjs") {
    & node scripts\verify-license.mjs $licenseDest
}
```

## 🚀 Installation Automatique

### Script d'Installation Rapide
```powershell
# install-license-onsite.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$LicenseFile,
    
    [string]$VaultPath = "",
    [switch]$Verify = $true
)

Write-Host "INSTALLATION LICENCE SITE CLIENT" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# 1. Vérifier licence source
if (-not (Test-Path $LicenseFile)) {
    Write-Error "Fichier licence introuvable: $LicenseFile"
    exit 1
}

Write-Host "Licence source: $LicenseFile" -ForegroundColor Green

# 2. Détecter vault automatiquement
if (-not $VaultPath) {
    $VaultPath = $env:VAULT_PATH
}

if (-not $VaultPath) {
    $candidates = @(
        "$env:USERPROFILE\Documents\vault",
        "C:\vault",
        "D:\vault", 
        ".\vault"
    )
    
    foreach ($candidate in $candidates) {
        if (Test-Path "$candidate\.vault" -PathType Container) {
            $VaultPath = $candidate
            break
        }
    }
}

if (-not $VaultPath) {
    Write-Error "Vault non trouvé. Spécifier -VaultPath"
    exit 1
}

Write-Host "Vault détecté: $VaultPath" -ForegroundColor Green

# 3. Préparer destination
$vaultDir = "$VaultPath\.vault"
$licenseDest = "$vaultDir\license.bin"

if (-not (Test-Path $vaultDir)) {
    New-Item $vaultDir -ItemType Directory -Force | Out-Null
    Write-Host "Dossier .vault créé" -ForegroundColor Yellow
}

# Backup licence existante
if (Test-Path $licenseDest) {
    $backup = "$licenseDest.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $licenseDest $backup
    Write-Host "Licence existante sauvegardée: $backup" -ForegroundColor Yellow
}

# 4. Installer nouvelle licence
try {
    Copy-Item $LicenseFile $licenseDest -Force
    Write-Host "✅ Licence installée avec succès" -ForegroundColor Green
    
    $size = (Get-Item $licenseDest).Length
    Write-Host "Taille: $size bytes" -ForegroundColor Gray
    
} catch {
    Write-Error "Erreur installation: $_"
    exit 1
}

# 5. Vérification
if ($Verify) {
    Write-Host "`nVérification..." -ForegroundColor Cyan
    
    # Test basique
    if (Test-Path $licenseDest) {
        Write-Host "✅ Fichier présent" -ForegroundColor Green
    } else {
        Write-Host "❌ Fichier manquant" -ForegroundColor Red
        exit 1
    }
    
    # Test avec script si disponible
    if (Test-Path "scripts\verify-license.mjs") {
        try {
            & node scripts\verify-license.mjs $licenseDest
            Write-Host "✅ Licence valide" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Erreur vérification: $_" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n🎉 INSTALLATION TERMINÉE" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host "Licence: $licenseDest" -ForegroundColor White
Write-Host "Prochaine étape: Lancer l'application et vérifier 'Licence validée'" -ForegroundColor Cyan
```

## ✅ Test Post-Installation

### 1. **Lancement Application**
```powershell
# Démarrer USB Video Vault
Start-Process "chemin\vers\USB Video Vault.exe"

# Surveiller logs (si accessible)
$logPath = "$env:APPDATA\USB Video Vault\logs"
if (Test-Path $logPath) {
    Write-Host "Logs disponibles: $logPath"
}
```

### 2. **Vérifications Visuelles**
```
✅ Application démarre sans erreur
✅ Interface affiche "Licence validée" 
✅ Accès aux médias autorisé
✅ Aucun message d'expiration
✅ Fonctionnalités premium disponibles
```

### 3. **Tests Fonctionnels**
```
✅ Lecture média test
✅ Navigation dans vault
✅ Toutes fonctionnalités accessibles
✅ Pas de limitations affichées
✅ Performance normale
```

## 🚨 Résolution Problèmes

### Erreur "Licence invalide"
```powershell
# 1. Vérifier empreinte machine
& node scripts\print-bindings.mjs

# 2. Comparer avec licence générée
& node scripts\verify-license.mjs "$vaultPath\.vault\license.bin"

# 3. Si différent, regénérer licence avec nouvelle empreinte
```

### Erreur "Horloge système"
```powershell
# 1. Vérifier heure système
Get-Date

# 2. Corriger si nécessaire
Set-Date "2025-09-19 15:30:00"

# 3. Reset state si problème persiste
Remove-Item "$env:APPDATA\USB Video Vault\.license_state.json" -Force
```

### Erreur "Fichier non trouvé"
```powershell
# 1. Vérifier permissions
icacls "$vaultPath\.vault\license.bin"

# 2. Recréer dossier .vault
Remove-Item "$vaultPath\.vault" -Recurse -Force
New-Item "$vaultPath\.vault" -ItemType Directory
Copy-Item license.bin "$vaultPath\.vault\license.bin"
```

## 📞 Support Urgence

### Informations à Collecter
```
✅ Message d'erreur exact
✅ Sortie de print-bindings.mjs
✅ Chemin vault utilisé
✅ Taille fichier licence
✅ Logs application (si accessible)
✅ Heure système actuelle
```

### Script Diagnostic Rapide
```powershell
# diagnostic-onsite.ps1
Write-Host "DIAGNOSTIC SITE CLIENT" -ForegroundColor Cyan

# Machine
Write-Host "Machine: $env:COMPUTERNAME"
Write-Host "Utilisateur: $env:USERNAME"
Write-Host "Heure: $(Get-Date)"

# Vault
$vaultPath = $env:VAULT_PATH
if (-not $vaultPath) { $vaultPath = "$env:USERPROFILE\Documents\vault" }
Write-Host "Vault: $vaultPath"
Write-Host "Licence: $(if(Test-Path "$vaultPath\.vault\license.bin") { 'Présente' } else { 'Absente' })"

# Empreinte
if (Test-Path "scripts\print-bindings.mjs") {
    Write-Host "`nEmpreinte:"
    & node scripts\print-bindings.mjs
}

# Application
$appProcess = Get-Process "USB Video Vault" -ErrorAction SilentlyContinue
Write-Host "Application: $(if($appProcess) { 'En cours' } else { 'Arrêtée' })"
```

## 📋 Checklist Installation

```
AVANT INSTALLATION:
□ Licence .bin reçue et vérifiée
□ Vault path identifié
□ Application fermée
□ Permissions suffisantes

INSTALLATION:
□ Dossier .vault créé/vérifié
□ Licence copiée dans .vault/license.bin
□ Backup ancienne licence (si existante)
□ Permissions correctes sur fichier

VERIFICATION:
□ Fichier licence présent
□ Taille cohérente (> 400 bytes)
□ Script verify-license.mjs OK (si disponible)
□ Application démarre sans erreur

POST-INSTALLATION:
□ Interface affiche "Licence validée"
□ Accès médias fonctionnel
□ Toutes fonctionnalités disponibles
□ Documentation utilisateur fournie

EN CAS DE PROBLEME:
□ Diagnostic complet effectué
□ Support contacté avec infos complètes
□ Backup disponible pour rollback
□ Procédure escalade connue
```

---

**🎯 Installation simplifiée et robuste**  
**✅ Vérifications automatiques complètes**  
**🚨 Support incident intégré**  
**📋 Checklist opérationnelle validée**