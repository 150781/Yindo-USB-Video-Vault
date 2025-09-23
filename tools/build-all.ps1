# Script de build complet USB Video Vault
# Usage: .\tools\build-all.ps1 [-Sign] [-CertPath "path"] [-CertPassword "pwd"]

param(
    [switch]$Sign,
    [string]$CertPath,
    [string]$CertPassword
)

Write-Host "=== Build USB Video Vault ===" -ForegroundColor Cyan
Write-Host "Version: $((Get-Content package.json | ConvertFrom-Json).version)"

# Étape 1: Clean & Install
Write-Host "`n1. Installation des dépendances..." -ForegroundColor Yellow
npm ci
if ($LASTEXITCODE -ne 0) {
    Write-Error "Erreur lors de npm ci"
    exit 1
}

# Étape 2: Build
Write-Host "`n2. Build de l'application..." -ForegroundColor Yellow
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Erreur lors du build"
    exit 1
}

# Étape 3: Electron Builder
Write-Host "`n3. Génération des binaires..." -ForegroundColor Yellow
npx electron-builder --win nsis portable --publish never
if ($LASTEXITCODE -ne 0) {
    Write-Error "Erreur lors d'electron-builder"
    exit 1
}

# Étape 4: Signature (optionnelle)
if ($Sign -and $CertPath -and $CertPassword) {
    Write-Host "`n4. Signature des binaires..." -ForegroundColor Yellow
    .\tools\sign-local.ps1 -CertPath $CertPath -Password $CertPassword
} elseif ($Sign) {
    Write-Warning "Signature demandée mais certificat non fourni"
    Write-Host "Usage: .\tools\build-all.ps1 -Sign -CertPath 'cert.pfx' -CertPassword 'password'"
}

# Résumé
Write-Host "`n=== Build terminé ===" -ForegroundColor Green
Write-Host "Fichiers générés dans dist/:"

if (Test-Path "dist") {
    Get-ChildItem "dist" -Filter "*.exe" | ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 1)
        Write-Host "  - $($_.Name) ($size MB)"
    }
} else {
    Write-Warning "Dossier dist introuvable"
}

Write-Host "`nPour tester:" -ForegroundColor Cyan
Write-Host "  - Portable: double-clic sur USB Video Vault *.exe"
Write-Host "  - Installateur: exécuter USB Video Vault Setup *.exe"