@echo off
echo === Reconstruction complete du vault avec nouvelles cles ===
echo.

echo 1. Suppression ancien vault...
rmdir /s /q "usb-package\vault" 2>nul
echo    Ancien vault supprime

echo 2. Reconstruction de l'application...
call npm run build:main
echo    Build main termine

echo 3. Initialisation nouveau vault...
node tools/packager/pack.js init --vault usb-package/vault
echo    Vault initialise

echo 4. Ajout des medias...
node tools/packager/pack.js add-media --vault usb-package/vault --file "src/assets/demo.mp4" --title "Demo Video" --artist "Test Artist"
node tools/packager/pack.js add-media --vault usb-package/vault --file "src/assets/Odogwu.mp4" --title "Odogwu" --artist "Burna Boy"
echo    Medias ajoutes

echo 5. Construction du manifest...
node tools/packager/pack.js build-manifest --vault usb-package/vault
echo    Manifest construit

echo 6. Scellement du manifest...
node tools/packager/pack.js seal-manifest --vault usb-package/vault
echo    Manifest scelle

echo 7. Generation nouvelle licence...
node tools/packager/pack.js issue-license --vault usb-package/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "928fb2e42e9de3a9e7305842ef114ae7ef35cb2e7e8003a37da07fd410e45bc5" --all
echo    Licence generee

echo 8. Test de la licence...
set VAULT_PATH=usb-package\vault
node -e "const license = require('./dist/main/license.js'); (async () => { try { const result = await license.enterLicensePassphrase('test123'); console.log('Test test123:', result.ok ? 'SUCCES' : 'ECHEC'); } catch (e) { console.log('ERREUR:', e.message); }})();"

echo.
echo === Reconstruction terminee ! ===
echo Mot de passe: test123
pause
