# Script de reconstruction du manifest avec genres
$env:VAULT_PATH = "C:\Users\patok\Documents\Yindo-USB-Video-Vault\usb-package\vault"
Write-Host "🎬 Reconstruction du manifest avec genres..." -ForegroundColor Cyan

Write-Host "1. Build manifest..."
node tools/packager/pack.js build-manifest --vault usb-package/vault

Write-Host "2. Seal manifest..."
node tools/packager/pack.js seal-manifest --vault usb-package/vault

Write-Host "✅ Manifest mis à jour avec métadonnées!" -ForegroundColor Green
