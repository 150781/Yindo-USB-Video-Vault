#!/usr/bin/env pwsh
# Quick Sign - Signature rapide pour build existant

param(
    [string]$FilePath = "",
    [string]$CertThumbprint = "",
    [switch]$SkipVerify
)

if (-not $FilePath) {
    # Auto-détection artefacts
    $candidates = @(
        "out\USB Video Vault Setup.exe",
        "out\win-unpacked\USB Video Vault.exe",
        "USB Video Vault.exe",
        "*.exe"
    )
    
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $FilePath = $candidate
            break
        }
    }
    
    if (-not $FilePath) {
        Write-Error "Aucun fichier .exe trouvé. Spécifier -FilePath"
        exit 1
    }
}

if (-not (Test-Path $FilePath)) {
    Write-Error "Fichier non trouvé: $FilePath"
    exit 1
}

Write-Host "🔐 Signature: $FilePath" -ForegroundColor Cyan

# Arguments signature
$signArgs = @("/fd", "SHA256", "/tr", "http://timestamp.digicert.com", "/td", "SHA256")
if ($CertThumbprint) { 
    $signArgs += "/sha1", $CertThumbprint 
} else { 
    $signArgs += "/a" 
}

# Signature
& signtool sign @signArgs $FilePath
if ($LASTEXITCODE -ne 0) {
    Write-Error "Signature échouée"
    exit 1
}

# Vérification
if (-not $SkipVerify) {
    Write-Host "🔍 Vérification..." -ForegroundColor Yellow
    & signtool verify /pa /all $FilePath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Signature validée" -ForegroundColor Green
    } else {
        Write-Error "Vérification échouée"
        exit 1
    }
}

Write-Host "🎉 Signature terminée: $FilePath" -ForegroundColor Green