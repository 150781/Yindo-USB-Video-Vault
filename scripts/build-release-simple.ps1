# Script de Build Release Production - Version Simple
# USB Video Vault - Build direct avec electron-builder

param(
  [Parameter(Mandatory = $false)]
  [string]$Version = "1.0.4",
  [Parameter(Mandatory = $false)]
  [string]$CertThumbprint,
  [Parameter(Mandatory = $false)]
  [switch]$SkipSigning
)

$ErrorActionPreference = "Stop"
$ReleaseDir = "releases\v$Version"

function Write-BuildLog {
  param([string]$Message, [string]$Level = "INFO")
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $color = switch ($Level) {
    "ERROR"   { "Red" }
    "WARN"    { "Yellow" }
    "SUCCESS" { "Green" }
    "STEP"    { "Cyan" }
    default   { "White" }
  }
  Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Resolve-Signtool {
  $candidates = @(
    "$env:ProgramFiles(x86)\Windows Kits\10\bin",
    "$env:ProgramFiles\Windows Kits\10\bin"
  ) | Where-Object { Test-Path $_ }

  $bins = foreach ($root in $candidates) {
    Get-ChildItem -Path $root -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue
  }
  $best = $bins | Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $best) { throw "signtool.exe introuvable" }
  return $best.FullName
}

function Sign-File {
  param([string]$File, [string]$Signtool, [string]$CertThumbprint)
  if (-not (Test-Path $File)) { throw "Fichier introuvable: $File" }
  if ($CertThumbprint) {
    & $Signtool sign /fd SHA256 /td SHA256 /tr "http://timestamp.digicert.com" /sha1 $CertThumbprint $File
    if ($LASTEXITCODE -ne 0) { throw "Echec signature: $File" }
  }
}

Write-BuildLog "=== Build Release Simple v$Version ===" "STEP"

try {
  # 1. Build main seulement (le renderer sera rebuild par electron-builder)
  Write-BuildLog "Build main process..." "STEP"
  npm run build:main
  if ($LASTEXITCODE -ne 0) { throw "Build main echoue" }

  # 2. electron-builder direct (qui va rebuilder le renderer)
  Write-BuildLog "electron-builder avec rebuild automatique..." "STEP"
  npx --yes electron-builder --win nsis portable --publish never
  if ($LASTEXITCODE -ne 0) { throw "electron-builder echoue" }

  # 3. Collection des artefacts
  Write-BuildLog "Collection artefacts..." "STEP"
  New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
  $artifacts = Get-ChildItem "dist\*.exe" -ErrorAction SilentlyContinue
  if ($artifacts.Count -eq 0) { throw "Aucun artefact trouve" }
  
  foreach ($file in $artifacts) {
    Copy-Item $file.FullName (Join-Path $ReleaseDir $file.Name) -Force
    Write-BuildLog "  + $($file.Name)" "INFO"
  }

  # 4. Signature optionnelle
  if (-not $SkipSigning -and $CertThumbprint) {
    Write-BuildLog "Signature..." "STEP"
    $signtool = Resolve-Signtool
    $toSign = Get-ChildItem $ReleaseDir -Include "*.exe" -Recurse
    foreach ($file in $toSign) {
      Sign-File -File $file.FullName -Signtool $signtool -CertThumbprint $CertThumbprint
      Write-BuildLog "  Signe: $($file.Name)" "SUCCESS"
    }
  }

  # 5. Hashes
  Write-BuildLog "Hashes SHA256..." "STEP"
  $hashFile = Join-Path $ReleaseDir "SHA256-HASHES-$Version.txt"
  Get-ChildItem $ReleaseDir -File -Include "*.exe" | ForEach-Object {
    $h = Get-FileHash $_.FullName -Algorithm SHA256
    "$($h.Hash) *$($_.Name)" | Out-File $hashFile -Append -Encoding ASCII
  }

  Write-BuildLog "Build termine avec succes!" "SUCCESS"
  Write-BuildLog "Artefacts dans: $ReleaseDir" "SUCCESS"
}
catch {
  Write-BuildLog "Build echoue: $_" "ERROR"
  exit 1
}