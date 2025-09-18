@echo off
echo === SYNCHRONISATION CLÉS AUTOMATIQUE ===

echo 1. Fermeture app...
taskkill /f /im "USB-Video-Vault-0.1.0-portable.exe" 2>nul

echo 2. Nettoyage vault...
del /q "usb-package\vault\.vault\*" 2>nul
del /q "usb-package\vault\media\*" 2>nul

echo 3. Initialisation vault...
node tools/packager/pack.js init --vault usb-package/vault

echo 4. Generation licence test123...
for /f %%i in ('type usb-package\vault\.vault\device.tag') do set DEVICE_TAG=%%i
node tools/packager/pack.js issue-license --vault usb-package/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "%DEVICE_TAG%" --all

echo 5. Compilation...
npm run build:main

echo 6. Copie executable...
copy /y "dist\USB-Video-Vault-0.1.0-portable.exe" "usb-package\"

echo 7. Lancement app...
cd usb-package
start USB-Video-Vault-0.1.0-portable.exe
cd ..

echo.
echo ✅ SYNC TERMINÉ !
echo ➡️  Mot de passe: test123
pause
