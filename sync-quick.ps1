#!/usr/bin/env pwsh
# Script de synchronisation rapide après modification de clé publique

Write-Host "=== SYNC RAPIDE CLÉS ===" -ForegroundColor Yellow

$VAULT_DIR = "usb-package\vault"

Write-Host "1. Nettoyage vault existant..." -ForegroundColor Cyan
Remove-Item "$VAULT_DIR\.vault\*" -Force -ErrorAction SilentlyContinue
Remove-Item "$VAULT_DIR\media\*" -Force -ErrorAction SilentlyContinue

Write-Host "2. Initialisation avec nouvelle clé..." -ForegroundColor Cyan
& node tools/packager/pack.js init --vault $VAULT_DIR

Write-Host "3. Génération licence test123..." -ForegroundColor Cyan
$deviceTag = Get-Content "$VAULT_DIR\.vault\device.tag" -Raw
$deviceTag = $deviceTag.Trim()
& node tools/packager/pack.js issue-license --vault $VAULT_DIR --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine $deviceTag --all

Write-Host "4. Compilation et repackaging..." -ForegroundColor Cyan
& npm run build:main
& Copy-Item "dist\USB-Video-Vault-0.1.0-portable.exe" "usb-package\" -Force

Write-Host "5. Lancement app..." -ForegroundColor Green
Set-Location "usb-package"
Start-Process "USB-Video-Vault-0.1.0-portable.exe" -NoNewWindow
Set-Location ".."

Write-Host "`n✅ SYNC TERMINÉ !" -ForegroundColor Green
Write-Host "➡️  Utilisez le mot de passe: test123" -ForegroundColor Yellow
