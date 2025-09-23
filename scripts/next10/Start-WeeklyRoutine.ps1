param(
  [Parameter()][string]$OutDir = ".\out\routines",
  [Parameter()][switch]$DryRun = $true
)

$ErrorActionPreference = 'Stop'
$null = New-Item -ItemType Directory -Path $OutDir -Force -ErrorAction SilentlyContinue

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile = Join-Path $OutDir "weekly-routine-$timestamp.json"

Write-Host "USB Video Vault - Routine Hebdomadaire" -ForegroundColor Cyan
Write-Host "Mode: $(if($DryRun){"DRY-RUN (simulation)"}else{"PRODUCTION"})" -ForegroundColor $(if($DryRun){"Yellow"}else{"Red"})
Write-Host "Rapport: $reportFile" -ForegroundColor Yellow
Write-Host ""

$results = @{
  timestamp = Get-Date
  dryRun = $DryRun
  tasks = @()
}

function Add-TaskResult {
  param($Name, $Status, $Details, $Duration)
  $task = @{
    name = $Name
    status = $Status
    details = $Details
    duration = $Duration
    timestamp = Get-Date
  }
  $script:results.tasks += $task
  
  $emoji = switch($Status) { 
    "SUCCESS" { "[OK]" }
    "WARNING" { "[WARN]" }
    "ERROR" { "[ERR]" }
    "SKIPPED" { "[SKIP]" }
    default { "[INFO]" }
  }
  Write-Host "$emoji $Name ($Duration ms) - $Details" -ForegroundColor $(
    switch($Status) {
      "SUCCESS" { "Green" }
      "WARNING" { "Yellow" }
      "ERROR" { "Red" }
      default { "Cyan" }
    }
  )
}

# 1. Audit licences + anti-rollback
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
  $licenseScript = ".\scripts\ring1-license-batch.ps1"
  if (Test-Path $licenseScript) {
    if ($DryRun) {
      Add-TaskResult "License Audit" "SUCCESS" "Simulation: vérification ring1-license-batch.ps1" $stopwatch.ElapsedMilliseconds
    } else {
      & $licenseScript -VerifyOnly
      Add-TaskResult "License Audit" "SUCCESS" "Audit des licences terminé" $stopwatch.ElapsedMilliseconds
    }
  } else {
    Add-TaskResult "License Audit" "SKIPPED" "Script non trouvé: $licenseScript" $stopwatch.ElapsedMilliseconds
  }
} catch {
  Add-TaskResult "License Audit" "ERROR" "Erreur: $_" $stopwatch.ElapsedMilliseconds
}

# 2. Test sécurité anti-rollback
$stopwatch.Restart()
try {
  $securityScript = ".\scripts\test-security-plan.ps1"
  if (Test-Path $securityScript) {
    if ($DryRun) {
      Add-TaskResult "Security Audit" "SUCCESS" "Simulation: test-security-plan.ps1 -TestType AuditWeekly" $stopwatch.ElapsedMilliseconds
    } else {
      & $securityScript -TestType AuditWeekly
      Add-TaskResult "Security Audit" "SUCCESS" "Audit sécurité hebdomadaire terminé" $stopwatch.ElapsedMilliseconds
    }
  } else {
    Add-TaskResult "Security Audit" "SKIPPED" "Script non trouvé: $securityScript" $stopwatch.ElapsedMilliseconds
  }
} catch {
  Add-TaskResult "Security Audit" "ERROR" "Erreur: $_" $stopwatch.ElapsedMilliseconds
}

# 3. SBOM/CVE + SmartScreen
$stopwatch.Restart()
try {
  $controlsScript = ".\scripts\production-controls.ps1"
  if (Test-Path $controlsScript) {
    if ($DryRun) {
      Add-TaskResult "SBOM/SmartScreen Check" "SUCCESS" "Simulation: production-controls.ps1 -VerifySbom -VerifySmartscreen" $stopwatch.ElapsedMilliseconds
    } else {
      & $controlsScript -VerifySbom -VerifySmartscreen
      Add-TaskResult "SBOM/SmartScreen Check" "SUCCESS" "Vérification SBOM et SmartScreen terminée" $stopwatch.ElapsedMilliseconds
    }
  } else {
    Add-TaskResult "SBOM/SmartScreen Check" "SKIPPED" "Script non trouvé: $controlsScript" $stopwatch.ElapsedMilliseconds
  }
} catch {
  Add-TaskResult "SBOM/SmartScreen Check" "ERROR" "Erreur: $_" $stopwatch.ElapsedMilliseconds
}

