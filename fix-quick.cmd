@echo off
echo === FIX RAPIDE VAULT 404 ===

echo 1. Suppression anciens medias...
del /Q "usb-package\vault\media\*.enc" 2>nul

echo 2. Suppression ancien manifest...
del /Q "usb-package\vault\.vault\manifest.bin" 2>nul
del /Q "usb-package\vault\.vault\manifest.dev.json" 2>nul
del /Q "usb-package\vault\.vault\license.bin" 2>nul

echo 3. Reconstruction manifest vide...
node tools/packager/pack.js init --vault usb-package/vault

echo 4. Generation licence vide...
for /f %%i in ('type usb-package\vault\.vault\device.tag') do set DEVICE_TAG=%%i
node tools/packager/pack.js issue-license --vault usb-package/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "%DEVICE_TAG%" --all

echo 5. Verification...
dir /b usb-package\vault\media 2>nul
if errorlevel 1 echo   (aucun fichier media - normal)

echo.
echo ✅ Vault vide reconstitué! 
echo ➡️  L'app devrait maintenant se lancer sans erreur 404.
echo ➡️  Vous pourrez ajouter des médias via l'interface.
echo.
echo Lancement de l'app...
cd usb-package
start USB-Video-Vault-0.1.0-portable.exe
cd ..
