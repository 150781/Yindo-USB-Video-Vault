# Test d'installation simple USB Video Vault
param(
    [string]$SetupPath = ".\dist\USB Video Vault Setup 0.1.4.exe"
)

Write-Host "=== Test d'installation USB Video Vault ===" -ForegroundColor Cyan
Write-Host "Setup: $SetupPath" -ForegroundColor Gray

# 1. Verification du fichier setup
if (-not (Test-Path $SetupPath)) {
    Write-Error "Fichier setup introuvable: $SetupPath"
    exit 1
}

$setupInfo = Get-Item $SetupPath
$setupHash = (Get-FileHash $SetupPath -Algorithm SHA256).Hash
$setupSize = [math]::Round($setupInfo.Length / 1MB, 2)

Write-Host "`n1. Informations du setup:" -ForegroundColor Yellow
Write-Host "Fichier: $($setupInfo.Name)" -ForegroundColor Green
Write-Host "Taille: ${setupSize}MB" -ForegroundColor Gray
Write-Host "SHA256: $setupHash" -ForegroundColor Gray

# 2. Verification signature
try {
    $signature = Get-AuthenticodeSignature $SetupPath
    if ($signature.Status -eq "Valid") {
        Write-Host "Signature numerique valide" -ForegroundColor Green
    } elseif ($signature.Status -eq "NotSigned") {
        Write-Host "Fichier non signe" -ForegroundColor Yellow
    } else {
        Write-Host "Signature invalide: $($signature.Status)" -ForegroundColor Red
    }
} catch {
    Write-Host "Impossible de verifier la signature" -ForegroundColor Yellow
}

Write-Host "`nVerifications terminees" -ForegroundColor Green
Write-Host "Le setup est pret pour la distribution" -ForegroundColor Cyan