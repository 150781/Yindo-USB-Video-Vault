param(
  [Parameter()][string]$DashboardPath = "C:\ProgramData\USBVideoVault\exec-dashboard.html",
  [Parameter()][string]$BundleOut = ".\bundles",
  [Parameter()][switch]$CheckOnly,
  [Parameter()][double]$CrashThreshold = 0.5,
  [Parameter()][double]$LicenseThreshold = 1.0,
  [Parameter()][double]$RamThreshold = 150.0,
  [Parameter()][double]$StartupThreshold = 3.0
)

$ErrorActionPreference = 'Stop'

Write-Host "SLO Monitor - Verification des seuils critiques" -ForegroundColor Cyan
Write-Host "Dashboard: $DashboardPath" -ForegroundColor Yellow

if (-not (Test-Path $DashboardPath)) {
  Write-Warning "Dashboard non trouve: $DashboardPath"
  Write-Host "Generez-le d'abord avec: .\scripts\next10\New-ExecDashboard.ps1" -ForegroundColor Yellow
  exit 1
}

# Parse le dashboard HTML pour extraire les métriques
$html = Get-Content $DashboardPath -Raw
$violations = @()

# Crash Rate
if ($html -match 'Crash Rate.*?(\d+(?:\.\d+)?)\s*%') {
  $crashRate = [double]$matches[1]
  Write-Host "Crash Rate: $crashRate% (seuil: $CrashThreshold%)" -ForegroundColor $(if($crashRate -le $CrashThreshold){"Green"}else{"Red"})
  if ($crashRate -gt $CrashThreshold) {
    $violations += "CRASH_RATE: $crashRate% > $CrashThreshold%"
  }
}

# License Errors
if ($html -match 'Erreurs Licence.*?(\d+(?:\.\d+)?)\s*%') {
  $licenseRate = [double]$matches[1]
  Write-Host "Erreurs Licence: $licenseRate% (seuil: $LicenseThreshold%)" -ForegroundColor $(if($licenseRate -le $LicenseThreshold){"Green"}else{"Red"})
  if ($licenseRate -gt $LicenseThreshold) {
    $violations += "LICENSE_ERROR: $licenseRate% > $LicenseThreshold%"
  }
}

# RAM P95
if ($html -match 'RAM P95.*?(\d+(?:\.\d+)?)\s*MB') {
  $ramP95 = [double]$matches[1]
  Write-Host "RAM P95: $ramP95 MB (seuil: $RamThreshold MB)" -ForegroundColor $(if($ramP95 -le $RamThreshold){"Green"}else{"Red"})
  if ($ramP95 -gt $RamThreshold) {
    $violations += "RAM_P95: $ramP95 MB > $RamThreshold MB"
  }
}

# Startup P95
if ($html -match 'Startup P95.*?(\d+(?:\.\d+)?)\s*s') {
  $startupP95 = [double]$matches[1]
  Write-Host "Startup P95: $startupP95s (seuil: $StartupThreshold s)" -ForegroundColor $(if($startupP95 -le $StartupThreshold){"Green"}else{"Red"})
  if ($startupP95 -gt $StartupThreshold) {
    $violations += "STARTUP_P95: $startupP95s > $StartupThreshold s"
  }
}

if ($violations.Count -eq 0) {
  Write-Host "Tous les SLO sont respectes" -ForegroundColor Green
  exit 0
}

Write-Host "$($violations.Count) violation(s) SLO detectee(s):" -ForegroundColor Red
$violations | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }

if ($CheckOnly) {
  Write-Host "Mode CheckOnly: pas de collecte de bundle" -ForegroundColor Cyan
  exit 2
}

# Collecte d'un bundle pour investigation
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundlePath = Join-Path $BundleOut "slo-violation-$timestamp.zip"
$null = New-Item -ItemType Directory -Path $BundleOut -Force -ErrorAction SilentlyContinue

Write-Host "Collecte du bundle d'investigation..." -ForegroundColor Cyan

try {
  # Réutilise le script de support pack existant
  $supportScript = ".\scripts\next10\New-SupportPack.ps1"
  if (Test-Path $supportScript) {
    & $supportScript -TicketNumber "SLO-$timestamp" -OutDir $BundleOut
    Write-Host "Bundle collecte: consultez $BundleOut" -ForegroundColor Green
  } else {
    Write-Warning "Script de support pack non trouvé: $supportScript"
  }
  
  # Log de l'incident
  $incidentLog = ".\out\slo-incidents.log"
  $null = New-Item -ItemType Directory -Path (Split-Path $incidentLog) -Force -ErrorAction SilentlyContinue
  "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SLO_VIOLATION | $($violations -join ' | ')" | Out-File -Append -Encoding UTF8 $incidentLog
  
  Write-Host "Incident logge dans: $incidentLog" -ForegroundColor Cyan
  
} catch {
  Write-Error "Erreur lors de la collecte: $_"
}

exit 2