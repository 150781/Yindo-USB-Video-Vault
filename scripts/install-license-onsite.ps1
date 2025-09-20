#!/usr/bin/env pwsh
# Installation Licence Site Client - USB Video Vault

param(
    [Parameter(Mandatory=$true)]
    [string]$LicenseFile,
    
    [string]$VaultPath = "",
    [switch]$SkipVerify
)

Write-Host "INSTALLATION LICENCE SITE CLIENT" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# 1. Verifier licence source
if (-not (Test-Path $LicenseFile)) {
    Write-Error "Fichier licence introuvable: $LicenseFile"
    exit 1
}

$licenseSize = (Get-Item $LicenseFile).Length
Write-Host "Licence source: $LicenseFile ($licenseSize bytes)" -ForegroundColor Green

# 2. Detecter vault automatiquement
if (-not $VaultPath) {
    $VaultPath = $env:VAULT_PATH
}

if (-not $VaultPath) {
    $candidates = @(
        "$env:USERPROFILE\Documents\vault",
        "C:\vault",
        "D:\vault", 
        ".\vault"
    )
    
    foreach ($candidate in $candidates) {
        if (Test-Path "$candidate\.vault" -PathType Container) {
            $VaultPath = $candidate
            break
        }
    }
}

if (-not $VaultPath) {
    Write-Error "Vault non trouve. Specifier -VaultPath"
    exit 1
}

Write-Host "Vault detecte: $VaultPath" -ForegroundColor Green

# 3. Preparer destination
$vaultDir = "$VaultPath\.vault"
$licenseDest = "$vaultDir\license.bin"

if (-not (Test-Path $vaultDir)) {
    New-Item $vaultDir -ItemType Directory -Force | Out-Null
    Write-Host "Dossier .vault cree" -ForegroundColor Yellow
}

# Backup licence existante
if (Test-Path $licenseDest) {
    $backup = "$licenseDest.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $licenseDest $backup
    Write-Host "Licence existante sauvegardee: $backup" -ForegroundColor Yellow
}

# 4. Installer nouvelle licence
try {
    Copy-Item $LicenseFile $licenseDest -Force
    Write-Host "Licence installee avec succes" -ForegroundColor Green
    
    $newSize = (Get-Item $licenseDest).Length
    Write-Host "Taille installee: $newSize bytes" -ForegroundColor Gray
    
} catch {
    Write-Error "Erreur installation: $_"
    exit 1
}

# 5. Verification
if (-not $SkipVerify) {
    Write-Host "`nVerification..." -ForegroundColor Cyan
    
    # Test basique
    if (Test-Path $licenseDest) {
        Write-Host "OK Fichier present" -ForegroundColor Green
    } else {
        Write-Host "ERREUR Fichier manquant" -ForegroundColor Red
        exit 1
    }
    
    # Test integrite
    $destSize = (Get-Item $licenseDest).Length
    if ($destSize -eq $licenseSize) {
        Write-Host "OK Taille coherente" -ForegroundColor Green
    } else {
        Write-Host "ATTENTION Taille differente (source: $licenseSize, dest: $destSize)" -ForegroundColor Yellow
    }
    
    # Test avec script si disponible
    if (Test-Path "scripts\verify-license.mjs") {
        try {
            Write-Host "Test validation licence..." -ForegroundColor Yellow
            $output = & node scripts\verify-license.mjs $licenseDest 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "OK Licence valide" -ForegroundColor Green
            } else {
                Write-Host "ATTENTION Probleme validation: $output" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "ATTENTION Erreur verification: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "INFO Script verification non disponible" -ForegroundColor Gray
    }
}

Write-Host "`nINSTALLATION TERMINEE" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host "Licence: $licenseDest" -ForegroundColor White
Write-Host "Vault: $VaultPath" -ForegroundColor White

Write-Host "`nETAPES SUIVANTES:" -ForegroundColor Cyan
Write-Host "1. Lancer l'application USB Video Vault" -ForegroundColor White
Write-Host "2. Verifier affichage 'Licence validee'" -ForegroundColor White
Write-Host "3. Tester acces aux medias" -ForegroundColor White
Write-Host "4. En cas de probleme, consulter ONSITE_INSTALLATION_GUIDE.md" -ForegroundColor White

Write-Host "`nInstallation reussie" -ForegroundColor Green