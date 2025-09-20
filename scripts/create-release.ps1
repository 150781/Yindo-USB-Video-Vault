# Release Automation Script - USB Video Vault
# Version: 1.0.3
# Description: Script automatisé pour générer une release complète et auditable

param(
    [string]$Version = "1.0.3",
    [string]$CertPath = "",
    [string]$CertPassword = "",
    [string]$TimestampUrl = "http://timestamp.digicert.com",
    [switch]$SkipBuild = $false,
    [switch]$SkipSigning = $false,
    [switch]$TestMode = $true
)

$ErrorActionPreference = "Stop"
$releaseDir = "release-v$Version"
$logFile = "release-$Version-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

function Test-Prerequisites {
    Write-Log "=== Vérification des prérequis ===" "INFO"
    
    # Vérifier Node.js
    try {
        $nodeVersion = node --version
        Write-Log "Node.js version: $nodeVersion" "OK"
    } catch {
        Write-Log "Node.js non trouvé!" "ERROR"
        exit 1
    }
    
    # Vérifier npm
    try {
        $npmVersion = npm --version
        Write-Log "npm version: $npmVersion" "OK"
    } catch {
        Write-Log "npm non trouvé!" "ERROR"
        exit 1
    }
    
    # Vérifier CycloneDX
    try {
        cyclonedx-npm --version
        Write-Log "CycloneDX npm disponible" "OK"
    } catch {
        Write-Log "Installation de CycloneDX npm..." "WARN"
        npm install -g @cyclonedx/cyclonedx-npm
    }
    
    # Vérifier Git
    try {
        $gitVersion = git --version
        Write-Log "Git version: $gitVersion" "OK"
    } catch {
        Write-Log "Git non trouvé!" "ERROR"
        exit 1
    }
}

function Update-Version {
    Write-Log "=== Mise à jour de la version ===" "INFO"
    
    # Mise à jour package.json
    $packageJson = Get-Content "package.json" | ConvertFrom-Json
    $packageJson.version = $Version
    $packageJson | ConvertTo-Json -Depth 10 | Set-Content "package.json"
    Write-Log "package.json mis à jour vers $Version" "OK"
    
    # Création du tag Git
    try {
        git tag "v$Version" 2>$null
        Write-Log "Tag Git v$Version créé" "OK"
    } catch {
        Write-Log "Tag v$Version existe déjà ou erreur Git" "WARN"
    }
}

function Build-Application {
    if ($SkipBuild) {
        Write-Log "Construction ignorée (SkipBuild=true)" "WARN"
        return
    }
    
    Write-Log "=== Construction de l'application ===" "INFO"
    
    # Nettoyage
    if (Test-Path "dist") {
        Write-Log "Nettoyage du répertoire dist..." "INFO"
        try {
            Remove-Item -Recurse -Force "dist" -ErrorAction SilentlyContinue
        } catch {
            Write-Log "Impossible de nettoyer dist (fichiers en cours d'utilisation)" "WARN"
        }
    }
    
    # Construction
    Write-Log "npm run build..." "INFO"
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Échec de la construction!" "ERROR"
        exit 1
    }
    
    Write-Log "npm run dist:win..." "INFO"
    npm run dist:win
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Échec de la distribution!" "ERROR"
        exit 1
    }
    
    Write-Log "Construction terminée avec succès" "OK"
}

function Generate-SBOM {
    Write-Log "=== Génération du SBOM ===" "INFO"
    
    $sbomFile = "sbom-v$Version.json"
    cyclonedx-npm --output-format json --output-file $sbomFile
    
    if (Test-Path $sbomFile) {
        $sbomSize = (Get-Item $sbomFile).Length
        Write-Log "SBOM généré: $sbomFile ($sbomSize bytes)" "OK"
    } else {
        Write-Log "Échec de génération du SBOM!" "ERROR"
        exit 1
    }
}

