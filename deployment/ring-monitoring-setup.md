# Ring Deployment Monitoring Dashboard Configuration

## Vue d'ensemble

Configuration du système de monitoring pour le déploiement par anneaux du USB Video Vault.

## Métriques par Ring

### Ring 0 (Équipe Interne)
```javascript
const ring0Metrics = {
  // Métriques techniques
  errorRate: { threshold: 0.1, unit: '%' },
  startupTime: { threshold: 5, unit: 'seconds' },
  memoryUsage: { threshold: 200, unit: 'MB' },
  licenseValidationTime: { threshold: 1, unit: 'seconds' },
  
  // Métriques sécurité
  signatureErrors: { threshold: 0, unit: 'count' },
  antiRollbackErrors: { threshold: 0, unit: 'count' },
  
  // Métriques stabilité
  crashRate: { threshold: 0, unit: 'count/24h' },
  uptime: { threshold: 99.9, unit: '%' }
};
```

### Ring 1 (Clients Pilotes)
```javascript
const ring1Metrics = {
  // Métriques utilisateur
  userSatisfaction: { threshold: 8.0, unit: '/10' },
  supportTickets: { threshold: 2, unit: 'count/week' },
  resolutionTime: { threshold: 24, unit: 'hours' },
  
  // Métriques business
  serviceAvailability: { threshold: 99.0, unit: '%' },
  featureAdoption: { threshold: 70, unit: '%' },
  
  // Métriques techniques héritées
  ...ring0Metrics
};
```

## Système d'Alertes

### Configuration Slack
```json
{
  "slack": {
    "webhookUrl": "${SLACK_WEBHOOK_URL}",
    "channels": {
      "critical": "#deployment-critical",
      "warnings": "#deployment-warnings", 
      "info": "#deployment-info"
    },
    "alertLevels": {
      "CRITICAL": ["signature_error", "antirollback_error", "crash"],
      "WARNING": ["performance_degradation", "high_error_rate"],
      "INFO": ["ring_progression", "milestone_reached"]
    }
  }
}
```

### Configuration Email
```json
{
  "email": {
    "smtp": {
      "host": "${SMTP_HOST}",
      "port": 587,
      "secure": false,
      "auth": {
        "user": "${SMTP_USER}",
        "pass": "${SMTP_PASS}"
      }
    },
    "recipients": {
      "critical": ["dev-team@company.com", "ops@company.com"],
      "escalation": ["management@company.com"]
    }
  }
}
```

## Scripts de Monitoring

