#!/usr/bin/env pwsh

# Script PowerShell pour reconstruire le vault
Write-Host "=== Reconstruction du vault ===" -ForegroundColor Green

# Supprimer l'ancien vault
Write-Host "1. Suppression de l'ancien vault..." -ForegroundColor Yellow
Remove-Item "usb-package\vault" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "   ✅ Ancien vault supprimé" -ForegroundColor Green

# Reconstruire l'application
Write-Host "2. Reconstruction de l'application..." -ForegroundColor Yellow
npm run build | Out-Null
Write-Host "   ✅ Application reconstruite" -ForegroundColor Green

# Créer le package USB
Write-Host "3. Création du package USB..." -ForegroundColor Yellow
npm run package:usb | Out-Null
Write-Host "   ✅ Package USB créé" -ForegroundColor Green

Write-Host "=== Reconstruction terminée ! ===" -ForegroundColor Green
Write-Host "Vous pouvez maintenant tester l'application avec le mot de passe: test123" -ForegroundColor Cyan
