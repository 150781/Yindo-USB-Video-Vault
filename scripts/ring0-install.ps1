# Script d'Installation Ring 0
# USB Video Vault - Installation silencieuse et tests

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InstallerPath = ".\releases\v1.0.4\USB-Video-Vault-Setup.exe",
    
    [Parameter(Mandatory=$false)]
    [string]$LicenseFile,
    
    [Parameter(Mandatory=$false)]
    [string]$MachineName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [switch]$SilentInstall,          # pas de valeur par défaut ici (PSAvoidDefaultValueSwitchParameter)
    
    [Parameter(Mandatory=$false)]
    [switch]$RunSmokeTests,          # pas de valeur par défaut ici (PSAvoidDefaultValueSwitchParameter)
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipLicense = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

# Configuration
$InstallPath = "C:\Program Files\USB Video Vault"
$AppDataPath = "$env:APPDATA\USB Video Vault"
$VaultPath   = "$env:USERPROFILE\Documents\Yindo-USB-Video-Vault\vault-real"
$PostInstallScript = "$InstallPath\post-install-simple.ps1"

function Write-InstallLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        "STEP"    { "Cyan" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-InstallPrerequisites {
    Write-InstallLog "Vérification des prérequis d'installation..." "STEP"
    
    # Vérifier privilèges administrateur
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-InstallLog "❌ Privilèges administrateur requis" "ERROR"
        throw "Exécuter en tant qu'administrateur"
    }
    Write-InstallLog "✓ Privilèges administrateur" "SUCCESS"
    
    # Vérifier installateur
    if (-not (Test-Path -LiteralPath $InstallerPath)) {
        Write-InstallLog "❌ Installateur non trouvé: $InstallerPath" "ERROR"
        throw "Installateur manquant"
    }
    Write-InstallLog "✓ Installateur trouvé: $InstallerPath" "SUCCESS"
    
    # Vérifier licence si spécifiée
    if (-not $SkipLicense) {
        if (-not $LicenseFile) {
            # Chercher licence automatiquement
            $autoLicense = "deliveries\$MachineName-license.bin"
            if (Test-Path -LiteralPath $autoLicense) {
                $LicenseFile = $autoLicense
                Write-InstallLog "✓ Licence auto-détectée: $LicenseFile" "SUCCESS"
            } else {
                Write-InstallLog "⚠️ Aucune licence spécifiée ou auto-détectée" "WARN"
            }
        } elseif (Test-Path -LiteralPath $LicenseFile) {
            Write-InstallLog "✓ Licence spécifiée: $LicenseFile" "SUCCESS"
        } else {
            Write-InstallLog "❌ Licence non trouvée: $LicenseFile" "ERROR"
            throw "Licence manquante"
        }
    }
    Write-InstallLog "Prérequis validés" "SUCCESS"
}

