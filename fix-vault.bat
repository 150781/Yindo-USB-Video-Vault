@echo off
echo === Reconstruction du vault pour corriger l'erreur cryptographique ===
echo.

echo 1. Suppression du vault existant...
rmdir /s /q "usb-package\vault" 2>nul
echo    Vault supprime

echo 2. Initialisation du nouveau vault...
node tools/packager/pack.js init --vault usb-package/vault
echo    Vault initialise

echo 3. Ajout des medias...
node tools/packager/pack.js add-media --vault usb-package/vault --file "src/assets/demo.mp4" --title "Demo Video" --artist "Test Artist"
node tools/packager/pack.js add-media --vault usb-package/vault --file "src/assets/Odogwu.mp4" --title "Odogwu" --artist "Burna Boy"
echo    Medias ajoutes

echo 4. Construction du manifest...
node tools/packager/pack.js build-manifest --vault usb-package/vault
echo    Manifest construit

echo 5. Scellement du manifest...
node tools/packager/pack.js seal-manifest --vault usb-package/vault
echo    Manifest scelle

echo 6. Generation de la licence...
node tools/packager/pack.js issue-license --vault usb-package/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "928fb2e42e9de3a9e7305842ef114ae7ef35cb2e7e8003a37da07fd410e45bc5" --all
echo    Licence generee

echo.
echo === Vault reconstruit avec succes ! ===
echo Mot de passe: test123
pause
