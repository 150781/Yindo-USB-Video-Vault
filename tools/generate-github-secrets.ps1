# GENERATE-GITHUB-SECRETS.PS1 - Générateur secrets GitHub optimisé
param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$CertPassword
)

$ErrorActionPreference = "Stop"

Write-Host "=== GÉNÉRATEUR SECRETS GITHUB ACTIONS ===" -ForegroundColor Green
Write-Host "Certificat: $CertPath" -ForegroundColor Cyan

# Vérifier certificat
if (-not (Test-Path $CertPath)) {
    Write-Host "[ERROR] Certificat introuvable: $CertPath" -ForegroundColor Red
    exit 1
}

# Validation certificat
Write-Host "`n🔍 VALIDATION CERTIFICAT" -ForegroundColor Blue
try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $CertPassword)
    Write-Host "   Subject: $($cert.Subject)" -ForegroundColor White
    Write-Host "   Issuer: $($cert.Issuer)" -ForegroundColor White
    Write-Host "   Valid from: $($cert.NotBefore)" -ForegroundColor White
    Write-Host "   Valid to: $($cert.NotAfter)" -ForegroundColor White
    
    # Type de certificat
    $certType = if ($cert.Subject -match "EV") { "Extended Validation (EV)" } 
                elseif ($cert.Subject -match "OV") { "Organization Validation (OV)" } 
                else { "Code Signing Standard" }
    Write-Host "   Type: $certType" -ForegroundColor $(if ($certType -match "EV") { "Green" } else { "Yellow" })
    
    # Vérification expiration
    $daysLeft = ($cert.NotAfter - (Get-Date)).Days
    if ($daysLeft -lt 30) {
        Write-Host "   [WARNING] Expire dans $daysLeft jours !" -ForegroundColor Red
    } else {
        Write-Host "   Valide pour: $daysLeft jours" -ForegroundColor Green
    }
} catch {
    Write-Host "   [ERROR] Certificat invalide: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Conversion Base64 propre (méthode recommandée)
Write-Host "`n📝 GÉNÉRATION BASE64" -ForegroundColor Blue
try {
    $certBytes = [IO.File]::ReadAllBytes($CertPath)
    $certBase64 = [Convert]::ToBase64String($certBytes)
    
    # Sauvegarder dans fichier temporaire (ASCII pur)
    $tempFile = "windows-cert.b64"
    $certBase64 | Set-Content -NoNewline -Encoding ascii $tempFile
    
    Write-Host "   Taille originale: $($certBytes.Length) bytes" -ForegroundColor White
    Write-Host "   Taille Base64: $($certBase64.Length) chars" -ForegroundColor White
    Write-Host "   Fichier généré: $tempFile" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] Conversion Base64 échouée: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Instructions GitHub détaillées
Write-Host "`n🚀 CONFIGURATION GITHUB REPOSITORY" -ForegroundColor Blue
$repoUrl = "https://github.com/150781/Yindo-USB-Video-Vault/settings/secrets/actions"
Write-Host "   1. Ouvrir: $repoUrl" -ForegroundColor Cyan
Write-Host "   2. Cliquer 'New repository secret'" -ForegroundColor Cyan

Write-Host "`n   📋 SECRET #1:" -ForegroundColor Green
Write-Host "   Name: WINDOWS_CERT_BASE64" -ForegroundColor White
Write-Host "   Value: (copier TOUT le contenu de $tempFile)" -ForegroundColor Yellow

Write-Host "`n   📋 SECRET #2:" -ForegroundColor Green
Write-Host "   Name: WINDOWS_CERT_PASSWORD" -ForegroundColor White
Write-Host "   Value: $CertPassword" -ForegroundColor Yellow

# Affichage Base64 avec instructions de copie
Write-Host "`n   ═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   📋 CONTENU À COPIER POUR WINDOWS_CERT_BASE64:" -ForegroundColor Yellow
Write-Host "   ═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host $certBase64 -ForegroundColor White
Write-Host "   ═══════════════════════════════════════" -ForegroundColor Cyan

# Instructions détaillées étapes suivantes
Write-Host "`n🔄 ÉTAPES SUIVANTES:" -ForegroundColor Blue

Write-Host "`n   1️⃣ CONFIGURER SECRETS:" -ForegroundColor Yellow
Write-Host "     - Aller sur $repoUrl" -ForegroundColor White
Write-Host "     - Ajouter WINDOWS_CERT_BASE64 avec le contenu ci-dessus" -ForegroundColor White
Write-Host "     - Ajouter WINDOWS_CERT_PASSWORD avec: $CertPassword" -ForegroundColor White

Write-Host "`n   2️⃣ TESTER SIGNATURE:" -ForegroundColor Yellow
Write-Host "     git tag v0.1.5-signed-test" -ForegroundColor Cyan
Write-Host "     git push origin v0.1.5-signed-test" -ForegroundColor Cyan
Write-Host "     # Surveiller: https://github.com/150781/Yindo-USB-Video-Vault/actions" -ForegroundColor Gray

Write-Host "`n   3️⃣ VÉRIFIER ARTEFACTS:" -ForegroundColor Yellow
Write-Host "     # Télécharger les EXE depuis la Release et vérifier:" -ForegroundColor Gray
Write-Host "     signtool verify /pa /v 'USB Video Vault Setup 0.1.5.exe'" -ForegroundColor Cyan
Write-Host "     Get-AuthenticodeSignature 'USB Video Vault Setup 0.1.5.exe'" -ForegroundColor Cyan

Write-Host "`n   4️⃣ RELEASE OFFICIELLE:" -ForegroundColor Yellow
Write-Host "     git tag v0.1.5" -ForegroundColor Cyan
Write-Host "     git push origin v0.1.5" -ForegroundColor Cyan

Write-Host "`n   5️⃣ TEST VM PROPRE:" -ForegroundColor Yellow
Write-Host "     .\tools\test-vm-windows.ps1" -ForegroundColor Cyan

# Récapitulatif sécurité
Write-Host "`n🔒 SÉCURITÉ:" -ForegroundColor Red
Write-Host "   - Supprimer $tempFile après usage !" -ForegroundColor Red
Write-Host "   - Ne jamais committer le certificat .pfx" -ForegroundColor Red
Write-Host "   - Les secrets GitHub sont chiffrés et sécurisés" -ForegroundColor Green

# Comportement SmartScreen attendu
Write-Host "`n🛡️ COMPORTEMENT SMARTSCREEN ATTENDU:" -ForegroundColor Blue
if ($certType -match "EV") {
    Write-Host "   ✅ EV Certificate → Aucun avertissement SmartScreen" -ForegroundColor Green
    Write-Host "   ✅ Installation silencieuse possible immédiatement" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  OV Certificate → Avertissement initial possible" -ForegroundColor Yellow
    Write-Host "   ✅ Réputation s'améliore après quelques téléchargements" -ForegroundColor Green
    Write-Host "   ✅ 'Informations complémentaires' → 'Exécuter quand même'" -ForegroundColor Yellow
}

Write-Host "`n✅ Prêt pour le déploiement avec signature de code !" -ForegroundColor Green

# Option: nettoyage auto du fichier temporaire
Write-Host "`nSupprimer le fichier temporaire $tempFile maintenant ? (Y/N)" -ForegroundColor Yellow
$cleanup = Read-Host
if ($cleanup -match "^[Yy]") {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    Write-Host "Fichier temporaire supprimé." -ForegroundColor Green
} else {
    Write-Host "ATTENTION: Supprimez manuellement $tempFile après usage !" -ForegroundColor Red
}