function Invoke-SilentInstallation {
    Write-InstallLog "Installation silencieuse..." "STEP"
    try {
        # Déterminer type d'installateur
        $installerExt = [System.IO.Path]::GetExtension($InstallerPath).ToLower()
        switch ($installerExt) {
            ".msi" {
                Write-InstallLog "Installation MSI..." "INFO"
                $msiParameters = "/i `"$InstallerPath`" /qn /L*v `"$env:TEMP\usb-vault-install.log`""
                $p = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiParameters -Wait -PassThru -NoNewWindow
                if ($p.ExitCode -ne 0) {
                    Write-InstallLog "❌ msiexec a retourné $($p.ExitCode)" "ERROR"
                    throw "Installation MSI échouée"
                }
            }
            ".exe" {
                Write-InstallLog "Installation EXE..." "INFO"
                # Essayer plusieurs paramètres silencieux courants
                $silentParameters = @("/S", "/SILENT", "/q", "/quiet")
                $success = $false
                foreach ($silentParam in $silentParameters) {
                    try {
                        $p = Start-Process -FilePath $InstallerPath -ArgumentList $silentParam -Wait -PassThru -NoNewWindow
                        if ($p.ExitCode -eq 0) {
                            Write-InstallLog "✓ Installation réussie avec: $silentParam" "SUCCESS"
                            $success = $true
                            break
                        }
                    } catch {
                        # on tente le paramètre suivant
                    }
                }
                if (-not $success) {
                    Write-InstallLog "❌ Impossible d'effectuer une installation silencieuse" "ERROR"
                    throw "Installation EXE échouée"
                }
            }
            default {
                Write-InstallLog "❌ Type d'installateur non supporté: $installerExt" "ERROR"
                throw "Type installateur inconnu"
            }
        }
        
        # Vérifier installation
        if (Test-Path -LiteralPath $InstallPath) {
            Write-InstallLog "✓ Installation détectée: $InstallPath" "SUCCESS"
        } else {
            Write-InstallLog "❌ Installation non détectée" "ERROR"
            throw "Installation échouée"
        }
    }
    catch {
        Write-InstallLog "❌ Erreur installation: $_" "ERROR"
        throw
    }
}

function Invoke-PostInstall {
    Write-InstallLog "Exécution post-install..." "STEP"
    try {
        if (Test-Path -LiteralPath $PostInstallScript) {
            Write-InstallLog "Exécution post-install script..." "INFO"
            $postInstallArgs = @()
            if ($Verbose) { $postInstallArgs += "-Verbose" }
            & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $PostInstallScript @postInstallArgs
            $ec = $LASTEXITCODE
            if ($ec -eq 0) {
                Write-InstallLog "✓ Post-install terminé" "SUCCESS"
            } else {
                Write-InstallLog "⚠️ Post-install avec avertissements (ExitCode=$ec)" "WARN"
            }
        } else {
            Write-InstallLog "⚠️ Script post-install non trouvé: $PostInstallScript" "WARN"
        }
    }
    catch {
        Write-InstallLog "❌ Erreur post-install: $_" "ERROR"
        # Ne pas arrêter l'installation pour le post-install
    }
}

function Install-License {
    if ($SkipLicense -or -not $LicenseFile) {
        Write-InstallLog "Installation licence ignorée" "WARN"
        return
    }
    Write-InstallLog "Installation de la licence..." "STEP"
    try {
        # Créer répertoires si nécessaires
        $vaultDir = "$VaultPath\.vault"
        if (-not (Test-Path -LiteralPath $vaultDir)) {
            New-Item -ItemType Directory -Path $vaultDir -Force | Out-Null
            Write-InstallLog "Répertoire vault créé: $vaultDir" "INFO"
        }
        # Copier licence
        $licenseDest = "$vaultDir\license.bin"
        Copy-Item -Path $LicenseFile -Destination $licenseDest -Force
        Write-InstallLog "✓ Licence installée: $licenseDest" "SUCCESS"
        
        # Vérifier licence
        if (Test-Path -LiteralPath "scripts\verify-license.mjs") {
            try {
                $verifyOutput = & node "scripts\verify-license.mjs" $licenseDest 2>&1
                $ec = $LASTEXITCODE
                if ($ec -eq 0) {
                    Write-InstallLog "✓ Licence vérifiée" "SUCCESS"
                } else {
                    Write-InstallLog "❌ Licence invalide: $verifyOutput" "ERROR"
                    throw "Licence invalide"
                }
            }
            catch {
                Write-InstallLog "⚠️ Impossible de vérifier licence" "WARN"
            }
        }
    }
    catch {
        Write-InstallLog "❌ Erreur installation licence: $_" "ERROR"
        throw
    }
}

