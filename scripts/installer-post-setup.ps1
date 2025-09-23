# Script de Configuration Post-Installation
# USB Video Vault - Intégration EULA, Privacy et outils client

param(
    [string]$InstallPath = "$env:ProgramFiles\USB Video Vault",
    [string]$UserDataPath = "$env:LOCALAPPDATA\USB Video Vault",
    [switch]$Force,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-LegalDocuments {
    Write-Log "Installation des documents légaux..." "INFO"
    
    $legalPath = Join-Path $InstallPath "legal"
    if (-not (Test-Path $legalPath)) {
        New-Item -Path $legalPath -ItemType Directory -Force | Out-Null
    }
    
    # Copier EULA
    $eulaSource = Join-Path $PSScriptRoot "..\legal\EULA.md"
    $eulaTarget = Join-Path $legalPath "EULA.md"
    if (Test-Path $eulaSource) {
        Copy-Item $eulaSource $eulaTarget -Force
        Write-Log "EULA installé: $eulaTarget" "SUCCESS"
    } else {
        Write-Log "EULA source non trouvé: $eulaSource" "ERROR"
    }
    
    # Copier Privacy Policy
    $privacySource = Join-Path $PSScriptRoot "..\legal\PRIVACY_POLICY.md"
    $privacyTarget = Join-Path $legalPath "PRIVACY_POLICY.md"
    if (Test-Path $privacySource) {
        Copy-Item $privacySource $privacyTarget -Force
        Write-Log "Politique de confidentialité installée: $privacyTarget" "SUCCESS"
    } else {
        Write-Log "Privacy Policy source non trouvée: $privacySource" "ERROR"
    }
    
    # Copier Client License Guide
    $guideSource = Join-Path $PSScriptRoot "..\legal\CLIENT_LICENSE_GUIDE.md"
    $guideTarget = Join-Path $legalPath "CLIENT_LICENSE_GUIDE.md"
    if (Test-Path $guideSource) {
        Copy-Item $guideSource $guideTarget -Force
        Write-Log "Guide licence client installé: $guideTarget" "SUCCESS"
    } else {
        Write-Log "Guide client source non trouvé: $guideSource" "ERROR"
    }
    
    # Créer raccourci vers les documents légaux
    $shortcutPath = Join-Path $InstallPath "📄 Documents Légaux.lnk"
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $legalPath
    $shortcut.Description = "Documents légaux USB Video Vault (EULA, Confidentialité, Guide)"
    $shortcut.Save()
    Write-Log "Raccourci créé: $shortcutPath" "SUCCESS"
}

function Install-ClientTools {
    Write-Log "Installation des outils client..." "INFO"
    
    $toolsPath = Join-Path $InstallPath "tools"
    if (-not (Test-Path $toolsPath)) {
        New-Item -Path $toolsPath -ItemType Directory -Force | Out-Null
    }
    
    # Copier verify-license.mjs
    $verifySource = Join-Path $PSScriptRoot "..\client-tools\verify-license.mjs"
    $verifyTarget = Join-Path $toolsPath "verify-license.mjs"
    if (Test-Path $verifySource) {
        Copy-Item $verifySource $verifyTarget -Force
        Write-Log "Outil vérification licence installé: $verifyTarget" "SUCCESS"
    } else {
        Write-Log "verify-license.mjs source non trouvé: $verifySource" "ERROR"
    }
    
    # Créer script batch pour faciliter l'usage
    $batchScript = @"
@echo off
echo 🔑 USB Video Vault - Vérification de Licence
echo ============================================
echo.

cd /d "%~dp0"

REM Chercher Node.js
where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Node.js non trouvé. Veuillez installer Node.js pour utiliser cet outil.
    echo.
    echo Téléchargez Node.js depuis: https://nodejs.org/
    pause
    exit /b 1
)

REM Exécuter la vérification
echo Vérification de votre licence...
echo.
node verify-license.mjs %*

echo.
echo 💡 Pour plus d'options: node verify-license.mjs --help
echo 📚 Guide complet: ..\legal\CLIENT_LICENSE_GUIDE.md
echo.
pause
"@
    
    $batchPath = Join-Path $toolsPath "verifier-licence.bat"
    Set-Content -Path $batchPath -Value $batchScript -Encoding ASCII
    Write-Log "Script batch créé: $batchPath" "SUCCESS"
    
    # Créer raccourci bureau pour vérification licence
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "🔑 Vérifier Licence USB Video Vault.lnk"
    
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $batchPath
    $shortcut.WorkingDirectory = $toolsPath
    $shortcut.Description = "Vérifier votre licence USB Video Vault"
    $shortcut.IconLocation = Join-Path $InstallPath "USB Video Vault.exe,0"
    $shortcut.Save()
    Write-Log "Raccourci bureau créé: $shortcutPath" "SUCCESS"
}

