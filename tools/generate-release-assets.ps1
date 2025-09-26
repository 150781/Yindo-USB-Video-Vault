# Script de generation assets integrite pour GitHub Release
# Usage: .\tools\generate-release-assets.ps1 -Version "0.1.5" [-TestMode]

param(
    [string]$Version = "0.1.5",
    [switch]$TestMode
)

Write-Host "=== GENERATION ASSETS INTEGRITE v$Version ===" -ForegroundColor Cyan
Write-Host ""

$distDir = ".\dist"
$assetsDir = ".\dist\release-assets"

# Creer dossier assets si necessaire
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
    Write-Host "Dossier assets cree: $assetsDir" -ForegroundColor Green
}

Write-Host "1. DETECTION BINAIRES DISTRIBUTION..." -ForegroundColor Yellow

# Recherche tous les binaires de distribution
$binaryPatterns = @(
    "USB Video Vault Setup *.exe",
    "USB Video Vault-*-win.exe",
    "*.exe",
    "*.msi",
    "*.zip",
    "*.tar.gz",
    "*.AppImage",
    "*.dmg",
    "*.pkg"
)

$foundBinaries = @()
foreach ($pattern in $binaryPatterns) {
    $files = Get-ChildItem -Path $distDir -Name $pattern -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $fullPath = Join-Path $distDir $file
        if ((Get-Item $fullPath).Length -gt 1MB) {  # Ignorer petits fichiers
            $foundBinaries += @{
                Name = $file
                Path = $fullPath
                Size = (Get-Item $fullPath).Length
            }
            Write-Host "  Trouve: $file ($([math]::Round((Get-Item $fullPath).Length/1MB, 1)) MB)" -ForegroundColor Green
        }
    }
}

if ($foundBinaries.Count -eq 0) {
    Write-Host "  ERREUR: Aucun binaire de distribution trouve" -ForegroundColor Red
    Write-Host "  Executer d'abord: npm run build" -ForegroundColor Blue
    exit 1
}

Write-Host "  Total: $($foundBinaries.Count) binaires detectes" -ForegroundColor Cyan

if ($TestMode) {
    Write-Host ""
    Write-Host "MODE TEST - Simulation generation assets" -ForegroundColor Blue
    Write-Host "Assets qui seraient generes:" -ForegroundColor Blue
    Write-Host "  - SHA256SUMS (hashes tous binaires)" -ForegroundColor Cyan
    Write-Host "  - SBOM.json (Software Bill of Materials)" -ForegroundColor Cyan
    Write-Host "  - security-report.json (audit securite)" -ForegroundColor Cyan
    Write-Host "  - checksums.txt (format compatible tools)" -ForegroundColor Cyan
    Write-Host "  - release-metadata.json (infos release)" -ForegroundColor Cyan
    exit 0
}

# GENERATION SHA256SUMS
Write-Host ""
Write-Host "2. GENERATION SHA256SUMS..." -ForegroundColor Yellow

$sha256Content = @()
$sha256Content += "# SHA256 Checksums for USB Video Vault v$Version"
$sha256Content += "# Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
$sha256Content += ""

