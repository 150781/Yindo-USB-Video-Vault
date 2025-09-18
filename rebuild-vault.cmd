@echo off
echo === RECONSTRUCTION VAULT ===

echo 1. Nettoyage vault...
node clean-vault.js

echo.
echo 2. Reconstruction manifest...
node tools/packager/pack.js init --vault usb-package/vault

echo.
echo 3. Ajout des medias...
node tools/packager/pack.js add-media --vault usb-package/vault --auto

echo.
echo 4. Generation licence...
for /f %%i in ('type usb-package\vault\.vault\device.tag') do set DEVICE_TAG=%%i
node tools/packager/pack.js issue-license --vault usb-package/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "%DEVICE_TAG%" --all

echo.
echo 5. Verification...
dir /b usb-package\vault\media
echo.
echo ✅ Vault reconstruit!
echo ➡️  Relancez l'app avec: npm run dev
pause
