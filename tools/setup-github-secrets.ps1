# SETUP-GITHUB-SECRETS.PS1 - Aide configuration des secrets GitHub
param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$CertPassword
)

$ErrorActionPreference = "Stop"

Write-Host "=== CONFIGURATION SECRETS GITHUB ACTIONS ===" -ForegroundColor Green

# Vérifier que le certificat existe
if (-not (Test-Path $CertPath)) {
    Write-Host "[ERROR] Certificat introuvable: $CertPath" -ForegroundColor Red
    exit 1
}

# Convertir le certificat en Base64
Write-Host "`n1. CONVERSION CERTIFICATE EN BASE64" -ForegroundColor Blue
try {
    $certBytes = [IO.File]::ReadAllBytes($CertPath)
    $certBase64 = [Convert]::ToBase64String($certBytes)
    Write-Host "   [SUCCESS] Certificat converti (${($certBytes.Length)} bytes -> ${($certBase64.Length)} chars)" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] Conversion échouée: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Instructions GitHub
Write-Host "`n2. CONFIGURATION GITHUB REPOSITORY" -ForegroundColor Blue
Write-Host "   Allez sur: https://github.com/150781/Yindo-USB-Video-Vault/settings/secrets/actions" -ForegroundColor Cyan
Write-Host "`n   Ajoutez ces 2 secrets:" -ForegroundColor Yellow

Write-Host "`n   Secret #1 - WINDOWS_CERT_BASE64:" -ForegroundColor Green
Write-Host "   Nom: WINDOWS_CERT_BASE64" -ForegroundColor White
Write-Host "   Valeur: (copiez le texte ci-dessous)" -ForegroundColor White
Write-Host "   ------- DÉBUT CERTIFICAT BASE64 -------" -ForegroundColor Cyan
Write-Host $certBase64 -ForegroundColor Yellow
Write-Host "   -------  FIN CERTIFICAT BASE64  -------" -ForegroundColor Cyan

Write-Host "`n   Secret #2 - WINDOWS_CERT_PASSWORD:" -ForegroundColor Green
Write-Host "   Nom: WINDOWS_CERT_PASSWORD" -ForegroundColor White
Write-Host "   Valeur: $CertPassword" -ForegroundColor Yellow

# Sauvegarder dans un fichier temporaire pour copier-coller
$tempFile = "github-secrets-temp.txt"
$secretsContent = @"
=== SECRETS GITHUB ACTIONS ===

Repository: https://github.com/150781/Yindo-USB-Video-Vault/settings/secrets/actions

Secret 1:
Name: WINDOWS_CERT_BASE64
Value:
$certBase64

Secret 2:
Name: WINDOWS_CERT_PASSWORD
Value: $CertPassword

=== INSTRUCTIONS ===
1. Allez sur le lien ci-dessus
2. Cliquez "New repository secret"
3. Ajoutez WINDOWS_CERT_BASE64 avec la valeur Base64
4. Ajoutez WINDOWS_CERT_PASSWORD avec le mot de passe
5. Supprimez ce fichier après usage !

=== TEST ===
Après configuration, créez un tag pour tester:
git tag v0.1.5-signed-test
git push origin v0.1.5-signed-test

Le workflow production-release.yml signera automatiquement.
"@

$secretsContent | Out-File -Encoding UTF8 $tempFile

Write-Host "`n3. SAUVEGARDE TEMPORAIRE" -ForegroundColor Blue
Write-Host "   Les secrets ont été sauvés dans: $tempFile" -ForegroundColor Cyan
Write-Host "   [IMPORTANT] Supprimez ce fichier après usage !" -ForegroundColor Red

# Vérification certificat
Write-Host "`n4. VALIDATION CERTIFICAT" -ForegroundColor Blue
try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $CertPassword)
    Write-Host "   Subject: $($cert.Subject)" -ForegroundColor White
    Write-Host "   Type: $(if ($cert.Subject -match 'EV') { 'Extended Validation (EV)' } elseif ($cert.Subject -match 'OV') { 'Organization Validation (OV)' } else { 'Domain/Code Signing' })" -ForegroundColor White
    Write-Host "   Valide jusqu'au: $($cert.NotAfter)" -ForegroundColor White
    
    $daysLeft = ($cert.NotAfter - (Get-Date)).Days
    if ($daysLeft -lt 30) {
        Write-Host "   [WARNING] Expire dans $daysLeft jours !" -ForegroundColor Yellow
    } else {
        Write-Host "   Valide pour $daysLeft jours" -ForegroundColor Green
    }
} catch {
    Write-Host "   [ERROR] Validation certificat: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== PROCHAINES ÉTAPES ===" -ForegroundColor Green
Write-Host "1. ✅ Configurez les secrets GitHub (liens ci-dessus)" -ForegroundColor Cyan
Write-Host "2. ✅ Testez avec: git tag v0.1.5-signed-test && git push origin v0.1.5-signed-test" -ForegroundColor Cyan
Write-Host "3. ✅ Vérifiez le workflow: https://github.com/150781/Yindo-USB-Video-Vault/actions" -ForegroundColor Cyan
Write-Host "4. ✅ Testez les EXE signés sur une VM propre" -ForegroundColor Cyan
Write-Host "5. ✅ Publiez la release officielle: git tag v0.1.5 && git push origin v0.1.5" -ForegroundColor Cyan

Write-Host "`n[SÉCURITÉ] N'oubliez pas de supprimer $tempFile !" -ForegroundColor Red