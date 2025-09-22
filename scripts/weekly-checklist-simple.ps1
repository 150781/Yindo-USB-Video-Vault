# Checklist Hebdomadaire Simplifiee - USB Video Vault
# Version sans caracteres Unicode pour compatibilite

param(
    [switch]$GenerateReport,
    [string]$OutputDir = "weekly-checks"
)

$ChecklistSLOs = @{
    MaxCrashRate = 0.5
    MaxErrorRate = 1.0
    MaxMemoryMB = 150
    MaxBackupAgeDays = 7
    MaxAntiRollbackEvents = 0
}

function Write-CheckResult {
    param($CheckName, $Status, $Details = "", $Critical = $false)
    
    $prefix = switch ($Status) {
        "PASS" { "[OK]" }
        "FAIL" { "[FAIL]" }
        "WARN" { "[WARN]" }
        default { "[INFO]" }
    }
    
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "Cyan" }
    }
    
    Write-Host "$prefix $CheckName" -ForegroundColor $color
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

function Test-QuickChecks {
    Write-Host "`n=== CHECKLIST HEBDOMADAIRE USB VIDEO VAULT ===" -ForegroundColor Cyan
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    $results = @()
    
    # 1. Process Check
    $process = Get-Process | Where-Object { $_.ProcessName -like "*USB*Video*Vault*" }
    if ($process) {
        $memoryMB = [math]::Round($process.WorkingSet64 / 1MB, 1)
        if ($memoryMB -le $ChecklistSLOs.MaxMemoryMB) {
            $results += Write-CheckResult "Memory Usage" "PASS" "Current: $memoryMB MB"
        } else {
            $results += Write-CheckResult "Memory Usage" "FAIL" "Current: $memoryMB MB (exceeds $($ChecklistSLOs.MaxMemoryMB) MB)" $true
        }
    } else {
        $results += Write-CheckResult "Application Running" "WARN" "No USB Video Vault process found"
    }
    
    # 2. License File Check
    $licensePath = "$env:ProgramData\USB Video Vault\license.bin"
    if (Test-Path $licensePath) {
        $licenseAge = (Get-Date) - (Get-Item $licensePath).LastWriteTime
        $results += Write-CheckResult "License File" "PASS" "Found, age: $([math]::Round($licenseAge.TotalDays, 1)) days"
    } else {
        $results += Write-CheckResult "License File" "WARN" "License file not found"
    }
    
    # 3. Log File Check
    $logPath = "$env:APPDATA\USB Video Vault\logs\main.log"
    if (Test-Path $logPath) {
        $logSize = [math]::Round((Get-Item $logPath).Length / 1KB, 1)
        
        # Check for recent errors
        $recentErrors = Get-Content $logPath -Tail 200 | Where-Object { 
            $_ -match 'Signature invalide|licence expiree|Anti-rollback|Erreur|ERROR|crash|fatal' 
        }
        
        if ($recentErrors.Count -eq 0) {
            $results += Write-CheckResult "Recent Errors" "PASS" "No errors in last 200 log lines"
        } else {
            $results += Write-CheckResult "Recent Errors" "WARN" "$($recentErrors.Count) error(s) found in recent logs"
        }
    } else {
        $results += Write-CheckResult "Log File" "WARN" "Main log file not found"
    }
    
    # 4. Audit Trail Check
    if (Test-Path "routine-output\audit") {
        $latestAudit = Get-ChildItem "routine-output\audit" -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestAudit) {
            $auditAge = (Get-Date) - $latestAudit.LastWriteTime
            if ($auditAge.Days -le 7) {
                $results += Write-CheckResult "Audit Trail" "PASS" "Latest audit: $([math]::Round($auditAge.TotalDays, 1)) days ago"
            } else {
                $results += Write-CheckResult "Audit Trail" "WARN" "Latest audit: $($auditAge.Days) days ago (run weekly audit)"
            }
        } else {
            $results += Write-CheckResult "Audit Trail" "WARN" "No audit files found"
        }
    } else {
        $results += Write-CheckResult "Audit Trail" "WARN" "No audit directory found"
    }
    
    # 5. Backup Check
    if (Test-Path "routine-output\backups") {
        $latestBackup = Get-ChildItem "routine-output\backups" -Filter "*.key" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestBackup) {
            $backupAge = (Get-Date) - $latestBackup.LastWriteTime
            if ($backupAge.Days -le $ChecklistSLOs.MaxBackupAgeDays) {
                $results += Write-CheckResult "Key Backup" "PASS" "Latest backup: $($backupAge.Days) days ago"
            } else {
                $results += Write-CheckResult "Key Backup" "FAIL" "Latest backup: $($backupAge.Days) days ago (exceeds $($ChecklistSLOs.MaxBackupAgeDays) days)" $true
            }
        } else {
            $results += Write-CheckResult "Key Backup" "FAIL" "No backup files found" $true
        }
    } else {
        $results += Write-CheckResult "Key Backup" "WARN" "No backup directory found"
    }
    
    # 6. SBOM Check
    if (Test-Path "dist\sbom-v1.0.4.json") {
        $sbomAge = (Get-Date) - (Get-Item "dist\sbom-v1.0.4.json").LastWriteTime
        if ($sbomAge.Days -le 7) {
            $results += Write-CheckResult "SBOM Currency" "PASS" "SBOM age: $($sbomAge.Days) days"
        } else {
            $results += Write-CheckResult "SBOM Currency" "WARN" "SBOM age: $($sbomAge.Days) days (consider updating)"
        }
    } else {
        $results += Write-CheckResult "SBOM Currency" "WARN" "SBOM file not found"
    }
    
    return $results
}

