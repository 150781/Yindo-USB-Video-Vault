# Script de configuration TSA (TimeStamp Authority) avec fallbacks
# Usage: .\tools\setup-code-signing-enhanced.ps1 -CertPath "cert.pfx" -Password "pass" [-Version "0.1.5"]

param(
    [string]$CertPath,
    [string]$Password,
    [string]$Version = "0.1.5",
    [switch]$TestMode
)

Write-Host "=== SETUP CODE SIGNING AVANCE ===" -ForegroundColor Cyan
Write-Host ""

# Configuration TSA avec fallbacks
$tsaServers = @(
    @{Name="Sectigo"; Url="http://timestamp.sectigo.com"; Primary=$true},
    @{Name="DigiCert"; Url="http://timestamp.digicert.com"; Primary=$false},
    @{Name="GlobalSign"; Url="http://timestamp.globalsign.com/scripts/timstamp.dll"; Primary=$false},
    @{Name="Entrust"; Url="http://timestamp.entrust.net/TSS/RFC3161sha2TS"; Primary=$false}
)

Write-Host "TSA configurees:" -ForegroundColor Yellow
foreach ($tsa in $tsaServers) {
    $marker = if ($tsa.Primary) { " (PRIMARY)" } else { " (FALLBACK)" }
    Write-Host "  $($tsa.Name): $($tsa.Url)$marker" -ForegroundColor White
}
Write-Host ""

# Fonction de signature avec fallback TSA
function Sign-FileWithFallback {
    param(
        [string]$FilePath,
        [string]$CertPath,
        [string]$Password,
        [array]$TSAServers
    )

    if (-not (Test-Path $FilePath)) {
        Write-Host "  ERREUR: Fichier non trouve: $FilePath" -ForegroundColor Red
        return $false
    }

    Write-Host "  Signature: $(Split-Path $FilePath -Leaf)" -ForegroundColor White

    foreach ($tsa in $TSAServers) {
        try {
            Write-Host "    Tentative TSA: $($tsa.Name)" -ForegroundColor Gray

            # Commande signtool avec TSA
            $signtoolArgs = @(
                "sign",
                "/fd", "SHA256",
                "/f", $CertPath,
                "/p", $Password,
                "/t", $tsa.Url,
                "/v",
                $FilePath
            )

            if ($TestMode) {
                Write-Host "    [TEST MODE] signtool $($signtoolArgs -join ' ')" -ForegroundColor Blue
                return $true
            }

            $result = & signtool @signtoolArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "    SUCCES avec $($tsa.Name)" -ForegroundColor Green

                # Verification immediate
                $verification = & signtool verify /pa /v $FilePath 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Verification: OK" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "    Verification: ECHEC" -ForegroundColor Red
                }
            } else {
                Write-Host "    ECHEC $($tsa.Name): $result" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    ERREUR $($tsa.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "  ECHEC: Toutes les TSA ont echoue pour $FilePath" -ForegroundColor Red
    return $false
}

# Test de connectivite TSA
Write-Host "Test connectivite TSA..." -ForegroundColor Yellow
$workingTSAs = @()

foreach ($tsa in $tsaServers) {
    try {
        Write-Host "  Test $($tsa.Name)..." -ForegroundColor Gray -NoNewline

        # Test HTTP simple
        $response = Invoke-WebRequest -Uri $tsa.Url -Method HEAD -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 405) {
            # 405 Method Not Allowed est normal pour les TSA
            Write-Host " OK" -ForegroundColor Green
            $workingTSAs += $tsa
        } else {
            Write-Host " Status: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " ECHEC: $($_.Exception.Message.Split('.')[0])" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "TSA operationnelles: $($workingTSAs.Count)/$($tsaServers.Count)" -ForegroundColor $(if($workingTSAs.Count -gt 0){"Green"}else{"Red"})

if ($workingTSAs.Count -eq 0) {
    Write-Host "ATTENTION: Aucune TSA accessible - signatures sans horodatage" -ForegroundColor Red
    Write-Host "Les signatures expireront avec le certificat" -ForegroundColor Yellow
} else {
    # Reordonner avec les TSA fonctionnelles en premier
    $orderedTSAs = $workingTSAs + ($tsaServers | Where-Object { $_ -notin $workingTSAs })
    Write-Host "Ordre de priorite TSA mis a jour" -ForegroundColor Green
}

# Signature des fichiers si mode execution
if ($CertPath -and $Password -and -not $TestMode) {
    Write-Host ""
    Write-Host "Signature des binaires..." -ForegroundColor Yellow

    $filesToSign = @(
        ".\dist\USB Video Vault Setup $Version.exe",
        ".\dist\USB Video Vault $Version.exe",
        ".\dist\win-unpacked\USB Video Vault.exe"
    )

    # Rechercher DLLs additionnelles
    $additionalFiles = Get-ChildItem ".\dist\win-unpacked" -Recurse -Include "*.exe","*.dll" -ErrorAction SilentlyContinue
    foreach ($file in $additionalFiles) {
        if ($file.FullName -notin $filesToSign) {
            $filesToSign += $file.FullName
        }
    }

    $successCount = 0
    $totalFiles = $filesToSign.Count

    Write-Host "Fichiers a signer: $totalFiles" -ForegroundColor White
    Write-Host ""

    foreach ($file in $filesToSign) {
        if (Sign-FileWithFallback -FilePath $file -CertPath $CertPath -Password $Password -TSAServers $orderedTSAs) {
            $successCount++
        }
    }

    # Rapport final signature
    Write-Host ""
    Write-Host "=== RAPPORT SIGNATURE ===" -ForegroundColor Cyan
    Write-Host "Fichiers signes: $successCount/$totalFiles" -ForegroundColor $(if($successCount -eq $totalFiles){"Green"}else{"Red"})

    if ($successCount -eq $totalFiles) {
        Write-Host "SUCCES: Tous les binaires signes avec horodatage" -ForegroundColor Green
    } else {
        Write-Host "ECHEC: $($totalFiles - $successCount) fichiers non signes" -ForegroundColor Red
        Write-Host "Verifier certificat et connectivite TSA" -ForegroundColor Yellow
    }

} elseif ($TestMode) {
    Write-Host ""
    Write-Host "MODE TEST - Pas de signature reelle" -ForegroundColor Blue
    Write-Host "Configuration TSA prete pour production" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Usage pour signature:" -ForegroundColor Blue
    Write-Host "  .\tools\setup-code-signing-enhanced.ps1 -CertPath 'cert.pfx' -Password 'pass' -Version '$Version'" -ForegroundColor White
    Write-Host ""
    Write-Host "Test de configuration:" -ForegroundColor Blue
    Write-Host "  .\tools\setup-code-signing-enhanced.ps1 -TestMode" -ForegroundColor White
}

Write-Host ""
Write-Host "Verification post-signature:" -ForegroundColor Gray
Write-Host "  .\tools\verify-all-signatures.ps1 -Version '$Version' -Detailed" -ForegroundColor White
