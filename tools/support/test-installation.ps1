# Script de test d'installation USB Video Vault
# Usage: .\test-installation.ps1 [-SetupPath "path"] [-FullTest] [-CleanUninstall]

param(
    [string]$SetupPath = ".\dist\USB Video Vault Setup 0.1.4.exe",
    [switch]$FullTest,
    [switch]$CleanUninstall
)

$ErrorActionPreference = "Continue"

Write-Host "=== Test d'installation USB Video Vault ===" -ForegroundColor Cyan
Write-Host "Setup: $SetupPath" -ForegroundColor Gray
Write-Host ""

# Fonction de vérification de l'état
function Test-InstallationState {
    $installed = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*USB Video Vault*" }
    $processRunning = Get-Process "USB Video Vault" -ErrorAction SilentlyContinue
    $installPath = "$env:ProgramFiles\USB Video Vault"

    return @{
        WmiProduct = $installed
        ProcessRunning = $processRunning
        InstallPath = $installPath
        FilesPresent = Test-Path $installPath
    }
}

# 1. État initial
Write-Host "1. 📋 État initial du système:" -ForegroundColor Yellow
$initialState = Test-InstallationState
if ($initialState.WmiProduct) {
    Write-Host "⚠️  Application déjà installée: $($initialState.WmiProduct.Name)" -ForegroundColor Yellow
    if ($CleanUninstall) {
        Write-Host "🧹 Désinstallation préalable..." -ForegroundColor Yellow
        $initialState.WmiProduct.Uninstall() | Out-Null
        Start-Sleep -Seconds 3
    }
} else {
    Write-Host "✅ Système propre - aucune installation détectée" -ForegroundColor Green
}

if ($initialState.ProcessRunning) {
    Write-Host "⚠️  Processus en cours d'exécution - arrêt..." -ForegroundColor Yellow
    Stop-Process -Name "USB Video Vault" -Force -ErrorAction SilentlyContinue
}

# 2. Vérification du setup
Write-Host "`n2. 🔍 Vérification du setup:" -ForegroundColor Yellow
if (-not (Test-Path $SetupPath)) {
    Write-Error "❌ Fichier setup introuvable: $SetupPath"
    exit 1
}

$setupInfo = Get-Item $SetupPath
$setupHash = (Get-FileHash $SetupPath -Algorithm SHA256).Hash
$setupSize = [math]::Round($setupInfo.Length / 1MB, 2)

Write-Host "✅ Fichier: $($setupInfo.Name)" -ForegroundColor Green
Write-Host "📊 Taille: ${setupSize}MB" -ForegroundColor Gray
Write-Host "🔐 SHA256: $setupHash" -ForegroundColor Gray

# Vérifier signature (si certificat présent)
try {
    $signature = Get-AuthenticodeSignature $SetupPath
    if ($signature.Status -eq "Valid") {
        Write-Host "✅ Signature numérique valide" -ForegroundColor Green
        Write-Host "📜 Certificat: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
    } elseif ($signature.Status -eq "NotSigned") {
        Write-Host "⚠️  Fichier non signé" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Signature invalide: $($signature.Status)" -ForegroundColor Red
    }
} catch {
    Write-Host "⚠️  Impossible de vérifier la signature" -ForegroundColor Yellow
}

# 3. Installation silencieuse
Write-Host "`n3. 📦 Installation silencieuse:" -ForegroundColor Yellow
Write-Host "Commande: `"$SetupPath`" /S" -ForegroundColor Gray

$installStart = Get-Date
try {
    $process = Start-Process -FilePath $SetupPath -ArgumentList "/S" -Wait -PassThru
    $installDuration = (Get-Date) - $installStart

    if ($process.ExitCode -eq 0) {
        Write-Host "✅ Installation terminée avec succès" -ForegroundColor Green
        Write-Host "⏱️  Durée: $([math]::Round($installDuration.TotalSeconds, 1))s" -ForegroundColor Gray
    } else {
        Write-Host "❌ Installation échouée - Code: $($process.ExitCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur lors de l'installation: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Vérification post-installation
Write-Host "`n4. ✅ Vérification post-installation:" -ForegroundColor Yellow
Start-Sleep -Seconds 2  # Attendre la finalisation

$postInstall = Test-InstallationState

# Vérifier WMI/Registry
if ($postInstall.WmiProduct) {
    Write-Host "✅ Produit enregistré: $($postInstall.WmiProduct.Name)" -ForegroundColor Green
    Write-Host "📝 Version: $($postInstall.WmiProduct.Version)" -ForegroundColor Gray
} else {
    Write-Host "❌ Produit non trouvé dans WMI" -ForegroundColor Red
}

