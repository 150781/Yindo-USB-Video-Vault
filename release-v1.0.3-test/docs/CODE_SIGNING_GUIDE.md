# 🔐 Guide Certificat Code Signing - USB Video Vault

## 📋 Options Certificats

### 🧪 Certificat Test (Développement)
```powershell
# Créer certificat auto-signé pour tests
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=USB Video Vault Test" -KeyUsage DigitalSignature -FriendlyName "USB Video Vault Test Certificate" -CertStoreLocation "Cert:\CurrentUser\My" -KeyLength 2048 -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -KeyExportPolicy Exportable -KeySpec Signature -KeyUsageProperty Sign -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")

Write-Host "Certificat test créé: $($cert.Thumbprint)" -ForegroundColor Green
```

### 🏭 Certificat Production

#### Option 1: DigiCert (Recommandé)
```
Coût: ~400€/an
Délai: 1-3 jours
Validation: Organisation + domaine
URL: https://www.digicert.com/code-signing/
```

#### Option 2: Sectigo (Comodo)
```
Coût: ~200€/an  
Délai: 1-2 jours
Validation: Organisation
URL: https://sectigo.com/ssl-certificates-tls/code-signing
```

#### Option 3: GlobalSign
```
Coût: ~300€/an
Délai: 1-3 jours
Validation: Organisation
URL: https://www.globalsign.com/code-signing-certificate
```

## 🛠️ Installation Windows SDK

### Téléchargement
```
URL: https://developer.microsoft.com/windows/downloads/windows-sdk/
Version recommandée: Windows 11 SDK (22H2)
Taille: ~2GB
```

### Installation Minimale
```
Composants requis:
☑️ Windows SDK Signing Tools for Desktop Apps
☐ Windows SDK for UWP Managed Apps (optionnel)
☐ Windows SDK for UWP C++ Apps (optionnel)
☐ IntelliSense Files (optionnel)
☐ MSI Tools (optionnel)
```

### Vérification Post-Installation
```powershell
# Vérifier SignTool disponible
& "C:\Program Files (x86)\Windows Kits\10\bin\x64\signtool.exe"

# Ajouter au PATH si nécessaire
$env:PATH += ";C:\Program Files (x86)\Windows Kits\10\bin\x64"
```

## 🔧 Configuration Certificat Test

### Script Création + Test
```powershell
# scripts/create-test-certificate.ps1
param([string]$SubjectName = "USB Video Vault Test")

Write-Host "Création certificat test..." -ForegroundColor Cyan

# Créer certificat
$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject "CN=$SubjectName" `
    -KeyUsage DigitalSignature `
    -FriendlyName "$SubjectName Certificate" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyLength 2048 `
    -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyUsageProperty Sign `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")

Write-Host "✅ Certificat créé: $($cert.Thumbprint)" -ForegroundColor Green

# Tester avec fichier factice
$testFile = "test-file.exe"
Copy-Item "$env:SystemRoot\System32\notepad.exe" $testFile

Write-Host "Test signature..." -ForegroundColor Yellow
& signtool sign /sha1 $cert.Thumbprint /fd SHA256 $testFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Signature test réussie" -ForegroundColor Green
    & signtool verify /pa $testFile
} else {
    Write-Host "❌ Signature test échouée" -ForegroundColor Red
}

Remove-Item $testFile -ErrorAction SilentlyContinue

Write-Host "`n🎯 THUMBPRINT POUR PRODUCTION:" -ForegroundColor Cyan
Write-Host "   $($cert.Thumbprint)" -ForegroundColor White
```

## 📜 Template Scripts Signature

### Build + Sign Automatique
```powershell
# scripts/build-sign-deploy.ps1
param(
    [string]$CertThumbprint = "AUTO",
    [switch]$TestCert,
    [switch]$Deploy
)

if ($TestCert) {
    # Utiliser certificat test
    $testCerts = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*Test*" -and $_.HasPrivateKey }
    if ($testCerts) {
        $CertThumbprint = $testCerts[0].Thumbprint
        Write-Host "Utilisation certificat test: $CertThumbprint" -ForegroundColor Yellow
    } else {
        Write-Error "Aucun certificat test trouvé. Exécuter create-test-certificate.ps1"
        exit 1
    }
}

# Build
npm run build:all
npm run pack

# Sign
if ($CertThumbprint -eq "AUTO") {
    & signtool sign /a /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "out\USB Video Vault Setup.exe"
} else {
    & signtool sign /sha1 $CertThumbprint /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 "out\USB Video Vault Setup.exe"
}

# Verify
& signtool verify /pa "out\USB Video Vault Setup.exe"

if ($Deploy) {
    # Logic de déploiement
    Write-Host "🚀 Déploiement..." -ForegroundColor Cyan
}
```

## ⚠️ Sécurité Certificats

### Sauvegarde Certificat
```powershell
# Exporter certificat + clé privée (PROTÉGÉ!)
$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq "THUMBPRINT" }
$password = ConvertTo-SecureString "MotDePasseComplexe" -AsPlainText -Force
Export-PfxCertificate -Cert $cert -FilePath "backup-cert.pfx" -Password $password
```

### Stockage Sécurisé
```
✅ Certificat production: Azure Key Vault / Hardware Security Module
✅ Backup chiffré: Stockage cloud sécurisé  
✅ Accès restreint: Équipe DevOps uniquement
❌ Jamais dans le code source
❌ Jamais en plain text
❌ Jamais sur poste développeur
```

## 🎯 Commandes Rapides

### Validation Environnement
```powershell
# Tout-en-un: certificats + outils + connectivité
.\scripts\validate-certificates.ps1 -CheckExpiry
```

### Signature Express
```powershell
# Build + sign en une commande
.\scripts\build-and-sign.ps1 -QuickMode

# Signature rapide fichier existant  
.\scripts\quick-sign.ps1 "path\to\file.exe"
```

### Test Certificat
```powershell
# Créer certificat test + tester signature
.\scripts\create-test-certificate.ps1

# Build avec certificat test
.\scripts\build-and-sign.ps1 -TestCert
```

## 📊 Checklist Pre-Production

```
Build Environment:
□ Windows SDK installé (signtool disponible)
□ Certificat code signing valide (> 30 jours)
□ Accès internet (serveurs timestamp)
□ Scripts signature testés

CI/CD:
□ Certificat stocké dans Azure Key Vault / GitHub Secrets
□ Pipeline signature automatisée
□ Tests post-signature (SmartScreen, AV)
□ Artifacts signés archivés

Distribution:
□ Setup.exe signé + timestampé
□ Application.exe signée + timestampée
□ Vérification signature avant publication
□ Documentation utilisateur mise à jour
```

---

**🔐 Signature code prête pour distribution sécurisée**  
**✅ Certificats validés et scripts automatisés**  
**🛡️ Conformité SmartScreen et antivirus**