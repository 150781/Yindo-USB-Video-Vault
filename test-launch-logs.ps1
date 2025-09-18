#!/usr/bin/env pwsh

$env:VAULT_PATH = ".\usb-package\vault"
$env:NODE_ENV = "production"

Write-Host "🚀 Lancement de l'app avec capture des logs..."
Write-Host "📁 VAULT_PATH: $env:VAULT_PATH"

# Lancer l'app et capturer la sortie
$process = Start-Process -FilePath "node_modules\.bin\electron" -ArgumentList ".", "--no-sandbox" -RedirectStandardOutput "app-logs.txt" -RedirectStandardError "app-errors.txt" -NoNewWindow -PassThru

# Attendre un moment pour que l'app démarre
Start-Sleep -Seconds 3

# Terminer l'app
if (!$process.HasExited) {
    $process.Kill()
    Write-Host "✅ App terminée"
}

Write-Host "📄 Logs de démarrage:"
if (Test-Path "app-logs.txt") {
    Get-Content "app-logs.txt" | Where-Object { $_ -match "LICENSE|LIC" }
}

Write-Host "📄 Erreurs:"
if (Test-Path "app-errors.txt") {
    Get-Content "app-errors.txt" | Where-Object { $_ -match "LICENSE|LIC" }
}

# Nettoyage
Remove-Item -Force app-logs.txt, app-errors.txt -ErrorAction SilentlyContinue