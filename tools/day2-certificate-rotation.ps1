# Scripts Day-2 Operations - Rotation certificats et maintenance
# Usage: .\tools\day2-certificate-rotation.ps1 [-TestMode] [-BackupOnly]

param(
    [switch]$TestMode,
    [switch]$BackupOnly
)

Write-Host "=== DAY-2 CERTIFICATE ROTATION ===" -ForegroundColor Cyan
Write-Host ""

$backupDir = ".\backup\certificates\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$logFile = ".\logs\certificate-rotation-$(Get-Date -Format 'yyyyMMdd').log"

# Creer dossiers si necessaire
@($backupDir, ".\logs") | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "WARN"){"Yellow"}else{"White"})
    $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-Log "=== DEBUT ROTATION CERTIFICATS ===" "INFO"

if ($TestMode) {
    Write-Host "MODE TEST - Simulation operations" -ForegroundColor Blue
    Write-Log "Mode test active - aucune modification reelle" "INFO"
}

# ETAPE 1: BACKUP CERTIFICATS ACTUELS
Write-Host "1. BACKUP CERTIFICATS ACTUELS..." -ForegroundColor Yellow
Write-Log "Debut backup certificats" "INFO"

# Localiser certificats de signature de code
$codeSigningCerts = Get-ChildItem -Path "Cert:\CurrentUser\My" |
    Where-Object { $_.EnhancedKeyUsageList -like "*Code Signing*" }

if ($codeSigningCerts.Count -eq 0) {
    Write-Log "Aucun certificat de signature de code trouve" "WARN"
    $codeSigningCerts = Get-ChildItem -Path "Cert:\LocalMachine\My" |
        Where-Object { $_.EnhancedKeyUsageList -like "*Code Signing*" }
}

foreach ($cert in $codeSigningCerts) {
    $certName = $cert.Subject -replace ",.*$", "" -replace "CN=", ""
    $backupFile = Join-Path $backupDir "$certName-$(Get-Date -Format 'yyyyMMdd').pfx"

    Write-Host "  Backup: $certName" -ForegroundColor Green
    Write-Host "    Expire: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
    Write-Host "    Fichier: $backupFile" -ForegroundColor Gray

    # Verification expiration
    $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days

    if ($daysUntilExpiry -lt 30) {
        Write-Log "ALERTE: Certificat expire dans $daysUntilExpiry jours - $certName" "WARN"
        Write-Host "    ALERTE: Expire dans $daysUntilExpiry jours!" -ForegroundColor Red
    } elseif ($daysUntilExpiry -lt 90) {
        Write-Log "ATTENTION: Certificat expire dans $daysUntilExpiry jours - $certName" "WARN"
        Write-Host "    ATTENTION: Expire dans $daysUntilExpiry jours" -ForegroundColor Yellow
    }

    if (-not $TestMode) {
        # Exporter certificat (necessaire mot de passe pour PFX)
        Write-Host "    Export metadata..." -ForegroundColor Gray

        $certInfo = @{
            subject = $cert.Subject
            issuer = $cert.Issuer
            thumbprint = $cert.Thumbprint
            serialNumber = $cert.SerialNumber
            notBefore = $cert.NotBefore
            notAfter = $cert.NotAfter
            keyUsage = $cert.EnhancedKeyUsageList | ForEach-Object { $_.FriendlyName }
            backupDate = Get-Date
        }

        $certInfoFile = Join-Path $backupDir "$certName-info.json"
        $certInfo | ConvertTo-Json -Depth 3 | Out-File -FilePath $certInfoFile -Encoding UTF8

        Write-Log "Certificat sauvegarde: $certName (expire: $($cert.NotAfter.ToString('yyyy-MM-dd')))" "INFO"
    }
}

# ETAPE 2: BACKUP CONFIGURATION SIGNING
Write-Host ""
Write-Host "2. BACKUP CONFIGURATION SIGNING..." -ForegroundColor Yellow

$configFiles = @(
    ".\tools\setup-code-signing.ps1",
    ".\tools\setup-code-signing-enhanced.ps1",
    ".\electron-builder.yml",
    ".\.env",
    ".\build-config.json"
)

foreach ($configFile in $configFiles) {
    if (Test-Path $configFile) {
        $backupPath = Join-Path $backupDir (Split-Path $configFile -Leaf)

        if (-not $TestMode) {
            Copy-Item $configFile $backupPath -Force
        }

        Write-Host "  Config: $(Split-Path $configFile -Leaf)" -ForegroundColor Green
        Write-Log "Configuration sauvegardee: $configFile" "INFO"
    } else {
        Write-Host "  Manquant: $(Split-Path $configFile -Leaf)" -ForegroundColor Yellow
    }
}

