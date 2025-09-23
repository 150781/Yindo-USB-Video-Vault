param(
  [Parameter()][string]$LogsPath = "$env:APPDATA\USB Video Vault\logs",
  [Parameter()][switch]$Continuous,
  [Parameter()][int]$ThresholdMinutes = 5
)

$ErrorActionPreference = 'Stop'

Write-Host "USBVault Live Monitor - Surveillance en temps reel" -ForegroundColor Cyan
Write-Host "Logs: $LogsPath" -ForegroundColor Yellow
Write-Host "Mode: $(if($Continuous){"Continu (Ctrl+C pour arrêter)"}else{"Une seule passe"})" -ForegroundColor Yellow

$logFile = Join-Path $LogsPath "main.log"
if (-not (Test-Path $logFile)) {
  Write-Warning "Aucun fichier de log trouvé: $logFile"
  exit 1
}

$patterns = @(
  "CRASH",
  "Signature de licence invalide",
  "Licence expirée", 
  "Anti-rollback",
  "FATAL",
  "ERROR.*License",
  "StartupSeconds=[5-9]\d+",  # Startup > 50s
  "RAM_MB=[2-9]\d{2}"         # RAM > 200MB
)

$alertCount = 0
$startTime = Get-Date

function Write-Alert {
  param($Line, $Pattern)
  $script:alertCount++
  $timestamp = Get-Date -Format "HH:mm:ss"
  Write-Host "[ALERT] [$timestamp] ALERTE #$alertCount" -ForegroundColor Red
  Write-Host "Pattern: $Pattern" -ForegroundColor Yellow
  Write-Host "Log: $Line" -ForegroundColor White
  Write-Host ""
  
  # Optionnel: log dans un fichier d'alertes
  $alertLog = ".\out\live-alerts.log"
  $null = New-Item -ItemType Directory -Path (Split-Path $alertLog) -Force -ErrorAction SilentlyContinue
  "[$timestamp] $Pattern | $Line" | Out-File -Append -Encoding UTF8 $alertLog
}

if ($Continuous) {
  Write-Host "Démarrage surveillance continue..." -ForegroundColor Green
  Write-Host "Patterns surveillés:" -ForegroundColor Cyan
  $patterns | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
  Write-Host ""
  
  try {
    Get-Content $logFile -Tail 0 -Wait | ForEach-Object {
      $line = $_
      foreach ($pattern in $patterns) {
        if ($line -match $pattern) {
          Write-Alert $line $pattern
          break
        }
      }
    }
  } catch {
    Write-Host "Surveillance interrompue: $_" -ForegroundColor Red
  }
} else {
  # Mode one-shot: analyse des dernières N minutes
  Write-Host "Analyse des dernières $ThresholdMinutes minutes..." -ForegroundColor Green
  $cutoff = (Get-Date).AddMinutes(-$ThresholdMinutes)
  
  $lines = Get-Content $logFile -ErrorAction SilentlyContinue | Where-Object {
    $_ -match '^\d{4}-\d{2}-\d{2}' -and 
    ($_ -split '\s+')[0] -as [datetime] -ge $cutoff
  }
  
  foreach ($line in $lines) {
    foreach ($pattern in $patterns) {
      if ($line -match $pattern) {
        Write-Alert $line $pattern
        break
      }
    }
  }
  
  if ($alertCount -eq 0) {
    Write-Host "Aucune alerte dans les dernieres $ThresholdMinutes minutes" -ForegroundColor Green
  } else {
    Write-Host "Total: $alertCount alertes detectees" -ForegroundColor Yellow
  }
}