# 4. Vérification dashboard SLO
$stopwatch.Restart()
try {
  $sloScript = ".\scripts\next10\Monitor-SLO.ps1"
  if (Test-Path $sloScript) {
    & $sloScript -CheckOnly
    $sloExitCode = $LASTEXITCODE
    if ($sloExitCode -eq 0) {
      Add-TaskResult "SLO Check" "SUCCESS" "Tous les SLO respectés" $stopwatch.ElapsedMilliseconds
    } elseif ($sloExitCode -eq 2) {
      Add-TaskResult "SLO Check" "WARNING" "Violations SLO détectées (voir logs)" $stopwatch.ElapsedMilliseconds
    } else {
      Add-TaskResult "SLO Check" "ERROR" "Erreur lors de la vérification SLO" $stopwatch.ElapsedMilliseconds
    }
  } else {
    Add-TaskResult "SLO Check" "SKIPPED" "Script non trouvé: $sloScript" $stopwatch.ElapsedMilliseconds
  }
} catch {
  Add-TaskResult "SLO Check" "ERROR" "Erreur: $_" $stopwatch.ElapsedMilliseconds
}

# 5. Nettoyage des logs anciens (>30 jours)
$stopwatch.Restart()
try {
  $logsPath = "$env:APPDATA\USB Video Vault\logs"
  if (Test-Path $logsPath) {
    $cutoff = (Get-Date).AddDays(-30)
    $oldLogs = Get-ChildItem $logsPath -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoff }
    if ($oldLogs) {
      if (-not $DryRun) {
        $oldLogs | Remove-Item -Force
      }
      Add-TaskResult "Log Cleanup" "SUCCESS" "$(if($DryRun){'Simulation: '}else{''})$($oldLogs.Count) anciens logs supprimes" $stopwatch.ElapsedMilliseconds
    } else {
      Add-TaskResult "Log Cleanup" "SUCCESS" "Aucun ancien log à nettoyer" $stopwatch.ElapsedMilliseconds
    }
  } else {
    Add-TaskResult "Log Cleanup" "SKIPPED" "Dossier logs non trouvé: $logsPath" $stopwatch.ElapsedMilliseconds
  }
} catch {
  Add-TaskResult "Log Cleanup" "ERROR" "Erreur: $_" $stopwatch.ElapsedMilliseconds
}

# Résumé
$results.summary = @{
  totalTasks = $results.tasks.Count
  successful = ($results.tasks | Where-Object { $_.status -eq "SUCCESS" }).Count
  warnings = ($results.tasks | Where-Object { $_.status -eq "WARNING" }).Count
  errors = ($results.tasks | Where-Object { $_.status -eq "ERROR" }).Count
  skipped = ($results.tasks | Where-Object { $_.status -eq "SKIPPED" }).Count
}

Write-Host ""
Write-Host "Resume de la routine hebdomadaire:" -ForegroundColor Cyan
Write-Host "  [OK] Succes: $($results.summary.successful)" -ForegroundColor Green
Write-Host "  [WARN] Avertissements: $($results.summary.warnings)" -ForegroundColor Yellow
Write-Host "  [ERR] Erreurs: $($results.summary.errors)" -ForegroundColor Red
Write-Host "  [SKIP] Ignorees: $($results.summary.skipped)" -ForegroundColor Gray

# Sauvegarde du rapport
$results | ConvertTo-Json -Depth 3 | Out-File -Encoding UTF8 $reportFile
Write-Host "Rapport detaille: $reportFile" -ForegroundColor Cyan

if ($results.summary.errors -gt 0) {
  Write-Host "Des erreurs ont ete detectees, consultez le rapport" -ForegroundColor Red
  exit 1
} elseif ($results.summary.warnings -gt 0) {
  Write-Host "Des avertissements ont ete emis, consultez le rapport" -ForegroundColor Yellow
  exit 2
} else {
  Write-Host "Routine hebdomadaire terminee avec succes" -ForegroundColor Green
  exit 0
}