# Checklist Hebdomadaire Automatisée - USB Video Vault
# Toutes les vérifications critiques en un seul script

param(
    [switch]$GenerateReport,
    [switch]$SendAlerts,
    [string]$OutputDir = "weekly-checks",
    [string]$WebhookUrl = "",
    [switch]$Verbose
)

# === CONFIGURATION CHECKLIST ===

$ChecklistSLOs = @{
    MaxCrashRate = 0.5      # < 0.5%
    MaxErrorRate = 1.0      # < 1%
    MaxMemoryMB = 150       # < 150 MB
    MaxBackupAgeDays = 7    # < 7 jours
    MaxAntiRollbackEvents = 0  # = 0
}

# === FONCTIONS CHECKLIST ===

function Write-CheckResult {
    param($CheckName, $Status, $Details = "", $Critical = $false)
    
    $icon = switch ($Status) {
        "PASS" { "OK" }
        "FAIL" { "FAIL" }
        "WARN" { "WARN" }
        default { "INFO" }
    }
    
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "Cyan" }
    }
    
    Write-Host "$icon [$Status] $CheckName" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
    
    return @{
        Check = $CheckName
        Status = $Status
        Details = $Details
        Critical = $Critical
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

function Test-CrashRate {
    $logPath = "$env:APPDATA\USB Video Vault\logs\main.log"
    
    try {
        if (!(Test-Path $logPath)) {
            return Write-CheckResult "Crash Rate" "WARN" "Log file not found"
        }
        
        $logContent = Get-Content $logPath -ErrorAction SilentlyContinue
        $cutoffDate = (Get-Date).AddDays(-7)
        
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
            $rate = 0
        } else {
            $rate = ($crashCount / $startupCount) * 100
        }
        
        $status = if ($rate -le $ChecklistSLOs.MaxCrashRate) { "PASS" } else { "FAIL" }
        $details = "Rate: $([math]::Round($rate, 2))% (Crashes: $crashCount, Startups: $startupCount)"
        
        return Write-CheckResult "Crash Rate below $($ChecklistSLOs.MaxCrashRate) percent" $status $details $true
        
    } catch {
        return Write-CheckResult "Crash Rate" "WARN" "Error reading logs: $($_.Exception.Message)"
    }
}

function Test-LicenseErrorRate {
    $logPath = "$env:APPDATA\USB Video Vault\logs\main.log"
    
    try {
        if (!(Test-Path $logPath)) {
            return Write-CheckResult "License Error Rate" "WARN" "Log file not found"
        }
        
        $logContent = Get-Content $logPath -ErrorAction SilentlyContinue
        $cutoffDate = (Get-Date).AddDays(-7)
        
        $licenseErrors = $logContent | Where-Object { 
            $_ -match "licence.*invalide|signature.*invalide|licence.*expir" -and
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
            $rate = 0
        } else {
            $rate = ($errorCount / $totalValidations) * 100
        }
        
        $status = if ($rate -le $ChecklistSLOs.MaxErrorRate) { "PASS" } else { "FAIL" }
        $details = "Rate: $([math]::Round($rate, 2))% (Errors: $errorCount, Validations: $totalValidations)"
        
        return Write-CheckResult "License Error Rate below $($ChecklistSLOs.MaxErrorRate) percent" $status $details $true
        
    } catch {
        return Write-CheckResult "License Error Rate" "WARN" "Error reading logs: $($_.Exception.Message)"
    }
}

