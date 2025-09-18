@echo off
echo === FIX VAULT 404 ===

echo Verification vault...
if not exist "usb-package\vault" (
    echo ERREUR: Vault introuvable
    pause
    exit /b 1
)

echo Contenu vault:
dir /b usb-package\vault

echo Contenu media:
if exist "usb-package\vault\media" (
    dir /b usb-package\vault\media
) else (
    echo Dossier media introuvable, creation...
    mkdir "usb-package\vault\media"
)

echo Copie fichiers test...
if exist "src\assets\demo.mp4" (
    copy "src\assets\demo.mp4" "usb-package\vault\media\" >nul
    echo demo.mp4 copie
)
if exist "src\assets\Odogwu.mp4" (
    copy "src\assets\Odogwu.mp4" "usb-package\vault\media\" >nul
    echo Odogwu.mp4 copie
)

echo Reconstruction manifest...
node tools/packager/pack.js init --vault usb-package\vault
node tools/packager/pack.js add-media --vault usb-package\vault --auto
node tools/packager/pack.js issue-license --vault usb-package\vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "928fb2e42e9de3a9e7305842ef114ae7ef35cb2e7e8003a37da07fd410e45bc5" --all

echo Vault repare! Redemarrez l'app.
pause
