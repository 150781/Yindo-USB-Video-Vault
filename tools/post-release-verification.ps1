# POST-RELEASE-VERIFICATION.PS1 - Verifications rapides post-release
param(
    [Parameter(Mandatory=$true)]
    [string]$Version = "0.1.5",
    
    [string]$ReleaseUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/v$Version"
)

$ErrorActionPreference = "Continue"

Write-Host "=== VERIFICATIONS POST-RELEASE v$Version ===" -ForegroundColor Green

# 1) Checksums locaux vs Release
Write-Host "`n1. VERIFICATION CHECKSUMS LOCAUX" -ForegroundColor Blue

$setupFile = ".\dist\USB Video Vault Setup $Version.exe"
$portableFile = ".\dist\USB Video Vault $Version.exe"
$sha256File = ".\dist\SHA256SUMS"

if (Test-Path $setupFile) {
    $localSetupHash = (Get-FileHash $setupFile -Algorithm SHA256).Hash.ToLower()
    Write-Host "   Setup local:    $localSetupHash" -ForegroundColor Cyan
} else {
    Write-Host "   [ERROR] Setup local introuvable: $setupFile" -ForegroundColor Red
}

if (Test-Path $portableFile) {
    $localPortableHash = (Get-FileHash $portableFile -Algorithm SHA256).Hash.ToLower()
    Write-Host "   Portable local: $localPortableHash" -ForegroundColor Cyan
} else {
    Write-Host "   [ERROR] Portable local introuvable: $portableFile" -ForegroundColor Red
}

# 2) Validation SHA256SUMS
Write-Host "`n2. VALIDATION SHA256SUMS" -ForegroundColor Blue

if (Test-Path $sha256File) {
    Write-Host "   Contenu SHA256SUMS:" -ForegroundColor Yellow
    Get-Content $sha256File | ForEach-Object { 
        Write-Host "     $_" -ForegroundColor White
    }
    
    # Verification format UNIX (pas de BOM)
    $bytes = [System.IO.File]::ReadAllBytes($sha256File)
    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "   [WARN] BOM UTF-8 detecte - devrait etre ASCII pur" -ForegroundColor Yellow
    } else {
        Write-Host "   [OK] Format ASCII/UNIX correct" -ForegroundColor Green
    }
} else {
    Write-Host "   [ERROR] SHA256SUMS introuvable: $sha256File" -ForegroundColor Red
}

# 3) Test téléchargement réel (SmartScreen/MOTW)
Write-Host "`n3. TEST TELECHARGEMENT REEL" -ForegroundColor Blue

if (Test-Path ".\tools\test-real-download.ps1") {
    try {
        Write-Host "   Lancement test-real-download.ps1..." -ForegroundColor Cyan
        & ".\tools\test-real-download.ps1" -Version $Version
    } catch {
        Write-Host "   [ERROR] Test download echec: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   [SKIP] tools\test-real-download.ps1 non trouve" -ForegroundColor Yellow
}

# 4) Vérification tailles fichiers
Write-Host "`n4. VERIFICATION TAILLES FICHIERS" -ForegroundColor Blue

if (Test-Path $setupFile) {
    $setupSize = (Get-Item $setupFile).Length
    Write-Host "   Setup:    $([math]::Round($setupSize/1MB,2)) MB ($setupSize bytes)" -ForegroundColor White
}

if (Test-Path $portableFile) {
    $portableSize = (Get-Item $portableFile).Length  
    Write-Host "   Portable: $([math]::Round($portableSize/1MB,2)) MB ($portableSize bytes)" -ForegroundColor White
}

# 5) Instructions Winget/Chocolatey
Write-Host "`n5. MISE A JOUR WINGET/CHOCOLATEY" -ForegroundColor Blue

Write-Host "   Winget installer.yaml:" -ForegroundColor Yellow
if (Test-Path $setupFile) {
    $setupHash = (Get-FileHash $setupFile -Algorithm SHA256).Hash.ToUpper()
    $setupSizeMB = [math]::Round((Get-Item $setupFile).Length/1MB,2)
    Write-Host "     InstallerUrl: https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v$Version/USB%20Video%20Vault%20Setup%20$Version.exe" -ForegroundColor Cyan
    Write-Host "     InstallerSha256: $setupHash" -ForegroundColor Cyan
    Write-Host "     Size (approx): ${setupSizeMB}MB" -ForegroundColor Cyan
}

Write-Host "`n   Chocolatey chocolateyinstall.ps1:" -ForegroundColor Yellow
if (Test-Path $setupFile) {
    Write-Host "     `$url = 'https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v$Version/USB%20Video%20Vault%20Setup%20$Version.exe'" -ForegroundColor Cyan
    Write-Host "     `$checksum = '$setupHash'" -ForegroundColor Cyan
    Write-Host "     silentArgs = '/S'" -ForegroundColor Cyan
}

# 6) Monitoring recommendations
Write-Host "`n6. MONITORING POST-RELEASE" -ForegroundColor Blue
Write-Host "   Commande monitoring 48h:" -ForegroundColor Yellow
Write-Host "     .\tools\monitor-release.ps1 -Version '$Version' -AllChecks" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Seuils rollback:" -ForegroundColor Yellow
Write-Host "     - Echecs install > 2%" -ForegroundColor White
Write-Host "     - SmartScreen bloquant > 5%" -ForegroundColor White
Write-Host "     - Crash-free < 99.5%" -ForegroundColor White
Write-Host ""
Write-Host "   Commande rollback d'urgence:" -ForegroundColor Yellow
Write-Host "     .\tools\emergency-rollback.ps1 -FromVersion '$Version' -ToVersion '0.1.4' -Execute" -ForegroundColor Cyan

Write-Host "`n=== VERIFICATION TERMINEE ===" -ForegroundColor Green
Write-Host "Release URL: $ReleaseUrl" -ForegroundColor Cyan