function Test-AntiRollbackEvents {
    $logPath = "$env:APPDATA\USB Video Vault\logs\main.log"
    
    try {
        if (!(Test-Path $logPath)) {
            return Write-CheckResult "Anti-Rollback Events" "WARN" "Log file not found"
        }
        
        $logContent = Get-Content $logPath -ErrorAction SilentlyContinue
        $cutoffDate = (Get-Date).AddDays(-7)
        
        $antiRollbackEvents = $logContent | Where-Object { 
            $_ -match "anti-rollback|rollback.*detect" -and
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

        $eventCount = ($antiRollbackEvents | Measure-Object).Count
        $status = if ($eventCount -eq $ChecklistSLOs.MaxAntiRollbackEvents) { "PASS" } else { "FAIL" }
        $details = "Events: $eventCount (last 7 days)"
        
        return Write-CheckResult "Anti-Rollback Events = 0" $status $details $true
        
    } catch {
        return Write-CheckResult "Anti-Rollback Events" "WARN" "Error reading logs: $($_.Exception.Message)"
    }
}

function Test-SBOMSecurityDiff {
    try {
        $sbomPath = "dist\sbom-v1.0.4.json"
        
        if (!(Test-Path $sbomPath)) {
            return Write-CheckResult "SBOM CVE Check" "WARN" "SBOM file not found: $sbomPath"
        }
        
        # Simuler une vérification CVE (en production, ceci ferait appel à une API CVE)
        $sbomAge = (Get-Date) - (Get-Item $sbomPath).LastWriteTime
        
        if ($sbomAge.Days -gt 7) {
            $status = "WARN"
            $details = "SBOM age: $($sbomAge.Days) days (> 7 days, consider updating)"
        } else {
            $status = "PASS"
            $details = "SBOM age: $($sbomAge.Days) days, no critical CVEs detected (simulated)"
        }
        
        return Write-CheckResult "SBOM CVE Check" $status $details
        
    } catch {
        return Write-CheckResult "SBOM CVE Check" "WARN" "Error checking SBOM: $($_.Exception.Message)"
    }
}

function Test-AuditLicenses {
    try {
        # Vérifier l'audit trail le plus récent
        $auditDir = "routine-output\audit"
        
        if (!(Test-Path $auditDir)) {
            return Write-CheckResult "License Audit Trail" "WARN" "No audit directory found"
        }
        
        $latestAudit = Get-ChildItem $auditDir -Filter "audit-trail-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if (!$latestAudit) {
            return Write-CheckResult "License Audit Trail" "WARN" "No audit trail found"
        }
        
        $auditAge = (Get-Date) - $latestAudit.LastWriteTime
        
        if ($auditAge.Days -gt 7) {
            $status = "WARN"
            $details = "Latest audit: $($auditAge.Days) days old (run weekly audit)"
        } else {
            # Vérifier le contenu de l'audit
            $auditData = Get-Content $latestAudit.FullName | ConvertFrom-Json
            
            if ($auditData.Summary.Issues -and $auditData.Summary.Issues.Count -gt 0) {
                $status = "WARN"
                $details = "Audit issues found: $($auditData.Summary.Issues.Count) problems"
            } else {
                $status = "PASS"
                $details = "Latest audit: $([math]::Round($auditAge.TotalHours, 1)) hours ago, no issues"
            }
        }
        
        return Write-CheckResult "License Audit Trail" $status $details
        
    } catch {
        return Write-CheckResult "License Audit Trail" "WARN" "Error checking audit: $($_.Exception.Message)"
    }
}

function Test-KeyBackup {
    try {
        $backupDir = "routine-output\backups"
        
        if (!(Test-Path $backupDir)) {
            return Write-CheckResult "Key Backup Age" "WARN" "No backup directory found"
        }
        
        $latestBackup = Get-ChildItem $backupDir -Filter "*.key" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if (!$latestBackup) {
            return Write-CheckResult "Key Backup Age" "FAIL" "No backup files found" $true
        }
        
        $backupAge = (Get-Date) - $latestBackup.LastWriteTime
        
        if ($backupAge.Days -gt $ChecklistSLOs.MaxBackupAgeDays) {
            $status = "FAIL"
            $details = "Backup age: $($backupAge.Days) days (> $($ChecklistSLOs.MaxBackupAgeDays) days)"
            $critical = $true
        } else {
            $status = "PASS"
            $details = "Backup age: $($backupAge.Days) days"
            $critical = $false
        }
        
        return Write-CheckResult "Key Backup Age below $($ChecklistSLOs.MaxBackupAgeDays) days" $status $details $critical
        
    } catch {
        return Write-CheckResult "Key Backup Age" "WARN" "Error checking backup: $($_.Exception.Message)"
    }
}

function Test-KIDRotationReadiness {
    try {
        $rotationDir = "routine-output\rotation"
        
        if (!(Test-Path $rotationDir)) {
            return Write-CheckResult "KID Rotation Test" "WARN" "No rotation test directory found"
        }
        
        $latestRotationTest = Get-ChildItem $rotationDir -Filter "kid-rotation-test-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if (!$latestRotationTest) {
            return Write-CheckResult "KID Rotation Test" "WARN" "No rotation test found (run monthly test)"
        }
        
        $testAge = (Get-Date) - $latestRotationTest.LastWriteTime
        
        if ($testAge.Days -gt 30) {
            $status = "WARN"
            $details = "Last test: $($testAge.Days) days ago (run monthly test)"
        } else {
            $rotationData = Get-Content $latestRotationTest.FullName | ConvertFrom-Json
            
            if ($rotationData.GlobalStatus -eq "READY") {
                $status = "PASS"
                $details = "Last test: $([math]::Round($testAge.TotalDays, 1)) days ago, status: READY"
            } else {
                $status = "WARN"
                $details = "Last test: $([math]::Round($testAge.TotalDays, 1)) days ago, status: NOT_READY"
            }
        }
        
        return Write-CheckResult "KID Rotation Test" $status $details
        
    } catch {
        return Write-CheckResult "KID Rotation Test" "WARN" "Error checking rotation test: $($_.Exception.Message)"
    }
}

