# Monitoring Déploiement Rings - Suivi Erreurs Critiques

## Vue d'ensemble

Système de surveillance spécialisé pour détecter et traquer les erreurs critiques "Signature invalide" et "Anti-rollback" par ring de déploiement.

## Architecture de Monitoring

### Collecteurs d'Erreurs par Ring

```powershell
# scripts/ring-error-monitor.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("ring0", "ring1", "ga")]
    [string]$Ring,
    
    [string]$LogPath = "$env:APPDATA\usb-video-vault\logs",
    [string]$OutputPath = ".\monitoring\ring-errors",
    [int]$IntervalMinutes = 1,
    [switch]$AlertMode
)

class CriticalError {
    [string]$Timestamp
    [string]$Ring
    [string]$Hostname
    [string]$ErrorType
    [string]$Message
    [string]$StackTrace
    [string]$UserContext
    [string]$AppVersion
    [string]$LogFile
    
    CriticalError([string]$type, [string]$message, [string]$ring) {
        $this.Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        $this.Ring = $ring
        $this.Hostname = $env:COMPUTERNAME
        $this.ErrorType = $type
        $this.Message = $message
        $this.UserContext = $env:USERNAME
    }
    
    [string] ToJson() {
        return $this | ConvertTo-Json -Compress
    }
    
    [string] ToAlert() {
        return "🚨 [$($this.Ring.ToUpper())] $($this.ErrorType): $($this.Message) - $($this.Hostname) ($($this.Timestamp))"
    }
}

function Search-CriticalErrors {
    param([string]$LogPath, [string]$Ring)
    
    $errors = @()
    $patterns = @{
        "SIGNATURE_INVALID" = @(
            "Signature invalide",
            "Invalid signature", 
            "signature verification failed",
            "signature mismatch"
        )
        "ANTI_ROLLBACK" = @(
            "Anti-rollback",
            "rollback protection",
            "version rollback detected",
            "downgrade not allowed"
        )
        "LICENSE_CORRUPTION" = @(
            "licence corrompue",
            "license corruption",
            "invalid license format",
            "license file damaged"
        )
        "TAMPER_DETECTION" = @(
            "tamper detected",
            "integrity check failed", 
            "file modification detected",
            "unauthorized change"
        )
    }
    
    if (-not (Test-Path $LogPath)) {
        Write-Warning "Dossier logs non trouvé: $LogPath"
        return $errors
    }
    
    # Analyser les logs des dernières 24h
    $cutoffDate = (Get-Date).AddDays(-1)
    $logFiles = Get-ChildItem $LogPath -Filter "*.log" | 
                Where-Object { $_.LastWriteTime -gt $cutoffDate }
    
    foreach ($logFile in $logFiles) {
        try {
            $content = Get-Content $logFile.FullName -Raw -ErrorAction Continue
            
            foreach ($errorType in $patterns.Keys) {
                foreach ($pattern in $patterns[$errorType]) {
                    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    
                    foreach ($match in $matches) {
                        # Extraire le contexte autour de l'erreur
                        $lines = $content -split "`n"
                        $matchLine = $lines | Where-Object { $_ -like "*$pattern*" } | Select-Object -First 1
                        
                        if ($matchLine) {
                            $error = [CriticalError]::new($errorType, $matchLine.Trim(), $Ring)
                            $error.LogFile = $logFile.Name
                            
                            # Extraire version si possible
                            $versionMatch = [regex]::Match($content, "version[:\s]+([0-9]+\.[0-9]+\.[0-9]+)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                            if ($versionMatch.Success) {
                                $error.AppVersion = $versionMatch.Groups[1].Value
                            }
                            
                            $errors += $error
                        }
                    }
                }
            }
        } catch {
            Write-Warning "Erreur lecture log $($logFile.Name): $($_.Exception.Message)"
        }
    }
    
    return $errors
}

