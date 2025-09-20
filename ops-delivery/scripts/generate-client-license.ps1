# Workflow Opérateur One-Liner - Génération licence complète

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientFingerprint,
    
    [string]$UsbSerial = "",
    [int]$Kid = 1,
    [string]$ExpirationDate = "",
    [string]$ClientName = "client",
    [switch]$SkipVerification = $false
)

# Configuration par défaut
if (-not $ExpirationDate) {
    $ExpirationDate = (Get-Date).AddYears(1).ToString("yyyy-MM-ddT23:59:59Z")
}

Write-Host "=== GENERATION LICENCE CLIENT ===" -ForegroundColor Cyan
Write-Host "Client: $ClientName" -ForegroundColor White
Write-Host "Fingerprint: $ClientFingerprint" -ForegroundColor White
Write-Host "USB: $(if($UsbSerial) { $UsbSerial } else { '(aucun)' })" -ForegroundColor White
Write-Host "Kid: $Kid" -ForegroundColor White
Write-Host "Expiration: $ExpirationDate" -ForegroundColor White
Write-Host "=================================" -ForegroundColor Cyan

# Vérifier secret
if (-not $env:PACKAGER_PRIVATE_HEX) {
    Write-Host "ERROR: Variable PACKAGER_PRIVATE_HEX non définie" -ForegroundColor Red
    Write-Host "Exécuter: `$env:PACKAGER_PRIVATE_HEX = '[SECRET_VAULT]'" -ForegroundColor Yellow
    exit 1
}

# 1. Générer licence
Write-Host "1. Génération licence..." -ForegroundColor Yellow
$makeArgs = @($ClientFingerprint)
if ($UsbSerial) { $makeArgs += $UsbSerial }
$makeArgs += "--kid", $Kid, "--exp", $ExpirationDate

try {
    & node scripts/make-license.mjs @makeArgs
    if ($LASTEXITCODE -ne 0) { throw "Erreur génération" }
    Write-Host "OK Licence générée" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Vérification (optionnelle)
if (-not $SkipVerification) {
    Write-Host "2. Vérification..." -ForegroundColor Yellow
    try {
        & node scripts/verify-license.mjs "vault-real"
        if ($LASTEXITCODE -ne 0) { throw "Erreur vérification" }
        Write-Host "OK Licence valide" -ForegroundColor Green
    } catch {
        Write-Host "WARN: Vérification échouée" -ForegroundColor Yellow
    }
}

# 3. Préparation package client
Write-Host "3. Préparation package client..." -ForegroundColor Yellow
$packageDir = "delivery-$ClientName"
if (Test-Path $packageDir) { Remove-Item $packageDir -Recurse -Force }
New-Item -ItemType Directory -Path $packageDir | Out-Null

# Copier fichiers essentiels
Copy-Item "vault-real\.vault\license.bin" "$packageDir\" -ErrorAction Stop
Copy-Item "scripts\post-install-client-clean.ps1" "$packageDir\install.ps1" -ErrorAction Stop
Copy-Item "docs\CLIENT_LICENSE_GUIDE.md" "$packageDir\README.md" -ErrorAction Stop

# Créer infos package
$packageInfo = @"
PACKAGE LICENCE CLIENT - $ClientName
=====================================
Date génération: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Fingerprint: $ClientFingerprint
$(if($UsbSerial) { "USB Serial: $UsbSerial" })
Kid: $Kid
Expiration: $ExpirationDate

FICHIERS:
- license.bin      (licence principale)
- install.ps1      (script installation automatique) 
- README.md        (guide client)

INSTRUCTIONS CLIENT:
1. Extraire ce package
2. PowerShell en admin: .\install.ps1
3. Vérifier message "INSTALLATION REUSSIE"
4. Si problème: capture écran au support

Support: support@yindo.com
"@

Set-Content -Path "$packageDir\PACKAGE-INFO.txt" -Value $packageInfo -Encoding UTF8

Write-Host "OK Package créé: $packageDir" -ForegroundColor Green

# 4. Résumé final
Write-Host "`n=== LIVRAISON PRÊTE ===" -ForegroundColor Green
Write-Host "Package: $packageDir" -ForegroundColor White
Write-Host "Fichiers: $(Get-ChildItem $packageDir | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White

$packageSize = Get-ChildItem $packageDir -File | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum
Write-Host "Taille: $([math]::Round($packageSize/1KB, 1)) KB" -ForegroundColor White

Write-Host "`nActions suivantes:" -ForegroundColor Cyan
Write-Host "1. Zip le dossier $packageDir" -ForegroundColor White
Write-Host "2. Envoyer au client" -ForegroundColor White
Write-Host "3. Donner instructions: .\install.ps1" -ForegroundColor White

Write-Host "`nGénération terminée avec succès! ✅" -ForegroundColor Green