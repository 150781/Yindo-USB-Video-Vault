param(
  [Parameter()][ValidateRange(1,100)][int]$Percent = 10,
  [Parameter()][string]$PopulationFile = ".\deliveries\ring1-population.csv", # colonnes: licenseId,client,machine
  [Parameter()][string]$OutFile = ".\out\kid-canary.json",
  [Parameter()][int]$Seed = 42
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null
if(-not (Test-Path $PopulationFile)){ throw "Population introuvable: $PopulationFile" }

# Lecture CSV
$rows = Import-Csv $PopulationFile
if(-not $rows){ throw "Population vide" }

# Shuffle déterministe
$rand = New-Object System.Random($Seed)
$shuffled = $rows | Sort-Object { $rand.Next() }
$take = [math]::Ceiling($shuffled.Count * ($Percent/100))
$canary = $shuffled | Select-Object -First $take

$payload = [pscustomobject]@{
  kid = 2
  percent = $Percent
  total = $rows.Count
  selected = $canary
  generatedAt = (Get-Date)
}
$payload | ConvertTo-Json -Depth 4 | Out-File -Encoding UTF8 $OutFile
Write-Host "Canari KID=2 → $Percent% sélectionnés (${take}/$($rows.Count)) → $OutFile" -ForegroundColor Green
exit 0