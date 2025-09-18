# Reconstruction complète du vault avec test123
Write-Host "=== Reconstruction vault avec nouvelles clés ===" -ForegroundColor Green

# Supprimer complètement usb-package
Write-Host "1. Suppression usb-package..." -ForegroundColor Yellow
if (Test-Path "usb-package") {
    Remove-Item "usb-package" -Recurse -Force
}

# Reconstruire l'app
Write-Host "2. Reconstruction app..." -ForegroundColor Yellow
npm run build | Out-Null

# Créer nouveau package USB
Write-Host "3. Création nouveau package..." -ForegroundColor Yellow
npm run package:usb | Out-Null

Write-Host "4. Test de la licence..." -ForegroundColor Yellow
$env:VAULT_PATH = "usb-package\vault"
node -e "
const license = require('./dist/main/license.js');
(async () => {
  try {
    const result = await license.enterLicensePassphrase('test123');
    console.log('test123:', result.ok ? 'SUCCÈS' : 'ÉCHEC');
    if (!result.ok && result.error) console.log('Erreur:', result.error);
  } catch (e) {
    console.log('ERREUR:', e.message);
  }
})();
"

Write-Host "=== Terminé ===" -ForegroundColor Green
