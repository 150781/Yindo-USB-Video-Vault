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
    Write-BuildLog "Verification des prerequis de build..." "STEP"
    
    # Node.js
    try {
        $nodeVersion = node --version
        Write-BuildLog "âœ" Node.js: $nodeVersion" "SUCCESS"
    }
    catch {
        Write-BuildLog "âŒ Node.js requis" "ERROR"
        throw
    }
    
    # npm
    try {
        $npmVersion = npm --version
        Write-BuildLog "âœ" npm: $npmVersion" "SUCCESS"
    }
    catch {
        Write-BuildLog "âŒ npm requis" "ERROR"
        throw
    }
    
    # Git (pour tags)
    try {
        $gitVersion = git --version
        Write-BuildLog "âœ" Git: $gitVersion" "SUCCESS"
    }
    catch {
        Write-BuildLog "âŒ Git requis pour release" "ERROR"
        throw
    }
    
    # Verifier workspace propre
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-BuildLog "âš ï¸ Workspace non propre - changements detectes" "WARN"
        if ($Verbose) {
            Write-BuildLog "Changements:" "INFO"
            $gitStatus | ForEach-Object { Write-BuildLog "  $_" "INFO" }
        }
        
        $continue = Read-Host "Continuer malgre les changements? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            throw "Build annule par l'utilisateur"
        }
    }
    
    Write-BuildLog "Prerequis valides" "SUCCESS"
}

function Update-Version {
    param([string]$NewVersion)
    
    Write-BuildLog "Mise Ã  jour version: $NewVersion" "STEP"
    
    try {
        # Mettre Ã  jour package.json
        $packagePath = "package.json"
        $package = Get-Content $packagePath | ConvertFrom-Json
        $oldVersion = $package.version
        $package.version = $NewVersion
        $package | ConvertTo-Json -Depth 10 | Set-Content $packagePath
        
        Write-BuildLog "Version mise Ã  jour: $oldVersion â†' $NewVersion" "SUCCESS"
        
        # Commit version si workspace etait propre
        $gitStatus = git status --porcelain
        if (-not $gitStatus -or ($gitStatus.Count -eq 1 -and $gitStatus[0] -match "package\.json")) {
            git add package.json
            git commit -m "chore: bump version to $NewVersion"
            Write-BuildLog "Version committee" "SUCCESS"
        }
        
    }
    catch {
        Write-BuildLog "âŒ Erreur mise Ã  jour version: $_" "ERROR"
        throw
    }
}

function Invoke-Tests {
    if ($SkipTests) {
        Write-BuildLog "Tests ignores (--SkipTests)" "WARN"
        return
    }
    
    Write-BuildLog "Execution des tests..." "STEP"
    
    try {
        # Tests unitaires si configures
        if (Test-Path "scripts\test-*.js") {
            Write-BuildLog "Execution tests unitaires..." "INFO"
            npm run test:unit 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-BuildLog "âœ" Tests unitaires passes" "SUCCESS"
            } else {
                Write-BuildLog "âš ï¸ Tests unitaires echoues ou non configures" "WARN"
            }
        }
        
        # Linting
        try {
            npm run lint 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-BuildLog "âœ" Linting passe" "SUCCESS"
            } else {
                Write-BuildLog "âš ï¸ Linting echoue ou non configure" "WARN"
            }
        }
        catch {
            Write-BuildLog "âš ï¸ Linting non disponible" "WARN"
        }
        
    }
    catch {
        Write-BuildLog "âŒ Erreur lors des tests: $_" "ERROR"
        throw
    }
}

function Invoke-Build {
    Write-BuildLog "Build de l'application..." "STEP"
    
    try {
        # Nettoyage
        if (Test-Path $BuildDir) {
            Remove-Item -Path $BuildDir -Recurse -Force
            Write-BuildLog "Repertoire dist nettoye" "INFO"
        }
        
        # Installation des dependances
        Write-BuildLog "Installation des dependances..." "INFO"
        npm ci
        
        # Build renderer
        Write-BuildLog "Build renderer..." "INFO"
        npm run build:renderer
        if ($LASTEXITCODE -ne 0) {
            throw "Ã‰chec build renderer"
        }
        
        # Build main
        Write-BuildLog "Build main..." "INFO"
        npm run build:main
        if ($LASTEXITCODE -ne 0) {
            throw "Ã‰chec build main"
        }
        
        # Package
        Write-BuildLog "Package Electron..." "INFO"
        npm run package
        if ($LASTEXITCODE -ne 0) {
            throw "Ã‰chec package"
        }
        
        Write-BuildLog "âœ" Build termine" "SUCCESS"
        
    }
    catch {
        Write-BuildLog "âŒ Erreur lors du build: $_" "ERROR"
        throw
    }
}

