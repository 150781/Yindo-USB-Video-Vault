param(
  [Parameter()][string]$Csv = ".\operations\renewals.csv", # licenseId,fingerprint,usbSerial,exp,client
  [Parameter()][string]$CanaryFile = ".\out\kid-canary.json",
  [Parameter()][string]$OutDir = ".\deliveries\renewals",
  [Parameter()][string]$MakeScript = ".\scripts\make-license.mjs"
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$items = Import-Csv $Csv
if(-not $items){ throw "renewals.csv vide" }

$canarySet=@{}
if(Test-Path $CanaryFile){
  $c = Get-Content $CanaryFile | ConvertFrom-Json
  foreach($x in $c.selected){ $canarySet[$x.licenseId]=$true }
}

$results=@()
foreach($row in $items){
  $env:PACKAGER_KID = if($canarySet.ContainsKey($row.licenseId)){"2"}else{$null}
  $args = @($row.fingerprint)
  if($row.usbSerial){ $args += $row.usbSerial }
  $output = & node $MakeScript @args 2>&1
  $code = $LASTEXITCODE
  if($code -eq 0 -and (Test-Path ".\license.bin")){
    $dest = Join-Path $OutDir "$($row.licenseId)-license.bin"
    Move-Item ".\license.bin" $dest -Force
    $results += [pscustomobject]@{ licenseId=$row.licenseId; status="OK"; file=$dest; kid=$env:PACKAGER_KID; log=$output }
  } else {
    $results += [pscustomobject]@{ licenseId=$row.licenseId; status="FAIL"; file=$null; kid=$env:PACKAGER_KID; log=$output }
  }
  Remove-Item Env:\PACKAGER_KID -ErrorAction SilentlyContinue
}
$report = [pscustomobject]@{
  generatedAt = (Get-Date)
  source = (Resolve-Path $Csv).Path
  results = $results
}
$reportPath = ".\out\renewals-report.json"
$report | ConvertTo-Json -Depth 4 | Out-File -Encoding UTF8 $reportPath
Write-Host "Renouvellements traités. Rapport → $reportPath" -ForegroundColor Green

if(($results | Where-Object status -ne 'OK').Count -gt 0){ exit 2 } else { exit 0 }