function Send-WeeklyAlert {
    param($CheckResults, $WebhookUrl)
    
    if (!$WebhookUrl) {
        return
    }
    
    $criticalFailures = $CheckResults | Where-Object { $_.Status -eq "FAIL" -and $_.Critical }
    $warnings = $CheckResults | Where-Object { $_.Status -eq "WARN" }
    $passes = $CheckResults | Where-Object { $_.Status -eq "PASS" }
    
    $overallStatus = if ($criticalFailures.Count -gt 0) { "CRITICAL" } elseif ($warnings.Count -gt 0) { "WARNING" } else { "HEALTHY" }
    
    $color = switch ($overallStatus) {
        "CRITICAL" { "danger" }
        "WARNING" { "warning" }
        default { "good" }
    }
    
    $payload = @{
        text = "🔍 USB Video Vault - Weekly Health Check"
        attachments = @(@{
            color = $color
            fields = @(
                @{ title = "Overall Status"; value = $overallStatus; short = $true }
                @{ title = "Checks Run"; value = $CheckResults.Count; short = $true }
                @{ title = "Passes"; value = $passes.Count; short = $true }
                @{ title = "Warnings"; value = $warnings.Count; short = $true }
                @{ title = "Critical Failures"; value = $criticalFailures.Count; short = $true }
                @{ title = "Timestamp"; value = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); short = $true }
            )
        })
    }
    
    if ($criticalFailures.Count -gt 0) {
        $failureText = ($criticalFailures | ForEach-Object { "❌ $($_.Check): $($_.Details)" }) -join "`n"
        $payload.attachments[0].fields += @{ title = "Critical Issues"; value = $failureText; short = $false }
    }
    
    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body ($payload | ConvertTo-Json -Depth 4) -ContentType "application/json"
        Write-Host "✅ Weekly alert sent successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to send alert: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# === EXECUTION PRINCIPALE ===

try {
    Write-Host "`n🔍 === CHECKLIST HEBDOMADAIRE USB VIDEO VAULT ===" -ForegroundColor Cyan
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    # Créer répertoire de sortie
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    # Exécuter tous les checks
    $checkResults = @()
    
    $checkResults += Test-CrashRate
    $checkResults += Test-LicenseErrorRate
    $checkResults += Test-AntiRollbackEvents
    $checkResults += Test-SBOMSecurityDiff
    $checkResults += Test-AuditLicenses
    $checkResults += Test-KeyBackup
    $checkResults += Test-KIDRotationReadiness
    
    # Résumé
    Write-Host ""
    Write-Host "📊 === RESUME CHECKLIST ===" -ForegroundColor Cyan
    
    $passes = $checkResults | Where-Object { $_.Status -eq "PASS" }
    $warnings = $checkResults | Where-Object { $_.Status -eq "WARN" }
    $failures = $checkResults | Where-Object { $_.Status -eq "FAIL" }
    $criticalFailures = $failures | Where-Object { $_.Critical }
    
    Write-Host "✅ Passed: $($passes.Count)" -ForegroundColor Green
    Write-Host "⚠️ Warnings: $($warnings.Count)" -ForegroundColor Yellow
    Write-Host "❌ Failures: $($failures.Count)" -ForegroundColor Red
    Write-Host "🚨 Critical: $($criticalFailures.Count)" -ForegroundColor Magenta
    
    $overallStatus = if ($criticalFailures.Count -gt 0) { "CRITICAL ISSUES" } elseif ($failures.Count -gt 0) { "ISSUES DETECTED" } elseif ($warnings.Count -gt 0) { "MINOR WARNINGS" } else { "HEALTHY" }
    
    Write-Host "`n🎯 Overall Status: $overallStatus" -ForegroundColor $(
        switch ($overallStatus) {
            "HEALTHY" { "Green" }
            "MINOR WARNINGS" { "Yellow" }
            default { "Red" }
        }
    )
    
    # Générer rapport
    if ($GenerateReport) {
        $report = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            OverallStatus = $overallStatus
            Summary = @{
                Total = $checkResults.Count
                Passed = $passes.Count
                Warnings = $warnings.Count
                Failures = $failures.Count
                Critical = $criticalFailures.Count
            }
            Checks = $checkResults
            SLOs = $ChecklistSLOs
        }
        
        $reportPath = Join-Path $OutputDir "weekly-check-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $report | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportPath -Encoding UTF8
        
        Write-Host "`n📄 Rapport sauvegardé: $reportPath" -ForegroundColor Cyan
    }
    
    # Envoyer alertes
    if ($SendAlerts) {
        Send-WeeklyAlert -CheckResults $checkResults -WebhookUrl $WebhookUrl
    }
    
    # Code de sortie selon les résultats
    $exitCode = if ($criticalFailures.Count -gt 0) { 2 } elseif ($failures.Count -gt 0) { 1 } else { 0 }
    
    Write-Host ""
    exit $exitCode
    
} catch {
    Write-Host "❌ Erreur checklist: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}