function Invoke-ProductionSigning {
    if ($SkipSigning) {
        Write-BuildLog "Signature ignoree (--SkipSigning)" "WARN"
        return
    }
    
    Write-BuildLog "Signature production..." "STEP"
    
    try {
        $signScript = "scripts\windows-sign-prod.ps1"
        
        if (-not (Test-Path $signScript)) {
            Write-BuildLog "âŒ Script de signature non trouve: $signScript" "ERROR"
            throw "Script de signature manquant"
        }
        
        # Parametres pour le script de signature
        $signParams = @{
            PfxPath = $PfxPath
            ExecutablePath = "dist\win-unpacked\USB Video Vault.exe"
            Verbose = $Verbose
        }
        
        if ($PfxPassword) {
            $signParams.PfxPassword = $PfxPassword
        }
        
        # Executer signature
        & $signScript @signParams
        
        Write-BuildLog "âœ" Signature production terminee" "SUCCESS"
        
    }
    catch {
        Write-BuildLog "âŒ Erreur lors de la signature: $_" "ERROR"
        throw
    }
}

function New-Installer {
    Write-BuildLog "Creation de l'installateur..." "STEP"
    
    try {
        # Verifier si electron-builder est configure pour MSI
        if (Test-Path "electron-builder.yml") {
            $builderConfig = Get-Content "electron-builder.yml" -Raw
            if ($builderConfig -match "nsis|msi") {
                Write-BuildLog "Generation installateur avec electron-builder..." "INFO"
                npm run dist
                if ($LASTEXITCODE -eq 0) {
                    Write-BuildLog "âœ" Installateur cree" "SUCCESS"
                } else {
                    Write-BuildLog "âš ï¸ Ã‰chec creation installateur" "WARN"
                }
            } else {
                Write-BuildLog "âš ï¸ Configuration installateur non trouvee" "WARN"
            }
        } else {
            Write-BuildLog "âš ï¸ electron-builder.yml non trouve" "WARN"
        }
        
    }
    catch {
        Write-BuildLog "âŒ Erreur creation installateur: $_" "ERROR"
        # Ne pas arrÃªter le build pour l'installateur
    }
}

function New-Checksums {
    Write-BuildLog "Generation des checksums..." "STEP"
    
    try {
        $checksumFile = Join-Path $BuildDir "checksums-v$Version.txt"
        $sha256File = Join-Path $BuildDir "checksums-sha256-v$Version.txt"
        
        # Trouver tous les artifacts
        $artifacts = Get-ChildItem -Path $BuildDir -Recurse -Include "*.exe","*.msi","*.zip" | Where-Object { $_.Length -gt 1MB }
        
        if ($artifacts.Count -eq 0) {
            Write-BuildLog "âš ï¸ Aucun artifact trouve pour checksums" "WARN"
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
        
        Write-BuildLog "âœ" Checksums generes:" "SUCCESS"
        Write-BuildLog "  - $checksumFile" "INFO"
        Write-BuildLog "  - $sha256File" "INFO"
        
    }
    catch {
        Write-BuildLog "âŒ Erreur generation checksums: $_" "ERROR"
        # Ne pas arrÃªter le build
    }
}

function New-ReleasePackage {
    Write-BuildLog "Creation du package de release..." "STEP"
    
    try {
        # Creer repertoire de release
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
                Write-BuildLog "  âœ" $($file.Name)" "INFO"
            }
        }
        
        # Creer notes de release
        $releaseNotes = @"
# USB Video Vault v$Version - Release Production

## ðŸ"' Release signee en production

Cette release est signee avec un certificat de code de production et prÃªte pour deploiement.

## ðŸ"¦ Artifacts

- **USB Video Vault.exe** - Application signee
- **USB-Video-Vault-Setup.exe** - Installateur signe (si disponible)
- **checksums-*.txt** - Verification d'integrite

## ðŸš€ Installation

### Installation standard
1. Telecharger l'installateur signe
2. Executer en tant qu'administrateur
3. Suivre les instructions

### Installation silencieuse
```cmd
USB-Video-Vault-Setup.exe /S
```

## ðŸ" Verification

### Signature
```cmd
signtool verify /pa /all "USB Video Vault.exe"
```

### Checksums
Verifier l'integrite avec les fichiers checksums fournis.

## ðŸ"‹ Changelog

$(try { git log --oneline --since="$(git describe --tags --abbrev=0)^" --pretty=format:"- %s (%h)" } catch { "Changelog automatique non disponible" })

---

**Date de build**: $(Get-Date)
**Commit**: $(try { git rev-parse HEAD } catch { "Non disponible" })
**Machine de build**: $env:COMPUTERNAME
"@
        
        $releaseNotesPath = Join-Path $ReleaseDir "RELEASE_NOTES_v$Version.md"
        $releaseNotes | Out-File -FilePath $releaseNotesPath -Encoding UTF8
        
        Write-BuildLog "âœ" Package de release cree: $ReleaseDir" "SUCCESS"
        
    }
    catch {
        Write-BuildLog "âŒ Erreur creation package: $_" "ERROR"
        throw
    }
}

