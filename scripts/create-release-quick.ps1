param(
  [Parameter(Mandatory=$true)][string]$Version,
  [string]$TimestampUrl = "http://timestamp.digicert.com",
  [string]$CertThumbprint,
  [string]$CertPath,
  [System.Security.SecureString]$CertPassword
)

$ErrorActionPreference = "Stop"

function Write-Log { param([string]$m,[string]$l="INFO")
  $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $c = switch($l){"ERROR"{"Red"}"WARN"{"Yellow"}"OK"{"Green"}default{"White"}}
  Write-Host "[$t][$l] $m" -ForegroundColor $c
}

function Resolve-Signtool {
  $candidates = @(
    "$env:ProgramFiles(x86)\Windows Kits\10\bin",
    "$env:ProgramFiles\Windows Kits\10\bin"
  ) | Where-Object { Test-Path $_ }

  $bins = foreach($root in $candidates){
    Get-ChildItem -Path $root -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue
  }
  $best = $bins | Sort-Object FullName -Descending | Select-Object -First 1
  if(-not $best){ throw "signtool.exe introuvable (installez Windows 10 SDK: App Installer 'Windows SDK Signing Tools')." }
  return $best.FullName
}

function Sign-File {
  param([string]$File,[string]$Signtool,[string]$TimestampUrl,[string]$CertThumbprint,[string]$CertPath,[string]$CertPassPlain)
  if(-not (Test-Path $File)){ throw "Fichier a signer introuvable: $File" }

  if($CertThumbprint){
    & $Signtool sign /fd SHA256 /td SHA256 /tr $TimestampUrl /sha1 $CertThumbprint $File
  } elseif($CertPath -and $CertPassPlain){
    & $Signtool sign /fd SHA256 /td SHA256 /tr $TimestampUrl /f $CertPath /p $CertPassPlain $File
  } else {
    throw "Aucun certificat fourni. Passez -CertThumbprint ou -CertPath + -CertPassword."
  }
  if($LASTEXITCODE -ne 0){ throw "Echec signature: $File" }
}

# 0) Pre-reqs
Write-Log "Version=$Version" "OK"
if(-not (Test-Path .\package.json)){ throw "package.json introuvable (lancez ce script depuis la racine du repo)." }
$node = Get-Command node -ErrorAction SilentlyContinue
if(-not $node){ throw "node non trouve. Installez Node.js 18+." }
$npm = Get-Command npm -ErrorAction SilentlyContinue
if(-not $npm){ throw "npm non trouve." }

# 1) Build (Electron Builder)
Write-Log "Installation deps (npm ci)..." "INFO"
try { npm ci --no-audit --prefer-offline } catch { npm install --no-audit }
Write-Log "Build Windows (electron-builder)..." "INFO"
npx --yes electron-builder --win nsis msi portable --publish never
if($LASTEXITCODE -ne 0){ throw "electron-builder a echoue." }

# 2) Collecte artefacts -> releases\<version>
$ReleaseDir = Join-Path -Path ".\releases" -ChildPath $Version
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
$dist = ".\dist"
$artifacts = @()
$artifacts += Get-ChildItem "$dist\*.exe" -ErrorAction SilentlyContinue
$artifacts += Get-ChildItem "$dist\*.msi" -ErrorAction SilentlyContinue
$artifacts += Get-ChildItem "$dist\*.zip" -ErrorAction SilentlyContinue
$artifacts += Get-ChildItem "$dist\*.7z" -ErrorAction SilentlyContinue
if($artifacts.Count -eq 0){ throw "Aucun artefact genere trouve dans .\dist. Verifiez electron-builder." }

foreach($f in $artifacts){
  Copy-Item $f.FullName (Join-Path $ReleaseDir $f.Name) -Force
}
Write-Log "Artefacts copies -> $ReleaseDir" "OK"

# 3) Signature + horodatage
if($CertPassword){
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertPassword)
  $CertPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)
} else {
  $CertPassPlain = $null
}
if(-not $CertThumbprint -and -not $CertPath){
  Write-Log "Avertissement: aucune signature effectuee (aucun certificat fourni)." "WARN"
} else {
  $signtool = Resolve-Signtool
  $toSign = Get-ChildItem $ReleaseDir -Include *.exe,*.msi -Recurse
  foreach($f in $toSign){
    Write-Log "Signature: $($f.Name)" "INFO"
    Sign-File -File $f.FullName -Signtool $signtool -TimestampUrl $TimestampUrl -CertThumbprint $CertThumbprint -CertPath $CertPath -CertPassPlain $CertPassPlain
  }
  Write-Log "Signature terminee." "OK"
}

# 4) SBOM (best effort)
try{
  Write-Log "Generation SBOM (CycloneDX)..." "INFO"
  npx --yes @cyclonedx/cyclonedx-npm --spec-version 1.5 --output-format json --output-file (Join-Path $ReleaseDir "sbom-$Version.json")
  Write-Log "SBOM ok." "OK"
} catch {
  Write-Log "SBOM ignore (outil non installe)." "WARN"
}

# 5) Hashes SHA256
Write-Log "Calcul des hashes..." "INFO"
$hashFile = Join-Path $ReleaseDir "SHA256-HASHES-$Version.txt"
"USB Video Vault - Hashes $Version" | Out-File $hashFile -Encoding ASCII
Get-ChildItem $ReleaseDir -File | Where-Object { $_.Extension -in ".exe",".msi",".zip",".7z" } | ForEach-Object {
  $h = Get-FileHash $_.FullName -Algorithm SHA256
  "$($h.Hash) *$($_.Name)" | Out-File $hashFile -Append -Encoding ASCII
}
Write-Log "Hashes ecrits: $(Split-Path $hashFile -Leaf)" "OK"

# 6) Rapport
Write-Log "Release $Version OK -> $ReleaseDir" "OK"
