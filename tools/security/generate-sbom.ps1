# Script de génération SBOM (Software Bill of Materials)
# Usage: .\generate-sbom.ps1 [-Format json|xml|spdx] [-Output path]

param(
    [ValidateSet("json","xml","spdx")]
    [string]$Format = "json",
    [string]$Output = ".\dist\sbom.$Format"
)

Write-Host "=== Génération SBOM - USB Video Vault ===" -ForegroundColor Cyan

# Lire package.json
$packageJson = Get-Content ".\package.json" | ConvertFrom-Json

# Informations de base du projet
$projectInfo = @{
    name = $packageJson.name
    version = $packageJson.version
    description = $packageJson.description
    homepage = $packageJson.homepage
    repository = $packageJson.repository.url
    license = $packageJson.license
    author = $packageJson.author
}

Write-Host "Projet: $($projectInfo.name) v$($projectInfo.version)" -ForegroundColor Green

# Analyser les dépendances de production
Write-Host "Analyse des dépendances de production..." -ForegroundColor Yellow
$prodDeps = @()

if ($packageJson.dependencies) {
    foreach ($dep in $packageJson.dependencies.PSObject.Properties) {
        $depName = $dep.Name
        $depVersion = $dep.Value
        
        try {
            # Lire package.json de la dépendance
            $depPackagePath = ".\node_modules\$depName\package.json"
            if (Test-Path $depPackagePath) {
                $depPackage = Get-Content $depPackagePath | ConvertFrom-Json
                
                $prodDeps += @{
                    name = $depName
                    version = $depVersion
                    actualVersion = $depPackage.version
                    license = $depPackage.license
                    description = $depPackage.description
                    homepage = $depPackage.homepage
                    repository = if ($depPackage.repository) { $depPackage.repository.url } else { $null }
                    author = $depPackage.author
                    type = "npm"
                    scope = "production"
                }
            } else {
                $prodDeps += @{
                    name = $depName
                    version = $depVersion
                    actualVersion = "unknown"
                    license = "unknown"
                    type = "npm"
                    scope = "production"
                }
            }
        } catch {
            Write-Warning "Erreur analyse $depName : $($_.Exception.Message)"
        }
    }
}

Write-Host "Dépendances de production: $($prodDeps.Count)" -ForegroundColor Green

# Analyser les dépendances de développement
Write-Host "Analyse des dépendances de développement..." -ForegroundColor Yellow
$devDeps = @()

if ($packageJson.devDependencies) {
    foreach ($dep in $packageJson.devDependencies.PSObject.Properties) {
        $depName = $dep.Name
        $depVersion = $dep.Value
        
        try {
            $depPackagePath = ".\node_modules\$depName\package.json"
            if (Test-Path $depPackagePath) {
                $depPackage = Get-Content $depPackagePath | ConvertFrom-Json
                
                $devDeps += @{
                    name = $depName
                    version = $depVersion
                    actualVersion = $depPackage.version
                    license = $depPackage.license
                    description = $depPackage.description
                    type = "npm"
                    scope = "development"
                }
            }
        } catch {
            Write-Warning "Erreur analyse dev $depName : $($_.Exception.Message)"
        }
    }
}

Write-Host "Dépendances de développement: $($devDeps.Count)" -ForegroundColor Green

# Générer le SBOM selon le format demandé
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$sbomId = "USB-Video-Vault-$($projectInfo.version)-$(Get-Date -Format 'yyyyMMdd')"

