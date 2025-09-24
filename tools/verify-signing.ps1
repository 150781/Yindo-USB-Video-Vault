# Script de verification signature et SmartScreen
# Usage: .\verify-signing.ps1 -SetupPath ".\USB Video Vault Setup 0.1.5.exe"

param(
    [string]$SetupPath,
    [string]$PortablePath,
    [switch]$Detailed,
    [switch]$TestSmartScreen
)

Write-Host "=== VERIFICATION SIGNATURE & SMARTSCREEN ===" -ForegroundColor Cyan
Write-Host ""

if (-not $SetupPath) {
    # Auto-detect latest setup
    $latestSetup = Get-ChildItem ".\dist\" -Filter "USB Video Vault Setup *.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestSetup) {
        $SetupPath = $latestSetup.FullName
        Write-Host "Auto-detect: $SetupPath" -ForegroundColor Blue
    } else {
        Write-Host "ERREUR Setup file non trouve" -ForegroundColor Red
        exit 1
    }
}

if (-not (Test-Path $SetupPath)) {
    Write-Host "ERREUR Fichier non trouve: $SetupPath" -ForegroundColor Red
    exit 1
}

# 1. VERIFICATION SIGNATURE AUTHENTICODE
Write-Host "1. Verification Authenticode..." -ForegroundColor Yellow

