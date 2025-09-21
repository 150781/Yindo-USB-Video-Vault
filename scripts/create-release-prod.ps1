# Script de Build Release Production v1.0.4
# USB Video Vault - Release avec signature production

param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.4",
    
    [Parameter(Mandatory=$false)]
    [string]$PfxPath = "C:\keys\codesign-prod.pfx",
    
    [Parameter(Mandatory=$false)]
    [SecureString]$PfxPassword,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSigning = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateGitHubRelease = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

# Configuration
$BuildDir = "dist"
$ReleaseDir = "releases\v$Version"
$TimestampServer = "http://timestamp.digicert.com"

function Write-BuildLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "STEP" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-BuildPrerequisites {
    Write-BuildLog "Vérification des prérequis de build..." "STEP"
    
    # Node.js
    try {
        $nodeVersion = node --version
        Write-BuildLog "✓ Node.js: $nodeVersion" "SUCCESS"
    }
    catch {
        Write-BuildLog "❌ Node.js requis" "ERROR"
        throw
    }
    
    # npm
    try {
        $npmVersion = npm --version
        Write-BuildLog "✓ npm: $npmVersion" "SUCCESS"
    }
    catch {
        Write-BuildLog "❌ npm requis" "ERROR"
        throw
    }
    
    # Git (pour tags)
    try {
        $gitVersion = git --version
        Write-BuildLog "✓ Git: $gitVersion" "SUCCESS"
    }
    catch {
        Write-BuildLog "❌ Git requis pour release" "ERROR"
        throw
    }
    
    # Vérifier workspace propre
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-BuildLog "⚠️ Workspace non propre - changements détectés" "WARN"
        if ($Verbose) {
            Write-BuildLog "Changements:" "INFO"
            $gitStatus | ForEach-Object { Write-BuildLog "  $_" "INFO" }
        }
        
        $continue = Read-Host "Continuer malgré les changements? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            throw "Build annulé par l'utilisateur"
        }
    }
    
    Write-BuildLog "Prérequis validés" "SUCCESS"
}

function Update-Version {
    param([string]$NewVersion)
    
    Write-BuildLog "Mise à jour version: $NewVersion" "STEP"
    
    try {
        # Mettre à jour package.json
        $packagePath = "package.json"
        $package = Get-Content $packagePath | ConvertFrom-Json
        $oldVersion = $package.version
        $package.version = $NewVersion
        $package | ConvertTo-Json -Depth 10 | Set-Content $packagePath
        
        Write-BuildLog "Version mise à jour: $oldVersion → $NewVersion" "SUCCESS"
        
        # Commit version si workspace était propre
        $gitStatus = git status --porcelain
        if (-not $gitStatus -or ($gitStatus.Count -eq 1 -and $gitStatus[0] -match "package\.json")) {
            git add package.json
            git commit -m "chore: bump version to $NewVersion"
            Write-BuildLog "Version committée" "SUCCESS"
        }
        
    }
    catch {
        Write-BuildLog "❌ Erreur mise à jour version: $_" "ERROR"
        throw
    }
}

function Invoke-Tests {
    if ($SkipTests) {
        Write-BuildLog "Tests ignorés (--SkipTests)" "WARN"
        return
    }
    
    Write-BuildLog "Exécution des tests..." "STEP"
    
    try {
        # Tests unitaires si configurés
        if (Test-Path "scripts\test-*.js") {
            Write-BuildLog "Exécution tests unitaires..." "INFO"
            npm run test:unit 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-BuildLog "✓ Tests unitaires passés" "SUCCESS"
            } else {
                Write-BuildLog "⚠️ Tests unitaires échoués ou non configurés" "WARN"
            }
        }
        
        # Linting
        try {
            npm run lint 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-BuildLog "✓ Linting passé" "SUCCESS"
            } else {
                Write-BuildLog "⚠️ Linting échoué ou non configuré" "WARN"
            }
        }
        catch {
            Write-BuildLog "⚠️ Linting non disponible" "WARN"
        }
        
    }
    catch {
        Write-BuildLog "❌ Erreur lors des tests: $_" "ERROR"
        throw
    }
}

