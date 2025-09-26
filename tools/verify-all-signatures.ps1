# Script de verification signature complete de tous les binaires
# Usage: .\tools\verify-all-signatures.ps1 -Version "0.1.5" [-Detailed]

param(
    [string]$Version = "0.1.5",
    [switch]$Detailed
)

Write-Host "=== VERIFICATION SIGNATURES COMPLETES v$Version ===" -ForegroundColor Cyan
Write-Host ""

$filesToCheck = @(
    @{Path=".\dist\USB Video Vault Setup $Version.exe"; Type="Setup"; Critical=$true},
    @{Path=".\dist\USB Video Vault $Version.exe"; Type="Portable"; Critical=$true},
    @{Path=".\dist\win-unpacked\USB Video Vault.exe"; Type="Main Binary"; Critical=$true},
    @{Path=".\dist\win-unpacked\resources\app.asar"; Type="App Bundle"; Critical=$false}
)

# Rechercher DLLs et autres binaires
$additionalBinaries = Get-ChildItem ".\dist\win-unpacked" -Recurse -Include "*.exe","*.dll" -ErrorAction SilentlyContinue
foreach ($binary in $additionalBinaries) {
    $filesToCheck += @{Path=$binary.FullName; Type="Binary ($($binary.Name))"; Critical=$false}
}

$totalFiles = 0
$signedFiles = 0
$validSignatures = 0
$timestampedFiles = 0
$issues = @()

Write-Host "Fichiers a verifier: $($filesToCheck.Count)" -ForegroundColor Yellow
Write-Host ""

foreach ($fileInfo in $filesToCheck) {
    $filePath = $fileInfo.Path
    $fileType = $fileInfo.Type
    $isCritical = $fileInfo.Critical

    if (-not (Test-Path $filePath)) {
        if ($isCritical) {
            Write-Host "[$fileType] MANQUANT: $filePath" -ForegroundColor Red
            $issues += "Fichier critique manquant: $filePath"
        } else {
            Write-Host "[$fileType] Optionnel manquant: $filePath" -ForegroundColor Gray
        }
        continue
    }

    $totalFiles++
    Write-Host "[$fileType] $filePath" -ForegroundColor White

    try {
        # Test signature PowerShell
        $psSignature = Get-AuthenticodeSignature $filePath -ErrorAction SilentlyContinue

        if ($psSignature -and $psSignature.Status -eq "Valid") {
            $signedFiles++
            $validSignatures++

            Write-Host "  Signature: VALIDE" -ForegroundColor Green
            Write-Host "  Certificat: $($psSignature.SignerCertificate.Subject.Split(',')[0])" -ForegroundColor Gray

            # Verification horodatage
            if ($psSignature.TimeStamperCertificate) {
                $timestampedFiles++
                Write-Host "  Horodatage: PRESENT" -ForegroundColor Green
                if ($Detailed) {
                    Write-Host "    TSA: $($psSignature.TimeStamperCertificate.Subject.Split(',')[0])" -ForegroundColor Gray
                }
            } else {
                Write-Host "  Horodatage: MANQUANT" -ForegroundColor Red
                if ($isCritical) {
                    $issues += "Horodatage manquant sur fichier critique: $filePath"
                }
            }

            # Verification expiration
            $now = Get-Date
            $daysToExpiry = ($psSignature.SignerCertificate.NotAfter - $now).Days
            if ($daysToExpiry -lt 30) {
                Write-Host "  Expiration: $daysToExpiry jours" -ForegroundColor Yellow
                if ($daysToExpiry -lt 7) {
                    $issues += "Certificat expire dans $daysToExpiry jours: $filePath"
                }
            } elseif ($Detailed) {
                Write-Host "  Expiration: $daysToExpiry jours" -ForegroundColor Gray
            }

        } elseif ($psSignature -and $psSignature.Status -eq "NotSigned") {
            Write-Host "  Signature: NON SIGNE" -ForegroundColor Yellow
            if ($isCritical) {
                $issues += "Fichier critique non signe: $filePath"
            }
        } else {
            Write-Host "  Signature: INVALIDE ($($psSignature.Status))" -ForegroundColor Red
            if ($isCritical) {
                $issues += "Signature invalide sur fichier critique: $filePath"
            }
            if ($Detailed -and $psSignature.StatusMessage) {
                Write-Host "    Raison: $($psSignature.StatusMessage)" -ForegroundColor Gray
            }
        }

        # Test signtool si disponible
        if ($Detailed -and (Get-Command signtool -ErrorAction SilentlyContinue)) {
            $signtoolOutput = & signtool verify /pa /q $filePath 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  signtool: OK" -ForegroundColor Green
            } else {
                Write-Host "  signtool: ECHEC" -ForegroundColor Red
            }
        }

    } catch {
        Write-Host "  ERREUR: $($_.Exception.Message)" -ForegroundColor Red
        if ($isCritical) {
            $issues += "Erreur verification signature: $filePath"
        }
    }

    Write-Host ""
}

# RAPPORT FINAL
Write-Host "=== RAPPORT SIGNATURES ===" -ForegroundColor Cyan
Write-Host "Fichiers verifies: $totalFiles" -ForegroundColor White
Write-Host "Fichiers signes: $signedFiles" -ForegroundColor $(if($signedFiles -eq $totalFiles){"Green"}else{"Yellow"})
Write-Host "Signatures valides: $validSignatures" -ForegroundColor $(if($validSignatures -eq $signedFiles){"Green"}else{"Red"})
Write-Host "Avec horodatage: $timestampedFiles" -ForegroundColor $(if($timestampedFiles -eq $validSignatures){"Green"}else{"Yellow"})

$coveragePercent = if ($totalFiles -gt 0) { [math]::Round(($validSignatures / $totalFiles) * 100, 1) } else { 0 }
Write-Host "Couverture signature: ${coveragePercent}%" -ForegroundColor $(if($coveragePercent -eq 100){"Green"}elseif($coveragePercent -gt 80){"Yellow"}else{"Red"})

if ($issues.Count -eq 0) {
    Write-Host ""
    Write-Host "STATUT: TOUTES LES SIGNATURES OK" -ForegroundColor Green
    Write-Host "Pret pour deploiement public" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "STATUT: PROBLEMES DETECTES" -ForegroundColor Red
    Write-Host "Issues a resoudre:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $issues.Count; $i++) {
        Write-Host "  $($i+1). $($issues[$i])" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Verification detaillee: .\tools\verify-all-signatures.ps1 -Version '$Version' -Detailed" -ForegroundColor Gray

return ($issues.Count -eq 0)
