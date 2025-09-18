# 🖊️ Signature Windows (Authenticode)
# Requires: Windows SDK + Code Signing Certificate

param(
    [Parameter(Mandatory=$true)]
    [string]$ExePath,
    
    [Parameter(Mandatory=$false)]
    [string]$CertPath = ".\certs\code-signing.pfx",
    
    [Parameter(Mandatory=$false)]
    [string]$TimestampUrl = "http://timestamp.sectigo.com"
)

Write-Host "🔏 === SIGNATURE WINDOWS AUTHENTICODE ===" -ForegroundColor Cyan

# Vérifier les prérequis
if (!(Test-Path $ExePath)) {
    Write-Error "❌ Fichier EXE introuvable: $ExePath"
    exit 1
}

if (!(Test-Path $CertPath)) {
    Write-Error "❌ Certificat introuvable: $CertPath"
    exit 1
}

if (!$env:PFX_PASSWORD) {
    Write-Error "❌ Variable PFX_PASSWORD non définie"
    exit 1
}

# Signature
Write-Host "🖊️ Signature en cours..." -ForegroundColor Yellow
try {
    & signtool sign /fd SHA256 /f $CertPath /p $env:PFX_PASSWORD `
        /tr $TimestampUrl /td SHA256 `
        /d "USB Video Vault" `
        /du "https://usbvideovault.com" `
        $ExePath
    
    if ($LASTEXITCODE -ne 0) {
        throw "Signature failed with code $LASTEXITCODE"
    }
    
    Write-Host "✅ Signature réussie" -ForegroundColor Green
} catch {
    Write-Error "❌ Erreur signature: $_"
    exit 1
}

# Vérification
Write-Host "🔍 Vérification de la signature..." -ForegroundColor Yellow
try {
    & signtool verify /pa /v $ExePath
    
    if ($LASTEXITCODE -ne 0) {
        throw "Verification failed with code $LASTEXITCODE"
    }
    
    Write-Host "✅ Signature vérifiée et valide" -ForegroundColor Green
} catch {
    Write-Error "❌ Erreur vérification: $_"
    exit 1
}

# Hash final
Write-Host "📊 Génération hash SHA256..." -ForegroundColor Yellow
$hash = (certutil -hashfile $ExePath SHA256 | Select-String -Pattern "^[0-9a-f]{64}$").Line
Write-Host "🔢 SHA256: $hash" -ForegroundColor Magenta

Write-Host "🎉 Signature Windows terminée avec succès !" -ForegroundColor Green