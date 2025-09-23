# Système de Notarisation macOS - Documentation Complète
# USB Video Vault - Guide complet pour la notarisation Apple

## ✅ Système Implémenté

### Scripts Créés

1. **`scripts/macos-sign.sh`** - Signature de code macOS
2. **`scripts/macos-notarize.sh`** - Notarisation Apple complète
3. **`scripts/macos-verify.sh`** - Vérification et validation
4. **`scripts/build-orchestrator.sh`** - Pipeline complète

### Documentation

1. **`docs/MACOS_NOTARIZATION.md`** - Guide de base
2. **`docs/MACOS_NOTARIZATION_PIPELINE.md`** - Pipeline CI/CD
3. **`docs/MACOS_NOTARIZATION_COMPLETE.md`** - Ce document (résumé complet)

## 🚀 Utilisation Rapide

### Build Local Complet
```bash
# Pipeline complète
chmod +x scripts/build-orchestrator.sh
export APPLE_ID="votre@email.com"
export APPLE_ID_PASSWORD="abcd-efgh-ijkl-mnop"
export TEAM_ID="VOTRE_TEAM_ID"
./scripts/build-orchestrator.sh --platforms mac --auto-release
```

### Notarisation Seule
```bash
# Après build
chmod +x scripts/macos-notarize.sh
export APPLE_ID="votre@email.com"
export APPLE_ID_PASSWORD="abcd-efgh-ijkl-mnop"
export TEAM_ID="VOTRE_TEAM_ID"
./scripts/macos-notarize.sh --verbose
```

### Vérification
```bash
chmod +x scripts/macos-verify.sh
./scripts/macos-verify.sh --verbose
```

## 🔧 Configuration Requise

### Certificats Apple Developer

1. **Certificat Developer ID Application**
   - Télécharger depuis Apple Developer
   - Installer dans Keychain
   - Noter l'identité complète

2. **App-Specific Password**
   - Créer sur appleid.apple.com
   - Sécurité > Mots de passe app
   - Format: `abcd-efgh-ijkl-mnop`

3. **Team ID**
   - Disponible dans Apple Developer Account
   - Membership tab

### Variables d'Environnement

```bash
# Signature
export SIGNING_IDENTITY="Developer ID Application: Votre Nom (TEAMID)"

# Notarisation
export APPLE_ID="votre@email.com"
export APPLE_ID_PASSWORD="abcd-efgh-ijkl-mnop"
export TEAM_ID="VOTRE_TEAM_ID"

# Optionnel
export VERBOSE=true
```

## 📋 Processus Complet

### 1. Préparation
```bash
# Vérifier certificats
security find-identity -v -p codesigning

# Vérifier application
ls -la "dist/mac/USB Video Vault.app"
```

### 2. Signature
```bash
./scripts/macos-sign.sh \
  --identity "Developer ID Application: Votre Nom (TEAMID)" \
  --verify
```

### 3. Notarisation
```bash
./scripts/macos-notarize.sh --verbose
```

### 4. Vérification
```bash
./scripts/macos-verify.sh --verbose
```

### 5. Distribution
```bash
# DMG signé et notarisé prêt
open dist/
```

## 🤖 CI/CD GitHub Actions

### Configuration Secrets

```yaml
# Dans GitHub Settings > Secrets
BUILD_CERTIFICATE_BASE64: <certificat .p12 en base64>
P12_PASSWORD: <mot de passe certificat>
KEYCHAIN_PASSWORD: <mot de passe keychain temporaire>
SIGNING_IDENTITY: <nom complet du certificat>
APPLE_ID: <email Apple ID>
APPLE_ID_PASSWORD: <app-specific password>
TEAM_ID: <Team ID Apple Developer>
```

### Workflow Example

```yaml
# .github/workflows/macos-release.yml
name: macOS Release

on:
  push:
    tags: ['v*']

jobs:
  macos-notarize:
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
    
    - name: Import certificates
      env:
        BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
        P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
        KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
      run: |
        echo $BUILD_CERTIFICATE_BASE64 | base64 --decode > certificate.p12
        security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
        security default-keychain -s build.keychain
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
        security import certificate.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" build.keychain
    
    - name: Build and Notarize
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
        TEAM_ID: ${{ secrets.TEAM_ID }}
      run: |
        chmod +x scripts/build-orchestrator.sh
        ./scripts/build-orchestrator.sh --platforms mac --auto-release
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v4
      with:
        name: macos-notarized
        path: |
          dist/*.dmg
          dist/build-report-*.txt
          dist/verification-report-*.txt
```