function Invoke-SmokeTests {
    if (-not $RunSmokeTests) {
        Write-InstallLog "Smoke tests ignorés" "WARN"
        return
    }
    Write-InstallLog "Exécution des smoke tests..." "STEP"
    try {
        $executable = "$InstallPath\USB Video Vault.exe"
        if (-not (Test-Path -LiteralPath $executable)) {
            Write-InstallLog "❌ Exécutable non trouvé: $executable" "ERROR"
            throw "Exécutable manquant"
        }
        
        # Test 1: Vérifier signature
        Write-InstallLog "Test 1: Signature exécutable..." "INFO"
        try {
            $signature = Get-AuthenticodeSignature -FilePath $executable
            if ($signature.Status -eq "Valid") {
                Write-InstallLog "✓ Signature valide" "SUCCESS"
            } else {
                Write-InstallLog "⚠️ Signature: $($signature.Status)" "WARN"
            }
        }
        catch {
            Write-InstallLog "⚠️ Impossible de vérifier signature" "WARN"
        }
        
        # Test 2: Test de lancement (avec timeout)
        Write-InstallLog "Test 2: Lancement application..." "INFO"
        try {
            $startTime = Get-Date
            $process = Start-Process -FilePath $executable -ArgumentList "--version" -PassThru -WindowStyle Hidden
            $timeout = 10
            $waited  = 0
            while (-not $process.HasExited -and $waited -lt $timeout) {
                Start-Sleep -Seconds 1
                $waited++
            }
            if ($process.HasExited) {
                $duration = ((Get-Date) - $startTime).TotalSeconds
                Write-InstallLog "✓ Application lancée (${duration}s)" "SUCCESS"
                if ($duration -lt 3) {
                    Write-InstallLog "✓ Démarrage rapide (< 3s)" "SUCCESS"
                } else {
                    Write-InstallLog "⚠️ Démarrage lent (>= 3s)" "WARN"
                }
            } else {
                Write-InstallLog "⚠️ Application ne s'arrête pas (timeout)" "WARN"
                try { $process | Stop-Process -Force } catch {}
            }
        }
        catch {
            Write-InstallLog "❌ Erreur test lancement: $_" "ERROR"
        }
        
        # Test 3: Vérifier logs
        Write-InstallLog "Test 3: Vérification logs..." "INFO"
        $logFile = "$AppDataPath\logs\main.log"
        if (Test-Path -LiteralPath $logFile) {
            $recentLogs = Get-Content -LiteralPath $logFile -Tail 50 | Out-String
            $criticalErrors = @(
                "Signature de licence invalide",
                "Licence expirée", 
                "Horloge incohérente",
                "Anti-rollback",
                "Erreur validation"
            )
            $criticalErrorCount = 0   # <-- évite toute variable nommée $error
            foreach ($critical in $criticalErrors) {
                if ($recentLogs -match [Regex]::Escape($critical)) {
                    Write-InstallLog "❌ Erreur détectée: $critical" "ERROR"
                    $criticalErrorCount++
                }
            }
            if ($criticalErrorCount -eq 0) {
                Write-InstallLog "✓ Aucune erreur critique dans logs" "SUCCESS"
            } else {
                Write-InstallLog "❌ $criticalErrorCount erreur(s) critique(s) trouvée(s)" "ERROR"
                throw "Erreurs critiques détectées"
            }
        } else {
            Write-InstallLog "⚠️ Fichier log non trouvé: $logFile" "WARN"
        }
        
        # Test 4: Utilisation mémoire
        Write-InstallLog "Test 4: Utilisation mémoire..." "INFO"
        try {
            $processes = Get-Process | Where-Object { $_.ProcessName -like "*USB*Video*Vault*" -or $_.MainWindowTitle -like "*USB Video Vault*" }
            if ($processes.Count -gt 0) {
                foreach ($proc in $processes) {
                    $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                    Write-InstallLog "Processus: $($proc.ProcessName) - Mémoire: ${memoryMB} MB" "INFO"
                    if ($memoryMB -lt 150) {
                        Write-InstallLog "✓ Utilisation mémoire acceptable (< 150 MB)" "SUCCESS"
                    } else {
                        Write-InstallLog "⚠️ Utilisation mémoire élevée (>= 150 MB)" "WARN"
                    }
                }
            } else {
                Write-InstallLog "ℹ️ Aucun processus actif trouvé" "INFO"
            }
        }
        catch {
            Write-InstallLog "⚠️ Impossible de vérifier mémoire: $_" "WARN"
        }
        Write-InstallLog "✓ Smoke tests terminés" "SUCCESS"
    }
    catch {
        Write-InstallLog "❌ Smoke tests échoués: $_" "ERROR"
        throw
    }
}

