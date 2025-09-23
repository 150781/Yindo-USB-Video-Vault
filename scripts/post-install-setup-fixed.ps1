# Script Post-Install Avance - Version Corrigee
param(
    [string]$VaultPath = "",
    [string]$LicenseSource = ".\out\license.bin",
    [switch]$Force,
    [switch]$Verbose
)

function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
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
    
    if ($CustomPath) {
        return $CustomPath
    }
    
    # Utiliser variable d'environnement ou defaut
    $envVaultPath = $env:VAULT_PATH
    if ($envVaultPath) {
        return $envVaultPath
    }
    
    # Chemin par defaut
    return "$env:USERPROFILE\Documents\USB-Video-Vault"
}

function Test-VaultSetup {
    param([string]$VaultPath)
    
    Write-LogMessage "Verification du setup vault: $VaultPath"
    
    # Verifier que le dossier .vault existe
    $vaultDir = Join-Path $VaultPath ".vault"
    if (-not (Test-Path $vaultDir)) {
        Write-LogMessage "Dossier vault manquant: $vaultDir" "WARN"
        return $false
    }
    
    # Verifier la licence si elle devrait etre presente
    $licenseFile = Join-Path $vaultDir "license.bin"
    if (Test-Path $licenseFile) {
        $licenseSize = (Get-Item $licenseFile).Length
        Write-LogMessage "Licence presente: $licenseFile ($licenseSize bytes)" "OK"
    } else {
        Write-LogMessage "Aucune licence dans le vault" "WARN"
    }
    
    return $true
}

function Install-VaultStructure {
    param(
        [string]$VaultPath,
        [string]$LicenseSource,
        [bool]$ForceInstall
    )
    
    Write-LogMessage "Installation structure vault: $VaultPath"
    
    # Creer le dossier principal si necessaire
    if (-not (Test-Path $VaultPath)) {
        Write-LogMessage "Creation dossier principal: $VaultPath"
        New-Item -Path $VaultPath -ItemType Directory -Force | Out-Null
    }
    
    # Creer le dossier .vault
    $vaultDir = Join-Path $VaultPath ".vault"
    if (-not (Test-Path $vaultDir)) {
        Write-LogMessage "Creation dossier vault: $vaultDir"
        New-Item -Path $vaultDir -ItemType Directory -Force | Out-Null
    } elseif ($ForceInstall) {
        Write-LogMessage "Recreation forcee du dossier vault" "WARN"
        Remove-Item $vaultDir -Recurse -Force
        New-Item -Path $vaultDir -ItemType Directory -Force | Out-Null
    }
    
    # Installer la licence si disponible
    if (Test-Path $LicenseSource) {
        $targetLicense = Join-Path $vaultDir "license.bin"
        
        Write-LogMessage "Installation licence: $LicenseSource -> $targetLicense"
        Copy-Item $LicenseSource $targetLicense -Force
        
        # Verifier l'integrite de la copie
        $sourceSize = (Get-Item $LicenseSource).Length
        $targetSize = (Get-Item $targetLicense).Length
        
        if ($sourceSize -eq $targetSize) {
            Write-LogMessage "Licence installee avec succes: $targetLicense ($targetSize bytes)" "OK"
            return $true
        } else {
            Write-LogMessage "Erreur d'integrite lors de la copie (tailles differentes)" "ERROR"
            throw "Erreur d'integrite"
        }
    } else {
        Write-LogMessage "Fichier licence source introuvable: $LicenseSource" "WARN"
        Write-LogMessage "Installation sans licence (peut etre ajoutee plus tard)" "WARN"
        return $true
    }
}

function Set-VaultEnvironment {
    param([string]$VaultPath)
    
    Write-LogMessage "Configuration variable VAULT_PATH: $VaultPath"
    
    # Definir pour la session actuelle
    $env:VAULT_PATH = $VaultPath
    
    # Definir de maniere persistante pour l'utilisateur
    try {
        [Environment]::SetEnvironmentVariable("VAULT_PATH", $VaultPath, "User")
        Write-LogMessage "Variable VAULT_PATH configuree de maniere persistante" "OK"
    } catch {
        Write-LogMessage "Impossible de configurer VAULT_PATH de maniere persistante: $($_.Exception.Message)" "WARN"
    }
}

function Show-InstallationSummary {
    param([string]$VaultPath)
    
    Write-LogMessage "=== RESUME DE L'INSTALLATION ==="
    Write-LogMessage "Vault Path: $VaultPath"
    Write-LogMessage "Variable VAULT_PATH: $env:VAULT_PATH"
    
    $vaultDir = Join-Path $VaultPath ".vault"
    if (Test-Path $vaultDir) {
        Write-LogMessage "Dossier vault: PRESENT" "OK"
        
        $licenseFile = Join-Path $vaultDir "license.bin"
        if (Test-Path $licenseFile) {
            $licenseSize = (Get-Item $licenseFile).Length
            Write-LogMessage "Licence: INSTALLEE ($licenseSize bytes)" "OK"
        } else {
            Write-LogMessage "Licence: NON INSTALLEE" "WARN"
        }
    } else {
        Write-LogMessage "Dossier vault: MANQUANT" "ERROR"
        return $false
    }
    
    return $true
}

# === EXECUTION PRINCIPALE ===
try {
    Write-LogMessage "=== DEBUT POST-INSTALL USB VIDEO VAULT ===" "OK"
    
    # Determiner le chemin vault
    $finalVaultPath = Get-VaultPath $VaultPath
    Write-LogMessage "Utilisation vault path: $finalVaultPath"
    
    if ($Verbose) {
        Write-LogMessage "Mode verbose active"
        Write-LogMessage "Licence source: $LicenseSource"
        Write-LogMessage "Force: $Force"
    }
    
    # Installer la structure vault
    $installResult = Install-VaultStructure $finalVaultPath $LicenseSource $Force
    
    # Configurer l'environnement
    Set-VaultEnvironment $finalVaultPath
    
    # Verifier l'installation
    $installationValid = Test-VaultSetup $finalVaultPath
    
    # Afficher le resume
    $summaryValid = Show-InstallationSummary $finalVaultPath
    
    if ($installationValid -and $summaryValid) {
        Write-LogMessage "=== INSTALLATION POST-INSTALL REUSSIE ===" "OK"
        exit 0
    } else {
        Write-LogMessage "=== ECHEC DE L'INSTALLATION POST-INSTALL ===" "ERROR"
        exit 1
    }
    
} catch {
    Write-LogMessage "ERREUR CRITIQUE: $($_.Exception.Message)" "ERROR"
    Write-LogMessage "Installation post-install echouee" "ERROR"
    exit 1
}