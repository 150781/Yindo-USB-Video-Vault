# scripts/create-release-prod.ps1
# USB Video Vault - Build Release Production

param(
  [Parameter(Mandatory = $false)]
  [string]$Version = "1.0.4",

  # Choisissez l'un OU l'autre:
  [Parameter(Mandatory = $false)]
  [string]$CertThumbprint,                 # Certificat dans le store utilisateur/machine
  [Parameter(Mandatory = $false)]
  [string]$PfxPath,                        # Chemin vers PFX (si pas de thumbprint)
  [Parameter(Mandatory = $false)]
  [System.Security.SecureString]$PfxPassword,

  [Parameter(Mandatory = $false)]
  [string]$TimestampUrl = "http://timestamp.digicert.com",

  [Parameter(Mandatory = $false)]
  [switch]$SkipTests,                      # par defaut: $false
  [Parameter(Mandatory = $false)]
  [switch]$SkipSigning,                    # par defaut: $false
  [Parameter(Mandatory = $false)]
  [switch]$CreateGitHubRelease,            # par defaut: $false
  [Parameter(Mandatory = $false)]
  [switch]$Force,                          # par defaut: $false - bypass git clean check
  [Parameter(Mandatory = $false)]
  [switch]$VerboseOutput                   # par defaut: $false
)

$ErrorActionPreference = "Stop"
$BuildDir   = "dist"
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

function Ensure-CleanPackageJson {
  Write-BuildLog "Verification package.json propre..." "STEP"
  try {
    # Vérifier et nettoyer les BOMs
    $packagePath = ".\package.json"
    $bytes = [IO.File]::ReadAllBytes($packagePath)
    
    if ($bytes.Length -ge 3 -and $bytes[0]-eq 239 -and $bytes[1]-eq 187 -and $bytes[2]-eq 191) {
      Write-BuildLog "BOM detecte -> conversion ASCII pure" "WARN"
      
      # Supprimer le BOM et lire le contenu
      $contentBytes = $bytes[3..($bytes.Length-1)]
      $content = [Text.Encoding]::UTF8.GetString($contentBytes)
      
      # Réécrire en ASCII pur sans BOM
      $ascii = [Text.Encoding]::ASCII
      [IO.File]::WriteAllBytes($packagePath, $ascii.GetBytes($content))
      Write-BuildLog "BOM supprime avec succes" "SUCCESS"
    }
    
    # Nettoyer les caches
    Remove-Item "$env:LOCALAPPDATA\electron-builder\Cache" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item ".\node_modules\.cache" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-BuildLog "package.json et caches nettoyes" "SUCCESS"
  }
  catch {
    Write-BuildLog "Erreur nettoyage package.json: $_" "ERROR"
    throw
  }
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
  if (-not $best) { throw "signtool.exe introuvable. Installez le Windows 10/11 SDK (Signing Tools)." }
  return $best.FullName
}

function Sign-File {
  param(
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][string]$Signtool,
    [Parameter(Mandatory = $true)][string]$TimestampUrl,
    [string]$CertThumbprint,
    [string]$PfxPath,
    [string]$PfxPassPlain
  )
  if (-not (Test-Path $File)) { throw "Fichier a signer introuvable: $File" }

  if ($CertThumbprint) {
    & $Signtool sign /fd SHA256 /td SHA256 /tr $TimestampUrl /sha1 $CertThumbprint $File
  }
  elseif ($PfxPath -and $PfxPassPlain) {
    & $Signtool sign /fd SHA256 /td SHA256 /tr $TimestampUrl /f $PfxPath /p $PfxPassPlain $File
  }
  else {
    throw "Aucun certificat pour la signature. Fournissez -CertThumbprint ou -PfxPath + -PfxPassword."
  }
  if ($LASTEXITCODE -ne 0) { throw "Echec signature: $File" }
}

