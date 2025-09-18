# Script manuel de reconstruction du vault
# 1. Copier l'exécutable portable
Copy-Item "dist\USB-Video-Vault-0.1.0-portable.exe" "usb-package-new\"

# 2. Supprimer et recréer le vault
Remove-Item "usb-package-new\vault" -Recurse -Force -ErrorAction SilentlyContinue

# 3. Initialiser un nouveau vault
node tools/packager/pack.js init --vault usb-package-new/vault

# 4. Ajouter les médias
node tools/packager/pack.js add-media --vault usb-package-new/vault --file "src/assets/demo.mp4" --title "Demo Video" --artist "Test Artist"
node tools/packager/pack.js add-media --vault usb-package-new/vault --file "src/assets/Odogwu.mp4" --title "Odogwu" --artist "Burna Boy"

# 5. Construire le manifest
node tools/packager/pack.js build-manifest --vault usb-package-new/vault

# 6. Sceller le manifest
node tools/packager/pack.js seal-manifest --vault usb-package-new/vault

# 7. Générer la licence
node tools/packager/pack.js issue-license --vault usb-package-new/vault --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "928fb2e42e9de3a9e7305842ef114ae7ef35cb2e7e8003a37da07fd410e45bc5" --all

# 8. Remplacer l'ancien package
Remove-Item "usb-package" -Recurse -Force -ErrorAction SilentlyContinue
Rename-Item "usb-package-new" "usb-package"
