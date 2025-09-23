param(
  [Parameter()][string]$LogsPath = "$env:APPDATA\USB Video Vault\logs",
  [Parameter()][string]$OutFile = ".\out\exec-dashboard.html",
  [Parameter()][int]$LookbackHours = 48
)

$ErrorActionPreference = 'Stop'

# S'assurer que le dossier de sortie existe (et gérer les chemins relatifs sans parent explicite)
$parent = Split-Path -Parent $OutFile
if ([string]::IsNullOrWhiteSpace($parent)) {
  $parent = "."
}
New-Item -ItemType Directory -Force -Path $parent | Out-Null

function Get-P95 {
  param([double[]]$Values)
  if(-not $Values -or $Values.Count -eq 0){ return 0 }
  $sorted = $Values | Sort-Object
  $idx = [math]::Floor(0.95*($sorted.Count-1))
  return [math]::Round($sorted[$idx],2)
}

# 1) Lire logs récents (main.log* rotatés)
$cut = (Get-Date).AddHours(-$LookbackHours)
$files = Get-ChildItem -Path $LogsPath -Filter "main*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime

# IMPORTANT : pas de pipe directement après foreach (sinon "élément de canal vide")
$lines = @()
foreach($f in $files){
  try {
    $lines += Get-Content $f.FullName -ErrorAction SilentlyContinue
  } catch { }
}

# Si aucun log, on produit quand même un dashboard neutre
if(-not $lines){ 
  $totalLaunch = 0; $crash = 0; $licErr = 0
  $startupTimes = @(); $ramSamples = @()
} else {
  $lines = $lines | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}' }
  $recent = $lines | Where-Object { ($_ -split '\s+')[0] -as [datetime] -ge $cut }

  # 2) Métriques
  $totalLaunch = ($recent | Select-String -SimpleMatch "App start").Count
  $crash = ($recent | Select-String -SimpleMatch "CRASH").Count
  $licErr = ($recent | Select-String -Pattern "Signature de licence invalide|Licence expirée|Anti-rollback").Count

  $startupTimes = @()
  ($recent | Select-String -Pattern "StartupSeconds=(\d+(\.\d+)?)" -AllMatches) | ForEach-Object {
    foreach($m in $_.Matches){ $startupTimes += [double]$m.Groups[1].Value }
  }

  $ramSamples = @()
  ($recent | Select-String -Pattern "RAM_MB=(\d+(\.\d+)?)" -AllMatches) | ForEach-Object {
    foreach($m in $_.Matches){ $ramSamples += [double]$m.Groups[1].Value }
  }
}

$crashRate = if($totalLaunch){ [math]::Round(100*$crash/[double]$totalLaunch,2) } else { 0 }
$licRate   = if($totalLaunch){ [math]::Round(100*$licErr/[double]$totalLaunch,2) } else { 0 }
$p95Start  = Get-P95 $startupTimes
$p95Ram    = Get-P95 $ramSamples

# 3) HTML (léger)
$html = @"
<!doctype html><html><head><meta charset="utf-8"><title>USB Video Vault - Exec Dashboard</title>
<style>body{font-family:Segoe UI,Arial;margin:24px} .kpi{display:inline-block;width:22%;margin:1%;padding:18px;border-radius:14px;box-shadow:0 2px 10px rgba(0,0,0,.08)}
h1{margin:0 0 16px 0} .lbl{color:#666;font-size:12px;text-transform:uppercase;letter-spacing:.08em} .val{font-size:28px;margin-top:6px}
.good{background:#f0fff4} .warn{background:#fffaf0} .bad{background:#fff5f5}</style></head><body>
<h1>USB Video Vault — Exec Dashboard (Dernières $LookbackHours h)</h1>
<div class="kpi $(if($crashRate -lt 0.5){"good"}elseif($crashRate -lt 1){"warn"}else{"bad"})">
  <div class="lbl">Crash Rate</div><div class="val">$crashRate %</div>
</div>
<div class="kpi $(if($licRate -lt 1){"good"}elseif($licRate -lt 2){"warn"}else{"bad"})">
  <div class="lbl">Erreurs Licence</div><div class="val">$licRate %</div>
</div>
<div class="kpi $(if($p95Ram -lt 150){"good"}elseif($p95Ram -lt 180){"warn"}else{"bad"})">
  <div class="lbl">RAM P95</div><div class="val">$p95Ram MB</div>
</div>
<div class="kpi $(if($p95Start -lt 3){"good"}elseif($p95Start -lt 5){"warn"}else{"bad"})">
  <div class="lbl">Startup P95</div><div class="val">$p95Start s</div>
</div>
<p style="color:#666;margin-top:24px">Sources: $LogsPath — Généré le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
</body></html>
"@

$html | Out-File -Encoding UTF8 -FilePath $OutFile
Write-Host "Dashboard généré → $OutFile" -ForegroundColor Green
exit 0