# Vérifier fichiers
if ($postInstall.FilesPresent) {
    Write-Host "✅ Dossier d'installation présent" -ForegroundColor Green
    $mainExe = "$($postInstall.InstallPath)\USB Video Vault.exe"
    $uninstaller = "$($postInstall.InstallPath)\Uninstall USB Video Vault.exe"

    if (Test-Path $mainExe) {
        $exeInfo = Get-Item $mainExe
        Write-Host "✅ Exécutable principal: $([math]::Round($exeInfo.Length/1MB,1))MB" -ForegroundColor Green
    } else {
        Write-Host "❌ Exécutable principal manquant" -ForegroundColor Red
    }

    if (Test-Path $uninstaller) {
        Write-Host "✅ Désinstallateur présent" -ForegroundColor Green
    } else {
        Write-Host "❌ Désinstallateur manquant" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Dossier d'installation manquant" -ForegroundColor Red
}

# 5. Test de lancement (si demandé)
if ($FullTest) {
    Write-Host "`n5. 🚀 Test de lancement:" -ForegroundColor Yellow

    try {
        $mainExe = "$($postInstall.InstallPath)\USB Video Vault.exe"
        if (Test-Path $mainExe) {
            $appProcess = Start-Process -FilePath $mainExe -PassThru
            Start-Sleep -Seconds 3

            if ($appProcess -and -not $appProcess.HasExited) {
                Write-Host "✅ Application lancée avec succès (PID: $($appProcess.Id))" -ForegroundColor Green

                # Vérifier la fenêtre
                $windowTitle = (Get-Process -Id $appProcess.Id -ErrorAction SilentlyContinue).MainWindowTitle
                if ($windowTitle) {
                    Write-Host "✅ Fenêtre principale: '$windowTitle'" -ForegroundColor Green
                }

                # Arrêter l'application après test
                Write-Host "🛑 Arrêt de l'application..." -ForegroundColor Gray
                Stop-Process -Id $appProcess.Id -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host "❌ Application fermée immédiatement" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "❌ Erreur de lancement: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 6. Test de désinstallation (si demandé)
if ($FullTest -and $postInstall.FilesPresent) {
    Write-Host "`n6. 🗑️  Test de désinstallation:" -ForegroundColor Yellow

    $uninstaller = "$($postInstall.InstallPath)\Uninstall USB Video Vault.exe"
    if (Test-Path $uninstaller) {
        Write-Host "Commande: `"$uninstaller`" /S" -ForegroundColor Gray

        try {
            $uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList "/S" -Wait -PassThru
            Start-Sleep -Seconds 2

            if ($uninstallProcess.ExitCode -eq 0) {
                Write-Host "✅ Désinstallation terminée" -ForegroundColor Green

                # Vérifier la suppression
                if (-not (Test-Path $postInstall.InstallPath)) {
                    Write-Host "✅ Dossier d'installation supprimé" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Dossier d'installation toujours présent" -ForegroundColor Yellow
                }

                $finalState = Test-InstallationState
                if (-not $finalState.WmiProduct) {
                    Write-Host "✅ Produit supprimé du registre" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Produit toujours dans le registre" -ForegroundColor Yellow
                }
            } else {
                Write-Host "❌ Désinstallation échouée - Code: $($uninstallProcess.ExitCode)" -ForegroundColor Red
            }
        } catch {
            Write-Host "❌ Erreur de désinstallation: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Désinstallateur introuvable" -ForegroundColor Red
    }
}

# Résumé final
Write-Host "`n=== RÉSUMÉ DU TEST ===" -ForegroundColor Cyan
$finalState = Test-InstallationState

if ($FullTest) {
    Write-Host "Test complet terminé" -ForegroundColor Green
} else {
    Write-Host "Test d'installation terminé" -ForegroundColor Green
    Write-Host "Pour un test complet: -FullTest" -ForegroundColor Gray
}

Write-Host "📁 État final:" -ForegroundColor Yellow
if ($finalState.WmiProduct) {
    Write-Host "   • Application installée: $($finalState.WmiProduct.Name)" -ForegroundColor Green
} else {
    Write-Host "   • Application non installée" -ForegroundColor Gray
}

if ($finalState.FilesPresent) {
    Write-Host "   • Fichiers présents: $($finalState.InstallPath)" -ForegroundColor Green
} else {
    Write-Host "   • Fichiers absents" -ForegroundColor Gray
}

Write-Host "`n🎯 Commandes recommandées:" -ForegroundColor Blue
Write-Host "   • Test basique: .\test-installation.ps1" -ForegroundColor White
Write-Host "   • Test complet: .\test-installation.ps1 -FullTest" -ForegroundColor White
Write-Host "   • Nettoyage: .\test-installation.ps1 -CleanUninstall" -ForegroundColor White
