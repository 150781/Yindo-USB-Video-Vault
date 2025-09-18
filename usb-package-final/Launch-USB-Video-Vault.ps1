# === Yindo USB Video Vault ===
Write-Host "=== Yindo USB Video Vault ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Lancement de l'application..." -ForegroundColor Green
Write-Host ""

# Définir le vault local
$env:VAULT_PATH = "$PSScriptRoot\vault"

# Lancer l'application portable
& "$PSScriptRoot\USB-Video-Vault.exe" --no-sandbox

Write-Host ""
Write-Host "Application fermée." -ForegroundColor Yellow
Read-Host "Appuyez sur Entrée pour continuer"
