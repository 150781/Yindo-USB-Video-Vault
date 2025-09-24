# Script de démonstration rapide - usage interne/demo
# Usage: .\demo-quick.ps1 -ShowUI -TestPlayback

param(
    [switch]$ShowUI,
    [switch]$TestPlayback,
    [switch]$CreateSampleVault,
    [string]$VaultPath = ".\demo-vault"
)

Write-Host "=== USB Video Vault - Demo Rapide ===" -ForegroundColor Cyan
Write-Host ""

# 1. Vérification app installée ou portable disponible
Write-Host "1. 🔍 Recherche application..." -ForegroundColor Yellow

$packageVersion = (Get-Content .\package.json | ConvertFrom-Json).version
$appPaths = @(
    "$env:LOCALAPPDATA\Programs\USB Video Vault\USB Video Vault.exe",
    "$env:PROGRAMFILES\USB Video Vault\USB Video Vault.exe",
    ".\dist\USB Video Vault $packageVersion.exe",
    ".\USB-Video-Vault.exe"
)

$appPath = $null
foreach ($path in $appPaths) {
    if (Test-Path $path) {
        $appPath = $path
        break
    }
}

if ($appPath) {
    Write-Host "✅ Application trouvée: $appPath" -ForegroundColor Green
} else {
    Write-Host "❌ Application non trouvée" -ForegroundColor Red
    Write-Host "   💡 Lancer d'abord: npm run build ou installer le setup" -ForegroundColor Yellow
    exit 1
}

# 2. Création vault demo si demandé
if ($CreateSampleVault) {
    Write-Host "`n2. 📁 Création vault de démonstration..." -ForegroundColor Yellow
    
    if (Test-Path $VaultPath) {
        Write-Host "   ⚠️  Vault existe déjà: $VaultPath" -ForegroundColor Yellow
        Write-Host "   🗑️  Supprimer? (y/N)" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq 'y' -or $response -eq 'Y') {
            Remove-Item $VaultPath -Recurse -Force
            Write-Host "   ✅ Vault supprimé" -ForegroundColor Green
        } else {
            Write-Host "   ⏭️  Utilisation vault existant" -ForegroundColor Blue
        }
    }
    
    if (-not (Test-Path $VaultPath)) {
        # Créer structure vault basique
        New-Item -ItemType Directory -Path $VaultPath -Force | Out-Null
        New-Item -ItemType Directory -Path "$VaultPath\media" -Force | Out-Null
        New-Item -ItemType Directory -Path "$VaultPath\manifests" -Force | Out-Null
        
        # Vault config basique
        $vaultConfig = @{
            version = "1.0"
            name = "Demo Vault"
            created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            encryption = @{
                algorithm = "AES-256-GCM"
                keyDerivation = "PBKDF2"
            }
            mediaCount = 0
        } | ConvertTo-Json -Depth 3
        
        $vaultConfig | Out-File "$VaultPath\vault.json" -Encoding UTF8
        
        # Index vide
        @{
            media = @()
            playlists = @()
            lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        } | ConvertTo-Json -Depth 3 | Out-File "$VaultPath\index.json" -Encoding UTF8
        
        Write-Host "✅ Vault demo créé: $VaultPath" -ForegroundColor Green
    }
}

