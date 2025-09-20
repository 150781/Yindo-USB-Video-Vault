#!/usr/bin/env pwsh
# Build and Sign - USB Video Vault
# Production-ready build with Authenticode signing

param(
    [string]$CertThumbprint = "",
    [switch]$SkipTests = $false,
    [switch]$Verbose = $false,
    [switch]$QuickMode = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$setupExe = "out\USB Video Vault Setup.exe"
$appExe = "out\win-unpacked\USB Video Vault.exe"

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "`nBUILD: $Message" -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-Step "Verification prerequis" "Yellow"
    
    # SignTool disponible
    try {
        & signtool 2>$null
    } catch {
        throw "SignTool.exe non trouve. Installer Windows SDK."
    }
    
    # Certificat disponible
    $certs = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue
    if (-not $certs -and -not $CertThumbprint) {
        $certs = Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue
    }
    if (-not $certs -and -not $CertThumbprint) {
        Write-Warning "Aucun certificat code signing trouve"
    }
    
    Write-Host "Prerequis valides" -ForegroundColor Green
}

function Invoke-Build {
    Write-Step "Build production" "Yellow"
    
    if (-not $QuickMode) {
        # Clean complet
        Remove-Item -Path "dist","out" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Clean effectue"
    }
    
    # Build
    & npm run build:all
    if ($LASTEXITCODE -ne 0) { throw "Build failed" }
    
    & npm run pack
    if ($LASTEXITCODE -ne 0) { throw "Package failed" }
    
    # Verifier artefacts
    if (-not (Test-Path $setupExe)) { throw "Setup exe manquant: $setupExe" }
    if (-not (Test-Path $appExe)) { throw "App exe manquant: $appExe" }
    
    $setupSize = [math]::Round((Get-Item $setupExe).Length / 1MB, 1)
    Write-Host "Build termine - Setup: ${setupSize}MB" -ForegroundColor Green
}

function Invoke-Signing {
    Write-Step "Signature Authenticode" "Yellow"
    
    # Arguments signature
    $signArgs = @("/fd", "SHA256", "/tr", "http://timestamp.digicert.com", "/td", "SHA256")
    if ($CertThumbprint) { 
        $signArgs += "/sha1", $CertThumbprint 
        Write-Host "Utilisation certificat: $CertThumbprint"
    } else { 
        $signArgs += "/a"
        Write-Host "Auto-detection certificat"
    }
    
    # Signature setup
    Write-Host "Signature setup..."
    & signtool sign @signArgs $setupExe
    if ($LASTEXITCODE -ne 0) { throw "Signature setup echouee" }
    
    # Signature app
    Write-Host "Signature application..."
    & signtool sign @signArgs $appExe
    if ($LASTEXITCODE -ne 0) { throw "Signature app echouee" }
    
    Write-Host "Signature terminee" -ForegroundColor Green
}

function Test-Signatures {
    Write-Step "Verification signatures" "Yellow"
    
    # Verification setup
    Write-Host "Verification setup..."
    & signtool verify /pa /all $setupExe
    if ($LASTEXITCODE -ne 0) { throw "Verification setup echouee" }
    
    # Verification app
    Write-Host "Verification application..."
    & signtool verify /pa /all $appExe
    if ($LASTEXITCODE -ne 0) { throw "Verification app echouee" }
    
    if ($Verbose) {
        Write-Host "`nDetails signatures:" -ForegroundColor Cyan
        & signtool verify /v $setupExe | Select-String "Issued to|Valid from|Valid to|Hash of file"
    }
    
    Write-Host "Signatures validees" -ForegroundColor Green
}

function Test-QualityAssurance {
    Write-Step "Tests qualite" "Yellow"
    
    if (-not $SkipTests) {
        Write-Host "Execution tests..."
        & npm test
        if ($LASTEXITCODE -ne 0) { throw "Tests QA echoues" }
    } else {
        Write-Host "Tests ignores (SkipTests)" -ForegroundColor Yellow
    }
    
    # Verifier tailles fichiers
    $setupSize = (Get-Item $setupExe).Length
    $appSize = (Get-Item $appExe).Length
    
    if ($setupSize -gt 300MB) {
        Write-Warning "Setup volumineux: $([math]::Round($setupSize/1MB, 1))MB"
    }
    
    if ($appSize -gt 150MB) {
        Write-Warning "Application volumineuse: $([math]::Round($appSize/1MB, 1))MB"
    }
    
    Write-Host "QA validee" -ForegroundColor Green
}

function Show-Summary {
    Write-Step "Resume build" "Green"
    
    $setupSize = [math]::Round((Get-Item $setupExe).Length / 1MB, 1)
    $appSize = [math]::Round((Get-Item $appExe).Length / 1MB, 1)
    
    Write-Host @"
ARTEFACTS SIGNES:
   • Setup: $setupExe (${setupSize}MB)
   • App:   $appExe (${appSize}MB)

SIGNATURE:
   • Algorithme: SHA256
   • Timestamp: DigiCert
   • Statut: Valide

PRET POUR DISTRIBUTION
"@ -ForegroundColor Green
}

# =============================================================================
# EXECUTION PRINCIPALE
# =============================================================================

try {
    Write-Host @"
BUILD ET SIGNATURE - USB Video Vault
====================================
"@ -ForegroundColor Cyan

    Test-Prerequisites
    
    if (-not $SkipTests) {
        Test-QualityAssurance
    }
    
    Invoke-Build
    Invoke-Signing
    Test-Signatures
    Show-Summary
    
    Write-Host "`nBUILD ET SIGNATURE REUSSIS" -ForegroundColor Green
    
} catch {
    Write-Host "`nERREUR: $_" -ForegroundColor Red
    exit 1
}