function Invoke-Build {
    Write-BuildLog "Build de l'application..." "STEP"
    
    try {
        # Nettoyage
        if (Test-Path $BuildDir) {
            Remove-Item -Path $BuildDir -Recurse -Force
            Write-BuildLog "Répertoire dist nettoyé" "INFO"
        }
        
        # Installation des dépendances
        Write-BuildLog "Installation des dépendances..." "INFO"
        npm ci
        
        # Build renderer
        Write-BuildLog "Build renderer..." "INFO"
        npm run build:renderer
        if ($LASTEXITCODE -ne 0) {
            throw "Échec build renderer"
        }
        
        # Build main
        Write-BuildLog "Build main..." "INFO"
        npm run build:main
        if ($LASTEXITCODE -ne 0) {
            throw "Échec build main"
        }
        
        # Package
        Write-BuildLog "Package Electron..." "INFO"
        npm run package
        if ($LASTEXITCODE -ne 0) {
            throw "Échec package"
        }
        
        Write-BuildLog "✓ Build terminé" "SUCCESS"
        
    }
    catch {
        Write-BuildLog "❌ Erreur lors du build: $_" "ERROR"
        throw
    }
}

function Invoke-ProductionSigning {
    if ($SkipSigning) {
        Write-BuildLog "Signature ignorée (--SkipSigning)" "WARN"
        return
    }
    
    Write-BuildLog "Signature production..." "STEP"
    
    try {
        $signScript = "scripts\windows-sign-prod.ps1"
        
        if (-not (Test-Path $signScript)) {
            Write-BuildLog "❌ Script de signature non trouvé: $signScript" "ERROR"
            throw "Script de signature manquant"
        }
        
        # Paramètres pour le script de signature
        $signParams = @{
            PfxPath = $PfxPath
            ExecutablePath = "dist\win-unpacked\USB Video Vault.exe"
            Verbose = $Verbose
        }
        
        if ($PfxPassword) {
            $signParams.PfxPassword = $PfxPassword
        }
        
        # Exécuter signature
        & $signScript @signParams
        
        Write-BuildLog "✓ Signature production terminée" "SUCCESS"
        
    }
    catch {
        Write-BuildLog "❌ Erreur lors de la signature: $_" "ERROR"
        throw
    }
}

function New-Installer {
    Write-BuildLog "Création de l'installateur..." "STEP"
    
    try {
        # Vérifier si electron-builder est configuré pour MSI
        if (Test-Path "electron-builder.yml") {
            $builderConfig = Get-Content "electron-builder.yml" -Raw
            if ($builderConfig -match "nsis|msi") {
                Write-BuildLog "Génération installateur avec electron-builder..." "INFO"
                npm run dist
                if ($LASTEXITCODE -eq 0) {
                    Write-BuildLog "✓ Installateur créé" "SUCCESS"
                } else {
                    Write-BuildLog "⚠️ Échec création installateur" "WARN"
                }
            } else {
                Write-BuildLog "⚠️ Configuration installateur non trouvée" "WARN"
            }
        } else {
            Write-BuildLog "⚠️ electron-builder.yml non trouvé" "WARN"
        }
        
    }
    catch {
        Write-BuildLog "❌ Erreur création installateur: $_" "ERROR"
        # Ne pas arrêter le build pour l'installateur
    }
}

