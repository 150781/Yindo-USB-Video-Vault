# VERIFY-SIGNED-ARTIFACTS.PS1 - Vérification artefacts signés
param(
    [string]$Version = "0.1.5",
    [string]$DownloadPath = ".\downloads",
    [string]$ReleaseUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/v0.1.5"
)

$ErrorActionPreference = "Continue"

Write-Host "=== VÉRIFICATION ARTEFACTS SIGNÉS v$Version ===" -ForegroundColor Green

# Créer dossier de téléchargement
if (-not (Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

$setupFile = Join-Path $DownloadPath "USB Video Vault Setup $Version.exe"
$portableFile = Join-Path $DownloadPath "USB Video Vault $Version.exe"
$sha256File = Join-Path $DownloadPath "SHA256SUMS"

# URLs de téléchargement
$setupUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v$Version/USB%20Video%20Vault%20Setup%20$Version.exe"
$portableUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v$Version/USB%20Video%20Vault%20$Version.exe"
$sha256Url = "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v$Version/SHA256SUMS"

Write-Host "`n📥 TÉLÉCHARGEMENT ARTEFACTS" -ForegroundColor Blue

# Téléchargement Setup
Write-Host "   Téléchargement Setup..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $setupUrl -OutFile $setupFile -UseBasicParsing
    Write-Host "   ✅ Setup téléchargé: $setupFile" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Erreur Setup: $($_.Exception.Message)" -ForegroundColor Red
}

# Téléchargement Portable
Write-Host "   Téléchargement Portable..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $portableUrl -OutFile $portableFile -UseBasicParsing
    Write-Host "   ✅ Portable téléchargé: $portableFile" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Erreur Portable: $($_.Exception.Message)" -ForegroundColor Red
}

# Téléchargement SHA256SUMS
Write-Host "   Téléchargement SHA256SUMS..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $sha256Url -OutFile $sha256File -UseBasicParsing
    Write-Host "   ✅ SHA256SUMS téléchargé: $sha256File" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Erreur SHA256SUMS: $($_.Exception.Message)" -ForegroundColor Red
}

# Trouver signtool.exe
Write-Host "`n🔍 RECHERCHE SIGNTOOL.EXE" -ForegroundColor Blue
$signtool = (Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1).FullName
if ($signtool) {
    Write-Host "   ✅ Trouvé: $signtool" -ForegroundColor Green
} else {
    Write-Host "   ❌ signtool.exe non trouvé - installez Windows SDK" -ForegroundColor Red
    Write-Host "   📥 https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/" -ForegroundColor Yellow
}

# Vérifications de signature
Write-Host "`n🖊️ VÉRIFICATION SIGNATURES" -ForegroundColor Blue

