# Corrections PowerShell Script Analyzer - build-installers.ps1

## Problèmes détectés et corrigés

### 1. ✅ PSAvoidDefaultValueSwitchParameter (4 occurrences)
**Problème :** Les paramètres switch avaient des valeurs par défaut à `$true`
**Correction :**
```powershell
# AVANT
[switch]$Portable = $true,
[switch]$NSIS = $true,
[switch]$MSI = $true,
[switch]$InnoSetup = $false

# APRÈS  
[switch]$Portable,
[switch]$NSIS,
[switch]$MSI,
[switch]$InnoSetup
```

**Logique d'initialisation ajoutée :**
```powershell
# Initialiser les valeurs par défaut si aucun switch n'est spécifié
$buildSwitchesSpecified = $PSBoundParameters.ContainsKey('Portable') -or 
                         $PSBoundParameters.ContainsKey('NSIS') -or 
                         $PSBoundParameters.ContainsKey('MSI') -or 
                         $PSBoundParameters.ContainsKey('InnoSetup')

if (-not $buildSwitchesSpecified) {
    Write-BuildLog "Aucun installateur spécifié, utilisation des valeurs par défaut" "INFO"
    $Portable = $true
    $NSIS = $true
    $MSI = $true
}
```

### 2. ✅ PSUseApprovedVerbs (5 fonctions corrigées)

#### Build-PortableVersion → New-PortableVersion
```powershell
# AVANT
function Build-PortableVersion {

# APRÈS  
function New-PortableVersion {
```

#### Build-NSISInstaller → New-NSISInstaller
```powershell
# AVANT
function Build-NSISInstaller {

# APRÈS
function New-NSISInstaller {
```

#### Build-MSIInstaller → New-MSIInstaller
```powershell
# AVANT
function Build-MSIInstaller {

# APRÈS
function New-MSIInstaller {
```

#### Build-InnoSetupInstaller → New-InnoSetupInstaller
```powershell
# AVANT
function Build-InnoSetupInstaller {

# APRÈS
function New-InnoSetupInstaller {
```

#### Clean-BuildArtifacts → Remove-BuildArtifacts
```powershell
# AVANT
function Clean-BuildArtifacts {

# APRÈS
function Remove-BuildArtifacts {
```

## Appels de fonctions mis à jour

```powershell
# Section principale corrigée
try {
    Write-BuildLog "=== DÉBUT DU BUILD INSTALLATEURS v$Version ===" "INFO"
    
    # Nettoyage si demandé
    Remove-BuildArtifacts              # ← Corrigé de Clean-BuildArtifacts
    
    # Vérifications préalables
    if (-not (Test-BuildPrerequisites)) {
        throw "Prérequis non satisfaits"
    }
    
    # Copier la licence si fournie
    Copy-LicenseIfExists
    
    # Build de l'application
    Invoke-ElectronBuild
    
    # Générer les différents installateurs
    New-PortableVersion              # ← Corrigé de Build-PortableVersion
    New-NSISInstaller               # ← Corrigé de Build-NSISInstaller
    New-MSIInstaller                # ← Corrigé de Build-MSIInstaller
    New-InnoSetupInstaller          # ← Corrigé de Build-InnoSetupInstaller
    
    # Résumé final
    Show-BuildSummary
    
    Write-BuildLog "=== BUILD INSTALLATEURS TERMINÉ AVEC SUCCÈS ===" "OK"
    
} catch {
    Write-BuildLog "ERREUR DURANT LE BUILD: $($_.Exception.Message)" "ERROR"
    exit 1
}
```

## Verbes PowerShell approuvés utilisés

| Fonction | Verbe PowerShell | Description |
|----------|------------------|-------------|
| `Write-BuildLog` | Write | Écriture de données |
| `Test-BuildPrerequisites` | Test | Test/vérification |
| `Copy-LicenseIfExists` | Copy | Copie de fichiers |
| `Invoke-ElectronBuild` | Invoke | Exécution/invocation |
| `New-PortableVersion` | New | Création d'objet |
| `New-NSISInstaller` | New | Création d'objet |
| `New-MSIInstaller` | New | Création d'objet |
| `New-InnoSetupInstaller` | New | Création d'objet |
| `Show-BuildSummary` | Show | Affichage d'informations |
| `Remove-BuildArtifacts` | Remove | Suppression d'éléments |

## Gestion avancée des paramètres switch

### Problème résolu
Les switches PowerShell ont un comportement spécial :
- Switch non spécifié = `$false`
- Switch spécifié sans valeur = `$true`  
- Switch spécifié avec `-Switch:$false` = `$false` explicite

### Solution implémentée
```powershell
# Utilisation de $PSBoundParameters pour détecter les switches explicites
$buildSwitchesSpecified = $PSBoundParameters.ContainsKey('Portable') -or 
                         $PSBoundParameters.ContainsKey('NSIS') -or 
                         $PSBoundParameters.ContainsKey('MSI') -or 
                         $PSBoundParameters.ContainsKey('InnoSetup')

# Comportement attendu :
# .\build-installers.ps1                     → Portable, NSIS, MSI = $true
# .\build-installers.ps1 -Portable          → Portable = $true, autres = $false
# .\build-installers.ps1 -Portable:$false   → Portable = $false, autres = $false
```

## Validation finale

### Script de validation créé
- `scripts/validate-build-installers.ps1` - Validation spécifique pour build-installers

### Résultats de validation
- ✅ Aucun switch avec valeur par défaut à `$true`
- ✅ Toutes les fonctions utilisent des verbes approuvés
- ✅ Syntaxe PowerShell valide
- ✅ Logique d'initialisation des switches présente
- ✅ Toutes les fonctions appelées sont définies

## Usage recommandé

### Build par défaut (tous les installateurs)
```powershell
.\scripts\build-installers.ps1
# Génère : Portable, NSIS, MSI
```

### Build sélectif
```powershell
# Portable uniquement
.\scripts\build-installers.ps1 -Portable

# MSI uniquement  
.\scripts\build-installers.ps1 -MSI

# Portable + NSIS
.\scripts\build-installers.ps1 -Portable -NSIS

# Désactiver explicitement
.\scripts\build-installers.ps1 -Portable -NSIS:$false -MSI:$false
```

### Autres options
```powershell
# Avec licence spécifique
.\scripts\build-installers.ps1 -LicensePath "path\to\license.bin"

# Sans rebuild de l'app
.\scripts\build-installers.ps1 -SkipBuild

# Avec nettoyage préalable
.\scripts\build-installers.ps1 -Clean
```

---

**Statut final :** ✅ **SCRIPT ENTIÈREMENT CONFORME** aux bonnes pratiques PowerShell

**Avantages des corrections :**
- Compatibilité avec PSScriptAnalyzer
- Comportement prévisible des paramètres
- Noms de fonctions standards PowerShell
- Facilité de découverte (`Get-Command *-*Installer`)
- Maintenance et extension simplifiées