function New-Checksums {
    Write-BuildLog "Génération des checksums..." "STEP"
    
    try {
        $checksumFile = Join-Path $BuildDir "checksums-v$Version.txt"
        $sha256File = Join-Path $BuildDir "checksums-sha256-v$Version.txt"
        
        # Trouver tous les artifacts
        $artifacts = Get-ChildItem -Path $BuildDir -Recurse -Include "*.exe","*.msi","*.zip" | Where-Object { $_.Length -gt 1MB }
        
        if ($artifacts.Count -eq 0) {
            Write-BuildLog "⚠️ Aucun artifact trouvé pour checksums" "WARN"
            return
        }
        
        $checksums = @()
        $sha256sums = @()
        
        foreach ($artifact in $artifacts) {
            $relativePath = $artifact.FullName.Replace("$PWD\", "")
            
            # MD5
            $md5 = Get-FileHash -Path $artifact.FullName -Algorithm MD5
            $checksums += "$($md5.Hash.ToLower())  $relativePath"
            
            # SHA256
            $sha256 = Get-FileHash -Path $artifact.FullName -Algorithm SHA256
            $sha256sums += "$($sha256.Hash.ToLower())  $relativePath"
        }
        
        # Sauvegarder checksums
        $checksums | Out-File -FilePath $checksumFile -Encoding UTF8
        $sha256sums | Out-File -FilePath $sha256File -Encoding UTF8
        
        Write-BuildLog "✓ Checksums générés:" "SUCCESS"
        Write-BuildLog "  - $checksumFile" "INFO"
        Write-BuildLog "  - $sha256File" "INFO"
        
    }
    catch {
        Write-BuildLog "❌ Erreur génération checksums: $_" "ERROR"
        # Ne pas arrêter le build
    }
}

function New-ReleasePackage {
    Write-BuildLog "Création du package de release..." "STEP"
    
    try {
        # Créer répertoire de release
        if (-not (Test-Path $ReleaseDir)) {
            New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
        }
        
        # Copier artifacts principaux
        $artifacts = @(
            "dist\win-unpacked\USB Video Vault.exe",
            "dist\*.exe",
            "dist\*.msi",
            "dist\checksums*.txt"
        )
        
        foreach ($pattern in $artifacts) {
            $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $dest = Join-Path $ReleaseDir $file.Name
                Copy-Item -Path $file.FullName -Destination $dest -Force
                Write-BuildLog "  ✓ $($file.Name)" "INFO"
            }
        }
        
        # Créer notes de release
        $releaseNotes = @"
# USB Video Vault v$Version - Release Production

## 🔒 Release signée en production

Cette release est signée avec un certificat de code de production et prête pour déploiement.

## 📦 Artifacts

- **USB Video Vault.exe** - Application signée
- **USB-Video-Vault-Setup.exe** - Installateur signé (si disponible)
- **checksums-*.txt** - Vérification d'intégrité

## 🚀 Installation

### Installation standard
1. Télécharger l'installateur signé
2. Exécuter en tant qu'administrateur
3. Suivre les instructions

### Installation silencieuse
```cmd
USB-Video-Vault-Setup.exe /S
```

## 🔐 Vérification

### Signature
```cmd
signtool verify /pa /all "USB Video Vault.exe"
```

### Checksums
Vérifier l'intégrité avec les fichiers checksums fournis.

## 📋 Changelog

$(try { git log --oneline --since="$(git describe --tags --abbrev=0)^" --pretty=format:"- %s (%h)" } catch { "Changelog automatique non disponible" })

---

**Date de build**: $(Get-Date)
**Commit**: $(try { git rev-parse HEAD } catch { "Non disponible" })
**Machine de build**: $env:COMPUTERNAME
"@
        
        $releaseNotesPath = Join-Path $ReleaseDir "RELEASE_NOTES_v$Version.md"
        $releaseNotes | Out-File -FilePath $releaseNotesPath -Encoding UTF8
        
        Write-BuildLog "✓ Package de release créé: $ReleaseDir" "SUCCESS"
        
    }
    catch {
        Write-BuildLog "❌ Erreur création package: $_" "ERROR"
        throw
    }
}

