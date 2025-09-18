# Script de rebuild avec VAULT_PATH
$env:VAULT_PATH = "C:\Users\patok\Documents\Yindo-USB-Video-Vault\usb-package\vault"
Write-Host "🔧 Rebuild renderer avec styles anti-scrollbar..." -ForegroundColor Cyan
npm run build:renderer