if ($BackupOnly) {
    Write-Host ""
    Write-Host "BACKUP TERMINE - Mode backup seul active" -ForegroundColor Green
    Write-Log "Fin backup (mode backup seul)" "INFO"
    exit 0
}

# ETAPE 3: VERIFICATION NOUVEAUX CERTIFICATS
Write-Host ""
Write-Host "3. VERIFICATION NOUVEAUX CERTIFICATS..." -ForegroundColor Yellow

# Rechercher nouveaux certificats (plus recents que 30 jours)
$recentCerts = Get-ChildItem -Path @("Cert:\CurrentUser\My", "Cert:\LocalMachine\My") |
    Where-Object {
        $_.EnhancedKeyUsageList -like "*Code Signing*" -and
        $_.NotBefore -gt (Get-Date).AddDays(-30)
    }

if ($recentCerts.Count -eq 0) {
    Write-Host "  Aucun nouveau certificat detecte" -ForegroundColor Yellow
    Write-Log "Aucun nouveau certificat trouve pour rotation" "WARN"

    # Verifier certificats expirant
    $expiringSoon = $codeSigningCerts | Where-Object {
        ($_.NotAfter - (Get-Date)).Days -lt 90
    }

    if ($expiringSoon.Count -gt 0) {
        Write-Host ""
        Write-Host "ATTENTION: Certificats expirant bientot:" -ForegroundColor Red
        foreach ($cert in $expiringSoon) {
            $daysLeft = ($cert.NotAfter - (Get-Date)).Days
            Write-Host "  - $($cert.Subject): $daysLeft jours" -ForegroundColor Red
            Write-Log "Certificat expire bientot: $($cert.Subject) ($daysLeft jours)" "ERROR"
        }

        Write-Host ""
        Write-Host "Actions requises:" -ForegroundColor Blue
        Write-Host "  1. Commander nouveau certificat" -ForegroundColor White
        Write-Host "  2. Installer sur poste de build" -ForegroundColor White
        Write-Host "  3. Re-executer rotation" -ForegroundColor White
    }

} else {
    Write-Host "  Nouveaux certificats detectes: $($recentCerts.Count)" -ForegroundColor Green

    foreach ($newCert in $recentCerts) {
        Write-Host "    - $($newCert.Subject)" -ForegroundColor Green
        Write-Host "      Valide: $($newCert.NotBefore.ToString('yyyy-MM-dd')) → $($newCert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
        Write-Log "Nouveau certificat disponible: $($newCert.Subject)" "INFO"
    }

    # ETAPE 4: MISE A JOUR CONFIGURATION
    Write-Host ""
    Write-Host "4. MISE A JOUR CONFIGURATION..." -ForegroundColor Yellow

    # Selectionner le certificat le plus recent avec la plus longue validite
    $bestCert = $recentCerts | Sort-Object NotAfter -Descending | Select-Object -First 1

    Write-Host "  Certificat selectionne: $($bestCert.Subject)" -ForegroundColor Green
    Write-Host "  Thumbprint: $($bestCert.Thumbprint)" -ForegroundColor Gray

    if (-not $TestMode) {
        # Mettre a jour setup-code-signing.ps1
        $setupScript = ".\tools\setup-code-signing.ps1"
        if (Test-Path $setupScript) {
            $scriptContent = Get-Content $setupScript -Raw

            # Chercher et remplacer thumbprint
            if ($scriptContent -match '\$certThumbprint\s*=\s*"([^"]+)"') {
                $oldThumbprint = $matches[1]
                $newContent = $scriptContent -replace [regex]::Escape($oldThumbprint), $bestCert.Thumbprint
                $newContent | Out-File -FilePath $setupScript -Encoding UTF8

                Write-Host "  Script mis a jour: setup-code-signing.ps1" -ForegroundColor Green
                Write-Log "Script signe mis a jour avec nouveau certificat: $($bestCert.Thumbprint)" "INFO"
            }
        }

        # Mettre a jour electron-builder.yml si necessaire
        $builderConfig = ".\electron-builder.yml"
        if (Test-Path $builderConfig) {
            Write-Host "  electron-builder.yml: Manuel requis" -ForegroundColor Yellow
            Write-Log "Mise a jour manuelle requise pour electron-builder.yml" "WARN"
        }

    } else {
        Write-Host "  [MODE TEST] Configuration qui serait mise a jour:" -ForegroundColor Blue
        Write-Host "    - setup-code-signing.ps1: $($bestCert.Thumbprint)" -ForegroundColor Cyan
        Write-Host "    - electron-builder.yml: mise a jour manuelle" -ForegroundColor Cyan
    }
}