### Collecteur de Métriques
```powershell
# scripts/ring-metrics-collector.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("ring0", "ring1", "ga")]
    [string]$Ring,
    
    [string]$OutputPath = ".\monitoring\metrics",
    [int]$IntervalMinutes = 5
)

function Collect-ApplicationMetrics {
    param([string]$Ring)
    
    $metrics = @{
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        ring = $Ring
        hostname = $env:COMPUTERNAME
        version = (Get-Content "package.json" | ConvertFrom-Json).version
    }
    
    # Métriques système
    $process = Get-Process "USB Video Vault" -ErrorAction SilentlyContinue
    if ($process) {
        $metrics.memoryUsage = [math]::Round($process.WorkingSet64 / 1MB, 2)
        $metrics.cpuUsage = $process.CPU
        $metrics.processUptime = (Get-Date) - $process.StartTime
    }
    
    # Métriques application
    $logPath = "$env:APPDATA\usb-video-vault\logs"
    if (Test-Path $logPath) {
        $todayLogs = Get-ChildItem $logPath -Filter "*.log" | 
                    Where-Object { $_.LastWriteTime -gt (Get-Date).Date }
        
        $errorCount = 0
        $signatureErrors = 0
        $antiRollbackErrors = 0
        
        foreach ($log in $todayLogs) {
            $content = Get-Content $log.FullName -Raw
            $errorCount += ($content | Select-String -Pattern "ERROR" -AllMatches).Matches.Count
            $signatureErrors += ($content | Select-String -Pattern "Signature invalide" -AllMatches).Matches.Count
            $antiRollbackErrors += ($content | Select-String -Pattern "Anti-rollback" -AllMatches).Matches.Count
        }
        
        $metrics.errorCount = $errorCount
        $metrics.signatureErrors = $signatureErrors
        $metrics.antiRollbackErrors = $antiRollbackErrors
    }
    
    return $metrics
}

function Send-MetricsToMonitoring {
    param([object]$Metrics, [string]$OutputPath)
    
    $fileName = "metrics-$($Metrics.ring)-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
    $filePath = Join-Path $OutputPath $fileName
    
    # Assurer que le dossier existe
    $directory = Split-Path $filePath -Parent
    if (-not (Test-Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }
    
    # Sauvegarder les métriques
    $Metrics | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
    
    # Envoyer à l'API de monitoring (si configurée)
    $monitoringUrl = $env:MONITORING_API_URL
    if ($monitoringUrl) {
        try {
            $body = $Metrics | ConvertTo-Json -Depth 10
            Invoke-RestMethod -Uri "$monitoringUrl/metrics" -Method POST -Body $body -ContentType "application/json"
        } catch {
            Write-Warning "Impossible d'envoyer les métriques à l'API: $($_.Exception.Message)"
        }
    }
}

# Collecte principale
while ($true) {
    try {
        $metrics = Collect-ApplicationMetrics -Ring $Ring
        Send-MetricsToMonitoring -Metrics $metrics -OutputPath $OutputPath
        
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Métriques collectées pour $Ring" -ForegroundColor Green
        
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    } catch {
        Write-Error "Erreur collecte métriques: $($_.Exception.Message)"
        Start-Sleep -Seconds 60
    }
}
```

### Système d'Alertes
```powershell
# scripts/ring-alerting.ps1
param(
    [string]$MetricsPath = ".\monitoring\metrics",
    [string]$ConfigPath = ".\monitoring\alerting-config.json"
)

function Load-AlertingConfig {
    param([string]$ConfigPath)
    
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath | ConvertFrom-Json
    } else {
        throw "Configuration d'alerting non trouvée: $ConfigPath"
    }
}

function Check-Thresholds {
    param([object]$Metrics, [object]$Config)
    
    $alerts = @()
    
    # Vérifier erreurs critiques
    if ($Metrics.signatureErrors -gt 0) {
        $alerts += @{
            level = "CRITICAL"
            type = "signature_error"
            message = "Erreurs de signature détectées: $($Metrics.signatureErrors)"
            ring = $Metrics.ring
            hostname = $Metrics.hostname
        }
    }
    
    if ($Metrics.antiRollbackErrors -gt 0) {
        $alerts += @{
            level = "CRITICAL" 
            type = "antirollback_error"
            message = "Erreurs anti-rollback détectées: $($Metrics.antiRollbackErrors)"
            ring = $Metrics.ring
            hostname = $Metrics.hostname
        }
    }
    
    # Vérifier performance
    if ($Metrics.memoryUsage -gt 200) {
        $alerts += @{
            level = "WARNING"
            type = "performance_degradation"
            message = "Consommation mémoire élevée: $($Metrics.memoryUsage)MB"
            ring = $Metrics.ring
            hostname = $Metrics.hostname
        }
    }
    
    return $alerts
}

function Send-SlackAlert {
    param([object]$Alert, [object]$Config)
    
    $webhookUrl = $Config.slack.webhookUrl
    $channel = switch ($Alert.level) {
        "CRITICAL" { $Config.slack.channels.critical }
        "WARNING" { $Config.slack.channels.warnings }
        default { $Config.slack.channels.info }
    }
    
    $emoji = switch ($Alert.level) {
        "CRITICAL" { ":red_circle:" }
        "WARNING" { ":warning:" }
        default { ":information_source:" }
    }
    
    $payload = @{
        channel = $channel
        username = "Ring Deployment Monitor"
        icon_emoji = ":gear:"
        attachments = @(
            @{
                color = switch ($Alert.level) {
                    "CRITICAL" { "danger" }
                    "WARNING" { "warning" }
                    default { "good" }
                }
                title = "Ring $($Alert.ring) - $($Alert.type)"
                text = "$emoji $($Alert.message)"
                fields = @(
                    @{
                        title = "Hostname"
                        value = $Alert.hostname
                        short = $true
                    },
                    @{
                        title = "Time"
                        value = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        short = $true
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method POST -Body $payload -ContentType "application/json"
        Write-Host "Alerte Slack envoyée: $($Alert.type)" -ForegroundColor Yellow
    } catch {
        Write-Error "Erreur envoi Slack: $($_.Exception.Message)"
    }
}

# Monitoring principal
$config = Load-AlertingConfig -ConfigPath $ConfigPath

while ($true) {
    try {
        # Lire les dernières métriques
        $latestMetrics = Get-ChildItem $MetricsPath -Filter "*.json" | 
                        Sort-Object LastWriteTime -Descending | 
                        Select-Object -First 10
        
        foreach ($metricsFile in $latestMetrics) {
            $metrics = Get-Content $metricsFile.FullName | ConvertFrom-Json
            $alerts = Check-Thresholds -Metrics $metrics -Config $config
            
            foreach ($alert in $alerts) {
                Send-SlackAlert -Alert $alert -Config $config
            }
        }
        
        Start-Sleep -Seconds 300  # 5 minutes
    } catch {
        Write-Error "Erreur monitoring: $($_.Exception.Message)"
        Start-Sleep -Seconds 60
    }
}
```

