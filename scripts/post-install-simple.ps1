# Script post-install simple pour USB Video Vault
# Copie la licence vers le vault selon votre spécification

param(
    [string]$LicenseSource = ".\out\license.bin"
)

Write-Host "=== Installation de la licence USB Video Vault ===" -ForegroundColor Cyan

# Déterminer le chemin du vault
$v = $env:VAULT_PATH
if (-not $v) {
    $v = Join-Path $env:USERPROFILE "Documents\Yindo-USB-Video-Vault\vault-real"
    Write-Host "Utilisation du chemin par défaut: $v" -ForegroundColor Yellow
} else {
    Write-Host "Utilisation de VAULT_PATH: $v" -ForegroundColor Green
}

# Créer le répertoire .vault s'il n'existe pas
$vaultConfigDir = Join-Path $v ".vault"
Write-Host "Création du répertoire: $vaultConfigDir" -ForegroundColor White
New-Item -ItemType Directory -Force -Path $vaultConfigDir | Out-Null

# Vérifier que le fichier licence source existe
if (-not (Test-Path $LicenseSource)) {
    Write-Host "❌ Fichier licence source introuvable: $LicenseSource" -ForegroundColor Red
    Write-Host "   Vérifiez que le fichier existe ou spécifiez le bon chemin avec -LicenseSource" -ForegroundColor Yellow
    exit 1
}

# Copier la licence
$targetLicense = Join-Path $vaultConfigDir "license.bin"
Write-Host "Copie de la licence: $LicenseSource → $targetLicense" -ForegroundColor White
Copy-Item $LicenseSource $targetLicense -Force

# Vérifier la copie
if (Test-Path $targetLicense) {
    $licenseSize = (Get-Item $targetLicense).Length
    Write-Host "✅ Licence installée avec succès: $targetLicense ($licenseSize bytes)" -ForegroundColor Green
    
    # Définir VAULT_PATH si ce n'était pas déjà fait
    if (-not $env:VAULT_PATH) {
        Write-Host "Définition de la variable d'environnement VAULT_PATH..." -ForegroundColor White
        [Environment]::SetEnvironmentVariable("VAULT_PATH", $v, "User")
        $env:VAULT_PATH = $v
        Write-Host "✅ VAULT_PATH défini: $v" -ForegroundColor Green
        Write-Host "⚠️  Redémarrez votre terminal pour prendre en compte VAULT_PATH" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🎉 Installation terminée!" -ForegroundColor Green
    Write-Host "   Vault: $v" -ForegroundColor White
    Write-Host "   Licence: $targetLicense" -ForegroundColor White
    
} else {
    Write-Host "❌ Échec de l'installation de la licence" -ForegroundColor Red
    exit 1
}