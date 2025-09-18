#!/usr/bin/env pwsh

# Script de synchronisation automatique des clés cryptographiques
Write-Host "=== SYNCHRONISATION AUTOMATIQUE DES CLÉS ===" -ForegroundColor Cyan
Write-Host ""

# 1. Arrêter tous les processus
Write-Host "1. Arrêt des processus en cours..." -ForegroundColor Yellow
taskkill /f /im node.exe /im electron.exe 2>$null | Out-Null
Start-Sleep 2

# 2. Reconstruire avec la nouvelle clé publique
Write-Host "2. Reconstruction avec nouvelle clé publique..." -ForegroundColor Yellow
npm run build:main | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur lors de la compilation" -ForegroundColor Red
    exit 1
}

# 3. Supprimer l'ancien vault incompatible
Write-Host "3. Suppression ancien vault incompatible..." -ForegroundColor Yellow
Remove-Item "usb-package\vault" -Recurse -Force -ErrorAction SilentlyContinue

# 4. Créer nouveau vault avec clés synchronisées
Write-Host "4. Création nouveau vault..." -ForegroundColor Yellow
node tools/packager/pack.js init --vault usb-package/vault | Out-Null

# 5. Ajouter les médias
Write-Host "5. Ajout des médias..." -ForegroundColor Yellow
node tools/packager/pack.js add-media --vault usb-package/vault --file "src/assets/demo.mp4" --title "Demo Video" --artist "Test Artist" | Out-Null
node tools/packager/pack.js add-media --vault usb-package/vault --file "src/assets/Odogwu.mp4" --title "Odogwu" --artist "Burna Boy" | Out-Null

# 6. Construire et sceller le manifest
Write-Host "6. Construction du manifest..." -ForegroundColor Yellow
node tools/packager/pack.js build-manifest --vault usb-package/vault | Out-Null
node tools/packager/pack.js seal-manifest --vault usb-package/vault | Out-Null

# 7. Générer la licence avec les nouvelles clés
Write-Host "7. Génération licence avec clés synchronisées..." -ForegroundColor Yellow
node tools/packager/pack.js issue-license --vault usb-package/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "928fb2e42e9de3a9e7305842ef114ae7ef35cb2e7e8003a37da07fd410e45bc5" --all | Out-Null

# 8. Test de validation
Write-Host "8. Test de validation..." -ForegroundColor Yellow
$env:VAULT_PATH = "usb-package\vault"
$testResult = node -e "
const license = require('./dist/main/license.js');
(async () => {
  try {
    const result = await license.enterLicensePassphrase('test123');
    console.log(result.ok ? 'SUCCESS' : 'FAIL');
  } catch (e) {
    console.log('ERROR');
  }
})();
" 2>$null

if ($testResult -eq "SUCCESS") {
    Write-Host "✅ Licence valide - Synchronisation réussie!" -ForegroundColor Green
} else {
    Write-Host "❌ Licence toujours invalide" -ForegroundColor Red
}

# 9. Relancer l'application
Write-Host "9. Relancement de l'application..." -ForegroundColor Yellow
Write-Host ""
Write-Host "🚀 Application prête avec mot de passe: test123" -ForegroundColor Green
Write-Host ""

$env:VAULT_PATH = "usb-package\vault"
npm run dev