function Calculate-Hashes {
    Write-Log "=== Calcul des empreintes SHA256 ===" "INFO"
    
    $hashFile = "SHA256-HASHES-v$Version.txt"
    $executables = @()
    
    # Chercher les exécutables
    if (Test-Path "dist\win-unpacked\USB Video Vault.exe") {
        $executables += "dist\win-unpacked\USB Video Vault.exe"
    }
    
    $portableExes = Get-ChildItem -Recurse -Filter "*portable*.exe" | Where-Object { $_.Directory.Name -match "dist|usb|package" }
    foreach ($exe in $portableExes) {
        $executables += $exe.FullName
    }
    
    # Calculer les hashes
    $hashResults = @()
    foreach ($exe in $executables) {
        if (Test-Path $exe) {
            Write-Log "Calcul hash pour: $exe" "INFO"
            $hash = (CertUtil -hashfile $exe SHA256 | Select-String "^\w{64}$").Matches[0].Value
            $size = (Get-Item $exe).Length
            $hashResults += [PSCustomObject]@{
                File = $exe
                Size = $size
                SHA256 = $hash
            }
            Write-Log "Hash calculé: $($hash.Substring(0,16))..." "OK"
        }
    }
    
    # Sauvegarder les résultats
    $hashResults | ConvertTo-Json -Depth 3 | Set-Content $hashFile
    Write-Log "Hashes sauvegardés dans: $hashFile" "OK"
    
    return $hashResults
}

