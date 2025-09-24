# Script de préparation des certificats pour signature Authenticode
# Usage: .\setup-code-signing.ps1 -CertPath "cert.pfx" -Password "password"

param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    [Parameter(Mandatory=$true)]
    [string]$Password
)

Write-Host "=== Configuration signature Authenticode ===" -ForegroundColor Cyan
Write-Host ""

# 1. Vérifier le certificat
if (-not (Test-Path $CertPath)) {
    Write-Error "Certificat introuvable: $CertPath"
    exit 1
}

try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $Password)
    Write-Host "✅ Certificat chargé avec succès" -ForegroundColor Green
    Write-Host "📜 Sujet: $($cert.Subject)" -ForegroundColor Gray
    Write-Host "🏢 Émetteur: $($cert.Issuer)" -ForegroundColor Gray
    Write-Host "📅 Valide du: $($cert.NotBefore) au $($cert.NotAfter)" -ForegroundColor Gray

    # Vérifier si c'est un certificat EV
    $isEV = $cert.Subject -match "OU=.*EV.*" -or $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Certificate Policies" }
    if ($isEV) {
        Write-Host "🏆 Certificat EV détecté - Excellente réputation SmartScreen" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Certificat OV/DV - Réputation SmartScreen progressive" -ForegroundColor Yellow
    }
} catch {
    Write-Error "Erreur lors du chargement du certificat: $($_.Exception.Message)"
    exit 1
}

# 2. Encoder en Base64
Write-Host "`n🔐 Encodage Base64 pour GitHub Secrets..." -ForegroundColor Yellow
try {
    $certBytes = [IO.File]::ReadAllBytes($CertPath)
    $certBase64 = [Convert]::ToBase64String($certBytes)

    $outputFile = "windows-cert-base64.txt"
    $certBase64 | Set-Content -Path $outputFile -Encoding ASCII
    Write-Host "✅ Certificat encodé sauvé: $outputFile" -ForegroundColor Green
    Write-Host "📏 Taille: $($certBase64.Length) caractères" -ForegroundColor Gray
} catch {
    Write-Error "Erreur encodage: $($_.Exception.Message)"
    exit 1
}

# 3. Instructions GitHub Secrets
Write-Host "`n📋 Instructions GitHub Secrets:" -ForegroundColor Cyan
Write-Host "1. Aller sur: https://github.com/150781/Yindo-USB-Video-Vault/settings/secrets/actions" -ForegroundColor White
Write-Host "2. Créer ces secrets:" -ForegroundColor White
Write-Host "   • WINDOWS_CERT_BASE64 = contenu de $outputFile" -ForegroundColor Green
Write-Host "   • WINDOWS_CERT_PASSWORD = votre mot de passe PFX" -ForegroundColor Green

# 4. Test de signature local
Write-Host "`n🧪 Test de signature local..." -ForegroundColor Yellow
$testFile = ".\dist\USB Video Vault Setup 0.1.4.exe"
if (Test-Path $testFile) {
    # Chercher signtool
    $signtool = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1

    if ($signtool) {
        Write-Host "🔧 Signature test avec signtool..." -ForegroundColor Gray
        try {
            & $signtool.FullName sign /fd SHA256 /f $CertPath /p $Password /tr http://timestamp.sectigo.com /td SHA256 /d "USB Video Vault" $testFile

            # Vérifier la signature
            & $signtool.FullName verify /pa /v $testFile
            Write-Host "✅ Signature test réussie!" -ForegroundColor Green
        } catch {
            Write-Host "❌ Erreur signature test: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  signtool.exe introuvable - installer Windows SDK" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Fichier setup introuvable pour test: $testFile" -ForegroundColor Yellow
}

# 5. Commandes de vérification
Write-Host "`n🔍 Commandes de vérification post-signature:" -ForegroundColor Cyan
Write-Host "# Vérifier signature Authenticode:" -ForegroundColor Gray
Write-Host 'Get-AuthenticodeSignature ".\USB Video Vault Setup 0.1.4.exe"' -ForegroundColor White
Write-Host ""
Write-Host "# Vérifier avec signtool:" -ForegroundColor Gray
Write-Host 'signtool verify /pa /v ".\USB Video Vault Setup 0.1.4.exe"' -ForegroundColor White

Write-Host "`n✅ Configuration terminée!" -ForegroundColor Green
Write-Host "📋 Prochaines étapes:" -ForegroundColor Yellow
Write-Host "1. Configurer les secrets GitHub" -ForegroundColor White
Write-Host "2. Créer un tag pour déclencher la signature automatique" -ForegroundColor White
Write-Host "3. Vérifier la signature dans les artifacts" -ForegroundColor White