function Create-UserDataStructure {
    Write-Log "Création structure données utilisateur..." "INFO"
    
    if (-not (Test-Path $UserDataPath)) {
        New-Item -Path $UserDataPath -ItemType Directory -Force | Out-Null
    }
    
    # Dossier backups
    $backupPath = Join-Path $UserDataPath "backups"
    if (-not (Test-Path $backupPath)) {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        Write-Log "Dossier sauvegarde créé: $backupPath" "SUCCESS"
    }
    
    # Dossier logs
    $logsPath = Join-Path $UserDataPath "logs"
    if (-not (Test-Path $logsPath)) {
        New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
        Write-Log "Dossier logs créé: $logsPath" "SUCCESS"
    }
    
    # Dossier support (pour bundles de support)
    $supportPath = Join-Path $UserDataPath "support"
    if (-not (Test-Path $supportPath)) {
        New-Item -Path $supportPath -ItemType Directory -Force | Out-Null
        Write-Log "Dossier support créé: $supportPath" "SUCCESS"
    }
    
    # Fichier de configuration initial
    $configPath = Join-Path $UserDataPath "config.json"
    if (-not (Test-Path $configPath) -or $Force) {
        $config = @{
            version = "1.0"
            installation = @{
                date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                path = $InstallPath
            }
            legal = @{
                eulaAccepted = $false
                eulaVersion = "1.0"
                privacyPolicyAccepted = $false
                privacyPolicyVersion = "1.0"
            }
            features = @{
                autoCheckLicense = $true
                autoBackup = $true
                verboseLogging = $false
            }
        } | ConvertTo-Json -Depth 4
        
        Set-Content -Path $configPath -Value $config -Encoding UTF8
        Write-Log "Configuration initiale créée: $configPath" "SUCCESS"
    }
}

function Register-FileAssociations {
    Write-Log "Enregistrement associations de fichiers..." "INFO"
    
    if (-not (Test-AdminRights)) {
        Write-Log "Droits administrateur requis pour les associations de fichiers" "WARNING"
        return
    }
    
    try {
        # Association .vault pour les fichiers de configuration vault
        $vaultKey = "HKLM:\SOFTWARE\Classes\.vault"
        New-Item -Path $vaultKey -Force | Out-Null
        Set-ItemProperty -Path $vaultKey -Name "(Default)" -Value "USBVideoVault.VaultFile"
        
        $vaultFileKey = "HKLM:\SOFTWARE\Classes\USBVideoVault.VaultFile"
        New-Item -Path $vaultFileKey -Force | Out-Null
        Set-ItemProperty -Path $vaultFileKey -Name "(Default)" -Value "USB Video Vault Configuration"
        
        $vaultIconKey = "$vaultFileKey\DefaultIcon"
        New-Item -Path $vaultIconKey -Force | Out-Null
        Set-ItemProperty -Path $vaultIconKey -Name "(Default)" -Value "`"$InstallPath\USB Video Vault.exe`",0"
        
        $vaultCommandKey = "$vaultFileKey\shell\open\command"
        New-Item -Path $vaultCommandKey -Force | Out-Null
        Set-ItemProperty -Path $vaultCommandKey -Name "(Default)" -Value "`"$InstallPath\USB Video Vault.exe`" `"%1`""
        
        Write-Log "Association .vault enregistrée" "SUCCESS"
        
    } catch {
        Write-Log "Erreur enregistrement associations: $($_.Exception.Message)" "ERROR"
    }
}

