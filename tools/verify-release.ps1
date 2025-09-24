# Script de vérification d'intégrité pour USB Video Vault v0.1.4
# Utilisation: .\verify-release.ps1 -Path "C:\Downloads"

param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

Write-Host "🔍 Vérification des assets USB Video Vault v0.1.4" -ForegroundColor Cyan
Write-Host "📁 Répertoire: $Path" -ForegroundColor Gray

$setupFile = Join-Path $Path "USB Video Vault Setup 0.1.4.exe"
$portableFile = Join-Path $Path "USB Video Vault 0.1.4.exe"
$sha256File = Join-Path $Path "SHA256SUMS"

Write-Host "`n📋 Vérification de la présence des fichiers:" -ForegroundColor Yellow

# Vérifier la présence des fichiers
$files = @(
  @{Name = "Setup NSIS"; Path = $setupFile },
  @{Name = "Portable"; Path = $portableFile },
  @{Name = "SHA256SUMS"; Path = $sha256File }
)

foreach ($file in $files) {
  if (Test-Path $file.Path) {
    Write-Host "✅ $($file.Name): Présent" -ForegroundColor Green
  }
  else {
    Write-Host "❌ $($file.Name): MANQUANT" -ForegroundColor Red
  }
}

Write-Host "`n🔐 Vérification des signatures:" -ForegroundColor Yellow

# Fonction pour vérifier la signature
function Test-CodeSignature {
  param([string]$FilePath, [string]$Name)

  if (-not (Test-Path $FilePath)) {
    Write-Host "❌ $Name - Fichier introuvable" -ForegroundColor Red
    return
  }

  try {
    $sig = Get-AuthenticodeSignature $FilePath
    Write-Host "`n📄 $Name" -ForegroundColor Cyan
    Write-Host "   Status: $($sig.Status)" -ForegroundColor $(if ($sig.Status -eq "Valid") { "Green" } else { "Red" })

    if ($sig.SignerCertificate) {
      Write-Host "   Signataire: $($sig.SignerCertificate.Subject)" -ForegroundColor Gray
      Write-Host "   Émetteur: $($sig.SignerCertificate.Issuer)" -ForegroundColor Gray
      Write-Host "   Expire: $($sig.SignerCertificate.NotAfter)" -ForegroundColor Gray
    }

    if ($sig.TimeStamperCertificate) {
      Write-Host "   Timestamp: $($sig.TimeStamperCertificate.Subject)" -ForegroundColor Gray
    }
    else {
      Write-Host "   ⚠️  Pas de timestamp" -ForegroundColor Yellow
    }

    if ($sig.Status -eq "Valid") {
      Write-Host "   ✅ Signature valide" -ForegroundColor Green
    }
    else {
      Write-Host "   ❌ Signature invalide: $($sig.StatusMessage)" -ForegroundColor Red
    }
  }
  catch {
    Write-Host "   ❌ Erreur lors de la vérification: $($_.Exception.Message)" -ForegroundColor Red
  }
}

Test-CodeSignature $setupFile "Setup NSIS"
Test-CodeSignature $portableFile "Portable"

Write-Host "`n🔢 Calcul des empreintes SHA256:" -ForegroundColor Yellow

# Fonction pour calculer et afficher les hashes
function Get-FileHashInfo {
  param([string]$FilePath, [string]$Name)

  if (-not (Test-Path $FilePath)) {
    Write-Host "❌ $Name - Fichier introuvable" -ForegroundColor Red
    return
  }

  try {
    $hash = Get-FileHash $FilePath -Algorithm SHA256
    $size = (Get-Item $FilePath).Length
    $sizeStr = if ($size -gt 1MB) { "{0:N1} MB" -f ($size / 1MB) } else { "{0:N0} KB" -f ($size / 1KB) }

    Write-Host "`n📄 $Name ($sizeStr)" -ForegroundColor Cyan
    Write-Host "   SHA256: $($hash.Hash)" -ForegroundColor Gray

    # Vérifier contre SHA256SUMS si disponible
    if (Test-Path $sha256File) {
      $sha256Content = Get-Content $sha256File
      $expectedHash = $sha256Content | Where-Object { $_ -like "*$(Split-Path $FilePath -Leaf)*" } | ForEach-Object { ($_ -split '\s+')[0] }

      if ($expectedHash -and $expectedHash.ToUpper() -eq $hash.Hash.ToUpper()) {
        Write-Host "   ✅ Hash correspondant dans SHA256SUMS" -ForegroundColor Green
      }
      elseif ($expectedHash) {
        Write-Host "   ❌ Hash différent dans SHA256SUMS" -ForegroundColor Red
      }
      else {
        Write-Host "   ⚠️  Hash non trouvé dans SHA256SUMS" -ForegroundColor Yellow
      }
    }
  }
  catch {
    Write-Host "   ❌ Erreur lors du calcul: $($_.Exception.Message)" -ForegroundColor Red
  }
}

Get-FileHashInfo $setupFile "Setup NSIS"
Get-FileHashInfo $portableFile "Portable"

Write-Host "`n📊 Résumé:" -ForegroundColor Yellow
$setupExists = Test-Path $setupFile
$portableExists = Test-Path $portableFile
$sha256Exists = Test-Path $sha256File

if ($setupExists -and $portableExists) {
  Write-Host "✅ Tous les exécutables sont présents" -ForegroundColor Green
}
else {
  Write-Host "❌ Des fichiers manquent" -ForegroundColor Red
}

if ($sha256Exists) {
  Write-Host "✅ Fichier SHA256SUMS présent" -ForegroundColor Green
}
else {
  Write-Host "⚠️  Fichier SHA256SUMS manquant" -ForegroundColor Yellow
}

Write-Host "`n🎯 Tests recommandés:" -ForegroundColor Yellow
Write-Host "   1. VM Windows propre (sans Node/Electron)" -ForegroundColor Gray
Write-Host "   2. Installation → Lancement → Désinstallation" -ForegroundColor Gray
Write-Host "   3. Test portable en droits utilisateur standard" -ForegroundColor Gray
Write-Host "   4. Installation silencieuse: .\`"USB Video Vault Setup 0.1.4.exe`" /S" -ForegroundColor Gray
Write-Host "   5. Désinstallation silencieuse depuis Program Files" -ForegroundColor Gray

Write-Host "`n🔍 Vérification terminée !" -ForegroundColor Cyan
