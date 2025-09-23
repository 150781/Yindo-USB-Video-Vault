# Notarisation macOS - USB Video Vault
# Infrastructure pour signature et notarisation Apple

## Vue d'ensemble

La notarisation macOS est requise pour distribuer des applications sur macOS 10.14.5+ en évitant les avertissements de sécurité Gatekeeper.

## Prérequis Apple

### 1. Compte Développeur Apple
- **Apple Developer Program** : Abonnement payant requis (99$/an)
- **Team ID** : Identifiant unique de votre équipe de développement
- **Developer ID Application Certificate** : Certificat de signature

### 2. Certificats Requis
- **Developer ID Application** : Pour signer l'application
- **Developer ID Installer** : Pour signer les packages d'installation
- **Mac App Store** : Si distribution via App Store

### 3. Profils de Provisioning
- Profils de développement et distribution
- Entitlements appropriés

## Architecture de Signature

### Processus de Build
```
[Build] → [Sign] → [Notarize] → [Staple] → [Distribute]
```

### Étapes Détaillées
1. **Build** : Compilation de l'application
2. **Sign** : Signature cryptographique avec certificat Developer ID
3. **Notarize** : Envoi à Apple pour vérification de sécurité
4. **Staple** : Intégration du ticket de notarisation
5. **Distribute** : Distribution de l'application notarisée

## Structure des Fichiers

### Scripts de Signature
- `scripts/macos-sign.sh` : Script de signature principale
- `scripts/macos-notarize.sh` : Script de notarisation
- `scripts/macos-verify.sh` : Vérification de signature

### Configuration
- `build/entitlements.plist` : Permissions et entitlements
- `build/info.plist` : Métadonnées de l'application
- `.env.macos` : Variables d'environnement sécurisées

## Sécurité

### Gestion des Certificats
- **Keychain Access** : Stockage sécurisé des certificats
- **Code Signing Identity** : Identité de signature unique
- **Provisioning Profiles** : Profils de provisioning appropriés

### Variables Sensibles
```bash
# Ne jamais committer ces valeurs
APPLE_DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
APPLE_ID_EMAIL="your-email@domain.com"
APPLE_ID_PASSWORD="app-specific-password"
TEAM_ID="YOUR_TEAM_ID"
```

### App-Specific Password
- Généré dans Apple ID Account Settings
- Utilisé pour l'authentification notarization
- Différent du mot de passe principal Apple ID

## Entitlements macOS

### Permissions Typiques
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Accès réseau pour vérification de licence -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Accès fichiers utilisateur -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Accès périphériques USB -->
    <key>com.apple.security.device.usb</key>
    <true/>
    
    <!-- Sandboxing (si requis) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Hardened Runtime -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
</dict>
</plist>
```

## Intégration CI/CD

### GitHub Actions (macOS)
```yaml
name: Build and Notarize macOS

on:
  push:
    tags: ['v*']

jobs:
  build-macos:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
    
    - name: Install Dependencies
      run: npm ci
    
    - name: Import Certificates
      env:
        DEVELOPER_ID_CERT: ${{ secrets.DEVELOPER_ID_CERT }}
        DEVELOPER_ID_CERT_PASSWORD: ${{ secrets.DEVELOPER_ID_CERT_PASSWORD }}
      run: |
        echo "$DEVELOPER_ID_CERT" | base64 --decode > certificate.p12
        security create-keychain -p temp_password build.keychain
        security import certificate.p12 -k build.keychain -P "$DEVELOPER_ID_CERT_PASSWORD" -T /usr/bin/codesign
        security list-keychains -s build.keychain
        security unlock-keychain -p temp_password build.keychain
    
    - name: Build Application
      run: npm run build:mac
    
    - name: Sign Application
      env:
        DEVELOPER_ID: ${{ secrets.DEVELOPER_ID }}
      run: ./scripts/macos-sign.sh
    
    - name: Notarize Application
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
        TEAM_ID: ${{ secrets.TEAM_ID }}
      run: ./scripts/macos-notarize.sh
    
    - name: Create DMG
      run: npm run package:dmg
    
    - name: Upload Artifacts
      uses: actions/upload-artifact@v4
      with:
        name: macos-app
        path: dist/*.dmg
```

## Outils de Développement

### Xcode Command Line Tools
```bash
# Installation
xcode-select --install

# Vérification
xcode-select -p
```

### Utilitaires de Signature
```bash
# Lister les identités de signature
security find-identity -v -p codesigning

# Vérifier la signature
codesign -dv --verbose=4 /path/to/app

# Vérifier la notarisation
spctl -a -vv /path/to/app
```

## Dépannage

### Problèmes Courants

#### 1. Certificat Non Trouvé
```bash
# Erreur: No identity found
# Solution: Importer le certificat dans Keychain Access
```

#### 2. Entitlements Invalides
```bash
# Erreur: Invalid entitlements
# Solution: Vérifier le format XML et les permissions
```

#### 3. Notarisation Échouée
```bash
# Vérifier le statut
xcrun altool --notarization-info SUBMISSION_ID \
  --username "your-email@domain.com" \
  --password "app-specific-password"
```

#### 4. Gatekeeper Bloque l'App
```bash
# Vérification manuelle
spctl --assess --verbose /path/to/app

# Réinitialiser Gatekeeper (développement seulement)
sudo spctl --master-disable
```

### Logs de Diagnostic
```bash
# Logs système macOS
log show --predicate 'subsystem contains "com.apple.security"' --last 1h

# Logs de signature
codesign -dvvv /path/to/app 2>&1 | grep -E "(Authority|Identifier|Format)"
```

## Coûts et Planification

### Coûts Apple
- **Apple Developer Program** : 99$ USD/an
- **Renouvellement certificats** : Inclus dans l'abonnement
- **Notarisation** : Gratuite

### Timeline de Développement
- **Setup initial** : 1-2 semaines (création compte, certificats)
- **Intégration CI/CD** : 1 semaine
- **Tests et validation** : 1 semaine
- **Documentation** : 2-3 jours

### Maintenance
- **Renouvellement annuel** : Certificats et abonnement
- **Mise à jour entitlements** : Selon évolution de l'app
- **Tests réguliers** : Vérification compatibilité macOS

Cette infrastructure prépare la notarisation macOS pour une distribution professionnelle future de USB Video Vault.