function Send-CriticalAlert {
    param([CriticalError]$Error, [string]$Ring)
    
    $alertConfig = @{
        slack = @{
            webhook = $env:SLACK_WEBHOOK_CRITICAL
            channel = "#deployment-critical"
        }
        email = @{
            smtp = $env:SMTP_SERVER
            from = "alerts@company.com"
            to = @("ops@company.com", "security@company.com")
        }
    }
    
    # Alerte Slack immédiate
    if ($alertConfig.slack.webhook) {
        $slackPayload = @{
            channel = $alertConfig.slack.channel
            username = "Ring Monitor CRITICAL"
            icon_emoji = ":rotating_light:"
            attachments = @(
                @{
                    color = "danger"
                    title = "🚨 ERREUR CRITIQUE - RING $($Ring.ToUpper())"
                    text = $Error.ToAlert()
                    fields = @(
                        @{ title = "Type"; value = $Error.ErrorType; short = $true }
                        @{ title = "Machine"; value = $Error.Hostname; short = $true }
                        @{ title = "Utilisateur"; value = $Error.UserContext; short = $true }
                        @{ title = "Version"; value = $Error.AppVersion; short = $true }
                        @{ title = "Log"; value = $Error.LogFile; short = $true }
                        @{ title = "Timestamp"; value = $Error.Timestamp; short = $true }
                    )
                    footer = "Ring Deployment Monitor"
                    ts = [int][double]::Parse((Get-Date -UFormat %s))
                }
            )
        } | ConvertTo-Json -Depth 10
        
        try {
            Invoke-RestMethod -Uri $alertConfig.slack.webhook -Method POST -Body $slackPayload -ContentType "application/json"
            Write-Host "Alerte Slack envoyée: $($Error.ErrorType)" -ForegroundColor Red
        } catch {
            Write-Error "Erreur envoi Slack: $($_.Exception.Message)"
        }
    }
    
    # Email pour erreurs de sécurité
    if ($Error.ErrorType -in @("SIGNATURE_INVALID", "TAMPER_DETECTION") -and $alertConfig.email.smtp) {
        $emailBody = @"
ALERTE SÉCURITÉ CRITIQUE - USB VIDEO VAULT

Ring de déploiement: $($Ring.ToUpper())
Type d'erreur: $($Error.ErrorType)
Machine: $($Error.Hostname)
Utilisateur: $($Error.UserContext)
Timestamp: $($Error.Timestamp)

Message d'erreur:
$($Error.Message)

Fichier de log: $($Error.LogFile)
Version application: $($Error.AppVersion)

Actions recommandées:
1. Arrêter immédiatement le déploiement du ring $Ring
2. Investiguer la cause racine
3. Vérifier l'intégrité des fichiers de licence
4. Contrôler l'accès aux clés de signature
5. Audit de sécurité complet

Cette alerte nécessite une réponse immédiate.

--
Ring Deployment Monitor
"@
        
        try {
            # Utiliser Send-MailMessage ou un autre système d'email
            Write-Host "Email d'alerte préparé pour $($Error.ErrorType)" -ForegroundColor Yellow
            # Send-MailMessage implémentation ici
        } catch {
            Write-Error "Erreur envoi email: $($_.Exception.Message)"
        }
    }
}