switch ($Format) {
    "json" {
        $sbom = @{
            bomFormat = "CycloneDx"
            specVersion = "1.4"
            serialNumber = "urn:uuid:$([System.Guid]::NewGuid().ToString())"
            version = 1
            metadata = @{
                timestamp = $timestamp
                tools = @(@{
                    vendor = "USB Video Vault"
                    name = "generate-sbom.ps1"
                    version = "1.0.0"
                })
                component = @{
                    type = "application"
                    "bom-ref" = $sbomId
                    name = $projectInfo.name
                    version = $projectInfo.version
                    description = $projectInfo.description
                    licenses = @(@{
                        license = @{
                            name = $projectInfo.license
                        }
                    })
                    externalReferences = @(
                        @{
                            type = "website"
                            url = $projectInfo.homepage
                        },
                        @{
                            type = "vcs"
                            url = $projectInfo.repository
                        }
                    )
                }
            }
            components = @()
        }
        
        # Ajouter les composants
        foreach ($dep in ($prodDeps + $devDeps)) {
            $component = @{
                type = "library"
                "bom-ref" = "$($dep.name)@$($dep.actualVersion)"
                name = $dep.name
                version = $dep.actualVersion
                description = $dep.description
                scope = $dep.scope
                licenses = @()
                externalReferences = @()
            }
            
            if ($dep.license) {
                $component.licenses += @{
                    license = @{
                        name = $dep.license
                    }
                }
            }
            
            if ($dep.homepage) {
                $component.externalReferences += @{
                    type = "website"
                    url = $dep.homepage
                }
            }
            
            if ($dep.repository) {
                $component.externalReferences += @{
                    type = "vcs"
                    url = $dep.repository
                }
            }
            
            $sbom.components += $component
        }
        
        $sbomJson = $sbom | ConvertTo-Json -Depth 10
        $sbomJson | Out-File -FilePath $Output -Encoding UTF8
    }
    
    "spdx" {
        $spdxContent = @"
SPDXVersion: SPDX-2.3
DataLicense: CC0-1.0
SPDXID: SPDXRef-DOCUMENT
DocumentName: $($projectInfo.name)-$($projectInfo.version)
DocumentNamespace: https://example.com/spdx/$sbomId
Creator: Tool: generate-sbom.ps1-1.0.0
Created: $timestamp

PackageName: $($projectInfo.name)
SPDXID: SPDXRef-Package
PackageVersion: $($projectInfo.version)
PackageDownloadLocation: $($projectInfo.repository)
FilesAnalyzed: false
PackageLicenseConcluded: $($projectInfo.license)
PackageLicenseDeclared: $($projectInfo.license)
PackageCopyrightText: NOASSERTION

"@
        
        foreach ($dep in $prodDeps) {
            $spdxContent += @"
PackageName: $($dep.name)
SPDXID: SPDXRef-$($dep.name -replace '[^a-zA-Z0-9]', '')
PackageVersion: $($dep.actualVersion)
PackageDownloadLocation: $($dep.repository)
FilesAnalyzed: false
PackageLicenseConcluded: $($dep.license)
PackageLicenseDeclared: $($dep.license)
PackageCopyrightText: NOASSERTION

"@
        }
        
        $spdxContent | Out-File -FilePath $Output -Encoding UTF8
    }
    
    "xml" {
        # Format XML simple (non-standard mais lisible)
        $xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<sbom xmlns="http://example.com/sbom" version="1.0" timestamp="$timestamp">
  <project>
    <name>$($projectInfo.name)</name>
    <version>$($projectInfo.version)</version>
    <description>$($projectInfo.description)</description>
    <license>$($projectInfo.license)</license>
    <repository>$($projectInfo.repository)</repository>
  </project>
  <dependencies>
"@
        
        foreach ($dep in ($prodDeps + $devDeps)) {
            $xmlContent += @"
    <dependency scope="$($dep.scope)">
      <name>$($dep.name)</name>
      <version>$($dep.actualVersion)</version>
      <license>$($dep.license)</license>
      <description><![CDATA[$($dep.description)]]></description>
    </dependency>
"@
        }
        
        $xmlContent += @"
  </dependencies>
</sbom>
"@
        
        $xmlContent | Out-File -FilePath $Output -Encoding UTF8
    }
}

Write-Host "`n✅ SBOM généré : $Output" -ForegroundColor Green
Write-Host "Format: $Format" -ForegroundColor Gray
Write-Host "Composants: $($prodDeps.Count + $devDeps.Count + 1) (app + dépendances)" -ForegroundColor Gray

# Validation basique
if (Test-Path $Output) {
    $size = (Get-Item $Output).Length
    Write-Host "Taille: $size octets" -ForegroundColor Gray
} else {
    Write-Error "Erreur: Fichier SBOM non créé"
    exit 1
}

# Résumé des licences
Write-Host "`nRésumé des licences:" -ForegroundColor Yellow
$licenses = ($prodDeps + $devDeps) | Where-Object { $_.license -and $_.license -ne "unknown" } | Group-Object license | Sort-Object Count -Descending
foreach ($license in $licenses) {
    Write-Host "  $($license.Name): $($license.Count) packages" -ForegroundColor Gray
}