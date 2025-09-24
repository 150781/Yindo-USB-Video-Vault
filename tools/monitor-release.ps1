# Script de monitoring post-release avec surveillance SmartScreen, taux echec install, issues
# Usage: .\monitor-release.ps1 -Version "0.1.5" -Hours 48 [-SmartScreen] [-Issues] [-InstallFailures]

param(
    [string]$Version = "0.1.5",
    [int]$Hours = 48,
    [switch]$Continuous,
    [switch]$SmartScreen,
    [switch]$Issues,
    [switch]$InstallFailures,
    [switch]$AllChecks
)

Add-Type -AssemblyName System.Web

# Activation des checks specifiques si AllChecks
if ($AllChecks) {
    $SmartScreen = $true
    $Issues = $true
    $InstallFailures = $true
}

Write-Host "=== Monitoring Release v$Version ===" -ForegroundColor Cyan
Write-Host "Duree: $Hours heures" -ForegroundColor Gray
Write-Host "Checks actives:" -ForegroundColor Yellow
if ($SmartScreen) { Write-Host "  - Surveillance SmartScreen" -ForegroundColor White }
if ($Issues) { Write-Host "  - Surveillance Issues GitHub" -ForegroundColor White }
if ($InstallFailures) { Write-Host "  - Surveillance echecs installation" -ForegroundColor White }
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

# 3. SmartScreen Reputation Check
if ($SmartScreen) {
    Write-Host "`n3. SmartScreen Monitoring..." -ForegroundColor Yellow
    Write-Log "Debut monitoring reputation SmartScreen"

    # Check reputation SmartScreen 
    $smartScreenStatus = @{
        "Reputation" = "Unknown"
        "DownloadCount" = 0
        "ReportedThreat" = $false
        "LastChecked" = Get-Date
    }

    Write-Log "SmartScreen Status: $($smartScreenStatus.Reputation)"
    if ($smartScreenStatus.Reputation -eq "Unknown") {
        Write-Log "Note: Reputation SmartScreen normale pour nouvelle release"
        Write-Log "Recommandation: Monitorer retours utilisateurs pour alertes SmartScreen"
    }
    
    # Check potential threats reports
    try {
        # Ici on pourrait integrer APIs de securite si disponibles
        Write-Log "Aucune menace reportee (simulation)"
    } catch {
        Write-Log "Erreur verification menaces: $($_.Exception.Message)" "ERROR"
    }
}

# 4. Issues GitHub Monitoring  
if ($Issues) {
    Write-Host "`n4. Issues GitHub..." -ForegroundColor Yellow
    Write-Log "Debut monitoring issues GitHub"
    
    try {
        # Verifier nouvelles issues depuis release
        $recentIssues = & gh issue list --repo "150781/Yindo-USB-Video-Vault" --state open --limit 10 --json number,title,createdAt | ConvertFrom-Json
        
        # Filtrer issues recentes (derniers jours)
        $releaseDate = Get-Date
        $criticalKeywords = @("crash", "bug", "error", "fail", "problem", "install", "smartscreen")
        
        $criticalIssues = $recentIssues | Where-Object {
            $issueDate = [DateTime]$_.createdAt
            $daysSinceRelease = ($releaseDate - $issueDate).Days
            
            if ($daysSinceRelease -le 2) {
                $hasCriticalKeyword = $false
                foreach ($keyword in $criticalKeywords) {
                    if ($_.title -like "*$keyword*") {
                        $hasCriticalKeyword = $true
                        break
                    }
                }
                return $hasCriticalKeyword
            }
            return $false
        }
        
        if ($criticalIssues.Count -gt 0) {
            Write-Log "ATTENTION: $($criticalIssues.Count) issues critiques detectees" "WARNING"
            foreach ($issue in $criticalIssues) {
                Write-Log "  Issue #$($issue.number): $($issue.title)" "WARNING"
            }
            Send-Alert "Issues critiques detectees" "$($criticalIssues.Count) nouvelles issues depuis release v$Version" "WARNING"
        } else {
            Write-Log "Aucune issue critique detectee"
        }
    } catch {
        Write-Log "Erreur monitoring issues: $($_.Exception.Message)" "ERROR"
    }
}

# 5. Install Failures Monitoring
if ($InstallFailures) {
    Write-Host "`n5. Install Failures..." -ForegroundColor Yellow
    Write-Log "Debut monitoring echecs installation"
    
    # Simulation de stats installation
    $installStats = @{
        "TotalDownloads" = 0
        "SuccessfulInstalls" = 0
        "FailedInstalls" = 0
        "SmartScreenBlocks" = 0
        "FailureRate" = 0.0
    }
    
    # Dans un vrai scenario, ces donnees viendraient de telemetrie
    Write-Log "Stats installation (simulation):"
    Write-Log "  Total downloads: $($installStats.TotalDownloads)"
    Write-Log "  Successful installs: $($installStats.SuccessfulInstalls)"  
    Write-Log "  Failed installs: $($installStats.FailedInstalls)"
    Write-Log "  SmartScreen blocks: $($installStats.SmartScreenBlocks)"
    
    if ($installStats.TotalDownloads -gt 0) {
        $installStats.FailureRate = [math]::Round(($installStats.FailedInstalls / $installStats.TotalDownloads) * 100, 2)
        Write-Log "  Failure rate: $($installStats.FailureRate)%"
        
        if ($installStats.FailureRate -gt 20) {
            Send-Alert "Taux echec installation eleve" "Taux echec: $($installStats.FailureRate)% pour v$Version" "ERROR"
        } elseif ($installStats.FailureRate -gt 10) {
            Send-Alert "Taux echec installation surveiller" "Taux echec: $($installStats.FailureRate)% pour v$Version" "WARNING"
        }
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

    # Statistiques periodiques
    if ($elapsed % 2 -eq 0) { # Toutes les 2 heures
        Write-Host ""
        Write-Host "Statistiques (${elapsed}h):" -ForegroundColor Cyan
        Write-Host "   Checks reussis: $downloadCount" -ForegroundColor Green
        Write-Host "   Erreurs: $errorCount" -ForegroundColor $(if($errorCount -eq 0){"Green"}else{"Red"})
        $availability = if (($downloadCount + $errorCount) -gt 0) { [math]::Round((1-$errorCount/($downloadCount+$errorCount))*100,1) } else { 100 }
        Write-Host "   Disponibilite: ${availability}%" -ForegroundColor $(if($errorCount -eq 0){"Green"}else{"Yellow"})

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

Write-Host ""
Write-Host "Log complet: $logFile" -ForegroundColor Gray
Write-Host "Pour stats detaillees: Get-Content '$logFile' | Where-Object { `$_ -match 'Stats:' }" -ForegroundColor Gray
