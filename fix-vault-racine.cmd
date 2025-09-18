@echo off
echo === FIX RAPIDE VAULT RACINE ===

echo 1. Suppression anciens medias...
del /Q "vault\media\*.enc" 2>nul

echo 2. Suppression ancien manifest...
del /Q "vault\.vault\manifest.bin" 2>nul
del /Q "vault\.vault\manifest.dev.json" 2>nul
del /Q "vault\.vault\license.bin" 2>nul

echo 3. Reconstruction manifest vide...
node tools/packager/pack.js init --vault vault

echo 4. Generation licence vide...
for /f %%i in ('type vault\.vault\device.tag') do set DEVICE_TAG=%%i
node tools/packager/pack.js issue-license --vault vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "%DEVICE_TAG%" --all

echo 5. Verification...
dir /b vault\media 2>nul

echo.
echo Vault racine reconstruit !
echo L'app devrait maintenant detecter le vault dans la racine.
pause