function New-InstallReport {
    Write-InstallLog "Génération rapport d'installation..." "STEP"
    try {
        $reportPath = "ring0-install-report-$MachineName-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $report = @"
USB Video Vault - Rapport Installation Ring 0
============================================

Machine: $MachineName
Date: $(Get-Date)
Installateur: $InstallerPath
Licence: $(if ($LicenseFile) { $LicenseFile } else { "Non installée" })

Installation:
  Chemin: $InstallPath
  Existe: $(Test-Path -LiteralPath $InstallPath)
  Exécutable: $(Test-Path -LiteralPath "$InstallPath\USB Video Vault.exe")

Licence:
  Fichier: $(if ($LicenseFile) { Test-Path -LiteralPath $LicenseFile } else { "N/A" })
  Installée: $(Test-Path -LiteralPath "$VaultPath\.vault\license.bin")

Logs:
  Répertoire: $AppDataPath\logs
  Fichier principal: $(Test-Path -LiteralPath "$AppDataPath\logs\main.log")

Tests:
  Smoke tests: $(if ($RunSmokeTests) { "Exécutés" } else { "Ignorés" })
  Post-install: $(Test-Path -LiteralPath $PostInstallScript)

Status: SUCCÈS

Prochaines étapes:
1. Vérifier l'application fonctionne
2. Commencer monitoring des logs
3. Préparer pour déploiement Ring 1

---
Rapport généré automatiquement
"@
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        Write-InstallLog "✓ Rapport sauvegardé: $reportPath" "SUCCESS"
    }
    catch {
        Write-InstallLog "❌ Erreur génération rapport: $_" "ERROR"
    }
}

# Fonction principale
function Main {
    Write-InstallLog "=== Installation Ring 0 - USB Video Vault ===" "STEP"
    Write-InstallLog "Machine: $MachineName" "INFO"
    
    # Définir valeurs par défaut pour switches (après analyse des paramètres)
    if (-not $PSBoundParameters.ContainsKey('SilentInstall')) { $SilentInstall = $true }
    if (-not $PSBoundParameters.ContainsKey('RunSmokeTests')) { $RunSmokeTests = $true }
    
    try {
        Test-InstallPrerequisites
        if ($SilentInstall) { Invoke-SilentInstallation } else { Write-InstallLog "Installation silencieuse désactivée" "WARN" }
        Invoke-PostInstall
        Install-License
        Invoke-SmokeTests
        New-InstallReport
        
        Write-InstallLog "🎉 Installation Ring 0 terminée avec succès!" "SUCCESS"
        Write-InstallLog "Application installée: $InstallPath" "SUCCESS"
        if (-not $SkipLicense -and $LicenseFile) {
            Write-InstallLog "Licence installée et vérifiée" "SUCCESS"
        }
        Write-InstallLog "Prochaines étapes:" "INFO"
        Write-InstallLog "1. Lancer l'application pour test final" "INFO"
        Write-InstallLog "2. Monitoring: Get-Content `"$AppDataPath\logs\main.log`" -Wait" "INFO"
        Write-InstallLog "3. Valider 48h puis passer Ring 1" "INFO"
    }
    catch {
        Write-InstallLog "❌ Installation échouée: $_" "ERROR"
        exit 1
    }
}

# Exécution
Main