## Configuration Dashboard

### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "USB Video Vault - Ring Deployment",
    "panels": [
      {
        "title": "Ring Status",
        "type": "stat",
        "targets": [
          {
            "query": "ring_status{ring=\"ring0\"}",
            "legend": "Ring 0"
          },
          {
            "query": "ring_status{ring=\"ring1\"}", 
            "legend": "Ring 1"
          }
        ]
      },
      {
        "title": "Error Rate by Ring",
        "type": "graph",
        "targets": [
          {
            "query": "rate(errors_total[5m]) by (ring)",
            "legend": "{{ring}}"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph", 
        "targets": [
          {
            "query": "memory_usage_mb by (ring)",
            "legend": "{{ring}}"
          }
        ]
      }
    ]
  }
}
```

## Scripts de Déploiement

### Déploiement automatisé par ring
```powershell
# scripts/deploy-ring.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("ring0", "ring1", "ga")]
    [string]$Ring,
    
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [string]$TargetsFile = ".\deployment\ring-targets.json"
)

function Deploy-ToRing {
    param([string]$Ring, [string]$Version, [array]$Targets)
    
    Write-Host "Déploiement $Version vers $Ring ($($Targets.Count) targets)" -ForegroundColor Green
    
    foreach ($target in $Targets) {
        try {
            Write-Host "  Déploiement vers $($target.hostname)..." -ForegroundColor Yellow
            
            # Logique de déploiement spécifique
            switch ($target.type) {
                "internal" { Deploy-Internal -Target $target -Version $Version }
                "client" { Deploy-Client -Target $target -Version $Version }
                default { throw "Type de target non supporté: $($target.type)" }
            }
            
            Write-Host "  ✅ $($target.hostname) déployé avec succès" -ForegroundColor Green
        } catch {
            Write-Error "❌ Échec déploiement $($target.hostname): $($_.Exception.Message)"
        }
    }
}

# Chargement configuration
$config = Get-Content $TargetsFile | ConvertFrom-Json
$targets = $config.rings.$Ring.targets

# Validation pré-déploiement
if ($Ring -eq "ring1" -and -not $config.rings.ring0.validated) {
    throw "Ring 0 non validé - impossible de déployer Ring 1"
}

if ($Ring -eq "ga" -and -not $config.rings.ring1.validated) {
    throw "Ring 1 non validé - impossible de déployer GA"
}

# Déploiement
Deploy-ToRing -Ring $Ring -Version $Version -Targets $targets
```

Cette configuration fournit une surveillance complète du déploiement par anneaux avec alertes automatiques et métriques en temps réel.