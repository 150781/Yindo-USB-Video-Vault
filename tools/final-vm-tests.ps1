# Tests finaux sur VM propre - USB Video Vault
# Usage: .\final-vm-tests.ps1 -SetupUrl "https://github.com/.../releases/download/v0.1.4/USB%20Video%20Vault%20Setup%200.1.4.exe"

param(
    [Parameter(Mandatory=$true)]
    [string]$SetupUrl,
    [string]$LocalSetup = ".\USB Video Vault Setup 0.1.4.exe"
)

Write-Host "=== Tests finaux VM propre - USB Video Vault ===" -ForegroundColor Cyan
Write-Host "Setup URL: $SetupUrl" -ForegroundColor Gray
Write-Host ""

$testResults = @{
    download = $false
    signature = $false
    silentInstall = $false
    launch = $false
    silentUninstall = $false
    cleanup = $false
}

# 1. Téléchargement du setup
Write-Host "1. 📥 Téléchargement du setup..." -ForegroundColor Yellow
try {
    $ProgressPreference = 'SilentlyContinue'  # Masquer barre de progression
    Invoke-WebRequest -Uri $SetupUrl -OutFile $LocalSetup -UseBasicParsing
    
    if (Test-Path $LocalSetup) {
        $setupInfo = Get-Item $LocalSetup
        $setupSize = [math]::Round($setupInfo.Length / 1MB, 2)
        Write-Host "✅ Téléchargement réussi: ${setupSize}MB" -ForegroundColor Green
        $testResults.download = $true
    }
} catch {
    Write-Host "❌ Erreur téléchargement: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Vérification signature et SmartScreen
Write-Host "`n2. 🔐 Vérification signature..." -ForegroundColor Yellow
try {
    $signature = Get-AuthenticodeSignature $LocalSetup
    
    switch ($signature.Status) {
        "Valid" {
            Write-Host "✅ Signature Authenticode valide" -ForegroundColor Green
            Write-Host "📜 Signataire: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
            $testResults.signature = $true
        }
        "NotSigned" {
            Write-Host "⚠️  Fichier non signé - SmartScreen peut bloquer" -ForegroundColor Yellow
        }
        default {
            Write-Host "❌ Signature invalide: $($signature.Status)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "❌ Erreur vérification signature: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Test SmartScreen simulation
Write-Host "`n3. 🛡️ Test réputation SmartScreen..." -ForegroundColor Yellow
# Simuler ce que ferait un utilisateur final
Write-Host "📋 Vérifications à effectuer manuellement:" -ForegroundColor Cyan
Write-Host "   • Double-clic sur le setup → Pas d'avertissement SmartScreen = ✅" -ForegroundColor White
Write-Host "   • Si avertissement → 'Informations complémentaires' → 'Exécuter quand même'" -ForegroundColor White
Write-Host "   • Certificat EV → Réputation immédiate" -ForegroundColor White
Write-Host "   • Certificat OV/DV → Réputation progressive (quelques jours)" -ForegroundColor White

# 4. Installation silencieuse
Write-Host "`n4. 📦 Test installation silencieuse..." -ForegroundColor Yellow
try {
    $installProcess = Start-Process -FilePath $LocalSetup -ArgumentList "/S" -Wait -PassThru
    
    if ($installProcess.ExitCode -eq 0) {
        Write-Host "✅ Installation silencieuse réussie" -ForegroundColor Green
        $testResults.silentInstall = $true
        
        # Vérifier les fichiers installés
        $installPath = "$env:ProgramFiles\USB Video Vault"
        $mainExe = "$installPath\USB Video Vault.exe"
        $uninstaller = "$installPath\Uninstall USB Video Vault.exe"
        
        if ((Test-Path $mainExe) -and (Test-Path $uninstaller)) {
            Write-Host "✅ Fichiers installés correctement" -ForegroundColor Green
        } else {
            Write-Host "❌ Fichiers d'installation manquants" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Installation échouée - Code: $($installProcess.ExitCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur installation: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Test de lancement
if ($testResults.silentInstall) {
    Write-Host "`n5. 🚀 Test de lancement..." -ForegroundColor Yellow
    try {
        $mainExe = "$env:ProgramFiles\USB Video Vault\USB Video Vault.exe"
        $appProcess = Start-Process -FilePath $mainExe -PassThru
        Start-Sleep -Seconds 5  # Attendre le démarrage
        
        if ($appProcess -and -not $appProcess.HasExited) {
            Write-Host "✅ Application lancée avec succès" -ForegroundColor Green
            $testResults.launch = $true
            
            # Vérifier la fenêtre
            $windowTitle = (Get-Process -Id $appProcess.Id -ErrorAction SilentlyContinue).MainWindowTitle
            if ($windowTitle) {
                Write-Host "✅ Fenêtre principale: '$windowTitle'" -ForegroundColor Green
            }
            
            # Fermer l'application proprement
            Stop-Process -Id $appProcess.Id -Force -ErrorAction SilentlyContinue
            Write-Host "🛑 Application fermée pour tests" -ForegroundColor Gray
        } else {
            Write-Host "❌ Application fermée immédiatement" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Erreur lancement: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 6. Test désinstallation silencieuse
if ($testResults.silentInstall) {
    Write-Host "`n6. 🗑️  Test désinstallation silencieuse..." -ForegroundColor Yellow
    try {
        $uninstaller = "$env:ProgramFiles\USB Video Vault\Uninstall USB Video Vault.exe"
        if (Test-Path $uninstaller) {
            $uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList "/S" -Wait -PassThru
            
            if ($uninstallProcess.ExitCode -eq 0) {
                Write-Host "✅ Désinstallation silencieuse réussie" -ForegroundColor Green
                $testResults.silentUninstall = $true
                
                # Vérifier suppression
                Start-Sleep -Seconds 2
                if (-not (Test-Path "$env:ProgramFiles\USB Video Vault")) {
                    Write-Host "✅ Dossier d'installation supprimé" -ForegroundColor Green
                    $testResults.cleanup = $true
                } else {
                    Write-Host "⚠️  Dossier d'installation toujours présent" -ForegroundColor Yellow
                }
            } else {
                Write-Host "❌ Désinstallation échouée - Code: $($uninstallProcess.ExitCode)" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Désinstallateur introuvable" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Erreur désinstallation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 7. Nettoyage
Write-Host "`n7. 🧹 Nettoyage..." -ForegroundColor Yellow
if (Test-Path $LocalSetup) {
    Remove-Item $LocalSetup -Force
    Write-Host "✅ Fichier setup supprimé" -ForegroundColor Green
}

# 8. Résumé des tests
Write-Host "`n=== RÉSUMÉ DES TESTS VM ===" -ForegroundColor Cyan
$passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count
$successRate = [math]::Round(($passedTests / $totalTests) * 100, 1)

Write-Host "Réussite: $passedTests/$totalTests ($successRate%)" -ForegroundColor $(if ($successRate -ge 80) { "Green" } else { "Yellow" })
Write-Host ""

foreach ($test in $testResults.GetEnumerator()) {
    $status = if ($test.Value) { "✅" } else { "❌" }
    $color = if ($test.Value) { "Green" } else { "Red" }
    Write-Host "$status $($test.Key)" -ForegroundColor $color
}

# 9. Recommandations
Write-Host "`n🎯 Recommandations:" -ForegroundColor Blue
if (-not $testResults.signature) {
    Write-Host "• Signer le fichier avec certificat Authenticode pour éviter SmartScreen" -ForegroundColor Yellow
}
if (-not $testResults.silentInstall) {
    Write-Host "• Vérifier les paramètres NSIS pour installation silencieuse" -ForegroundColor Yellow
}
if (-not $testResults.launch) {
    Write-Host "• Vérifier les dépendances et permissions de l'application" -ForegroundColor Yellow
}
if (-not $testResults.cleanup) {
    Write-Host "• Améliorer le script de désinstallation NSIS" -ForegroundColor Yellow
}

if ($successRate -ge 80) {
    Write-Host "`n🎉 Tests VM réussis - Prêt pour publication!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Tests partiellement réussis - Corrections recommandées" -ForegroundColor Yellow
}

Write-Host "`n📋 Commandes de diagnostic pour support:" -ForegroundColor Cyan
Write-Host "Si problèmes utilisateur, demander d'exécuter:" -ForegroundColor Gray
Write-Host ".\tools\support\troubleshoot.ps1 -Detailed -CollectLogs" -ForegroundColor White