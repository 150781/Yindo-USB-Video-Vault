#!/bin/bash
# 🐧 Signature Linux (GPG)
# Requires: GPG private key configured

set -e

APPIMAGE_PATH="${1:-dist/USB-Video-Vault-*.AppImage}"
GPG_KEY_ID="${GPG_KEY_ID:-USB_VIDEO_VAULT_SIGNING_KEY}"

echo "🐧 === SIGNATURE LINUX (GPG) ==="

# Vérifications prérequis
if ! ls $APPIMAGE_PATH 1> /dev/null 2>&1; then
    echo "❌ AppImage introuvable: $APPIMAGE_PATH"
    exit 1
fi

# Vérifier clé GPG
if ! gpg --list-secret-keys | grep -q "$GPG_KEY_ID"; then
    echo "❌ Clé GPG introuvable: $GPG_KEY_ID"
    echo "💡 Générer avec: gpg --full-generate-key"
    exit 1
fi

# Signature pour chaque AppImage trouvé
for appimage in $APPIMAGE_PATH; do
    if [ -f "$appimage" ]; then
        echo "🖊️ Signature de: $appimage"
        
        # Signature détachée
        gpg --detach-sign --armor --default-key "$GPG_KEY_ID" "$appimage"
        
        if [ $? -eq 0 ]; then
            echo "✅ Signature créée: ${appimage}.asc"
        else
            echo "❌ Erreur signature de $appimage"
            exit 1
        fi
        
        # Vérification
        echo "🔍 Vérification de la signature..."
        gpg --verify "${appimage}.asc" "$appimage"
        
        if [ $? -eq 0 ]; then
            echo "✅ Signature vérifiée pour $appimage"
        else
            echo "❌ Erreur vérification de $appimage"
            exit 1
        fi
        
        # Hash
        echo "📊 Hash SHA256 de $appimage:"
        shasum -a 256 "$appimage"
        
    fi
done

echo "🎉 Signature Linux terminée avec succès !"

# Afficher les clés publiques pour distribution
echo ""
echo "📋 Clé publique GPG (à distribuer avec les releases):"
echo "=================================================="
gpg --armor --export "$GPG_KEY_ID"
echo "=================================================="
echo ""
echo "💡 Les utilisateurs pourront vérifier avec:"
echo "   gpg --import public-key.asc"
echo "   gpg --verify USB-Video-Vault-*.AppImage.asc USB-Video-Vault-*.AppImage"