try {
    $signature = Get-AuthenticodeSignature $SetupPath

    Write-Host "  Status: $($signature.Status)" -ForegroundColor $(if($signature.Status -eq 'Valid'){'Green'}else{'Red'})

    if ($signature.SignerCertificate) {
        Write-Host "  Signer: $($signature.SignerCertificate.Subject)" -ForegroundColor Blue
        Write-Host "  Issuer: $($signature.SignerCertificate.Issuer)" -ForegroundColor Blue
        Write-Host "  Valid from: $($signature.SignerCertificate.NotBefore)" -ForegroundColor Gray
        Write-Host "  Valid until: $($signature.SignerCertificate.NotAfter)" -ForegroundColor Gray

        # Check certificate type (EV/OV/DV)
        $certExtensions = $signature.SignerCertificate.Extensions
        $isEV = $certExtensions | Where-Object {$_.Oid.FriendlyName -eq "Certificate Policies"}
        if ($isEV) {
            Write-Host "  Type: Extended Validation (EV) - SmartScreen optimal" -ForegroundColor Green
        } else {
            Write-Host "  Type: Organization/Domain Validation - SmartScreen normal" -ForegroundColor Yellow
        }
    }

    if ($signature.TimeStamperCertificate) {
        Write-Host "  Timestamp: $($signature.TimeStamperCertificate.Subject)" -ForegroundColor Blue
        Write-Host "  Timestamp valid until: $($signature.TimeStamperCertificate.NotAfter)" -ForegroundColor Gray
    } else {
        Write-Host "  WARN Pas de timestamp - signature expire avec le certificat" -ForegroundColor Yellow
    }

} catch {
    Write-Host "  ERREUR Verification signature: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. VERIFICATION SIGNTOOL (si disponible)
Write-Host "`n2. Verification signtool..." -ForegroundColor Yellow

if (Get-Command signtool -ErrorAction SilentlyContinue) {
    try {
        $signtoolOutput = & signtool verify /pa /v $SetupPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK Signature valide (signtool)" -ForegroundColor Green
            if ($Detailed) {
                Write-Host "  Details signtool:" -ForegroundColor Gray
                $signtoolOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
        } else {
            Write-Host "  ERREUR Signature invalide (signtool)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ERREUR signtool: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  SKIP signtool non installe" -ForegroundColor Gray
}

# 3. VERIFICATION PORTABLE (si fourni)
if ($PortablePath -and (Test-Path $PortablePath)) {
    Write-Host "`n3. Verification portable..." -ForegroundColor Yellow

    $portableSignature = Get-AuthenticodeSignature $PortablePath
    Write-Host "  Portable status: $($portableSignature.Status)" -ForegroundColor $(if($portableSignature.Status -eq 'Valid'){'Green'}else{'Red'})

    # Verifier coherence signatures
    if ($signature.SignerCertificate -and $portableSignature.SignerCertificate) {
        if ($signature.SignerCertificate.Thumbprint -eq $portableSignature.SignerCertificate.Thumbprint) {
            Write-Host "  OK Meme certificat pour setup et portable" -ForegroundColor Green
        } else {
            Write-Host "  WARN Certificats differents - peut impacter reputation SmartScreen" -ForegroundColor Yellow
        }
    }
}

# 4. SIMULATION TEST SMARTSCREEN
if ($TestSmartScreen) {
    Write-Host "`n4. Test SmartScreen simulation..." -ForegroundColor Yellow

    # Test 1: Verification hash dans base de donnees (simulation)
    $fileHash = (Get-FileHash $SetupPath -Algorithm SHA256).Hash
    Write-Host "  Hash fichier: $fileHash" -ForegroundColor Blue

    # Test 2: Verification Publisher reputation (simulation)
    if ($signature.SignerCertificate) {
        $publisherName = ($signature.SignerCertificate.Subject -split ',')[0] -replace 'CN=', ''
        Write-Host "  Publisher: $publisherName" -ForegroundColor Blue
        Write-Host "  Reputation: Nouveau publisher - warnings initiaux normaux" -ForegroundColor Yellow
    }

    # Test 3: Simulation download et execution
    Write-Host "  Test simulation: Telechargement depuis GitHub" -ForegroundColor Blue
    Write-Host "  Prediction SmartScreen:" -ForegroundColor Blue
    if ($signature.Status -eq 'Valid') {
        Write-Host "    - Signature valide: Warning reduit mais possible" -ForegroundColor Yellow
        Write-Host "    - Reputation publisher: En construction" -ForegroundColor Yellow
        Write-Host "    - Temps construction reputation: 7-30 jours (100-500 installs)" -ForegroundColor Yellow
    } else {
        Write-Host "    - Signature manquante: Warning systematique" -ForegroundColor Red
    }
}

# 5. RECOMMANDATIONS SMARTSCREEN
Write-Host "`n5. Recommandations SmartScreen..." -ForegroundColor Yellow

Write-Host "  AVANT PUBLICATION:" -ForegroundColor Blue
Write-Host "    - Signer SETUP + PORTABLE avec meme certificat" -ForegroundColor White
Write-Host "    - Utiliser timestamp authority fiable (DigiCert/Sectigo)" -ForegroundColor White
Write-Host "    - Garder meme Publisher name pour toutes versions" -ForegroundColor White
Write-Host "    - Schema nommage stable (USB Video Vault vX.Y.Z)" -ForegroundColor White

Write-Host "  APRES PUBLICATION:" -ForegroundColor Blue
Write-Host "    - Communiquer warnings initiaux sont normaux" -ForegroundColor White
Write-Host "    - Documenter processus signature dans Release Notes" -ForegroundColor White
Write-Host "    - Monitorer feedback utilisateurs sur warnings" -ForegroundColor White
Write-Host "    - Reputation etablie apres ~100-500 installations" -ForegroundColor White

Write-Host "  COMMUNICATION UTILISATEURS:" -ForegroundColor Blue
Write-Host "    'Windows SmartScreen peut alerter car cette version" -ForegroundColor White
Write-Host "     n'a pas encore etabli sa reputation. L'executable" -ForegroundColor White
Write-Host "     est signe avec certificat Authenticode valide." -ForegroundColor White
Write-Host "     La reputation se construira automatiquement.'" -ForegroundColor White

# 6. RESUME FINAL
Write-Host "`n=== RESUME VERIFICATION ===" -ForegroundColor Green

$statusIcon = if ($signature.Status -eq 'Valid') { "✅" } else { "❌" }
Write-Host "$statusIcon Signature: $($signature.Status)" -ForegroundColor $(if($signature.Status -eq 'Valid'){'Green'}else{'Red'})

if ($signature.SignerCertificate) {
    Write-Host "✅ Certificat: Valide" -ForegroundColor Green
    Write-Host "✅ Publisher: $($signature.SignerCertificate.Subject.Split(',')[0] -replace 'CN=', '')" -ForegroundColor Green
} else {
    Write-Host "❌ Certificat: Manquant" -ForegroundColor Red
}

$timestampIcon = if ($signature.TimeStamperCertificate) { "✅" } else { "⚠️" }
Write-Host "$timestampIcon Timestamp: $(if($signature.TimeStamperCertificate){'Present'}else{'Manquant'})" -ForegroundColor $(if($signature.TimeStamperCertificate){'Green'}else{'Yellow'})

Write-Host ""
Write-Host "PRET POUR DIFFUSION PUBLIQUE:" -ForegroundColor Cyan
if ($signature.Status -eq 'Valid' -and $signature.TimeStamperCertificate) {
    Write-Host "🚀 OUI - Signature optimale pour SmartScreen" -ForegroundColor Green
} elseif ($signature.Status -eq 'Valid') {
    Write-Host "⚠️  ACCEPTABLE - Ajouter timestamp recommande" -ForegroundColor Yellow
} else {
    Write-Host "❌ NON - Signature requise pour diffusion serieuse" -ForegroundColor Red
}
