# Production Monitoring & SLOs - USB Video Vault
# Surveillance continue avec alertes on-call

param(
    [string]$Mode = "check",  # check, alert, dashboard
    [string]$LogDir = "$env:APPDATA\USB Video Vault\logs",
    [string]$OutputDir = "monitoring-output",
    [int]$DaysBack = 7,
    [string]$WebhookUrl = "",  # Teams/Slack pour alertes
    [switch]$Verbose
)

# === CONFIGURATION SLOs ===
$SLOs = @{
    CrashRate = 0.5        # < 0.5%
    LicenseErrorRate = 1.0 # < 1% 
    StartupTime = 3000     # < 3s (ms)
    MemoryUsage = 150      # < 150 MB
}

# === FONCTIONS MONITORING ===

function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Write-Host $logMessage -ForegroundColor $(
        switch($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    
    if ($Verbose) {
        Add-Content -Path "$OutputDir\monitoring-$(Get-Date -Format 'yyyyMMdd').log" -Value $logMessage
    }
}

function Get-CrashRate {
    param($LogPath, $Days)
    
    try {
        if (!(Test-Path $LogPath)) {
            Write-Log "Log principal non trouvé: $LogPath" "WARN"
            return @{ Rate = 0; Count = 0; Total = 0 }
        }

        $logContent = Get-Content $LogPath -ErrorAction SilentlyContinue
        $cutoffDate = (Get-Date).AddDays(-$Days)
        
        # Compter les crashes et démarrages
        $crashes = $logContent | Where-Object { 
            $_ -match "crash|fatal|exception|unhandled" -and
            $_ -match "\d{4}-\d{2}-\d{2}" 
        } | Where-Object {
            try {
                $dateMatch = [regex]::Match($_, '\d{4}-\d{2}-\d{2}')
                if ($dateMatch.Success) {
                    $logDate = [datetime]::Parse($dateMatch.Value)
                    return $logDate -gt $cutoffDate
                }
            } catch { }
            return $false
        }
        
        $startups = $logContent | Where-Object { 
            $_ -match "application.*start|main.*init" -and
            $_ -match "\d{4}-\d{2}-\d{2}"
        } | Where-Object {
            try {
                $dateMatch = [regex]::Match($_, '\d{4}-\d{2}-\d{2}')
                if ($dateMatch.Success) {
                    $logDate = [datetime]::Parse($dateMatch.Value)
                    return $logDate -gt $cutoffDate
                }
            } catch { }
            return $false
        }

        $crashCount = ($crashes | Measure-Object).Count
        $startupCount = ($startups | Measure-Object).Count
        
        if ($startupCount -eq 0) {
            return @{ Rate = 0; Count = $crashCount; Total = 0 }
        }
        
        $rate = ($crashCount / $startupCount) * 100
        
        return @{
            Rate = [math]::Round($rate, 2)
            Count = $crashCount
            Total = $startupCount
        }
        
    } catch {
        Write-Log "Erreur calcul crash rate: $($_.Exception.Message)" "ERROR"
        return @{ Rate = 0; Count = 0; Total = 0 }
    }
}

function Get-LicenseErrorRate {
    param($LogPath, $Days)
    
    try {
        if (!(Test-Path $LogPath)) {
            return @{ Rate = 0; Count = 0; Total = 0 }
        }

        $logContent = Get-Content $LogPath -ErrorAction SilentlyContinue
        $cutoffDate = (Get-Date).AddDays(-$Days)
        
        # Erreurs de licence
        $licenseErrors = $logContent | Where-Object { 
            $_ -match "licence.*invalide|signature.*invalide|anti-rollback|licence.*expir" -and
            $_ -match "\d{4}-\d{2}-\d{2}"
        } | Where-Object {
            try {
                $dateMatch = [regex]::Match($_, '\d{4}-\d{2}-\d{2}')
                if ($dateMatch.Success) {
                    $logDate = [datetime]::Parse($dateMatch.Value)
                    return $logDate -gt $cutoffDate
                }
            } catch { }
            return $false
        }
        
        # Validations de licence
        $licenseValidations = $logContent | Where-Object { 
            $_ -match "licence.*valid|licence.*check" -and
            $_ -match "\d{4}-\d{2}-\d{2}"
        } | Where-Object {
            try {
                $dateMatch = [regex]::Match($_, '\d{4}-\d{2}-\d{2}')
                if ($dateMatch.Success) {
                    $logDate = [datetime]::Parse($dateMatch.Value)
                    return $logDate -gt $cutoffDate
                }
            } catch { }
            return $false
        }

        $errorCount = ($licenseErrors | Measure-Object).Count
        $totalValidations = ($licenseValidations | Measure-Object).Count
        
        if ($totalValidations -eq 0) {
            return @{ Rate = 0; Count = $errorCount; Total = 0 }
        }
        
        $rate = ($errorCount / $totalValidations) * 100
        
        return @{
            Rate = [math]::Round($rate, 2)
            Count = $errorCount
            Total = $totalValidations
        }
        
    } catch {
        Write-Log "Erreur calcul license error rate: $($_.Exception.Message)" "ERROR"
        return @{ Rate = 0; Count = 0; Total = 0 }
    }
}

function Get-StartupPerformance {
    try {
        # Vérifier si l'application est en cours d'exécution
        $process = Get-Process | Where-Object { $_.ProcessName -like "*USB*Video*Vault*" }
        
        if (!$process) {
            return @{ StartupTime = 0; MemoryMB = 0; Running = $false }
        }
        
        # Temps depuis le démarrage (approximation)
        $startupTime = (Get-Date) - $process.StartTime
        $memoryMB = [math]::Round($process.WorkingSet64 / 1MB, 1)
        
        return @{
            StartupTime = $startupTime.TotalMilliseconds
            MemoryMB = $memoryMB
            Running = $true
            ProcessId = $process.Id
            StartTime = $process.StartTime
        }
        
    } catch {
        Write-Log "Erreur mesure performance: $($_.Exception.Message)" "ERROR"
        return @{ StartupTime = 0; MemoryMB = 0; Running = $false }
    }
}

function Send-Alert {
    param($AlertType, $Message, $Severity = "WARNING")
    
    Write-Log "$AlertType ALERT: $Message" $Severity
    
    if ($WebhookUrl) {
        try {
            $payload = @{
                text = "🚨 USB Video Vault Alert"
                attachments = @(@{
                    color = if ($Severity -eq "ERROR") { "danger" } else { "warning" }
                    fields = @(
                        @{ title = "Type"; value = $AlertType; short = $true }
                        @{ title = "Severity"; value = $Severity; short = $true }
                        @{ title = "Message"; value = $Message; short = $false }
                        @{ title = "Timestamp"; value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); short = $true }
                    )
                })
            }
            
            Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body ($payload | ConvertTo-Json -Depth 4) -ContentType "application/json"
            Write-Log "Alerte envoyée via webhook" "SUCCESS"
        } catch {
            Write-Log "Erreur envoi alerte: $($_.Exception.Message)" "ERROR"
        }
    }
}

