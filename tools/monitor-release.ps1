# Script de monitoring post-release
# Usage: .\monitor-release.ps1 -Version "0.1.4" -Hours 48

param(
    [string]$Version = "0.1.4",
    [int]$Hours = 48,
    [switch]$Continuous,
    [switch]$SkipSmartScreen
)

Add-Type -AssemblyName System.Web

Write-Host "=== Monitoring Release v$Version ===" -ForegroundColor Cyan
Write-Host "🕐 Durée: $Hours heures" -ForegroundColor Gray
Write-Host ""

# Configuration
$releaseUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/v$Version"
$setupFile = "USB Video Vault Setup $Version.exe"
$logFile = ".\logs\release-monitoring-v$Version.log"

# Créer le dossier de logs
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Fonction de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    $logEntry | Out-File $logFile -Append -Encoding UTF8
}

# Fonction d'envoi de notification (mock)
function Send-Alert {
    param([string]$Title, [string]$Message, [string]$Severity = "INFO")
    Write-Log "🚨 ALERT [$Severity] $Title - $Message" "ALERT"

    # Ici vous pourriez intégrer Slack, Teams, email, etc.
    # Exemple webhook Slack:
    # $webhook = "https://hooks.slack.com/services/..."
    # $payload = @{text="[$Severity] $Title - $Message"} | ConvertTo-Json
    # Invoke-RestMethod -Uri $webhook -Method POST -Body $payload -ContentType "application/json"
}

Write-Log "Démarrage monitoring release v$Version"

# 1. Vérification initiale de la release
Write-Host "1. 🔍 Vérification release GitHub..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $releaseUrl -Method HEAD -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Log "✅ Release v$Version accessible"
    }
} catch {
    Write-Log "❌ Erreur accès release: $($_.Exception.Message)" "ERROR"
    Send-Alert "Release inaccessible" "La release v$Version n'est pas accessible" "ERROR"
}

# 2. Test de téléchargement
Write-Host "`n2. ⬇️ Test téléchargement setup..." -ForegroundColor Yellow
$downloadUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v$Version/$setupFile"
try {
    $testPath = "$env:TEMP\usb-vault-setup-test.exe"
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $testPath)

    if (Test-Path $testPath) {
        $downloadSize = [math]::Round((Get-Item $testPath).Length / 1MB, 2)
        Write-Log "✅ Téléchargement OK (${downloadSize}MB)"
        Remove-Item $testPath -Force
    }
} catch {
    Write-Log "❌ Erreur téléchargement: $($_.Exception.Message)" "ERROR"
    Send-Alert "Téléchargement échoué" "Le setup v$Version ne peut pas être téléchargé" "ERROR"
}

# 3. SmartScreen Reputation Check (si pas ignoré)
if (-not $SkipSmartScreen) {
    Write-Host "`n3. 🛡️ Monitoring SmartScreen..." -ForegroundColor Yellow
    Write-Log "Début monitoring réputation SmartScreen"

    # Simulation d'un check de réputation (à remplacer par API réelle si disponible)
    $smartScreenStatus = @{
        "Reputation" = "Unknown"
        "DownloadCount" = 0
        "ReportedThreat" = $false
        "LastChecked" = Get-Date
    }

    Write-Log "⚠️  SmartScreen Status: $($smartScreenStatus.Reputation)"
    if ($smartScreenStatus.Reputation -eq "Unknown") {
        Write-Log "ℹ️  Note: Réputation SmartScreen normale pour nouvelle release"
    }
}

# 4. Surveillance continue des erreurs
$startTime = Get-Date
$endTime = $startTime.AddHours($Hours)
$checkInterval = 15 # minutes
$errorCount = 0
$downloadCount = 0

Write-Host "`n4. 🔄 Surveillance continue..." -ForegroundColor Yellow
Write-Log "Surveillance démarrée jusqu'à $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"

