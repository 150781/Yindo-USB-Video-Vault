#!/usr/bin/env pwsh
# Create Test Certificate - Code Signing

param(
    [string]$SubjectName = "USB Video Vault Test",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "CREATION CERTIFICAT TEST" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Vérifier si certificat existe déjà
$existingCert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { 
    $_.Subject -like "*$SubjectName*" -and $_.HasPrivateKey 
}

if ($existingCert -and -not $Force) {
    Write-Host "Certificat existant trouve:" -ForegroundColor Yellow
    Write-Host "   Subject: $($existingCert.Subject)" -ForegroundColor Gray
    Write-Host "   Thumbprint: $($existingCert.Thumbprint)" -ForegroundColor Gray
    Write-Host "   Expire: $($existingCert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
    Write-Host "`nUtiliser -Force pour recréer" -ForegroundColor Yellow
    exit 0
}

if ($existingCert -and $Force) {
    Write-Host "Suppression certificat existant..." -ForegroundColor Yellow
    Remove-Item "Cert:\CurrentUser\My\$($existingCert.Thumbprint)" -Force
}

Write-Host "Creation certificat: $SubjectName" -ForegroundColor Yellow

try {
    # Créer certificat auto-signé
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

    Write-Host "Certificat cree avec succes!" -ForegroundColor Green
    Write-Host "   Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
    Write-Host "   Subject: $($cert.Subject)" -ForegroundColor Gray
    Write-Host "   Expire: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray

} catch {
    Write-Host "Erreur creation certificat: $_" -ForegroundColor Red
    exit 1
}

# Test signature avec fichier factice
Write-Host "`nTest signature..." -ForegroundColor Yellow
$testFile = "test-signature.exe"

try {
    # Copier notepad comme fichier test
    Copy-Item "$env:SystemRoot\System32\notepad.exe" $testFile
    
    # Tester signature
    & signtool sign /sha1 $cert.Thumbprint /fd SHA256 $testFile 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Signature test reussie!" -ForegroundColor Green
        
        # Vérifier signature
        & signtool verify /pa $testFile 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Verification signature reussie!" -ForegroundColor Green
        } else {
            Write-Host "Verification signature echouee" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Signature test echouee" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Erreur test signature: $_" -ForegroundColor Red
} finally {
    Remove-Item $testFile -ErrorAction SilentlyContinue
}

Write-Host "`nTHUMBPRINT POUR SCRIPTS:" -ForegroundColor Cyan
Write-Host "   $($cert.Thumbprint)" -ForegroundColor White

Write-Host "`nCOMMANDES UTILES:" -ForegroundColor Cyan
Write-Host "   # Build avec ce certificat test:" -ForegroundColor Gray
Write-Host "   .\scripts\build-and-sign.ps1 -CertThumbprint $($cert.Thumbprint)" -ForegroundColor White
Write-Host "   # Signature rapide:" -ForegroundColor Gray  
Write-Host "   .\scripts\quick-sign.ps1 -CertThumbprint $($cert.Thumbprint) `"file.exe`"" -ForegroundColor White

Write-Host "`nCertificat test pret!" -ForegroundColor Green