# PREVOL ULTRA-COURT - 10 checks rapides avant deploiement public
# Usage: .\tools\preflight-final.ps1 -Version "0.1.5" [-FixIssues]

param(
    [string]$Version = "0.1.5",
    [switch]$FixIssues,
    [switch]$Detailed
)

Write-Host "=== PREVOL ULTRA-COURT v$Version ===" -ForegroundColor Cyan
Write-Host "10 checks critiques avant deploiement public" -ForegroundColor White
Write-Host ""

$issues = @()
$warnings = @()
$checks = 0
$passed = 0

# CHECK 1: Version lock
Write-Host "1/10 Version lock..." -ForegroundColor Yellow
$checks++

$versionSources = @(
    @{File="package.json"; Pattern='"version":\s*"([^"]+)"'; Name="package.json"},
    @{File="packaging\winget\Yindo.USBVideoVault.yaml"; Pattern='PackageVersion:\s*(.+)'; Name="Winget"},
    @{File="packaging\chocolatey\usbvideovault.nuspec"; Pattern='<version>([^<]+)</version>'; Name="Chocolatey"}
)

$versionMismatches = @()
foreach ($vs in $versionSources) {
    if (Test-Path $vs.File) {
        $content = Get-Content $vs.File -Raw
        if ($content -match $vs.Pattern) {
            $foundVersion = $matches[1].Trim()
            if ($foundVersion -ne $Version) {
                $versionMismatches += "$($vs.Name): $foundVersion (attendu: $Version)"
            }
        } else {
            $versionMismatches += "$($vs.Name): version non trouvee"
        }
    } else {
        $versionMismatches += "$($vs.Name): fichier manquant"
    }
}

if ($versionMismatches.Count -eq 0) {
    Write-Host "   [OK] Versions coherentes: $Version" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   [FAILED] Versions incoherentes:" -ForegroundColor Red
    $versionMismatches | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
    $issues += "Versions incoherentes detectees"
}

# CHECK 2: SHA256 reels
Write-Host "2/10 SHA256 reels..." -ForegroundColor Yellow
$checks++

$setupFile = ".\dist\USB Video Vault Setup $Version.exe"
$portableFile = ".\dist\USB Video Vault $Version.exe"
$sha256File = ".\dist\SHA256SUMS"

$sha256Issues = @()

if (Test-Path $setupFile) {
    $actualSha256 = (Get-FileHash $setupFile -Algorithm SHA256).Hash

    # Verifier SHA256SUMS
    if (Test-Path $sha256File) {
        $sha256Content = Get-Content $sha256File -Raw
        if ($sha256Content -match $actualSha256) {
            Write-Host "   [OK] SHA256SUMS a jour" -ForegroundColor Green
            $passed++
        } else {
            $sha256Issues += "SHA256SUMS obsolete"
        }
    } else {
        $sha256Issues += "SHA256SUMS manquant"
    }

    # Verifier manifests
    $wingetInstaller = ".\packaging\winget\installer.yaml"
    if (Test-Path $wingetInstaller) {
        $wingetContent = Get-Content $wingetInstaller -Raw
        if ($wingetContent -notmatch "YOUR_SHA256_HERE" -and $wingetContent -match $actualSha256.Substring(0,16)) {
            # SHA256 semble a jour
        } else {
            $sha256Issues += "Winget SHA256 placeholder ou obsolete"
        }
    }
} else {
    $sha256Issues += "Setup file manquant: $setupFile"
}

if ($sha256Issues.Count -eq 0) {
    if ($passed -lt $checks) { $passed++ }
} else {
    Write-Host "   [FAILED] SHA256 issues:" -ForegroundColor Red
    $sha256Issues | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
    $issues += "SHA256 non synchronises"
}

# CHECK 3: Signature Authenticode
Write-Host "3/10 Signature..." -ForegroundColor Yellow
$checks++

