# État des signatures - Release v1.0.3

## Résumé des vérifications

### Signatures Authenticode

| Fichier | Status | Certificat | Horodatage |
|---------|--------|------------|------------|
| `USB Video Vault.exe` | ❌ Not Signed | N/A | N/A |
| `USB-Video-Vault-0.1.0-portable.exe` | ⚠️ Unknown Error | Test Certificate | Non horodaté |

### Détails du certificat de test

- **Subject** : CN=Yindo USB Video Vault Test Certificate
- **Issuer** : CN=Yindo USB Video Vault Test Certificate (auto-signé)
- **Thumbprint** : 74D81F58E006CB1E05FB66B3CCF69540F4186737
- **Validité** : 2025-09-20 → 2026-09-20
- **Status** : UnknownError (certificat racine non approuvé)

## Recommandations pour production

### 1. Certificat de signature de code commercial

Pour la production, obtenir un certificat de signature de code auprès d'une CA reconnue :

- **DigiCert** : Code Signing Certificate
- **Sectigo** : Code Signing Certificate  
- **GlobalSign** : Code Signing Certificate

### 2. Horodatage (Timestamping)

Ajouter un horodatage pour la validité post-expiration :

```powershell
# Avec signtool.exe
signtool sign /f certificate.p12 /p password /t http://timestamp.digicert.com /v executable.exe

# Avec PowerShell Set-AuthenticodeSignature
Set-AuthenticodeSignature -FilePath "app.exe" -Certificate $cert -TimestampServer "http://timestamp.digicert.com"
```

### 3. Scripts de signature automatisée

```powershell
# sign-release.ps1 - Script de signature pour production
param(
    [string]$CertPath,
    [string]$Password,
    [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$cert = Get-PfxCertificate -FilePath $CertPath
$executables = @(
    "dist\win-unpacked\USB Video Vault.exe",
    "usb-package\USB-Video-Vault-portable.exe"
)

foreach ($exe in $executables) {
    if (Test-Path $exe) {
        Write-Host "Signature de $exe..."
        $signature = Set-AuthenticodeSignature -FilePath $exe -Certificate $cert -TimestampServer $TimestampUrl
        
        if ($signature.Status -eq "Valid") {
            Write-Host "✅ Signature réussie pour $exe" -ForegroundColor Green
        } else {
            Write-Host "❌ Échec signature pour $exe : $($signature.StatusMessage)" -ForegroundColor Red
        }
    }
}
```

## Workflow de validation

### Vérification post-signature

```powershell
# validate-signatures.ps1
$files = @(
    "dist\win-unpacked\USB Video Vault.exe",
    "usb-package\USB-Video-Vault-portable.exe"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        $sig = Get-AuthenticodeSignature $file
        
        Write-Host "=== $file ===" -ForegroundColor Cyan
        Write-Host "Status: $($sig.Status)"
        Write-Host "Certificat: $($sig.SignerCertificate.Subject)"
        Write-Host "Horodatage: $($sig.TimeStamperCertificate.Subject ?? 'Non horodaté')"
        Write-Host "Valide jusqu'à: $($sig.SignerCertificate.NotAfter)"
        Write-Host ""
    }
}
```

## Checklist production

- [ ] Obtenir certificat de signature de code commercial
- [ ] Configurer horodatage automatique
- [ ] Tester signature sur exécutables de test
- [ ] Valider certificats avant release
- [ ] Archiver certificats et clés de signature
- [ ] Documenter procédures de signature d'urgence