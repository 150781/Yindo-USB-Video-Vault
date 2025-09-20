# Script de build pour tous les installateurs USB Video Vault
# Génère: Portable, NSIS, MSI, et Inno Setup

param(
    [string]$Version = "1.0.3",
    [switch]$SkipBuild = $false,
    [switch]$Portable = $true,
    [switch]$NSIS = $true,
    [switch]$MSI = $true,
    [switch]$InnoSetup = $false,
    [string]$LicensePath = "",
    [switch]$Clean = $false
)

function Write-BuildLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        "ERROR" { "[ERROR]" }
        "WARN"  { "[WARN]" }
        "OK"    { "[OK]" }
        default { "[INFO]" }
    }
    Write-Host "[$timestamp] $prefix $Message"
}

function Test-BuildPrerequisites {
    Write-BuildLog "=== Vérification des prérequis ===" "INFO"
    
    # Vérifier Node.js et npm
    try {
        $nodeVersion = node --version
        Write-BuildLog "Node.js: $nodeVersion" "OK"
    } catch {
        Write-BuildLog "Node.js requis mais non trouvé!" "ERROR"
        return $false
    }
    
    # Vérifier electron-builder
    try {
        npx electron-builder --version | Out-Null
        Write-BuildLog "electron-builder disponible" "OK"
    } catch {
        Write-BuildLog "electron-builder requis mais non trouvé!" "ERROR"
        return $false
    }
    
    # Vérifier Inno Setup si demandé
    if ($InnoSetup) {
        $innoPath = Get-Command "iscc.exe" -ErrorAction SilentlyContinue
        if ($innoPath) {
            Write-BuildLog "Inno Setup: $($innoPath.Source)" "OK"
        } else {
            Write-BuildLog "Inno Setup requis mais non trouvé dans PATH!" "ERROR"
            return $false
        }
    }
    
    return $true
}

function Copy-LicenseIfExists {
    if ($LicensePath -and (Test-Path $LicensePath)) {
        Copy-Item $LicensePath ".\license.bin" -Force
        Write-BuildLog "Licence copiée: $LicensePath" "OK"
        return $true
    } elseif (Test-Path ".\license.bin") {
        Write-BuildLog "Utilisation de la licence existante: .\license.bin" "INFO"
        return $true
    } else {
        Write-BuildLog "Aucune licence trouvée - build sans licence" "WARN"
        return $false
    }
}

function Invoke-ElectronBuild {
    if (-not $SkipBuild) {
        Write-BuildLog "=== Construction de l'application ===" "INFO"
        npm run build
        if ($LASTEXITCODE -ne 0) {
            Write-BuildLog "Échec de la construction npm!" "ERROR"
            throw "Build failed"
        }
    }
}

function Build-PortableVersion {
    if ($Portable) {
        Write-BuildLog "=== Génération version portable ===" "INFO"
        npx electron-builder --win portable
        if ($LASTEXITCODE -eq 0) {
            Write-BuildLog "Version portable générée avec succès" "OK"
        } else {
            Write-BuildLog "Échec génération version portable" "ERROR"
        }
    }
}

function Build-NSISInstaller {
    if ($NSIS) {
        Write-BuildLog "=== Génération installateur NSIS ===" "INFO"
        npx electron-builder --win nsis
        if ($LASTEXITCODE -eq 0) {
            Write-BuildLog "Installateur NSIS généré avec succès" "OK"
        } else {
            Write-BuildLog "Échec génération installateur NSIS" "ERROR"
        }
    }
}

function Build-MSIInstaller {
    if ($MSI) {
        Write-BuildLog "=== Génération installateur MSI ===" "INFO"
        npx electron-builder --win msi
        if ($LASTEXITCODE -eq 0) {
            Write-BuildLog "Installateur MSI généré avec succès" "OK"
        } else {
            Write-BuildLog "Échec génération installateur MSI" "ERROR"
        }
    }
}

function Build-InnoSetupInstaller {
    if ($InnoSetup) {
        Write-BuildLog "=== Génération installateur Inno Setup ===" "INFO"
        
        # Vérifier que le script Inno Setup existe
        if (-not (Test-Path "installer\inno-setup.iss")) {
            Write-BuildLog "Fichier inno-setup.iss non trouvé!" "ERROR"
            return
        }
        
        # Compiler avec Inno Setup
        iscc "installer\inno-setup.iss"
        if ($LASTEXITCODE -eq 0) {
            Write-BuildLog "Installateur Inno Setup généré avec succès" "OK"
        } else {
            Write-BuildLog "Échec génération installateur Inno Setup" "ERROR"
        }
    }
}

function Show-BuildSummary {
    Write-BuildLog "=== RÉSUMÉ DES BUILDS ===" "INFO"
    
    if (Test-Path "release") {
        $releaseFiles = Get-ChildItem "release" -Filter "*.exe" | Sort-Object Name
        foreach ($file in $releaseFiles) {
            $sizeKB = [math]::Round($file.Length / 1KB, 0)
            Write-BuildLog "  [PACKAGE] $($file.Name) ($sizeKB KB)" "INFO"
        }
        
        $msiFiles = Get-ChildItem "release" -Filter "*.msi" | Sort-Object Name
        foreach ($file in $msiFiles) {
            $sizeKB = [math]::Round($file.Length / 1KB, 0)
            Write-BuildLog "  [PACKAGE] $($file.Name) ($sizeKB KB)" "INFO"
        }
    } else {
        Write-BuildLog "Aucun fichier de release trouvé" "WARN"
    }
}

function Clean-BuildArtifacts {
    if ($Clean) {
        Write-BuildLog "=== Nettoyage des artefacts ===" "INFO"
        
        if (Test-Path "release") {
            Remove-Item "release" -Recurse -Force
            Write-BuildLog "Répertoire release nettoyé" "OK"
        }
        
        if (Test-Path "dist") {
            Remove-Item "dist" -Recurse -Force
            Write-BuildLog "Répertoire dist nettoyé" "OK"
        }
    }
}

# === EXÉCUTION PRINCIPALE ===

try {
    Write-BuildLog "=== DÉBUT DU BUILD INSTALLATEURS v$Version ===" "INFO"
    
    # Nettoyage si demandé
    Clean-BuildArtifacts
    
    # Vérifications préalables
    if (-not (Test-BuildPrerequisites)) {
        throw "Prérequis non satisfaits"
    }
    
    # Copier la licence si fournie
    Copy-LicenseIfExists
    
    # Build de l'application
    Invoke-ElectronBuild
    
    # Générer les différents installateurs
    Build-PortableVersion
    Build-NSISInstaller
    Build-MSIInstaller
    Build-InnoSetupInstaller
    
    # Résumé final
    Show-BuildSummary
    
    Write-BuildLog "=== BUILD INSTALLATEURS TERMINÉ AVEC SUCCÈS ===" "OK"
    
} catch {
    Write-BuildLog "ERREUR DURANT LE BUILD: $($_.Exception.Message)" "ERROR"
    exit 1
}