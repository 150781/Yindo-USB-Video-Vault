# Pipeline de Notarisation macOS Complète
# USB Video Vault - Documentation Pipeline Notarisation

## Vue d'ensemble

Ce document décrit la pipeline complète de notarisation macOS pour USB Video Vault, incluant la signature, la notarisation automatisée, et la validation.

## Scripts Disponibles

### 1. Signature (`scripts/macos-sign.sh`)
```bash
# Signature basique
./scripts/macos-sign.sh

# Signature avec certificat spécifique
./scripts/macos-sign.sh --identity "Developer ID Application: Yindo (TEAMID)"

# Signature avec verification
./scripts/macos-sign.sh --verify
```

### 2. Notarisation (`scripts/macos-notarize.sh`)
```bash
# Notarisation complète
export APPLE_ID="votre@email.com"
export APPLE_ID_PASSWORD="abcd-efgh-ijkl-mnop"  # App-specific password
export TEAM_ID="VOTRE_TEAM_ID"
./scripts/macos-notarize.sh

# Vérifier statut d'une soumission
./scripts/macos-notarize.sh --check-status "uuid-de-soumission"

# Attendre une soumission en cours
./scripts/macos-notarize.sh --wait-only
```

## Workflow CI/CD

### GitHub Actions Workflow

```yaml
# .github/workflows/macos-notarize.yml
name: macOS Build and Notarize

on:
  push:
    tags: ['v*']
  workflow_dispatch:

jobs:
  build-and-notarize:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Build application
      run: npm run build:mac
    
    - name: Import certificates
      env:
        BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
        P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
        KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
      run: |
        # Créer keychain temporaire
        echo $BUILD_CERTIFICATE_BASE64 | base64 --decode > certificate.p12
        security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
        security default-keychain -s build.keychain
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
        security import certificate.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain
    
    - name: Sign application
      run: |
        chmod +x scripts/macos-sign.sh
        ./scripts/macos-sign.sh --identity "Developer ID Application: ${{ secrets.SIGNING_IDENTITY }}"
    
    - name: Notarize application
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
        TEAM_ID: ${{ secrets.TEAM_ID }}
      run: |
        chmod +x scripts/macos-notarize.sh
        ./scripts/macos-notarize.sh --verbose
    
    - name: Create DMG
      run: |
        npm run package:mac:dmg
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v4
      with:
        name: macos-notarized
        path: |
          dist/USB Video Vault-*.dmg
          build/notarization-report-*.txt
```

## Secrets GitHub Actions

### Secrets requis

```bash
# Certificats de signature
BUILD_CERTIFICATE_BASE64=    # Certificat .p12 encodé en base64
P12_PASSWORD=               # Mot de passe du certificat .p12
KEYCHAIN_PASSWORD=          # Mot de passe keychain temporaire
SIGNING_IDENTITY=           # Nom complet du certificat

# Notarisation Apple
APPLE_ID=                   # Email Apple ID
APPLE_ID_PASSWORD=          # App-specific password
TEAM_ID=                    # Team ID Apple Developer
```

### Génération des secrets

```bash
# Encoder le certificat .p12
base64 -i certificate.p12 -o certificate.txt

# Créer app-specific password
# 1. Aller sur appleid.apple.com
# 2. Se connecter
# 3. Sécurité > Mots de passe app
# 4. Générer un nouveau mot de passe
# 5. Utiliser le format: abcd-efgh-ijkl-mnop
```

## Validation Locale

### Test complet local

```bash
# 1. Build
npm run build:mac

# 2. Signature
export SIGNING_IDENTITY="Developer ID Application: Votre Nom (TEAMID)"
./scripts/macos-sign.sh --identity "$SIGNING_IDENTITY" --verify

# 3. Notarisation
export APPLE_ID="votre@email.com"
export APPLE_ID_PASSWORD="abcd-efgh-ijkl-mnop"
export TEAM_ID="VOTRE_TEAM_ID"
./scripts/macos-notarize.sh --verbose

# 4. Test Gatekeeper
spctl --assess --type execute --verbose "dist/mac/USB Video Vault.app"

# 5. Test d'installation utilisateur
open "dist/mac/USB Video Vault.app"
```