function Sign-Executables {
    param([array]$Executables)
    
    if ($SkipSigning) {
        Write-Log "Signature ignorée (SkipSigning=true)" "WARN"
        return
    }
    
    Write-Log "=== Signature des exécutables ===" "INFO"
    
    # Mode test : certificat auto-signé
    if ($TestMode -or [string]::IsNullOrEmpty($CertPath)) {
        Write-Log "Mode test : utilisation du certificat auto-signé" "WARN"
        
        # Vérifier/créer certificat test
        $testCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {$_.Subject -like "*Yindo*"} | Select-Object -First 1
        
        if (-not $testCert) {
            Write-Log "Création du certificat de test..." "INFO"
            $testCert = New-SelfSignedCertificate -DnsName "Yindo USB Video Vault" -Subject "CN=Yindo USB Video Vault Test Certificate" -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage DigitalSignature -Type CodeSigningCert
        }
        
        # Signer avec certificat test
        foreach ($exe in $Executables) {
            if (Test-Path $exe.File) {
                try {
                    Write-Log "Signature de test: $($exe.File)" "INFO"
                    $signature = Set-AuthenticodeSignature -FilePath $exe.File -Certificate $testCert
                    Write-Log "Signature appliquée (Status: $($signature.Status))" "OK"
                } catch {
                    Write-Log "Impossible de signer $($exe.File): $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
    # Mode production : certificat commercial
    else {
        Write-Log "Mode production : utilisation du certificat commercial" "INFO"
        
        if (-not (Test-Path $CertPath)) {
            Write-Log "Certificat non trouvé: $CertPath" "ERROR"
            exit 1
        }
        
        $cert = Get-PfxCertificate -FilePath $CertPath
        
        foreach ($exe in $Executables) {
            if (Test-Path $exe.File) {
                Write-Log "Signature production: $($exe.File)" "INFO"
                $signature = Set-AuthenticodeSignature -FilePath $exe.File -Certificate $cert -TimestampServer $TimestampUrl
                
                if ($signature.Status -eq "Valid") {
                    Write-Log "Signature réussie pour $($exe.File)" "OK"
                } else {
                    Write-Log "Échec signature pour $($exe.File): $($signature.StatusMessage)" "ERROR"
                }
            }
        }
    }
}

function Create-ReleasePackage {
    param([array]$Executables)
    
    Write-Log "=== Création du package de release ===" "INFO"
    
    # Créer le répertoire de release
    if (Test-Path $releaseDir) {
        Remove-Item -Recurse -Force $releaseDir
    }
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
    
    # Copier les fichiers essentiels
    $filesToCopy = @(
        "CHANGELOG.md",
        "SHA256-HASHES-v$Version.txt",
        "sbom-v$Version.json",
        "SIGNATURE-STATUS-v$Version.md",
        "README.md",
        "package.json"
    )
    
    foreach ($file in $filesToCopy) {
        if (Test-Path $file) {
            Copy-Item $file "$releaseDir\" -Force
            Write-Log "Copié: $file" "OK"
        }
    }
    
    # Copier les exécutables
    $exeDir = "$releaseDir\executables"
    New-Item -ItemType Directory -Path $exeDir | Out-Null
    
    foreach ($exe in $Executables) {
        if (Test-Path $exe.File) {
            $fileName = Split-Path $exe.File -Leaf
            Copy-Item $exe.File "$exeDir\$fileName" -Force
            Write-Log "Copié exécutable: $fileName" "OK"
        }
    }
    
    # Copier la documentation
    $docsDir = "$releaseDir\docs"
    if (Test-Path "docs") {
        Copy-Item "docs" $docsDir -Recurse -Force
        Write-Log "Documentation copiée" "OK"
    }
    
    # Créer l'archive de release
    $archiveName = "USB-Video-Vault-v$Version-release.zip"
    if (Test-Path $archiveName) {
        Remove-Item $archiveName -Force
    }
    
    Compress-Archive -Path "$releaseDir\*" -DestinationPath $archiveName
    $archiveSize = (Get-Item $archiveName).Length
    Write-Log "Archive créée: $archiveName ($archiveSize bytes)" "OK"
    
    return $archiveName
}

function Generate-ReleaseReport {
    param([array]$Executables, [string]$Archive)
    
    Write-Log "=== Génération du rapport de release ===" "INFO"
    
    $reportFile = "RELEASE-REPORT-v$Version.md"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $report = @"
# Release Report - USB Video Vault v$Version

**Date de génération** : $timestamp  
**Environnement** : $env:COMPUTERNAME  
**Utilisateur** : $env:USERNAME  

## Fichiers de release

### Archive principale
- **Fichier** : $Archive
- **Taille** : $((Get-Item $Archive).Length) bytes
- **SHA256** : $((CertUtil -hashfile $Archive SHA256 | Select-String "^\w{64}$").Matches[0].Value)

### Exécutables inclus
"@

    foreach ($exe in $Executables) {
        $report += @"

- **$($exe.File)**
  - Taille : $($exe.Size) bytes
  - SHA256 : $($exe.SHA256)
"@
    }

    $report += @"

## Artefacts de release

- [ ] CHANGELOG.md - Journal des modifications
- [ ] SBOM (sbom-v$Version.json) - Bill of Materials CycloneDX
- [ ] Hashes SHA256 - Empreintes de vérification
- [ ] Documentation signatures - État de la signature de code
- [ ] Archive complète - Package de distribution

## Validation post-release

### Commandes de vérification

``````powershell
# Vérifier l'intégrité de l'archive
CertUtil -hashfile $Archive SHA256

# Extraire et vérifier les exécutables
Expand-Archive $Archive -DestinationPath temp-verification
Get-ChildItem temp-verification\executables\*.exe | ForEach-Object {
    Write-Host "Vérification: `$($_.Name)"
    CertUtil -hashfile `$_.FullName SHA256
    Get-AuthenticodeSignature `$_.FullName
}
``````

### Checklist de déploiement

- [ ] Archive téléchargée et vérifiée
- [ ] Hashes SHA256 validés
- [ ] Signatures Authenticode vérifiées
- [ ] SBOM analysé pour audit sécurité
- [ ] Documentation opérationnelle consultée
- [ ] Tests d'installation effectués

## Métadonnées

- **Tag Git** : v$Version
- **Commit** : $(git rev-parse HEAD)
- **Branch** : $(git branch --show-current)
- **Build timestamp** : $timestamp

---

*Ce rapport a été généré automatiquement par le script de release.*
"@

    Set-Content -Path $reportFile -Value $report
    Write-Log "Rapport de release généré: $reportFile" "OK"
}

# === EXÉCUTION PRINCIPALE ===

try {
    Write-Log "=== DÉBUT DE LA RELEASE v$Version ===" "INFO"
    
    Test-Prerequisites
    Update-Version
    Build-Application
    Generate-SBOM
    $executables = Calculate-Hashes
    Sign-Executables -Executables $executables
    $archive = Create-ReleasePackage -Executables $executables
    Generate-ReleaseReport -Executables $executables -Archive $archive
    
    Write-Log "=== RELEASE v$Version TERMINÉE AVEC SUCCÈS ===" "OK"
    Write-Log "Archive de release: $archive" "INFO"
    Write-Log "Log complet: $logFile" "INFO"
    
} catch {
    Write-Log "ERREUR DURANT LA RELEASE: $($_.Exception.Message)" "ERROR"
    Write-Log "Log complet: $logFile" "INFO"
    exit 1
}