## 🔍 Troubleshooting

### Erreurs Communes

#### 1. "No signing identity found"
```bash
# Vérifier certificats
security find-identity -v -p codesigning
# Réimporter si nécessaire
```

#### 2. "Invalid credentials"
```bash
# Vérifier variables
echo $APPLE_ID
echo $TEAM_ID
# Régénérer app-specific password si nécessaire
```

#### 3. "Notarization failed"
```bash
# Obtenir détails
./scripts/macos-notarize.sh --check-status "uuid"
# Vérifier logs Apple
```

#### 4. "Gatekeeper rejection"
```bash
# Forcer réévaluation
sudo spctl --master-disable
sudo spctl --master-enable
# Vérifier signature
codesign -dv --verbose=4 "app-path"
```

### Logs et Diagnostics

```bash
# Logs système
sudo log show --predicate 'subsystem == "com.apple.syspolicy"' --last 1h

# Test Gatekeeper
spctl --assess --type execute --verbose "path/to/app"

# Vérification signature
codesign --verify --strict --verbose "path/to/app"

# Status notarisation
xcrun altool --notarization-info "uuid" \
  --username "$APPLE_ID" \
  --password "$APPLE_ID_PASSWORD"
```

## 📊 Monitoring et Reporting

### Rapports Automatiques

Chaque script génère des rapports:
- `build/signing-report-*.txt`
- `build/notarization-report-*.txt`
- `build/verification-report-*.txt`
- `dist/build-report-*.txt`

### Métriques

```bash
# Temps de notarisation
grep "completion" build/notarization-report-*.txt

# Taille des artifacts
ls -lh dist/*.dmg

# Status final
tail -5 build/verification-report-*.txt
```

## 🔄 Maintenance

### Rotation Certificats

1. Exporter nouveau certificat depuis Apple Developer
2. Mettre à jour secrets GitHub
3. Tester build local
4. Déployer nouvelle version

### Mise à Jour Pipeline

```bash
# Vérifier compatibilité Xcode
xcode-select --version
xcrun --version

# Update dependencies
npm update

# Test pipeline
./scripts/build-orchestrator.sh --dry-run --platforms mac
```

## 📈 Optimisations Futures

### Améliorations Possibles

1. **Cache Notarisation**
   - Éviter re-notarisation si binaire identique
   - Cache basé sur hash du binaire

2. **Notarisation Parallèle**
   - Multiple plateformes simultanées
   - Queue de notarisation

3. **Validation Avancée**
   - Tests automatisés post-notarisation
   - Validation sur multiple versions macOS

4. **Monitoring Avancé**
   - Webhooks pour status notarisation
   - Alertes en cas d'échec
   - Dashboard de métriques

### Intégrations

```bash
# Slack notifications
curl -X POST "$SLACK_WEBHOOK" -H "Content-Type: application/json" \
  -d '{"text":"✅ Notarisation réussie: v'$VERSION'"}'

# Discord notifications
curl -X POST "$DISCORD_WEBHOOK" -H "Content-Type: application/json" \
  -d '{"content":"🚀 Build macOS disponible: v'$VERSION'"}'
```

## ✅ État Actuel

### ✅ Implémenté
- [x] Signature de code automatisée
- [x] Notarisation Apple complète
- [x] Validation et vérification
- [x] Pipeline CI/CD GitHub Actions
- [x] Orchestrateur de build
- [x] Reporting complet
- [x] Troubleshooting et diagnostics
- [x] Documentation complète

### 🔮 Futur (Optionnel)
- [ ] Cache notarisation
- [ ] Tests automatisés post-notarisation
- [ ] Monitoring avancé avec webhooks
- [ ] Validation multi-versions macOS

---

**Le système de notarisation macOS est maintenant complet et prêt pour la production!** 🎉

Tous les scripts sont créés, testés, et documentés. La pipeline peut être utilisée immédiatement pour des builds locaux ou en CI/CD.