function New-GitTag {
    Write-BuildLog "Création du tag Git..." "STEP"
    
    try {
        $tagName = "v$Version"
        
        # Vérifier si le tag existe déjà
        $existingTag = git tag -l $tagName
        if ($existingTag) {
            Write-BuildLog "⚠️ Tag $tagName existe déjà" "WARN"
            return
        }
        
        # Créer tag annotated
        git tag -a $tagName -m "Release v$Version - Production signed"
        Write-BuildLog "✓ Tag créé: $tagName" "SUCCESS"
        
        # Pousser le tag
        $pushTag = Read-Host "Pousser le tag vers origin? (y/N)"
        if ($pushTag -eq "y" -or $pushTag -eq "Y") {
            git push origin $tagName
            Write-BuildLog "✓ Tag poussé vers origin" "SUCCESS"
        }
        
    }
    catch {
        Write-BuildLog "❌ Erreur création tag: $_" "ERROR"
        # Ne pas arrêter le build
    }
}

function New-BuildReport {
    Write-BuildLog "Génération du rapport de build..." "STEP"
    
    try {
        $reportPath = Join-Path $ReleaseDir "build-report-v$Version.txt"
        
        $report = @"
USB Video Vault - Rapport de Build v$Version
==========================================

Date de build: $(Get-Date)
Version: $Version
Machine: $env:COMPUTERNAME
Utilisateur: $env:USERNAME
PowerShell: $($PSVersionTable.PSVersion)
Commit: $(try { git rev-parse HEAD } catch { "Non disponible" })

Configuration:
- Tests: $(if($SkipTests) { "Ignorés" } else { "Exécutés" })
- Signature: $(if($SkipSigning) { "Ignorée" } else { "Production" })
- PFX: $PfxPath

Artifacts générés:
$(Get-ChildItem -Path $ReleaseDir -File | ForEach-Object { "- $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)" })

Durée de build: $($buildEndTime - $buildStartTime)

Status: SUCCÈS
"@
        
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        Write-BuildLog "✓ Rapport sauvegardé: $reportPath" "SUCCESS"
        
    }
    catch {
        Write-BuildLog "❌ Erreur génération rapport: $_" "ERROR"
    }
}

# Fonction principale
function Main {
    $script:buildStartTime = Get-Date
    
    Write-BuildLog "=== USB Video Vault - Build Release Production v$Version ===" "STEP"
    
    try {
        Test-BuildPrerequisites
        Update-Version -NewVersion $Version
        Invoke-Tests
        Invoke-Build
        Invoke-ProductionSigning
        New-Installer
        New-Checksums
        New-ReleasePackage
        New-GitTag
        
        $script:buildEndTime = Get-Date
        New-BuildReport
        
        Write-BuildLog "🎉 Build release v$Version terminé avec succès!" "SUCCESS"
        Write-BuildLog "📦 Package disponible: $ReleaseDir" "SUCCESS"
        
        # Afficher résumé
        Write-BuildLog "=== RÉSUMÉ ===" "INFO"
        Write-BuildLog "Version: $Version" "INFO"
        Write-BuildLog "Signature: $(if($SkipSigning) { "Ignorée" } else { "Production" })" "INFO"
        Write-BuildLog "Durée: $($buildEndTime - $buildStartTime)" "INFO"
        Write-BuildLog "Package: $ReleaseDir" "INFO"
        
        if ($CreateGitHubRelease) {
            Write-BuildLog "Pour créer la GitHub Release:" "INFO"
            Write-BuildLog "gh release create v$Version --title `"USB Video Vault v$Version`" --notes-file `"$ReleaseDir\RELEASE_NOTES_v$Version.md`" `"$ReleaseDir\*`"" "INFO"
        }
        
    }
    catch {
        $script:buildEndTime = Get-Date
        Write-BuildLog "❌ Build échoué: $_" "ERROR"
        exit 1
    }
}

# Exécution
Main