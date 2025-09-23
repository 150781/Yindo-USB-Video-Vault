# Script post-install pour USB Video Vault
# Crée le répertoire vault et installe la licence

param(
    [string]$LicenseSource = ".\license.bin",
    [string]$VaultPath = $null,
    [switch]$Force = $false,
    [switch]$Verbose = $false
)

function Write-LogMessage {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        "ERROR" { "[ERROR]" }
        "WARN"  { "[WARN] " }
        "OK"    { "[OK]   " }
        default { "[INFO] " }
    }
    Write-Host "[$timestamp] $prefix $Message"
}

function Get-VaultPath {
    param([string]$CustomPath)
    
    # 1. Utiliser le paramètre personnalisé s'il est fourni
    if ($CustomPath) {
        Write-LogMessage "Utilisation du chemin personnalisé: $CustomPath" "INFO"
        return $CustomPath
    }
    
    # 2. Vérifier la variable d'environnement VAULT_PATH
    $envVaultPath = $env:VAULT_PATH
    if ($envVaultPath) {
        Write-LogMessage "Utilisation de VAULT_PATH: $envVaultPath" "INFO"
        return $envVaultPath
    }
    
    # 3. Utiliser le chemin par défaut
    $defaultPath = Join-Path $env:USERPROFILE "Documents\Yindo-USB-Video-Vault\vault-real"
    Write-LogMessage "Utilisation du chemin par défaut: $defaultPath" "INFO"
    return $defaultPath
}

function Initialize-VaultDirectory {
    param([string]$VaultPath)
    
    $vaultConfigDir = Join-Path $VaultPath ".vault"
    
    try {
        # Créer le répertoire vault principal
        if (-not (Test-Path $VaultPath)) {
            New-Item -ItemType Directory -Force -Path $VaultPath | Out-Null
            Write-LogMessage "Répertoire vault créé: $VaultPath" "OK"
        } else {
            Write-LogMessage "Répertoire vault existe déjà: $VaultPath" "INFO"
        }
        
        # Créer le répertoire de configuration .vault
        if (-not (Test-Path $vaultConfigDir)) {
            New-Item -ItemType Directory -Force -Path $vaultConfigDir | Out-Null
            Write-LogMessage "Répertoire de configuration créé: $vaultConfigDir" "OK"
        } else {
            Write-LogMessage "Répertoire de configuration existe déjà: $vaultConfigDir" "INFO"
        }
        
        return $vaultConfigDir
        
    } catch {
        Write-LogMessage "Erreur lors de la création des répertoires: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Install-License {
    param(
        [string]$SourcePath,
        [string]$VaultConfigDir,
        [bool]$ForceOverwrite
    )
    
    $targetLicense = Join-Path $VaultConfigDir "license.bin"
    
    # Vérifier que le fichier source existe
    if (-not (Test-Path $SourcePath)) {
        Write-LogMessage "Fichier licence source introuvable: $SourcePath" "ERROR"
        throw "Fichier licence source introuvable"
    }
    
    # Vérifier si la licence existe déjà
    if ((Test-Path $targetLicense) -and -not $ForceOverwrite) {
        Write-LogMessage "Licence existe déjà. Utilisez -Force pour écraser: $targetLicense" "WARN"
        return $false
    }
    
    try {
        # Copier la licence
        Copy-Item $SourcePath $targetLicense -Force
        
        # Vérifier l'intégrité de la copie
        $sourceSize = (Get-Item $SourcePath).Length
        $targetSize = (Get-Item $targetLicense).Length
        
        if ($sourceSize -eq $targetSize) {
            Write-LogMessage "Licence installee avec succes: $targetLicense ($targetSize bytes)" "OK"
            return $true
        } else {
            Write-LogMessage "Erreur d'integrite lors de la copie (tailles differentes)" "ERROR"
            throw "Erreur d'integrite"
        }
        
    } catch {
        Write-LogMessage "Erreur lors de l'installation de la licence: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Test-Installation {
    param([string]$VaultConfigDir)
    
    $licenseFile = Join-Path $VaultConfigDir "license.bin"
    
    if (Test-Path $licenseFile) {
        $licenseSize = (Get-Item $licenseFile).Length
        Write-LogMessage "✅ Installation vérifiée - Licence: $licenseFile ($licenseSize bytes)" "OK"
        
        # Afficher les informations de la licence
        if ($Verbose) {
            $licenseInfo = Get-Item $licenseFile
            Write-LogMessage "  Créé: $($licenseInfo.CreationTime)" "INFO"
            Write-LogMessage "  Modifié: $($licenseInfo.LastWriteTime)" "INFO"
        }
        
        return $true
    } else {
        Write-LogMessage "❌ Vérification échouée - Licence non trouvée" "ERROR"
        return $false
    }
}

function Set-VaultEnvironment {
    param([string]$VaultPath)
    
    try {
        # Définir la variable d'environnement pour l'utilisateur
        [Environment]::SetEnvironmentVariable("VAULT_PATH", $VaultPath, "User")
        Write-LogMessage "Variable d'environnement VAULT_PATH définie: $VaultPath" "OK"
        
        # Mettre à jour la session actuelle
        $env:VAULT_PATH = $VaultPath
        
    } catch {
        Write-LogMessage "Impossible de définir VAULT_PATH: $($_.Exception.Message)" "WARN"
    }
}

# === EXÉCUTION PRINCIPALE ===

try {
    Write-LogMessage "=== DÉBUT DE L'INSTALLATION POST-INSTALL ===" "INFO"
    
    # 1. Déterminer le chemin du vault
    $vaultPath = Get-VaultPath -CustomPath $VaultPath
    
    # 2. Initialiser les répertoires
    $vaultConfigDir = Initialize-VaultDirectory -VaultPath $vaultPath
    
    # 3. Installer la licence
    $licenseInstalled = Install-License -SourcePath $LicenseSource -VaultConfigDir $vaultConfigDir -ForceOverwrite $Force
    
    # 4. Définir la variable d'environnement
    Set-VaultEnvironment -VaultPath $vaultPath
    
    # 5. Vérifier l'installation
    $installationValid = Test-Installation -VaultConfigDir $vaultConfigDir
    
    if ($installationValid) {
        Write-LogMessage "=== INSTALLATION POST-INSTALL TERMINÉE AVEC SUCCÈS ===" "OK"
        Write-LogMessage "Vault configuré: $vaultPath" "INFO"
        Write-LogMessage "Licence installée: $(Join-Path $vaultConfigDir 'license.bin')" "INFO"
        
        # Instructions pour l'utilisateur
        Write-Host ""
        Write-Host "📋 INSTRUCTIONS:" -ForegroundColor Cyan
        Write-Host "   • Le vault est configuré dans: $vaultPath" -ForegroundColor White
        Write-Host "   • Variable VAULT_PATH définie automatiquement" -ForegroundColor White
        Write-Host "   • Redémarrez votre terminal pour prendre en compte VAULT_PATH" -ForegroundColor Yellow
        Write-Host "   • L'application USB Video Vault peut maintenant être lancée" -ForegroundColor Green
        
    } else {
        Write-LogMessage "=== ECHEC DE L'INSTALLATION POST-INSTALL ===" "ERROR"
        exit 1
    }
    
} catch {
    Write-LogMessage "ERREUR CRITIQUE: $($_.Exception.Message)" "ERROR"
    Write-LogMessage "Installation post-install echouee" "ERROR"
    exit 1
}