# CREATE-GITHUB-RELEASE.PS1 - Creation automatisee Release GitHub
param(
  [Parameter(Mandatory = $true)]
  [string]$Version = "0.1.5",

  [Parameter(Mandatory = $true)]
  [string]$GitHubToken,

  [switch]$Execute = $false
)

$ErrorActionPreference = "Stop"

# Configuration
$repoOwner = "150781"
$repoName = "Yindo-USB-Video-Vault"
$tagName = "v$Version"
$releaseName = "USB Video Vault v$Version"

# Headers pour API GitHub
$headers = @{
  "Authorization" = "Bearer $GitHubToken"
  "Accept"        = "application/vnd.github.v3+json"
  "Content-Type"  = "application/json"
}

function Create-GitHubRelease {
  Write-Host "=== CREATION RELEASE GITHUB v$Version ===" -ForegroundColor Green

  # 1. Verification des fichiers
  Write-Host "1. Verification fichiers..." -ForegroundColor Blue

  $setupFile = ".\dist\USB Video Vault Setup $Version.exe"
  $portableFile = ".\dist\USB Video Vault $Version.exe"
  $sha256File = ".\dist\SHA256SUMS"
  $readmeFile = ".\dist\README-RELEASE.md"

  $files = @()

  if (Test-Path $setupFile) {
    Write-Host "   [OK] Setup file: $setupFile" -ForegroundColor Green
    $files += $setupFile
  }
  else {
    Write-Host "   [ERROR] Setup file manquant: $setupFile" -ForegroundColor Red
    return $false
  }

  if (Test-Path $portableFile) {
    Write-Host "   [OK] Portable file: $portableFile" -ForegroundColor Green
    $files += $portableFile
  }
  else {
    Write-Host "   [WARN] Portable file manquant: $portableFile" -ForegroundColor Yellow
  }

  if (Test-Path $sha256File) {
    Write-Host "   [OK] SHA256SUMS: $sha256File" -ForegroundColor Green
    $files += $sha256File
  }
  else {
    Write-Host "   [ERROR] SHA256SUMS manquant: $sha256File" -ForegroundColor Red
    return $false
  }

  if (Test-Path $readmeFile) {
    Write-Host "   [OK] README: $readmeFile" -ForegroundColor Green
    $files += $readmeFile
  }

  # 2. Creation de la release
  Write-Host "`n2. Creation release sur GitHub..." -ForegroundColor Blue

  $releaseBody = @"
## USB Video Vault v$Version

### 📥 Installation
- **Setup (recommandé)** : ``USB Video Vault Setup $Version.exe``
- **Version portable** : ``USB Video Vault $Version.exe``

### ⚠️ Note Windows SmartScreen
Si Windows affiche un avertissement, cliquez sur "**Informations complémentaires**" puis "**Exécuter quand même**".

### 🔒 Vérification d'intégrité
Voir le fichier ``SHA256SUMS`` pour les hachages de vérification.

### 📞 Support
Pour toute question, ouvrez une issue sur ce repository.

---
**Première release publique** • **Windows x64** • **26 septembre 2025**
"@

  $releaseData = @{
    tag_name         = $tagName
    target_commitish = "master"
    name             = $releaseName
    body             = $releaseBody
    draft            = $false
    prerelease       = $false
  } | ConvertTo-Json -Depth 3

  if ($Execute) {
    try {
      $releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/releases" `
        -Method POST -Headers $headers -Body $releaseData

      Write-Host "   [OK] Release creee: $($releaseResponse.html_url)" -ForegroundColor Green
      $releaseId = $releaseResponse.id
    }
    catch {
      Write-Host "   [ERROR] Echec creation release: $($_.Exception.Message)" -ForegroundColor Red
      return $false
    }

    # 3. Upload des assets
    Write-Host "`n3. Upload assets..." -ForegroundColor Blue

    foreach ($file in $files) {
      if (Test-Path $file) {
        $fileName = Split-Path $file -Leaf
        Write-Host "   Uploading: $fileName" -ForegroundColor Cyan

        try {
          $fileBytes = [System.IO.File]::ReadAllBytes($file)
          $uploadHeaders = @{
            "Authorization" = "Bearer $GitHubToken"
            "Content-Type"  = "application/octet-stream"
          }

          $uploadUrl = "https://uploads.github.com/repos/$repoOwner/$repoName/releases/$releaseId/assets?name=$fileName"
          $uploadResponse = Invoke-RestMethod -Uri $uploadUrl -Method POST -Headers $uploadHeaders -Body $fileBytes

          Write-Host "     [OK] $fileName uploaded" -ForegroundColor Green
        }
        catch {
          Write-Host "     [ERROR] Upload failed for $fileName : $($_.Exception.Message)" -ForegroundColor Red
        }
      }
    }

    Write-Host "`n[SUCCESS] Release GitHub creee avec succes!" -ForegroundColor Green
    Write-Host "URL: $($releaseResponse.html_url)" -ForegroundColor Cyan

  }
  else {
    Write-Host "   [SIMULATION] Creation release..." -ForegroundColor Gray
    Write-Host "   Tag: $tagName" -ForegroundColor White
    Write-Host "   Nom: $releaseName" -ForegroundColor White
    Write-Host "   Fichiers: $($files.Count) assets" -ForegroundColor White
  }

  return $true
}

# Instructions si pas de token
if (-not $GitHubToken) {
  Write-Host "=== INSTRUCTIONS GITHUB RELEASE ===" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Pour creer la release automatiquement:" -ForegroundColor White
  Write-Host "1. Allez sur: https://github.com/settings/tokens" -ForegroundColor Cyan
  Write-Host "2. Generate new token (classic)" -ForegroundColor Cyan
  Write-Host "3. Cochez: 'repo' (Full control of private repositories)" -ForegroundColor Cyan
  Write-Host "4. Copiez le token genere" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Puis executez:" -ForegroundColor White
  Write-Host "  .\create-github-release.ps1 -Version '$Version' -GitHubToken 'VOTRE_TOKEN' -Execute" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "=== ALTERNATIVE MANUELLE ===" -ForegroundColor Yellow
  Write-Host "1. https://github.com/$repoOwner/$repoName/releases/new" -ForegroundColor Cyan
  Write-Host "2. Tag: $tagName" -ForegroundColor White
  Write-Host "3. Title: $releaseName" -ForegroundColor White
  Write-Host "4. Upload files from .\dist\" -ForegroundColor White
  return
}

# Execution
$success = Create-GitHubRelease
if ($success) {
  exit 0
}
else {
  exit 1
}