function Install-StartMenuShortcuts {
    Write-Log "Installation raccourcis menu Démarrer..." "INFO"
    
    $startMenuPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\USB Video Vault"
    if (-not (Test-Path $startMenuPath)) {
        New-Item -Path $startMenuPath -ItemType Directory -Force | Out-Null
    }
    
    $wshell = New-Object -ComObject WScript.Shell
    
    # Raccourci principal
    $mainShortcut = $wshell.CreateShortcut((Join-Path $startMenuPath "USB Video Vault.lnk"))
    $mainShortcut.TargetPath = Join-Path $InstallPath "USB Video Vault.exe"
    $mainShortcut.Description = "USB Video Vault - Gestionnaire de médias sécurisé"
    $mainShortcut.Save()
    
    # Raccourci vérification licence
    $licenseShortcut = $wshell.CreateShortcut((Join-Path $startMenuPath "Vérifier Licence.lnk"))
    $licenseShortcut.TargetPath = Join-Path $InstallPath "tools\verifier-licence.bat"
    $licenseShortcut.WorkingDirectory = Join-Path $InstallPath "tools"
    $licenseShortcut.Description = "Vérifier votre licence USB Video Vault"
    $licenseShortcut.Save()
    
    # Raccourci guide utilisateur
    $guideShortcut = $wshell.CreateShortcut((Join-Path $startMenuPath "Guide Licence.lnk"))
    $guideShortcut.TargetPath = Join-Path $InstallPath "legal\CLIENT_LICENSE_GUIDE.md"
    $guideShortcut.Description = "Guide d'utilisation des licences"
    $guideShortcut.Save()
    
    # Raccourci désinstaller
    $uninstallShortcut = $wshell.CreateShortcut((Join-Path $startMenuPath "Désinstaller.lnk"))
    $uninstallShortcut.TargetPath = Join-Path $InstallPath "uninstall.exe"
    $uninstallShortcut.Description = "Désinstaller USB Video Vault"
    $uninstallShortcut.Save()
    
    Write-Log "Raccourcis menu Démarrer créés: $startMenuPath" "SUCCESS"
}

function Test-NodeJsAvailability {
    Write-Log "Vérification disponibilité Node.js..." "INFO"
    
    try {
        $nodeVersion = & node --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Node.js détecté: $nodeVersion" "SUCCESS"
            return $true
        }
    } catch {
        # Node.js non trouvé
    }
    
    Write-Log "Node.js non détecté" "WARNING"
    Write-Log "Les outils de vérification de licence nécessitent Node.js" "WARNING"
    Write-Log "Téléchargez Node.js depuis: https://nodejs.org/" "INFO"
    
    return $false
}

function Show-CompletionMessage {
    Write-Log "Installation post-configuration terminée!" "SUCCESS"
    Write-Log "" "INFO"
    Write-Log "📁 Répertoire d'installation: $InstallPath" "INFO"
    Write-Log "👤 Données utilisateur: $UserDataPath" "INFO"
    Write-Log "" "INFO"
    Write-Log "📚 Documents installés:" "INFO"
    Write-Log "   • EULA (Contrat de licence)" "INFO"
    Write-Log "   • Politique de confidentialité" "INFO"
    Write-Log "   • Guide licence client" "INFO"
    Write-Log "" "INFO"
    Write-Log "🔧 Outils disponibles:" "INFO"
    Write-Log "   • Vérificateur de licence (Desktop + Menu Démarrer)" "INFO"
    Write-Log "   • Script verify-license.mjs" "INFO"
    Write-Log "" "INFO"
    
    if (-not (Test-NodeJsAvailability)) {
        Write-Log "⚠️  ATTENTION: Installez Node.js pour utiliser les outils de licence" "WARNING"
    } else {
        Write-Log "✅ Système prêt à utiliser!" "SUCCESS"
    }
    
    Write-Log "" "INFO"
    Write-Log "🚀 Pour commencer:" "INFO"
    Write-Log "   1. Lancez USB Video Vault depuis le menu Démarrer" "INFO"
    Write-Log "   2. Acceptez l'EULA et la politique de confidentialité" "INFO"
    Write-Log "   3. Insérez votre périphérique USB licencié" "INFO"
    Write-Log "   4. Utilisez 'Vérifier Licence' si nécessaire" "INFO"
}

# SCRIPT PRINCIPAL
try {
    Write-Log "Début configuration post-installation USB Video Vault" "INFO"
    Write-Log "=====================================================" "INFO"
    
    # Vérifications préliminaires
    if (-not (Test-Path $InstallPath)) {
        Write-Log "Répertoire d'installation non trouvé: $InstallPath" "ERROR"
        Write-Log "Veuillez spécifier le bon chemin avec -InstallPath" "ERROR"
        exit 1
    }
    
    # Installation des composants
    Install-LegalDocuments
    Install-ClientTools
    Create-UserDataStructure
    Register-FileAssociations
    Install-StartMenuShortcuts
    
    # Message de fin
    Show-CompletionMessage
    
    Write-Log "Configuration post-installation terminée avec succès!" "SUCCESS"
    exit 0
    
} catch {
    Write-Log "Erreur durant la configuration: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}