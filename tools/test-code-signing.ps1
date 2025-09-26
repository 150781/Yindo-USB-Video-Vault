# TEST-CODE-SIGNING.PS1 - Test local de signature de code
param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$CertPassword,
    
    [string]$TestExe = ".\dist\USB Video Vault Setup 0.1.5.exe"
)

$ErrorActionPreference = "Stop"

Write-Host "=== TEST SIGNATURE DE CODE WINDOWS ===" -ForegroundColor Green
Write-Host "Certificat: $CertPath" -ForegroundColor Cyan
Write-Host "Exécutable: $TestExe" -ForegroundColor Cyan

# Vérifier que l'EXE existe
if (-not (Test-Path $TestExe)) {
    Write-Host "[ERROR] Exécutable introuvable: $TestExe" -ForegroundColor Red
    Write-Host "Lancez d'abord: npm run build; npm run electron:build" -ForegroundColor Yellow
    exit 1
}

# Vérifier que le certificat existe
if (-not (Test-Path $CertPath)) {
    Write-Host "[ERROR] Certificat introuvable: $CertPath" -ForegroundColor Red
    exit 1
}

# Trouver signtool.exe
Write-Host "`n1. RECHERCHE SIGNTOOL.EXE" -ForegroundColor Blue
$signtool = (Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1).FullName
if (-not $signtool) {
    Write-Host "[ERROR] signtool.exe non trouvé" -ForegroundColor Red
    Write-Host "Installez Windows SDK : https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/" -ForegroundColor Yellow
    exit 1
}
Write-Host "   Trouvé: $signtool" -ForegroundColor Green

# Copier l'EXE pour test (éviter de corrompre l'original)
$testCopy = $TestExe -replace "\.exe$", "_SIGNED_TEST.exe"
Copy-Item $TestExe $testCopy -Force
Write-Host "`n2. COPIE DE TEST: $testCopy" -ForegroundColor Blue

# Signature
Write-Host "`n3. SIGNATURE EN COURS..." -ForegroundColor Blue
try {
    & "$signtool" sign `
      /fd SHA256 /f "$CertPath" /p "$CertPassword" `
      /tr http://timestamp.sectigo.com /td SHA256 `
      /d "USB Video Vault" "$testCopy"
    
    if ($LASTEXITCODE -ne 0) {
        throw "signtool sign failed with exit code $LASTEXITCODE"
    }
    Write-Host "   [SUCCESS] Signature réussie !" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] Signature échouée: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item $testCopy -ErrorAction SilentlyContinue
    exit 1
}

# Vérification avec signtool
Write-Host "`n4. VERIFICATION SIGNTOOL" -ForegroundColor Blue
try {
    & "$signtool" verify /pa /v "$testCopy"
    if ($LASTEXITCODE -ne 0) {
        throw "signtool verify failed with exit code $LASTEXITCODE"
    }
    Write-Host "   [SUCCESS] Vérification signtool OK !" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] Vérification signtool échouée: $($_.Exception.Message)" -ForegroundColor Red
}

# Vérification PowerShell
Write-Host "`n5. VERIFICATION POWERSHELL" -ForegroundColor Blue
try {
    $signature = Get-AuthenticodeSignature $testCopy
    Write-Host "   Status: $($signature.Status)" -ForegroundColor $(if ($signature.Status -eq "Valid") { "Green" } else { "Red" })
    Write-Host "   Signer: $($signature.SignerCertificate.Subject)" -ForegroundColor Cyan
    Write-Host "   Timestamp: $($signature.TimeStamperCertificate.Subject)" -ForegroundColor Cyan
    Write-Host "   Hash: $($signature.HashAlgorithm)" -ForegroundColor Cyan
    
    if ($signature.Status -eq "Valid") {
        Write-Host "   [SUCCESS] Signature PowerShell valide !" -ForegroundColor Green
    } else {
        Write-Host "   [WARNING] Signature PowerShell: $($signature.Status)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERROR] Vérification PowerShell échouée: $($_.Exception.Message)" -ForegroundColor Red
}

# Informations certificat
Write-Host "`n6. INFORMATIONS CERTIFICAT" -ForegroundColor Blue
try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $CertPassword)
    Write-Host "   Subject: $($cert.Subject)" -ForegroundColor White
    Write-Host "   Issuer: $($cert.Issuer)" -ForegroundColor White
    Write-Host "   Valid from: $($cert.NotBefore)" -ForegroundColor White
    Write-Host "   Valid to: $($cert.NotAfter)" -ForegroundColor White
    
    $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
    if ($daysUntilExpiry -lt 30) {
        Write-Host "   [WARNING] Le certificat expire dans $daysUntilExpiry jours !" -ForegroundColor Yellow
    } else {
        Write-Host "   Expire dans: $daysUntilExpiry jours" -ForegroundColor Green
    }
} catch {
    Write-Host "   [ERROR] Lecture certificat échouée: $($_.Exception.Message)" -ForegroundColor Red
}

# Checksum final
Write-Host "`n7. CHECKSUM FINAL" -ForegroundColor Blue
$hash = (Get-FileHash $testCopy -Algorithm SHA256).Hash.ToLower()
Write-Host "   SHA256: $hash" -ForegroundColor White

Write-Host "`n=== RÉSUMÉ ===" -ForegroundColor Green
Write-Host "✅ Fichier de test: $testCopy" -ForegroundColor Cyan
Write-Host "✅ Vous pouvez maintenant tester l'installation sur une VM propre" -ForegroundColor Cyan
Write-Host "✅ Pour GitHub Actions, ajoutez ces secrets:" -ForegroundColor Cyan
Write-Host "   WINDOWS_CERT_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes('$CertPath'))" -ForegroundColor Yellow
Write-Host "   WINDOWS_CERT_PASSWORD = $CertPassword" -ForegroundColor Yellow

# Nettoyage optionnel
Write-Host "`nSupprimer le fichier de test ? (Y/N)" -ForegroundColor Yellow
$response = Read-Host
if ($response -match "^[Yy]") {
    Remove-Item $testCopy -ErrorAction SilentlyContinue
    Write-Host "Fichier de test supprimé." -ForegroundColor Green
}