# === EXECUTION PRINCIPALE ===

try {
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    $checkResults = Test-QuickChecks
    
    # Resume
    Write-Host ""
    Write-Host "=== RESUME CHECKLIST ===" -ForegroundColor Cyan
    
    $passes = $checkResults | Where-Object { $_.Status -eq "PASS" }
    $warnings = $checkResults | Where-Object { $_.Status -eq "WARN" }
    $failures = $checkResults | Where-Object { $_.Status -eq "FAIL" }
    $criticalFailures = $failures | Where-Object { $_.Critical }
    
    Write-Host "Passed: $($passes.Count)" -ForegroundColor Green
    Write-Host "Warnings: $($warnings.Count)" -ForegroundColor Yellow
    Write-Host "Failures: $($failures.Count)" -ForegroundColor Red
    Write-Host "Critical: $($criticalFailures.Count)" -ForegroundColor Magenta
    
    $overallStatus = if ($criticalFailures.Count -gt 0) { 
        "CRITICAL ISSUES" 
    } elseif ($failures.Count -gt 0) { 
        "ISSUES DETECTED" 
    } elseif ($warnings.Count -gt 0) { 
        "MINOR WARNINGS" 
    } else { 
        "HEALTHY" 
    }
    
    Write-Host "`nOverall Status: $overallStatus" -ForegroundColor $(
        switch ($overallStatus) {
            "HEALTHY" { "Green" }
            "MINOR WARNINGS" { "Yellow" }
            default { "Red" }
        }
    )
    
    # Generate Report
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
        }
        
        $reportPath = Join-Path $OutputDir "weekly-check-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $report | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportPath -Encoding UTF8
        
        Write-Host "`nRapport sauvegarde: $reportPath" -ForegroundColor Cyan
        
        # Show critical issues if any
        if ($criticalFailures.Count -gt 0) {
            Write-Host "`nACTIONS REQUISES:" -ForegroundColor Red
            foreach ($critical in $criticalFailures) {
                Write-Host "  - $($critical.Check): $($critical.Details)" -ForegroundColor Red
            }
        }
    }
    
    # Exit code based on results
    $exitCode = if ($criticalFailures.Count -gt 0) { 2 } elseif ($failures.Count -gt 0) { 1 } else { 0 }
    exit $exitCode
    
} catch {
    Write-Host "Erreur checklist: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}