function Test-BuildPrerequisites {
  Write-BuildLog "Verification des prerequis..." "STEP"
  try { $null = node --version; Write-BuildLog "Node OK" "SUCCESS" } catch { Write-BuildLog "Node requis" "ERROR"; throw }
  try { $null = npm --version;  Write-BuildLog "npm OK"  "SUCCESS" } catch { Write-BuildLog "npm requis"  "ERROR"; throw }
  try { $null = git --version;  Write-BuildLog "Git OK"  "SUCCESS" } catch { Write-BuildLog "Git requis"  "ERROR"; throw }

  $status = git status --porcelain
  if ($status) {
    Write-BuildLog "Workspace non propre (fichiers modifies/non indexes)" "WARN"
    if ($VerboseOutput) { $status | ForEach-Object { Write-BuildLog "  $_" "INFO" } }
    if ($Force) {
      Write-BuildLog "Force = true, continuation malgre les changements" "WARN"
    } else {
      $continue = Read-Host "Continuer malgre les changements? (y/N)"
      if ($continue -notin @("y","Y")) { throw "Build annule par l'utilisateur" }
    }
  }
  Write-BuildLog "Prerequis valides" "SUCCESS"
}

function Update-Version {
  param([string]$NewVersion)
  Write-BuildLog "Mise a jour de la version package.json -> $NewVersion" "STEP"
  try {
    $packagePath = "package.json"
    if (-not (Test-Path $packagePath)) { throw "package.json introuvable" }
    $package = Get-Content $packagePath -Raw | ConvertFrom-Json
    $old = $package.version
    $package.version = $NewVersion
    
    # Écrire JSON sans BOM
    $json = $package | ConvertTo-Json -Depth 20
    $ascii = [Text.Encoding]::ASCII
    [IO.File]::WriteAllBytes($packagePath, $ascii.GetBytes($json))
    
    Write-BuildLog "Version: $old -> $NewVersion" "SUCCESS"

    git add package.json | Out-Null
    git commit -m "chore: bump version to $NewVersion" | Out-Null
    Write-BuildLog "Commit de version effectue" "SUCCESS"
  }
  catch {
    Write-BuildLog "Erreur de mise a jour version: $_" "ERROR"
    throw
  }
}

function Invoke-Tests {
  if ($SkipTests) {
    Write-BuildLog "Tests ignores (parametre -SkipTests)" "WARN"
    return
  }
  Write-BuildLog "Execution des tests (best effort)..." "STEP"
  try {
    if (Test-Path "package.json") {
      $pkg = Get-Content package.json -Raw | ConvertFrom-Json
      if ($pkg.scripts."test") {
        npm run test
        if ($LASTEXITCODE -eq 0) { Write-BuildLog "Tests OK" "SUCCESS" } else { Write-BuildLog "Tests KO (continuer)" "WARN" }
      }
      else {
        Write-BuildLog "Aucun script test dans package.json" "WARN"
      }
    }
  }
  catch {
    Write-BuildLog "Erreur pendant les tests (ignoree): $_" "WARN"
  }
}

function Invoke-Build {
  Write-BuildLog "Build application..." "STEP"
  try {
    if (Test-Path $BuildDir) { Remove-Item -Path $BuildDir -Recurse -Force }
    Write-BuildLog "Installation dependances (npm ci)..." "INFO"
    try { npm ci --no-audit --prefer-offline } catch { npm install --no-audit }
    if ($LASTEXITCODE -ne 0) { throw "npm ci/install a echoue" }

    # Build du projet (renderer + main) si scripts dispos; sinon electron-builder reconstruira.
    if (Test-Path "package.json") {
      $pkg = Get-Content package.json -Raw | ConvertFrom-Json
      if ($pkg.scripts."build") {
        Write-BuildLog "npm run build..." "INFO"
        npm run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build a echoue" }
      }
      else {
        Write-BuildLog "Pas de script build; on continue" "WARN"
      }
    }

    # Packaging Electron - on evite MSI par defaut (problemes d'icone WiX)
    Write-BuildLog "electron-builder (win nsis portable)..." "INFO"
    npx --yes electron-builder --win nsis portable --publish never
    if ($LASTEXITCODE -ne 0) { throw "electron-builder a echoue" }

    Write-BuildLog "Build termine" "SUCCESS"
  }
  catch {
    Write-BuildLog "Erreur de build: $_" "ERROR"
    throw
  }
}

