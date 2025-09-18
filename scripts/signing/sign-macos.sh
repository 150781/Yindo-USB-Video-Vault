#!/bin/bash
# 🍎 Signature macOS (codesign + notarization)
# Requires: Xcode, Developer ID Certificate, App-Specific Password

set -e

APP_PATH="${1:-dist/mac/USB-Video-Vault.app}"
ZIP_PATH="${APP_PATH%.*}.zip"
DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: USB VIDEO VAULT (TEAMID)}"
APPLE_ID="${APPLE_ID:-support@usbvideovault.com}"
TEAM_ID="${TEAM_ID:-TEAMID}"

echo "🍎 === SIGNATURE MACOS (CODESIGN + NOTARIZE) ==="

# Vérifications prérequis
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle introuvable: $APP_PATH"
    exit 1
fi

if [ -z "$NOTARY_PASSWORD" ]; then
    echo "❌ Variable NOTARY_PASSWORD non définie"
    echo "💡 Créer un App-Specific Password sur appleid.apple.com"
    exit 1
fi

# 1. Code Signing
echo "🖊️ Signature de l'application..."
codesign --deep --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID" \
    "$APP_PATH"

echo "✅ Signature codesign terminée"

# 2. Vérification signature
echo "🔍 Vérification de la signature..."
codesign --verify --verbose=2 "$APP_PATH"
echo "✅ Signature vérifiée"

# 3. Création du ZIP pour notarization
echo "📦 Création du ZIP pour notarization..."
if [ -f "$ZIP_PATH" ]; then
    rm "$ZIP_PATH"
fi
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "✅ ZIP créé: $ZIP_PATH"

# 4. Notarization Apple
echo "🍎 Soumission pour notarization Apple..."
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$NOTARY_PASSWORD" \
    --wait

if [ $? -ne 0 ]; then
    echo "❌ Notarization échouée"
    exit 1
fi

echo "✅ Notarization réussie"

# 5. Stapling
echo "📎 Stapling du ticket de notarization..."
xcrun stapler staple "$APP_PATH"
echo "✅ Stapling terminé"

# 6. Vérification finale
echo "🔍 Vérification finale..."
spctl --assess --verbose=2 "$APP_PATH"
echo "✅ App prête pour distribution"

# 7. Création DMG final (optionnel)
DMG_PATH="${APP_PATH%/*}/USB-Video-Vault-$(date +%Y%m%d).dmg"
echo "💿 Création du DMG: $DMG_PATH"
hdiutil create -volname "USB Video Vault" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"

# 8. Hash final
echo "📊 Génération hash SHA256..."
shasum -a 256 "$DMG_PATH"

echo "🎉 Signature macOS terminée avec succès !"
echo "📁 Fichiers prêts:"
echo "   - App: $APP_PATH"
echo "   - DMG: $DMG_PATH"