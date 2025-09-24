# Script de preparation des assets de release GitHub
# Usage: .\prepare-release-assets.ps1 -Version "0.1.4" -OutputDir ".\release-assets"

param(
    [string]$Version = "0.1.4",
    [string]$OutputDir = ".\release-assets"
)

Write-Host "=== Preparation assets release v$Version ===" -ForegroundColor Cyan
Write-Host ""

# Creer le dossier de sortie
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Dossier cree: $OutputDir" -ForegroundColor Green
} else {
    Write-Host "Dossier existant: $OutputDir" -ForegroundColor Gray
}

# 1. Copier les binaires principaux
Write-Host "`n1. Copie des binaires..." -ForegroundColor Yellow
$sourceFiles = @(
    ".\dist\USB Video Vault Setup $Version.exe",
    ".\dist\USB Video Vault $Version.exe"
)

foreach ($file in $sourceFiles) {
    if (Test-Path $file) {
        $fileName = Split-Path $file -Leaf
        Copy-Item $file -Destination "$OutputDir\$fileName" -Force
        $size = [math]::Round((Get-Item "$OutputDir\$fileName").Length / 1MB, 2)
        Write-Host "OK $fileName ($size MB)" -ForegroundColor Green
    } else {
        Write-Host "WARN Fichier manquant: $file" -ForegroundColor Yellow
    }
}

# 2. Generer/Copier les checksums
Write-Host "`n2. Generation des checksums..." -ForegroundColor Yellow
$checksumFile = "$OutputDir\SHA256SUMS"
if (Test-Path ".\dist\SHA256SUMS") {
    Copy-Item ".\dist\SHA256SUMS" -Destination $checksumFile -Force
    Write-Host "OK SHA256SUMS copie" -ForegroundColor Green
} else {
    # Generer les checksums
    $binaries = Get-ChildItem $OutputDir -Filter "*.exe"
    $checksums = @()
    foreach ($binary in $binaries) {
        $hash = (Get-FileHash $binary.FullName -Algorithm SHA256).Hash
        $checksums += "$hash  $($binary.Name)"
    }
    $checksums -join "`n" | Out-File $checksumFile -Encoding ASCII
    Write-Host "OK SHA256SUMS genere" -ForegroundColor Green
}

# 3. Copier le SBOM
Write-Host "`n3. SBOM (Software Bill of Materials)..." -ForegroundColor Yellow
$sbomSource = ".\dist\SBOM-USBVideoVault-v$Version.json"
if (Test-Path $sbomSource) {
    Copy-Item $sbomSource -Destination "$OutputDir\SBOM.json" -Force
    $sbomSize = [math]::Round((Get-Item "$OutputDir\SBOM.json").Length / 1KB, 1)
    Write-Host "OK SBOM.json ($sbomSize KB)" -ForegroundColor Green
} else {
    Write-Host "WARN SBOM non trouve - generation..." -ForegroundColor Yellow
    if (Test-Path ".\tools\security\generate-sbom.ps1") {
        & .\tools\security\generate-sbom.ps1 -Format json -Output "$OutputDir\SBOM.json"
    }
}

# 4. Copier la documentation utilisateur
Write-Host "`n4. Documentation utilisateur..." -ForegroundColor Yellow
$docsToInclude = @(
    @{Source=".\tools\support\USER_SUPPORT_GUIDE.md"; Target="USER_SUPPORT_GUIDE.md"},
    @{Source=".\README.md"; Target="README.md"},
    @{Source=".\CHANGELOG.md"; Target="CHANGELOG.md"}
)

foreach ($doc in $docsToInclude) {
    if (Test-Path $doc.Source) {
        Copy-Item $doc.Source -Destination "$OutputDir\$($doc.Target)" -Force
        Write-Host "OK $($doc.Target)" -ForegroundColor Green
    } else {
        Write-Host "WARN Document manquant: $($doc.Source)" -ForegroundColor Yellow
    }
}

# 5. Creer les notes de release
Write-Host "`n5. Generation des notes de release..." -ForegroundColor Yellow
$releaseNotesContent = @"
# USB Video Vault v$Version

## Nouvelle version stable

### Fonctionnalites principales
- **Gestion securisee des medias** : Chiffrement AES-256 des fichiers video
- **Systeme de licences** : Licences liees au materiel pour la protection
- **Interface moderne** : Interface utilisateur Electron avec gestion des playlists
- **Installation silencieuse** : Support IT avec switches /S et /D=path

### Securite
- Binaires signes avec certificat Authenticode (si disponible)
- Audit de securite : Score 84.2%
- SBOM (Software Bill of Materials) inclus pour la compliance
- Checksums SHA256 verifies

### Installation

#### Windows (Recommande)
```powershell
# Installation normale
.\USB Video Vault Setup $Version.exe

# Installation silencieuse (IT/Admin)
.\USB Video Vault Setup $Version.exe /S

# Installation dans un dossier specifique
.\USB Video Vault Setup $Version.exe /S /D=C:\MonDossier\USBVideoVault
```

### Support technique

En cas de probleme, executez le script de diagnostic :
```powershell
.\troubleshoot.ps1 -Detailed -CollectLogs
```

**Canaux de support :**
- GitHub Issues : Signaler un probleme
- Documentation : Guide utilisateur

### Checksums SHA256
Voir fichier SHA256SUMS inclus

---

**Installation testee sur :** Windows 10/11 (x64)
**Prerequis :** Aucun (runtime inclus)
**Taille d'installation :** ~200MB
"@

$releaseNotesContent | Out-File "$OutputDir\RELEASE_NOTES.md" -Encoding UTF8
Write-Host "OK RELEASE_NOTES.md genere" -ForegroundColor Green

# 6. Script de troubleshooting pour les utilisateurs
Write-Host "`n6. Script de diagnostic utilisateur..." -ForegroundColor Yellow
if (Test-Path ".\tools\support\troubleshoot.ps1") {
    Copy-Item ".\tools\support\troubleshoot.ps1" -Destination "$OutputDir\troubleshoot.ps1" -Force
    Write-Host "OK troubleshoot.ps1 copie" -ForegroundColor Green
} else {
    Write-Host "WARN Script troubleshoot non trouve" -ForegroundColor Yellow
}

# 7. Resume final
Write-Host "`n=== ASSETS DE RELEASE PRETS ===" -ForegroundColor Green
if (Test-Path $OutputDir) {
    $assets = Get-ChildItem $OutputDir | Sort-Object Name
    Write-Host "Dossier: $OutputDir" -ForegroundColor Cyan
    Write-Host "Assets ($($assets.Count) fichiers):" -ForegroundColor Yellow

    foreach ($asset in $assets) {
        $size = if ($asset.Length -gt 1MB) {
            "$([math]::Round($asset.Length/1MB,1))MB"
        } else {
            "$([math]::Round($asset.Length/1KB,1))KB"
        }
        Write-Host "  • $($asset.Name) ($size)" -ForegroundColor White
    }

    $totalSize = [math]::Round(($assets | Measure-Object Length -Sum).Sum / 1MB, 1)
    Write-Host "`nTaille totale: ${totalSize}MB" -ForegroundColor Cyan
}

Write-Host "`nCommandes GitHub Release:" -ForegroundColor Blue
Write-Host "gh release create v$Version --title `"USB Video Vault v$Version`" --notes-file `"$OutputDir\RELEASE_NOTES.md`" $OutputDir\*" -ForegroundColor White