## Troubleshooting

### Erreurs Communes

#### 1. Certificat non trouvé
```bash
# Lister les certificats disponibles
security find-identity -v -p codesigning

# Vérifier keychain
security list-keychains
```

#### 2. Échec de notarisation
```bash
# Vérifier soumission
./scripts/macos-notarize.sh --check-status "uuid"

# Obtenir détails d'échec
xcrun altool --notarization-info "uuid" \
  --username "$APPLE_ID" \
  --password "$APPLE_ID_PASSWORD"
```

#### 3. Gatekeeper refuse l'app
```bash
# Forcer re-évaluation
sudo spctl --master-disable
sudo spctl --master-enable

# Vérifier signature
codesign -dv --verbose=4 "app-path"
```

### Logs et Diagnostics

```bash
# Logs de signature
./scripts/macos-sign.sh --verbose > sign.log 2>&1

# Logs de notarisation
./scripts/macos-notarize.sh --verbose > notarize.log 2>&1

# Vérifier état système
spctl --status
sudo log show --predicate 'subsystem == "com.apple.syspolicy"' --last 1h
```

## Automatisation Production

### Script d'orchestration

```bash
#!/bin/bash
# scripts/build-and-notarize-complete.sh

set -e

echo "🚀 Build et Notarisation Complète - USB Video Vault"
echo "=================================================="

# 1. Build
echo "📦 Build de l'application..."
npm run build:mac

# 2. Signature
echo "✍️ Signature de l'application..."
./scripts/macos-sign.sh --verify

# 3. Notarisation
echo "📋 Notarisation Apple..."
./scripts/macos-notarize.sh

# 4. Package DMG
echo "💿 Création du DMG..."
npm run package:mac:dmg

# 5. Validation finale
echo "✅ Validation finale..."
DMG_PATH="dist/USB Video Vault-$(cat package.json | jq -r .version).dmg"
if [ -f "$DMG_PATH" ]; then
    echo "✅ DMG créé: $DMG_PATH"
    ls -lh "$DMG_PATH"
else
    echo "❌ DMG non trouvé"
    exit 1
fi

echo "🎉 Build et notarisation terminés avec succès!"
```

### Hooks de déploiement

```bash
# package.json
{
  "scripts": {
    "build:mac:complete": "./scripts/build-and-notarize-complete.sh",
    "notarize:only": "./scripts/macos-notarize.sh",
    "verify:mac": "./scripts/macos-verify.sh"
  }
}
```

## Monitoring et Alertes

### Script de monitoring

```bash
#!/bin/bash
# scripts/monitor-notarization.sh

check_notarization_health() {
    local request_uuid="$1"
    local webhook_url="$2"
    
    status=$(./scripts/macos-notarize.sh --check-status "$request_uuid")
    
    if echo "$status" | grep -q "Status: success"; then
        curl -X POST "$webhook_url" -H "Content-Type: application/json" \
          -d '{"text":"✅ Notarisation réussie: '"$request_uuid"'"}'
    elif echo "$status" | grep -q "Status: invalid"; then
        curl -X POST "$webhook_url" -H "Content-Type: application/json" \
          -d '{"text":"❌ Notarisation échouée: '"$request_uuid"'"}'
    fi
}

# Utilisation avec webhook Slack/Discord
check_notarization_health "uuid" "https://hooks.slack.com/webhook-url"
```

## Maintenance

### Rotation des certificats

```bash
# 1. Exporter nouveau certificat
# 2. Mettre à jour secrets GitHub
# 3. Tester build local
# 4. Déployer avec nouveau certificat
```

### Mise à jour pipeline

```bash
# Vérifier compatibilité Xcode
xcode-select --version
xcrun --version

# Mise à jour dependencies
npm update
```

---

**Note**: Cette pipeline assure une notarisation complète et fiable pour macOS, avec monitoring, troubleshooting, et automatisation CI/CD.