do {
    $currentTime = Get-Date
    $elapsed = [math]::Round(($currentTime - $startTime).TotalHours, 1)

    Write-Host "`n⏰ Check $elapsed/$Hours heures..." -ForegroundColor Blue

    # Check 1: Disponibilité release
    try {
        $response = Invoke-WebRequest -Uri $releaseUrl -Method HEAD -TimeoutSec 10
        Write-Log "✅ Release accessible (Status: $($response.StatusCode))"
    } catch {
        $errorCount++
        Write-Log "❌ Erreur accès release: $($_.Exception.Message)" "ERROR"

        if ($errorCount -ge 3) {
            Send-Alert "Release indisponible" "3+ erreurs consécutives d'accès à la release" "CRITICAL"
        }
    }

    # Check 2: Test téléchargement léger
    try {
        $headResponse = Invoke-WebRequest -Uri $downloadUrl -Method HEAD -TimeoutSec 10
        if ($headResponse.StatusCode -eq 200) {
            $fileSize = $headResponse.Headers.'Content-Length'
            Write-Log "✅ Setup téléchargeable (${fileSize} bytes)"
            $downloadCount++
        }
    } catch {
        Write-Log "⚠️  Erreur check téléchargement: $($_.Exception.Message)" "WARN"
    }

    # Check 3: Logs d'erreur GitHub (mock)
    # En production, vous pourriez interroger l'API GitHub pour les issues, discussions, etc.
    $mockGitHubIssues = @()
    if ($mockGitHubIssues.Count -gt 0) {
        Write-Log "⚠️  $($mockGitHubIssues.Count) nouveaux problèmes signalés" "WARN"
        Send-Alert "Problèmes utilisateurs" "$($mockGitHubIssues.Count) nouveaux problèmes signalés" "WARN"
    }

    # Statistiques périodiques
    if ($elapsed % 2 -eq 0) { # Toutes les 2 heures
        Write-Host "`n📊 Statistiques ($elapsed h):" -ForegroundColor Cyan
        Write-Host "   • Checks réussis: $downloadCount" -ForegroundColor Green
        Write-Host "   • Erreurs: $errorCount" -ForegroundColor $(if($errorCount -eq 0){"Green"}else{"Red"})
        Write-Host "   • Disponibilité: $([math]::Round((1-$errorCount/($downloadCount+$errorCount))*100,1))%" -ForegroundColor $(if($errorCount -eq 0){"Green"}else{"Yellow"})

        Write-Log "Stats: $downloadCount OK, $errorCount erreurs"
    }

    # Attendre avant le prochain check
    if ($currentTime -lt $endTime) {
        Write-Host "⏸️  Attente $checkInterval min..." -ForegroundColor Gray
        Start-Sleep -Seconds ($checkInterval * 60)
    }

} while ((Get-Date) -lt $endTime -and ($Continuous -or (Get-Date) -lt $endTime))

# 5. Rapport final
$finalTime = Get-Date
$totalHours = [math]::Round(($finalTime - $startTime).TotalHours, 2)

Write-Host "`n=== RAPPORT FINAL ===" -ForegroundColor Green
Write-Host "🕐 Durée monitoring: $totalHours heures" -ForegroundColor Cyan
Write-Host "✅ Checks réussis: $downloadCount" -ForegroundColor Green
Write-Host "❌ Erreurs: $errorCount" -ForegroundColor $(if($errorCount -eq 0){"Green"}else{"Red"})

$availability = if (($downloadCount + $errorCount) -gt 0) {
    [math]::Round((1-$errorCount/($downloadCount+$errorCount))*100,1)
} else { 0 }

Write-Host "📈 Disponibilité: $availability%" -ForegroundColor $(if($availability -ge 99){"Green"}elseif($availability -ge 95){"Yellow"}else{"Red"})

Write-Log "Monitoring terminé - Disponibilité: $availability%"

# Recommandations finales
Write-Host "`n🎯 Recommandations:" -ForegroundColor Blue
if ($errorCount -eq 0) {
    Write-Host "   ✅ Release stable - aucun problème détecté" -ForegroundColor Green
} elseif ($errorCount -le 2) {
    Write-Host "   ⚠️  Quelques problèmes mineurs - surveillance continue recommandée" -ForegroundColor Yellow
} else {
    Write-Host "   🚨 Problèmes significatifs - investigation requise" -ForegroundColor Red
    Send-Alert "Investigation requise" "Release v$Version présente des problèmes de stabilité" "HIGH"
}

Write-Host "`n📄 Log complet: $logFile" -ForegroundColor Gray
Write-Host "📊 Pour stats détaillées: Get-Content '$logFile' | Where-Object {`$_ -match 'Stats:'}" -ForegroundColor Gray