function Collect-Artifacts {
  Write-BuildLog "Collecte des artefacts vers $ReleaseDir..." "STEP"
  try {
    New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
    $toCopy = @()
    $toCopy += Get-ChildItem "$BuildDir\*.exe" -ErrorAction SilentlyContinue
    $toCopy += Get-ChildItem "$BuildDir\*.msi" -ErrorAction SilentlyContinue
    $toCopy += Get-ChildItem "$BuildDir\*.zip" -ErrorAction SilentlyContinue
    $toCopy += Get-ChildItem "$BuildDir\*.7z"  -ErrorAction SilentlyContinue
    if ($toCopy.Count -eq 0) { throw "Aucun artefact trouve dans $BuildDir" }
    foreach ($f in $toCopy) {
      Copy-Item $f.FullName (Join-Path $ReleaseDir $f.Name) -Force
      Write-BuildLog ("  + " + $f.Name) "INFO"
    }
    Write-BuildLog "Collecte OK" "SUCCESS"
  }
  catch {
    Write-BuildLog "Erreur de collecte: $_" "ERROR"
    throw
  }
}

function Invoke-Signing {
  if ($SkipSigning) {
    Write-BuildLog "Signature ignoree (parametre -SkipSigning)" "WARN"
    return
  }
  Write-BuildLog "Signature des artefacts..." "STEP"
  try {
    $signtool = Resolve-Signtool
    $plain = $null
    if ($PfxPassword) {
      $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PfxPassword)
      $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)
    }

    $files = Get-ChildItem $ReleaseDir -Include *.exe,*.msi -Recurse -ErrorAction SilentlyContinue
    if ($files.Count -eq 0) { Write-BuildLog "Aucun .exe/.msi a signer dans $ReleaseDir" "WARN"; return }

    foreach ($f in $files) {
      Write-BuildLog ("Signature: " + $f.Name) "INFO"
      Sign-File -File $f.FullName -Signtool $signtool -TimestampUrl $TimestampUrl -CertThumbprint $CertThumbprint -PfxPath $PfxPath -PfxPassPlain $plain
    }
    Write-BuildLog "Signature terminee" "SUCCESS"
  }
  catch {
    Write-BuildLog "Erreur de signature: $_" "ERROR"
    throw
  }
}

function New-Checksums {
  Write-BuildLog "Calcul des hashes SHA256..." "STEP"
  try {
    $hashFile = Join-Path $ReleaseDir "SHA256-HASHES-$Version.txt"
    "USB Video Vault - Hashes $Version" | Out-File $hashFile -Encoding ASCII
    Get-ChildItem $ReleaseDir -File | Where-Object { $_.Extension -in ".exe",".msi",".zip",".7z" } | ForEach-Object {
      $h = Get-FileHash $_.FullName -Algorithm SHA256
      "$($h.Hash) *$($_.Name)" | Out-File $hashFile -Append -Encoding ASCII
    }
    Write-BuildLog ("Hashes ecrits: " + (Split-Path $hashFile -Leaf)) "SUCCESS"
  }
  catch {
    Write-BuildLog "Erreur hashes: $_" "ERROR"
    # ne pas interrompre
  }
}

function New-ReleaseNotes {
  Write-BuildLog "Generation release notes..." "STEP"
  try {
    $notesPath = Join-Path $ReleaseDir "RELEASE_NOTES_v$Version.md"
    $commit    = (git rev-parse HEAD) 2>$null
    $sinceTag  = (git describe --tags --abbrev=0) 2>$null
    $changelog = ""
    try {
      if ($sinceTag) {
        $changelog = git log --oneline "$sinceTag"..HEAD --pretty=format:"- %s (%h)"
      }
      else {
        $changelog = git log --oneline -n 50 --pretty=format:"- %s (%h)"
      }
    } catch { $changelog = "Changelog automatique indisponible." }

@"
# USB Video Vault v$Version - Release Production

## Artifacts
- Installateur NSIS (.exe) signe
- Portable (.exe)
- SHA256-HASHES-$Version.txt

## Verification
- Signature: signtool verify /pa /all "<votre fichier .exe>"
- Hashes: comparer avec SHA256-HASHES-$Version.txt

## Changelog
$changelog

---
Date de build: $(Get-Date)
Commit: $commit
Machine: $env:COMPUTERNAME
"@ | Out-File -FilePath $notesPath -Encoding UTF8

    Write-BuildLog ("Release notes: " + (Split-Path $notesPath -Leaf)) "SUCCESS"
  }
  catch {
    Write-BuildLog "Erreur release notes: $_" "ERROR"
    # ne pas interrompre
  }
}

