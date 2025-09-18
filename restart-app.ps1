# Script de redémarrage avec le bon VAULT_PATH

Write-Host "🔄 Redémarrage de l'application avec le vault correct" -ForegroundColor Green

# Arrêt des processus existants
Write-Host "1. Arrêt des processus existants..."
taskkill /f /im node.exe /im electron.exe 2>$null | Out-Null
Start-Sleep -Seconds 2

# Configuration du VAULT_PATH
$env:VAULT_PATH = "C:\Users\patok\Documents\Yindo-USB-Video-Vault\usb-package\vault"
Write-Host "2. VAULT_PATH défini sur: $env:VAULT_PATH" -ForegroundColor Yellow

# Vérification que le vault existe
$vaultPath = $env:VAULT_PATH
$deviceTagPath = Join-Path $vaultPath ".vault\device.tag"

if (Test-Path $deviceTagPath) {
    Write-Host "✅ Vault trouvé: $deviceTagPath" -ForegroundColor Green
    
    # Reconstruction du main process
    Write-Host "3. Reconstruction du main process..."
    npm run build:main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Build réussi" -ForegroundColor Green
        
        # Démarrage de l'application
        Write-Host "4. Démarrage de l'application..." -ForegroundColor Cyan
        npm run dev
    } else {
        Write-Host "❌ Erreur lors du build" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Vault non trouvé: $deviceTagPath" -ForegroundColor Red
    Write-Host "Contenu du dossier usb-package:" -ForegroundColor Yellow
    Get-ChildItem "C:\Users\patok\Documents\Yindo-USB-Video-Vault\usb-package" -Force
}