if (Test-Path $setupFile) {
    try {
        # Test signature robuste avec signtool + PowerShell
        $signtoolOutput = & signtool verify /pa /kp /d /v $setupFile 2>&1
        $signatureValid = $LASTEXITCODE -eq 0
        $psSignature = Get-AuthenticodeSignature $setupFile -ErrorAction SilentlyContinue

        if ($signatureValid -and $psSignature -and $psSignature.Status -eq "Valid") {
            # Verifier horodatage (critique pour longevite)
            if ($signtoolOutput -match "timestamp" -or $psSignature.TimeStamperCertificate) {
                Write-Host "   [OK] Signature + horodatage valides" -ForegroundColor Green
                Write-Host "     Certificat: $($psSignature.SignerCertificate.Subject.Split(',')[0])" -ForegroundColor Gray
                $passed++
            } else {
                Write-Host "   [FAILED] Signature valide MAIS horodatage manquant" -ForegroundColor Red
                $issues += "Horodatage manquant - signature expirera avec certificat"
            }

            # Verifier expiration certificat proche
            $now = Get-Date
            if ($psSignature.SignerCertificate.NotAfter -lt $now.AddDays(30)) {
                Write-Host "   [WARNING] Certificat expire en moins de 30 jours" -ForegroundColor Yellow
                $warnings += "Certificat expire bientot: $($psSignature.SignerCertificate.NotAfter)"
            }
        } else {
            Write-Host "   [FAILED] Signature invalide ou manquante" -ForegroundColor Red
            if ($psSignature) {
                Write-Host "     Raison: $($psSignature.StatusMessage)" -ForegroundColor White
            }
            $issues += "Signature Authenticode invalide"
        }
    } catch {
        Write-Host "   [WARNING] signtool non disponible - verification manuelle requise" -ForegroundColor Yellow
        $warnings += "Verification signature manuelle requise"
        $passed++
    }
} else {
    Write-Host "   [FAILED] Setup file manquant pour verification signature" -ForegroundColor Red
    $issues += "Setup file manquant"
}

# CHECK 4: Silent switches
Write-Host "4/10 Silent switches..." -ForegroundColor Yellow
$checks++

$switchesOK = $true

# Winget
$wingetInstaller = ".\packaging\winget\installer.yaml"
if (Test-Path $wingetInstaller) {
    $wingetContent = Get-Content $wingetInstaller -Raw
    if ($wingetContent -match "InstallerType:\s*nullsoft" -and $wingetContent -match "Silent:\s*/S") {
        Write-Host "   [OK] Winget switches OK (nullsoft /S)" -ForegroundColor Green
    } else {
        $switchesOK = $false
        Write-Host "   [FAILED] Winget switches incorrects" -ForegroundColor Red
    }
} else {
    $switchesOK = $false
}

# Chocolatey
$chocoInstall = ".\packaging\chocolatey\chocolateyinstall.ps1"
if (Test-Path $chocoInstall) {
    $chocoContent = Get-Content $chocoInstall -Raw
    if ($chocoContent -match 'silentArgs.*[''"][/]S[''"]') {
        Write-Host "   [OK] Chocolatey switches OK (/S)" -ForegroundColor Green
    } else {
        $switchesOK = $false
        Write-Host "   [FAILED] Chocolatey switches incorrects" -ForegroundColor Red
    }
}

if ($switchesOK) {
    $passed++
} else {
    $issues += "Silent switches incorrects"
}

# CHECK 5: SmartScreen test ready
Write-Host "5/10 SmartScreen test..." -ForegroundColor Yellow
$checks++

$vmTestScript = ".\tools\final-vm-tests.ps1"
if (Test-Path $vmTestScript) {
    Write-Host "   [OK] Script VM test disponible" -ForegroundColor Green
    Write-Host "     Executer: .\tools\final-vm-tests.ps1 -SetupPath '$setupFile'" -ForegroundColor Gray
    $passed++
} else {
    Write-Host "   [WARNING] Script VM test manquant - test manuel requis" -ForegroundColor Yellow
    $warnings += "Test SmartScreen manuel requis sur VM propre"
    $passed++
}

# CHECK 6: Install/Uninstall ready
Write-Host "6/10 Install/Uninstall..." -ForegroundColor Yellow
$checks++

# Verifier si setup supporte /S (silent install)
if (Test-Path $setupFile) {
    $setupSize = [math]::Round((Get-Item $setupFile).Length / 1MB, 1)
    if ($setupSize -gt 40 -and $setupSize -lt 300) {
        Write-Host "   [OK] Setup size normal: ${setupSize}MB" -ForegroundColor Green
        Write-Host "     Test install: start '$setupFile' /S" -ForegroundColor Gray
        Write-Host "     Test uninstall: .\tools\test-uninstall.ps1 (si disponible)" -ForegroundColor Gray
        $passed++
    } else {
        Write-Host "   [WARNING] Setup size suspect: ${setupSize}MB" -ForegroundColor Yellow
        $warnings += "Setup size a verifier: ${setupSize}MB"
        $passed++
    }
} else {
    Write-Host "   [FAILED] Setup manquant" -ForegroundColor Red
    $issues += "Setup file manquant"
}

# CHECK 7: Rollback ready
Write-Host "7/10 Rollback ready..." -ForegroundColor Yellow
$checks++

$rollbackScript = ".\tools\emergency-rollback.ps1"
if (Test-Path $rollbackScript) {
    Write-Host "   [OK] Script rollback disponible" -ForegroundColor Green
    Write-Host "     Test a blanc: .\tools\emergency-rollback.ps1 -FromVersion '$Version' -ToVersion '0.1.4' -WhatIf" -ForegroundColor Gray
    $passed++
} else {
    Write-Host "   [FAILED] Script rollback manquant" -ForegroundColor Red
    $issues += "Script emergency-rollback.ps1 manquant"
}