# Vérifier Setup
if (Test-Path $setupFile) {
    Write-Host "`n   📦 SETUP.EXE:" -ForegroundColor Yellow
    
    # signtool verify
    if ($signtool) {
        try {
            Write-Host "     signtool verify:" -ForegroundColor Cyan
            & "$signtool" verify /pa /v "$setupFile"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "     ✅ Signature valide (signtool)" -ForegroundColor Green
            } else {
                Write-Host "     ❌ Signature invalide (signtool)" -ForegroundColor Red
            }
        } catch {
            Write-Host "     ❌ Erreur signtool: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # PowerShell verify
    try {
        Write-Host "     PowerShell verify:" -ForegroundColor Cyan
        $signature = Get-AuthenticodeSignature $setupFile
        Write-Host "       Status: $($signature.Status)" -ForegroundColor $(if ($signature.Status -eq "Valid") { "Green" } else { "Red" })
        if ($signature.SignerCertificate) {
            Write-Host "       Signer: $($signature.SignerCertificate.Subject)" -ForegroundColor White
            Write-Host "       Issuer: $($signature.SignerCertificate.Issuer)" -ForegroundColor White
        }
        if ($signature.TimeStamperCertificate) {
            Write-Host "       Timestamp: $($signature.TimeStamperCertificate.Subject)" -ForegroundColor White
        }
        Write-Host "       Hash: $($signature.HashAlgorithm)" -ForegroundColor White
    } catch {
        Write-Host "     ❌ Erreur PowerShell: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Vérifier Portable
if (Test-Path $portableFile) {
    Write-Host "`n   📱 PORTABLE.EXE:" -ForegroundColor Yellow
    
    # signtool verify
    if ($signtool) {
        try {
            Write-Host "     signtool verify:" -ForegroundColor Cyan
            & "$signtool" verify /pa /v "$portableFile"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "     ✅ Signature valide (signtool)" -ForegroundColor Green
            } else {
                Write-Host "     ❌ Signature invalide (signtool)" -ForegroundColor Red
            }
        } catch {
            Write-Host "     ❌ Erreur signtool: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # PowerShell verify
    try {
        Write-Host "     PowerShell verify:" -ForegroundColor Cyan
        $signature = Get-AuthenticodeSignature $portableFile
        Write-Host "       Status: $($signature.Status)" -ForegroundColor $(if ($signature.Status -eq "Valid") { "Green" } else { "Red" })
    } catch {
        Write-Host "     ❌ Erreur PowerShell: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Vérification checksums
Write-Host "`n🔒 VÉRIFICATION CHECKSUMS" -ForegroundColor Blue

if (Test-Path $sha256File) {
    Write-Host "   Contenu SHA256SUMS:" -ForegroundColor Cyan
    Get-Content $sha256File | ForEach-Object { 
        Write-Host "     $_" -ForegroundColor White
    }
    
    # Vérifier Setup hash
    if (Test-Path $setupFile) {
        $setupHash = (Get-FileHash $setupFile -Algorithm SHA256).Hash.ToLower()
        $setupName = Split-Path $setupFile -Leaf
        $expectedLine = Get-Content $sha256File | Where-Object { $_ -match [regex]::Escape($setupName) }
        
        Write-Host "`n   Setup hash verification:" -ForegroundColor Cyan
        Write-Host "     Calculé:  $setupHash" -ForegroundColor White
        Write-Host "     Attendu:  $expectedLine" -ForegroundColor White
        
        if ($expectedLine -and $expectedLine.StartsWith($setupHash)) {
            Write-Host "     ✅ Hash Setup correspond" -ForegroundColor Green
        } else {
            Write-Host "     ❌ Hash Setup ne correspond pas" -ForegroundColor Red
        }
    }
    
    # Vérifier Portable hash
    if (Test-Path $portableFile) {
        $portableHash = (Get-FileHash $portableFile -Algorithm SHA256).Hash.ToLower()
        $portableName = Split-Path $portableFile -Leaf
        $expectedLine = Get-Content $sha256File | Where-Object { $_ -match [regex]::Escape($portableName) }
        
        Write-Host "`n   Portable hash verification:" -ForegroundColor Cyan
        Write-Host "     Calculé:  $portableHash" -ForegroundColor White
        Write-Host "     Attendu:  $expectedLine" -ForegroundColor White
        
        if ($expectedLine -and $expectedLine.StartsWith($portableHash)) {
            Write-Host "     ✅ Hash Portable correspond" -ForegroundColor Green
        } else {
            Write-Host "     ❌ Hash Portable ne correspond pas" -ForegroundColor Red
        }
    }
}

# Informations fichiers
Write-Host "`n📊 INFORMATIONS FICHIERS" -ForegroundColor Blue

if (Test-Path $setupFile) {
    $setupSize = (Get-Item $setupFile).Length
    Write-Host "   Setup:    $([math]::Round($setupSize/1MB,2)) MB ($setupSize bytes)" -ForegroundColor White
}

if (Test-Path $portableFile) {
    $portableSize = (Get-Item $portableFile).Length  
    Write-Host "   Portable: $([math]::Round($portableSize/1MB,2)) MB ($portableSize bytes)" -ForegroundColor White
}

# Instructions VM test
Write-Host "`n🖥️ PROCHAINES ÉTAPES - TEST VM:" -ForegroundColor Blue
Write-Host "   1. Préparer VM Windows 10/11 vierge" -ForegroundColor Cyan
Write-Host "   2. Télécharger depuis GitHub Release (MOTW nécessaire)" -ForegroundColor Cyan
Write-Host "   3. Tester installation avec SmartScreen activé" -ForegroundColor Cyan
Write-Host "   4. Vérifier comportement:" -ForegroundColor Cyan
Write-Host "      - EV Certificate: Installation directe" -ForegroundColor Green
Write-Host "      - OV Certificate: 'Informations complémentaires' → 'Exécuter quand même'" -ForegroundColor Yellow
Write-Host "   5. Script disponible: .\tools\test-vm-windows.ps1" -ForegroundColor Cyan

Write-Host "`n=== VÉRIFICATION TERMINÉE ===" -ForegroundColor Green
Write-Host "Artefacts dans: $DownloadPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseUrl" -ForegroundColor Cyan