foreach ($binary in $foundBinaries) {
    Write-Host "  Calcul SHA256: $($binary.Name)..." -ForegroundColor Gray

    try {
        $hash = Get-FileHash -Path $binary.Path -Algorithm SHA256
        $sha256Content += "$($hash.Hash.ToLower())  $($binary.Name)"
        Write-Host "    $($hash.Hash.ToLower())" -ForegroundColor Green
    } catch {
        Write-Host "    ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

$sha256File = Join-Path $assetsDir "SHA256SUMS"
$sha256Content | Out-File -FilePath $sha256File -Encoding UTF8
Write-Host "  SHA256SUMS genere: $sha256File" -ForegroundColor Green

# GENERATION SBOM (Software Bill of Materials)
Write-Host ""
Write-Host "3. GENERATION SBOM..." -ForegroundColor Yellow

$packageJson = Get-Content ".\package.json" -Raw | ConvertFrom-Json

$sbom = @{
    bomFormat = "CycloneDX"
    specVersion = "1.4"
    serialNumber = "urn:uuid:$([System.Guid]::NewGuid().ToString())"
    version = 1
    metadata = @{
        timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        tools = @(
            @{
                vendor = "Yindo"
                name = "USB Video Vault Build System"
                version = $Version
            }
        )
        component = @{
            type = "application"
            "bom-ref" = "usb-video-vault@$Version"
            name = "USB Video Vault"
            version = $Version
            description = $packageJson.description
            licenses = @(
                @{ license = @{ id = $packageJson.license } }
            )
        }
    }
    components = @()
}

# Ajouter dependances principales depuis package.json
if ($packageJson.dependencies) {
    foreach ($dep in $packageJson.dependencies.PSObject.Properties) {
        $sbom.components += @{
            type = "library"
            "bom-ref" = "$($dep.Name)@$($dep.Value)"
            name = $dep.Name
            version = $dep.Value.TrimStart('^~')
            scope = "required"
        }
    }
}

# Ajouter informations binaires
foreach ($binary in $foundBinaries) {
    $hash = Get-FileHash -Path $binary.Path -Algorithm SHA256
    $sbom.components += @{
        type = "file"
        "bom-ref" = $binary.Name
        name = $binary.Name
        version = $Version
        hashes = @(
            @{
                alg = "SHA-256"
                content = $hash.Hash.ToLower()
            }
        )
        properties = @(
            @{
                name = "size"
                value = $binary.Size.ToString()
            }
        )
    }
}

$sbomFile = Join-Path $assetsDir "SBOM.json"
$sbom | ConvertTo-Json -Depth 10 | Out-File -FilePath $sbomFile -Encoding UTF8
Write-Host "  SBOM genere: $sbomFile ($($sbom.components.Count) composants)" -ForegroundColor Green

# GENERATION RAPPORT SECURITE
Write-Host ""
Write-Host "4. GENERATION RAPPORT SECURITE..." -ForegroundColor Yellow

$securityReport = @{
    version = $Version
    timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    summary = @{
        totalBinaries = $foundBinaries.Count
        signedBinaries = 0
        unsignedBinaries = 0
        vulnerabilities = @()
        recommendations = @()
    }
    binaries = @()
}

# Analyser chaque binaire
foreach ($binary in $foundBinaries) {
    Write-Host "  Analyse securite: $($binary.Name)..." -ForegroundColor Gray

    $binaryAnalysis = @{
        name = $binary.Name
        size = $binary.Size
        hash = (Get-FileHash -Path $binary.Path -Algorithm SHA256).Hash.ToLower()
        signature = @{
            status = "unknown"
            valid = $false
            signer = ""
            timestamp = ""
        }
        issues = @()
    }

    # Verification signature
    if ($binary.Name.EndsWith(".exe") -or $binary.Name.EndsWith(".msi")) {
        try {
            $signature = Get-AuthenticodeSignature $binary.Path

            $binaryAnalysis.signature.status = $signature.Status.ToString()

            if ($signature.Status -eq "Valid") {
                $binaryAnalysis.signature.valid = $true
                $binaryAnalysis.signature.signer = $signature.SignerCertificate.Subject
                if ($signature.TimeStamperCertificate) {
                    $binaryAnalysis.signature.timestamp = $signature.TimeStamperCertificate.NotAfter.ToString("yyyy-MM-dd")
                }
                $securityReport.summary.signedBinaries++
            } elseif ($signature.Status -eq "NotSigned") {
                $binaryAnalysis.issues += "Binary not digitally signed - SmartScreen risk"
                $securityReport.summary.unsignedBinaries++
            } else {
                $binaryAnalysis.issues += "Invalid digital signature - status: $($signature.Status)"
                $securityReport.summary.unsignedBinaries++
            }
        } catch {
            $binaryAnalysis.issues += "Signature verification failed: $($_.Exception.Message)"
            $securityReport.summary.unsignedBinaries++
        }
    }

    # Verification taille
    if ($binary.Size -gt 200MB) {
        $binaryAnalysis.issues += "Large binary size may indicate bundled dependencies"
    }

    $securityReport.binaries += $binaryAnalysis
}

# Recommandations generales
if ($securityReport.summary.unsignedBinaries -gt 0) {
    $securityReport.summary.recommendations += "Sign all executable binaries with Authenticode certificate"
    $securityReport.summary.recommendations += "Configure timestamp server for long-term signature validity"
}

$securityReport.summary.recommendations += "Verify all binaries with antivirus before distribution"
$securityReport.summary.recommendations += "Monitor Windows SmartScreen reputation after release"

$securityFile = Join-Path $assetsDir "security-report.json"
$securityReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $securityFile -Encoding UTF8
Write-Host "  Rapport securite genere: $securityFile" -ForegroundColor Green

# GENERATION CHECKSUMS COMPATIBLES
Write-Host ""
Write-Host "5. GENERATION CHECKSUMS COMPATIBLES..." -ForegroundColor Yellow

$checksumsContent = @()
foreach ($binary in $foundBinaries) {
    $hash = Get-FileHash -Path $binary.Path -Algorithm SHA256
    # Format standard: HASH *FILENAME
    $checksumsContent += "$($hash.Hash.ToLower()) *$($binary.Name)"
}

$checksumsFile = Join-Path $assetsDir "checksums.txt"
$checksumsContent | Out-File -FilePath $checksumsFile -Encoding UTF8
Write-Host "  Checksums generes: $checksumsFile" -ForegroundColor Green

# GENERATION METADATA RELEASE
Write-Host ""
Write-Host "6. GENERATION METADATA RELEASE..." -ForegroundColor Yellow

$releaseMetadata = @{
    version = $Version
    releaseDate = (Get-Date).ToString("yyyy-MM-dd")
    buildTimestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    platform = "windows"
    architecture = "x64"
    artifacts = @()
    checksums = @{
        algorithm = "SHA256"
        file = "SHA256SUMS"
    }
    security = @{
        signed = ($securityReport.summary.signedBinaries -gt 0)
        signedCount = $securityReport.summary.signedBinaries
        totalCount = $securityReport.summary.totalBinaries
        vulnerabilities = $securityReport.summary.vulnerabilities.Count
    }
    tools = @{
        electron = $packageJson.devDependencies.electron
        electronBuilder = $packageJson.devDependencies."electron-builder"
        node = $env:NODE_VERSION
        npm = (npm --version 2>$null)
    }
}

foreach ($binary in $foundBinaries) {
    $releaseMetadata.artifacts += @{
        name = $binary.Name
        size = $binary.Size
        type = if ($binary.Name -like "*.exe") { "installer" } else { "archive" }
        platform = "windows"
        hash = (Get-FileHash -Path $binary.Path -Algorithm SHA256).Hash.ToLower()
    }
}

$metadataFile = Join-Path $assetsDir "release-metadata.json"
$releaseMetadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataFile -Encoding UTF8
Write-Host "  Metadata generes: $metadataFile" -ForegroundColor Green

# RAPPORT FINAL
Write-Host ""
Write-Host "=== ASSETS INTEGRITE GENERES ===" -ForegroundColor Cyan

$generatedFiles = Get-ChildItem $assetsDir -File
Write-Host "Dossier: $assetsDir" -ForegroundColor White
Write-Host ""
Write-Host "Assets generes:" -ForegroundColor White
foreach ($file in $generatedFiles) {
    $size = [math]::Round($file.Length / 1KB, 1)
    Write-Host "  + $($file.Name) ($size KB)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Statistiques:" -ForegroundColor White
Write-Host "  Binaires analyses: $($foundBinaries.Count)" -ForegroundColor Gray
Write-Host "  Binaires signes: $($securityReport.summary.signedBinaries)" -ForegroundColor Gray
Write-Host "  Binaires non-signes: $($securityReport.summary.unsignedBinaries)" -ForegroundColor Gray
Write-Host "  Composants SBOM: $($sbom.components.Count)" -ForegroundColor Gray

Write-Host ""
if ($securityReport.summary.unsignedBinaries -eq 0) {
    Write-Host "RESULTAT: INTEGRITE COMPLETE" -ForegroundColor Green
    Write-Host "Tous les binaires sont signes et verifies" -ForegroundColor Green
} else {
    Write-Host "RESULTAT: SIGNATURE INCOMPLETE" -ForegroundColor Yellow
    Write-Host "$($securityReport.summary.unsignedBinaries) binaire(s) non-signe(s) detecte(s)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Pour GitHub Release:" -ForegroundColor Blue
Write-Host "  1. Uploader tous les fichiers de: $assetsDir" -ForegroundColor White
Write-Host "  2. Inclure SHA256SUMS dans description release" -ForegroundColor White
Write-Host "  3. Reference SBOM.json pour compliance supply-chain" -ForegroundColor White