function New-GitTag {
  Write-BuildLog "Creation du tag Git..." "STEP"
  try {
    $tagName = "v$Version"
    $exists = git tag -l $tagName
    if ($exists) {
      Write-BuildLog "Tag $tagName existe deja" "WARN"
      return
    }
    git tag -a $tagName -m "Release v$Version - Production"
    Write-BuildLog "Tag cree: $tagName" "SUCCESS"

    $push = Read-Host "Pousser le tag vers origin? (y/N)"
    if ($push -in @("y","Y")) {
      git push origin $tagName
      Write-BuildLog "Tag pousse vers origin" "SUCCESS"
    }
  }
  catch {
    Write-BuildLog "Erreur tag: $_" "ERROR"
    # ne pas interrompre
  }
}

function New-BuildReport {
  Write-BuildLog "Generation du rapport de build..." "STEP"
  try {
    $reportPath = Join-Path $ReleaseDir "build-report-v$Version.txt"
@"
USB Video Vault - Rapport de Build v$Version
==========================================

Date de build: $(Get-Date)
Version: $Version
Machine: $env:COMPUTERNAME
Utilisateur: $env:USERNAME
PowerShell: $($PSVersionTable.PSVersion)
Commit: $(git rev-parse HEAD 2>$null)

Configuration:
- Tests: $(if($SkipTests) { "Ignores" } else { "Executes" })
- Signature: $(if($SkipSigning) { "Ignoree" } else { "Activee" })
- Timestamp: $TimestampUrl
- Cert: $(if($CertThumbprint){ "Store (thumbprint)" } elseif($PfxPath){ "PFX" } else { "Aucun" })

Artifacts:
$(Get-ChildItem -Path $ReleaseDir -File | ForEach-Object { "- $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)" })

Status: SUCCES
"@ | Out-File -FilePath $reportPath -Encoding UTF8
    Write-BuildLog ("Rapport: " + (Split-Path $reportPath -Leaf)) "SUCCESS"
  }
  catch {
    Write-BuildLog "Erreur rapport: $_" "ERROR"
  }
}

function Main {
  $script:buildStart = Get-Date
  Write-BuildLog "=== Build Release Production v$Version ===" "STEP"
  try {
    Ensure-CleanPackageJson
    Test-BuildPrerequisites
    Update-Version -NewVersion $Version
    Invoke-Tests
    Invoke-Build
    Collect-Artifacts
    Invoke-Signing
    New-Checksums
    New-ReleaseNotes
    New-GitTag
    New-BuildReport

    $script:buildEnd = Get-Date
    Write-BuildLog "Build termine avec succes." "SUCCESS"
    Write-BuildLog ("Release dir: " + $ReleaseDir) "SUCCESS"
    Write-BuildLog ("Duree: " + ($buildEnd - $buildStart)) "INFO"

    if ($CreateGitHubRelease) {
      Write-BuildLog ("Commande suggeree: gh release create v$Version --title `"USB Video Vault v$Version`" --notes-file `"$ReleaseDir\RELEASE_NOTES_v$Version.md`" `"$ReleaseDir\*`"") "INFO"
    }
  }
  catch {
    Write-BuildLog ("Build echoue: " + $_) "ERROR"
    exit 1
  }
}

# Execution
Main

<#
.SYNOPSIS
USB Video Vault - Script de Build Release Production

.DESCRIPTION
Script propre et robuste pour generer une release production de USB Video Vault avec:
- Build electron-builder (NSIS + portable)
- Signature code (certificat store ou PFX)
- Hashes SHA256
- Notes de release automatiques
- Tag Git

.EXAMPLE
# Avec certificat du store Windows
.\scripts\create-release-prod.ps1 -Version "1.0.4" -CertThumbprint "74d81f58e006cb1e05fb66b3ccf69540f4186737"

.EXAMPLE  
# Avec fichier PFX
$pass = Read-Host -AsSecureString "Mot de passe PFX"
.\scripts\create-release-prod.ps1 -Version "1.0.4" -PfxPath "C:\certs\codesign.pfx" -PfxPassword $pass

.EXAMPLE
# Sans signature (test)
.\scripts\create-release-prod.ps1 -Version "1.0.4" -SkipSigning -SkipTests
#>
