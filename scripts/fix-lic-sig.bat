@echo off
REM === Séquence rapide de diagnostic et synchronisation LIC-SIG ===
cd /d "c:\Users\patok\Documents\Yindo-USB-Video-Vault"

echo === 1) Vérification des empreintes des clés ===
node scripts/keys/fingerprint.cjs
if errorlevel 1 goto error

echo.
echo === 2) Si mismatch détecté, synchronisation ===
echo Appuyez sur Entrée pour synchroniser, ou Ctrl+C pour annuler...
pause >nul

node scripts/keys/sync-public-key-to-app.cjs
if errorlevel 1 goto error

echo.
echo === 3) Rebuild du main ===
npm run build:main
if errorlevel 1 goto error

echo.
echo === 4) Vérification des clés après sync ===
node scripts/keys/fingerprint.cjs

echo.
echo === 5) Vérification de la licence ===
if not defined VAULT_PATH set VAULT_PATH=usb-package\vault
echo Vault utilisé: %VAULT_PATH%
node tools/packager/verify-license.cjs "%VAULT_PATH%"

echo.
echo === 6) Si licence invalide, régénération ===
echo Appuyez sur Entrée pour régénérer la licence, ou Ctrl+C pour passer...
pause >nul

REM Obtenir l'ID machine
for /f %%i in ('node -e "console.log(require('node-machine-id').machineIdSync())"') do set MACHINE_ID=%%i
echo Machine ID: %MACHINE_ID%

REM Régénérer la licence
node tools/packager/pack.js issue-license --vault "%VAULT_PATH%" --machine "%MACHINE_ID%" --expiry 2026-12-31 --owner "Test User" --passphrase "test123" --all
if errorlevel 1 goto error

echo.
echo === 7) Vérification finale ===
node tools/packager/verify-license.cjs "%VAULT_PATH%"

echo.
echo === 8) Test de connexion ===
npm run build:main >nul
set VAULT_PATH=%VAULT_PATH%
node -e "const license = require('./dist/main/license.js'); (async () => { try { console.log('Test connexion avec test123...'); const result = await license.enterLicensePassphrase('test123'); console.log('Résultat:', result.ok ? '✅ SUCCÈS' : '❌ ÉCHEC'); if (!result.ok && result.error) { console.log('Détail erreur:', result.error); } } catch (e) { console.error('❌ Erreur:', e.message); } })();"

echo.
echo ✅ Diagnostic terminé!
goto end

:error
echo ❌ Erreur détectée - Arrêt du script
exit /b 1

:end
pause
