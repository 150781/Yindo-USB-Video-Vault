param(
  [Parameter()][string]$LogsPath = "$env:APPDATA\USB Video Vault\logs",
  [Parameter()][int]$WindowHours = 24,
  [Parameter()][int]$Threshold = 3,
  [Parameter()][string]$OutFile = ".\out\abuse-alerts.json"
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null
$cut=(Get-Date).AddHours(-$WindowHours)

$files = Get-ChildItem $LogsPath -Filter "main*.log" -ErrorAction SilentlyContinue
$lines = foreach($f in $files){ Get-Content $f -ErrorAction SilentlyContinue }
$recent = $lines | Where-Object { ($_ -split '\s+')[0] -as [datetime] -ge $cut }

# Attendu dans les logs: "Signature de licence invalide (licenseId=XXX)"
$hits = $recent | Select-String -Pattern 'Signature de licence invalide .*licenseId=([\w\-\.:]+)' -AllMatches
$counts=@{}
foreach($m in $hits){ foreach($g in $m.Matches){ $id=$g.Groups[1].Value; $counts[$id]=1+($counts[$id]); } }

$alerts=@()
foreach($k in $counts.Keys){
  if($counts[$k] -ge $Threshold){ $alerts += [pscustomobject]@{ licenseId=$k; count=$counts[$k]; windowHours=$WindowHours } }
}

$payload=[pscustomobject]@{ generatedAt=Get-Date; threshold=$Threshold; alerts=$alerts }
$payload | ConvertTo-Json -Depth 3 | Out-File -Encoding UTF8 $OutFile
if($alerts.Count -gt 0){
  Write-Host "ALERTE: abus potentiels → $OutFile" -ForegroundColor Yellow
  exit 4
}else{
  Write-Host "Aucune alerte d'abus" -ForegroundColor Green
  exit 0
}