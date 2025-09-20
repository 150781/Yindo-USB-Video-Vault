# ✅ Build Signing Checklist - USB Video Vault

## 🔐 Signature Authenticode - Pipeline Production

### 📋 Prérequis (à vérifier avant build)

```
□ Certificat code signing valide installé
□ SignTool.exe disponible (Windows SDK)
□ Internet accessible pour timestamp
□ Build artefacts générés (npm run pack)
□ Tests QA passés
□ Licence system validé
```

### 🏗️ Étapes Build & Signature

#### 1️⃣ Build Production
```powershell
# Clean build
Remove-Item -Path "dist" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "out" -Recurse -Force -ErrorAction SilentlyContinue

# Build complet
npm run build:all
npm run pack

# Vérifier artefacts
Get-ChildItem "out" -Name "*.exe"
```

#### 2️⃣ Signature Authenticode
```powershell
# Signature avec SHA256 + timestamp
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a "out\USB Video Vault Setup.exe"
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a "out\win-unpacked\USB Video Vault.exe"

# Vérification signatures
signtool verify /pa /all "out\USB Video Vault Setup.exe"
signtool verify /pa /all "out\win-unpacked\USB Video Vault.exe"
```

#### 3️⃣ Validation Post-Signature
```powershell
# Vérifier détails certificat
signtool verify /v "out\USB Video Vault Setup.exe"

# Test lancement (sans installation)
Start-Process "out\win-unpacked\USB Video Vault.exe" -Wait

# Vérifier signature dans Explorateur Windows
# → Clic droit > Propriétés > Signatures numériques
```

### 📄 Script Automatisé

#### `scripts/build-and-sign.ps1`
```powershell
param(
    [string]$CertThumbprint = "",
    [switch]$SkipTests = $false,
    [switch]$Verbose = $false
)

Write-Host "🏗️ BUILD & SIGNATURE - USB Video Vault" -ForegroundColor Cyan

# 1. Prérequis
if (-not $SkipTests) {
    Write-Host "1. Tests QA..." -ForegroundColor Yellow
    npm test
    if ($LASTEXITCODE -ne 0) { throw "Tests échoués" }
}

# 2. Clean build
Write-Host "2. Clean build..." -ForegroundColor Yellow
Remove-Item -Path "dist","out" -Recurse -Force -ErrorAction SilentlyContinue
npm run build:all
npm run pack

# 3. Vérifier artefacts
$setupExe = "out\USB Video Vault Setup.exe"
$appExe = "out\win-unpacked\USB Video Vault.exe"

if (-not (Test-Path $setupExe)) { throw "Setup exe manquant" }
if (-not (Test-Path $appExe)) { throw "App exe manquant" }

# 4. Signature
Write-Host "3. Signature Authenticode..." -ForegroundColor Yellow
$signArgs = @("/fd", "SHA256", "/tr", "http://timestamp.digicert.com", "/td", "SHA256")
if ($CertThumbprint) { $signArgs += "/sha1", $CertThumbprint } else { $signArgs += "/a" }

& signtool sign @signArgs $setupExe
& signtool sign @signArgs $appExe

# 5. Vérification
Write-Host "4. Vérification signatures..." -ForegroundColor Yellow
& signtool verify /pa /all $setupExe
& signtool verify /pa /all $appExe

if ($Verbose) {
    Write-Host "5. Détails signatures..." -ForegroundColor Yellow
    & signtool verify /v $setupExe
}

Write-Host "✅ BUILD & SIGNATURE TERMINÉS" -ForegroundColor Green
```

### 🔍 Validation Manuelle

#### Checklist Post-Build
```
□ signtool verify retourne "Successfully verified"
□ Pas d'avertissement sécurité au lancement
□ Certificat visible dans Propriétés > Signatures
□ Timestamp valide et récent
□ Taille fichiers cohérente avec build précédent
□ Version affichée correcte dans About
□ Licence system opérationnel après signature
```

#### Tests Sécurité
```powershell
# Test SmartScreen (Windows 10/11)
Start-Process $setupExe -PassThru

# Vérifier réputation fichier
# → Pas de "Fichier dangereux" ou "Éditeur inconnu"

# Test antivirus (si disponible)
# → Scanner avec Windows Defender ou autre AV
```

### 🚨 Troubleshooting

#### Erreurs Courantes

**"No certificates were found that met all the given criteria"**
```powershell
# Lister certificats disponibles
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert
Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert

# Utiliser thumbprint spécifique
signtool sign /sha1 THUMBPRINT /tr http://timestamp.digicert.com /td SHA256 /fd SHA256 "file.exe"
```

**"The specified timestamp server either could not be reached"**
```powershell
# Essayer serveurs timestamp alternatifs
/tr http://timestamp.comodoca.com
/tr http://timestamp.sectigo.com  
/tr http://tsa.starfieldtech.com
```

**"SignTool Error: An error occurred while attempting to sign"**
```powershell
# Vérifier certificat encore valide
signtool verify /v "file-deja-signe.exe"

# Vérifier permissions fichier
icacls "file.exe"
```

### 📅 Certificat Management

#### Monitoring Expiration
```powershell
# Vérifier date expiration certificat
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
$daysToExpiry = ($cert.NotAfter - (Get-Date)).Days
Write-Host "Certificat expire dans $daysToExpiry jours" -ForegroundColor $(if($daysToExpiry -lt 30) {'Red'} else {'Green'})
```

#### Renouvellement
```
□ Surveiller expiration (< 30 jours)
□ Commander nouveau certificat
□ Installer nouveau certificat
□ Tester signature avec nouveau cert
□ Mettre à jour scripts CI/CD
□ Documenter changement
```

### 🔧 CI/CD Integration

#### Azure DevOps Pipeline
```yaml
- task: PowerShell@2
  displayName: 'Build and Sign'
  inputs:
    targetType: 'filePath'
    filePath: 'scripts/build-and-sign.ps1'
    arguments: '-CertThumbprint $(CODE_SIGN_CERT_THUMBPRINT)'
  env:
    PACKAGER_PRIVATE_HEX: $(LICENSE_PRIVATE_KEY)
```

#### GitHub Actions
```yaml
- name: Build and Sign
  run: |
    .\scripts\build-and-sign.ps1 -CertThumbprint ${{ secrets.CODE_SIGN_CERT_THUMBPRINT }}
  env:
    PACKAGER_PRIVATE_HEX: ${{ secrets.LICENSE_PRIVATE_KEY }}
```

### 📊 Métriques Qualité

#### KPIs Build
```
✅ Temps build total: < 10 minutes
✅ Taille setup.exe: < 200 MB
✅ Tests QA: 100% réussis
✅ Signature: Valide + timestampée
✅ SmartScreen: Pas d'avertissement
✅ Licence: Validée post-build
```

### 🎯 Commandes Rapides

#### Build Signature Express
```powershell
# Quick build + sign (production)
npm run build:all; npm run pack
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a "out\USB Video Vault Setup.exe"
signtool verify /pa /all "out\USB Video Vault Setup.exe"
```

#### Vérification Signature
```powershell
# Vérifier signature existante
signtool verify /pa /all "USB Video Vault.exe"
signtool verify /v "USB Video Vault.exe" | Select-String "Issued to|Valid from|Valid to"
```

---

**🔐 Artefacts signés et prêts pour distribution sécurisée**  
**✅ Pipeline automatisé pour builds de production**  
**🛡️ Validation complète certificat + timestamp + réputation**