# 3. Ajout média de test si disponible
if ($CreateSampleVault -and (Test-Path ".\src\assets\demo.mp4")) {
    Write-Host "`n3. 🎬 Ajout média de démonstration..." -ForegroundColor Yellow
    
    if (Test-Path ".\tools\packager\pack.js") {
        try {
            & node .\tools\packager\pack.js add-media --vault $VaultPath --file ".\src\assets\demo.mp4" --title "Vidéo de démonstration" --artist "USB Video Vault"
            Write-Host "✅ Média de demo ajouté" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Erreur ajout média: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  Packager non disponible" -ForegroundColor Yellow
    }
}

# 4. Lancement application si demandé
if ($ShowUI) {
    Write-Host "`n4. 🚀 Lancement application..." -ForegroundColor Yellow
    
    try {
        # Lancer l'app en mode démo si vault créé
        if ($CreateSampleVault -and (Test-Path $VaultPath)) {
            Write-Host "   📁 Ouverture avec vault demo: $VaultPath" -ForegroundColor Blue
            Start-Process $appPath -ArgumentList "--vault-path=`"$VaultPath`"" -WindowStyle Normal
        } else {
            Write-Host "   🎯 Lancement normal" -ForegroundColor Blue
            Start-Process $appPath -WindowStyle Normal
        }
        
        # Attendre que l'app se lance
        Start-Sleep -Seconds 3
        
        # Vérifier si l'app est lancée
        $process = Get-Process | Where-Object {$_.ProcessName -like "*USB Video Vault*" -or $_.MainWindowTitle -like "*USB Video Vault*"}
        if ($process) {
            Write-Host "✅ Application lancée (PID: $($process.Id))" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Application peut-être en cours de lancement..." -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "❌ Erreur lancement: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   💡 Vérifier que l'application n'est pas déjà lancée" -ForegroundColor Yellow
    }
}

# 5. Test de lecture si demandé et vault disponible
if ($TestPlayback -and (Test-Path "$VaultPath\index.json")) {
    Write-Host "`n5. ⏯️ Test de lecture..." -ForegroundColor Yellow
    
    try {
        $index = Get-Content "$VaultPath\index.json" | ConvertFrom-Json
        if ($index.media -and $index.media.Count -gt 0) {
            $firstMedia = $index.media[0]
            Write-Host "   🎬 Média trouvé: $($firstMedia.title)" -ForegroundColor Blue
            Write-Host "   ⏯️  Test de lecture automatique..." -ForegroundColor Blue
            
            # Ici vous pourriez déclencher la lecture via IPC si l'API le permet
            # Pour l'instant, juste afficher les infos
            Write-Host "   📊 Durée: $($firstMedia.duration)s" -ForegroundColor Gray
            Write-Host "   📏 Taille: $([math]::Round($firstMedia.fileSize/1MB,1))MB" -ForegroundColor Gray
            Write-Host "   ✅ Média prêt pour lecture" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Aucun média dans le vault" -ForegroundColor Yellow
            Write-Host "   💡 Relancer avec -CreateSampleVault pour ajouter du contenu" -ForegroundColor Blue
        }
    } catch {
        Write-Host "   ❌ Erreur lecture index: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 6. Infos post-demo
Write-Host "`n=== DEMO TERMINÉE ===" -ForegroundColor Green
Write-Host ""
Write-Host "📱 Application:" -ForegroundColor Blue
Write-Host "   • Chemin: $appPath" -ForegroundColor White
if ($ShowUI) {
    Write-Host "   • Status: Lancée" -ForegroundColor Green
} else {
    Write-Host "   • Status: Prête à lancer" -ForegroundColor Yellow
}

if ($CreateSampleVault) {
    Write-Host "`n📁 Vault Demo:" -ForegroundColor Blue
    Write-Host "   • Chemin: $VaultPath" -ForegroundColor White
    if (Test-Path "$VaultPath\index.json") {
        $index = Get-Content "$VaultPath\index.json" | ConvertFrom-Json
        Write-Host "   • Médias: $($index.media.Count)" -ForegroundColor White
    }
}

Write-Host "`n🎯 Actions suggérées:" -ForegroundColor Blue
if (-not $ShowUI) {
    Write-Host "   • Lancer l'interface: .\demo-quick.ps1 -ShowUI" -ForegroundColor White
}
if (-not $CreateSampleVault) {
    Write-Host "   • Créer vault demo: .\demo-quick.ps1 -CreateSampleVault" -ForegroundColor White
}
Write-Host "   • Tests complets: .\tools\troubleshoot.ps1 -RunAllTests" -ForegroundColor White
Write-Host "   • Documentation: .\docs\README.md" -ForegroundColor White

Write-Host ""
Write-Host "💡 Pour fermer l'application: Alt+F4 ou fermer la fenêtre" -ForegroundColor Gray