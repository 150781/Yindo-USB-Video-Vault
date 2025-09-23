param(
  [Parameter()][string]$CveReport = ".\releases\v1.0.4\cve-report.json",
  [Parameter()][string]$Waivers = ".\security\cve-waivers.json" # { "waived": ["CVE-2025-XXXX", ...] }
)
$ErrorActionPreference='Stop'
if(-not (Test-Path $CveReport)){ throw "Rapport CVE introuvable: $CveReport" }
$v = Get-Content $CveReport | ConvertFrom-Json
$waived=@{}
if(Test-Path $Waivers){ (Get-Content $Waivers | ConvertFrom-Json).waived | ForEach-Object { $waived[$_]=$true } }

$crit = @()
foreach($c in $v.vulnerabilities){
  $id=$c.id; $sev=$c.severity
  if($sev -match 'CRITICAL' -and -not $waived.ContainsKey($id)){ $crit += $id }
}
if($crit.Count -gt 0){
  Write-Error "CVE critiques non waivées: $($crit -join ', ')"
  exit 3
}
Write-Host "SBOM Gate OK (aucune CVE critique non waivée)" -ForegroundColor Green
exit 0