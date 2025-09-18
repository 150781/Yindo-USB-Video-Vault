$env:VAULT_PATH = ".\usb-package\vault"
$env:NODE_ENV = "production"

Write-Host "Lancement de l'app..."
Write-Host "VAULT_PATH: $env:VAULT_PATH"

npx electron . --no-sandbox *> app-output.txt
Start-Sleep -Seconds 4

Write-Host "Logs:"
if (Test-Path app-output.txt) {
    Get-Content app-output.txt | Select-String "LICENSE"
}

Remove-Item app-output.txt -ErrorAction SilentlyContinue