function Test-SLOs {
    param($LogPath)
    
    Write-Log "=== VERIFICATION SLOs USB VIDEO VAULT ===" "INFO"
    
    # 1. Crash Rate
    $crashData = Get-CrashRate -LogPath $LogPath -Days $DaysBack
    $crashSLO = $crashData.Rate -le $SLOs.CrashRate
    
    Write-Log "Crash Rate: $($crashData.Rate)% (SLO: < $($SLOs.CrashRate)%) - $(if($crashSLO){'✅ OK'}else{'❌ ECHEC'})"
    
    if (!$crashSLO) {
        Send-Alert "CRASH_RATE_SLO" "Crash rate $($crashData.Rate)% dépasse le SLO de $($SLOs.CrashRate)%" "ERROR"
    }
    
    # 2. License Error Rate
    $licenseData = Get-LicenseErrorRate -LogPath $LogPath -Days $DaysBack
    $licenseSLO = $licenseData.Rate -le $SLOs.LicenseErrorRate
    
    Write-Log "License Error Rate: $($licenseData.Rate)% (SLO: < $($SLOs.LicenseErrorRate)%) - $(if($licenseSLO){'✅ OK'}else{'❌ ECHEC'})"
    
    if (!$licenseSLO) {
        Send-Alert "LICENSE_ERROR_SLO" "License error rate $($licenseData.Rate)% dépasse le SLO de $($SLOs.LicenseErrorRate)%" "ERROR"
    }
    
    # 3. Performance
    $perfData = Get-StartupPerformance
    $memorySLO = $perfData.MemoryMB -le $SLOs.MemoryUsage -or !$perfData.Running
    
    Write-Log "Memory Usage: $($perfData.MemoryMB) MB (SLO: < $($SLOs.MemoryUsage) MB) - $(if($memorySLO){'✅ OK'}else{'❌ ECHEC'})"
    Write-Log "Application Running: $($perfData.Running)"
    
    if (!$memorySLO -and $perfData.Running) {
        Send-Alert "MEMORY_SLO" "Utilisation mémoire $($perfData.MemoryMB) MB dépasse le SLO de $($SLOs.MemoryUsage) MB" "WARNING"
    }
    
    # Résumé
    $allSLOsOk = $crashSLO -and $licenseSLO -and $memorySLO
    Write-Log "=== RESUME SLOs: $(if($allSLOsOk){'✅ TOUS OK'}else{'❌ VIOLATIONS DETECTEES'}) ===" $(if($allSLOsOk){"SUCCESS"}else{"ERROR"})
    
    return @{
        AllOK = $allSLOsOk
        CrashRate = $crashData
        LicenseErrors = $licenseData
        Performance = $perfData
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

function Export-Dashboard {
    param($SLOResults, $OutputPath)
    
    $dashboard = @{
        LastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        SLOStatus = $SLOResults.AllOK
        Metrics = @{
            CrashRate = @{
                Current = $SLOResults.CrashRate.Rate
                Threshold = $SLOs.CrashRate
                Status = if($SLOResults.CrashRate.Rate -le $SLOs.CrashRate) { "OK" } else { "VIOLATION" }
                Details = "Crashes: $($SLOResults.CrashRate.Count) / Startups: $($SLOResults.CrashRate.Total)"
            }
            LicenseErrors = @{
                Current = $SLOResults.LicenseErrors.Rate
                Threshold = $SLOs.LicenseErrorRate
                Status = if($SLOResults.LicenseErrors.Rate -le $SLOs.LicenseErrorRate) { "OK" } else { "VIOLATION" }
                Details = "Errors: $($SLOResults.LicenseErrors.Count) / Validations: $($SLOResults.LicenseErrors.Total)"
            }
            Memory = @{
                Current = $SLOResults.Performance.MemoryMB
                Threshold = $SLOs.MemoryUsage
                Status = if($SLOResults.Performance.MemoryMB -le $SLOs.MemoryUsage -or !$SLOResults.Performance.Running) { "OK" } else { "VIOLATION" }
                Details = "Process Running: $($SLOResults.Performance.Running)"
            }
        }
        Config = $SLOs
    }
    
    $dashboard | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Log "Dashboard exporté: $OutputPath" "SUCCESS"
}

# === EXECUTION PRINCIPALE ===

try {
    # Créer répertoire de sortie
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    $mainLogPath = Join-Path $LogDir "main.log"
    
    switch ($Mode) {
        "check" {
            Write-Log "Mode: Vérification SLOs" "INFO"
            $results = Test-SLOs -LogPath $mainLogPath
            
            # Exporter les résultats
            $reportPath = Join-Path $OutputDir "slo-check-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $results | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportPath -Encoding UTF8
            Write-Log "Rapport SLO sauvegardé: $reportPath" "SUCCESS"
        }
        
        "alert" {
            Write-Log "Mode: Vérification avec alertes" "INFO"
            $results = Test-SLOs -LogPath $mainLogPath
            
            # Alertes spécifiques (déjà envoyées dans Test-SLOs)
            if (!$results.AllOK) {
                Send-Alert "SLO_VIOLATIONS" "Une ou plusieurs violations SLO détectées" "ERROR"
            }
        }
        
        "dashboard" {
            Write-Log "Mode: Génération dashboard" "INFO"
            $results = Test-SLOs -LogPath $mainLogPath
            
            $dashboardPath = Join-Path $OutputDir "dashboard.json"
            Export-Dashboard -SLOResults $results -OutputPath $dashboardPath
        }
        
        default {
            Write-Log "Mode non reconnu: $Mode" "ERROR"
            exit 1
        }
    }
    
    Write-Log "Monitoring terminé avec succès" "SUCCESS"
    
} catch {
    Write-Log "Erreur monitoring: $($_.Exception.Message)" "ERROR"
    exit 1
}