function Generate-ErrorReport {
    param([array]$Errors, [string]$Ring, [string]$OutputPath)
    
    $reportData = @{
        generatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        ring = $Ring
        totalErrors = $Errors.Count
        errorsByType = @{}
        errorsByHour = @{}
        criticalMachines = @()
        errors = $Errors
    }
    
    # Statistiques par type
    $Errors | Group-Object ErrorType | ForEach-Object {
        $reportData.errorsByType[$_.Name] = $_.Count
    }
    
    # Statistiques par heure
    $Errors | ForEach-Object {
        $hour = ([DateTime]$_.Timestamp).ToString("yyyy-MM-dd HH:00")
        if ($reportData.errorsByHour.ContainsKey($hour)) {
            $reportData.errorsByHour[$hour]++
        } else {
            $reportData.errorsByHour[$hour] = 1
        }
    }
    
    # Machines critiques (plus de 3 erreurs)
    $Errors | Group-Object Hostname | Where-Object { $_.Count -gt 3 } | ForEach-Object {
        $reportData.criticalMachines += @{
            hostname = $_.Name
            errorCount = $_.Count
            errorTypes = ($_.Group | Group-Object ErrorType | ForEach-Object { $_.Name })
        }
    }
    
    # Sauvegarder rapport JSON
    $reportFile = Join-Path $OutputPath "error-report-$Ring-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $directory = Split-Path $reportFile -Parent
    if (-not (Test-Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }
    
    $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
    
    # Générer rapport HTML
    $htmlFile = $reportFile -replace '\.json$', '.html'
    $html = Generate-HtmlReport -ReportData $reportData -Ring $Ring
    $html | Out-File -FilePath $htmlFile -Encoding UTF8
    
    Write-Host "Rapport généré: $reportFile" -ForegroundColor Green
    Write-Host "Rapport HTML: $htmlFile" -ForegroundColor Green
    
    return $reportFile
}

function Generate-HtmlReport {
    param([object]$ReportData, [string]$Ring)
    
    $errorTypeColors = @{
        "SIGNATURE_INVALID" = "#ff0000"
        "ANTI_ROLLBACK" = "#ff6600"
        "LICENSE_CORRUPTION" = "#cc0000"
        "TAMPER_DETECTION" = "#990000"
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Rapport Erreurs Critiques - Ring $($Ring.ToUpper())</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #d32f2f; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .summary { display: flex; gap: 20px; margin-bottom: 20px; }
        .stat-box { background-color: white; padding: 15px; border-radius: 8px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .critical { background-color: #ffebee; border-left: 4px solid #d32f2f; }
        .warning { background-color: #fff3e0; border-left: 4px solid #f57c00; }
        .error-table { width: 100%; border-collapse: collapse; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .error-table th, .error-table td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        .error-table th { background-color: #f5f5f5; font-weight: bold; }
        .error-type { padding: 4px 8px; border-radius: 4px; color: white; font-weight: bold; }
        .machines-section { margin-top: 20px; background-color: white; padding: 20px; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚨 Rapport Erreurs Critiques - Ring $($Ring.ToUpper())</h1>
        <p>Généré le $($ReportData.generatedAt) | Total: $($ReportData.totalErrors) erreurs</p>
    </div>
    
    <div class="summary">
        <div class="stat-box critical">
            <h3>$($ReportData.totalErrors)</h3>
            <p>Erreurs Totales</p>
        </div>
"@

    # Statistiques par type
    foreach ($errorType in $ReportData.errorsByType.Keys) {
        $count = $ReportData.errorsByType[$errorType]
        $color = $errorTypeColors[$errorType] ?? "#666666"
        $html += @"
        <div class="stat-box">
            <h3 style="color: $color">$count</h3>
            <p>$errorType</p>
        </div>
"@
    }

    $html += @"
    </div>
    
    <table class="error-table">
        <thead>
            <tr>
                <th>Timestamp</th>
                <th>Type</th>
                <th>Machine</th>
                <th>Utilisateur</th>
                <th>Message</th>
                <th>Version</th>
                <th>Log</th>
            </tr>
        </thead>
        <tbody>
"@

    foreach ($error in $ReportData.errors) {
        $typeColor = $errorTypeColors[$error.ErrorType] ?? "#666666"
        $html += @"
            <tr>
                <td>$($error.Timestamp)</td>
                <td><span class="error-type" style="background-color: $typeColor">$($error.ErrorType)</span></td>
                <td>$($error.Hostname)</td>
                <td>$($error.UserContext)</td>
                <td>$($error.Message)</td>
                <td>$($error.AppVersion)</td>
                <td>$($error.LogFile)</td>
            </tr>
"@
    }

    $html += @"
        </tbody>
    </table>
    
    <div class="machines-section">
        <h2>Machines Critiques (>3 erreurs)</h2>
"@

    if ($ReportData.criticalMachines.Count -gt 0) {
        foreach ($machine in $ReportData.criticalMachines) {
            $html += @"
        <div class="critical" style="margin: 10px 0; padding: 10px;">
            <strong>$($machine.hostname)</strong> - $($machine.errorCount) erreurs
            <br>Types: $($machine.errorTypes -join ', ')
        </div>
"@
        }
    } else {
        $html += "<p>Aucune machine critique détectée.</p>"
    }

    $html += @"
    </div>
</body>
</html>
"@

    return $html
}

# === EXÉCUTION PRINCIPALE ===
Write-Host "🔍 Ring Error Monitor - $Ring" -ForegroundColor Yellow
Write-Host "Surveillance des erreurs critiques..." -ForegroundColor Gray

while ($true) {
    try {
        # Rechercher erreurs critiques
        $errors = Search-CriticalErrors -LogPath $LogPath -Ring $Ring
        
        if ($errors.Count -gt 0) {
            Write-Host "⚠️ $($errors.Count) erreur(s) critique(s) détectée(s)" -ForegroundColor Red
            
            # Envoyer alertes pour nouvelles erreurs
            if ($AlertMode) {
                $errors | ForEach-Object {
                    Send-CriticalAlert -Error $_ -Ring $Ring
                }
            }
            
            # Générer rapport
            $reportFile = Generate-ErrorReport -Errors $errors -Ring $Ring -OutputPath $OutputPath
            
            # Afficher résumé
            Write-Host "📊 Résumé des erreurs:" -ForegroundColor Yellow
            $errors | Group-Object ErrorType | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
            }
        } else {
            Write-Host "✅ Aucune erreur critique détectée" -ForegroundColor Green
        }
        
        Write-Host "⏰ Prochaine vérification dans $IntervalMinutes minute(s)..." -ForegroundColor Gray
        Start-Sleep -Seconds ($IntervalMinutes * 60)
        
    } catch {
        Write-Error "Erreur monitoring: $($_.Exception.Message)"
        Start-Sleep -Seconds 60
    }
}
```

## Déploiement du Monitoring

### Configuration par Ring

#### Ring 0 (Équipe Interne)
```powershell
# Surveillance intensive - 1 minute
.\scripts\ring-error-monitor.ps1 -Ring ring0 -IntervalMinutes 1 -AlertMode

# Variables d'environnement
$env:SLACK_WEBHOOK_CRITICAL = "https://hooks.slack.com/services/..."
$env:SMTP_SERVER = "smtp.company.com"
```

#### Ring 1 (Clients Pilotes) 
```powershell
# Surveillance modérée - 5 minutes
.\scripts\ring-error-monitor.ps1 -Ring ring1 -IntervalMinutes 5 -AlertMode
```

#### GA (Production)
```powershell
# Surveillance standard - 15 minutes avec reporting
.\scripts\ring-error-monitor.ps1 -Ring ga -IntervalMinutes 15
```

## Dashboard de Synthèse

### Script de Dashboard Temps Réel
```powershell
# scripts/ring-dashboard.ps1
param(
    [string]$MonitoringPath = ".\monitoring\ring-errors"
)

function Show-RingStatus {
    Clear-Host
    
    Write-Host "🎯 USB VIDEO VAULT - RING DEPLOYMENT STATUS" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Mise à jour: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    $rings = @("ring0", "ring1", "ga")
    
    foreach ($ring in $rings) {
        Write-Host "[$($ring.ToUpper())]" -ForegroundColor Yellow -NoNewline
        
        # Chercher le rapport le plus récent
        $latestReport = Get-ChildItem $MonitoringPath -Filter "error-report-$ring-*.json" | 
                       Sort-Object LastWriteTime -Descending | 
                       Select-Object -First 1
        
        if ($latestReport) {
            $reportData = Get-Content $latestReport.FullName | ConvertFrom-Json
            $totalErrors = $reportData.totalErrors
            
            if ($totalErrors -eq 0) {
                Write-Host " ✅ SAIN" -ForegroundColor Green
            } elseif ($totalErrors -lt 5) {
                Write-Host " ⚠️ ATTENTION ($totalErrors erreurs)" -ForegroundColor Yellow
            } else {
                Write-Host " 🚨 CRITIQUE ($totalErrors erreurs)" -ForegroundColor Red
            }
            
            # Détails par type d'erreur
            foreach ($errorType in $reportData.errorsByType.PSObject.Properties) {
                Write-Host "  $($errorType.Name): $($errorType.Value)" -ForegroundColor White
            }
        } else {
            Write-Host " ❓ INCONNU (pas de rapport)" -ForegroundColor Gray
        }
        
        Write-Host ""
    }
    
    Write-Host "Appuyer sur Ctrl+C pour arrêter..." -ForegroundColor Gray
}

# Boucle d'affichage
while ($true) {
    Show-RingStatus
    Start-Sleep -Seconds 30
}
```

Cette solution de monitoring offre une surveillance complète des erreurs critiques avec alertes immédiates et rapports détaillés pour chaque ring de déploiement.