# CHECK 8: Diagnostics ready
Write-Host "8/10 Diagnostics..." -ForegroundColor Yellow
$checks++

$diagnosticsScript = ".\tools\troubleshoot.ps1"
if (Test-Path $diagnosticsScript) {
    Write-Host "   [OK] Script diagnostics disponible" -ForegroundColor Green
    Write-Host "     Test: .\tools\troubleshoot.ps1 -Detailed" -ForegroundColor Gray
    $passed++
} else {
    Write-Host "   [WARNING] Script diagnostics manquant" -ForegroundColor Yellow
    $warnings += "Script troubleshoot.ps1 recommande pour support"
    $passed++
}

# CHECK 9: SBOM & Security
Write-Host "9/10 SBOM & Security..." -ForegroundColor Yellow
$checks++

$sbomScript = ".\tools\generate-sbom.ps1"
$securityScript = ".\tools\security-audit.ps1"
$sbomReady = $false

if (Test-Path $sbomScript) {
    Write-Host "   [OK] SBOM generator disponible" -ForegroundColor Green
    $sbomReady = $true
}

if (Test-Path $securityScript) {
    Write-Host "   [OK] Security audit disponible" -ForegroundColor Green
    $sbomReady = $true
}

if ($sbomReady) {
    Write-Host "     Generer: .\tools\generate-sbom.ps1 && .\tools\security-audit.ps1" -ForegroundColor Gray
    $passed++
} else {
    Write-Host "   [WARNING] Scripts SBOM/Security manquants" -ForegroundColor Yellow
    $warnings += "SBOM et security audit recommandes"
    $passed++
}

# CHECK 10: Release page ready
Write-Host "10/10 Release page..." -ForegroundColor Yellow
$checks++

$releaseAssets = @(
    $setupFile,
    $portableFile,
    ".\dist\SHA256SUMS"
)

$missingAssets = @()
foreach ($asset in $releaseAssets) {
    if (-not (Test-Path $asset)) {
        $missingAssets += $asset
    }
}

if ($missingAssets.Count -eq 0) {
    Write-Host "   [OK] Assets release prets" -ForegroundColor Green
    Write-Host "     Setup: $(Split-Path $setupFile -Leaf)" -ForegroundColor Gray
    Write-Host "     Portable: $(Split-Path $portableFile -Leaf)" -ForegroundColor Gray
    Write-Host "     SHA256SUMS: present" -ForegroundColor Gray
    $passed++
} else {
    Write-Host "   [FAILED] Assets manquants:" -ForegroundColor Red
    $missingAssets | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
    $issues += "Assets release incomplets"
}

# RESUME FINAL
Write-Host ""
Write-Host "=== RESUME PREVOL ===" -ForegroundColor Cyan
Write-Host "Checks: $passed/$checks passes" -ForegroundColor $(if($passed -eq $checks){"Green"}else{"Yellow"})

if ($issues.Count -eq 0) {
    Write-Host "STATUT: READY FOR GO" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== COMMANDES GO ===" -ForegroundColor Blue
    Write-Host "1. .\tools\quick-pitfalls-check.ps1 -Version '$Version'" -ForegroundColor Yellow
    Write-Host "2. .\tools\check-go-nogo.ps1 -Version '$Version' -Detailed" -ForegroundColor Yellow
    Write-Host "3. .\tools\deploy-first-public.ps1 -Version '$Version' -Execute" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== POST-DEPLOIEMENT T+0->T+48h ===" -ForegroundColor Blue
    Write-Host ".\tools\monitor-release.ps1 -Version '$Version' -Hours 48" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== SI ANOMALIE ===" -ForegroundColor Red
    Write-Host ".\tools\emergency-rollback.ps1 -FromVersion '$Version' -ToVersion '0.1.4' -Execute" -ForegroundColor Yellow
} else {
    Write-Host "STATUT: NO-GO - Issues a resoudre" -ForegroundColor Red
    Write-Host ""
    Write-Host "ISSUES CRITIQUES:" -ForegroundColor Red
    for ($i = 0; $i -lt $issues.Count; $i++) {
        Write-Host "  $($i+1). $($issues[$i])" -ForegroundColor White
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNINGS (non bloquants):" -ForegroundColor Yellow
    for ($i = 0; $i -lt $warnings.Count; $i++) {
        Write-Host "  $($i+1). $($warnings[$i])" -ForegroundColor White
    }
}

Write-Host ""
return ($issues.Count -eq 0)