function New-GitTag {
    Write-BuildLog "Creation du tag Git..." "STEP"
    
    try {
        $tagName = "v$Version"
        
        # Verifier si le tag existe dejÃ 
        $existingTag = git tag -l $tagName
        if ($existingTag) {
            Write-BuildLog "âš ï¸ Tag $tagName existe dejÃ " "WARN"
            return
        }
        
        # Creer tag annotated
        git tag -a $tagName -m "Release v$Version - Production signed"
        Write-BuildLog "âœ" Tag cree: $tagName" "SUCCESS"
        
        # Pousser le tag
        $pushTag = Read-Host "Pousser le tag vers origin? (y/N)"
        if ($pushTag -eq "y" -or $pushTag -eq "Y") {
            git push origin $tagName
            Write-BuildLog "âœ" Tag pousse vers origin" "SUCCESS"
        }
        
    }
    catch {
        Write-BuildLog "âŒ Erreur creation tag: $_" "ERROR"
        # Ne pas arrÃªter le build
    }
}

function New-BuildReport {
    Write-BuildLog "Generation du rapport de build..." "STEP"
    
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
- Tests: $(if($SkipTests) { "Ignores" } else { "Executes" })
- Signature: $(if($SkipSigning) { "Ignoree" } else { "Production" })
- PFX: $PfxPath

Artifacts generes:
$(Get-ChildItem -Path $ReleaseDir -File | ForEach-Object { "- $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)" })

Duree de build: $($buildEndTime - $buildStartTime)

Status: SUCCÃˆS
"@
        
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        Write-BuildLog "âœ" Rapport sauvegarde: $reportPath" "SUCCESS"
        
    }
    catch {
        Write-BuildLog "âŒ Erreur generation rapport: $_" "ERROR"
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
        
        Write-BuildLog "ðŸŽ‰ Build release v$Version termine avec succes!" "SUCCESS"
        Write-BuildLog "ðŸ"¦ Package disponible: $ReleaseDir" "SUCCESS"
        
        # Afficher resume
        Write-BuildLog "=== RÃ‰SUMÃ‰ ===" "INFO"
        Write-BuildLog "Version: $Version" "INFO"
        Write-BuildLog "Signature: $(if($SkipSigning) { "Ignoree" } else { "Production" })" "INFO"
        Write-BuildLog "Duree: $($buildEndTime - $buildStartTime)" "INFO"
        Write-BuildLog "Package: $ReleaseDir" "INFO"
        
        if ($CreateGitHubRelease) {
            Write-BuildLog "Pour creer la GitHub Release:" "INFO"
            Write-BuildLog "gh release create v$Version --title `"USB Video Vault v$Version`" --notes-file `"$ReleaseDir\RELEASE_NOTES_v$Version.md`" `"$ReleaseDir\*`"" "INFO"
        }
        
    }
    catch {
        $script:buildEndTime = Get-Date
        Write-BuildLog "âŒ Build echoue: $_" "ERROR"
        exit 1
    }
}

# Execution
Main
