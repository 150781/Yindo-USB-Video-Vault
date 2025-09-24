# Script de test utilisateur pour USB Video Vault
# Tests rapides sur machine propre ou VM

param(
    [string]$TestPath = "C:\Temp\USBVaultTest",
    [switch]$CleanupFirst
)

Write-Host "🧪 Tests utilisateur USB Video Vault v0.1.4" -ForegroundColor Cyan

if ($CleanupFirst) {
    Write-Host "🧹 Nettoyage préalable..." -ForegroundColor Yellow
    
    # Désinstaller si présent
    $uninstaller = "C:\Program Files\USB Video Vault\Uninstall USB Video Vault.exe"
    if (Test-Path $uninstaller) {
        Write-Host "   Désinstallation silencieuse..." -ForegroundColor Gray
        Start-Process $uninstaller -ArgumentList "/S" -Wait -NoNewWindow
    }
    
    # Nettoyer le répertoire de test
    if (Test-Path $TestPath) {
        Remove-Item $TestPath -Recurse -Force
    }
}

# Créer répertoire de test
New-Item -ItemType Directory -Path $TestPath -Force | Out-Null
Write-Host "📁 Répertoire de test: $TestPath" -ForegroundColor Gray

# Tests disponibles
$tests = @(
    @{
        Name = "Test installation NSIS"
        Description = "Installation → Lancement → Vérification"
        Action = {
            Write-Host "   📦 Installation en cours..." -ForegroundColor Gray
            $setupPath = Read-Host "   Chemin vers 'USB Video Vault Setup 0.1.4.exe'"
            if (Test-Path $setupPath) {
                Start-Process $setupPath -Wait
                Write-Host "   ✅ Installation terminée" -ForegroundColor Green
                
                $exePath = "C:\Program Files\USB Video Vault\USB Video Vault.exe"
                if (Test-Path $exePath) {
                    Write-Host "   🚀 Test de lancement..." -ForegroundColor Gray
                    $process = Start-Process $exePath -PassThru
                    Start-Sleep 3
                    if (-not $process.HasExited) {
                        Write-Host "   ✅ Application lancée avec succès" -ForegroundColor Green
                        $process.Kill()
                    } else {
                        Write-Host "   ❌ L'application s'est fermée immédiatement" -ForegroundColor Red
                    }
                } else {
                    Write-Host "   ❌ Exécutable non trouvé après installation" -ForegroundColor Red
                }
            } else {
                Write-Host "   ❌ Fichier setup introuvable" -ForegroundColor Red
            }
        }
    },
    @{
        Name = "Test portable"
        Description = "Lancement depuis répertoire utilisateur"
        Action = {
            $portablePath = Read-Host "   Chemin vers 'USB Video Vault 0.1.4.exe'"
            if (Test-Path $portablePath) {
                $testDir = Join-Path $TestPath "Portable"
                New-Item -ItemType Directory -Path $testDir -Force | Out-Null
                $targetPath = Join-Path $testDir "USB Video Vault.exe"
                Copy-Item $portablePath $targetPath
                
                Write-Host "   🚀 Test de lancement portable..." -ForegroundColor Gray
                $process = Start-Process $targetPath -WorkingDirectory $testDir -PassThru
                Start-Sleep 3
                if (-not $process.HasExited) {
                    Write-Host "   ✅ Version portable fonctionne" -ForegroundColor Green
                    $process.Kill()
                } else {
                    Write-Host "   ❌ La version portable s'est fermée immédiatement" -ForegroundColor Red
                }
            } else {
                Write-Host "   ❌ Fichier portable introuvable" -ForegroundColor Red
            }
        }
    },
    @{
        Name = "Test installation silencieuse"
        Description = "Installation et désinstallation automatiques"
        Action = {
            $setupPath = Read-Host "   Chemin vers 'USB Video Vault Setup 0.1.4.exe'"
            if (Test-Path $setupPath) {
                Write-Host "   📦 Installation silencieuse..." -ForegroundColor Gray
                Start-Process $setupPath -ArgumentList "/S" -Wait -NoNewWindow
                
                Start-Sleep 2
                $exePath = "C:\Program Files\USB Video Vault\USB Video Vault.exe"
                if (Test-Path $exePath) {
                    Write-Host "   ✅ Installation silencieuse réussie" -ForegroundColor Green
                    
                    Write-Host "   🗑️ Désinstallation silencieuse..." -ForegroundColor Gray
                    $uninstaller = "C:\Program Files\USB Video Vault\Uninstall USB Video Vault.exe"
                    if (Test-Path $uninstaller) {
                        Start-Process $uninstaller -ArgumentList "/S" -Wait -NoNewWindow
                        Start-Sleep 2
                        if (-not (Test-Path $exePath)) {
                            Write-Host "   ✅ Désinstallation silencieuse réussie" -ForegroundColor Green
                        } else {
                            Write-Host "   ⚠️  Désinstallation incomplète" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "   ❌ Désinstallateur introuvable" -ForegroundColor Red
                    }
                } else {
                    Write-Host "   ❌ Installation silencieuse échouée" -ForegroundColor Red
                }
            } else {
                Write-Host "   ❌ Fichier setup introuvable" -ForegroundColor Red
            }
        }
    },
    @{
        Name = "Test droits utilisateur"
        Description = "Vérification fonctionnement sans droits admin"
        Action = {
            Write-Host "   ⚠️  Ce test nécessite une session utilisateur standard" -ForegroundColor Yellow
            Write-Host "   📋 Actions à effectuer manuellement:" -ForegroundColor Gray
            Write-Host "      1. Se connecter avec un compte utilisateur (non admin)" -ForegroundColor Gray
            Write-Host "      2. Lancer l'application" -ForegroundColor Gray
            Write-Host "      3. Vérifier qu'aucune erreur de permissions n'apparaît" -ForegroundColor Gray
            Write-Host "      4. Tester les fonctionnalités de base" -ForegroundColor Gray
            Read-Host "   Appuyez sur Entrée quand terminé"
        }
    }
)

# Menu de sélection
do {
    Write-Host "`n🎯 Tests disponibles:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $tests.Count; $i++) {
        Write-Host "   $($i + 1). $($tests[$i].Name)" -ForegroundColor White
        Write-Host "      $($tests[$i].Description)" -ForegroundColor Gray
    }
    Write-Host "   0. Quitter" -ForegroundColor White
    
    $choice = Read-Host "`nChoisissez un test (0-$($tests.Count))"
    
    if ($choice -eq "0") {
        break
    } elseif ($choice -match '^\d+$' -and [int]$choice -le $tests.Count -and [int]$choice -gt 0) {
        $testIndex = [int]$choice - 1
        Write-Host "`n🧪 Exécution: $($tests[$testIndex].Name)" -ForegroundColor Cyan
        try {
            & $tests[$testIndex].Action
        } catch {
            Write-Host "   ❌ Erreur pendant le test: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host "`n✅ Test terminé" -ForegroundColor Green
        Read-Host "Appuyez sur Entrée pour continuer"
    } else {
        Write-Host "❌ Choix invalide" -ForegroundColor Red
    }
} while ($true)

Write-Host "`n🎯 Tests terminés !" -ForegroundColor Cyan
Write-Host "📁 Répertoire de test conservé: $TestPath" -ForegroundColor Gray