# ETAPE 5: TEST SIGNATURE
if ($recentCerts.Count -gt 0 -and -not $TestMode) {
    Write-Host ""
    Write-Host "5. TEST SIGNATURE AVEC NOUVEAU CERTIFICAT..." -ForegroundColor Yellow

    # Creer fichier test
    $testFile = ".\temp-sign-test.txt"
    "Test signature $(Get-Date)" | Out-File -FilePath $testFile -Encoding UTF8

    try {
        # Test signature avec signtool
        $signCmd = "signtool sign /sha1 $($bestCert.Thumbprint) /t http://timestamp.sectigo.com /v `"$testFile`""
        Write-Host "  Test signature..." -ForegroundColor Gray

        $signResult = cmd /c $signCmd 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Test signature: SUCCES" -ForegroundColor Green
            Write-Log "Test signature reussi avec nouveau certificat" "INFO"

            # Verification signature
            $testSignature = Get-AuthenticodeSignature $testFile
            if ($testSignature.Status -eq "Valid") {
                Write-Host "  Verification: VALIDE" -ForegroundColor Green
                Write-Log "Verification signature test valide" "INFO"
            } else {
                Write-Host "  Verification: ECHEC ($($testSignature.Status))" -ForegroundColor Red
                Write-Log "Verification signature test echouee: $($testSignature.Status)" "ERROR"
            }
        } else {
            Write-Host "  Test signature: ECHEC" -ForegroundColor Red
            Write-Log "Test signature echoue: $signResult" "ERROR"
        }

        # Nettoyer fichier test
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue

    } catch {
        Write-Host "  Test signature: ERREUR ($($_.Exception.Message))" -ForegroundColor Red
        Write-Log "Erreur test signature: $($_.Exception.Message)" "ERROR"
    }
}

# ETAPE 6: NOTIFICATIONS
Write-Host ""
Write-Host "6. NOTIFICATIONS..." -ForegroundColor Yellow

$notifications = @()

# Certificats expirant
$expiringSoon = $codeSigningCerts | Where-Object {
    ($_.NotAfter - (Get-Date)).Days -lt 90
}

foreach ($cert in $expiringSoon) {
    $daysLeft = ($cert.NotAfter - (Get-Date)).Days
    $notifications += "Certificat expire dans $daysLeft jours: $($cert.Subject)"
}

# Nouveaux certificats installes
if ($recentCerts.Count -gt 0) {
    $notifications += "$($recentCerts.Count) nouveau(x) certificat(s) detecte(s)"
}

# Afficher notifications
if ($notifications.Count -gt 0) {
    Write-Host "  Notifications:" -ForegroundColor Blue
    foreach ($notification in $notifications) {
        Write-Host "    - $notification" -ForegroundColor White
        Write-Log "Notification: $notification" "INFO"
    }

    # Si en production, envoyer email/Teams (placeholder)
    if (-not $TestMode) {
        Write-Host "  [PLACEHOLDER] Envoi notifications Teams/Email" -ForegroundColor Gray
    }
} else {
    Write-Host "  Aucune notification" -ForegroundColor Green
}

# RAPPORT FINAL
Write-Host ""
Write-Host "=== RAPPORT ROTATION CERTIFICATS ===" -ForegroundColor Cyan

Write-Host "Backup effectue: $backupDir" -ForegroundColor White
Write-Host "Log detaille: $logFile" -ForegroundColor White
Write-Host ""

if ($codeSigningCerts.Count -eq 0) {
    Write-Host "STATUT: AUCUN CERTIFICAT" -ForegroundColor Red
    Write-Host "Action requise: Installer certificat de signature de code" -ForegroundColor Red
} elseif ($expiringSoon.Count -gt 0) {
    Write-Host "STATUT: CERTIFICATS EXPIRANT" -ForegroundColor Yellow
    Write-Host "Action requise: Commander nouveaux certificats" -ForegroundColor Yellow
} elseif ($recentCerts.Count -gt 0) {
    Write-Host "STATUT: ROTATION DISPONIBLE" -ForegroundColor Green
    Write-Host "Certificats mis a jour disponibles" -ForegroundColor Green
} else {
    Write-Host "STATUT: CERTIFICATS OK" -ForegroundColor Green
    Write-Host "Aucune action requise" -ForegroundColor Green
}

Write-Log "=== FIN ROTATION CERTIFICATS ===" "INFO"

# Recommandations operationnelles
Write-Host ""
Write-Host "Recommandations operationnelles:" -ForegroundColor Blue
Write-Host "  - Executer rotation mensuelle" -ForegroundColor White
Write-Host "  - Commander nouveaux certificats 60 jours avant expiration" -ForegroundColor White
Write-Host "  - Tester signature apres chaque rotation" -ForegroundColor White
Write-Host "  - Monitorer alertes d'expiration" -ForegroundColor White
