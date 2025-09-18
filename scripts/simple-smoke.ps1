# Simple Smoke Test - USB Video Vault
param(
    [string]$ExePath = ".\dist\USB-Video-Vault-0.1.0-portable.exe"
)

Write-Host "🧪 === SMOKE TEST SIMPLE ===" -ForegroundColor Green

if (-not (Test-Path $ExePath)) {
    Write-Host "❌ Exécutable introuvable: $ExePath" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Exécutable: $ExePath" -ForegroundColor Cyan

try {
    Write-Host "🚀 Lancement..." -ForegroundColor Yellow
    
    $process = Start-Process -FilePath $ExePath -ArgumentList "--no-sandbox" -PassThru
    
    Write-Host "✅ Processus démarré (PID: $($process.Id))" -ForegroundColor Green
    Write-Host "⏳ Attente 5 secondes..." -ForegroundColor Yellow
    
    Start-Sleep -Seconds 5
    
    Write-Host "🛑 Fermeture..." -ForegroundColor Yellow
    $process | Stop-Process -Force
    
    Write-Host "✅ SMOKE TEST RÉUSSI - App démarre et se ferme correctement" -ForegroundColor Green
    
} catch {
    Write-Host "❌ ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}